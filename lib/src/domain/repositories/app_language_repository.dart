import '../models/app_language.dart';

abstract class AppLanguageRepository {
  Future<AppLanguage> appLanguage();

  Future<void> setAppLanguage(AppLanguage language);
}
