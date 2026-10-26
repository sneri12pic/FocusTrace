// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appCategoryAll => 'Alle';

  @override
  String get appCategoryTitle => 'App-Kategorie';

  @override
  String get appCategoryAutomatic => 'Automatisch';

  @override
  String get appCategorySave => 'Kategorie speichern';

  @override
  String get appCategorySaveError =>
      'Die Kategorie konnte nicht gespeichert werden. Bitte erneut versuchen.';

  @override
  String get usageDetailsBarChart => 'Säulendiagramm';

  @override
  String get usageDetailsAreaChart => 'Nutzungsverlauf';

  @override
  String get usageDetailsChartSaveError =>
      'Die Diagrammauswahl konnte nicht gespeichert werden. Bitte versuche es erneut.';

  @override
  String get appTitle => 'FocusTrace';

  @override
  String get durationLessThanOneMinute => '<1 Min.';

  @override
  String durationMinutesShort(int minutes) {
    return '$minutes Min.';
  }

  @override
  String durationHoursShort(int hours) {
    return '$hours Std.';
  }

  @override
  String durationHoursMinutesShort(int hours, int minutes) {
    return '$hours Std. $minutes Min.';
  }

  @override
  String get categoryEntertainment => 'Unterhaltung';

  @override
  String get categoryProductivity => 'Produktivität';

  @override
  String get categoryWeb => 'Web';

  @override
  String get categoryCommunication => 'Kommunikation';

  @override
  String get categorySystem => 'System';

  @override
  String get categoryActivity => 'Aktivität';

  @override
  String get onboardingSkip => 'Überspringen';

  @override
  String get onboardingGetStarted => 'Loslegen';

  @override
  String get onboardingContinue => 'Weiter';

  @override
  String get onboardingStartSoftBlocks => 'Flexible Sperren aktivieren';

  @override
  String get onboardingChooseLater => 'Später auswählen';

  @override
  String get onboardingChooseWhatToLimit => 'Apps zum Begrenzen auswählen';

  @override
  String get onboardingChooseWhatToLimitDescription =>
      'Wähle Apps aus und lege ein Tagesziel für flexible Sperren fest.';

  @override
  String get onboardingNoAppsToChooseTitle => 'Noch keine Apps zur Auswahl';

  @override
  String get onboardingNoAppsToChooseBody =>
      'FocusTrace benötigt aktuelle Nutzungsdaten, bevor hier Apps angezeigt werden können. Du kannst die Einrichtung überspringen und später in den Einstellungen Einschränkungen hinzufügen.';

  @override
  String get onboardingNoMatchingAppsTitle => 'Keine passenden Apps';

  @override
  String get onboardingNoMatchingAppsBody =>
      'Versuche es mit einem anderen Suchbegriff.';

  @override
  String get onboardingWelcomeTitle => 'Hol dir deine Bildschirmzeit zurück';

  @override
  String get onboardingWelcomeBody =>
      'Verstehe, wohin deine Aufmerksamkeit geht.\nSetze sanfte Grenzen.\nEntwickle in deinem Tempo bessere Gewohnheiten.';

  @override
  String get onboardingAccessTitle => 'FocusTrace Zugriff gewähren';

  @override
  String get onboardingAccessBody =>
      'FocusTrace benötigt zwei Berechtigungen.\nAlles bleibt auf deinem Gerät.';

  @override
  String get onboardingNoPermissionsTitle => 'Hier ist keine Freigabe nötig';

  @override
  String get onboardingNoPermissionsBody =>
      'Diese Berechtigungen werden nur unter Android benötigt.';

  @override
  String get onboardingUsageAccessTitle => 'Nutzungszugriff';

  @override
  String get onboardingUsageAccessSubtitle =>
      'Um deine App-Nutzungszeit zu messen';

  @override
  String get onboardingOverlayAccessTitle => 'Über anderen Apps einblenden';

  @override
  String get onboardingOverlayAccessSubtitle =>
      'Um den Sperrbildschirm über begrenzten Apps anzuzeigen';

  @override
  String get onboardingPermissionsSettingsHint =>
      'Die ersten beiden Berechtigungen werden in den Android-Einstellungen verwaltet.';

  @override
  String get onboardingAllow => 'Zulassen';

  @override
  String get onboardingOpenSettings => 'Einstellungen öffnen';

  @override
  String get onboardingNotificationsTitle => 'Benachrichtigungen';

  @override
  String get onboardingNotificationsSubtitle =>
      'Optional: Warnungen vor Erreichen eines Tageslimits erhalten';

  @override
  String get onboardingSearchApps => 'Apps suchen';

  @override
  String onboardingAppUsageToday(String appKey, String duration) {
    return '$appKey · heute $duration';
  }

  @override
  String get onboardingDailyTarget => 'Tagesziel';

  @override
  String get restrictionsTitle => 'Einschränkungen';

  @override
  String get restrictionsSearchApps => 'Apps suchen';

  @override
  String get restrictionsAddRestriction => 'Einschränkung hinzufügen';

  @override
  String get restrictionsAddRoutine => 'Neue Routine';

  @override
  String get restrictionsRoutinesTitle => 'Sperrroutinen';

  @override
  String get restrictionsRoutinesEmptyTitle => 'Keine Sperrroutinen';

  @override
  String get restrictionsRoutinesEmptyBody =>
      'Gruppiere Apps in einer Routine und schalte die ganze Gruppe ein oder aus.';

  @override
  String get restrictionsIndividualRulesTitle => 'Einzelne Einschränkungen';

  @override
  String restrictionsRoutineAppCount(int count) {
    return '$count Apps';
  }

  @override
  String get restrictionsDeleteRoutine => 'Routine löschen';

  @override
  String get routineEditorNewTitle => 'Neue Sperrroutine';

  @override
  String get routineEditorEditTitle => 'Sperrroutine bearbeiten';

  @override
  String get routineEditorName => 'Name der Routine';

  @override
  String get routineEditorSearchApps => 'Apps suchen';

  @override
  String get routineEditorNoMatchingApps => 'Keine passenden Apps';

  @override
  String get routineEditorSave => 'Routine speichern';

  @override
  String get routineDailyLimit => 'Gemeinsames Tageslimit';

  @override
  String get routineNoDailyLimit => 'Kein Tageslimit';

  @override
  String get routineCustomDuration => 'Benutzerdefiniert';

  @override
  String get routineChooseDuration => 'Tageslimit auswählen';

  @override
  String get routineNotFound => 'Diese Routine existiert nicht mehr.';

  @override
  String get routineRename => 'Routine umbenennen';

  @override
  String get routineAppsTitle => 'Apps';

  @override
  String get routineAddApp => 'App hinzufügen';

  @override
  String routineAppUsage(String duration) {
    return 'Heute $duration · Im Limit enthalten';
  }

  @override
  String routineAppUsageExcluded(String duration) {
    return 'Heute $duration · Vom Limit ausgeschlossen';
  }

  @override
  String get routineRemoveApp => 'App entfernen';

  @override
  String get routineKeepOneApp =>
      'Eine Routine muss mindestens eine App enthalten.';

  @override
  String routineDeleteConfirmation(String name) {
    return '$name löschen? Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String get routineUsageToday => 'Heute angerechnete Nutzung';

  @override
  String get routineNoIncludedApps =>
      'Mindestens eine App einbeziehen, um das Limit zu aktivieren';

  @override
  String get routineLimitReached =>
      'Limit erreicht · einbezogene Apps sind bis Mitternacht gesperrt';

  @override
  String get routineActive => 'Aktiv';

  @override
  String get routinePaused => 'Pausiert';

  @override
  String routineUsageOfLimit(String used, String limit) {
    return '$used von $limit';
  }

  @override
  String routineRemaining(String duration) {
    return '$duration verbleibend';
  }

  @override
  String get routineSetLimit => 'Limit festlegen';

  @override
  String get routineEditLimit => 'Limit bearbeiten';

  @override
  String get routineRemoveLimit => 'Limit entfernen';

  @override
  String routineUsageOnly(String duration) {
    return 'Heute $duration';
  }

  @override
  String get restrictionsPlatformStatusTitle =>
      'Status nur auf dieser Plattform';

  @override
  String get restrictionsPlatformStatusBody =>
      'Regeln werden hier gespeichert und angezeigt. Die Vollbildsperre funktioniert derzeit nur unter Android.';

  @override
  String get restrictionsEmptyTitle => 'Keine App-Einschränkungen';

  @override
  String get restrictionsEmptyBody =>
      'Halte eine App in den Nutzungsblasen oder der aktuellen Liste gedrückt, um eine Regel hinzuzufügen.';

  @override
  String get restrictionsNoAppsAvailable =>
      'Noch keine Apps verfügbar. Öffne das Dashboard, sobald Nutzungsdaten vorliegen, und suche dann hier.';

  @override
  String get restrictionsNoMatchingApps => 'Keine passenden Apps';

  @override
  String get restrictionsDeleteRule => 'Regel löschen';

  @override
  String get restrictionsUnblockNow => 'Jetzt entsperren';

  @override
  String restrictionsBlockedUntil(String time) {
    return 'Gesperrt bis $time';
  }

  @override
  String get restrictionsTemporaryBlockExpired => 'Temporäre Sperre abgelaufen';

  @override
  String restrictionsDailyLimitStatus(
    String limitDuration,
    String usedDuration,
  ) {
    return 'Tageslimit: $limitDuration · Genutzt: $usedDuration';
  }

  @override
  String restrictionsScheduleStatus(String startTime, String endTime) {
    return 'Zeitplan: $startTime–$endTime';
  }

  @override
  String get restrictionsOverlayPermissionTitle =>
      'Berechtigung zum Einblenden erforderlich';

  @override
  String get restrictionsOverlayPermissionBody =>
      'Android benötigt die Berechtigung „Über anderen Apps einblenden“, bevor FocusTrace einen Sperrbildschirm anzeigen kann.';

  @override
  String get restrictionsOpenOverlaySettings => 'Overlay-Einstellungen öffnen';

  @override
  String get restrictionsRecheck => 'Erneut prüfen';

  @override
  String get restrictionEditorAllowFullScreenTitle =>
      'Vollbildsperre zulassen?';

  @override
  String get restrictionEditorAllowFullScreenBody =>
      'FocusTrace benötigt die Berechtigung „Über anderen Apps einblenden“, um beim Öffnen einer eingeschränkten App einen Sperrbildschirm anzuzeigen.';

  @override
  String get restrictionEditorLater => 'Später';

  @override
  String get restrictionEditorOpenSettings => 'Einstellungen öffnen';

  @override
  String get restrictionEditorTypeNow => 'Jetzt';

  @override
  String get restrictionEditorTypeLimit => 'Limit';

  @override
  String get restrictionEditorTypeSchedule => 'Zeitplan';

  @override
  String get restrictionEditorSaveRule => 'Regel speichern';

  @override
  String get restrictionEditorTomorrow => 'Morgen';

  @override
  String restrictionEditorDailyLimitPerDay(String duration) {
    return '$duration pro Tag';
  }

  @override
  String dashboardDayTracked(String duration) {
    return 'Erfasst · $duration';
  }

  @override
  String get dashboardDayToday => 'Heute';

  @override
  String get dashboardDayYesterday => 'Gestern';

  @override
  String get dashboardPreviousDayTooltip => 'Vorheriger Tag';

  @override
  String get dashboardNextDayTooltip => 'Nächster Tag';

  @override
  String get navHome => 'Start';

  @override
  String get trackingRunsWhileOpen =>
      'Die Erfassung läuft nur, solange FocusTrace geöffnet ist.';

  @override
  String get dashboardStopTracking => 'Erfassung beenden';

  @override
  String get dashboardStartTracking => 'Erfassung starten';

  @override
  String get dashboardNoUsageToday => 'Für heute wurde keine Nutzung erfasst.';

  @override
  String get dashboardNoUsageDay =>
      'Für diesen Tag wurde keine Nutzung erfasst.';

  @override
  String get dashboardUsageUnavailableDay =>
      'Nutzungsdaten sind für diesen Tag derzeit nicht verfügbar.';

  @override
  String get dashboardAllTimeMostUsedTitle => 'Meistgenutzte App aller Zeiten';

  @override
  String get dashboardUnsupportedPlatform =>
      'Das FocusTrace-MVP unterstützt Android und Windows. Weitere Plattformen können später über separate Plattform-Datenquellen hinzugefügt werden.';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonUnexpectedError =>
      'Etwas ist schiefgelaufen. Bitte versuche es erneut.';

  @override
  String get usageBubblesTitle => 'Nutzungsblasen';

  @override
  String get usageBubblesDescription =>
      'Größere Blasen bedeuten mehr Nutzungszeit';

  @override
  String get usageBubblesCurrentList => 'Aktuelle Liste';

  @override
  String usageListShowAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle anzeigen ($count weitere)',
      one: 'Alle anzeigen (1 weitere)',
    );
    return '$_temp0';
  }

  @override
  String get usageListShowLess => 'Weniger anzeigen';

  @override
  String get actionUnblockNow => 'Jetzt entsperren';

  @override
  String get actionUnblockNowDescription => 'Aktive Sperrregeln entfernen';

  @override
  String get actionRestrictApp => 'App einschränken...';

  @override
  String get actionRestrictAppDescription =>
      'Jetzt sperren, ein Limit festlegen oder einen Zeitplan hinzufügen';

  @override
  String percentageValue(String percentage) {
    return '$percentage %';
  }

  @override
  String get actionRemoveFromToday => 'Aus der heutigen Ansicht entfernen';

  @override
  String get actionRemoveFromTodayDescription =>
      'Diese App aus der heutigen Statistik ausblenden';

  @override
  String get actionExcludeFromTracking => 'Von der Erfassung ausschließen';

  @override
  String get actionExcludeFromTrackingDescription =>
      'Nicht mehr erfassen und aus allen Statistiken ausblenden';

  @override
  String excludeAppDialogTitle(String appName) {
    return '$appName ausschließen?';
  }

  @override
  String get excludeAppDialogBody =>
      'Die App wird nicht mehr erfasst oder in Statistiken angezeigt. Dies kann in den Einstellungen rückgängig gemacht werden.';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get actionExclude => 'Ausschließen';

  @override
  String sessionTotal(String duration) {
    return 'Gesamt · $duration';
  }

  @override
  String get sessionDetailsUnavailable =>
      'Sitzungsdetails sind auf dieser Plattform nicht verfügbar.';

  @override
  String get sessionNoneRecorded => 'Keine Sitzungen aufgezeichnet.';

  @override
  String get sessionLongestTitle => 'Längste Sitzungen';

  @override
  String sessionOngoingLabel(String startTime, String duration) {
    return '$startTime · $duration';
  }

  @override
  String sessionRangeLabel(String startTime, String endTime, String duration) {
    return '$startTime – $endTime · $duration';
  }

  @override
  String get permissionWindowsPrivacyTitle => 'Windows-Datenschutz';

  @override
  String get permissionUsageAccessRequiredTitle =>
      'Nutzungszugriff erforderlich';

  @override
  String get permissionUsageAccessRequiredBody =>
      'FocusTrace benötigt den Android-Nutzungszugriff, um deine App-Nutzung zu lesen. Die Daten bleiben lokal auf diesem Gerät.';

  @override
  String get permissionOpenUsageAccessSettings =>
      'Einstellungen für den Nutzungszugriff öffnen';

  @override
  String get commonRecheck => 'Erneut prüfen';

  @override
  String get trackingWindowsRunning =>
      'Die Erfassung unter Windows läuft, solange FocusTrace geöffnet ist.';

  @override
  String get trackingWindowsIdle =>
      'Die Erfassung unter Windows läuft nur, solange FocusTrace geöffnet ist.';

  @override
  String get trackingAndroidUsageAccess =>
      'Die Android-Nutzung wird über den Nutzungszugriff gelesen.';

  @override
  String get trackingUnsupportedPlatform =>
      'Die Nutzungserfassung wird auf dieser Plattform noch nicht unterstützt.';

  @override
  String get trackingError =>
      'Bei der Erfassung ist ein Problem aufgetreten. Ein neuer Versuch erfolgt automatisch.';

  @override
  String bubblePercentageOfToday(String percentage) {
    return '$percentage % der heutigen Nutzung';
  }

  @override
  String usageBubbleSemanticsLabel(String appName, String category) {
    return '$appName, $category';
  }

  @override
  String usageBubbleNearLimitSemanticsLabel(String appName, String category) {
    return '$appName, $category, Tageslimit fast erreicht';
  }

  @override
  String summaryLaunchCount(int count) {
    return 'Starts: $count';
  }

  @override
  String get usageTrendDayShort => 'T';

  @override
  String get usageTrendWeekShort => 'W';

  @override
  String get usageTrendMonthShort => 'M';

  @override
  String usageTrendIncrease(String period, int percentage) {
    return '$period: Nutzung um $percentage % gestiegen';
  }

  @override
  String usageTrendDecrease(String period, int percentage) {
    return '$period: Nutzung um $percentage % gesunken';
  }

  @override
  String usageTrendUnchanged(String period) {
    return '$period: Nutzung unverändert';
  }

  @override
  String get usageTrendNew => 'Neu';

  @override
  String usageTrendNewLabel(String period) {
    return '$period: neue Nutzung, kein früherer Vergleichswert';
  }

  @override
  String usageTrendIncreaseAboveCap(String period, int percentage) {
    return '$period: Nutzung um mehr als $percentage % gestiegen';
  }

  @override
  String get usageDetailsLastSevenDays => 'Letzte 7 Tage';

  @override
  String get usageDetailsTimeTracked => 'Erfasste Zeit';

  @override
  String get usageDetailsPeriodSevenDays => '7 Tage';

  @override
  String get usageDetailsPeriodTwoWeeks => '2 Wochen';

  @override
  String get usageDetailsPeriodMonth => 'Ein Monat';

  @override
  String get usageDetailsPeriodYear => 'Ein Jahr';

  @override
  String usageDetailsPeriodTotal(String period, String duration) {
    return '$period: $duration';
  }

  @override
  String usageDetailsMoreThanYesterday(int percentage) {
    return '$percentage % mehr als gestern';
  }

  @override
  String usageDetailsLessThanYesterday(int percentage) {
    return '$percentage % weniger als gestern';
  }

  @override
  String get usageDetailsSameAsYesterday => 'Wie gestern';

  @override
  String get usageDetailsNoYesterdayComparison =>
      'Noch kein Vergleich mit gestern';

  @override
  String usageDetailsRankLabel(int rank) {
    return 'Platz $rank der meistgenutzten Apps';
  }

  @override
  String usageDetailsRankLead(String duration, String appName) {
    return '$duration mehr als $appName';
  }

  @override
  String usageDetailsDayValue(String date, String duration) {
    return '$date: $duration';
  }

  @override
  String get reportsTitle => 'Berichte';

  @override
  String get reportsWeekly => 'Wöchentlich';

  @override
  String get reportsMonthly => 'Monatlich';

  @override
  String get reportsYearly => 'Jährlich';

  @override
  String get reportsTotalUsage => 'Gesamtnutzung';

  @override
  String get reportsDailyAverage => 'Tagesdurchschnitt';

  @override
  String get reportsActiveDays => 'Aktive Tage';

  @override
  String get reportsTimeOfDayTitle => 'Nutzung nach Tageszeit';

  @override
  String get reportsHabitTitle => 'Gewohnheitsbildung';

  @override
  String get reportsPeakTime => 'Aktivste Zeit';

  @override
  String get reportsFirstUse => 'Durchschnittliche erste Nutzung';

  @override
  String get reportsFirstApp => 'Häufigste erste App';

  @override
  String get reportsConsistency => 'Regelmäßigkeit der ersten Nutzung';

  @override
  String reportsVariationMinutes(int minutes) {
    return '± $minutes Min.';
  }

  @override
  String get reportsWakeHeuristic =>
      'Die erste Nutzung wird nach mindestens 4 Stunden Inaktivität zwischen 04:00 und 14:00 Uhr geschätzt.';

  @override
  String get reportsTopApps => 'Meistgenutzte Apps';

  @override
  String get reportsRestrictionsTitle => 'Einschränkungsaktivität';

  @override
  String get reportsBlockedAttempts => 'Blockierte Versuche';

  @override
  String get reportsManualUnblocks => 'Manuelle Entsperrungen';

  @override
  String get reportsBlocked => 'Blockiert';

  @override
  String get reportsUnblocked => 'Entsperrt';

  @override
  String get reportsEmpty =>
      'Für diesen Bericht sind noch nicht genügend lokale Daten vorhanden.';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsGeneralSection => 'Allgemein';

  @override
  String get settingsActivityDataSection => 'Aktivität und Daten';

  @override
  String get settingsSupportSection => 'Hilfe und Feedback';

  @override
  String get settingsPrivacyTitle => 'Daten und Datenschutz';

  @override
  String get settingsPrivacyBody =>
      'Dein Nutzungsverlauf und deine Einstellungen bleiben auf diesem Gerät, sofern du keine Sicherung exportierst. FocusTrace lädt sie niemals hoch.';

  @override
  String get settingsClearLocalData => 'Lokale Daten löschen';

  @override
  String get settingsDataTransferTitle => 'Sichern und Wiederherstellen';

  @override
  String get settingsDataTransferBody =>
      'Erstelle eine portable Sicherung oder stelle Daten aus einer anderen FocusTrace-Installation wieder her. Importierte Daten werden mit den vorhandenen Daten auf diesem Gerät zusammengeführt.';

  @override
  String get settingsExportData => 'Daten exportieren';

  @override
  String get settingsImportData => 'Daten importieren';

  @override
  String get settingsExportSuccess => 'FocusTrace-Sicherung gespeichert.';

  @override
  String get settingsImportSuccess => 'FocusTrace-Sicherung importiert.';

  @override
  String get settingsImportDialogTitle => 'FocusTrace-Daten importieren?';

  @override
  String get settingsImportDialogBody =>
      'Die Sicherung wird mit vorhandenen lokalen Daten zusammengeführt. Übereinstimmende Einträge und Einstellungen verwenden die importierten Werte.';

  @override
  String get settingsImportDialogDetail =>
      'Das gilt auch für Einschränkungen, Sperrroutinen, ausgeschlossene Apps und App-Kategorien, sofern die Sicherung sie enthält. Auf diesem Gerät wird nichts gelöscht, und die Synchronisierungsanmeldung bleibt unverändert.';

  @override
  String get settingsLanguageTitle => 'Sprache';

  @override
  String get settingsLanguageSystemDefault => 'Systemeinstellung';

  @override
  String get settingsChooseLanguage => 'Sprache auswählen';

  @override
  String get settingsLanguageUpdateError =>
      'Die Spracheinstellung konnte nicht übernommen werden. Bitte versuche es erneut.';

  @override
  String get settingsExcludedAppsTitle => 'Vom Tracking ausgeschlossene Apps';

  @override
  String get settingsExcludedAppsEmpty =>
      'Keine Apps sind vom Tracking ausgeschlossen. Halte eine App im Dashboard gedrückt, um sie hier hinzuzufügen.';

  @override
  String get settingsStopExcluding => 'Ausschluss aufheben';

  @override
  String get settingsWindowsTrackingComingSoon =>
      'Demnächst: Erfassung unter Windows';

  @override
  String get settingsSendFeedback => 'Feedback senden';

  @override
  String get settingsWindowsTrackingInterval =>
      'Erfassungsintervall unter Windows';

  @override
  String get settingsWindowsIdleTimeout =>
      'Zeitlimit für Inaktivität unter Windows';

  @override
  String get settingsClearDataDialogTitle => 'Alle lokalen Daten löschen?';

  @override
  String get settingsClearDataDeletes =>
      'Wird von diesem Gerät gelöscht: Nutzungsverlauf und Berichte, Einschränkungen und Sperrroutinen, ausgeschlossene Apps, App-Kategorien und weitere Einstellungen.';

  @override
  String get settingsClearDataKeeps =>
      'Bleibt erhalten: deine Spracheinstellung. Android-Berechtigungen werden nicht geändert. Exportiere vorher eine Sicherung, falls du diese Daten noch brauchst.';

  @override
  String get settingsClearDataKeepsSync =>
      'Dein Cloud-Konto und bereits synchronisierte Daten werden nicht gelöscht. Die Synchronisierung wird auf diesem Gerät ausgeschaltet.';

  @override
  String get settingsClearDataDone => 'Lokale Daten gelöscht.';

  @override
  String get settingsCancel => 'Abbrechen';

  @override
  String get settingsClear => 'Löschen';

  @override
  String get settingsSave => 'Speichern';

  @override
  String secondsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sekunden',
      one: '1 Sekunde',
    );
    return '$_temp0';
  }

  @override
  String get settingsSyncSection => 'Konto und Synchronisierung';

  @override
  String get settingsSyncTitle => 'Cloud-Synchronisierung';

  @override
  String get settingsSyncBody =>
      'Melde dich an, um deine täglichen Nutzungssummen in dein eigenes Konto zu kopieren und auf einem anderen Gerät zu sehen. Aus, bis du sie einschaltest.';

  @override
  String get settingsSyncEmail => 'E-Mail';

  @override
  String get settingsSyncPassword => 'Passwort';

  @override
  String get settingsSyncPasswordRequirements =>
      'Verwende 15–128 Zeichen. Einige Wörter ohne Zusammenhang ergeben eine sichere, leicht merkbare Passphrase. Häufige Passwörter werden nicht akzeptiert.';

  @override
  String get settingsSyncShowPassword => 'Passwort anzeigen';

  @override
  String get settingsSyncHidePassword => 'Passwort verbergen';

  @override
  String get settingsSyncSignInHeading => 'Bei deinem Konto anmelden';

  @override
  String get settingsSyncCreateHeading => 'Ein Sync-Konto erstellen';

  @override
  String get settingsSyncSwitchToCreate => 'Neu bei Sync? Konto erstellen';

  @override
  String get settingsSyncSwitchToSignIn => 'Du hast schon ein Konto? Anmelden';

  @override
  String get settingsSyncSignInInstead => 'Stattdessen anmelden';

  @override
  String get settingsSyncSigningIn => 'Anmeldung läuft…';

  @override
  String get settingsSyncCreatingAccount => 'Konto wird erstellt…';

  @override
  String get settingsSyncAccountCreated => 'Konto erstellt';

  @override
  String settingsSyncSignedInAs(String email) {
    return 'Angemeldet als $email';
  }

  @override
  String get settingsSyncCreatedNextStep =>
      'Sync ist noch aus. Schalte es ein, wenn die täglichen Nutzungswerte dieses Geräts in dein Konto kopiert werden sollen.';

  @override
  String get settingsSyncTurnOnSync => 'Sync einschalten';

  @override
  String get settingsSyncAccountCreatedSignInRequired =>
      'Dein Konto wurde erstellt, aber die automatische Anmeldung ist fehlgeschlagen. Gib dein Passwort ein und tippe auf „Anmelden“, um fortzufahren.';

  @override
  String get settingsSyncErrorRegistration =>
      'Konto nicht erstellt. Prüfe deine E-Mail-Adresse und dein Passwort und versuche es erneut.';

  @override
  String get settingsSyncErrorEmailRequired => 'Gib deine E-Mail-Adresse ein.';

  @override
  String get settingsSyncErrorEmailInvalid =>
      'Gib eine gültige E-Mail-Adresse ein, etwa name@example.com.';

  @override
  String get settingsSyncErrorPasswordRequired => 'Gib dein Passwort ein.';

  @override
  String settingsSyncErrorPasswordTooShort(int count) {
    return 'Verwende mindestens 15 Zeichen (bisher $count).';
  }

  @override
  String get settingsSyncErrorPasswordTooLong =>
      'Verwende höchstens 128 Zeichen.';

  @override
  String get settingsSyncErrorPasswordRejected =>
      'Dieses Passwort ist zu häufig oder entspricht deiner E-Mail-Adresse. Wähle ein anderes.';

  @override
  String get settingsSyncErrorThrottled =>
      'Zu viele Versuche aus diesem Netzwerk. Warte eine Weile und versuche es dann erneut.';

  @override
  String get settingsSyncSignIn => 'Anmelden';

  @override
  String get settingsSyncCreateAccount => 'Konto erstellen';

  @override
  String get settingsSyncSignOut => 'Abmelden';

  @override
  String get settingsSyncEnabledLabel => 'Dieses Gerät synchronisieren';

  @override
  String get settingsSyncEnabledSubtitle =>
      'Ausschalten stoppt das Senden neuer Daten. Bereits Synchronisiertes wird nicht gelöscht.';

  @override
  String get settingsSyncNow => 'Jetzt synchronisieren';

  @override
  String get settingsSyncNeverSynced => 'Noch nicht synchronisiert';

  @override
  String get settingsSyncStateSyncing => 'Wird synchronisiert...';

  @override
  String get settingsSyncStateSuccess => 'Synchronisierung abgeschlossen';

  @override
  String get settingsSyncStateError => 'Synchronisierung fehlgeschlagen';

  @override
  String get settingsSyncErrorOffline =>
      'Der Dienst war nicht erreichbar. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get settingsSyncErrorCredentials =>
      'E-Mail und Passwort passen zu keinem Konto.';

  @override
  String get settingsSyncErrorEmailTaken =>
      'Für diese E-Mail gibt es bereits ein Konto.';

  @override
  String get settingsSyncErrorWeakPassword =>
      'Wähle ein längeres, weniger verbreitetes Passwort.';

  @override
  String get settingsSyncErrorSessionExpired =>
      'Deine Sitzung ist abgelaufen. Melde dich erneut an.';

  @override
  String get settingsSyncErrorRefused =>
      'Der Dienst hat die Anfrage abgelehnt.';

  @override
  String get settingsSyncErrorUnknown =>
      'Etwas ist schiefgelaufen. Versuche es erneut.';

  @override
  String get settingsSyncDeleteAccount => 'Konto löschen';

  @override
  String get settingsSyncDeleteTitle => 'FocusTrace-Konto löschen?';

  @override
  String get settingsSyncDeleteBody =>
      'Dadurch werden dein FocusTrace-Cloudkonto und alle auf den Server synchronisierten Nutzungsdaten dauerhaft gelöscht. Das kann nicht rückgängig gemacht werden.\n\nDer Nutzungsverlauf auf diesem Gerät bleibt erhalten, und die Synchronisierung wird ausgeschaltet.';

  @override
  String get settingsSyncDeletePassword => 'Aktuelles Passwort';

  @override
  String get settingsSyncDeleteConfirm => 'Endgültig löschen';

  @override
  String get settingsSyncDeleted =>
      'Dein FocusTrace-Konto wurde gelöscht. Der Nutzungsverlauf auf diesem Gerät wurde behalten.';

  @override
  String get settingsSyncRepeatPassword => 'Passwort wiederholen';

  @override
  String get settingsSyncShowRepeatPassword => 'Wiederholtes Passwort anzeigen';

  @override
  String get settingsSyncHideRepeatPassword =>
      'Wiederholtes Passwort verbergen';

  @override
  String get settingsSyncErrorPasswordMismatch =>
      'Die Passwörter stimmen nicht überein.';

  @override
  String get settingsSyncDangerZone => 'Gefahrenbereich';

  @override
  String get settingsSyncDangerZoneBody =>
      'Wenn du dein Konto löschst, werden es und alle auf den Server synchronisierten Nutzungsdaten endgültig entfernt. Der Nutzungsverlauf auf diesem Gerät bleibt erhalten.';

  @override
  String get settingsSyncDeleteAcknowledge =>
      'Ich verstehe, dass mein Cloud-Konto damit endgültig gelöscht wird.';

  @override
  String get settingsSyncDeleting => 'Wird gelöscht…';

  @override
  String get settingsSyncErrorWrongPassword =>
      'Das Passwort ist nicht korrekt. Dein Konto wurde nicht gelöscht.';

  @override
  String get settingsPrivacyBodySync =>
      'Dein Nutzungsverlauf und deine Einstellungen bleiben auf diesem Gerät, außer du exportierst eine Sicherung oder aktivierst die Cloud-Synchronisierung.';

  @override
  String get usageCalendarTotalThisMonth => 'Gesamt diesen Monat';

  @override
  String get usageCalendarAveragePerDay => 'Durchschnitt pro Tag';

  @override
  String get usageCalendarAppOpens => 'App-Öffnungen';

  @override
  String get usageCalendarLongestSession => 'Längste Sitzung';

  @override
  String get usageCalendarVsLastMonth => 'ggü. Vormonat';

  @override
  String get usageCalendarPreviousMonth => 'Vorheriger Monat';

  @override
  String get usageCalendarNextMonth => 'Nächster Monat';

  @override
  String get usageCalendarTotalTime => 'Gesamtzeit';

  @override
  String get usageCalendarAverageSession => 'Durchschnittliche Sitzung';

  @override
  String get usageCalendarVsDailyAverage => 'ggü. deinem Tagesdurchschnitt';

  @override
  String get usageCalendarTimeline => 'Nutzungsverlauf';

  @override
  String get usageCalendarNoTimeline => 'Keine Sitzungsdetails für diesen Tag';

  @override
  String get usageApproximateNote =>
      '≈ Ungefähr: aus Androids eigener Nutzungsübersicht, bevor FocusTrace aufgezeichnet hat';

  @override
  String get usageApproximateTag => '≈ Ungefähr';

  @override
  String get onboardingHistoryChecking => 'Suche nach früherer Nutzung…';

  @override
  String get onboardingHistoryNone =>
      'Android hat auf diesem Telefon keine frühere Nutzung gespeichert';

  @override
  String onboardingHistoryFound(String date) {
    return 'Frühere Nutzung bis zum $date gefunden';
  }

  @override
  String restrictionsTimeLeft(String duration) {
    return 'Noch $duration';
  }

  @override
  String get restrictionsLimitReached => 'Limit erreicht';

  @override
  String get rxWeek => 'Diese Woche';

  @override
  String get rxTopApps => 'Deine meistgenutzten Apps';

  @override
  String rxAverage(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Tagesdurchschnitt · $days erfasste Tage',
      one: 'Tagesdurchschnitt · 1 erfasster Tag',
    );
    return '$_temp0';
  }

  @override
  String get rxBusiest => 'Deine aktivsten Stunden';

  @override
  String rxPeak(String start, String end) {
    return 'Die meiste erfasste Nutzung liegt zwischen $start und $end.';
  }

  @override
  String get rxNoInsights =>
      'Noch nicht genug erfasste Nutzung für einen Zeitvorschlag.';

  @override
  String get rxPlanBlock => 'Zeitplan anlegen';

  @override
  String get rxYourRules => 'Deine Einschränkungen';

  @override
  String get rxLimit => 'Limit';

  @override
  String get rxEdit => 'Bearbeiten';

  @override
  String rxRestrict(String app) {
    return '$app einschränken';
  }

  @override
  String rxAverageApp(String duration) {
    return 'Durchschnittlich $duration / Tag';
  }

  @override
  String get rxType => 'Art der Einschränkung';

  @override
  String get rxDailyLimit => 'Tageslimit';

  @override
  String get rxBlockNow => 'Jetzt sperren';

  @override
  String get rxDifficulty => 'Schwierigkeit beim Entsperren';

  @override
  String get rxEasy => 'Einfach';

  @override
  String get rxModerate => 'Mittel';

  @override
  String get rxHard => 'Schwer';

  @override
  String get rxEasyHint => 'Zum Entsperren bestätigen';

  @override
  String get rxModerateHint => 'Zum Entsperren 5 Minuten warten';

  @override
  String get rxHardHint => 'Kein vorzeitiges Entsperren in FocusTrace';

  @override
  String get rxProtectionNote =>
      'Dies gilt auch für das Ändern oder Entfernen einer aktiven Regel.';

  @override
  String get rxSetLimit => 'Tageslimit festlegen';

  @override
  String get rxSetSchedule => 'Zeitplan festlegen';

  @override
  String get rxStartBlock => 'Sperre starten';

  @override
  String rxBelowAverage(String duration) {
    return '$duration unter deinem Tagesdurchschnitt';
  }

  @override
  String get rxRepeat => 'Wiederholen';

  @override
  String get rxNextDay => 'Endet am nächsten Tag';

  @override
  String rxEndsAt(String time) {
    return 'Endet um $time';
  }

  @override
  String get rxHardConfirm =>
      'Solange diese Regel eine App sperrt, kannst du sie in FocusTrace nicht vorzeitig entsperren, bearbeiten oder entfernen.';

  @override
  String get rxConfirm => 'Bestätigen';

  @override
  String get rxChangeTitle => 'Einschränkung ändern?';

  @override
  String get rxChangeBody =>
      'Einfache Regeln lassen sich sofort ändern. Mittlere Regeln erfordern fünf Minuten Wartezeit. Schwere Regeln bleiben bis zum Ende der aktuellen Sperre gesperrt.';

  @override
  String get rxCooldown =>
      'Fünf Minuten Wartezeit gestartet. Versuche es danach erneut; die App bleibt bis zur erneuten Bestätigung gesperrt.';

  @override
  String get rxHardLocked =>
      'Diese Regel bleibt bis zum Ende der aktuellen Sperre gesperrt.';

  @override
  String get rxUnavailable =>
      'Die Einschränkung konnte nicht geprüft werden. Prüfe den Nutzungszugriff und versuche es erneut.';

  @override
  String get rxMinutes => 'Dauer in Minuten';

  @override
  String get rxRetry => 'Erneut versuchen';

  @override
  String get rxScheduleInvalid =>
      'Wähle unterschiedliche Start- und Endzeiten und mindestens einen Tag.';

  @override
  String get rxNoUsage =>
      'Keine erfasste Nutzung für diesen Zeitraum. Du kannst trotzdem eine App einschränken.';

  @override
  String rxNextBlock(String time) {
    return 'Nächster Start: $time';
  }

  @override
  String rxPerDay(String duration) {
    return '$duration / Tag';
  }

  @override
  String rxUntil(String time) {
    return 'Bis $time';
  }

  @override
  String rxLeftToday(String duration) {
    return 'Heute noch $duration';
  }

  @override
  String rxStarts(String time) {
    return 'Beginnt $time';
  }

  @override
  String get rxStartLabel => 'Beginn';

  @override
  String get rxEndLabel => 'Ende';

  @override
  String get rxHoursField => 'Stunden';

  @override
  String get rxMinutesField => 'Minuten';

  @override
  String get rxAdd => 'Hinzufügen';

  @override
  String get rxNoRulesYet =>
      'Noch keine Einschränkungen. Wähle unten eine App oder tippe auf Hinzufügen.';

  @override
  String get rxChooseApps => 'Apps zum Begrenzen wählen';

  @override
  String get rxSearchAll => 'Alle Apps durchsuchen';

  @override
  String get rxTodayUsage => 'Heutige Nutzung bisher';

  @override
  String get rxCreate => 'Erstellen';

  @override
  String rxSharedLimit(String duration) {
    return 'Gemeinsames Tageslimit · $duration';
  }

  @override
  String rxMoreApps(String names, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Apps',
      one: '1 App',
    );
    return '$names + $_temp0';
  }

  @override
  String get rxPaused => 'Pausiert';

  @override
  String rxUsed(String duration) {
    return '$duration genutzt';
  }

  @override
  String rxLeft(String duration) {
    return 'Noch $duration';
  }

  @override
  String get rxEveryDay => 'Jeden Tag';

  @override
  String get rxUnblockAfterWait => 'Nach 5 Minuten Wartezeit entsperren';

  @override
  String rxLockedUntil(String time) {
    return 'Gesperrt bis $time';
  }

  @override
  String get rxEditDuration => 'Dauer bearbeiten';

  @override
  String get rxSaveChanges => 'Änderungen speichern';

  @override
  String get rxEasyExplain =>
      'Du kannst nach einer Bestätigung vorzeitig entsperren. Auch das Bearbeiten oder Entfernen der Regel während einer Sperre erfordert eine Bestätigung.';

  @override
  String get rxModerateExplain =>
      'Vorzeitiges Entsperren oder das Bearbeiten oder Entfernen der Regel während einer Sperre startet eine Wartezeit von fünf Minuten. Die App bleibt so lange gesperrt. Wiederhole danach die Aktion und bestätige erneut. Nichts wird von selbst entsperrt.';

  @override
  String get rxHardExplain =>
      'Solange diese Regel sperrt, entsperrt FocusTrace nicht vorzeitig, und du kannst sie bis zum Ende der Sperre weder bearbeiten noch entfernen. Außerhalb der Sperrzeiten kannst du sie normal ändern.';

  @override
  String get rxModerateUnblockBody =>
      'Damit startet eine Wartezeit von fünf Minuten. Die App bleibt bis dahin gesperrt. Wähle danach erneut Entsperren und bestätige.';

  @override
  String get routineLastAppPrompt =>
      'Diese Routine hat keine Apps mehr. Routine löschen?';

  @override
  String get routineKeepRoutine => 'Routine behalten';

  @override
  String get routineNamePrompt => 'Routinenamen hinzufügen';

  @override
  String get routineEmpty =>
      'Diese Routine enthält noch keine Apps. Füge Apps hinzu, um ihre Limits wieder zu nutzen.';

  @override
  String get routineNoAppsShort => 'Noch keine Apps';

  @override
  String get routinePickerAll => 'Alle';

  @override
  String routinePickerSelectCategory(String category) {
    return 'Alle in $category auswählen';
  }

  @override
  String get routineAddApps => 'Apps hinzufügen';

  @override
  String routineAddSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Apps hinzufügen',
      one: '1 App hinzufügen',
    );
    return '$_temp0';
  }

  @override
  String routineAppLimit(String duration) {
    return 'App-Limit $duration';
  }

  @override
  String get routineNoAppLimit => 'Kein App-Limit';

  @override
  String routineAppLimitTitle(String app) {
    return 'Tageslimit für $app';
  }

  @override
  String get routineAppLimitHint =>
      'Begrenzt nur diese App. Ihre Zeit zählt weiter zum gemeinsamen Kontingent.';

  @override
  String routineReasonShared(String routine) {
    return '$routine: gemeinsames Kontingent aufgebraucht';
  }

  @override
  String routineReasonApp(String routine) {
    return '$routine: App-Limit erreicht';
  }

  @override
  String get reasonDailyAppLimit => 'Tageslimit der App erreicht';

  @override
  String reasonScheduleUntil(String time) {
    return 'Durch Zeitplan gesperrt bis $time';
  }

  @override
  String reasonTemporaryUntil(String time) {
    return 'Vorübergehend gesperrt bis $time';
  }

  @override
  String routineOpenDetails(String app) {
    return 'Details zu $app öffnen';
  }

  @override
  String get usageTimelineHint =>
      'Tippen oder ziehen für genaue Zeiten · halten, um einen Zeitraum einzuschränken';

  @override
  String get rxRangeQuestion => 'Diesen Zeitraum einschränken?';

  @override
  String get rxRangeHint =>
      'Ziehe oder tippe auf den Ring, um das Ende zu verschieben';

  @override
  String get rxRangeAction => 'Einschränken';

  @override
  String get rxScheduleDialHint =>
      'Ziehe eines der roten Enden oder tippe, wohin es soll';

  @override
  String get healthConnectTitle => 'Health Connect';

  @override
  String get healthConnectSettingsOff =>
      'Aus · Trainings aus Apps wie Hevy importieren';

  @override
  String healthConnectSettingsOn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'An · $count Trainings importiert',
      one: 'An · 1 Training importiert',
      zero: 'An · noch keine Trainings importiert',
    );
    return '$_temp0';
  }

  @override
  String get healthConnectIntro =>
      'Importiere deine Trainings aus Apps wie Hevy über Health Connect von Android. Das ist optional und standardmäßig aus. Tracking, Limits und Sperren hängen nie davon ab.';

  @override
  String get healthConnectDataTitle => 'Was FocusTrace liest';

  @override
  String get healthConnectDataBody =>
      'Nur Trainingseinheiten: die Art des Trainings, seinen Namen, Beginn und Ende und welche App es aufgezeichnet hat. Sonst nichts, etwa Herzfrequenz, Routen oder Sätze, und FocusTrace schreibt nichts in Health Connect. Importierte Trainings bleiben auf diesem Gerät: Die Synchronisierung lädt sie nicht hoch und Sicherungen enthalten sie nicht.';

  @override
  String get healthConnectImportSwitch => 'Trainings importieren';

  @override
  String get healthConnectAutoImport => 'Automatisch importieren';

  @override
  String get healthConnectAutoImportBody =>
      'Sucht alle paar Stunden nach neuen Trainings. Apps synchronisieren nach eigenem Zeitplan mit Health Connect, daher kann ein Training eine Weile brauchen, bis es erscheint.';

  @override
  String get healthConnectAutoImportUnsupported =>
      'Automatischer Import braucht eine neuere Version von Health Connect. Jetzt importieren funktioniert trotzdem.';

  @override
  String get healthConnectAutoImportBlocked =>
      'Health Connect erlaubt FocusTrace nicht, im Hintergrund zu lesen, daher kann der automatische Import nicht laufen. Erlaube es in Health Connect oder nutze Jetzt importieren.';

  @override
  String get healthConnectImportNow => 'Jetzt importieren';

  @override
  String healthConnectLastSuccess(String time) {
    return 'Letzter erfolgreicher Import: $time';
  }

  @override
  String get healthConnectNeverImported => 'Noch nichts importiert';

  @override
  String healthConnectOutcomeImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Letzte Prüfung: $count Trainings hinzugefügt oder aktualisiert',
      one: 'Letzte Prüfung: 1 Training hinzugefügt oder aktualisiert',
    );
    return '$_temp0';
  }

  @override
  String get healthConnectOutcomeNoNew =>
      'Letzte Prüfung: keine neuen Trainings';

  @override
  String get healthConnectOutcomeUnavailable =>
      'Letzte Prüfung fehlgeschlagen: Health Connect ist nicht verfügbar';

  @override
  String get healthConnectOutcomePermission =>
      'Letzte Prüfung fehlgeschlagen: Zugriff auf Trainingsdaten ist in Health Connect aus';

  @override
  String get healthConnectOutcomeBackground =>
      'Letzte automatische Prüfung konnte nicht im Hintergrund laufen';

  @override
  String get healthConnectOutcomeFailed =>
      'Letzte Prüfung wurde nicht abgeschlossen. Sie wird erneut versucht.';

  @override
  String get healthConnectUnavailable =>
      'Health Connect ist auf diesem Gerät nicht verfügbar. Es braucht Android 9 oder neuer.';

  @override
  String get healthConnectUpdateRequired =>
      'Installiere oder aktualisiere Health Connect aus Google Play, um das zu nutzen.';

  @override
  String get healthConnectGetApp => 'Google Play öffnen';

  @override
  String get healthConnectRevoked =>
      'FocusTrace hat keinen Zugriff mehr auf deine Trainingsdaten. Erteile ihn erneut, um weiter zu importieren.';

  @override
  String get healthConnectGrantAgain => 'Zugriff erteilen';

  @override
  String get healthConnectManage => 'Zugriff in Health Connect verwalten';

  @override
  String get healthConnectOffNote =>
      'Ausschalten stoppt jedes Lesen und jeden geplanten Import. Die Berechtigung von FocusTrace und alles in Health Connect bleiben unverändert; verwalte das dort. Bereits importierte Trainings bleiben auf diesem Gerät, bis du sie löschst.';

  @override
  String get healthConnectDeleteImported => 'Importierte Trainings löschen';

  @override
  String get healthConnectDeleteTitle => 'Importierte Trainings löschen?';

  @override
  String get healthConnectDeleteBody =>
      'Damit werden die Trainings entfernt, die FocusTrace auf dieses Gerät kopiert hat. In Health Connect und den aufzeichnenden Apps ändert sich nichts.';

  @override
  String get healthConnectDelete => 'Löschen';

  @override
  String get healthConnectWorkoutsTitle => 'Importierte Trainings';

  @override
  String get healthConnectNoWorkouts =>
      'Noch keine Trainings. Der erste Import umfasst die letzten 30 Tage; ältere Trainings werden nicht importiert.';

  @override
  String healthConnectWorkoutSource(String duration, String app) {
    return '$duration · aus $app';
  }

  @override
  String get workoutStrength => 'Krafttraining';

  @override
  String get workoutRunning => 'Laufen';

  @override
  String get workoutWalking => 'Gehen';

  @override
  String get workoutCycling => 'Radfahren';

  @override
  String get workoutSwimming => 'Schwimmen';

  @override
  String get workoutYoga => 'Yoga';

  @override
  String get workoutOther => 'Training';

  @override
  String get onboardingHealthTitle => 'Hol deine Trainings dazu';

  @override
  String get onboardingHealthBody =>
      'Optional. Importiere Trainings aus Apps wie Hevy über Health Connect. FocusTrace liest nur Trainingseinheiten und behält sie auf diesem Gerät. Du kannst das jederzeit in den Einstellungen ändern.';

  @override
  String get onboardingHealthConnect => 'Health Connect verbinden';

  @override
  String get onboardingHealthSkip => 'Nicht jetzt';

  @override
  String get onboardingHealthConnected =>
      'Verbunden. Deine Trainings findest du in den Einstellungen unter Health Connect.';

  @override
  String get onboardingHealthDenied =>
      'Es wurde kein Zugriff erteilt. Du kannst später in den Einstellungen verbinden.';

  @override
  String get settingsClearDataHealth =>
      'Der Health-Connect-Import wird ausgeschaltet und importierte Trainings werden gelöscht. In Health Connect ändert sich nichts.';
}
