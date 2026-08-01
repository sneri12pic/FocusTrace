// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'FocusTrace';

  @override
  String get durationLessThanOneMinute => '<1 min';

  @override
  String durationMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHoursShort(int hours) {
    return '$hours h';
  }

  @override
  String durationHoursMinutesShort(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get categoryEntertainment => 'Divertissement';

  @override
  String get categoryProductivity => 'Productivité';

  @override
  String get categoryWeb => 'Web';

  @override
  String get categoryCommunication => 'Communication';

  @override
  String get categorySystem => 'Système';

  @override
  String get categoryActivity => 'Activité';

  @override
  String get onboardingSkip => 'Ignorer';

  @override
  String get onboardingGetStarted => 'Commencer';

  @override
  String get onboardingContinue => 'Continuer';

  @override
  String get onboardingStartSoftBlocks => 'Activer les blocages souples';

  @override
  String get onboardingChooseLater => 'Choisir plus tard';

  @override
  String get onboardingChooseWhatToLimit =>
      'Choisissez les applications à limiter';

  @override
  String get onboardingChooseWhatToLimitDescription =>
      'Sélectionnez des applications et définissez un objectif quotidien pour les blocages souples.';

  @override
  String get onboardingNoAppsToChooseTitle =>
      'Aucune application à choisir pour le moment';

  @override
  String get onboardingNoAppsToChooseBody =>
      'FocusTrace a besoin de données d’utilisation récentes avant de pouvoir afficher des applications ici. Vous pouvez ignorer la configuration et ajouter des restrictions plus tard dans les paramètres.';

  @override
  String get onboardingNoMatchingAppsTitle => 'Aucune application trouvée';

  @override
  String get onboardingNoMatchingAppsBody =>
      'Essayez un autre terme de recherche.';

  @override
  String get onboardingWelcomeTitle =>
      'Reprenez le contrôle de votre temps d’écran';

  @override
  String get onboardingWelcomeBody =>
      'Comprenez où va votre attention.\nFixez des limites souples.\nAdoptez de meilleures habitudes à votre rythme.';

  @override
  String get onboardingAccessTitle => 'Accordez les accès à FocusTrace';

  @override
  String get onboardingAccessBody =>
      'FocusTrace a besoin de deux autorisations pour fonctionner.\nToutes vos données restent sur votre appareil.';

  @override
  String get onboardingNoPermissionsTitle =>
      'Aucune autorisation à accorder ici';

  @override
  String get onboardingNoPermissionsBody =>
      'Ces autorisations ne sont nécessaires que sur Android.';

  @override
  String get onboardingUsageAccessTitle => 'Accès aux données d’utilisation';

  @override
  String get onboardingUsageAccessSubtitle =>
      'Pour mesurer le temps passé sur vos applications';

  @override
  String get onboardingOverlayAccessTitle =>
      'Affichage par-dessus d’autres applications';

  @override
  String get onboardingOverlayAccessSubtitle =>
      'Pour afficher l’écran de blocage sur les applications que vous limitez';

  @override
  String get onboardingPermissionsSettingsHint =>
      'Vous pourrez modifier ce choix plus tard dans les paramètres.';

  @override
  String get onboardingAllow => 'Autoriser';

  @override
  String get onboardingSearchApps => 'Rechercher des applications';

  @override
  String onboardingAppUsageToday(String appKey, String duration) {
    return '$appKey · $duration aujourd’hui';
  }

  @override
  String get onboardingDailyTarget => 'Objectif quotidien';

  @override
  String get restrictionsTitle => 'Restrictions';

  @override
  String get restrictionsSearchApps => 'Rechercher des applications';

  @override
  String get restrictionsAddRestriction => 'Ajouter une restriction';

  @override
  String get restrictionsAddRoutine => 'Nouvelle routine';

  @override
  String get restrictionsRoutinesTitle => 'Routines de blocage';

  @override
  String get restrictionsRoutinesEmptyTitle => 'Aucune routine de blocage';

  @override
  String get restrictionsRoutinesEmptyBody =>
      'Regroupez des apps dans une routine, puis activez ou désactivez tout le groupe.';

  @override
  String get restrictionsIndividualRulesTitle => 'Restrictions individuelles';

  @override
  String restrictionsRoutineAppCount(int count) {
    return '$count applications';
  }

  @override
  String get restrictionsDeleteRoutine => 'Supprimer la routine';

  @override
  String get routineEditorNewTitle => 'Nouvelle routine de blocage';

  @override
  String get routineEditorEditTitle => 'Modifier la routine de blocage';

  @override
  String get routineEditorName => 'Nom de la routine';

  @override
  String get routineEditorSearchApps => 'Rechercher des apps';

  @override
  String get routineEditorNoMatchingApps => 'Aucune app correspondante';

  @override
  String get routineEditorSave => 'Enregistrer la routine';

  @override
  String get restrictionsPlatformStatusTitle =>
      'État disponible uniquement sur cette plateforme';

  @override
  String get restrictionsPlatformStatusBody =>
      'Les règles sont enregistrées et affichées ici. Le blocage plein écran ne fonctionne actuellement que sur Android.';

  @override
  String get restrictionsEmptyTitle => 'Aucune restriction d’application';

  @override
  String get restrictionsEmptyBody =>
      'Appuyez longuement sur une application dans les bulles d’utilisation ou la liste actuelle pour ajouter une règle.';

  @override
  String get restrictionsNoAppsAvailable =>
      'Aucune application disponible pour le moment. Ouvrez le tableau de bord une fois les données d’utilisation disponibles, puis effectuez une recherche ici.';

  @override
  String get restrictionsNoMatchingApps => 'Aucune application trouvée';

  @override
  String get restrictionsDeleteRule => 'Supprimer la règle';

  @override
  String get restrictionsUnblockNow => 'Débloquer maintenant';

  @override
  String restrictionsBlockedUntil(String time) {
    return 'Bloquée jusqu’à $time';
  }

  @override
  String get restrictionsTemporaryBlockExpired =>
      'Le blocage temporaire a expiré';

  @override
  String restrictionsDailyLimitStatus(
    String limitDuration,
    String usedDuration,
  ) {
    return 'Limite quotidienne : $limitDuration · Utilisation : $usedDuration';
  }

  @override
  String restrictionsScheduleStatus(String startTime, String endTime) {
    return 'Plage horaire : $startTime–$endTime';
  }

  @override
  String get restrictionsOverlayPermissionTitle =>
      'Autorisation de superposition requise';

  @override
  String get restrictionsOverlayPermissionBody =>
      'Android a besoin de l’autorisation d’affichage par-dessus d’autres applications avant que FocusTrace puisse afficher un écran de blocage.';

  @override
  String get restrictionsOpenOverlaySettings =>
      'Ouvrir les paramètres de superposition';

  @override
  String get restrictionsRecheck => 'Vérifier à nouveau';

  @override
  String get restrictionEditorAllowFullScreenTitle =>
      'Autoriser le blocage plein écran ?';

  @override
  String get restrictionEditorAllowFullScreenBody =>
      'FocusTrace a besoin de l’autorisation d’affichage par-dessus d’autres applications pour afficher un écran de blocage lorsqu’une application restreinte s’ouvre.';

  @override
  String get restrictionEditorLater => 'Plus tard';

  @override
  String get restrictionEditorOpenSettings => 'Ouvrir les paramètres';

  @override
  String get restrictionEditorTypeNow => 'Maintenant';

  @override
  String get restrictionEditorTypeLimit => 'Limite';

  @override
  String get restrictionEditorTypeSchedule => 'Plage horaire';

  @override
  String get restrictionEditorSaveRule => 'Enregistrer la règle';

  @override
  String get restrictionEditorTomorrow => 'Demain';

  @override
  String restrictionEditorDailyLimitPerDay(String duration) {
    return '$duration par jour';
  }

  @override
  String dashboardDayTracked(String duration) {
    return 'Temps suivi · $duration';
  }

  @override
  String get dashboardDayToday => 'Aujourd’hui';

  @override
  String get dashboardDayYesterday => 'Hier';

  @override
  String get dashboardPreviousDayTooltip => 'Jour précédent';

  @override
  String get dashboardNextDayTooltip => 'Jour suivant';

  @override
  String get navHome => 'Accueil';

  @override
  String get trackingRunsWhileOpen =>
      'Le suivi ne fonctionne que lorsque FocusTrace est ouvert.';

  @override
  String get dashboardStopTracking => 'Arrêter le suivi';

  @override
  String get dashboardStartTracking => 'Démarrer le suivi';

  @override
  String get dashboardNoUsageToday =>
      'Aucune utilisation enregistrée aujourd’hui.';

  @override
  String get dashboardNoUsageDay =>
      'Aucune utilisation enregistrée ce jour-là.';

  @override
  String get dashboardAllTimeMostUsedTitle => 'Application la plus utilisée';

  @override
  String get dashboardUnsupportedPlatform =>
      'Le MVP de FocusTrace prend en charge Android et Windows. D’autres plateformes pourront être ajoutées ultérieurement via des sources de données distinctes propres à chaque plateforme.';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonUnexpectedError =>
      'Un problème est survenu. Veuillez réessayer.';

  @override
  String get usageBubblesTitle => 'Bulles d’utilisation';

  @override
  String get usageBubblesDescription =>
      'Plus une bulle est grande, plus le temps d’utilisation est long';

  @override
  String get usageBubblesCurrentList => 'Liste actuelle';

  @override
  String get actionUnblockNow => 'Débloquer maintenant';

  @override
  String get actionUnblockNowDescription =>
      'Supprimer les règles de blocage actives';

  @override
  String get actionRestrictApp => 'Restreindre l’application...';

  @override
  String get actionRestrictAppDescription =>
      'Bloquer maintenant, définir une limite ou ajouter une plage horaire';

  @override
  String percentageValue(String percentage) {
    return '$percentage%';
  }

  @override
  String get actionRemoveFromToday => 'Retirer des données du jour';

  @override
  String get actionRemoveFromTodayDescription =>
      'Masquer cette application dans les statistiques d’aujourd’hui';

  @override
  String get actionExcludeFromTracking => 'Exclure du suivi';

  @override
  String get actionExcludeFromTrackingDescription =>
      'Arrêter le suivi et masquer dans toutes les statistiques';

  @override
  String excludeAppDialogTitle(String appName) {
    return 'Exclure $appName ?';
  }

  @override
  String get excludeAppDialogBody =>
      'L’application ne sera plus suivie ni affichée dans les statistiques. Vous pouvez annuler ce choix dans les paramètres.';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get actionExclude => 'Exclure';

  @override
  String sessionTotal(String duration) {
    return 'Total · $duration';
  }

  @override
  String get sessionDetailsUnavailable =>
      'Les détails des sessions ne sont pas disponibles sur cette plateforme.';

  @override
  String get sessionNoneRecorded => 'Aucune session enregistrée.';

  @override
  String get sessionLongestTitle => 'Sessions les plus longues';

  @override
  String sessionOngoingLabel(String startTime, String duration) {
    return '$startTime · $duration';
  }

  @override
  String sessionRangeLabel(String startTime, String endTime, String duration) {
    return '$startTime – $endTime · $duration';
  }

  @override
  String get permissionWindowsPrivacyTitle => 'Confidentialité Windows';

  @override
  String get permissionUsageAccessRequiredTitle =>
      'Accès aux données d’utilisation requis';

  @override
  String get permissionUsageAccessRequiredBody =>
      'FocusTrace a besoin de l’accès aux données d’utilisation Android pour lire l’utilisation de vos propres applications. Les données restent stockées localement sur cet appareil.';

  @override
  String get permissionOpenUsageAccessSettings =>
      'Ouvrir les paramètres d’accès aux données d’utilisation';

  @override
  String get commonRecheck => 'Vérifier à nouveau';

  @override
  String get trackingWindowsRunning =>
      'Le suivi Windows est actif tant que FocusTrace est ouvert.';

  @override
  String get trackingWindowsIdle =>
      'Le suivi Windows ne fonctionne que tant que FocusTrace est ouvert.';

  @override
  String get trackingAndroidUsageAccess =>
      'L’utilisation sur Android est lue via l’accès aux données d’utilisation.';

  @override
  String get trackingUnsupportedPlatform =>
      'Le suivi de l’utilisation n’est pas encore pris en charge sur cette plateforme.';

  @override
  String get trackingError =>
      'Un problème est survenu pendant le suivi. Une nouvelle tentative aura lieu automatiquement.';

  @override
  String bubblePercentageOfToday(String percentage) {
    return '$percentage% du total d’aujourd’hui';
  }

  @override
  String usageBubbleSemanticsLabel(String appName, String category) {
    return '$appName, $category';
  }

  @override
  String usageBubbleNearLimitSemanticsLabel(String appName, String category) {
    return '$appName, $category, limite quotidienne presque atteinte';
  }

  @override
  String summaryLaunchCount(int count) {
    return 'Lancements : $count';
  }

  @override
  String get usageTrendDayShort => 'J';

  @override
  String get usageTrendWeekShort => 'S';

  @override
  String get usageTrendMonthShort => 'M';

  @override
  String usageTrendIncrease(String period, int percentage) {
    return '$period : utilisation en hausse de $percentage %';
  }

  @override
  String usageTrendDecrease(String period, int percentage) {
    return '$period : utilisation en baisse de $percentage %';
  }

  @override
  String usageTrendUnchanged(String period) {
    return '$period : utilisation inchangée';
  }

  @override
  String get usageDetailsLastSevenDays => '7 derniers jours';

  @override
  String usageDetailsMoreThanYesterday(int percentage) {
    return '$percentage % de plus qu’hier';
  }

  @override
  String usageDetailsLessThanYesterday(int percentage) {
    return '$percentage % de moins qu’hier';
  }

  @override
  String get usageDetailsSameAsYesterday => 'Identique à hier';

  @override
  String get usageDetailsNoYesterdayComparison =>
      'Pas encore de comparaison avec hier';

  @override
  String usageDetailsRankLabel(int rank) {
    return 'N° $rank des plus utilisées';
  }

  @override
  String usageDetailsRankLead(String duration, String appName) {
    return '$duration de plus que $appName';
  }

  @override
  String usageDetailsDayValue(String date, String duration) {
    return '$date : $duration';
  }

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsPrivacyTitle => 'Confidentialité';

  @override
  String get settingsPrivacyBody =>
      'FocusTrace stocke les données d’utilisation localement sur cet appareil. L’application ne transfère aucune donnée enregistrée sur l’utilisation des applications ou des fenêtres.';

  @override
  String get settingsClearLocalData => 'Effacer les données locales';

  @override
  String get settingsLanguageTitle => 'Langue';

  @override
  String get settingsLanguageSystemDefault => 'Langue du système';

  @override
  String get settingsChooseLanguage => 'Choisir la langue';

  @override
  String get settingsLanguageUpdateError =>
      'La préférence linguistique n’a pas pu être appliquée. Veuillez réessayer.';

  @override
  String get settingsExcludedAppsTitle => 'Applications exclues';

  @override
  String get settingsExcludedAppsEmpty =>
      'Aucune application exclue. Appuyez longuement sur une application du tableau de bord pour l’exclure du suivi.';

  @override
  String get settingsStopExcluding => 'Ne plus exclure';

  @override
  String get settingsWindowsTrackingComingSoon =>
      'Bientôt disponible : suivi Windows';

  @override
  String get settingsSendFeedback => 'Envoyer un commentaire';

  @override
  String get settingsWindowsTrackingInterval => 'Intervalle de suivi Windows';

  @override
  String get settingsWindowsIdleTimeout => 'Délai d’inactivité Windows';

  @override
  String get settingsClearDataDialogTitle => 'Effacer les données locales ?';

  @override
  String get settingsClearDataDialogBody =>
      'Cette action supprime de cet appareil les sessions d’utilisation et les paramètres enregistrés. Votre choix de langue est conservé.';

  @override
  String get settingsCancel => 'Annuler';

  @override
  String get settingsClear => 'Effacer';

  @override
  String get settingsSave => 'Enregistrer';

  @override
  String secondsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count secondes',
      one: '1 seconde',
    );
    return '$_temp0';
  }
}
