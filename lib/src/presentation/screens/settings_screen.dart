import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/models/app_language.dart';
import '../localization/app_localizations_x.dart';
import '../providers.dart';
import '../view_models/settings_view_model.dart';
import '../widgets/sync_account_card.dart';
import 'reports_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsViewModelProvider);
    final viewModel = ref.read(settingsViewModelProvider.notifier);
    final appLanguageState = ref.watch(appLanguageViewModelProvider);
    final dataTransferSupported = ref.watch(dataTransferSupportedProvider);
    final syncSupported = ref.watch(syncSupportedProvider);
    final l10n = context.l10n;
    final settingsBusy = state.isSaving || state.isTransferring;
    final error = Theme.of(context).colorScheme.error;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        // Extra bottom space so the last card is never flush against the
        // nav strip and stays comfortably scrollable into view.
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // Ordered by how often each is used: preferences, everyday tracking,
          // the account, rare data operations, then support. Rows with a
          // chevron open a screen or picker; actions have none.
          _sectionHeader(context, l10n.settingsGeneralSection),
          Card(
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(l10n.settingsLanguageTitle),
                  subtitle: Text(
                    _languageName(context, appLanguageState.language),
                  ),
                  trailing: appLanguageState.isSaving
                      ? const _RowProgress()
                      : const Icon(Icons.chevron_right),
                  onTap: appLanguageState.isLoading || appLanguageState.isSaving
                      ? null
                      : () => _showLanguageDialog(
                          context,
                          ref,
                          appLanguageState.language,
                        ),
                ),
                if (appLanguageState.hasError)
                  _CardError(l10n.settingsLanguageUpdateError),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader(context, l10n.settingsActivityDataSection),
          Card(
            elevation: 0,
            child: ListTile(
              key: const ValueKey('settings-reports'),
              leading: const Icon(Icons.insights_outlined),
              title: Text(l10n.reportsTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (context) => const ReportsScreen()),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  key: const ValueKey('settings-excluded-apps'),
                  leading: const Icon(Icons.visibility_off_outlined),
                  title: Text(l10n.settingsExcludedAppsTitle),
                  subtitle: state.excludedApps.isEmpty
                      ? Text(l10n.settingsExcludedAppsEmpty)
                      : null,
                ),
                for (final appKey in state.excludedApps)
                  ListTile(
                    // Aligned with the title text above, not with its icon.
                    contentPadding: const EdgeInsetsDirectional.only(
                      start: 72,
                      end: 8,
                    ),
                    title: Text(
                      state.excludedAppNames[appKey] ?? appKey,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: l10n.settingsStopExcluding,
                      icon: const Icon(Icons.undo),
                      onPressed: state.isSaving
                          ? null
                          : () async {
                              await viewModel.removeExcludedApp(appKey);
                              ref
                                  .read(dashboardViewModelProvider.notifier)
                                  .refresh();
                            },
                    ),
                  ),
              ],
            ),
          ),
          if (syncSupported) ...[
            const SizedBox(height: 24),
            _sectionHeader(context, l10n.settingsSyncSection),
            const SyncAccountCard(),
          ],
          const SizedBox(height: 24),
          _sectionHeader(context, l10n.settingsPrivacyTitle),
          Card(
            elevation: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  // The plain sentence claims FocusTrace never uploads
                  // anything, which stops being true once sync exists in the
                  // build, so it is only shown where that still holds.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        syncSupported
                            ? l10n.settingsPrivacyBodySync
                            : l10n.settingsPrivacyBody,
                      ),
                      if (dataTransferSupported) ...[
                        const SizedBox(height: 8),
                        Text(l10n.settingsDataTransferBody),
                      ],
                    ],
                  ),
                ),
                if (dataTransferSupported) ...[
                  ListTile(
                    key: const ValueKey('settings-export-data'),
                    leading: const Icon(Icons.file_upload_outlined),
                    title: Text(l10n.settingsExportData),
                    enabled: !settingsBusy,
                    onTap: () => _exportData(context, viewModel),
                  ),
                  ListTile(
                    key: const ValueKey('settings-import-data'),
                    leading: const Icon(Icons.file_download_outlined),
                    title: Text(l10n.settingsImportData),
                    enabled: !settingsBusy,
                    onTap: () => _importData(context, ref, viewModel),
                  ),
                  if (state.isTransferring)
                    const LinearProgressIndicator(
                      key: ValueKey('settings-transfer-progress'),
                    ),
                ],
                // Last in the card and set apart: never the row a thumb lands
                // on by habit.
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('settings-clear-data'),
                  iconColor: error,
                  textColor: error,
                  leading: const Icon(Icons.delete_outline),
                  title: Text(l10n.settingsClearLocalData),
                  enabled: !settingsBusy,
                  onTap: () => _clearLocalData(context, ref, viewModel),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader(context, l10n.settingsSupportSection),
          // ponytail: Windows tracking card removed for Play release, restore
          // from git history when Windows sync ships.
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.mail_outline),
              title: Text(l10n.settingsSendFeedback),
              // Leaves the app, unlike the chevron rows.
              trailing: const Icon(Icons.open_in_new),
              onTap: () => launchUrl(
                Uri(
                  scheme: 'mailto',
                  path: 'stepan.demyanenko30@gmail.com',
                  queryParameters: {'subject': 'FocusTrace feedback'},
                ),
              ),
            ),
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            _CardError(l10n.commonUnexpectedError),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Future<void> _showLanguageDialog(
    BuildContext context,
    WidgetRef ref,
    AppLanguage currentLanguage,
  ) async {
    final selectedLanguage = await showDialog<AppLanguage>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(dialogContext.l10n.settingsChooseLanguage),
          contentPadding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final language in AppLanguage.values)
                  RadioListTile<AppLanguage>(
                    value: language,
                    // ponytail: RadioGroup migration needs Flutter >=3.35;
                    // local SDK is 3.32. Drop these ignores after upgrading.
                    // ignore: deprecated_member_use
                    groupValue: currentLanguage,
                    title: Text(_languageName(dialogContext, language)),
                    controlAffinity: ListTileControlAffinity.trailing,
                    // ignore: deprecated_member_use
                    onChanged: (selection) {
                      Navigator.of(dialogContext).pop(selection);
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(dialogContext.l10n.settingsCancel),
            ),
          ],
        );
      },
    );

    if (selectedLanguage == null || !context.mounted) {
      return;
    }
    await ref
        .read(appLanguageViewModelProvider.notifier)
        .updateLanguage(selectedLanguage);
  }

  String _languageName(BuildContext context, AppLanguage language) {
    return switch (language) {
      AppLanguage.system => context.l10n.settingsLanguageSystemDefault,
      AppLanguage.english => 'English',
      AppLanguage.spanish => 'Español',
      AppLanguage.french => 'Français',
      AppLanguage.german => 'Deutsch',
      AppLanguage.portugueseBrazil => 'Português (Brasil)',
      AppLanguage.japanese => '日本語',
      AppLanguage.ukrainian => 'Українська',
    };
  }

  /// The sheet runs the deletion itself, so it can show progress and an error
  /// without closing; it closes only once the data is gone.
  Future<void> _clearLocalData(
    BuildContext context,
    WidgetRef ref,
    SettingsViewModel viewModel,
  ) async {
    final l10n = context.l10n;
    final syncSupported = ref.read(syncSupportedProvider);
    final deleted = await _ConfirmSheet.show(
      context,
      key: const ValueKey('settings-clear-data-sheet'),
      title: l10n.settingsClearDataDialogTitle,
      paragraphs: [
        l10n.settingsClearDataDeletes,
        if (syncSupported) l10n.settingsClearDataKeepsSync,
        l10n.settingsClearDataKeeps,
      ],
      confirmLabel: l10n.settingsClearLocalData,
      destructive: true,
      action: () async {
        await viewModel.clearLocalData();
        if (ref.read(settingsViewModelProvider).errorMessage != null) {
          return false;
        }
        ref.invalidate(appCategoriesViewModelProvider);
        await ref
            .read(appLanguageViewModelProvider.notifier)
            .restoreAfterDataClear();
        await ref.read(restrictionsViewModelProvider.notifier).load();
        // This device's sync opt-in was a local setting too.
        if (syncSupported) {
          await ref.read(syncViewModelProvider.notifier).load();
        }
        ref.read(dashboardViewModelProvider.notifier).refresh();
        return true;
      },
    );
    if (!deleted || !context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.settingsClearDataDone)));
  }

  Future<void> _exportData(
    BuildContext context,
    SettingsViewModel viewModel,
  ) async {
    final saved = await viewModel.exportLocalData();
    if (!saved || !context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.settingsExportSuccess)));
  }

  Future<void> _importData(
    BuildContext context,
    WidgetRef ref,
    SettingsViewModel viewModel,
  ) async {
    // Only confirms; the system file picker opens after the sheet closes.
    final confirmed = await _ConfirmSheet.show(
      context,
      key: const ValueKey('settings-import-sheet'),
      title: context.l10n.settingsImportDialogTitle,
      paragraphs: [
        context.l10n.settingsImportDialogBody,
        context.l10n.settingsImportDialogDetail,
      ],
      confirmLabel: context.l10n.settingsImportData,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final result = await viewModel.importLocalData();
    if (result == null || !context.mounted) {
      return;
    }
    await ref.read(appLanguageViewModelProvider.notifier).load();
    ref.invalidate(appCategoriesViewModelProvider);
    await ref.read(restrictionsViewModelProvider.notifier).load();
    await ref.read(dashboardViewModelProvider.notifier).refresh();
    ref.invalidate(reportsViewModelProvider);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.settingsImportSuccess)));
  }
}

class _RowProgress extends StatelessWidget {
  const _RowProgress();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}

/// An error that belongs to a card, announced when it appears.
class _CardError extends StatelessWidget {
  const _CardError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        liveRegion: true,
        child: Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    ),
  );
}

/// The bottom-sheet confirmation used in Settings, laid out like the account
/// deletion sheet. With an [action], the sheet runs it and shows progress; it
/// cannot be dismissed meanwhile, stays open with an error if the action
/// fails, and closes only on success. Resolves to true only when confirmed and
/// the action, if any, succeeded.
class _ConfirmSheet extends StatefulWidget {
  const _ConfirmSheet({
    super.key,
    required this.title,
    required this.paragraphs,
    required this.confirmLabel,
    this.destructive = false,
    this.action,
  });

  final String title;
  final List<String> paragraphs;
  final String confirmLabel;
  final bool destructive;
  final Future<bool> Function()? action;

  static Future<bool> show(
    BuildContext context, {
    Key? key,
    required String title,
    required List<String> paragraphs,
    required String confirmLabel,
    bool destructive = false,
    Future<bool> Function()? action,
  }) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Dragging down would close it past PopScope, even mid-action.
      enableDrag: false,
      builder: (context) => _ConfirmSheet(
        key: key,
        title: title,
        paragraphs: paragraphs,
        confirmLabel: confirmLabel,
        destructive: destructive,
        action: action,
      ),
    );
    return confirmed ?? false;
  }

  @override
  State<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<_ConfirmSheet> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _confirm() async {
    final action = widget.action;
    if (action == null) {
      Navigator.of(context).pop(true);
      return;
    }
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _failed = false;
    });
    final succeeded = await action();
    if (!mounted) {
      return;
    }
    if (succeeded) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _failed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PopScope(
      // Back and the barrier cannot interrupt an action already running.
      canPop: !_busy,
      child: SingleChildScrollView(
        // The keyboard pushes the sheet up rather than covering its buttons.
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          // useSafeArea leaves the bottom out; keep buttons above the nav bar.
          16 +
              MediaQuery.viewInsetsOf(context).bottom +
              MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(widget.title, style: theme.textTheme.titleLarge),
            ),
            for (final paragraph in widget.paragraphs) ...[
              const SizedBox(height: 12),
              Text(paragraph),
            ],
            if (_failed) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.commonUnexpectedError,
                  key: const ValueKey('settings-sheet-error'),
                  style: TextStyle(color: scheme.error),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  key: const ValueKey('settings-sheet-cancel'),
                  style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: Text(l10n.settingsCancel),
                ),
                FilledButton(
                  key: const ValueKey('settings-sheet-confirm'),
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.destructive ? scheme.error : null,
                    foregroundColor: widget.destructive ? scheme.onError : null,
                    minimumSize: const Size(64, 48),
                  ),
                  onPressed: _busy ? null : _confirm,
                  child: _busy
                      ? SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: widget.destructive
                                ? scheme.onError
                                : scheme.onPrimary,
                          ),
                        )
                      : Text(widget.confirmLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
