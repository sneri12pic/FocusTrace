// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

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
  String get settingsClearDataDialogBody =>
      'Dadurch werden Nutzungsverlauf und Einstellungen dauerhaft von diesem Gerät gelöscht. Deine Sprachauswahl bleibt erhalten. Exportiere zuerst eine Sicherung, falls du die Daten später benötigst.';

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
}
