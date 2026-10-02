import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/app_localizations_x.dart';
import '../providers.dart';
import '../view_models/sync_view_model.dart';

/// Account and sync controls for the settings screen.
///
/// Only built when `syncSupportedProvider` is true, so a build without a sync
/// base URL shows nothing and behaves exactly as it did before.
class SyncAccountCard extends ConsumerStatefulWidget {
  const SyncAccountCard({super.key});

  @override
  ConsumerState<SyncAccountCard> createState() => _SyncAccountCardState();
}

enum _AuthMode { signIn, createAccount }

class _SyncAccountCardState extends ConsumerState<SyncAccountCard> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  /// Registration only. Compared exactly, never sent, cleared with [_password].
  final _repeat = TextEditingController();
  final _repeatFocus = FocusNode();

  // Form state, not account state, so it stays out of [SyncState].
  var _mode = _AuthMode.signIn;

  /// Local validation shows only after the first submit, then updates live.
  bool _submitted = false;
  bool _showPassword = false;
  bool _showRepeat = false;

  /// This card created the account now signed in; drives the success panel.
  bool _accountCreated = false;

  /// Mirrors the server's D02 bounds. Server validation stays authoritative:
  /// it counts code points after NFC, which this approximates with runes.
  static const _minPasswordLength = 15;
  static const _maxPasswordLength = 128;

  bool get _creating => _mode == _AuthMode.createAccount;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    _repeat.dispose();
    _repeatFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(syncViewModelProvider);
    final l10n = context.l10n;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.settingsSyncTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(l10n.settingsSyncBody),
            const SizedBox(height: 16),
            if (state.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (state.isSignedIn) ...[
              ..._signedIn(context, state),
              if (state.error != null) ...[
                const SizedBox(height: 8),
                _error(context, _errorText(context, state.error!)),
              ],
            ] else
              ..._signedOut(context, state),
          ],
        ),
      ),
    );
  }

  List<Widget> _signedOut(BuildContext context, SyncState state) {
    final l10n = context.l10n;
    final busy = state.isAuthenticating;
    final error = state.error;
    final notice = _formNotice(context, error);
    return [
      if (state.accountDeleted) ...[
        _Notice(
          key: const ValueKey('sync-account-deleted'),
          tone: _Tone.info,
          message: l10n.settingsSyncDeleted,
        ),
        const SizedBox(height: 16),
      ],
      Semantics(
        header: true,
        child: Text(
          key: const ValueKey('sync-form-heading'),
          _creating
              ? l10n.settingsSyncCreateHeading
              : l10n.settingsSyncSignInHeading,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      const SizedBox(height: 12),
      AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('sync-email-field'),
              controller: _email,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.email,
                AutofillHints.username,
              ],
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) => _edited(),
              onSubmitted: (_) => _passwordFocus.requestFocus(),
              decoration: InputDecoration(
                labelText: l10n.settingsSyncEmail,
                prefixIcon: const Icon(Icons.mail_outline),
                errorText: _emailError(context, error),
                errorMaxLines: 3,
                border: const OutlineInputBorder(),
              ),
            ),
            if (error == SyncErrorKind.emailTaken)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const ValueKey('sync-sign-in-instead-button'),
                  onPressed: busy ? null : () => _switchMode(_AuthMode.signIn),
                  child: Text(l10n.settingsSyncSignInInstead),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('sync-password-field'),
              controller: _password,
              focusNode: _passwordFocus,
              enabled: !busy,
              obscureText: !_showPassword,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: _creating
                  ? TextInputAction.next
                  : TextInputAction.done,
              // newPassword lets a password manager offer to generate one.
              autofillHints: [
                _creating ? AutofillHints.newPassword : AutofillHints.password,
              ],
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) => _edited(),
              onSubmitted: (_) =>
                  _creating ? _repeatFocus.requestFocus() : _submit(),
              decoration: InputDecoration(
                labelText: l10n.settingsSyncPassword,
                prefixIcon: const Icon(Icons.lock_outline),
                helperText: _creating
                    ? l10n.settingsSyncPasswordRequirements
                    : null,
                helperMaxLines: 4,
                errorText: _passwordError(context, error),
                errorMaxLines: 4,
                suffixIcon: IconButton(
                  key: const ValueKey('sync-show-password-button'),
                  tooltip: _showPassword
                      ? l10n.settingsSyncHidePassword
                      : l10n.settingsSyncShowPassword,
                  onPressed: busy
                      ? null
                      : () => setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            if (_creating) ...[
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('sync-repeat-password-field'),
                controller: _repeat,
                focusNode: _repeatFocus,
                enabled: !busy,
                obscureText: !_showRepeat,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
                // Same hint as the first field, so a generated password can
                // fill both.
                autofillHints: const [AutofillHints.newPassword],
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => _edited(),
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: l10n.settingsSyncRepeatPassword,
                  prefixIcon: const Icon(Icons.lock_outline),
                  errorText: _repeatError(context),
                  errorMaxLines: 3,
                  suffixIcon: IconButton(
                    key: const ValueKey('sync-show-repeat-password-button'),
                    tooltip: _showRepeat
                        ? l10n.settingsSyncHideRepeatPassword
                        : l10n.settingsSyncShowRepeatPassword,
                    onPressed: busy
                        ? null
                        : () => setState(() => _showRepeat = !_showRepeat),
                    icon: Icon(
                      _showRepeat
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      if (notice != null) ...[const SizedBox(height: 16), notice],
      const SizedBox(height: 20),
      FilledButton(
        key: const ValueKey('sync-submit-button'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: busy ? null : _submit,
        child: busy
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      _creating
                          ? l10n.settingsSyncCreatingAccount
                          : l10n.settingsSyncSigningIn,
                    ),
                  ),
                ],
              )
            : Text(
                _creating
                    ? l10n.settingsSyncCreateAccount
                    : l10n.settingsSyncSignIn,
              ),
      ),
      const SizedBox(height: 8),
      TextButton(
        key: const ValueKey('sync-mode-switch'),
        style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: busy
            ? null
            : () => _switchMode(
                _creating ? _AuthMode.signIn : _AuthMode.createAccount,
              ),
        child: Text(
          _creating
              ? l10n.settingsSyncSwitchToSignIn
              : l10n.settingsSyncSwitchToCreate,
          textAlign: TextAlign.center,
        ),
      ),
    ];
  }

  List<Widget> _signedIn(BuildContext context, SyncState state) {
    final l10n = context.l10n;
    return [
      if (_accountCreated) ...[
        _Notice(
          key: const ValueKey('sync-account-created'),
          tone: _Tone.success,
          title: l10n.settingsSyncAccountCreated,
          message: [
            l10n.settingsSyncSignedInAs(state.accountEmail ?? ''),
            if (!state.syncEnabled) l10n.settingsSyncCreatedNextStep,
          ].join('\n'),
          // The next step is offered, never taken: sync stays opt-in.
          action: state.syncEnabled
              ? null
              : FilledButton.tonal(
                  key: const ValueKey('sync-turn-on-button'),
                  onPressed: () => ref
                      .read(syncViewModelProvider.notifier)
                      .setSyncEnabled(true),
                  child: Text(l10n.settingsSyncTurnOnSync),
                ),
        ),
        const SizedBox(height: 8),
      ],
      ListTile(
        key: const ValueKey('sync-account-tile'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.account_circle_outlined),
        title: Text(state.accountEmail ?? ''),
        subtitle: Text(_lastSyncText(context, state)),
      ),
      SwitchListTile(
        key: const ValueKey('sync-enabled-switch'),
        contentPadding: EdgeInsets.zero,
        value: state.syncEnabled,
        title: Text(l10n.settingsSyncEnabledLabel),
        subtitle: Text(l10n.settingsSyncEnabledSubtitle),
        onChanged: state.isSyncing
            ? null
            : (value) => ref
                  .read(syncViewModelProvider.notifier)
                  .setSyncEnabled(value),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: FilledButton.tonal(
              key: const ValueKey('sync-now-button'),
              onPressed: state.canSyncNow
                  ? () => ref.read(syncViewModelProvider.notifier).syncNow()
                  : null,
              child: state.isSyncing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.settingsSyncNow),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('sync-sign-out-button'),
              onPressed: state.isAuthenticating || state.isSyncing
                  ? null
                  : () => ref.read(syncViewModelProvider.notifier).signOut(),
              child: Text(l10n.settingsSyncSignOut),
            ),
          ),
        ],
      ),
      if (state.phase != SyncPhase.idle) ...[
        const SizedBox(height: 8),
        Text(key: const ValueKey('sync-phase-label'), switch (state.phase) {
          SyncPhase.syncing => l10n.settingsSyncStateSyncing,
          SyncPhase.success => l10n.settingsSyncStateSuccess,
          SyncPhase.error => l10n.settingsSyncStateError,
          SyncPhase.idle => '',
        }),
      ],
      const SizedBox(height: 24),
      _dangerZone(context, state),
    ];
  }

  /// Set apart below everything routine, so it is never the button a thumb
  /// lands on by habit. It only opens the confirmation dialog.
  Widget _dangerZone(BuildContext context, SyncState state) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const ValueKey('sync-danger-zone'),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.error.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.settingsSyncDangerZone,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: scheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(l10n.settingsSyncDangerZoneBody),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                key: const ValueKey('sync-delete-account-button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.error,
                  side: BorderSide(color: scheme.error),
                  minimumSize: const Size(0, 48),
                ),
                onPressed: state.isAuthenticating || state.isSyncing
                    ? null
                    : _confirmDeletion,
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(l10n.settingsSyncDeleteAccount),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _edited() {
    // A server error describes what was submitted, not what is typed now.
    ref.read(syncViewModelProvider.notifier).clearError();
    // Registration rebuilds too: the mismatch hint follows typing.
    if (_submitted || _creating) {
      setState(() {});
    }
  }

  /// Keeps the email, which usually fits the other mode too. Leaving
  /// registration drops both passwords, so neither outlives that flow.
  void _switchMode(_AuthMode mode) {
    ref.read(syncViewModelProvider.notifier).clearError();
    setState(() {
      if (_creating && mode != _AuthMode.createAccount) {
        _clearPasswords();
      }
      _mode = mode;
      _submitted = false;
    });
  }

  void _clearPasswords() {
    _password.clear();
    _repeat.clear();
    _showPassword = false;
    _showRepeat = false;
  }

  /// Exact comparison, no trimming or normalisation: what is checked is
  /// exactly what is sent.
  bool get _passwordsMatch => _repeat.text == _password.text;

  /// Shown once submitted, or as soon as the repeat can no longer match.
  String? _repeatError(BuildContext context) {
    if (_passwordsMatch) {
      return null;
    }
    if (_submitted || !_password.text.startsWith(_repeat.text)) {
      return context.l10n.settingsSyncErrorPasswordMismatch;
    }
    return null;
  }

  String? _localEmailError(BuildContext context) {
    final email = _email.text.trim();
    if (email.isEmpty) {
      return context.l10n.settingsSyncErrorEmailRequired;
    }
    // Loose on purpose: the server owns the exact rule.
    if (_creating && !RegExp(r'^[^@\s]+@[^@\s]+$').hasMatch(email)) {
      return context.l10n.settingsSyncErrorEmailInvalid;
    }
    return null;
  }

  String? _localPasswordError(BuildContext context) {
    final length = _password.text.runes.length;
    if (length == 0) {
      return context.l10n.settingsSyncErrorPasswordRequired;
    }
    // Sign-in checks nothing else: a wrong password is the server's call.
    if (_creating && length < _minPasswordLength) {
      return context.l10n.settingsSyncErrorPasswordTooShort(length);
    }
    if (_creating && length > _maxPasswordLength) {
      return context.l10n.settingsSyncErrorPasswordTooLong;
    }
    return null;
  }

  String? _emailError(BuildContext context, SyncErrorKind? error) {
    return switch (error) {
      SyncErrorKind.invalidEmail => context.l10n.settingsSyncErrorEmailInvalid,
      SyncErrorKind.emailTaken => context.l10n.settingsSyncErrorEmailTaken,
      _ => _submitted ? _localEmailError(context) : null,
    };
  }

  String? _passwordError(BuildContext context, SyncErrorKind? error) {
    return switch (error) {
      SyncErrorKind.passwordRejected || SyncErrorKind.weakPassword =>
        context.l10n.settingsSyncErrorPasswordRejected,
      _ => _submitted ? _localPasswordError(context) : null,
    };
  }

  /// Failures that belong to no single field.
  Widget? _formNotice(BuildContext context, SyncErrorKind? error) {
    return switch (error) {
      null ||
      SyncErrorKind.invalidEmail ||
      SyncErrorKind.emailTaken ||
      SyncErrorKind.passwordRejected ||
      SyncErrorKind.weakPassword => null,
      SyncErrorKind.accountCreatedSignInRequired => _Notice(
        key: const ValueKey('sync-form-notice'),
        tone: _Tone.info,
        title: context.l10n.settingsSyncAccountCreated,
        message: context.l10n.settingsSyncAccountCreatedSignInRequired,
      ),
      _ => _Notice(
        key: const ValueKey('sync-form-notice'),
        tone: _Tone.error,
        message: _errorText(context, error),
      ),
    };
  }

  Future<void> _submit() async {
    if (ref.read(syncViewModelProvider).isAuthenticating) {
      return;
    }
    setState(() => _submitted = true);
    if (_localEmailError(context) != null ||
        _localPasswordError(context) != null ||
        (_creating && !_passwordsMatch)) {
      return;
    }
    final creating = _creating;
    final email = _email.text.trim();
    final password = _password.text;
    FocusScope.of(context).unfocus();
    setState(() => _accountCreated = false);
    final viewModel = ref.read(syncViewModelProvider.notifier);
    if (creating) {
      await viewModel.createAccount(email: email, password: password);
    } else {
      await viewModel.signIn(email: email, password: password);
    }
    if (!mounted) {
      return;
    }
    final after = ref.read(syncViewModelProvider);
    if (after.isSignedIn) {
      // Offer the credentials to the password manager while the fields still
      // hold them; then the password does not outlive the attempt.
      TextInput.finishAutofillContext();
      _email.clear();
      setState(() {
        _clearPasswords();
        _accountCreated = creating;
        _mode = _AuthMode.signIn;
        _submitted = false;
      });
      return;
    }
    // A finished registration attempt keeps neither password. A failed sign-in
    // keeps it, in memory only, so a typo in the email can be fixed without
    // retyping a 15+ character passphrase, unless it was itself the problem.
    if (creating) {
      setState(() {
        _clearPasswords();
        _submitted = false;
      });
    } else if (after.error == SyncErrorKind.passwordRejected) {
      _password.clear();
    }
    if (after.error == SyncErrorKind.accountCreatedSignInRequired) {
      setState(() => _mode = _AuthMode.signIn);
    }
  }

  /// The dialog does the deleting, so it can stay open with progress and a
  /// wrong-password error. Closing it without success changes nothing.
  Future<void> _confirmDeletion() async {
    await showDialog<void>(
      context: context,
      builder: (context) => const _DeleteAccountDialog(),
    );
    // A failure shown in the dialog should not linger on the card behind it.
    if (mounted && ref.read(syncViewModelProvider).isSignedIn) {
      ref.read(syncViewModelProvider.notifier).clearError();
    }
  }

  String _lastSyncText(BuildContext context, SyncState state) {
    final at = state.lastSuccessAt;
    if (at == null) {
      return context.l10n.settingsSyncNeverSynced;
    }
    final local = at.toLocal();
    final material = MaterialLocalizations.of(context);
    return '${material.formatShortDate(local)} '
        '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  static String _errorText(BuildContext context, SyncErrorKind kind) {
    final l10n = context.l10n;
    return switch (kind) {
      SyncErrorKind.offline => l10n.settingsSyncErrorOffline,
      SyncErrorKind.invalidCredentials => l10n.settingsSyncErrorCredentials,
      SyncErrorKind.invalidRegistration => l10n.settingsSyncErrorRegistration,
      SyncErrorKind.invalidEmail => l10n.settingsSyncErrorEmailInvalid,
      SyncErrorKind.passwordRejected => l10n.settingsSyncErrorPasswordRejected,
      SyncErrorKind.accountCreatedSignInRequired =>
        l10n.settingsSyncAccountCreatedSignInRequired,
      SyncErrorKind.emailTaken => l10n.settingsSyncErrorEmailTaken,
      SyncErrorKind.weakPassword => l10n.settingsSyncErrorWeakPassword,
      SyncErrorKind.throttled => l10n.settingsSyncErrorThrottled,
      SyncErrorKind.sessionExpired => l10n.settingsSyncErrorSessionExpired,
      SyncErrorKind.refused => l10n.settingsSyncErrorRefused,
      SyncErrorKind.wrongPassword => l10n.settingsSyncErrorWrongPassword,
      SyncErrorKind.unknown => l10n.settingsSyncErrorUnknown,
    };
  }

  static Widget _error(BuildContext context, String message) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        liveRegion: true,
        child: Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}

enum _Tone { info, success, error }

/// A message about the whole form or account, announced by screen readers
/// when it appears. Colours come from the scheme, so it follows the theme.
class _Notice extends StatelessWidget {
  const _Notice({
    super.key,
    required this.tone,
    required this.message,
    this.title,
    this.action,
  });

  final _Tone tone;
  final String message;
  final String? title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (background, foreground, icon) = switch (tone) {
      _Tone.info => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.info_outline,
      ),
      _Tone.success => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        Icons.check_circle_outline,
      ),
      _Tone.error => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.error_outline,
      ),
    };
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: foreground, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null) ...[
                      Text(
                        title!,
                        style: text.titleSmall?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      message,
                      style: text.bodyMedium?.copyWith(color: foreground),
                    ),
                    if (action != null) ...[
                      const SizedBox(height: 12),
                      action!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Explains exactly what is and is not deleted. Deletes only with the current
/// password typed and the acknowledgment ticked, and closes itself only when
/// the server confirmed it, or the session ended. The password lives in this
/// dialog's controller alone and is discarded with it.
class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _acknowledged = false;
  bool _deleting = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_deleting) {
      return;
    }
    setState(() => _deleting = true);
    await ref
        .read(syncViewModelProvider.notifier)
        .deleteAccount(_password.text);
    if (!mounted) {
      return;
    }
    final after = ref.read(syncViewModelProvider);
    if (!after.isSignedIn) {
      // Deleted, or the session was rejected; the card says which.
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _deleting = false;
      if (after.error == SyncErrorKind.wrongPassword) {
        _password.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final error = ref.watch(syncViewModelProvider.select((s) => s.error));
    final busy = _deleting;
    final ready = _password.text.isNotEmpty && _acknowledged && !busy;
    return PopScope(
      // Back and the barrier cannot interrupt a request already sent.
      canPop: !busy,
      child: AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: scheme.error),
        title: Text(l10n.settingsSyncDeleteTitle),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.settingsSyncDeleteBody),
            const SizedBox(height: 16),
            AutofillGroup(
              child: TextField(
                key: const ValueKey('sync-delete-password-field'),
                controller: _password,
                enabled: !busy,
                obscureText: true,
                // No autofocus: the keyboard would cover the explanation and
                // the acknowledgment before either is read.
                keyboardType: TextInputType.visiblePassword,
                autofillHints: const [AutofillHints.password],
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) {
                  ref.read(syncViewModelProvider.notifier).clearError();
                  setState(() {});
                },
                decoration: InputDecoration(
                  labelText: l10n.settingsSyncDeletePassword,
                  prefixIcon: const Icon(Icons.lock_outline),
                  errorText: error == SyncErrorKind.wrongPassword
                      ? l10n.settingsSyncErrorWrongPassword
                      : null,
                  errorMaxLines: 3,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const ValueKey('sync-delete-acknowledge'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _acknowledged,
              onChanged: busy
                  ? null
                  : (value) => setState(() => _acknowledged = value ?? false),
              title: Text(l10n.settingsSyncDeleteAcknowledge),
            ),
            if (error != null && error != SyncErrorKind.wrongPassword) ...[
              const SizedBox(height: 8),
              _Notice(
                key: const ValueKey('sync-delete-error'),
                tone: _Tone.error,
                message: _SyncAccountCardState._errorText(context, error),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('sync-delete-cancel-button'),
            style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.settingsCancel),
          ),
          FilledButton(
            key: const ValueKey('sync-delete-confirm-button'),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
              minimumSize: const Size(64, 48),
            ),
            onPressed: ready ? _delete : null,
            child: busy
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.onError,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(child: Text(l10n.settingsSyncDeleting)),
                    ],
                  )
                : Text(l10n.settingsSyncDeleteConfirm),
          ),
        ],
      ),
    );
  }
}
