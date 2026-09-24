import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';
import 'package:focustrace/l10n/generated/app_localizations.dart';

/// The account card itself: what it shows, and what it refuses to do.
void main() {
  Future<void> pump(WidgetTester tester, _FakeSyncRepository repository) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [syncRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: SyncAccountCard())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a build without a sync URL has no sync UI at all', (
    tester,
  ) async {
    // syncBaseUrl comes from --dart-define, which the test build does not set,
    // so the settings screen never reaches SyncAccountCard.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(syncSupportedProvider), isFalse);
    expect(container.read(syncRepositoryProvider), isNull);
  });

  testWidgets('signed out shows the sign-in form and no sync controls', (
    tester,
  ) async {
    await pump(tester, _FakeSyncRepository());

    expect(find.byKey(const ValueKey('sync-email-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('sync-password-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('sync-sign-in-button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sync-create-account-button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('sync-enabled-switch')), findsNothing);
    expect(find.byKey(const ValueKey('sync-now-button')), findsNothing);
  });

  testWidgets('empty fields are refused without calling the repository', (
    tester,
  ) async {
    final repository = _FakeSyncRepository();
    await pump(tester, repository);

    await tester.tap(find.byKey(const ValueKey('sync-sign-in-button')));
    await tester.pumpAndSettle();

    expect(repository.signInCalls, 0);
    expect(find.text('Enter an email and a password.'), findsOneWidget);
  });

  testWidgets('signing in swaps the form for the account controls', (
    tester,
  ) async {
    final repository = _FakeSyncRepository();
    await pump(tester, repository);

    await tester.enterText(
      find.byKey(const ValueKey('sync-email-field')),
      'a@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('sync-password-field')),
      'pw',
    );
    await tester.tap(find.byKey(const ValueKey('sync-sign-in-button')));
    await tester.pumpAndSettle();

    expect(repository.signInCalls, 1);
    expect(find.text('a@example.com'), findsOneWidget);
    expect(find.byKey(const ValueKey('sync-enabled-switch')), findsOneWidget);
    expect(find.byKey(const ValueKey('sync-email-field')), findsNothing);
  });

  testWidgets('sync now is disabled until the user opts in', (tester) async {
    final repository = _FakeSyncRepository()
      ..signedIn = true
      ..email = 'a@example.com';
    await pump(tester, repository);

    final button = tester.widget<ButtonStyleButton>(
      find.byKey(const ValueKey('sync-now-button')),
    );
    expect(button.onPressed, isNull, reason: 'off means off');
    expect(find.text('Not synced yet'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sync-enabled-switch')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ButtonStyleButton>(
            find.byKey(const ValueKey('sync-now-button')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('a manual sync reports success', (tester) async {
    final repository = _FakeSyncRepository()
      ..signedIn = true
      ..email = 'a@example.com'
      ..enabled = true;
    await pump(tester, repository);

    await tester.tap(find.byKey(const ValueKey('sync-now-button')));
    await tester.pumpAndSettle();

    expect(repository.syncRuns, 1);
    expect(find.text('Sync complete'), findsOneWidget);
  });

  testWidgets('a failed sync shows a reason and never the raw failure', (
    tester,
  ) async {
    final repository = _FakeSyncRepository()
      ..signedIn = true
      ..email = 'a@example.com'
      ..enabled = true
      ..syncFailure = SyncFailureReason.offline;
    await pump(tester, repository);

    await tester.tap(find.byKey(const ValueKey('sync-now-button')));
    await tester.pumpAndSettle();

    expect(find.text('Sync failed'), findsOneWidget);
    expect(
      find.text(
        'Could not reach the sync service. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    // The developer string behind the failure must not be on screen.
    expect(find.textContaining('SocketException'), findsNothing);
    expect(find.textContaining(_FakeSyncRepository.rawFailure), findsNothing);
  });

  testWidgets('logging out returns to the signed-out form', (tester) async {
    final repository = _FakeSyncRepository()
      ..signedIn = true
      ..email = 'a@example.com'
      ..enabled = true;
    await pump(tester, repository);

    await tester.tap(find.byKey(const ValueKey('sync-sign-out-button')));
    await tester.pumpAndSettle();

    expect(repository.signedOut, isTrue);
    expect(find.byKey(const ValueKey('sync-email-field')), findsOneWidget);
    expect(find.text('a@example.com'), findsNothing);
  });
}

class _FakeSyncRepository implements SyncRepository {
  static const rawFailure = 'internal-failure-string';

  bool signedIn = false;
  String? email;
  bool enabled = false;
  DateTime? lastSuccess;
  SyncFailureReason? syncFailure;

  int signInCalls = 0;
  int syncRuns = 0;
  bool signedOut = false;

  @override
  Future<bool> get isSignedIn async => signedIn;

  @override
  Future<String?> accountEmail() async => email;

  @override
  Future<bool> isSyncEnabled() async => enabled;

  @override
  Future<void> setSyncEnabled(bool value) async => enabled = value;

  @override
  Future<DateTime?> lastSuccessfulSyncAt() async => lastSuccess;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    signedIn = true;
    this.email = email;
  }

  @override
  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    signedIn = true;
    this.email = email;
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
    signedIn = false;
    email = null;
    enabled = false;
  }

  @override
  Future<SyncRunResult> syncNow({bool requireEnabled = false}) async {
    syncRuns++;
    if (syncFailure != null) {
      return SyncRunResult.failed(rawFailure, syncFailure!);
    }
    lastSuccess = DateTime.utc(2026, 9, 20, 12);
    return const SyncRunResult(
      uploadedDays: 1,
      results: <SyncUploadResult>[],
      rejectedDays: 0,
    );
  }

  @override
  Future<String> installationId() async => 'installation';

  @override
  Future<List<RemoteUsageDay>> readRemoteHistory({
    required DateTime from,
    required DateTime to,
    String? deviceId,
  }) async => const <RemoteUsageDay>[];
}
