// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appCategoryAll => 'All';

  @override
  String get appCategoryTitle => 'App category';

  @override
  String get appCategoryAutomatic => 'Automatic';

  @override
  String get appCategorySave => 'Save category';

  @override
  String get appCategorySaveError =>
      'Couldn’t save the category. Please try again.';

  @override
  String get usageDetailsBarChart => 'Bar chart';

  @override
  String get usageDetailsAreaChart => 'Usage trend';

  @override
  String get usageDetailsChartSaveError =>
      'Couldn\'t save your chart choice. Please try again.';

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
      'Android Settings controls the first two permissions.';

  @override
  String get onboardingAllow => 'Allow';

  @override
  String get onboardingOpenSettings => 'Open settings';

  @override
  String get onboardingNotificationsTitle => 'Notifications';

  @override
  String get onboardingNotificationsSubtitle =>
      'Optional: get alerts before reaching a daily limit';

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
  String get routineDailyLimit => 'Daily shared limit';

  @override
  String get routineNoDailyLimit => 'No daily limit';

  @override
  String get routineCustomDuration => 'Custom';

  @override
  String get routineChooseDuration => 'Choose daily limit';

  @override
  String get routineNotFound => 'This routine no longer exists.';

  @override
  String get routineRename => 'Rename routine';

  @override
  String get routineAppsTitle => 'Apps';

  @override
  String get routineAddApp => 'Add app';

  @override
  String routineAppUsage(String duration) {
    return '$duration today · Included in limit';
  }

  @override
  String routineAppUsageExcluded(String duration) {
    return '$duration today · Excluded from limit';
  }

  @override
  String get routineRemoveApp => 'Remove app';

  @override
  String get routineKeepOneApp => 'A routine must keep at least one app.';

  @override
  String routineDeleteConfirmation(String name) {
    return 'Delete $name? This cannot be undone.';
  }

  @override
  String get routineUsageToday => 'Counted usage today';

  @override
  String get routineNoIncludedApps =>
      'Include at least one app to enable the limit';

  @override
  String get routineLimitReached =>
      'Limit reached · included apps are blocked until midnight';

  @override
  String get routineActive => 'Active';

  @override
  String get routinePaused => 'Paused';

  @override
  String routineUsageOfLimit(String used, String limit) {
    return '$used of $limit';
  }

  @override
  String routineRemaining(String duration) {
    return '$duration remaining';
  }

  @override
  String get routineSetLimit => 'Set limit';

  @override
  String get routineEditLimit => 'Edit limit';

  @override
  String get routineRemoveLimit => 'Remove limit';

  @override
  String routineUsageOnly(String duration) {
    return '$duration today';
  }

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
  String get dashboardUsageUnavailableDay =>
      'Usage data is currently unavailable for this day.';

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
  String usageListShowAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show all ($count more)',
      one: 'Show all (1 more)',
    );
    return '$_temp0';
  }

  @override
  String get usageListShowLess => 'Show less';

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
  String get usageTrendNew => 'New';

  @override
  String usageTrendNewLabel(String period) {
    return '$period: new usage, nothing earlier to compare';
  }

  @override
  String usageTrendIncreaseAboveCap(String period, int percentage) {
    return '$period: usage increased by more than $percentage%';
  }

  @override
  String get usageDetailsLastSevenDays => 'Last 7 days';

  @override
  String get usageDetailsTimeTracked => 'Time tracked';

  @override
  String get usageDetailsPeriodSevenDays => '7 days';

  @override
  String get usageDetailsPeriodTwoWeeks => '2 weeks';

  @override
  String get usageDetailsPeriodMonth => 'A month';

  @override
  String get usageDetailsPeriodYear => 'Year';

  @override
  String usageDetailsPeriodTotal(String period, String duration) {
    return '$period: $duration';
  }

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
  String get reportsTitle => 'Reports';

  @override
  String get reportsWeekly => 'Weekly';

  @override
  String get reportsMonthly => 'Monthly';

  @override
  String get reportsYearly => 'Yearly';

  @override
  String get reportsTotalUsage => 'Total usage';

  @override
  String get reportsDailyAverage => 'Daily average';

  @override
  String get reportsActiveDays => 'Active days';

  @override
  String get reportsTimeOfDayTitle => 'Usage by time of day';

  @override
  String get reportsHabitTitle => 'Habit formation';

  @override
  String get reportsPeakTime => 'Most active time';

  @override
  String get reportsFirstUse => 'Average first use';

  @override
  String get reportsFirstApp => 'Most common first app';

  @override
  String get reportsConsistency => 'First-use consistency';

  @override
  String reportsVariationMinutes(int minutes) {
    return '± $minutes min';
  }

  @override
  String get reportsWakeHeuristic =>
      'First use is inferred after at least 4 hours inactive, between 04:00 and 14:00.';

  @override
  String get reportsTopApps => 'Most used apps';

  @override
  String get reportsRestrictionsTitle => 'Restriction activity';

  @override
  String get reportsBlockedAttempts => 'Blocked attempts';

  @override
  String get reportsManualUnblocks => 'Manual unblocks';

  @override
  String get reportsBlocked => 'Blocked';

  @override
  String get reportsUnblocked => 'Unblocked';

  @override
  String get reportsEmpty =>
      'There is not enough local data for this report yet.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGeneralSection => 'General';

  @override
  String get settingsActivityDataSection => 'Activity & data';

  @override
  String get settingsSupportSection => 'Support';

  @override
  String get settingsPrivacyTitle => 'Data and privacy';

  @override
  String get settingsPrivacyBody =>
      'Your usage history and settings stay on this device unless you export a backup. FocusTrace never uploads them.';

  @override
  String get settingsClearLocalData => 'Delete local data';

  @override
  String get settingsDataTransferTitle => 'Backup and restore';

  @override
  String get settingsDataTransferBody =>
      'Save a portable backup or restore data from another FocusTrace installation. Imports merge with data already on this device.';

  @override
  String get settingsExportData => 'Export data';

  @override
  String get settingsImportData => 'Import data';

  @override
  String get settingsExportSuccess => 'FocusTrace backup saved.';

  @override
  String get settingsImportSuccess => 'FocusTrace backup imported.';

  @override
  String get settingsImportDialogTitle => 'Import FocusTrace data?';

  @override
  String get settingsImportDialogBody =>
      'The backup will be merged with existing local data. Matching records and settings will use the imported values.';

  @override
  String get settingsImportDialogDetail =>
      'This includes restrictions, block routines, excluded apps and app categories when the backup has them. Nothing on this device is deleted, and the sync sign-in on this device is not changed.';

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
  String get settingsExcludedAppsTitle => 'Tracking exclusions';

  @override
  String get settingsExcludedAppsEmpty =>
      'No apps are excluded from tracking. Long-press an app on the dashboard to add one here.';

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
  String get settingsClearDataDialogTitle => 'Delete all local data?';

  @override
  String get settingsClearDataDeletes =>
      'Deletes from this device: usage history and reports, restrictions and block routines, excluded apps, app categories and other settings.';

  @override
  String get settingsClearDataKeeps =>
      'Kept: your language choice. Android permissions are not changed. Export a backup first if you may need this data.';

  @override
  String get settingsClearDataKeepsSync =>
      'Your cloud account and data already synced are not deleted. Sync turns off on this device.';

  @override
  String get settingsClearDataDone => 'Local data deleted.';

  @override
  String get settingsCancel => 'Cancel';

  @override
  String get settingsClear => 'Delete';

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

  @override
  String get settingsSyncSection => 'Account & sync';

  @override
  String get settingsSyncTitle => 'Cloud sync';

  @override
  String get settingsSyncBody =>
      'Sign in to copy your daily usage totals to your own account, so another device can see them. Off until you turn it on.';

  @override
  String get settingsSyncEmail => 'Email';

  @override
  String get settingsSyncPassword => 'Password';

  @override
  String get settingsSyncPasswordRequirements =>
      'Use 15–128 characters. A few unrelated words make a strong, memorable passphrase. Common passwords are not accepted.';

  @override
  String get settingsSyncShowPassword => 'Show password';

  @override
  String get settingsSyncHidePassword => 'Hide password';

  @override
  String get settingsSyncSignInHeading => 'Sign in to your account';

  @override
  String get settingsSyncCreateHeading => 'Create a sync account';

  @override
  String get settingsSyncSwitchToCreate => 'New to sync? Create an account';

  @override
  String get settingsSyncSwitchToSignIn => 'Already have an account? Sign in';

  @override
  String get settingsSyncSignInInstead => 'Sign in instead';

  @override
  String get settingsSyncSigningIn => 'Signing in…';

  @override
  String get settingsSyncCreatingAccount => 'Creating account…';

  @override
  String get settingsSyncAccountCreated => 'Account created';

  @override
  String settingsSyncSignedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get settingsSyncCreatedNextStep =>
      'Sync is still off. Turn it on when you want this device\'s daily totals copied to your account.';

  @override
  String get settingsSyncTurnOnSync => 'Turn on sync';

  @override
  String get settingsSyncAccountCreatedSignInRequired =>
      'Your account was created, but signing in automatically did not work. Enter your password and tap Sign in to continue.';

  @override
  String get settingsSyncErrorRegistration =>
      'Account not created. Check your email and password and try again.';

  @override
  String get settingsSyncErrorEmailRequired => 'Enter your email address.';

  @override
  String get settingsSyncErrorEmailInvalid =>
      'Enter a valid email address, like name@example.com.';

  @override
  String get settingsSyncErrorPasswordRequired => 'Enter your password.';

  @override
  String settingsSyncErrorPasswordTooShort(int count) {
    return 'Use at least 15 characters ($count so far).';
  }

  @override
  String get settingsSyncErrorPasswordTooLong => 'Use at most 128 characters.';

  @override
  String get settingsSyncErrorPasswordRejected =>
      'This password is too common or matches your email. Choose a different one.';

  @override
  String get settingsSyncErrorThrottled =>
      'Too many attempts from this network. Wait a while, then try again.';

  @override
  String get settingsSyncSignIn => 'Sign in';

  @override
  String get settingsSyncCreateAccount => 'Create account';

  @override
  String get settingsSyncSignOut => 'Log out';

  @override
  String get settingsSyncEnabledLabel => 'Sync this device';

  @override
  String get settingsSyncEnabledSubtitle =>
      'Turning this off stops sending new data. Nothing already synced is deleted.';

  @override
  String get settingsSyncNow => 'Sync now';

  @override
  String get settingsSyncNeverSynced => 'Not synced yet';

  @override
  String get settingsSyncStateSyncing => 'Syncing...';

  @override
  String get settingsSyncStateSuccess => 'Sync complete';

  @override
  String get settingsSyncStateError => 'Sync failed';

  @override
  String get settingsSyncErrorOffline =>
      'Could not reach the sync service. Check your connection and try again.';

  @override
  String get settingsSyncErrorCredentials =>
      'That email and password did not match an account.';

  @override
  String get settingsSyncErrorEmailTaken =>
      'An account already exists for that email.';

  @override
  String get settingsSyncErrorWeakPassword =>
      'Choose a longer, less common password.';

  @override
  String get settingsSyncErrorSessionExpired =>
      'Your session has ended. Sign in again.';

  @override
  String get settingsSyncErrorRefused =>
      'The sync service refused the request.';

  @override
  String get settingsSyncErrorUnknown => 'Something went wrong. Try again.';

  @override
  String get settingsSyncDeleteAccount => 'Delete account';

  @override
  String get settingsSyncDeleteTitle => 'Delete your FocusTrace account?';

  @override
  String get settingsSyncDeleteBody =>
      'This permanently deletes your FocusTrace cloud account and all usage data synced to the server. It cannot be undone.\n\nUsage history on this device stays, and sync will be turned off.';

  @override
  String get settingsSyncDeletePassword => 'Current password';

  @override
  String get settingsSyncDeleteConfirm => 'Delete permanently';

  @override
  String get settingsSyncDeleted =>
      'Your FocusTrace account was deleted. Usage history on this device was kept.';

  @override
  String get settingsSyncRepeatPassword => 'Repeat password';

  @override
  String get settingsSyncShowRepeatPassword => 'Show repeated password';

  @override
  String get settingsSyncHideRepeatPassword => 'Hide repeated password';

  @override
  String get settingsSyncErrorPasswordMismatch => 'The passwords do not match.';

  @override
  String get settingsSyncDangerZone => 'Danger zone';

  @override
  String get settingsSyncDangerZoneBody =>
      'Deleting your account permanently removes it and all usage data synced to the server. Usage history on this device stays.';

  @override
  String get settingsSyncDeleteAcknowledge =>
      'I understand this permanently deletes my cloud account.';

  @override
  String get settingsSyncDeleting => 'Deleting…';

  @override
  String get settingsSyncErrorWrongPassword =>
      'That password is not correct. Your account was not deleted.';

  @override
  String get settingsPrivacyBodySync =>
      'Your usage history and settings stay on this device unless you export a backup or turn on cloud sync.';

  @override
  String get usageCalendarTotalThisMonth => 'Total this month';

  @override
  String get usageCalendarAveragePerDay => 'Average per day';

  @override
  String get usageCalendarAppOpens => 'App opens';

  @override
  String get usageCalendarLongestSession => 'Longest session';

  @override
  String get usageCalendarVsLastMonth => 'vs. last month';

  @override
  String get usageCalendarPreviousMonth => 'Previous month';

  @override
  String get usageCalendarNextMonth => 'Next month';

  @override
  String get usageCalendarTotalTime => 'Total time';

  @override
  String get usageCalendarAverageSession => 'Average session';

  @override
  String get usageCalendarVsDailyAverage => 'vs. your daily average';

  @override
  String get usageCalendarTimeline => 'Usage timeline';

  @override
  String get usageCalendarNoTimeline => 'No session details for this day';

  @override
  String get usageApproximateNote =>
      '≈ Approximate: from Android\'s own usage summary, before FocusTrace was recording';

  @override
  String get usageApproximateTag => '≈ Approximate';

  @override
  String get onboardingHistoryChecking => 'Checking for earlier usage…';

  @override
  String get onboardingHistoryNone =>
      'Android has no earlier usage saved on this phone';

  @override
  String onboardingHistoryFound(String date) {
    return 'Found your earlier usage back to $date';
  }

  @override
  String restrictionsTimeLeft(String duration) {
    return '$duration left';
  }

  @override
  String get restrictionsLimitReached => 'Limit reached';

  @override
  String get rxWeek => 'This week';

  @override
  String get rxTopApps => 'Your most-used apps';

  @override
  String rxAverage(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Daily average · $days recorded days',
      one: 'Daily average · 1 recorded day',
    );
    return '$_temp0';
  }

  @override
  String get rxBusiest => 'Your busiest hours';

  @override
  String rxPeak(String start, String end) {
    return 'Most recorded usage is from $start to $end.';
  }

  @override
  String get rxNoInsights => 'Not enough recorded usage to suggest a time yet.';

  @override
  String get rxPlanBlock => 'Plan a schedule';

  @override
  String get rxYourRules => 'Your restrictions';

  @override
  String get rxLimit => 'Limit';

  @override
  String get rxEdit => 'Edit';

  @override
  String rxRestrict(String app) {
    return 'Restrict $app';
  }

  @override
  String rxAverageApp(String duration) {
    return 'Average $duration / day';
  }

  @override
  String get rxType => 'Restriction type';

  @override
  String get rxDailyLimit => 'Daily limit';

  @override
  String get rxBlockNow => 'Block now';

  @override
  String get rxDifficulty => 'Unblocking difficulty';

  @override
  String get rxEasy => 'Easy';

  @override
  String get rxModerate => 'Moderate';

  @override
  String get rxHard => 'Hard';

  @override
  String get rxEasyHint => 'Confirm to unblock';

  @override
  String get rxModerateHint => 'Wait 5 minutes to unblock';

  @override
  String get rxHardHint => 'No early unblock in FocusTrace';

  @override
  String get rxProtectionNote =>
      'This also applies to changing or removing an active rule.';

  @override
  String get rxSetLimit => 'Set daily limit';

  @override
  String get rxSetSchedule => 'Set schedule';

  @override
  String get rxStartBlock => 'Start block';

  @override
  String rxBelowAverage(String duration) {
    return '$duration below your daily average';
  }

  @override
  String get rxRepeat => 'Repeat';

  @override
  String get rxNextDay => 'Ends the next day';

  @override
  String rxEndsAt(String time) {
    return 'Ends at $time';
  }

  @override
  String get rxHardConfirm =>
      'While this rule is blocking an app, you cannot unblock it, edit it, or remove it early in FocusTrace.';

  @override
  String get rxConfirm => 'Confirm';

  @override
  String get rxChangeTitle => 'Change restriction?';

  @override
  String get rxChangeBody =>
      'Easy rules can be changed now. Moderate rules start a five-minute wait. Hard rules stay locked until the current block ends.';

  @override
  String get rxCooldown =>
      'Five-minute cooldown requested. Try again after it ends; the app stays blocked until you confirm again.';

  @override
  String get rxHardLocked =>
      'This rule is locked until the current block ends.';

  @override
  String get rxUnavailable =>
      'Unable to verify this restriction. Check usage access and try again.';

  @override
  String get rxMinutes => 'Duration in minutes';

  @override
  String get rxRetry => 'Retry';

  @override
  String get rxScheduleInvalid =>
      'Choose different start and end times and at least one day.';

  @override
  String get rxNoUsage =>
      'No recorded usage for this period. You can still choose any app to restrict.';

  @override
  String rxNextBlock(String time) {
    return 'Next: $time';
  }

  @override
  String rxPerDay(String duration) {
    return '$duration / day';
  }

  @override
  String rxUntil(String time) {
    return 'Until $time';
  }

  @override
  String rxLeftToday(String duration) {
    return '$duration left today';
  }

  @override
  String rxStarts(String time) {
    return 'Starts $time';
  }

  @override
  String get rxStartLabel => 'Starts';

  @override
  String get rxEndLabel => 'Ends';

  @override
  String get rxHoursField => 'Hours';

  @override
  String get rxMinutesField => 'Minutes';

  @override
  String get rxAdd => 'Add';

  @override
  String get rxNoRulesYet =>
      'No restrictions yet. Choose an app below, or tap Add.';

  @override
  String get rxChooseApps => 'Choose apps to limit';

  @override
  String get rxSearchAll => 'Search all apps';

  @override
  String get rxTodayUsage => 'Today\'s usage so far';

  @override
  String get rxCreate => 'Create';

  @override
  String rxSharedLimit(String duration) {
    return 'Shared daily limit · $duration';
  }

  @override
  String rxMoreApps(String names, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count apps',
      one: '1 app',
    );
    return '$names + $_temp0';
  }

  @override
  String get rxPaused => 'Paused';

  @override
  String rxUsed(String duration) {
    return '$duration used';
  }

  @override
  String rxLeft(String duration) {
    return '$duration left';
  }

  @override
  String get rxEveryDay => 'Every day';

  @override
  String get rxUnblockAfterWait => 'Unblock after 5-minute wait';

  @override
  String rxLockedUntil(String time) {
    return 'Locked until $time';
  }

  @override
  String get rxEditDuration => 'Edit duration';

  @override
  String get rxSaveChanges => 'Save changes';

  @override
  String get rxEasyExplain =>
      'You can unblock early after confirming. Editing or removing this rule while it blocks also asks for confirmation.';

  @override
  String get rxModerateExplain =>
      'Unblocking early, or editing or removing this rule while it blocks, starts a five-minute wait. The app stays blocked meanwhile. When the wait ends, repeat the action and confirm again. Nothing unblocks on its own.';

  @override
  String get rxHardExplain =>
      'While this rule is blocking, FocusTrace will not unblock it early, and you cannot edit or remove it until the block ends. Outside blocking times you can change it as usual.';

  @override
  String get rxModerateUnblockBody =>
      'This starts a five-minute wait. The app stays blocked until it ends. Then choose Unblock again and confirm.';

  @override
  String get routineLastAppPrompt =>
      'This routine has no apps left. Delete the routine?';

  @override
  String get routineKeepRoutine => 'Keep routine';

  @override
  String get routineNamePrompt => 'Add routine name';

  @override
  String get routineEmpty =>
      'No apps in this routine yet. Add apps to use its limits again.';

  @override
  String get routineNoAppsShort => 'No apps yet';

  @override
  String get routinePickerAll => 'All';

  @override
  String routinePickerSelectCategory(String category) {
    return 'Select all in $category';
  }

  @override
  String get routineAddApps => 'Add apps';

  @override
  String routineAddSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count apps',
      one: 'Add 1 app',
    );
    return '$_temp0';
  }

  @override
  String routineAppLimit(String duration) {
    return 'App limit $duration';
  }

  @override
  String get routineNoAppLimit => 'No app limit';

  @override
  String routineAppLimitTitle(String app) {
    return 'Daily limit for $app';
  }

  @override
  String get routineAppLimitHint =>
      'Caps this app alone. Its time still counts toward the shared allowance.';

  @override
  String routineReasonShared(String routine) {
    return '$routine: shared allowance reached';
  }

  @override
  String routineReasonApp(String routine) {
    return '$routine: app limit reached';
  }

  @override
  String get reasonDailyAppLimit => 'Daily app limit reached';

  @override
  String reasonScheduleUntil(String time) {
    return 'Blocked by schedule until $time';
  }

  @override
  String reasonTemporaryUntil(String time) {
    return 'Temporary block until $time';
  }

  @override
  String routineOpenDetails(String app) {
    return 'Open details for $app';
  }

  @override
  String get usageTimelineHint =>
      'Tap or drag for exact times · hold to restrict a time frame';

  @override
  String get rxRangeQuestion => 'Restrict this time frame?';

  @override
  String get rxRangeHint => 'Drag or tap the ring to move the end';

  @override
  String get rxRangeAction => 'Restrict';

  @override
  String get rxScheduleDialHint =>
      'Drag either red end, or tap where it should go';

  @override
  String get healthConnectTitle => 'Health Connect';

  @override
  String get healthConnectSettingsOff =>
      'Off · import workouts from apps like Hevy';

  @override
  String healthConnectSettingsOn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'On · $count workouts imported',
      one: 'On · 1 workout imported',
      zero: 'On · no workouts imported yet',
    );
    return '$_temp0';
  }

  @override
  String get healthConnectIntro =>
      'Import your workouts from apps like Hevy through Android\'s Health Connect. It\'s optional and off by default. Tracking, limits and blocking never depend on it.';

  @override
  String get healthConnectDataTitle => 'What FocusTrace reads';

  @override
  String get healthConnectDataBody =>
      'Only exercise sessions: the kind of workout, its name, when it started and ended, and which app recorded it. Nothing else, such as heart rate, routes or sets, is read, and FocusTrace writes nothing to Health Connect. Imported workouts stay on this device: sync doesn\'t upload them and backups don\'t include them.';

  @override
  String get healthConnectImportSwitch => 'Import workouts';

  @override
  String get healthConnectAutoImport => 'Import automatically';

  @override
  String get healthConnectAutoImportBody =>
      'Checks for new workouts every few hours. Apps sync to Health Connect on their own schedule, so a workout can take a while to show up.';

  @override
  String get healthConnectAutoImportUnsupported =>
      'Automatic import needs a newer version of Health Connect. Import now still works.';

  @override
  String get healthConnectAutoImportBlocked =>
      'Health Connect doesn\'t allow FocusTrace to read in the background, so automatic import can\'t run. Allow it in Health Connect, or use Import now.';

  @override
  String get healthConnectImportNow => 'Import now';

  @override
  String healthConnectLastSuccess(String time) {
    return 'Last successful import: $time';
  }

  @override
  String get healthConnectNeverImported => 'Nothing imported yet';

  @override
  String healthConnectOutcomeImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Last check: $count workouts added or updated',
      one: 'Last check: 1 workout added or updated',
    );
    return '$_temp0';
  }

  @override
  String get healthConnectOutcomeNoNew => 'Last check: no new workouts';

  @override
  String get healthConnectOutcomeUnavailable =>
      'Last check failed: Health Connect isn\'t available';

  @override
  String get healthConnectOutcomePermission =>
      'Last check failed: access to exercise data is off in Health Connect';

  @override
  String get healthConnectOutcomeBackground =>
      'Last automatic check couldn\'t run in the background';

  @override
  String get healthConnectOutcomeFailed =>
      'Last check didn\'t finish. It will be tried again.';

  @override
  String get healthConnectUnavailable =>
      'Health Connect isn\'t available on this device. It needs Android 9 or newer.';

  @override
  String get healthConnectUpdateRequired =>
      'Install or update Health Connect from Google Play to use this.';

  @override
  String get healthConnectGetApp => 'Open Google Play';

  @override
  String get healthConnectRevoked =>
      'FocusTrace no longer has access to your exercise data. Grant it again to keep importing.';

  @override
  String get healthConnectGrantAgain => 'Grant access';

  @override
  String get healthConnectManage => 'Manage access in Health Connect';

  @override
  String get healthConnectOffNote =>
      'Turning this off stops every read and scheduled import. It doesn\'t remove FocusTrace\'s permission or change anything in Health Connect; manage that there. Workouts already imported stay on this device until you delete them.';

  @override
  String get healthConnectDeleteImported => 'Delete imported workouts';

  @override
  String get healthConnectDeleteTitle => 'Delete imported workouts?';

  @override
  String get healthConnectDeleteBody =>
      'This removes the workouts FocusTrace copied to this device. Nothing in Health Connect or the apps that recorded them changes.';

  @override
  String get healthConnectDelete => 'Delete';

  @override
  String get healthConnectWorkoutsTitle => 'Imported workouts';

  @override
  String get healthConnectNoWorkouts =>
      'No workouts yet. The first import covers the last 30 days; older workouts aren\'t imported.';

  @override
  String healthConnectWorkoutSource(String duration, String app) {
    return '$duration · from $app';
  }

  @override
  String get workoutStrength => 'Strength training';

  @override
  String get workoutRunning => 'Running';

  @override
  String get workoutWalking => 'Walking';

  @override
  String get workoutCycling => 'Cycling';

  @override
  String get workoutSwimming => 'Swimming';

  @override
  String get workoutYoga => 'Yoga';

  @override
  String get workoutOther => 'Workout';

  @override
  String get onboardingHealthTitle => 'Bring in your workouts';

  @override
  String get onboardingHealthBody =>
      'Optional. Import workouts from apps like Hevy through Health Connect. FocusTrace only reads exercise sessions and keeps them on this device. You can change this anytime in Settings.';

  @override
  String get onboardingHealthConnect => 'Connect Health Connect';

  @override
  String get onboardingHealthSkip => 'Not now';

  @override
  String get onboardingHealthConnected =>
      'Connected. Your workouts are in Settings, under Health Connect.';

  @override
  String get onboardingHealthDenied =>
      'No access was given. You can connect later in Settings.';

  @override
  String get settingsClearDataHealth =>
      'Health Connect import turns off and imported workouts are deleted. Nothing in Health Connect changes.';
}
