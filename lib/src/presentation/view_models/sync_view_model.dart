import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/sync_usage.dart';
import '../../domain/repositories/sync_repository.dart';

/// What the account section is doing right now.
enum SyncPhase { idle, syncing, success, error }

/// Why the last action failed, in terms a screen can translate.
///
/// Distinct from [SyncFailureReason] because sign-in can fail in ways a sync
/// run cannot, and vice versa. No status code, server text, token or exception
/// string ever reaches this type.
enum SyncErrorKind {
  offline,
  invalidCredentials,
  invalidRegistration,
  invalidEmail,
  passwordRejected,
  accountCreatedSignInRequired,
  emailTaken,
  weakPassword,
  throttled,
  sessionExpired,
  refused,

  /// Account deletion: the confirmation password was wrong.
  wrongPassword,
  unknown,
}

class SyncState {
  const SyncState({
    this.isLoading = true,
    this.isSignedIn = false,
    this.accountEmail,
    this.syncEnabled = false,
    this.phase = SyncPhase.idle,
    this.lastSuccessAt,
    this.error,
    this.isAuthenticating = false,
    this.accountDeleted = false,
  });

  final bool isLoading;
  final bool isSignedIn;
  final String? accountEmail;
  final bool syncEnabled;
  final SyncPhase phase;
  final DateTime? lastSuccessAt;
  final SyncErrorKind? error;

  /// Sign-in, account creation, sign-out or account deletion is in flight.
  final bool isAuthenticating;

  /// The account was just deleted, so the signed-out form can say so.
  final bool accountDeleted;

  bool get isSyncing => phase == SyncPhase.syncing;

  /// Manual sync is an opt-in action too: with the switch off nothing leaves
  /// the device, by hand or otherwise.
  bool get canSyncNow => isSignedIn && syncEnabled && !isSyncing;

  SyncState copyWith({
    bool? isLoading,
    bool? isSignedIn,
    String? accountEmail,
    bool? syncEnabled,
    SyncPhase? phase,
    DateTime? lastSuccessAt,
    SyncErrorKind? error,
    bool? isAuthenticating,
    bool? accountDeleted,
    bool clearError = false,
    bool clearAccountEmail = false,
    bool clearLastSuccess = false,
  }) {
    return SyncState(
      isLoading: isLoading ?? this.isLoading,
      isSignedIn: isSignedIn ?? this.isSignedIn,
      accountEmail: clearAccountEmail
          ? null
          : accountEmail ?? this.accountEmail,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      phase: phase ?? this.phase,
      lastSuccessAt: clearLastSuccess
          ? null
          : lastSuccessAt ?? this.lastSuccessAt,
      error: clearError ? null : error ?? this.error,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      accountDeleted: accountDeleted ?? this.accountDeleted,
    );
  }
}

/// Account and sync controls.
///
/// The only thing in FocusTrace that asks the sync repository to do anything.
/// It holds no credential of its own: the password is a method argument that is
/// never stored, and whether a session exists is always re-read from the
/// repository, which reads the OS keystore.
class SyncViewModel extends StateNotifier<SyncState> {
  SyncViewModel(this._repository) : super(const SyncState());

  final SyncRepository _repository;

  /// Restores the signed-in state after a restart. The session comes from the
  /// keystore, so a revoked or unreadable credential lands here as signed out.
  Future<void> load() async {
    final signedIn = await _repository.isSignedIn;
    state = state.copyWith(
      isLoading: false,
      isSignedIn: signedIn,
      accountEmail: signedIn ? await _repository.accountEmail() : null,
      clearAccountEmail: !signedIn,
      syncEnabled: signedIn && await _repository.isSyncEnabled(),
      lastSuccessAt: await _repository.lastSuccessfulSyncAt(),
    );
  }

  Future<void> signIn({required String email, required String password}) =>
      _authenticate(() => _repository.signIn(email: email, password: password));

  Future<void> createAccount({
    required String email,
    required String password,
  }) => _authenticate(
    () => _repository.createAccount(email: email, password: password),
  );

  Future<void> _authenticate(Future<void> Function() action) async {
    if (state.isAuthenticating) {
      return;
    }
    state = state.copyWith(
      isAuthenticating: true,
      accountDeleted: false,
      clearError: true,
    );
    try {
      await action();
    } on SyncAuthException catch (error) {
      state = state.copyWith(
        isAuthenticating: false,
        error: _authErrorFor(error.failure),
      );
      return;
    } on Object {
      state = state.copyWith(
        isAuthenticating: false,
        error: SyncErrorKind.unknown,
      );
      return;
    }
    state = state.copyWith(isAuthenticating: false);
    await load();
  }

  /// The form was edited, so the last failure no longer describes it.
  void clearError() {
    if (state.error != null && !state.isAuthenticating) {
      state = state.copyWith(clearError: true);
    }
  }

  /// Signing out always ends signed out locally, even if the server could not
  /// be reached: the repository clears the credential either way.
  Future<void> signOut() async {
    if (state.isAuthenticating) {
      return;
    }
    state = state.copyWith(isAuthenticating: true, clearError: true);
    try {
      await _repository.signOut();
    } on Object {
      // The credential is gone regardless; there is nothing useful to say.
    }
    state = const SyncState(isLoading: false);
  }

  /// Permanent. The password is only passed through, never kept. Success ends
  /// signed out with sync off; any other outcome leaves the account signed in and
  /// untouched, except a rejected session, which is signed out like a failed sync.
  Future<void> deleteAccount(String password) async {
    if (state.isAuthenticating || state.isSyncing) {
      return;
    }
    state = state.copyWith(isAuthenticating: true, clearError: true);
    try {
      await _repository.deleteAccount(password: password);
    } on SyncAuthException catch (error) {
      final kind = error.failure == SyncAuthFailure.invalidCredentials
          ? SyncErrorKind.wrongPassword
          : _authErrorFor(error.failure);
      state = state.copyWith(isAuthenticating: false, error: kind);
      if (kind == SyncErrorKind.sessionExpired) {
        state = state.copyWith(
          isSignedIn: false,
          syncEnabled: false,
          clearAccountEmail: true,
        );
      }
      return;
    } on Object {
      state = state.copyWith(
        isAuthenticating: false,
        error: SyncErrorKind.unknown,
      );
      return;
    }
    state = const SyncState(isLoading: false, accountDeleted: true);
  }

  /// Off does not delete anything the server already holds, and does not sign
  /// the account out. It only stops this device sending more.
  Future<void> setSyncEnabled(bool enabled) async {
    if (!state.isSignedIn) {
      return;
    }
    await _repository.setSyncEnabled(enabled);
    state = state.copyWith(
      syncEnabled: enabled,
      phase: SyncPhase.idle,
      clearError: true,
    );
  }

  Future<void> syncNow() async {
    // A second tap while a run is in flight is ignored rather than queued.
    // Two concurrent runs would race the refresh-token rotation.
    if (!state.canSyncNow) {
      return;
    }
    state = state.copyWith(phase: SyncPhase.syncing, clearError: true);
    final result = await _repository.syncNow();
    if (result.succeeded) {
      state = state.copyWith(
        phase: SyncPhase.success,
        lastSuccessAt: await _repository.lastSuccessfulSyncAt(),
        clearError: true,
      );
      return;
    }
    final kind = _syncErrorFor(result.reason);
    state = state.copyWith(phase: SyncPhase.error, error: kind);
    if (kind == SyncErrorKind.sessionExpired) {
      // The refresh token was rejected and the store has already cleared it,
      // so the app must stop presenting itself as signed in.
      state = state.copyWith(
        isSignedIn: false,
        syncEnabled: false,
        clearAccountEmail: true,
      );
    }
  }

  static SyncErrorKind _authErrorFor(SyncAuthFailure failure) {
    return switch (failure) {
      SyncAuthFailure.offline => SyncErrorKind.offline,
      SyncAuthFailure.invalidCredentials => SyncErrorKind.invalidCredentials,
      SyncAuthFailure.invalidRegistration => SyncErrorKind.invalidRegistration,
      SyncAuthFailure.invalidEmail => SyncErrorKind.invalidEmail,
      SyncAuthFailure.passwordRejected => SyncErrorKind.passwordRejected,
      SyncAuthFailure.throttled => SyncErrorKind.throttled,
      SyncAuthFailure.accountCreatedSignInRequired =>
        SyncErrorKind.accountCreatedSignInRequired,
      SyncAuthFailure.emailTaken => SyncErrorKind.emailTaken,
      SyncAuthFailure.weakPassword => SyncErrorKind.weakPassword,
      SyncAuthFailure.sessionExpired => SyncErrorKind.sessionExpired,
      SyncAuthFailure.unknown => SyncErrorKind.unknown,
    };
  }

  static SyncErrorKind _syncErrorFor(SyncFailureReason? reason) {
    return switch (reason) {
      SyncFailureReason.offline => SyncErrorKind.offline,
      SyncFailureReason.sessionExpired ||
      SyncFailureReason.notSignedIn => SyncErrorKind.sessionExpired,
      SyncFailureReason.refused => SyncErrorKind.refused,
      _ => SyncErrorKind.unknown,
    };
  }
}
