import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ja'),
    Locale('pt'),
    Locale('uk'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'FocusTrace'**
  String get appTitle;

  /// No description provided for @durationLessThanOneMinute.
  ///
  /// In en, this message translates to:
  /// **'<1m'**
  String get durationLessThanOneMinute;

  /// No description provided for @durationMinutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String durationMinutesShort(int minutes);

  /// No description provided for @durationHoursShort.
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String durationHoursShort(int hours);

  /// No description provided for @durationHoursMinutesShort.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String durationHoursMinutesShort(int hours, int minutes);

  /// No description provided for @categoryEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get categoryEntertainment;

  /// No description provided for @categoryProductivity.
  ///
  /// In en, this message translates to:
  /// **'Productivity'**
  String get categoryProductivity;

  /// No description provided for @categoryWeb.
  ///
  /// In en, this message translates to:
  /// **'Web'**
  String get categoryWeb;

  /// No description provided for @categoryCommunication.
  ///
  /// In en, this message translates to:
  /// **'Communication'**
  String get categoryCommunication;

  /// No description provided for @categorySystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get categorySystem;

  /// No description provided for @categoryActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get categoryActivity;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingContinue;

  /// No description provided for @onboardingStartSoftBlocks.
  ///
  /// In en, this message translates to:
  /// **'Start soft blocks'**
  String get onboardingStartSoftBlocks;

  /// No description provided for @onboardingChooseLater.
  ///
  /// In en, this message translates to:
  /// **'Choose later'**
  String get onboardingChooseLater;

  /// No description provided for @onboardingChooseWhatToLimit.
  ///
  /// In en, this message translates to:
  /// **'Choose what to limit'**
  String get onboardingChooseWhatToLimit;

  /// No description provided for @onboardingChooseWhatToLimitDescription.
  ///
  /// In en, this message translates to:
  /// **'Select apps and set a daily target for soft blocks.'**
  String get onboardingChooseWhatToLimitDescription;

  /// No description provided for @onboardingNoAppsToChooseTitle.
  ///
  /// In en, this message translates to:
  /// **'No apps to choose yet'**
  String get onboardingNoAppsToChooseTitle;

  /// No description provided for @onboardingNoAppsToChooseBody.
  ///
  /// In en, this message translates to:
  /// **'FocusTrace needs current usage data before it can show apps here. You can skip setup and add restrictions later from Settings.'**
  String get onboardingNoAppsToChooseBody;

  /// No description provided for @onboardingNoMatchingAppsTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching apps'**
  String get onboardingNoMatchingAppsTitle;

  /// No description provided for @onboardingNoMatchingAppsBody.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term.'**
  String get onboardingNoMatchingAppsBody;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Take back your screen time'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Understand where your attention goes.\nSet gentle limits.\nBuild better habits at your pace.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Give FocusTrace access'**
  String get onboardingAccessTitle;

  /// No description provided for @onboardingAccessBody.
  ///
  /// In en, this message translates to:
  /// **'FocusTrace needs two permissions to work.\nEverything stays on your device.'**
  String get onboardingAccessBody;

  /// No description provided for @onboardingNoPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to grant here'**
  String get onboardingNoPermissionsTitle;

  /// No description provided for @onboardingNoPermissionsBody.
  ///
  /// In en, this message translates to:
  /// **'These permissions are only needed on Android.'**
  String get onboardingNoPermissionsBody;

  /// No description provided for @onboardingUsageAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Usage access'**
  String get onboardingUsageAccessTitle;

  /// No description provided for @onboardingUsageAccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'To measure your app time'**
  String get onboardingUsageAccessSubtitle;

  /// No description provided for @onboardingOverlayAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Display over other apps'**
  String get onboardingOverlayAccessTitle;

  /// No description provided for @onboardingOverlayAccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'To show the block screen over apps you limit'**
  String get onboardingOverlayAccessSubtitle;

  /// No description provided for @onboardingPermissionsSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'You can change this later in settings.'**
  String get onboardingPermissionsSettingsHint;

  /// No description provided for @onboardingAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get onboardingAllow;

  /// No description provided for @onboardingSearchApps.
  ///
  /// In en, this message translates to:
  /// **'Search apps'**
  String get onboardingSearchApps;

  /// No description provided for @onboardingAppUsageToday.
  ///
  /// In en, this message translates to:
  /// **'{appKey} · {duration} today'**
  String onboardingAppUsageToday(String appKey, String duration);

  /// No description provided for @onboardingDailyTarget.
  ///
  /// In en, this message translates to:
  /// **'Daily target'**
  String get onboardingDailyTarget;

  /// No description provided for @restrictionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Restrictions'**
  String get restrictionsTitle;

  /// No description provided for @restrictionsSearchApps.
  ///
  /// In en, this message translates to:
  /// **'Search apps'**
  String get restrictionsSearchApps;

  /// No description provided for @restrictionsAddRestriction.
  ///
  /// In en, this message translates to:
  /// **'Add restriction'**
  String get restrictionsAddRestriction;

  /// No description provided for @restrictionsAddRoutine.
  ///
  /// In en, this message translates to:
  /// **'New routine'**
  String get restrictionsAddRoutine;

  /// No description provided for @restrictionsRoutinesTitle.
  ///
  /// In en, this message translates to:
  /// **'Block routines'**
  String get restrictionsRoutinesTitle;

  /// No description provided for @restrictionsRoutinesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No block routines'**
  String get restrictionsRoutinesEmptyTitle;

  /// No description provided for @restrictionsRoutinesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Group apps into a routine, then switch the whole group on or off.'**
  String get restrictionsRoutinesEmptyBody;

  /// No description provided for @restrictionsIndividualRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Individual restrictions'**
  String get restrictionsIndividualRulesTitle;

  /// No description provided for @restrictionsRoutineAppCount.
  ///
  /// In en, this message translates to:
  /// **'{count} apps'**
  String restrictionsRoutineAppCount(int count);

  /// No description provided for @restrictionsDeleteRoutine.
  ///
  /// In en, this message translates to:
  /// **'Delete routine'**
  String get restrictionsDeleteRoutine;

  /// No description provided for @routineEditorNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New block routine'**
  String get routineEditorNewTitle;

  /// No description provided for @routineEditorEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit block routine'**
  String get routineEditorEditTitle;

  /// No description provided for @routineEditorName.
  ///
  /// In en, this message translates to:
  /// **'Routine name'**
  String get routineEditorName;

  /// No description provided for @routineEditorSearchApps.
  ///
  /// In en, this message translates to:
  /// **'Search apps'**
  String get routineEditorSearchApps;

  /// No description provided for @routineEditorNoMatchingApps.
  ///
  /// In en, this message translates to:
  /// **'No matching apps'**
  String get routineEditorNoMatchingApps;

  /// No description provided for @routineEditorSave.
  ///
  /// In en, this message translates to:
  /// **'Save routine'**
  String get routineEditorSave;

  /// No description provided for @restrictionsPlatformStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Status only on this platform'**
  String get restrictionsPlatformStatusTitle;

  /// No description provided for @restrictionsPlatformStatusBody.
  ///
  /// In en, this message translates to:
  /// **'Rules are saved and shown here. Full-screen blocking currently runs only on Android.'**
  String get restrictionsPlatformStatusBody;

  /// No description provided for @restrictionsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No app restrictions'**
  String get restrictionsEmptyTitle;

  /// No description provided for @restrictionsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Long-press an app in the usage bubbles or current list to add a rule.'**
  String get restrictionsEmptyBody;

  /// No description provided for @restrictionsNoAppsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No apps available yet. Open the dashboard after usage data is available, then search here.'**
  String get restrictionsNoAppsAvailable;

  /// No description provided for @restrictionsNoMatchingApps.
  ///
  /// In en, this message translates to:
  /// **'No matching apps'**
  String get restrictionsNoMatchingApps;

  /// No description provided for @restrictionsDeleteRule.
  ///
  /// In en, this message translates to:
  /// **'Delete rule'**
  String get restrictionsDeleteRule;

  /// No description provided for @restrictionsUnblockNow.
  ///
  /// In en, this message translates to:
  /// **'Unblock now'**
  String get restrictionsUnblockNow;

  /// No description provided for @restrictionsBlockedUntil.
  ///
  /// In en, this message translates to:
  /// **'Blocked until {time}'**
  String restrictionsBlockedUntil(String time);

  /// No description provided for @restrictionsTemporaryBlockExpired.
  ///
  /// In en, this message translates to:
  /// **'Temporary block expired'**
  String get restrictionsTemporaryBlockExpired;

  /// No description provided for @restrictionsDailyLimitStatus.
  ///
  /// In en, this message translates to:
  /// **'Daily limit {limitDuration} · {usedDuration} used'**
  String restrictionsDailyLimitStatus(
    String limitDuration,
    String usedDuration,
  );

  /// No description provided for @restrictionsScheduleStatus.
  ///
  /// In en, this message translates to:
  /// **'Schedule {startTime}–{endTime}'**
  String restrictionsScheduleStatus(String startTime, String endTime);

  /// No description provided for @restrictionsOverlayPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Overlay permission required'**
  String get restrictionsOverlayPermissionTitle;

  /// No description provided for @restrictionsOverlayPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'Android needs Display over other apps permission before FocusTrace can show a block screen.'**
  String get restrictionsOverlayPermissionBody;

  /// No description provided for @restrictionsOpenOverlaySettings.
  ///
  /// In en, this message translates to:
  /// **'Open Overlay Settings'**
  String get restrictionsOpenOverlaySettings;

  /// No description provided for @restrictionsRecheck.
  ///
  /// In en, this message translates to:
  /// **'Recheck'**
  String get restrictionsRecheck;

  /// No description provided for @restrictionEditorAllowFullScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow full-screen blocking?'**
  String get restrictionEditorAllowFullScreenTitle;

  /// No description provided for @restrictionEditorAllowFullScreenBody.
  ///
  /// In en, this message translates to:
  /// **'FocusTrace needs Display over other apps permission to show a block screen when a restricted app opens.'**
  String get restrictionEditorAllowFullScreenBody;

  /// No description provided for @restrictionEditorLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get restrictionEditorLater;

  /// No description provided for @restrictionEditorOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get restrictionEditorOpenSettings;

  /// No description provided for @restrictionEditorTypeNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get restrictionEditorTypeNow;

  /// No description provided for @restrictionEditorTypeLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get restrictionEditorTypeLimit;

  /// No description provided for @restrictionEditorTypeSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get restrictionEditorTypeSchedule;

  /// No description provided for @restrictionEditorSaveRule.
  ///
  /// In en, this message translates to:
  /// **'Save rule'**
  String get restrictionEditorSaveRule;

  /// No description provided for @restrictionEditorTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get restrictionEditorTomorrow;

  /// No description provided for @restrictionEditorDailyLimitPerDay.
  ///
  /// In en, this message translates to:
  /// **'{duration} per day'**
  String restrictionEditorDailyLimitPerDay(String duration);

  /// No description provided for @dashboardDayTracked.
  ///
  /// In en, this message translates to:
  /// **'Tracked · {duration}'**
  String dashboardDayTracked(String duration);

  /// No description provided for @dashboardDayToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dashboardDayToday;

  /// No description provided for @dashboardDayYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dashboardDayYesterday;

  /// No description provided for @dashboardPreviousDayTooltip.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get dashboardPreviousDayTooltip;

  /// No description provided for @dashboardNextDayTooltip.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get dashboardNextDayTooltip;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @trackingRunsWhileOpen.
  ///
  /// In en, this message translates to:
  /// **'Tracking runs only while FocusTrace is open.'**
  String get trackingRunsWhileOpen;

  /// No description provided for @dashboardStopTracking.
  ///
  /// In en, this message translates to:
  /// **'Stop Tracking'**
  String get dashboardStopTracking;

  /// No description provided for @dashboardStartTracking.
  ///
  /// In en, this message translates to:
  /// **'Start Tracking'**
  String get dashboardStartTracking;

  /// No description provided for @dashboardNoUsageToday.
  ///
  /// In en, this message translates to:
  /// **'No usage recorded for today.'**
  String get dashboardNoUsageToday;

  /// No description provided for @dashboardNoUsageDay.
  ///
  /// In en, this message translates to:
  /// **'No usage recorded for this day.'**
  String get dashboardNoUsageDay;

  /// No description provided for @dashboardAllTimeMostUsedTitle.
  ///
  /// In en, this message translates to:
  /// **'Most used of all time'**
  String get dashboardAllTimeMostUsedTitle;

  /// No description provided for @dashboardUnsupportedPlatform.
  ///
  /// In en, this message translates to:
  /// **'FocusTrace MVP supports Android and Windows. Other platforms can be added later through isolated platform data sources.'**
  String get dashboardUnsupportedPlatform;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get commonUnexpectedError;

  /// No description provided for @usageBubblesTitle.
  ///
  /// In en, this message translates to:
  /// **'Usage Bubbles'**
  String get usageBubblesTitle;

  /// No description provided for @usageBubblesDescription.
  ///
  /// In en, this message translates to:
  /// **'Bigger bubbles mean more time spent'**
  String get usageBubblesDescription;

  /// No description provided for @usageBubblesCurrentList.
  ///
  /// In en, this message translates to:
  /// **'Current list'**
  String get usageBubblesCurrentList;

  /// No description provided for @actionUnblockNow.
  ///
  /// In en, this message translates to:
  /// **'Unblock now'**
  String get actionUnblockNow;

  /// No description provided for @actionUnblockNowDescription.
  ///
  /// In en, this message translates to:
  /// **'Remove active blocking rules'**
  String get actionUnblockNowDescription;

  /// No description provided for @actionRestrictApp.
  ///
  /// In en, this message translates to:
  /// **'Restrict app...'**
  String get actionRestrictApp;

  /// No description provided for @actionRestrictAppDescription.
  ///
  /// In en, this message translates to:
  /// **'Block now, set a limit, or add a schedule'**
  String get actionRestrictAppDescription;

  /// No description provided for @percentageValue.
  ///
  /// In en, this message translates to:
  /// **'{percentage}%'**
  String percentageValue(String percentage);

  /// No description provided for @actionRemoveFromToday.
  ///
  /// In en, this message translates to:
  /// **'Remove from today'**
  String get actionRemoveFromToday;

  /// No description provided for @actionRemoveFromTodayDescription.
  ///
  /// In en, this message translates to:
  /// **'Hide this app from today\'s stats'**
  String get actionRemoveFromTodayDescription;

  /// No description provided for @actionExcludeFromTracking.
  ///
  /// In en, this message translates to:
  /// **'Exclude from tracking'**
  String get actionExcludeFromTracking;

  /// No description provided for @actionExcludeFromTrackingDescription.
  ///
  /// In en, this message translates to:
  /// **'Stop tracking and hide from all stats'**
  String get actionExcludeFromTrackingDescription;

  /// No description provided for @excludeAppDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Exclude {appName}?'**
  String excludeAppDialogTitle(String appName);

  /// No description provided for @excludeAppDialogBody.
  ///
  /// In en, this message translates to:
  /// **'The app will no longer be tracked or shown in stats. You can undo this from Settings.'**
  String get excludeAppDialogBody;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @actionExclude.
  ///
  /// In en, this message translates to:
  /// **'Exclude'**
  String get actionExclude;

  /// No description provided for @sessionTotal.
  ///
  /// In en, this message translates to:
  /// **'Total · {duration}'**
  String sessionTotal(String duration);

  /// No description provided for @sessionDetailsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Session details not available on this platform.'**
  String get sessionDetailsUnavailable;

  /// No description provided for @sessionNoneRecorded.
  ///
  /// In en, this message translates to:
  /// **'No sessions recorded.'**
  String get sessionNoneRecorded;

  /// No description provided for @sessionLongestTitle.
  ///
  /// In en, this message translates to:
  /// **'Longest sessions'**
  String get sessionLongestTitle;

  /// No description provided for @sessionOngoingLabel.
  ///
  /// In en, this message translates to:
  /// **'{startTime} · {duration}'**
  String sessionOngoingLabel(String startTime, String duration);

  /// No description provided for @sessionRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'{startTime} – {endTime} · {duration}'**
  String sessionRangeLabel(String startTime, String endTime, String duration);

  /// No description provided for @permissionWindowsPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Windows privacy'**
  String get permissionWindowsPrivacyTitle;

  /// No description provided for @permissionUsageAccessRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Usage Access required'**
  String get permissionUsageAccessRequiredTitle;

  /// No description provided for @permissionUsageAccessRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'FocusTrace needs Android Usage Access to read your own app usage. Data stays local on this device.'**
  String get permissionUsageAccessRequiredBody;

  /// No description provided for @permissionOpenUsageAccessSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Usage Access Settings'**
  String get permissionOpenUsageAccessSettings;

  /// No description provided for @commonRecheck.
  ///
  /// In en, this message translates to:
  /// **'Recheck'**
  String get commonRecheck;

  /// No description provided for @trackingWindowsRunning.
  ///
  /// In en, this message translates to:
  /// **'Windows tracking is running while FocusTrace is open.'**
  String get trackingWindowsRunning;

  /// No description provided for @trackingWindowsIdle.
  ///
  /// In en, this message translates to:
  /// **'Windows tracking runs only while FocusTrace is open.'**
  String get trackingWindowsIdle;

  /// No description provided for @trackingAndroidUsageAccess.
  ///
  /// In en, this message translates to:
  /// **'Android usage is read from Usage Access.'**
  String get trackingAndroidUsageAccess;

  /// No description provided for @trackingUnsupportedPlatform.
  ///
  /// In en, this message translates to:
  /// **'Usage tracking is not supported on this platform yet.'**
  String get trackingUnsupportedPlatform;

  /// No description provided for @trackingError.
  ///
  /// In en, this message translates to:
  /// **'Tracking ran into a problem. It will retry automatically.'**
  String get trackingError;

  /// No description provided for @bubblePercentageOfToday.
  ///
  /// In en, this message translates to:
  /// **'{percentage}% of today'**
  String bubblePercentageOfToday(String percentage);

  /// No description provided for @usageBubbleSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'{appName}, {category}'**
  String usageBubbleSemanticsLabel(String appName, String category);

  /// No description provided for @usageBubbleNearLimitSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'{appName}, {category}, daily limit almost reached'**
  String usageBubbleNearLimitSemanticsLabel(String appName, String category);

  /// No description provided for @summaryLaunchCount.
  ///
  /// In en, this message translates to:
  /// **'Launches: {count}'**
  String summaryLaunchCount(int count);

  /// No description provided for @usageTrendDayShort.
  ///
  /// In en, this message translates to:
  /// **'D'**
  String get usageTrendDayShort;

  /// No description provided for @usageTrendWeekShort.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get usageTrendWeekShort;

  /// No description provided for @usageTrendMonthShort.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get usageTrendMonthShort;

  /// No description provided for @usageTrendIncrease.
  ///
  /// In en, this message translates to:
  /// **'{period}: usage increased by {percentage}%'**
  String usageTrendIncrease(String period, int percentage);

  /// No description provided for @usageTrendDecrease.
  ///
  /// In en, this message translates to:
  /// **'{period}: usage decreased by {percentage}%'**
  String usageTrendDecrease(String period, int percentage);

  /// No description provided for @usageTrendUnchanged.
  ///
  /// In en, this message translates to:
  /// **'{period}: usage unchanged'**
  String usageTrendUnchanged(String period);

  /// No description provided for @usageDetailsLastSevenDays.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get usageDetailsLastSevenDays;

  /// No description provided for @usageDetailsMoreThanYesterday.
  ///
  /// In en, this message translates to:
  /// **'{percentage}% more than yesterday'**
  String usageDetailsMoreThanYesterday(int percentage);

  /// No description provided for @usageDetailsLessThanYesterday.
  ///
  /// In en, this message translates to:
  /// **'{percentage}% less than yesterday'**
  String usageDetailsLessThanYesterday(int percentage);

  /// No description provided for @usageDetailsSameAsYesterday.
  ///
  /// In en, this message translates to:
  /// **'Same as yesterday'**
  String get usageDetailsSameAsYesterday;

  /// No description provided for @usageDetailsNoYesterdayComparison.
  ///
  /// In en, this message translates to:
  /// **'No yesterday comparison yet'**
  String get usageDetailsNoYesterdayComparison;

  /// No description provided for @usageDetailsRankLabel.
  ///
  /// In en, this message translates to:
  /// **'#{rank} most used'**
  String usageDetailsRankLabel(int rank);

  /// No description provided for @usageDetailsRankLead.
  ///
  /// In en, this message translates to:
  /// **'{duration} more than {appName}'**
  String usageDetailsRankLead(String duration, String appName);

  /// No description provided for @usageDetailsDayValue.
  ///
  /// In en, this message translates to:
  /// **'{date}: {duration}'**
  String usageDetailsDayValue(String date, String duration);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacyTitle;

  /// No description provided for @settingsPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'FocusTrace stores usage data locally on this device. It does not upload tracked app or window usage.'**
  String get settingsPrivacyBody;

  /// No description provided for @settingsClearLocalData.
  ///
  /// In en, this message translates to:
  /// **'Clear local data'**
  String get settingsClearLocalData;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystemDefault;

  /// No description provided for @settingsChooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get settingsChooseLanguage;

  /// No description provided for @settingsLanguageUpdateError.
  ///
  /// In en, this message translates to:
  /// **'The language preference could not be applied. Please try again.'**
  String get settingsLanguageUpdateError;

  /// No description provided for @settingsExcludedAppsTitle.
  ///
  /// In en, this message translates to:
  /// **'Excluded apps'**
  String get settingsExcludedAppsTitle;

  /// No description provided for @settingsExcludedAppsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No excluded apps. Long-press an app on the dashboard to exclude it from tracking.'**
  String get settingsExcludedAppsEmpty;

  /// No description provided for @settingsStopExcluding.
  ///
  /// In en, this message translates to:
  /// **'Stop excluding'**
  String get settingsStopExcluding;

  /// No description provided for @settingsWindowsTrackingComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon: Windows tracking'**
  String get settingsWindowsTrackingComingSoon;

  /// No description provided for @settingsSendFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get settingsSendFeedback;

  /// No description provided for @settingsWindowsTrackingInterval.
  ///
  /// In en, this message translates to:
  /// **'Windows tracking interval'**
  String get settingsWindowsTrackingInterval;

  /// No description provided for @settingsWindowsIdleTimeout.
  ///
  /// In en, this message translates to:
  /// **'Windows idle timeout'**
  String get settingsWindowsIdleTimeout;

  /// No description provided for @settingsClearDataDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear local data?'**
  String get settingsClearDataDialogTitle;

  /// No description provided for @settingsClearDataDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This removes stored usage sessions and settings from this device. Your language choice is preserved.'**
  String get settingsClearDataDialogBody;

  /// No description provided for @settingsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsCancel;

  /// No description provided for @settingsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get settingsClear;

  /// No description provided for @settingsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsSave;

  /// No description provided for @secondsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 second} other{{count} seconds}}'**
  String secondsCount(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'ja',
    'pt',
    'uk',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ja':
      return AppLocalizationsJa();
    case 'pt':
      return AppLocalizationsPt();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
