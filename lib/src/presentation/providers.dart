import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/services/usage_aggregation_service.dart';
import '../application/services/report_generation_service.dart';
import '../application/services/usage_trend_service.dart';
import '../data/datasources/focus_trace_local_data_source.dart';
import '../data/datasources/backup_document_data_source.dart';
import '../data/datasources/platform_locale_data_source.dart';
import '../data/datasources/focus_trace_sync_api.dart';
import '../data/datasources/platform_usage_data_source.dart';
import '../data/datasources/secure_sync_credential_store.dart';
import '../data/repositories/app_language_repository_impl.dart';
import '../data/repositories/data_transfer_repository_impl.dart';
import '../data/repositories/report_repository_impl.dart';
import '../data/repositories/settings_repository_impl.dart';
import '../data/repositories/sync_repository_impl.dart';
import '../data/repositories/usage_repository_impl.dart';
import '../domain/models/app_usage_summary.dart';
import '../domain/models/usage_session.dart';
import '../domain/repositories/app_language_repository.dart';
import '../domain/repositories/data_transfer_repository.dart';
import '../domain/repositories/report_repository.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/repositories/sync_repository.dart';
import '../domain/repositories/usage_repository.dart';
import 'view_models/app_language_view_model.dart';
import 'view_models/app_usage_details_view_model.dart';
import 'view_models/dashboard_view_model.dart';
import 'view_models/onboarding_view_model.dart';
import 'view_models/reports_view_model.dart';
import 'view_models/restrictions_view_model.dart';
import 'view_models/sync_view_model.dart';
import 'view_models/settings_view_model.dart';
import 'view_models/tracking_view_model.dart';

final usagePlatformProvider = Provider<UsagePlatform>((ref) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return UsagePlatform.android;
    case TargetPlatform.windows:
      return UsagePlatform.windows;
    case TargetPlatform.iOS:
      return UsagePlatform.ios;
    case TargetPlatform.macOS:
      return UsagePlatform.macos;
    case TargetPlatform.linux:
      return UsagePlatform.linux;
    case TargetPlatform.fuchsia:
      return UsagePlatform.unsupported;
  }
});

final usageAggregationServiceProvider = Provider<UsageAggregationService>(
  (ref) => const UsageAggregationService(),
);

final usageTrendServiceProvider = Provider<UsageTrendService>(
  (ref) => const UsageTrendService(),
);

final reportGenerationServiceProvider = Provider<ReportGenerationService>(
  (ref) => const ReportGenerationService(),
);

final localDataSourceProvider = Provider<FocusTraceLocalDataSource>(
  (ref) => SqfliteFocusTraceLocalDataSource(),
);

final portableLocalDataSourceProvider = Provider<PortableFocusTraceDataSource>((
  ref,
) {
  final source = ref.watch(localDataSourceProvider);
  if (source is PortableFocusTraceDataSource) {
    return source as PortableFocusTraceDataSource;
  }
  throw StateError('The configured local data source cannot transfer data.');
});

final dataTransferSupportedProvider = Provider<bool>(
  (ref) => ref.watch(usagePlatformProvider) == UsagePlatform.android,
);

final backupDocumentDataSourceProvider = Provider<BackupDocumentDataSource>((
  ref,
) {
  if (ref.watch(dataTransferSupportedProvider)) {
    return AndroidBackupDocumentDataSource();
  }
  return const UnsupportedBackupDocumentDataSource();
});

final dataTransferRepositoryProvider = Provider<DataTransferRepository>((ref) {
  return DataTransferRepositoryImpl(
    localDataSource: ref.watch(portableLocalDataSourceProvider),
    documentDataSource: ref.watch(backupDocumentDataSourceProvider),
  );
});

final appLanguageRepositoryProvider = Provider<AppLanguageRepository>(
  (ref) => AppLanguageRepositoryImpl(ref.watch(localDataSourceProvider)),
);

final platformLocaleDataSourceProvider = Provider<PlatformLocaleDataSource>((
  ref,
) {
  if (ref.watch(usagePlatformProvider) == UsagePlatform.android) {
    return AndroidPlatformLocaleDataSource();
  }
  return const NoOpPlatformLocaleDataSource();
});

final appLanguageViewModelProvider =
    StateNotifierProvider<AppLanguageViewModel, AppLanguageState>((ref) {
      final viewModel = AppLanguageViewModel(
        repository: ref.watch(appLanguageRepositoryProvider),
        platformLocaleDataSource: ref.watch(platformLocaleDataSourceProvider),
      );
      viewModel.load();
      return viewModel;
    });

final platformDataSourceProvider = Provider<PlatformUsageDataSource>((ref) {
  switch (ref.watch(usagePlatformProvider)) {
    case UsagePlatform.android:
      return AndroidUsageDataSource();
    case UsagePlatform.windows:
      return WindowsUsageDataSource();
    case UsagePlatform.macos:
    case UsagePlatform.ios:
    case UsagePlatform.linux:
    case UsagePlatform.unsupported:
      return const UnsupportedPlatformUsageDataSource();
  }
});

final installedAppsProvider = FutureProvider<List<AppUsageSummary>>((
  ref,
) async {
  try {
    return await ref.watch(platformDataSourceProvider).getInstalledApps();
  } catch (error) {
    // Decorative/auxiliary data: fall back to an empty list, never block UI.
    debugPrint('getInstalledApps failed: $error');
    return const [];
  }
});

final usageRepositoryProvider = Provider<UsageRepository>((ref) {
  return UsageRepositoryImpl(
    platform: ref.watch(usagePlatformProvider),
    localDataSource: ref.watch(localDataSourceProvider),
    platformDataSource: ref.watch(platformDataSourceProvider),
    aggregationService: ref.watch(usageAggregationServiceProvider),
  );
});

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepositoryImpl(
    usageRepository: ref.watch(usageRepositoryProvider),
    localDataSource: ref.watch(localDataSourceProvider),
    platformDataSource: ref.watch(platformDataSourceProvider),
  );
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl(ref.watch(localDataSourceProvider));
});

/// Empty unless the build supplies
/// `--dart-define=FOCUSTRACE_SYNC_BASE_URL=https://...`.
///
/// Sync is opt-in and off the critical path: with no base URL there is no sync
/// object at all, and tracking, restrictions, blocking, schedules, local
/// history and the UI are exactly what they were before.
const syncBaseUrl = String.fromEnvironment('FOCUSTRACE_SYNC_BASE_URL');

final syncSupportedProvider = Provider<bool>(
  (ref) =>
      syncBaseUrl.isNotEmpty &&
      ref.watch(usagePlatformProvider) == UsagePlatform.android,
);

/// `null` when sync is not configured for this build. Widgets, screens and view
/// models may hold this; none of them may hold [FocusTraceSyncApi].
final syncRepositoryProvider = Provider<SyncRepository?>((ref) {
  if (!ref.watch(syncSupportedProvider)) {
    return null;
  }
  final source = ref.watch(localDataSourceProvider);
  if (source is! UsageSyncDataSource) {
    throw StateError('The configured local data source cannot sync usage.');
  }
  return SyncRepositoryImpl(
    api: FocusTraceSyncApi(
      baseUrl: Uri.parse(syncBaseUrl),
      credentials: const SecureSyncCredentialStore(),
    ),
    localDataSource: source,
    // Promotion does not survive the interface split, as in portableLocalDataSourceProvider.
    usageDataSource: source as UsageSyncDataSource,
    // Architecture section 3 wants Build.MODEL here, which needs a platform
    // call this stage does not add. Tracked in the plan.
    deviceName: 'Android device',
  );
});

/// `null` when this build has no sync. Every widget that reads it must handle
/// that, which is why the account card is only built behind
/// [syncSupportedProvider].
final syncViewModelProvider =
    StateNotifierProvider<SyncViewModel, SyncState>((ref) {
      final repository = ref.watch(syncRepositoryProvider);
      if (repository == null) {
        throw StateError('Sync is not configured in this build.');
      }
      final viewModel = SyncViewModel(repository);
      viewModel.load();
      return viewModel;
    });

final onboardingViewModelProvider =
    StateNotifierProvider<OnboardingViewModel, OnboardingState>((ref) {
      final viewModel = OnboardingViewModel(
        settingsRepository: ref.watch(settingsRepositoryProvider),
      );
      viewModel.load();
      return viewModel;
    });

final dashboardViewModelProvider =
    StateNotifierProvider<DashboardViewModel, DashboardState>((ref) {
      final viewModel = DashboardViewModel(
        usageRepository: ref.watch(usageRepositoryProvider),
        settingsRepository: ref.watch(settingsRepositoryProvider),
        platform: ref.watch(usagePlatformProvider),
        aggregationService: ref.watch(usageAggregationServiceProvider),
        trendService: ref.watch(usageTrendServiceProvider),
      );
      viewModel.loadTodayUsage();
      return viewModel;
    });

final appUsageDetailsViewModelProvider = StateNotifierProvider.autoDispose
    .family<
      AppUsageDetailsViewModel,
      AppUsageDetailsState,
      AppUsageDetailsRequest
    >((ref, request) {
      final viewModel = AppUsageDetailsViewModel(
        usageRepository: ref.watch(usageRepositoryProvider),
        settingsRepository: ref.watch(settingsRepositoryProvider),
        request: request,
      );
      viewModel.load();
      return viewModel;
    });

final trackingViewModelProvider =
    StateNotifierProvider<TrackingViewModel, TrackingState>((ref) {
      final viewModel = TrackingViewModel(
        platform: ref.watch(usagePlatformProvider),
        platformDataSource: ref.watch(platformDataSourceProvider),
        usageRepository: ref.watch(usageRepositoryProvider),
        settingsRepository: ref.watch(settingsRepositoryProvider),
      );
      viewModel.loadSettings();
      return viewModel;
    });

final settingsViewModelProvider =
    StateNotifierProvider<SettingsViewModel, SettingsState>((ref) {
      final viewModel = SettingsViewModel(
        settingsRepository: ref.watch(settingsRepositoryProvider),
        usageRepository: ref.watch(usageRepositoryProvider),
        dataTransferRepository: ref.watch(dataTransferRepositoryProvider),
      );
      viewModel.load();
      return viewModel;
    });

final restrictionsViewModelProvider =
    StateNotifierProvider<RestrictionsViewModel, RestrictionsState>((ref) {
      final viewModel = RestrictionsViewModel(
        settingsRepository: ref.watch(settingsRepositoryProvider),
        platformDataSource: ref.watch(platformDataSourceProvider),
        usageRepository: ref.watch(usageRepositoryProvider),
        platform: ref.watch(usagePlatformProvider),
        reportRepository: ref.watch(reportRepositoryProvider),
      );
      viewModel.load();
      return viewModel;
    });

final reportsViewModelProvider =
    StateNotifierProvider<ReportsViewModel, ReportsState>((ref) {
      final viewModel = ReportsViewModel(
        repository: ref.watch(reportRepositoryProvider),
        generationService: ref.watch(reportGenerationServiceProvider),
      );
      viewModel.load();
      return viewModel;
    });
