import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/models/app_language.dart';
import '../localization/app_localizations_x.dart';
import '../providers.dart';
import '../view_models/settings_view_model.dart';
import 'reports_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsViewModelProvider);
    final viewModel = ref.read(settingsViewModelProvider.notifier);
    final appLanguageState = ref.watch(appLanguageViewModelProvider);
    final dataTransferSupported = ref.watch(dataTransferSupportedProvider);
    final l10n = context.l10n;
    final settingsBusy = state.isSaving || state.isTransferring;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        // Extra bottom space so the last card is never flush against the
        // nav strip and stays comfortably scrollable into view.
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
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
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        l10n.settingsLanguageUpdateError,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader(context, l10n.settingsActivityDataSection),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.settingsExcludedAppsTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (state.excludedApps.isEmpty)
                    Text(l10n.settingsExcludedAppsEmpty)
                  else
                    for (final appKey in state.excludedApps)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
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
          ),
          const SizedBox(height: 12),
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
          if (dataTransferSupported) ...[
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsDataTransferTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.settingsDataTransferBody),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          key: const ValueKey('settings-export-data'),
                          onPressed: settingsBusy
                              ? null
                              : () => _exportData(context, viewModel),
                          icon: const Icon(Icons.file_upload_outlined),
                          label: Text(l10n.settingsExportData),
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey('settings-import-data'),
                          onPressed: settingsBusy
                              ? null
                              : () => _importData(context, ref, viewModel),
                          icon: const Icon(Icons.file_download_outlined),
                          label: Text(l10n.settingsImportData),
                        ),
                        if (state.isTransferring)
                          const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.settingsPrivacyTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.settingsPrivacyBody),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: settingsBusy
                        ? null
                        : () async {
                            final confirmed = await _confirmClearData(context);
                            if (confirmed && context.mounted) {
                              await viewModel.clearLocalData();
                              await ref
                                  .read(appLanguageViewModelProvider.notifier)
                                  .restoreAfterDataClear();
                              await ref
                                  .read(restrictionsViewModelProvider.notifier)
                                  .load();
                              ref
                                  .read(dashboardViewModelProvider.notifier)
                                  .refresh();
                            }
                          },
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.settingsClearLocalData),
                  ),
                ],
              ),
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
              trailing: const Icon(Icons.chevron_right),
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
            Text(
              l10n.commonUnexpectedError,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
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

  Future<bool> _confirmClearData(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(context.l10n.settingsClearDataDialogTitle),
              content: Text(context.l10n.settingsClearDataDialogBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(context.l10n.settingsCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(context.l10n.settingsClear),
                ),
              ],
            );
          },
        ) ??
        false;
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
    final confirmed = await _confirmImportData(context);
    if (!confirmed || !context.mounted) {
      return;
    }
    final result = await viewModel.importLocalData();
    if (result == null || !context.mounted) {
      return;
    }
    await ref.read(appLanguageViewModelProvider.notifier).load();
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

  Future<bool> _confirmImportData(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(dialogContext.l10n.settingsImportDialogTitle),
            content: Text(dialogContext.l10n.settingsImportDialogBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(dialogContext.l10n.settingsCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(dialogContext.l10n.settingsImportData),
              ),
            ],
          ),
        ) ??
        false;
  }
}
