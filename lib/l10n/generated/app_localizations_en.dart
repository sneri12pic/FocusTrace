// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'FocusTrace';

  @override
  String get durationLessThanOneMinute => '<1m';

  @override
  String durationMinutesShort(int minutes) {
    return '${minutes}m';
  }

  @override
  String durationHoursShort(int hours) {
    return '${hours}h';
  }

  @override
  String durationHoursMinutesShort(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get categoryEntertainment => 'Entertainment';

  @override
  String get categoryProductivity => 'Productivity';

  @override
  String get categoryWeb => 'Web';

  @override
  String get categoryCommunication => 'Communication';

  @override
  String get categorySystem => 'System';

  @override
  String get categoryActivity => 'Activity';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingGetStarted => 'Get started';

  @override
  String get onboardingContinue => 'Continue';

  @override
  String get onboardingStartSoftBlocks => 'Start soft blocks';

  @override
  String get onboardingChooseLater => 'Choose later';

  @override
  String get onboardingChooseWhatToLimit => 'Choose what to limit';

  @override
  String get onboardingChooseWhatToLimitDescription =>
      'Select apps and set a daily target for soft blocks.';

  @override
  String get onboardingNoAppsToChooseTitle => 'No apps to choose yet';

  @override
  String get onboardingNoAppsToChooseBody =>
      'FocusTrace needs current usage data before it can show apps here. You can skip setup and add restrictions later from Settings.';

  @override
  String get onboardingNoMatchingAppsTitle => 'No matching apps';

  @override
  String get onboardingNoMatchingAppsBody => 'Try a different search term.';

  @override
  String get onboardingWelcomeTitle => 'Take back your screen time';

  @override
  String get onboardingWelcomeBody =>
      'Understand where your attention goes.\nSet gentle limits.\nBuild better habits at your pace.';

  @override
  String get onboardingAccessTitle => 'Give FocusTrace access';

  @override
  String get onboardingAccessBody =>
      'FocusTrace needs two permissions to work.\nEverything stays on your device.';

  @override
  String get onboardingNoPermissionsTitle => 'Nothing to grant here';

  @override
  String get onboardingNoPermissionsBody =>
      'These permissions are only needed on Android.';

  @override
  String get onboardingUsageAccessTitle => 'Usage access';

  @override
  String get onboardingUsageAccessSubtitle => 'To measure your app time';

  @override
  String get onboardingOverlayAccessTitle => 'Display over other apps';

  @override
  String get onboardingOverlayAccessSubtitle =>
      'To show the block screen over apps you limit';

  @override
  String get onboardingPermissionsSettingsHint =>
      'You can change this later in settings.';

  @override
  String get onboardingAllow => 'Allow';

  @override
  String get onboardingSearchApps => 'Search apps';

  @override
  String onboardingAppUsageToday(String appKey, String duration) {
    return '$appKey · $duration today';
  }

  @override
  String get onboardingDailyTarget => 'Daily target';

  @override
  String get restrictionsTitle => 'Restrictions';

  @override
  String get restrictionsSearchApps => 'Search apps';

  @override
  String get restrictionsAddRestriction => 'Add restriction';

  @override
  String get restrictionsAddRoutine => 'New routine';

  @override
  String get restrictionsRoutinesTitle => 'Block routines';

  @override
  String get restrictionsRoutinesEmptyTitle => 'No block routines';

  @override
  String get restrictionsRoutinesEmptyBody =>
      'Group apps into a routine, then switch the whole group on or off.';

  @override
  String get restrictionsIndividualRulesTitle => 'Individual restrictions';

  @override
  String restrictionsRoutineAppCount(int count) {
    return '$count apps';
  }

  @override
  String get restrictionsDeleteRoutine => 'Delete routine';

  @override
  String get routineEditorNewTitle => 'New block routine';

  @override
  String get routineEditorEditTitle => 'Edit block routine';

  @override
  String get routineEditorName => 'Routine name';

  @override
  String get routineEditorSearchApps => 'Search apps';

  @override
  String get routineEditorNoMatchingApps => 'No matching apps';

  @override
  String get routineEditorSave => 'Save routine';

  @override
  String get restrictionsPlatformStatusTitle => 'Status only on this platform';

  @override
  String get restrictionsPlatformStatusBody =>
      'Rules are saved and shown here. Full-screen blocking currently runs only on Android.';

  @override
  String get restrictionsEmptyTitle => 'No app restrictions';

  @override
  String get restrictionsEmptyBody =>
      'Long-press an app in the usage bubbles or current list to add a rule.';

  @override
  String get restrictionsNoAppsAvailable =>
      'No apps available yet. Open the dashboard after usage data is available, then search here.';

  @override
  String get restrictionsNoMatchingApps => 'No matching apps';

  @override
  String get restrictionsDeleteRule => 'Delete rule';

  @override
  String get restrictionsUnblockNow => 'Unblock now';

  @override
  String restrictionsBlockedUntil(String time) {
    return 'Blocked until $time';
  }

  @override
  String get restrictionsTemporaryBlockExpired => 'Temporary block expired';

  @override
  String restrictionsDailyLimitStatus(
    String limitDuration,
    String usedDuration,
  ) {
    return 'Daily limit $limitDuration · $usedDuration used';
  }

  @override
  String restrictionsScheduleStatus(String startTime, String endTime) {
    return 'Schedule $startTime–$endTime';
  }

  @override
  String get restrictionsOverlayPermissionTitle =>
      'Overlay permission required';

  @override
  String get restrictionsOverlayPermissionBody =>
      'Android needs Display over other apps permission before FocusTrace can show a block screen.';

  @override
  String get restrictionsOpenOverlaySettings => 'Open Overlay Settings';

  @override
  String get restrictionsRecheck => 'Recheck';

  @override
  String get restrictionEditorAllowFullScreenTitle =>
      'Allow full-screen blocking?';

  @override
  String get restrictionEditorAllowFullScreenBody =>
      'FocusTrace needs Display over other apps permission to show a block screen when a restricted app opens.';

  @override
  String get restrictionEditorLater => 'Later';

  @override
  String get restrictionEditorOpenSettings => 'Open settings';

  @override
  String get restrictionEditorTypeNow => 'Now';

  @override
  String get restrictionEditorTypeLimit => 'Limit';

  @override
  String get restrictionEditorTypeSchedule => 'Schedule';

  @override
  String get restrictionEditorSaveRule => 'Save rule';

  @override
  String get restrictionEditorTomorrow => 'Tomorrow';

  @override
  String restrictionEditorDailyLimitPerDay(String duration) {
    return '$duration per day';
  }

  @override
  String dashboardDayTracked(String duration) {
    return 'Tracked · $duration';
  }

  @override
  String get dashboardDayToday => 'Today';

  @override
  String get dashboardDayYesterday => 'Yesterday';

  @override
  String get dashboardPreviousDayTooltip => 'Previous day';

  @override
  String get dashboardNextDayTooltip => 'Next day';

  @override
  String get navHome => 'Home';

  @override
  String get trackingRunsWhileOpen =>
      'Tracking runs only while FocusTrace is open.';

  @override
  String get dashboardStopTracking => 'Stop Tracking';

  @override
  String get dashboardStartTracking => 'Start Tracking';

  @override
  String get dashboardNoUsageToday => 'No usage recorded for today.';

  @override
  String get dashboardNoUsageDay => 'No usage recorded for this day.';

  @override
  String get dashboardAllTimeMostUsedTitle => 'Most used of all time';

  @override
  String get dashboardUnsupportedPlatform =>
      'FocusTrace MVP supports Android and Windows. Other platforms can be added later through isolated platform data sources.';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonUnexpectedError => 'Something went wrong. Please try again.';

  @override
  String get usageBubblesTitle => 'Usage Bubbles';

  @override
  String get usageBubblesDescription => 'Bigger bubbles mean more time spent';

  @override
  String get usageBubblesCurrentList => 'Current list';

  @override
  String get actionUnblockNow => 'Unblock now';

  @override
  String get actionUnblockNowDescription => 'Remove active blocking rules';

  @override
  String get actionRestrictApp => 'Restrict app...';

  @override
  String get actionRestrictAppDescription =>
      'Block now, set a limit, or add a schedule';

  @override
  String percentageValue(String percentage) {
    return '$percentage%';
  }

  @override
  String get actionRemoveFromToday => 'Remove from today';

  @override
  String get actionRemoveFromTodayDescription =>
      'Hide this app from today\'s stats';

  @override
  String get actionExcludeFromTracking => 'Exclude from tracking';

  @override
  String get actionExcludeFromTrackingDescription =>
      'Stop tracking and hide from all stats';

  @override
  String excludeAppDialogTitle(String appName) {
    return 'Exclude $appName?';
  }

  @override
  String get excludeAppDialogBody =>
      'The app will no longer be tracked or shown in stats. You can undo this from Settings.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get actionExclude => 'Exclude';

  @override
  String sessionTotal(String duration) {
    return 'Total · $duration';
  }

  @override
  String get sessionDetailsUnavailable =>
      'Session details not available on this platform.';

  @override
  String get sessionNoneRecorded => 'No sessions recorded.';

  @override
  String get sessionLongestTitle => 'Longest sessions';

  @override
  String sessionOngoingLabel(String startTime, String duration) {
    return '$startTime · $duration';
  }

  @override
  String sessionRangeLabel(String startTime, String endTime, String duration) {
    return '$startTime – $endTime · $duration';
  }

  @override
  String get permissionWindowsPrivacyTitle => 'Windows privacy';

  @override
  String get permissionUsageAccessRequiredTitle => 'Usage Access required';

  @override
  String get permissionUsageAccessRequiredBody =>
      'FocusTrace needs Android Usage Access to read your own app usage. Data stays local on this device.';

  @override
  String get permissionOpenUsageAccessSettings => 'Open Usage Access Settings';

  @override
  String get commonRecheck => 'Recheck';

  @override
  String get trackingWindowsRunning =>
      'Windows tracking is running while FocusTrace is open.';

  @override
  String get trackingWindowsIdle =>
      'Windows tracking runs only while FocusTrace is open.';

  @override
  String get trackingAndroidUsageAccess =>
      'Android usage is read from Usage Access.';

  @override
  String get trackingUnsupportedPlatform =>
      'Usage tracking is not supported on this platform yet.';

  @override
  String get trackingError =>
      'Tracking ran into a problem. It will retry automatically.';

  @override
  String bubblePercentageOfToday(String percentage) {
    return '$percentage% of today';
  }

  @override
  String usageBubbleSemanticsLabel(String appName, String category) {
    return '$appName, $category';
  }

  @override
  String usageBubbleNearLimitSemanticsLabel(String appName, String category) {
    return '$appName, $category, daily limit almost reached';
  }

  @override
  String summaryLaunchCount(int count) {
    return 'Launches: $count';
  }

  @override
  String get usageTrendDayShort => 'D';

  @override
  String get usageTrendWeekShort => 'W';

  @override
  String get usageTrendMonthShort => 'M';

  @override
  String usageTrendIncrease(String period, int percentage) {
    return '$period: usage increased by $percentage%';
  }

  @override
  String usageTrendDecrease(String period, int percentage) {
    return '$period: usage decreased by $percentage%';
  }

  @override
  String usageTrendUnchanged(String period) {
    return '$period: usage unchanged';
  }

  @override
  String get usageDetailsLastSevenDays => 'Last 7 days';

  @override
  String usageDetailsMoreThanYesterday(int percentage) {
    return '$percentage% more than yesterday';
  }

  @override
  String usageDetailsLessThanYesterday(int percentage) {
    return '$percentage% less than yesterday';
  }

  @override
  String get usageDetailsSameAsYesterday => 'Same as yesterday';

  @override
  String get usageDetailsNoYesterdayComparison => 'No yesterday comparison yet';

  @override
  String usageDetailsRankLabel(int rank) {
    return '#$rank most used';
  }

  @override
  String usageDetailsRankLead(String duration, String appName) {
    return '$duration more than $appName';
  }

  @override
  String usageDetailsDayValue(String date, String duration) {
    return '$date: $duration';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsPrivacyTitle => 'Privacy';

  @override
  String get settingsPrivacyBody =>
      'FocusTrace stores usage data locally on this device. It does not upload tracked app or window usage.';

  @override
  String get settingsClearLocalData => 'Clear local data';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageSystemDefault => 'System default';

  @override
  String get settingsChooseLanguage => 'Choose language';

  @override
  String get settingsLanguageUpdateError =>
      'The language preference could not be applied. Please try again.';

  @override
  String get settingsExcludedAppsTitle => 'Excluded apps';

  @override
  String get settingsExcludedAppsEmpty =>
      'No excluded apps. Long-press an app on the dashboard to exclude it from tracking.';

  @override
  String get settingsStopExcluding => 'Stop excluding';

  @override
  String get settingsWindowsTrackingComingSoon =>
      'Coming soon: Windows tracking';

  @override
  String get settingsSendFeedback => 'Send feedback';

  @override
  String get settingsWindowsTrackingInterval => 'Windows tracking interval';

  @override
  String get settingsWindowsIdleTimeout => 'Windows idle timeout';

  @override
  String get settingsClearDataDialogTitle => 'Clear local data?';

  @override
  String get settingsClearDataDialogBody =>
      'This removes stored usage sessions and settings from this device. Your language choice is preserved.';

  @override
  String get settingsCancel => 'Cancel';

  @override
  String get settingsClear => 'Clear';

  @override
  String get settingsSave => 'Save';

  @override
  String secondsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
    );
    return '$_temp0';
  }
}
