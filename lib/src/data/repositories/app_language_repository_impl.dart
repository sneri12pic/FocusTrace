import '../../domain/models/app_language.dart';
import '../../domain/repositories/app_language_repository.dart';
import '../datasources/focus_trace_local_data_source.dart';

class AppLanguageRepositoryImpl implements AppLanguageRepository {
  AppLanguageRepositoryImpl(this._localDataSource);

  static const _appLanguageKey = 'app_language';

  final FocusTraceLocalDataSource _localDataSource;

  @override
  Future<AppLanguage> appLanguage() async {
    final stored = await _localDataSource.readSetting(_appLanguageKey);
    return AppLanguage.fromLocaleTag(stored);
  }

  @override
  Future<void> setAppLanguage(AppLanguage language) {
    return _localDataSource.writeSetting(
      _appLanguageKey,
      language.storageValue,
    );
  }
}
