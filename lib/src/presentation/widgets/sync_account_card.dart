import 'package:flutter/material.dart';
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

class _SyncAccountCardState extends ConsumerState<SyncAccountCard> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  /// Shown when the fields are empty. Kept out of [SyncState] because it is
  /// about this form, not about the account.
  bool _missingFields = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsSyncTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(l10n.settingsSyncBody),
            const SizedBox(height: 12),
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
            else if (state.isSignedIn)
              ..._signedIn(context, state)
            else
              ..._signedOut(context, state),
            if (_missingFields && !state.isSignedIn) ...[
              const SizedBox(height: 8),
              _error(context, l10n.settingsSyncMissingFields),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 8),
              _error(context, _errorText(context, state.error!)),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _signedOut(BuildContext context, SyncState state) {
    final l10n = context.l10n;
    final busy = state.isAuthenticating;
    return [
      TextField(
        key: const ValueKey('sync-email-field'),
        controller: _email,
        enabled: !busy,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: l10n.settingsSyncEmail,
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const ValueKey('sync-password-field'),
        controller: _password,
        enabled: !busy,
        obscureText: true,
        decoration: InputDecoration(
          labelText: l10n.settingsSyncPassword,
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: FilledButton(
              key: const ValueKey('sync-sign-in-button'),
              onPressed: busy ? null : () => _submit(signIn: true),
              child: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.settingsSyncSignIn),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('sync-create-account-button'),
              onPressed: busy ? null : () => _submit(signIn: false),
              child: Text(l10n.settingsSyncCreateAccount),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _signedIn(BuildContext context, SyncState state) {
    final l10n = context.l10n;
    return [
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
            : (value) =>
                  ref.read(syncViewModelProvider.notifier).setSyncEnabled(value),
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
        Text(
          key: const ValueKey('sync-phase-label'),
          switch (state.phase) {
            SyncPhase.syncing => l10n.settingsSyncStateSyncing,
            SyncPhase.success => l10n.settingsSyncStateSuccess,
            SyncPhase.error => l10n.settingsSyncStateError,
            SyncPhase.idle => '',
          },
        ),
      ],
    ];
  }

  Future<void> _submit({required bool signIn}) async {
    final email = _email.text.trim();
    final password = _password.text;
    setState(() => _missingFields = email.isEmpty || password.isEmpty);
    if (_missingFields) {
      return;
    }
    final viewModel = ref.read(syncViewModelProvider.notifier);
    if (signIn) {
      await viewModel.signIn(email: email, password: password);
    } else {
      await viewModel.createAccount(email: email, password: password);
    }
    if (!mounted) {
      return;
    }
    // The password never outlives the attempt, successful or not.
    _password.clear();
    if (ref.read(syncViewModelProvider).isSignedIn) {
      _email.clear();
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
      SyncErrorKind.emailTaken => l10n.settingsSyncErrorEmailTaken,
      SyncErrorKind.weakPassword => l10n.settingsSyncErrorWeakPassword,
      SyncErrorKind.sessionExpired => l10n.settingsSyncErrorSessionExpired,
      SyncErrorKind.refused => l10n.settingsSyncErrorRefused,
      SyncErrorKind.unknown => l10n.settingsSyncErrorUnknown,
    };
  }

  static Widget _error(BuildContext context, String message) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
