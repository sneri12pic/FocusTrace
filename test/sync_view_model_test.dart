import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';

/// The account section's state machine against a fake repository.
///
/// The repository contract is already proven against a real HTTP server in
/// `sync_repository_test.dart` and against the real backend in
/// `sync_end_to_end_test.dart`; what is tested here is what the UI does with
/// it, including the cases those suites cannot reach - a second tap while a
/// run is in flight, and the state left after a restart.
void main() {
  late _FakeSyncRepository repository;
  late SyncViewModel viewModel;

  setUp(() {
    repository = _FakeSyncRepository();
    viewModel = SyncViewModel(repository);
  });

  tearDown(() => viewModel.dispose());

  group('signed out', () {
    test('starts signed out with sync off and nothing synced', () async {
      await viewModel.load();

      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.isSignedIn, isFalse);
      expect(viewModel.state.syncEnabled, isFalse);
      expect(viewModel.state.lastSuccessAt, isNull);
      expect(viewModel.state.canSyncNow, isFalse);
    });

    test('sync stays off until the user opts in', () async {
      await viewModel.load();

      // Nothing may sync on behalf of a signed-out installation.
      await viewModel.syncNow();

      expect(repository.syncRuns, 0);
      expect(viewModel.state.phase, SyncPhase.idle);
    });
  });

  group('delete account', () {
    Future<void> signedInAndSyncing() async {
      await viewModel.signIn(email: 'a@example.com', password: 'pw');
      await viewModel.setSyncEnabled(true);
    }

    test('success ends signed out with sync off and says so', () async {
      await signedInAndSyncing();

      await viewModel.deleteAccount('current-password');

      expect(repository.deletedWith, 'current-password');
      expect(viewModel.state.isSignedIn, isFalse);
      expect(viewModel.state.syncEnabled, isFalse);
      expect(viewModel.state.accountEmail, isNull);
      expect(viewModel.state.accountDeleted, isTrue);
      expect(viewModel.state.error, isNull);
      expect(viewModel.state.isAuthenticating, isFalse);
    });

    test('a wrong password keeps the account and reports it as such', () async {
      await signedInAndSyncing();
      repository.deleteFailure = SyncAuthFailure.invalidCredentials;

      await viewModel.deleteAccount('wrong');

      expect(viewModel.state.error, SyncErrorKind.wrongPassword);
      expect(viewModel.state.isSignedIn, isTrue);
      expect(viewModel.state.syncEnabled, isTrue);
      expect(viewModel.state.accountEmail, 'a@example.com');
      expect(viewModel.state.accountDeleted, isFalse);
    });

    test('offline keeps the account so the user can retry', () async {
      await signedInAndSyncing();
      repository.deleteFailure = SyncAuthFailure.offline;

      await viewModel.deleteAccount('current-password');

      expect(viewModel.state.error, SyncErrorKind.offline);
      expect(viewModel.state.isSignedIn, isTrue);
      expect(viewModel.state.syncEnabled, isTrue);
    });

    test('a rejected session signs out without claiming deletion', () async {
      await signedInAndSyncing();
      repository.deleteFailure = SyncAuthFailure.sessionExpired;

      await viewModel.deleteAccount('current-password');

      expect(viewModel.state.error, SyncErrorKind.sessionExpired);
      expect(viewModel.state.isSignedIn, isFalse);
      expect(viewModel.state.accountDeleted, isFalse);
    });

    test('is ignored while a sync is in flight', () async {
      await signedInAndSyncing();
      repository.hold();
      final run = viewModel.syncNow();

      await viewModel.deleteAccount('current-password');
      repository.release();
      await run;

      expect(repository.deletedWith, isNull);
      expect(viewModel.state.isSignedIn, isTrue);
    });

    test('a later sign-in clears the deletion notice', () async {
      await signedInAndSyncing();
      await viewModel.deleteAccount('current-password');

      await viewModel.signIn(email: 'b@example.com', password: 'pw');

      expect(viewModel.state.accountDeleted, isFalse);
      expect(viewModel.state.accountEmail, 'b@example.com');
    });
  });

  group('sign in', () {
    test('a successful sign-in restores the account', () async {
      await viewModel.load();

      await viewModel.signIn(email: 'a@example.com', password: 'pw');

      expect(viewModel.state.isSignedIn, isTrue);
      expect(viewModel.state.accountEmail, 'a@example.com');
      expect(viewModel.state.error, isNull);
      expect(viewModel.state.isAuthenticating, isFalse);
      // Opting in is still a separate, explicit act.
      expect(viewModel.state.syncEnabled, isFalse);
    });

    test('rejected credentials leave the app signed out', () async {
      repository.authFailure = SyncAuthFailure.invalidCredentials;
      await viewModel.load();

      await viewModel.signIn(email: 'a@example.com', password: 'wrong');

      expect(viewModel.state.isSignedIn, isFalse);
      expect(viewModel.state.error, SyncErrorKind.invalidCredentials);
      expect(viewModel.state.isAuthenticating, isFalse);
    });

    test('an unreachable service is reported as offline', () async {
      repository.authFailure = SyncAuthFailure.offline;
      await viewModel.load();

      await viewModel.signIn(email: 'a@example.com', password: 'pw');

      expect(viewModel.state.error, SyncErrorKind.offline);
      expect(viewModel.state.isSignedIn, isFalse);
    });

    test('creating an account signs in and records the email', () async {
      await viewModel.load();

      await viewModel.createAccount(email: 'new@example.com', password: 'pw');

      expect(repository.registered, isTrue);
      expect(viewModel.state.isSignedIn, isTrue);
      expect(viewModel.state.accountEmail, 'new@example.com');
    });

    test('a taken email is reported as such', () async {
      repository.authFailure = SyncAuthFailure.emailTaken;
      await viewModel.load();

      await viewModel.createAccount(email: 'taken@example.com', password: 'pw');

      expect(viewModel.state.error, SyncErrorKind.emailTaken);
    });
  });

  group('persisted session', () {
    test('a restart restores the signed-in account and its opt-in', () async {
      repository
        ..signedIn = true
        ..email = 'a@example.com'
        ..enabled = true
        ..lastSuccess = DateTime.utc(2026, 9, 20, 10);

      // A brand new view model over the same repository: what a cold start has.
      final afterRestart = SyncViewModel(repository);
      addTearDown(afterRestart.dispose);
      await afterRestart.load();

      expect(afterRestart.state.isSignedIn, isTrue);
      expect(afterRestart.state.accountEmail, 'a@example.com');
      expect(afterRestart.state.syncEnabled, isTrue);
      expect(afterRestart.state.lastSuccessAt, DateTime.utc(2026, 9, 20, 10));
      expect(afterRestart.state.canSyncNow, isTrue);
    });

    test(
      'a credential the keystore no longer has restores signed out',
      () async {
        // What a wiped keystore or a revoked session leaves behind.
        repository
          ..signedIn = false
          ..email = 'a@example.com'
          ..enabled = true;

        await viewModel.load();

        expect(viewModel.state.isSignedIn, isFalse);
        expect(viewModel.state.accountEmail, isNull);
        expect(viewModel.state.syncEnabled, isFalse);
        expect(viewModel.state.canSyncNow, isFalse);
      },
    );
  });

  group('opt in and out', () {
    setUp(() async {
      repository.signedIn = true;
      await viewModel.load();
    });

    test('turning sync on is what makes a manual run possible', () async {
      expect(viewModel.state.canSyncNow, isFalse);

      await viewModel.setSyncEnabled(true);

      expect(viewModel.state.syncEnabled, isTrue);
      expect(repository.enabled, isTrue);
      expect(viewModel.state.canSyncNow, isTrue);
    });

    test(
      'turning it off stops syncing without signing out or deleting',
      () async {
        await viewModel.setSyncEnabled(true);
        await viewModel.syncNow();
        final runsWhileOn = repository.syncRuns;

        await viewModel.setSyncEnabled(false);
        await viewModel.syncNow();

        expect(repository.syncRuns, runsWhileOn, reason: 'no further uploads');
        expect(repository.enabled, isFalse);
        // The account and the server's copy are both untouched.
        expect(viewModel.state.isSignedIn, isTrue);
        expect(repository.signedOut, isFalse);
        expect(viewModel.state.lastSuccessAt, isNotNull);
      },
    );
  });

  group('sync now', () {
    setUp(() async {
      repository.signedIn = true;
      await viewModel.load();
      await viewModel.setSyncEnabled(true);
    });

    test('a successful run ends in success with a new timestamp', () async {
      expect(viewModel.state.lastSuccessAt, isNull);

      await viewModel.syncNow();

      expect(repository.syncRuns, 1);
      expect(viewModel.state.phase, SyncPhase.success);
      expect(viewModel.state.lastSuccessAt, isNotNull);
      expect(viewModel.state.error, isNull);
    });

    test(
      'a failed run reports a useful reason and keeps the account',
      () async {
        repository.syncFailure = SyncFailureReason.offline;

        await viewModel.syncNow();

        expect(viewModel.state.phase, SyncPhase.error);
        expect(viewModel.state.error, SyncErrorKind.offline);
        expect(viewModel.state.isSignedIn, isTrue);
        expect(viewModel.state.lastSuccessAt, isNull);
      },
    );

    test('a rejected session returns the app to signed out', () async {
      repository.syncFailure = SyncFailureReason.sessionExpired;

      await viewModel.syncNow();

      expect(viewModel.state.phase, SyncPhase.error);
      expect(viewModel.state.error, SyncErrorKind.sessionExpired);
      // Failing closed: the credential is gone, so the UI must not claim a
      // session it no longer has.
      expect(viewModel.state.isSignedIn, isFalse);
      expect(viewModel.state.syncEnabled, isFalse);
      expect(viewModel.state.accountEmail, isNull);
    });

    test('a second tap during a run is ignored, not queued', () async {
      repository.hold();

      final first = viewModel.syncNow();
      expect(viewModel.state.isSyncing, isTrue);
      // Two runs at once would present the same refresh token twice.
      await viewModel.syncNow();
      await viewModel.syncNow();
      repository.release();
      await first;

      expect(repository.syncRuns, 1);
      expect(repository.maxConcurrentRuns, 1);
      expect(viewModel.state.phase, SyncPhase.success);
    });
  });

  group('sign out', () {
    test('clears the session, the opt-in and the account', () async {
      repository
        ..signedIn = true
        ..email = 'a@example.com'
        ..enabled = true;
      await viewModel.load();

      await viewModel.signOut();

      expect(repository.signedOut, isTrue);
      expect(viewModel.state.isSignedIn, isFalse);
      expect(viewModel.state.accountEmail, isNull);
      expect(viewModel.state.syncEnabled, isFalse);
      expect(viewModel.state.phase, SyncPhase.idle);
    });

    test('still ends signed out when the server cannot be reached', () async {
      repository
        ..signedIn = true
        ..signOutThrows = true;
      await viewModel.load();

      await viewModel.signOut();

      expect(viewModel.state.isSignedIn, isFalse);
    });

    test('a restart after signing out is signed out', () async {
      repository
        ..signedIn = true
        ..email = 'a@example.com'
        ..enabled = true;
      await viewModel.load();
      await viewModel.signOut();

      final afterRestart = SyncViewModel(repository);
      addTearDown(afterRestart.dispose);
      await afterRestart.load();

      expect(afterRestart.state.isSignedIn, isFalse);
      expect(afterRestart.state.accountEmail, isNull);
      expect(afterRestart.state.syncEnabled, isFalse);
    });
  });
}

/// Stands in for `SyncRepositoryImpl`, keeping the same observable rules:
/// signing in records the email, signing out clears the session and the opt-in,
/// and a successful run stamps the clock.
class _FakeSyncRepository implements SyncRepository {
  bool signedIn = false;
  String? email;
  bool enabled = false;
  DateTime? lastSuccess;

  bool registered = false;
  bool signedOut = false;
  bool signOutThrows = false;
  SyncAuthFailure? authFailure;
  SyncFailureReason? syncFailure;
  SyncAuthFailure? deleteFailure;
  String? deletedWith;

  int syncRuns = 0;
  int _activeRuns = 0;
  int maxConcurrentRuns = 0;
  Future<void>? _gate;
  void Function()? _openGate;

  /// Makes the next [syncNow] block until [release], so a second call can be
  /// made while the first is genuinely in flight.
  void hold() {
    final completer = Completer<void>();
    _gate = completer.future;
    _openGate = () => completer.complete();
  }

  void release() => _openGate?.call();

  @override
  Future<bool> get isSignedIn async => signedIn;

  @override
  Future<String?> accountEmail() async => email;

  @override
  Future<bool> isSyncEnabled() async => enabled;

  @override
  Future<void> setSyncEnabled(bool value) async => enabled = value;

  @override
  Future<DateTime?> lastSuccessfulSyncAt() async => lastSuccess;

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (authFailure != null) {
      throw SyncAuthException(authFailure!);
    }
    signedIn = true;
    this.email = email;
  }

  @override
  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    if (authFailure != null) {
      throw SyncAuthException(authFailure!);
    }
    registered = true;
    signedIn = true;
    this.email = email;
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
    signedIn = false;
    email = null;
    enabled = false;
    if (signOutThrows) {
      throw const SyncAuthException(SyncAuthFailure.offline);
    }
  }

  @override
  Future<SyncRunResult> syncNow({bool requireEnabled = false}) async {
    _activeRuns++;
    maxConcurrentRuns = _activeRuns > maxConcurrentRuns
        ? _activeRuns
        : maxConcurrentRuns;
    try {
      final gate = _gate;
      if (gate != null) {
        _gate = null;
        await gate;
      }
      syncRuns++;
      if (syncFailure != null) {
        return SyncRunResult.failed('failed', syncFailure!);
      }
      lastSuccess = DateTime.utc(2026, 9, 20, 12);
      return const SyncRunResult(
        uploadedDays: 1,
        results: <SyncUploadResult>[],
        rejectedDays: 0,
      );
    } finally {
      _activeRuns--;
    }
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    deletedWith = password;
    if (deleteFailure != null) {
      throw SyncAuthException(deleteFailure!);
    }
    signedIn = false;
    email = null;
    enabled = false;
  }

  @override
  Future<String> installationId() async => 'installation';

  @override
  Future<List<RemoteUsageDay>> readRemoteHistory({
    required DateTime from,
    required DateTime to,
    String? deviceId,
  }) async => const <RemoteUsageDay>[];
}
