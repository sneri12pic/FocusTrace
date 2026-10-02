import 'dart:async';

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

  test('a release build treats a non-https sync URL as not configured', () {
    const local = 'http://127.0.0.1:18080';
    expect(syncBaseUrlUsable(local, releaseMode: true), isFalse);
    expect(
      syncBaseUrlUsable('HTTP://sync.example', releaseMode: true),
      isFalse,
    );
    expect(syncBaseUrlUsable('sync.example', releaseMode: true), isFalse);
    expect(
      syncBaseUrlUsable('https://sync.example', releaseMode: true),
      isTrue,
    );
    expect(syncBaseUrlUsable(local, releaseMode: false), isTrue);
    expect(syncBaseUrlUsable('', releaseMode: false), isFalse);
  });

  group('signed-out form', () {
    final email = find.byKey(const ValueKey('sync-email-field'));
    final password = find.byKey(const ValueKey('sync-password-field'));
    final repeat = find.byKey(const ValueKey('sync-repeat-password-field'));
    final submit = find.byKey(const ValueKey('sync-submit-button'));
    final modeSwitch = find.byKey(const ValueKey('sync-mode-switch'));
    final notice = find.byKey(const ValueKey('sync-form-notice'));
    const passphrase = 'my unique passphrase';

    TextField field(WidgetTester tester, Finder finder) =>
        tester.widget<TextField>(finder);

    Future<void> tap(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    /// Registration gets the same password repeated, unless [again] differs.
    Future<void> fill(
      WidgetTester tester,
      String e,
      String p, {
      String? again,
    }) async {
      await tester.enterText(email, e);
      await tester.enterText(password, p);
      if (repeat.evaluate().isNotEmpty) {
        await tester.enterText(repeat, again ?? p);
      }
      await tester.pump();
    }

    Future<void> toCreate(WidgetTester tester) => tap(tester, modeSwitch);

    testWidgets('opens on sign-in with one primary action and no sync '
        'controls', (tester) async {
      await pump(tester, _FakeSyncRepository());

      expect(find.text('Sign in to your account'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('New to sync? Create an account'), findsOneWidget);
      expect(field(tester, password).autofillHints, [AutofillHints.password]);
      expect(field(tester, email).autofillHints, contains(AutofillHints.email));
      expect(find.byKey(const ValueKey('sync-enabled-switch')), findsNothing);
      expect(find.byKey(const ValueKey('sync-now-button')), findsNothing);
    });

    testWidgets('switching to create account explains the requirements '
        'before submission and keeps the email', (tester) async {
      await pump(tester, _FakeSyncRepository());
      await tester.enterText(email, 'a@example.com');

      await toCreate(tester);

      expect(find.text('Create a sync account'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Create account'),
        findsOneWidget,
      );
      expect(find.textContaining('Use 15–128 characters'), findsOneWidget);
      expect(
        find.textContaining('Common passwords are not accepted'),
        findsOneWidget,
      );
      expect(field(tester, password).autofillHints, [
        AutofillHints.newPassword,
      ]);
      expect(field(tester, email).controller!.text, 'a@example.com');

      await tap(tester, modeSwitch);
      expect(find.text('Sign in to your account'), findsOneWidget);
    });

    testWidgets('password can be shown and hidden without changing its value', (
      tester,
    ) async {
      await pump(tester, _FakeSyncRepository());
      await tester.enterText(password, passphrase);
      expect(field(tester, password).obscureText, isTrue);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(field(tester, password).obscureText, isFalse);
      expect(field(tester, password).controller!.text, passphrase);
      await tester.tap(find.byTooltip('Hide password'));
      await tester.pump();
      expect(field(tester, password).obscureText, isTrue);
    });

    testWidgets('empty fields are flagged beside each field without calling '
        'the repository', (tester) async {
      final repository = _FakeSyncRepository();
      await pump(tester, repository);

      await tap(tester, submit);

      expect(repository.signInCalls, 0);
      expect(field(tester, email).decoration!.errorText, isNotNull);
      expect(field(tester, password).decoration!.errorText, isNotNull);
      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
    });

    testWidgets('a short new password is caught locally and the error '
        'updates as the user types', (tester) async {
      final repository = _FakeSyncRepository();
      await pump(tester, repository);
      await toCreate(tester);
      await fill(tester, 'a@example.com', 'short');

      await tap(tester, submit);

      expect(repository.createCalls, 0);
      expect(
        find.text('Use at least 15 characters (5 so far).'),
        findsOneWidget,
      );
      await tester.enterText(password, passphrase);
      await tester.pump();
      expect(field(tester, password).decoration!.errorText, isNull);
    });

    testWidgets('an invalid new email is caught locally', (tester) async {
      final repository = _FakeSyncRepository();
      await pump(tester, repository);
      await toCreate(tester);
      await fill(tester, 'not-an-email', passphrase);

      await tap(tester, submit);

      expect(repository.createCalls, 0);
      expect(
        field(tester, email).decoration!.errorText,
        'Enter a valid email address, like name@example.com.',
      );
    });

    testWidgets('creating an account is unmistakable and leaves sync off '
        'until the user turns it on', (tester) async {
      final repository = _FakeSyncRepository();
      await pump(tester, repository);
      await toCreate(tester);
      await fill(tester, 'a@example.com', passphrase);

      await tap(tester, submit);

      final created = find.byKey(const ValueKey('sync-account-created'));
      expect(created, findsOneWidget);
      expect(
        find.descendant(of: created, matching: find.text('Account created')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: created,
          matching: find.textContaining('Signed in as a@example.com'),
        ),
        findsOneWidget,
      );
      expect(repository.enabled, isFalse, reason: 'sync stays opt-in');

      await tap(tester, find.byKey(const ValueKey('sync-turn-on-button')));
      expect(repository.enabled, isTrue);
      expect(find.byKey(const ValueKey('sync-turn-on-button')), findsNothing);
    });

    testWidgets('submitting shows progress on the action and ignores repeat '
        'taps', (tester) async {
      final repository = _FakeSyncRepository()..hold = Completer<void>();
      await pump(tester, repository);
      await toCreate(tester);
      await fill(tester, 'a@example.com', passphrase);

      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();

      expect(find.text('Creating account…'), findsOneWidget);
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      expect(field(tester, email).enabled, isFalse);
      await tester.tap(submit, warnIfMissed: false);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      repository.hold!.complete();
      await tester.pumpAndSettle();
      expect(repository.createCalls, 1);
      expect(
        find.byKey(const ValueKey('sync-account-created')),
        findsOneWidget,
      );
    });

    testWidgets('a rejected email is shown on the email field, never as a '
        'credentials error', (tester) async {
      await pump(
        tester,
        _FakeSyncRepository()..createFailure = SyncAuthFailure.invalidEmail,
      );
      await toCreate(tester);
      await fill(tester, 'a@example', passphrase);

      await tap(tester, submit);

      expect(
        field(tester, email).decoration!.errorText,
        'Enter a valid email address, like name@example.com.',
      );
      expect(field(tester, password).decoration!.errorText, isNull);
      expect(find.textContaining('did not match an account'), findsNothing);
      expect(find.byKey(const ValueKey('sync-account-created')), findsNothing);
      // Editing the field clears the stale server verdict.
      await tester.enterText(email, 'a@example.com');
      await tester.pump();
      expect(field(tester, email).decoration!.errorText, isNull);
    });

    testWidgets('a rejected common password is shown on the password field '
        'and cleared', (tester) async {
      await pump(
        tester,
        _FakeSyncRepository()..createFailure = SyncAuthFailure.passwordRejected,
      );
      await toCreate(tester);
      await fill(tester, 'a@example.com', 'passwordpassword');

      await tap(tester, submit);

      expect(
        field(tester, password).decoration!.errorText,
        'This password is too common or matches your email. '
        'Choose a different one.',
      );
      expect(field(tester, password).controller!.text, isEmpty);
      expect(field(tester, email).decoration!.errorText, isNull);
    });

    testWidgets('an existing email offers sign-in with the same email', (
      tester,
    ) async {
      final repository = _FakeSyncRepository()
        ..createFailure = SyncAuthFailure.emailTaken;
      await pump(tester, repository);
      await toCreate(tester);
      await fill(tester, 'a@example.com', passphrase);

      await tap(tester, submit);

      expect(
        field(tester, email).decoration!.errorText,
        'An account already exists for that email.',
      );
      await tap(
        tester,
        find.byKey(const ValueKey('sync-sign-in-instead-button')),
      );
      expect(find.text('Sign in to your account'), findsOneWidget);
      expect(field(tester, email).controller!.text, 'a@example.com');
      // The registration attempt is over, so its password is gone.
      expect(field(tester, password).controller!.text, isEmpty);

      await tester.enterText(password, passphrase);
      await tap(tester, submit);
      expect(repository.signInCalls, 1);
      expect(find.byKey(const ValueKey('sync-enabled-switch')), findsOneWidget);
    });

    testWidgets('account created but sign-in failed says the account exists '
        'and moves to sign-in', (tester) async {
      final repository = _FakeSyncRepository()
        ..createFailure = SyncAuthFailure.accountCreatedSignInRequired;
      await pump(tester, repository);
      await toCreate(tester);
      await fill(tester, 'a@example.com', passphrase);

      await tap(tester, submit);

      expect(
        find.descendant(of: notice, matching: find.text('Account created')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Enter your password and tap Sign in'),
        findsOneWidget,
      );
      expect(find.text('Sign in to your account'), findsOneWidget);
      expect(field(tester, password).controller!.text, isEmpty);
    });

    group('repeat password', () {
      testWidgets('appears only while creating an account, with its own '
          'show/hide control and the new-password autofill hint', (
        tester,
      ) async {
        await pump(tester, _FakeSyncRepository());
        expect(repeat, findsNothing);

        await toCreate(tester);
        expect(repeat, findsOneWidget);
        expect(find.text('Repeat password'), findsOneWidget);
        expect(field(tester, repeat).autofillHints, [
          AutofillHints.newPassword,
        ]);
        await fill(tester, 'a@example.com', passphrase);

        expect(field(tester, repeat).obscureText, isTrue);
        await tester.tap(find.byTooltip('Show repeated password'));
        await tester.pump();
        expect(field(tester, repeat).obscureText, isFalse);
        expect(field(tester, password).obscureText, isTrue);
        expect(field(tester, repeat).controller!.text, passphrase);
        await tester.tap(find.byTooltip('Hide repeated password'));
        await tester.pump();
        expect(field(tester, repeat).obscureText, isTrue);

        await tap(tester, modeSwitch);
        expect(repeat, findsNothing);
      });

      testWidgets('a mismatch is shown inline and nothing is sent', (
        tester,
      ) async {
        final repository = _FakeSyncRepository();
        await pump(tester, repository);
        await toCreate(tester);
        await fill(
          tester,
          'a@example.com',
          passphrase,
          again: 'my unique passphrasf',
        );
        expect(
          field(tester, repeat).decoration!.errorText,
          'The passwords do not match.',
        );

        await tap(tester, submit);
        expect(repository.createCalls, 0);

        await tester.enterText(repeat, passphrase);
        await tester.pump();
        expect(field(tester, repeat).decoration!.errorText, isNull);
      });

      testWidgets('is not flagged while it is still a prefix being typed', (
        tester,
      ) async {
        await pump(tester, _FakeSyncRepository());
        await toCreate(tester);
        await fill(tester, 'a@example.com', passphrase, again: 'my uni');
        expect(field(tester, repeat).decoration!.errorText, isNull);
      });

      testWidgets('compares exactly: surrounding spaces still count', (
        tester,
      ) async {
        final repository = _FakeSyncRepository();
        await pump(tester, repository);
        await toCreate(tester);
        await fill(tester, 'a@example.com', ' $passphrase ', again: passphrase);
        await tap(tester, submit);
        expect(repository.createCalls, 0);
        expect(
          field(tester, repeat).decoration!.errorText,
          'The passwords do not match.',
        );
      });

      testWidgets('matching passwords send only the original, untrimmed, and '
          'both fields are cleared', (tester) async {
        final repository = _FakeSyncRepository();
        await pump(tester, repository);
        await toCreate(tester);
        await fill(tester, 'a@example.com', ' $passphrase ');

        await tap(tester, submit);

        expect(repository.createCalls, 1);
        expect(repository.createdWith, ' $passphrase ');
        expect(
          find.byKey(const ValueKey('sync-account-created')),
          findsOneWidget,
        );
      });

      testWidgets('a failed attempt clears both passwords', (tester) async {
        final repository = _FakeSyncRepository()
          ..createFailure = SyncAuthFailure.offline;
        await pump(tester, repository);
        await toCreate(tester);
        await fill(tester, 'a@example.com', passphrase);

        await tap(tester, submit);

        expect(repository.createCalls, 1);
        expect(field(tester, password).controller!.text, isEmpty);
        expect(field(tester, repeat).controller!.text, isEmpty);
        expect(field(tester, email).controller!.text, 'a@example.com');
      });

      testWidgets('leaving registration clears both passwords', (tester) async {
        await pump(tester, _FakeSyncRepository());
        await toCreate(tester);
        await fill(tester, 'a@example.com', passphrase);

        await tap(tester, modeSwitch);
        expect(field(tester, password).controller!.text, isEmpty);
        expect(field(tester, email).controller!.text, 'a@example.com');

        await toCreate(tester);
        expect(field(tester, password).controller!.text, isEmpty);
        expect(field(tester, repeat).controller!.text, isEmpty);
      });

      testWidgets('keyboard: next moves from password to repeat', (
        tester,
      ) async {
        await pump(tester, _FakeSyncRepository());
        await toCreate(tester);
        await tester.tap(password);
        await tester.enterText(password, passphrase);
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump();
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: repeat,
                  matching: find.byType(EditableText),
                ),
              )
              .focusNode
              .hasFocus,
          isTrue,
        );
      });
    });

    for (final (failure, message) in [
      (
        SyncAuthFailure.invalidCredentials,
        'That email and password did not match an account.',
      ),
      (
        SyncAuthFailure.offline,
        'Could not reach the sync service. Check your connection and try '
            'again.',
      ),
      (
        SyncAuthFailure.throttled,
        'Too many attempts from this network. Wait a while, then try again.',
      ),
      (SyncAuthFailure.unknown, 'Something went wrong. Try again.'),
    ]) {
      testWidgets('sign-in failure $failure has its own message', (
        tester,
      ) async {
        await pump(tester, _FakeSyncRepository()..signInFailure = failure);
        await fill(tester, 'a@example.com', 'pw');

        await tap(tester, submit);

        expect(
          find.descendant(of: notice, matching: find.text(message)),
          findsOneWidget,
        );
        expect(field(tester, email).decoration!.errorText, isNull);
        expect(field(tester, password).decoration!.errorText, isNull);
      });
    }

    testWidgets('signing in swaps the form for the account controls', (
      tester,
    ) async {
      final repository = _FakeSyncRepository();
      await pump(tester, repository);
      await fill(tester, 'a@example.com', 'pw');

      await tap(tester, submit);

      expect(repository.signInCalls, 1);
      expect(find.text('a@example.com'), findsOneWidget);
      expect(find.byKey(const ValueKey('sync-enabled-switch')), findsOneWidget);
      expect(find.byKey(const ValueKey('sync-email-field')), findsNothing);
      expect(find.byKey(const ValueKey('sync-account-created')), findsNothing);
    });

    testWidgets('keyboard: next moves to the password, done submits', (
      tester,
    ) async {
      final repository = _FakeSyncRepository();
      await pump(tester, repository);
      await tester.tap(email);
      await tester.enterText(email, 'a@example.com');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: password,
                matching: find.byType(EditableText),
              ),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.enterText(password, 'pw');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(repository.signInCalls, 1);
    });

    testWidgets('fits a small phone at 200% text in both modes with errors', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncRepositoryProvider.overrideWithValue(
              _FakeSyncRepository()..signInFailure = SyncAuthFailure.throttled,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const Scaffold(
              body: SingleChildScrollView(child: SyncAccountCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await fill(tester, 'a@example.com', 'pw');
      await tap(tester, submit);
      await toCreate(tester);
      await tap(tester, submit);

      expect(tester.takeException(), isNull);
      final button = tester.getSize(submit);
      expect(button.height, greaterThanOrEqualTo(48));
      expect(tester.getSize(modeSwitch).height, greaterThanOrEqualTo(48));
    });
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

  group('account deletion', () {
    _FakeSyncRepository signedIn() => _FakeSyncRepository()
      ..signedIn = true
      ..email = 'a@example.com'
      ..enabled = true;

    Future<void> openDialog(WidgetTester tester) async {
      await tester.ensureVisible(
        find.byKey(const ValueKey('sync-delete-account-button')),
      );
      await tester.tap(
        find.byKey(const ValueKey('sync-delete-account-button')),
      );
      await tester.pumpAndSettle();
    }

    FilledButton confirmButton(WidgetTester tester) =>
        tester.widget(find.byKey(const ValueKey('sync-delete-confirm-button')));

    Future<void> typePassword(WidgetTester tester, String password) async {
      await tester.enterText(
        find.byKey(const ValueKey('sync-delete-password-field')),
        password,
      );
      await tester.pump();
    }

    Future<void> acknowledge(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('sync-delete-acknowledge')));
      await tester.pump();
    }

    Future<void> confirm(WidgetTester tester) async {
      await tester.tap(
        find.byKey(const ValueKey('sync-delete-confirm-button')),
      );
      await tester.pumpAndSettle();
    }

    final dialog = find.byType(AlertDialog);

    testWidgets('sits in a separate danger zone below the routine controls', (
      tester,
    ) async {
      await pump(tester, signedIn());
      final zone = find.byKey(const ValueKey('sync-danger-zone'));
      expect(
        find.descendant(of: zone, matching: find.text('Danger zone')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: zone,
          matching: find.byKey(const ValueKey('sync-delete-account-button')),
        ),
        findsOneWidget,
      );
      final signOut = find.byKey(const ValueKey('sync-sign-out-button'));
      expect(
        tester.getTopLeft(zone).dy,
        greaterThan(tester.getBottomLeft(signOut).dy),
      );
    });

    testWidgets('explains what is deleted and needs the password first', (
      tester,
    ) async {
      final repository = signedIn();
      await pump(tester, repository);

      await openDialog(tester);

      Finder inDialog(String text) =>
          find.descendant(of: dialog, matching: find.textContaining(text));
      expect(find.text('Delete your FocusTrace account?'), findsOneWidget);
      expect(
        inDialog('permanently deletes your FocusTrace cloud account'),
        findsOneWidget,
      );
      expect(inDialog('synced to the server'), findsOneWidget);
      expect(inDialog('cannot be undone'), findsOneWidget);
      expect(inDialog('Usage history on this device stays'), findsOneWidget);
      expect(inDialog('sync will be turned off'), findsOneWidget);
      expect(
        inDialog('I understand this permanently deletes my cloud account.'),
        findsOneWidget,
      );
      // Opening the dialog did nothing; confirming needs both inputs.
      expect(repository.deletedWith, isNull);
      expect(confirmButton(tester).onPressed, isNull);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('sync-delete-acknowledge')),
            )
            .value,
        isFalse,
      );

      await typePassword(tester, 'current-password');
      expect(confirmButton(tester).onPressed, isNull, reason: 'not ticked');

      await acknowledge(tester);
      expect(confirmButton(tester).onPressed, isNotNull);

      await typePassword(tester, '');
      expect(confirmButton(tester).onPressed, isNull, reason: 'no password');
      expect(repository.deleteCalls, 0);
    });

    testWidgets('cancel deletes nothing', (tester) async {
      final repository = signedIn();
      await pump(tester, repository);
      await openDialog(tester);
      await typePassword(tester, 'current-password');

      await acknowledge(tester);

      await tester.tap(find.byKey(const ValueKey('sync-delete-cancel-button')));
      await tester.pumpAndSettle();

      expect(dialog, findsNothing);
      expect(repository.deleteCalls, 0);
      expect(find.text('a@example.com'), findsOneWidget);
    });

    testWidgets('dismissing by the barrier or back deletes nothing', (
      tester,
    ) async {
      final repository = signedIn();
      await pump(tester, repository);
      await openDialog(tester);
      await typePassword(tester, 'current-password');
      await acknowledge(tester);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);

      await openDialog(tester);
      // The previous dialog's input did not survive it.
      expect(confirmButton(tester).onPressed, isNull);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);

      expect(repository.deleteCalls, 0);
      expect(find.text('a@example.com'), findsOneWidget);
    });

    testWidgets('shows progress, ignores repeat taps and cannot be dismissed '
        'while the request is in flight', (tester) async {
      final repository = signedIn()..deleteHold = Completer<void>();
      await pump(tester, repository);
      await openDialog(tester);
      await typePassword(tester, 'current-password');
      await acknowledge(tester);

      await tester.tap(
        find.byKey(const ValueKey('sync-delete-confirm-button')),
      );
      await tester.pump();

      expect(find.text('Deleting…'), findsOneWidget);
      expect(confirmButton(tester).onPressed, isNull);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('sync-delete-cancel-button')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.byKey(const ValueKey('sync-delete-confirm-button')),
        warnIfMissed: false,
      );
      await tester.tapAt(const Offset(4, 4));
      await tester.pump();
      expect(dialog, findsOneWidget);
      // Nothing claims success before the server answers.
      expect(find.byKey(const ValueKey('sync-account-deleted')), findsNothing);

      repository.deleteHold!.complete();
      await tester.pumpAndSettle();
      expect(repository.deleteCalls, 1);
      expect(dialog, findsNothing);
      expect(
        find.byKey(const ValueKey('sync-account-deleted')),
        findsOneWidget,
      );
    });

    testWidgets('confirming deletes with the typed password and signs out', (
      tester,
    ) async {
      final repository = signedIn();
      await pump(tester, repository);
      await openDialog(tester);
      await typePassword(tester, 'current-password');
      await acknowledge(tester);

      await confirm(tester);

      expect(repository.deletedWith, 'current-password');
      expect(dialog, findsNothing);
      expect(
        find.byKey(const ValueKey('sync-account-deleted')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('sync-email-field')), findsOneWidget);
      expect(find.text('a@example.com'), findsNothing);
    });

    testWidgets('a wrong password says so and keeps the account', (
      tester,
    ) async {
      final repository = signedIn()
        ..deleteFailure = SyncAuthFailure.invalidCredentials;
      await pump(tester, repository);
      await openDialog(tester);
      await typePassword(tester, 'wrong-password');
      await acknowledge(tester);

      await confirm(tester);

      // Stays open so the password can be retyped; the field says why.
      expect(dialog, findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('sync-delete-password-field')),
      );
      expect(
        field.decoration!.errorText,
        'That password is not correct. Your account was not deleted.',
      );
      expect(field.controller!.text, isEmpty);
      expect(confirmButton(tester).onPressed, isNull);
      expect(find.byKey(const ValueKey('sync-account-deleted')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('sync-delete-cancel-button')));
      await tester.pumpAndSettle();
      expect(find.text('a@example.com'), findsOneWidget);
      // The dialog's error does not linger on the card.
      expect(find.textContaining('password is not correct'), findsNothing);
    });

    testWidgets('a connection failure says so and keeps the account', (
      tester,
    ) async {
      final repository = signedIn()..deleteFailure = SyncAuthFailure.offline;
      await pump(tester, repository);
      await openDialog(tester);
      await typePassword(tester, 'current-password');
      await acknowledge(tester);

      await confirm(tester);

      expect(dialog, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('sync-delete-error')),
          matching: find.textContaining('Could not reach the sync service'),
        ),
        findsOneWidget,
      );
      // Retrying is one tap: the password and acknowledgment stay.
      expect(confirmButton(tester).onPressed, isNotNull);
      expect(find.byKey(const ValueKey('sync-account-deleted')), findsNothing);
      expect(repository.signedIn, isTrue);
    });

    testWidgets('fits a small phone at 200% text', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncRepositoryProvider.overrideWithValue(
              signedIn()..deleteFailure = SyncAuthFailure.offline,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const Scaffold(
              body: SingleChildScrollView(child: SyncAccountCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openDialog(tester);
      await typePassword(tester, 'current-password');
      await tester.ensureVisible(
        find.byKey(const ValueKey('sync-delete-acknowledge')),
      );
      await acknowledge(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('sync-delete-confirm-button')),
      );
      await confirm(tester);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('sync-delete-error')), findsOneWidget);
    });
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
  SyncAuthFailure? deleteFailure;
  SyncAuthFailure? createFailure;
  SyncAuthFailure? signInFailure;
  int createCalls = 0;
  String? createdWith;
  int deleteCalls = 0;

  /// When set, account deletion waits for it to complete.
  Completer<void>? deleteHold;

  /// When set, sign-in and account creation wait for it to complete.
  Completer<void>? hold;
  String? deletedWith;

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
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    await hold?.future;
    if (signInFailure != null) throw SyncAuthException(signInFailure!);
    signedIn = true;
    this.email = email;
  }

  @override
  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    createCalls++;
    createdWith = password;
    await hold?.future;
    if (createFailure != null) throw SyncAuthException(createFailure!);
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
  Future<void> deleteAccount({required String password}) async {
    deleteCalls++;
    deletedWith = password;
    await deleteHold?.future;
    if (deleteFailure != null) {
      throw SyncAuthException(deleteFailure!);
    }
    signedIn = false;
    email = null;
    enabled = false;
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
