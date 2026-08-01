// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'FocusTrace';

  @override
  String get durationLessThanOneMinute => '<1 хв';

  @override
  String durationMinutesShort(int minutes) {
    return '$minutes хв';
  }

  @override
  String durationHoursShort(int hours) {
    return '$hours год';
  }

  @override
  String durationHoursMinutesShort(int hours, int minutes) {
    return '$hours год $minutes хв';
  }

  @override
  String get categoryEntertainment => 'Розваги';

  @override
  String get categoryProductivity => 'Продуктивність';

  @override
  String get categoryWeb => 'Інтернет';

  @override
  String get categoryCommunication => 'Спілкування';

  @override
  String get categorySystem => 'Система';

  @override
  String get categoryActivity => 'Активність';

  @override
  String get onboardingSkip => 'Пропустити';

  @override
  String get onboardingGetStarted => 'Розпочати';

  @override
  String get onboardingContinue => 'Продовжити';

  @override
  String get onboardingStartSoftBlocks => 'Увімкнути м\'які блокування';

  @override
  String get onboardingChooseLater => 'Вибрати пізніше';

  @override
  String get onboardingChooseWhatToLimit => 'Виберіть, що обмежити';

  @override
  String get onboardingChooseWhatToLimitDescription =>
      'Виберіть застосунки та встановіть денну ціль для м\'яких блокувань.';

  @override
  String get onboardingNoAppsToChooseTitle =>
      'Поки немає застосунків для вибору';

  @override
  String get onboardingNoAppsToChooseBody =>
      'FocusTrace потребує актуальних даних про використання, щоб показати застосунки тут. Ви можете пропустити налаштування та додати обмеження пізніше в Налаштуваннях.';

  @override
  String get onboardingNoMatchingAppsTitle => 'Немає відповідних застосунків';

  @override
  String get onboardingNoMatchingAppsBody => 'Спробуйте інший пошуковий запит.';

  @override
  String get onboardingWelcomeTitle => 'Поверніть контроль над екранним часом';

  @override
  String get onboardingWelcomeBody =>
      'Зрозумійте, куди йде ваша увага.\nВстановіть м\'які обмеження.\nФормуйте кращі звички у своєму темпі.';

  @override
  String get onboardingAccessTitle => 'Надайте FocusTrace доступ';

  @override
  String get onboardingAccessBody =>
      'Для роботи FocusTrace потрібні два дозволи.\nУсе залишається на вашому пристрої.';

  @override
  String get onboardingNoPermissionsTitle => 'Тут нічого надавати';

  @override
  String get onboardingNoPermissionsBody =>
      'Ці дозволи потрібні лише на Android.';

  @override
  String get onboardingUsageAccessTitle => 'Доступ до даних про використання';

  @override
  String get onboardingUsageAccessSubtitle =>
      'Щоб вимірювати час у застосунках';

  @override
  String get onboardingOverlayAccessTitle => 'Показ поверх інших застосунків';

  @override
  String get onboardingOverlayAccessSubtitle =>
      'Щоб показувати екран блокування поверх обмежених застосунків';

  @override
  String get onboardingPermissionsSettingsHint =>
      'Це можна змінити пізніше в налаштуваннях.';

  @override
  String get onboardingAllow => 'Дозволити';

  @override
  String get onboardingSearchApps => 'Пошук застосунків';

  @override
  String onboardingAppUsageToday(String appKey, String duration) {
    return '$appKey · $duration сьогодні';
  }

  @override
  String get onboardingDailyTarget => 'Денна ціль';

  @override
  String get restrictionsTitle => 'Обмеження';

  @override
  String get restrictionsSearchApps => 'Пошук застосунків';

  @override
  String get restrictionsAddRestriction => 'Додати обмеження';

  @override
  String get restrictionsAddRoutine => 'Нова рутина';

  @override
  String get restrictionsRoutinesTitle => 'Рутини блокування';

  @override
  String get restrictionsRoutinesEmptyTitle => 'Немає рутин блокування';

  @override
  String get restrictionsRoutinesEmptyBody =>
      'Об’єднайте застосунки в рутину та вмикайте або вимикайте всю групу.';

  @override
  String get restrictionsIndividualRulesTitle => 'Окремі обмеження';

  @override
  String restrictionsRoutineAppCount(int count) {
    return 'Застосунків: $count';
  }

  @override
  String get restrictionsDeleteRoutine => 'Видалити рутину';

  @override
  String get routineEditorNewTitle => 'Нова рутина блокування';

  @override
  String get routineEditorEditTitle => 'Редагувати рутину блокування';

  @override
  String get routineEditorName => 'Назва рутини';

  @override
  String get routineEditorSearchApps => 'Пошук застосунків';

  @override
  String get routineEditorNoMatchingApps => 'Немає відповідних застосунків';

  @override
  String get routineEditorSave => 'Зберегти рутину';

  @override
  String get restrictionsPlatformStatusTitle =>
      'На цій платформі — лише статус';

  @override
  String get restrictionsPlatformStatusBody =>
      'Правила зберігаються та відображаються тут. Повноекранне блокування наразі працює лише на Android.';

  @override
  String get restrictionsEmptyTitle => 'Немає обмежень застосунків';

  @override
  String get restrictionsEmptyBody =>
      'Утримуйте застосунок у бульбашках використання або в поточному списку, щоб додати правило.';

  @override
  String get restrictionsNoAppsAvailable =>
      'Застосунки поки недоступні. Відкрийте панель після появи даних про використання, потім шукайте тут.';

  @override
  String get restrictionsNoMatchingApps => 'Немає відповідних застосунків';

  @override
  String get restrictionsDeleteRule => 'Видалити правило';

  @override
  String get restrictionsUnblockNow => 'Розблокувати зараз';

  @override
  String restrictionsBlockedUntil(String time) {
    return 'Заблоковано до $time';
  }

  @override
  String get restrictionsTemporaryBlockExpired =>
      'Тимчасове блокування завершилося';

  @override
  String restrictionsDailyLimitStatus(
    String limitDuration,
    String usedDuration,
  ) {
    return 'Денний ліміт $limitDuration · використано $usedDuration';
  }

  @override
  String restrictionsScheduleStatus(String startTime, String endTime) {
    return 'Розклад $startTime–$endTime';
  }

  @override
  String get restrictionsOverlayPermissionTitle =>
      'Потрібен дозвіл на накладання';

  @override
  String get restrictionsOverlayPermissionBody =>
      'Android потребує дозволу «Показ поверх інших застосунків», щоб FocusTrace міг показувати екран блокування.';

  @override
  String get restrictionsOpenOverlaySettings =>
      'Відкрити налаштування накладання';

  @override
  String get restrictionsRecheck => 'Перевірити ще раз';

  @override
  String get restrictionEditorAllowFullScreenTitle =>
      'Дозволити повноекранне блокування?';

  @override
  String get restrictionEditorAllowFullScreenBody =>
      'FocusTrace потребує дозволу «Показ поверх інших застосунків», щоб показувати екран блокування, коли відкривається обмежений застосунок.';

  @override
  String get restrictionEditorLater => 'Пізніше';

  @override
  String get restrictionEditorOpenSettings => 'Відкрити налаштування';

  @override
  String get restrictionEditorTypeNow => 'Зараз';

  @override
  String get restrictionEditorTypeLimit => 'Ліміт';

  @override
  String get restrictionEditorTypeSchedule => 'Розклад';

  @override
  String get restrictionEditorSaveRule => 'Зберегти правило';

  @override
  String get restrictionEditorTomorrow => 'Завтра';

  @override
  String restrictionEditorDailyLimitPerDay(String duration) {
    return '$duration на день';
  }

  @override
  String dashboardDayTracked(String duration) {
    return 'Відстежено · $duration';
  }

  @override
  String get dashboardDayToday => 'Сьогодні';

  @override
  String get dashboardDayYesterday => 'Вчора';

  @override
  String get dashboardPreviousDayTooltip => 'Попередній день';

  @override
  String get dashboardNextDayTooltip => 'Наступний день';

  @override
  String get navHome => 'Головна';

  @override
  String get trackingRunsWhileOpen =>
      'Відстеження працює лише коли FocusTrace відкрито.';

  @override
  String get dashboardStopTracking => 'Зупинити відстеження';

  @override
  String get dashboardStartTracking => 'Почати відстеження';

  @override
  String get dashboardNoUsageToday =>
      'За сьогодні використання не зафіксовано.';

  @override
  String get dashboardNoUsageDay => 'За цей день використання не зафіксовано.';

  @override
  String get dashboardAllTimeMostUsedTitle =>
      'Найчастіше використовуваний застосунок';

  @override
  String get dashboardUnsupportedPlatform =>
      'MVP FocusTrace підтримує Android і Windows. Інші платформи можна додати пізніше через ізольовані платформні джерела даних.';

  @override
  String get commonRetry => 'Повторити';

  @override
  String get commonUnexpectedError => 'Щось пішло не так. Спробуйте ще раз.';

  @override
  String get usageBubblesTitle => 'Бульбашки використання';

  @override
  String get usageBubblesDescription =>
      'Більші бульбашки означають більше витраченого часу';

  @override
  String get usageBubblesCurrentList => 'Поточний список';

  @override
  String get actionUnblockNow => 'Розблокувати зараз';

  @override
  String get actionUnblockNowDescription =>
      'Видалити активні правила блокування';

  @override
  String get actionRestrictApp => 'Обмежити застосунок...';

  @override
  String get actionRestrictAppDescription =>
      'Заблокувати зараз, встановити ліміт або додати розклад';

  @override
  String percentageValue(String percentage) {
    return '$percentage%';
  }

  @override
  String get actionRemoveFromToday => 'Прибрати з сьогодні';

  @override
  String get actionRemoveFromTodayDescription =>
      'Сховати цей застосунок зі статистики за сьогодні';

  @override
  String get actionExcludeFromTracking => 'Виключити з відстеження';

  @override
  String get actionExcludeFromTrackingDescription =>
      'Припинити відстеження та сховати з усієї статистики';

  @override
  String excludeAppDialogTitle(String appName) {
    return 'Виключити $appName?';
  }

  @override
  String get excludeAppDialogBody =>
      'Застосунок більше не відстежуватиметься й не показуватиметься у статистиці. Це можна скасувати в Налаштуваннях.';

  @override
  String get commonCancel => 'Скасувати';

  @override
  String get actionExclude => 'Виключити';

  @override
  String sessionTotal(String duration) {
    return 'Усього · $duration';
  }

  @override
  String get sessionDetailsUnavailable =>
      'Деталі сеансів недоступні на цій платформі.';

  @override
  String get sessionNoneRecorded => 'Немає записаних сеансів.';

  @override
  String get sessionLongestTitle => 'Найдовші сеанси';

  @override
  String sessionOngoingLabel(String startTime, String duration) {
    return '$startTime · $duration';
  }

  @override
  String sessionRangeLabel(String startTime, String endTime, String duration) {
    return '$startTime – $endTime · $duration';
  }

  @override
  String get permissionWindowsPrivacyTitle => 'Конфіденційність Windows';

  @override
  String get permissionUsageAccessRequiredTitle =>
      'Потрібен доступ до даних про використання';

  @override
  String get permissionUsageAccessRequiredBody =>
      'FocusTrace потребує доступу Android до даних про використання, щоб читати використання ваших власних застосунків. Дані залишаються локально на цьому пристрої.';

  @override
  String get permissionOpenUsageAccessSettings =>
      'Відкрити налаштування доступу';

  @override
  String get commonRecheck => 'Перевірити ще раз';

  @override
  String get trackingWindowsRunning =>
      'Відстеження Windows працює, поки FocusTrace відкрито.';

  @override
  String get trackingWindowsIdle =>
      'Відстеження Windows працює лише коли FocusTrace відкрито.';

  @override
  String get trackingAndroidUsageAccess =>
      'Дані Android зчитуються через доступ до даних про використання.';

  @override
  String get trackingUnsupportedPlatform =>
      'Відстеження використання поки не підтримується на цій платформі.';

  @override
  String get trackingError =>
      'Під час відстеження сталася помилка. Спробу буде повторено автоматично.';

  @override
  String bubblePercentageOfToday(String percentage) {
    return '$percentage% від сьогодні';
  }

  @override
  String usageBubbleSemanticsLabel(String appName, String category) {
    return '$appName, $category';
  }

  @override
  String usageBubbleNearLimitSemanticsLabel(String appName, String category) {
    return '$appName, $category, денний ліміт майже вичерпано';
  }

  @override
  String summaryLaunchCount(int count) {
    return 'Запуски: $count';
  }

  @override
  String get usageTrendDayShort => 'Д';

  @override
  String get usageTrendWeekShort => 'Т';

  @override
  String get usageTrendMonthShort => 'М';

  @override
  String usageTrendIncrease(String period, int percentage) {
    return '$period: використання зросло на $percentage%';
  }

  @override
  String usageTrendDecrease(String period, int percentage) {
    return '$period: використання зменшилося на $percentage%';
  }

  @override
  String usageTrendUnchanged(String period) {
    return '$period: використання без змін';
  }

  @override
  String get usageDetailsLastSevenDays => 'Останні 7 днів';

  @override
  String usageDetailsMoreThanYesterday(int percentage) {
    return 'На $percentage% більше, ніж учора';
  }

  @override
  String usageDetailsLessThanYesterday(int percentage) {
    return 'На $percentage% менше, ніж учора';
  }

  @override
  String get usageDetailsSameAsYesterday => 'Так само, як учора';

  @override
  String get usageDetailsNoYesterdayComparison => 'Порівняння з учора ще немає';

  @override
  String usageDetailsRankLabel(int rank) {
    return '№$rank за використанням';
  }

  @override
  String usageDetailsRankLead(String duration, String appName) {
    return 'на $duration більше, ніж $appName';
  }

  @override
  String usageDetailsDayValue(String date, String duration) {
    return '$date: $duration';
  }

  @override
  String get settingsTitle => 'Налаштування';

  @override
  String get settingsPrivacyTitle => 'Конфіденційність';

  @override
  String get settingsPrivacyBody =>
      'FocusTrace зберігає дані про використання локально на цьому пристрої. Дані про відстежені застосунки чи вікна нікуди не надсилаються.';

  @override
  String get settingsClearLocalData => 'Очистити локальні дані';

  @override
  String get settingsLanguageTitle => 'Мова';

  @override
  String get settingsLanguageSystemDefault => 'Системна за замовчуванням';

  @override
  String get settingsChooseLanguage => 'Виберіть мову';

  @override
  String get settingsLanguageUpdateError =>
      'Не вдалося застосувати мовне налаштування. Спробуйте ще раз.';

  @override
  String get settingsExcludedAppsTitle => 'Виключені застосунки';

  @override
  String get settingsExcludedAppsEmpty =>
      'Немає виключених застосунків. Утримуйте застосунок на панелі, щоб виключити його з відстеження.';

  @override
  String get settingsStopExcluding => 'Не виключати';

  @override
  String get settingsWindowsTrackingComingSoon =>
      'Незабаром: відстеження Windows';

  @override
  String get settingsSendFeedback => 'Надіслати відгук';

  @override
  String get settingsWindowsTrackingInterval => 'Інтервал відстеження Windows';

  @override
  String get settingsWindowsIdleTimeout => 'Тайм-аут бездіяльності Windows';

  @override
  String get settingsClearDataDialogTitle => 'Очистити локальні дані?';

  @override
  String get settingsClearDataDialogBody =>
      'Це видалить збережені сеанси використання та налаштування з цього пристрою. Ваш вибір мови буде збережено.';

  @override
  String get settingsCancel => 'Скасувати';

  @override
  String get settingsClear => 'Очистити';

  @override
  String get settingsSave => 'Зберегти';

  @override
  String secondsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count секунди',
      many: '$count секунд',
      few: '$count секунди',
      one: '1 секунда',
    );
    return '$_temp0';
  }
}
