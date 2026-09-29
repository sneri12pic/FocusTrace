import 'dart:convert';
import 'dart:io';

import '../../domain/models/sync_usage.dart';

/// A failure the server reported, or a transport failure on the way there.
///
/// Carries the status and a fixed message only. No response body, no header and
/// no credential ever reaches this object, because it is the thing most likely
/// to be printed.
class SyncApiException implements Exception {
  const SyncApiException(this.statusCode, this.message);

  /// 0 when the request never produced a response (offline, timeout, TLS).
  final int statusCode;
  final String message;

  /// The request is wrong, not the moment. Resending it unchanged cannot help.
  bool get isPermanent => statusCode == 400 || statusCode == 404;

  bool get isUnauthenticated => statusCode == 401;

  @override
  String toString() => 'SyncApiException($statusCode): $message';
}

/// Where the rotating refresh token lives.
///
/// Backend security baseline section 8: a long-lived credential belongs in
/// OS-backed storage, never in a plaintext file and never in the SQLite
/// database. The access token is short-lived and memory-only, so it is not part
/// of this interface.
abstract interface class SyncCredentialStore {
  Future<String?> readRefreshToken();

  Future<void> writeRefreshToken(String token);

  Future<void> clear();
}

/// The one place FocusTrace speaks HTTP.
///
/// Owns the Sync v1 endpoints, JSON encoding, status mapping and the access
/// token lifecycle. Nothing above the sync repository sees an [HttpClient], a
/// status code or a JSON map, and no widget or view model reaches this class.
class FocusTraceSyncApi {
  FocusTraceSyncApi({
    required Uri baseUrl,
    required SyncCredentialStore credentials,
    HttpClient? httpClient,
    Duration timeout = const Duration(seconds: 20),
    DateTime Function()? now,
  }) : _baseUrl = baseUrl,
       _credentials = credentials,
       _client = httpClient ?? HttpClient(),
       _timeout = timeout,
       _now = now ?? DateTime.now;

  final Uri _baseUrl;
  final SyncCredentialStore _credentials;
  final HttpClient _client;
  final Duration _timeout;
  final DateTime Function() _now;

  void close() => _client.close(force: true);

  String? _accessToken;
  DateTime? _accessTokenExpiry;
  String? _sessionRefreshToken;

  /// Called only after acquiring the repository's cross-engine gate. Another
  /// engine may have rotated, replaced or cleared the persisted session.
  Future<void> reconcileSession() async {
    final current = await _credentials.readRefreshToken();
    if (current != _sessionRefreshToken) {
      _accessToken = null;
      _accessTokenExpiry = null;
      _sessionRefreshToken = current;
    }
  }

  /// One refresh at a time. Several requests hitting 401 together await this
  /// single attempt instead of racing the server's rotation, which would revoke
  /// the session chain by replay.
  Future<String>? _refreshing;

  /// Renew a little early so a request does not fail on a token that expires
  /// between the check and the server reading it.
  static const _clockMargin = Duration(seconds: 30);

  Future<bool> get hasSession async =>
      await _credentials.readRefreshToken() != null;

  // --- authentication -------------------------------------------------------

  Future<void> register(String email, String password) async {
    final response = await _send(
      'POST',
      '/api/v1/auth/register',
      body: {'email': email, 'password': password},
    );
    if (response.status != 201) {
      throw SyncApiException(response.status, 'Registration was refused.');
    }
  }

  Future<void> signIn(String email, String password) async {
    final response = await _send(
      'POST',
      '/api/v1/auth/login',
      body: {'email': email, 'password': password},
    );
    if (response.status != 200) {
      throw SyncApiException(response.status, 'Sign-in was refused.');
    }
    await _adoptSession(response.json);
  }

  /// Revokes this session server-side where possible, and always forgets it
  /// locally: a logout that cannot reach the network still signs the user out.
  Future<void> signOut() async {
    try {
      final refreshToken = await _credentials.readRefreshToken();
      _accessToken = null;
      _accessTokenExpiry = null;
      if (refreshToken != null) {
        try {
          await _authorized(
            'POST',
            '/api/v1/auth/logout',
            body: {'refreshToken': refreshToken},
          );
        } on SyncApiException {
          // Already revoked, or unreachable. Either way the local session goes.
        }
      }
    } finally {
      await _forgetSession();
    }
  }

  /// Backend D19: deletes the signed-in account and everything the server holds
  /// for it, confirmed with the current password. The body carries nothing else:
  /// the account is always the bearer token's. Only a 204 is success, and only
  /// then is the session forgotten here - the server no longer has it. A wrong
  /// password is a 403, so it never triggers the 401 refresh-and-replay below.
  Future<void> deleteAccount(String password) async {
    final response = await _authorized(
      'POST',
      '/api/v1/account/delete',
      body: {'password': password},
    );
    if (response.status != 204) {
      throw SyncApiException(response.status, 'Account deletion was refused.');
    }
    await _forgetSession();
  }

  Future<void> _forgetSession() async {
    _accessToken = null;
    _accessTokenExpiry = null;
    _sessionRefreshToken = null;
    await _credentials.clear();
  }

  /// The signed-in account's server id: the `sub` of the current access token,
  /// fetched or refreshed as needed. Read locally, not verified - the token came
  /// from the server over TLS and the value only labels local upload progress.
  Future<String> accountId() async {
    final payload = (await _validAccessToken()).split('.')[1];
    final claims = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(payload))),
    );
    return (claims as Map<String, Object?>)['sub']! as String;
  }

  // --- devices --------------------------------------------------------------

  /// Idempotent on [deviceId]: 201 the first time, 200 afterwards. A 409 means
  /// the installation UUID belongs to another account and this one must be
  /// regenerated, which is why the status is preserved in the exception.
  Future<void> registerDevice({
    required String deviceId,
    required String displayName,
    required String platform,
  }) async {
    final response = await _authorized(
      'POST',
      '/api/v1/devices',
      body: {
        'deviceId': deviceId,
        'displayName': displayName,
        'platform': platform,
      },
    );
    if (response.status != 200 && response.status != 201) {
      throw SyncApiException(
        response.status,
        'Device registration was refused.',
      );
    }
  }

  // --- usage ----------------------------------------------------------------

  Future<List<SyncUploadResult>> uploadDays(
    String deviceId,
    List<SyncUsageDay> days,
  ) async {
    final response = await _authorized(
      'PUT',
      '/api/v1/sync/usage-days',
      body: {
        'deviceId': deviceId,
        'days': [for (final day in days) day.toJson()],
      },
    );
    if (response.status != 200) {
      throw SyncApiException(response.status, 'Usage upload was refused.');
    }
    return [
      for (final result
          in (response.json['results']! as List).cast<Map<String, Object?>>())
        SyncUploadResult.fromJson(result),
    ];
  }

  /// [from] inclusive, [to] exclusive, at most 400 days (architecture 9.3).
  Future<List<RemoteUsageDay>> readHistory({
    required DateTime from,
    required DateTime to,
    String? deviceId,
  }) async {
    final response = await _authorized(
      'GET',
      '/api/v1/usage',
      query: {
        'from': _dayKey(from),
        'to': _dayKey(to),
        if (deviceId != null) 'deviceId': deviceId,
      },
    );
    if (response.status != 200) {
      throw SyncApiException(response.status, 'Usage history was refused.');
    }
    return [
      for (final day
          in (response.json['days']! as List).cast<Map<String, Object?>>())
        RemoteUsageDay.fromJson(day),
    ];
  }

  static String _dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  // --- token lifecycle --------------------------------------------------------

  Future<_Response> _authorized(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    var response = await _send(
      method,
      path,
      body: body,
      query: query,
      bearer: await _validAccessToken(),
    );
    if (response.status == 401) {
      // The token may have expired between the margin check and the server.
      // One coordinated refresh, then one replay. Never a loop.
      response = await _send(
        method,
        path,
        body: body,
        query: query,
        bearer: await _refreshAccessToken(),
      );
    }
    return response;
  }

  Future<String> _validAccessToken() {
    final token = _accessToken;
    final expiry = _accessTokenExpiry;
    if (token != null &&
        expiry != null &&
        expiry.isAfter(_now().add(_clockMargin))) {
      return Future<String>.value(token);
    }
    return _refreshAccessToken();
  }

  Future<String> _refreshAccessToken() {
    return _refreshing ??= _rotate().whenComplete(() => _refreshing = null);
  }

  Future<String> _rotate() async {
    final refreshToken = await _credentials.readRefreshToken();
    if (refreshToken == null) {
      throw const SyncApiException(401, 'Not signed in.');
    }
    final response = await _send(
      'POST',
      '/api/v1/auth/refresh',
      body: {'refreshToken': refreshToken},
    );
    if (response.status != 200) {
      if (response.status == 401) {
        // Expired, rotated away or revoked by replay detection. Signing in
        // again is the only recovery, so stop presenting a dead token.
        await _credentials.clear();
      }
      throw SyncApiException(response.status, 'Session refresh failed.');
    }
    return _adoptSession(response.json);
  }

  /// Persists the rotated refresh token before returning, so a crash right
  /// after this cannot leave the app holding a token the server has retired.
  Future<String> _adoptSession(Map<String, Object?> session) async {
    final accessToken = session['accessToken']! as String;
    final expiresIn = (session['expiresIn']! as num).toInt();
    await _credentials.writeRefreshToken(session['refreshToken']! as String);
    _sessionRefreshToken = session['refreshToken']! as String;
    _accessToken = accessToken;
    _accessTokenExpiry = _now().add(Duration(seconds: expiresIn));
    return accessToken;
  }

  // --- transport ----------------------------------------------------------------

  Future<_Response> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    String? bearer,
  }) async {
    final uri = _baseUrl.replace(
      path: path,
      queryParameters: query?.isEmpty ?? true ? null : query,
    );
    try {
      final request = await _client.openUrl(method, uri).timeout(_timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (bearer != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearer');
      }
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.add(utf8.encode(jsonEncode(body)));
      }
      final response = await request.close().timeout(_timeout);
      final text = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout);
      return _Response(response.statusCode, text);
    } on Object catch (error) {
      // Offline, DNS, TLS, timeout: the request never got an answer. Only the
      // error's type is carried; its message can quote a URL, and a URL is the
      // one place a credential could plausibly have been put.
      throw SyncApiException(
        0,
        'The sync service could not be reached (${error.runtimeType}).',
      );
    }
  }
}

class _Response {
  _Response(this.status, this.body);

  final int status;
  final String body;

  Map<String, Object?> get json => jsonDecode(body) as Map<String, Object?>;
}
