enum AppLanguage {
  system(null),
  english('en'),
  spanish('es'),
  french('fr'),
  german('de'),
  portugueseBrazil('pt-BR'),
  japanese('ja'),
  ukrainian('uk');

  const AppLanguage(this.localeTag);

  final String? localeTag;

  String get storageValue => localeTag ?? 'system';

  static AppLanguage fromLocaleTag(String? localeTag) {
    final normalized = localeTag?.replaceAll('_', '-').toLowerCase();
    if (normalized == null || normalized == 'system') {
      return AppLanguage.system;
    }
    for (final language in AppLanguage.values) {
      if (language.localeTag?.toLowerCase() == normalized) {
        return language;
      }
    }
    return AppLanguage.system;
  }
}
