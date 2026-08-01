import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/services/usage_aggregation_service.dart';
import '../application/services/usage_trend_service.dart';
import '../data/datasources/focus_trace_local_data_source.dart';
import '../data/datasources/platform_locale_data_source.dart';
import '../data/datasources/platform_usage_data_source.dart';
import '../data/repositories/app_language_repository_impl.dart';
import '../data/repositories/settings_repository_impl.dart';
import '../data/repositories/usage_repository_impl.dart';
import '../domain/models/app_usage_summary.dart';
import '../domain/models/usage_session.dart';
import '../domain/repositories/app_language_repository.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/repositories/usage_repository.dart';
import 'view_models/app_language_view_model.dart';
import 'view_models/app_usage_details_view_model.dart';
import 'view_models/dashboard_view_model.dart';
import 'view_models/onboarding_view_model.dart';
import 'view_models/restrictions_view_model.dart';
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

final localDataSourceProvider = Provider<FocusTraceLocalDataSource>(
  (ref) => SqfliteFocusTraceLocalDataSource(),
);

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

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl(ref.watch(localDataSourceProvider));
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
      );
      viewModel.load();
      return viewModel;
    });

final restrictionsViewModelProvider =
    StateNotifierProvider<RestrictionsViewModel, RestrictionsState>((ref) {
      final viewModel = RestrictionsViewModel(
        settingsRepository: ref.watch(settingsRepositoryProvider),
        platformDataSource: ref.watch(platformDataSourceProvider),
        platform: ref.watch(usagePlatformProvider),
      );
      viewModel.load();
      return viewModel;
    });
