import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLanguage', () {
    test('parses persisted locale tags and falls back safely', () {
      expect(AppLanguage.fromLocaleTag(null), AppLanguage.system);
      expect(AppLanguage.fromLocaleTag('system'), AppLanguage.system);
      expect(AppLanguage.fromLocaleTag('es'), AppLanguage.spanish);
      expect(AppLanguage.fromLocaleTag('pt_BR'), AppLanguage.portugueseBrazil);
      expect(AppLanguage.fromLocaleTag('unsupported'), AppLanguage.system);
    });
  });

  group('AppLanguageViewModel', () {
    test('loads, persists, and syncs the selected language', () async {
      final repository = _FakeAppLanguageRepository(AppLanguage.spanish);
      final platform = _FakePlatformLocaleDataSource();
      final viewModel = AppLanguageViewModel(
        repository: repository,
        platformLocaleDataSource: platform,
      );

      await viewModel.load();
      expect(viewModel.state.language, AppLanguage.spanish);
      expect(viewModel.state.isLoading, isFalse);
      expect(platform.appliedLanguages, [AppLanguage.spanish]);

      await viewModel.updateLanguage(AppLanguage.japanese);
      expect(viewModel.state.language, AppLanguage.japanese);
      expect(repository.language, AppLanguage.japanese);
      expect(platform.appliedLanguages.last, AppLanguage.japanese);
    });

    test('restores the active language after local data is cleared', () async {
      final repository = _FakeAppLanguageRepository(AppLanguage.ukrainian);
      final viewModel = AppLanguageViewModel(
        repository: repository,
        platformLocaleDataSource: _FakePlatformLocaleDataSource(),
      );

      await viewModel.load();
      repository.language = AppLanguage.system;
      await viewModel.restoreAfterDataClear();

      expect(repository.language, AppLanguage.ukrainian);
      expect(viewModel.state.language, AppLanguage.ukrainian);
    });

    test('keeps Flutter language when native synchronization fails', () async {
      final repository = _FakeAppLanguageRepository(AppLanguage.english);
      final viewModel = AppLanguageViewModel(
        repository: repository,
        platformLocaleDataSource: _FakePlatformLocaleDataSource(
          shouldFail: true,
        ),
      );

      await viewModel.load();
      await viewModel.updateLanguage(AppLanguage.french);

      expect(viewModel.state.language, AppLanguage.french);
      expect(repository.language, AppLanguage.french);
      expect(viewModel.state.hasError, isTrue);
    });
  });

  test('Android locale data source sends the persisted BCP-47 tag', () async {
    const channel = MethodChannel('test/focustrace_locale');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final dataSource = AndroidPlatformLocaleDataSource(channel: channel);

    await dataSource.applyLanguage(AppLanguage.portugueseBrazil);
    await dataSource.applyLanguage(AppLanguage.system);

    expect(calls[0].method, 'setAppLocale');
    expect(calls[0].arguments, 'pt-BR');
    expect(calls[1].method, 'setAppLocale');
    expect(calls[1].arguments, isNull);
  });
}

class _FakeAppLanguageRepository implements AppLanguageRepository {
  _FakeAppLanguageRepository(this.language);

  AppLanguage language;

  @override
  Future<AppLanguage> appLanguage() async => language;

  @override
  Future<void> setAppLanguage(AppLanguage language) async {
    this.language = language;
  }
}

class _FakePlatformLocaleDataSource implements PlatformLocaleDataSource {
  _FakePlatformLocaleDataSource({this.shouldFail = false});

  final bool shouldFail;
  final List<AppLanguage> appliedLanguages = [];

  @override
  Future<void> applyLanguage(AppLanguage language) async {
    if (shouldFail) {
      throw StateError('native sync failed');
    }
    appliedLanguages.add(language);
  }
}
