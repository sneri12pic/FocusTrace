import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/platform_locale_data_source.dart';
import '../../domain/models/app_language.dart';
import '../../domain/repositories/app_language_repository.dart';

class AppLanguageState {
  const AppLanguageState({
    this.language = AppLanguage.system,
    this.isLoading = false,
    this.isSaving = false,
    this.hasError = false,
  });

  final AppLanguage language;
  final bool isLoading;
  final bool isSaving;
  final bool hasError;

  AppLanguageState copyWith({
    AppLanguage? language,
    bool? isLoading,
    bool? isSaving,
    bool? hasError,
  }) {
    return AppLanguageState(
      language: language ?? this.language,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      hasError: hasError ?? this.hasError,
    );
  }
}

class AppLanguageViewModel extends StateNotifier<AppLanguageState> {
  AppLanguageViewModel({
    required AppLanguageRepository repository,
    required PlatformLocaleDataSource platformLocaleDataSource,
  }) : _repository = repository,
       _platformLocaleDataSource = platformLocaleDataSource,
       super(const AppLanguageState(isLoading: true));

  final AppLanguageRepository _repository;
  final PlatformLocaleDataSource _platformLocaleDataSource;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, hasError: false);
    try {
      final language = await _repository.appLanguage();
      state = state.copyWith(language: language, isLoading: false);
      await _syncPlatformLanguage(language);
    } catch (_) {
      state = state.copyWith(
        language: AppLanguage.system,
        isLoading: false,
        hasError: true,
      );
    }
  }

  Future<void> updateLanguage(AppLanguage language) async {
    if (state.isSaving || (language == state.language && !state.hasError)) {
      return;
    }

    final previousLanguage = state.language;
    state = state.copyWith(language: language, isSaving: true, hasError: false);
    try {
      await _repository.setAppLanguage(language);
      state = state.copyWith(isSaving: false);
      await _syncPlatformLanguage(language);
    } catch (_) {
      state = state.copyWith(
        language: previousLanguage,
        isSaving: false,
        hasError: true,
      );
    }
  }

  Future<void> restoreAfterDataClear() async {
    final language = state.language;
    state = state.copyWith(isSaving: true, hasError: false);
    try {
      await _repository.setAppLanguage(language);
      state = state.copyWith(isSaving: false);
      await _syncPlatformLanguage(language);
    } catch (_) {
      state = state.copyWith(isSaving: false, hasError: true);
    }
  }

  Future<void> _syncPlatformLanguage(AppLanguage language) async {
    try {
      await _platformLocaleDataSource.applyLanguage(language);
    } catch (_) {
      state = state.copyWith(hasError: true);
    }
  }
}
