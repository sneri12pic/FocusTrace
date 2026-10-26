// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appCategoryAll => 'Toutes';

  @override
  String get appCategoryTitle => 'Catégorie de l’application';

  @override
  String get appCategoryAutomatic => 'Automatique';

  @override
  String get appCategorySave => 'Enregistrer la catégorie';

  @override
  String get appCategorySaveError =>
      'Impossible d’enregistrer la catégorie. Réessayez.';

  @override
  String get usageDetailsBarChart => 'Graphique en barres';

  @override
  String get usageDetailsAreaChart => 'Évolution de l\'utilisation';

  @override
  String get usageDetailsChartSaveError =>
      'Impossible d\'enregistrer le graphique choisi. Réessaie.';

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
      'Les deux premières autorisations sont contrôlées dans les paramètres Android.';

  @override
  String get onboardingAllow => 'Autoriser';

  @override
  String get onboardingOpenSettings => 'Ouvrir les paramètres';

  @override
  String get onboardingNotificationsTitle => 'Notifications';

  @override
  String get onboardingNotificationsSubtitle =>
      'Facultatif : recevez une alerte avant d’atteindre une limite quotidienne';

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
  String get routineDailyLimit => 'Limite quotidienne partagée';

  @override
  String get routineNoDailyLimit => 'Aucune limite quotidienne';

  @override
  String get routineCustomDuration => 'Personnalisée';

  @override
  String get routineChooseDuration => 'Choisir la limite quotidienne';

  @override
  String get routineNotFound => 'Cette routine n’existe plus.';

  @override
  String get routineRename => 'Renommer la routine';

  @override
  String get routineAppsTitle => 'Applications';

  @override
  String get routineAddApp => 'Ajouter une application';

  @override
  String routineAppUsage(String duration) {
    return '$duration aujourd’hui · Incluse dans la limite';
  }

  @override
  String routineAppUsageExcluded(String duration) {
    return '$duration aujourd’hui · Exclue de la limite';
  }

  @override
  String get routineRemoveApp => 'Retirer l’application';

  @override
  String get routineKeepOneApp =>
      'Une routine doit conserver au moins une application.';

  @override
  String routineDeleteConfirmation(String name) {
    return 'Supprimer $name ? Cette action est irréversible.';
  }

  @override
  String get routineUsageToday => 'Utilisation comptabilisée aujourd’hui';

  @override
  String get routineNoIncludedApps =>
      'Incluez au moins une application pour activer la limite';

  @override
  String get routineLimitReached =>
      'Limite atteinte · les applications incluses sont bloquées jusqu’à minuit';

  @override
  String get routineActive => 'Active';

  @override
  String get routinePaused => 'En pause';

  @override
  String routineUsageOfLimit(String used, String limit) {
    return '$used sur $limit';
  }

  @override
  String routineRemaining(String duration) {
    return '$duration restantes';
  }

  @override
  String get routineSetLimit => 'Définir la limite';

  @override
  String get routineEditLimit => 'Modifier la limite';

  @override
  String get routineRemoveLimit => 'Supprimer la limite';

  @override
  String routineUsageOnly(String duration) {
    return '$duration aujourd’hui';
  }

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
  String get dashboardUsageUnavailableDay =>
      'Les données d\'utilisation sont actuellement indisponibles pour ce jour.';

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
  String usageListShowAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tout afficher ($count de plus)',
      one: 'Tout afficher (1 de plus)',
    );
    return '$_temp0';
  }

  @override
  String get usageListShowLess => 'Afficher moins';

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
  String get usageTrendNew => 'Nouveau';

  @override
  String usageTrendNewLabel(String period) {
    return '$period : nouvelle utilisation, aucune donnée antérieure à comparer';
  }

  @override
  String usageTrendIncreaseAboveCap(String period, int percentage) {
    return '$period : utilisation en hausse de plus de $percentage %';
  }

  @override
  String get usageDetailsLastSevenDays => '7 derniers jours';

  @override
  String get usageDetailsTimeTracked => 'Temps suivi';

  @override
  String get usageDetailsPeriodSevenDays => '7 jours';

  @override
  String get usageDetailsPeriodTwoWeeks => '2 semaines';

  @override
  String get usageDetailsPeriodMonth => 'Un mois';

  @override
  String get usageDetailsPeriodYear => 'Un an';

  @override
  String usageDetailsPeriodTotal(String period, String duration) {
    return '$period : $duration';
  }

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
  String get reportsTitle => 'Rapports';

  @override
  String get reportsWeekly => 'Hebdomadaire';

  @override
  String get reportsMonthly => 'Mensuel';

  @override
  String get reportsYearly => 'Annuel';

  @override
  String get reportsTotalUsage => 'Utilisation totale';

  @override
  String get reportsDailyAverage => 'Moyenne quotidienne';

  @override
  String get reportsActiveDays => 'Jours actifs';

  @override
  String get reportsTimeOfDayTitle => 'Utilisation selon l’heure';

  @override
  String get reportsHabitTitle => 'Formation des habitudes';

  @override
  String get reportsPeakTime => 'Période la plus active';

  @override
  String get reportsFirstUse => 'Première utilisation moyenne';

  @override
  String get reportsFirstApp => 'Première app la plus fréquente';

  @override
  String get reportsConsistency => 'Régularité de la première utilisation';

  @override
  String reportsVariationMinutes(int minutes) {
    return '± $minutes min';
  }

  @override
  String get reportsWakeHeuristic =>
      'La première utilisation est estimée après au moins 4 heures d’inactivité, entre 04:00 et 14:00.';

  @override
  String get reportsTopApps => 'Apps les plus utilisées';

  @override
  String get reportsRestrictionsTitle => 'Activité des restrictions';

  @override
  String get reportsBlockedAttempts => 'Tentatives bloquées';

  @override
  String get reportsManualUnblocks => 'Déblocages manuels';

  @override
  String get reportsBlocked => 'Bloquée';

  @override
  String get reportsUnblocked => 'Débloquée';

  @override
  String get reportsEmpty =>
      'Il n’y a pas encore assez de données locales pour ce rapport.';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsGeneralSection => 'Général';

  @override
  String get settingsActivityDataSection => 'Activité et données';

  @override
  String get settingsSupportSection => 'Assistance';

  @override
  String get settingsPrivacyTitle => 'Données et confidentialité';

  @override
  String get settingsPrivacyBody =>
      'Votre historique d’utilisation et vos paramètres restent sur cet appareil, sauf si vous exportez une sauvegarde. FocusTrace ne les transfère jamais.';

  @override
  String get settingsClearLocalData => 'Supprimer les données locales';

  @override
  String get settingsDataTransferTitle => 'Sauvegarde et restauration';

  @override
  String get settingsDataTransferBody =>
      'Enregistrez une sauvegarde portable ou restaurez les données d’une autre installation de FocusTrace. Les données importées sont fusionnées avec celles déjà présentes sur cet appareil.';

  @override
  String get settingsExportData => 'Exporter les données';

  @override
  String get settingsImportData => 'Importer les données';

  @override
  String get settingsExportSuccess => 'Sauvegarde FocusTrace enregistrée.';

  @override
  String get settingsImportSuccess => 'Sauvegarde FocusTrace importée.';

  @override
  String get settingsImportDialogTitle => 'Importer les données FocusTrace ?';

  @override
  String get settingsImportDialogBody =>
      'La sauvegarde sera fusionnée avec les données locales existantes. Les enregistrements et réglages correspondants utiliseront les valeurs importées.';

  @override
  String get settingsImportDialogDetail =>
      'Cela inclut les restrictions, routines de blocage, applications exclues et catégories d’applications si la sauvegarde en contient. Rien n’est supprimé sur cet appareil et la connexion de synchronisation reste inchangée.';

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
  String get settingsExcludedAppsTitle => 'Exclusions du suivi';

  @override
  String get settingsExcludedAppsEmpty =>
      'Aucune application n’est exclue du suivi. Appuyez longuement sur une application du tableau de bord pour l’ajouter ici.';

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
  String get settingsClearDataDialogTitle =>
      'Supprimer toutes les données locales ?';

  @override
  String get settingsClearDataDeletes =>
      'Supprimé de cet appareil : historique d’utilisation et rapports, restrictions et routines de blocage, applications exclues, catégories d’applications et autres réglages.';

  @override
  String get settingsClearDataKeeps =>
      'Conservé : votre choix de langue. Les autorisations Android ne changent pas. Exportez d’abord une sauvegarde si vous pourriez avoir besoin de ces données.';

  @override
  String get settingsClearDataKeepsSync =>
      'Votre compte cloud et les données déjà synchronisées ne sont pas supprimés. La synchronisation est désactivée sur cet appareil.';

  @override
  String get settingsClearDataDone => 'Données locales supprimées.';

  @override
  String get settingsCancel => 'Annuler';

  @override
  String get settingsClear => 'Supprimer';

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

  @override
  String get settingsSyncSection => 'Compte et synchronisation';

  @override
  String get settingsSyncTitle => 'Synchronisation cloud';

  @override
  String get settingsSyncBody =>
      'Connectez-vous pour copier vos totaux d’utilisation quotidiens vers votre compte et les consulter sur un autre appareil. Désactivée tant que vous ne l’activez pas.';

  @override
  String get settingsSyncEmail => 'E-mail';

  @override
  String get settingsSyncPassword => 'Mot de passe';

  @override
  String get settingsSyncPasswordRequirements =>
      'Utilisez entre 15 et 128 caractères. Quelques mots sans rapport forment une phrase de passe sûre et facile à retenir. Les mots de passe courants ne sont pas acceptés.';

  @override
  String get settingsSyncShowPassword => 'Afficher le mot de passe';

  @override
  String get settingsSyncHidePassword => 'Masquer le mot de passe';

  @override
  String get settingsSyncSignInHeading => 'Connectez-vous à votre compte';

  @override
  String get settingsSyncCreateHeading => 'Créez un compte de synchronisation';

  @override
  String get settingsSyncSwitchToCreate =>
      'Première synchronisation ? Créez un compte';

  @override
  String get settingsSyncSwitchToSignIn =>
      'Vous avez déjà un compte ? Connectez-vous';

  @override
  String get settingsSyncSignInInstead => 'Se connecter à la place';

  @override
  String get settingsSyncSigningIn => 'Connexion en cours…';

  @override
  String get settingsSyncCreatingAccount => 'Création du compte…';

  @override
  String get settingsSyncAccountCreated => 'Compte créé';

  @override
  String settingsSyncSignedInAs(String email) {
    return 'Connecté avec $email';
  }

  @override
  String get settingsSyncCreatedNextStep =>
      'La synchronisation est encore désactivée. Activez-la quand vous souhaitez copier les totaux quotidiens de cet appareil vers votre compte.';

  @override
  String get settingsSyncTurnOnSync => 'Activer la synchronisation';

  @override
  String get settingsSyncAccountCreatedSignInRequired =>
      'Votre compte a été créé, mais la connexion automatique a échoué. Saisissez votre mot de passe et appuyez sur « Se connecter » pour continuer.';

  @override
  String get settingsSyncErrorRegistration =>
      'Compte non créé. Vérifiez votre adresse e-mail et votre mot de passe, puis réessayez.';

  @override
  String get settingsSyncErrorEmailRequired =>
      'Saisissez votre adresse e-mail.';

  @override
  String get settingsSyncErrorEmailInvalid =>
      'Saisissez une adresse e-mail valide, comme nom@example.com.';

  @override
  String get settingsSyncErrorPasswordRequired =>
      'Saisissez votre mot de passe.';

  @override
  String settingsSyncErrorPasswordTooShort(int count) {
    return 'Utilisez au moins 15 caractères ($count pour le moment).';
  }

  @override
  String get settingsSyncErrorPasswordTooLong =>
      'Utilisez au maximum 128 caractères.';

  @override
  String get settingsSyncErrorPasswordRejected =>
      'Ce mot de passe est trop courant ou correspond à votre adresse e-mail. Choisissez-en un autre.';

  @override
  String get settingsSyncErrorThrottled =>
      'Trop de tentatives depuis ce réseau. Attendez un moment, puis réessayez.';

  @override
  String get settingsSyncSignIn => 'Se connecter';

  @override
  String get settingsSyncCreateAccount => 'Créer un compte';

  @override
  String get settingsSyncSignOut => 'Se déconnecter';

  @override
  String get settingsSyncEnabledLabel => 'Synchroniser cet appareil';

  @override
  String get settingsSyncEnabledSubtitle =>
      'La désactivation arrête l’envoi de nouvelles données. Rien de déjà synchronisé n’est supprimé.';

  @override
  String get settingsSyncNow => 'Synchroniser maintenant';

  @override
  String get settingsSyncNeverSynced => 'Pas encore synchronisé';

  @override
  String get settingsSyncStateSyncing => 'Synchronisation...';

  @override
  String get settingsSyncStateSuccess => 'Synchronisation terminée';

  @override
  String get settingsSyncStateError => 'Échec de la synchronisation';

  @override
  String get settingsSyncErrorOffline =>
      'Service de synchronisation injoignable. Vérifiez votre connexion et réessayez.';

  @override
  String get settingsSyncErrorCredentials =>
      'Cet e-mail et ce mot de passe ne correspondent à aucun compte.';

  @override
  String get settingsSyncErrorEmailTaken =>
      'Un compte existe déjà pour cet e-mail.';

  @override
  String get settingsSyncErrorWeakPassword =>
      'Choisissez un mot de passe plus long et moins courant.';

  @override
  String get settingsSyncErrorSessionExpired =>
      'Votre session a expiré. Reconnectez-vous.';

  @override
  String get settingsSyncErrorRefused => 'Le service a refusé la requête.';

  @override
  String get settingsSyncErrorUnknown => 'Une erreur est survenue. Réessayez.';

  @override
  String get settingsSyncDeleteAccount => 'Supprimer le compte';

  @override
  String get settingsSyncDeleteTitle => 'Supprimer votre compte FocusTrace ?';

  @override
  String get settingsSyncDeleteBody =>
      'Cela supprime définitivement votre compte cloud FocusTrace et toutes les données d’utilisation synchronisées sur le serveur. Cette action est irréversible.\n\nL’historique d’utilisation de cet appareil est conservé et la synchronisation sera désactivée.';

  @override
  String get settingsSyncDeletePassword => 'Mot de passe actuel';

  @override
  String get settingsSyncDeleteConfirm => 'Supprimer définitivement';

  @override
  String get settingsSyncDeleted =>
      'Votre compte FocusTrace a été supprimé. L’historique d’utilisation de cet appareil a été conservé.';

  @override
  String get settingsSyncRepeatPassword => 'Répéter le mot de passe';

  @override
  String get settingsSyncShowRepeatPassword =>
      'Afficher le mot de passe répété';

  @override
  String get settingsSyncHideRepeatPassword => 'Masquer le mot de passe répété';

  @override
  String get settingsSyncErrorPasswordMismatch =>
      'Les mots de passe ne correspondent pas.';

  @override
  String get settingsSyncDangerZone => 'Zone de danger';

  @override
  String get settingsSyncDangerZoneBody =>
      'Supprimer votre compte le supprime définitivement, ainsi que toutes les données d’utilisation synchronisées sur le serveur. L’historique d’utilisation de cet appareil est conservé.';

  @override
  String get settingsSyncDeleteAcknowledge =>
      'Je comprends que cela supprime définitivement mon compte cloud.';

  @override
  String get settingsSyncDeleting => 'Suppression…';

  @override
  String get settingsSyncErrorWrongPassword =>
      'Ce mot de passe est incorrect. Votre compte n’a pas été supprimé.';

  @override
  String get settingsPrivacyBodySync =>
      'Votre historique d’utilisation et vos réglages restent sur cet appareil, sauf si vous exportez une sauvegarde ou activez la synchronisation cloud.';

  @override
  String get usageCalendarTotalThisMonth => 'Total ce mois-ci';

  @override
  String get usageCalendarAveragePerDay => 'Moyenne par jour';

  @override
  String get usageCalendarAppOpens => 'Ouvertures';

  @override
  String get usageCalendarLongestSession => 'Session la plus longue';

  @override
  String get usageCalendarVsLastMonth => 'vs le mois dernier';

  @override
  String get usageCalendarPreviousMonth => 'Mois précédent';

  @override
  String get usageCalendarNextMonth => 'Mois suivant';

  @override
  String get usageCalendarTotalTime => 'Temps total';

  @override
  String get usageCalendarAverageSession => 'Session moyenne';

  @override
  String get usageCalendarVsDailyAverage => 'vs votre moyenne quotidienne';

  @override
  String get usageCalendarTimeline => 'Chronologie d\'utilisation';

  @override
  String get usageCalendarNoTimeline => 'Aucun détail de session pour ce jour';

  @override
  String get usageApproximateNote =>
      '≈ Approximatif : issu du résumé d\'utilisation d\'Android, avant l\'enregistrement par FocusTrace';

  @override
  String get usageApproximateTag => '≈ Approximatif';

  @override
  String get onboardingHistoryChecking =>
      'Recherche de l\'utilisation antérieure…';

  @override
  String get onboardingHistoryNone =>
      'Android n\'a enregistré aucune utilisation antérieure sur ce téléphone';

  @override
  String onboardingHistoryFound(String date) {
    return 'Utilisation antérieure trouvée depuis le $date';
  }

  @override
  String restrictionsTimeLeft(String duration) {
    return 'Encore $duration';
  }

  @override
  String get restrictionsLimitReached => 'Limite atteinte';

  @override
  String get rxWeek => 'Cette semaine';

  @override
  String get rxTopApps => 'Vos applications les plus utilisées';

  @override
  String rxAverage(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Moyenne quotidienne · $days jours enregistrés',
      one: 'Moyenne quotidienne · 1 jour enregistré',
    );
    return '$_temp0';
  }

  @override
  String get rxBusiest => 'Vos heures les plus actives';

  @override
  String rxPeak(String start, String end) {
    return 'L’utilisation enregistrée est la plus forte de $start à $end.';
  }

  @override
  String get rxNoInsights =>
      'Pas encore assez de données pour suggérer un horaire.';

  @override
  String get rxPlanBlock => 'Planifier un horaire';

  @override
  String get rxYourRules => 'Vos restrictions';

  @override
  String get rxLimit => 'Limite';

  @override
  String get rxEdit => 'Modifier';

  @override
  String rxRestrict(String app) {
    return 'Restreindre $app';
  }

  @override
  String rxAverageApp(String duration) {
    return 'Moyenne de $duration / jour';
  }

  @override
  String get rxType => 'Type de restriction';

  @override
  String get rxDailyLimit => 'Limite quotidienne';

  @override
  String get rxBlockNow => 'Bloquer maintenant';

  @override
  String get rxDifficulty => 'Difficulté du déblocage';

  @override
  String get rxEasy => 'Facile';

  @override
  String get rxModerate => 'Modérée';

  @override
  String get rxHard => 'Difficile';

  @override
  String get rxEasyHint => 'Confirmez pour débloquer';

  @override
  String get rxModerateHint => 'Attendez 5 minutes pour débloquer';

  @override
  String get rxHardHint => 'Aucun déblocage anticipé dans FocusTrace';

  @override
  String get rxProtectionNote =>
      'Cela s’applique aussi à la modification ou à la suppression d’une règle active.';

  @override
  String get rxSetLimit => 'Définir la limite quotidienne';

  @override
  String get rxSetSchedule => 'Définir le planning';

  @override
  String get rxStartBlock => 'Démarrer le blocage';

  @override
  String rxBelowAverage(String duration) {
    return '$duration de moins que votre moyenne quotidienne';
  }

  @override
  String get rxRepeat => 'Répéter';

  @override
  String get rxNextDay => 'Se termine le lendemain';

  @override
  String rxEndsAt(String time) {
    return 'Se termine à $time';
  }

  @override
  String get rxHardConfirm =>
      'Tant que cette règle bloque une application, vous ne pouvez pas la débloquer, modifier la règle ou la supprimer avant la fin dans FocusTrace.';

  @override
  String get rxConfirm => 'Confirmer';

  @override
  String get rxChangeTitle => 'Modifier la restriction ?';

  @override
  String get rxChangeBody =>
      'Les règles faciles peuvent être modifiées maintenant. Les règles modérées imposent cinq minutes d’attente. Les règles difficiles restent verrouillées jusqu’à la fin du blocage actuel.';

  @override
  String get rxCooldown =>
      'Le délai de cinq minutes a commencé. Réessayez ensuite ; l’application reste bloquée jusqu’à votre nouvelle confirmation.';

  @override
  String get rxHardLocked =>
      'Cette règle est verrouillée jusqu’à la fin du blocage actuel.';

  @override
  String get rxUnavailable =>
      'Impossible de vérifier cette restriction. Vérifiez l’accès aux données d’utilisation et réessayez.';

  @override
  String get rxMinutes => 'Durée en minutes';

  @override
  String get rxRetry => 'Réessayer';

  @override
  String get rxScheduleInvalid =>
      'Choisissez des heures de début et de fin différentes et au moins un jour.';

  @override
  String get rxNoUsage =>
      'Aucune utilisation enregistrée pour cette période. Vous pouvez quand même choisir une application à restreindre.';

  @override
  String rxNextBlock(String time) {
    return 'Prochain début : $time';
  }

  @override
  String rxPerDay(String duration) {
    return '$duration / jour';
  }

  @override
  String rxUntil(String time) {
    return 'Jusqu\'à $time';
  }

  @override
  String rxLeftToday(String duration) {
    return 'Encore $duration aujourd\'hui';
  }

  @override
  String rxStarts(String time) {
    return 'Commence $time';
  }

  @override
  String get rxStartLabel => 'Début';

  @override
  String get rxEndLabel => 'Fin';

  @override
  String get rxHoursField => 'Heures';

  @override
  String get rxMinutesField => 'Minutes';

  @override
  String get rxAdd => 'Ajouter';

  @override
  String get rxNoRulesYet =>
      'Aucune restriction pour le moment. Choisissez une app ci-dessous ou touchez Ajouter.';

  @override
  String get rxChooseApps => 'Choisir des apps à limiter';

  @override
  String get rxSearchAll => 'Rechercher dans toutes les apps';

  @override
  String get rxTodayUsage => 'Utilisation d\'aujourd\'hui jusqu\'ici';

  @override
  String get rxCreate => 'Créer';

  @override
  String rxSharedLimit(String duration) {
    return 'Limite quotidienne partagée · $duration';
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
  String get rxPaused => 'En pause';

  @override
  String rxUsed(String duration) {
    return '$duration utilisé';
  }

  @override
  String rxLeft(String duration) {
    return 'Reste $duration';
  }

  @override
  String get rxEveryDay => 'Tous les jours';

  @override
  String get rxUnblockAfterWait => 'Débloquer après 5 minutes d’attente';

  @override
  String rxLockedUntil(String time) {
    return 'Verrouillée jusqu’à $time';
  }

  @override
  String get rxEditDuration => 'Modifier la durée';

  @override
  String get rxSaveChanges => 'Enregistrer';

  @override
  String get rxEasyExplain =>
      'Vous pouvez débloquer plus tôt après confirmation. Modifier ou supprimer cette règle pendant un blocage demande aussi une confirmation.';

  @override
  String get rxModerateExplain =>
      'Débloquer plus tôt, ou modifier ou supprimer cette règle pendant un blocage, lance une attente de cinq minutes. L’app reste bloquée pendant ce temps. Une fois l’attente terminée, refaites l’action et confirmez à nouveau. Rien ne se débloque tout seul.';

  @override
  String get rxHardExplain =>
      'Tant que cette règle bloque, FocusTrace ne la débloque pas plus tôt et vous ne pouvez ni la modifier ni la supprimer avant la fin du blocage. En dehors des périodes de blocage, vous pouvez la modifier normalement.';

  @override
  String get rxModerateUnblockBody =>
      'Cela lance une attente de cinq minutes. L’app reste bloquée jusqu’à la fin. Choisissez ensuite à nouveau Débloquer et confirmez.';

  @override
  String get routineLastAppPrompt =>
      'Cette routine n’a plus d’apps. Supprimer la routine ?';

  @override
  String get routineKeepRoutine => 'Garder la routine';

  @override
  String get routineNamePrompt => 'Ajoutez un nom de routine';

  @override
  String get routineEmpty =>
      'Cette routine ne contient encore aucune app. Ajoutez des apps pour réutiliser ses limites.';

  @override
  String get routineNoAppsShort => 'Aucune app pour l’instant';

  @override
  String get routinePickerAll => 'Toutes';

  @override
  String routinePickerSelectCategory(String category) {
    return 'Tout sélectionner dans $category';
  }

  @override
  String get routineAddApps => 'Ajouter des apps';

  @override
  String routineAddSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ajouter $count apps',
      one: 'Ajouter 1 app',
    );
    return '$_temp0';
  }

  @override
  String routineAppLimit(String duration) {
    return 'Limite d’app $duration';
  }

  @override
  String get routineNoAppLimit => 'Pas de limite d’app';

  @override
  String routineAppLimitTitle(String app) {
    return 'Limite quotidienne pour $app';
  }

  @override
  String get routineAppLimitHint =>
      'Limite seulement cette app. Son temps compte toujours dans le temps partagé.';

  @override
  String routineReasonShared(String routine) {
    return '$routine : temps partagé épuisé';
  }

  @override
  String routineReasonApp(String routine) {
    return '$routine : limite de l’app atteinte';
  }

  @override
  String get reasonDailyAppLimit => 'Limite quotidienne de l’app atteinte';

  @override
  String reasonScheduleUntil(String time) {
    return 'Bloquée par l’horaire jusqu’à $time';
  }

  @override
  String reasonTemporaryUntil(String time) {
    return 'Blocage temporaire jusqu’à $time';
  }

  @override
  String routineOpenDetails(String app) {
    return 'Ouvrir les détails de $app';
  }

  @override
  String get usageTimelineHint =>
      'Touchez ou glissez pour les heures exactes · maintenez pour restreindre une plage';

  @override
  String get rxRangeQuestion => 'Restreindre cette plage horaire ?';

  @override
  String get rxRangeHint =>
      'Faites glisser ou touchez l’anneau pour déplacer la fin';

  @override
  String get rxRangeAction => 'Restreindre';

  @override
  String get rxScheduleDialHint =>
      'Faites glisser une extrémité rouge ou touchez l’endroit voulu';

  @override
  String get healthConnectTitle => 'Health Connect';

  @override
  String get healthConnectSettingsOff =>
      'Désactivé · importer les entraînements d\'apps comme Hevy';

  @override
  String healthConnectSettingsOn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Activé · $count entraînements importés',
      one: 'Activé · 1 entraînement importé',
      zero: 'Activé · aucun entraînement importé pour l\'instant',
    );
    return '$_temp0';
  }

  @override
  String get healthConnectIntro =>
      'Importez vos entraînements depuis des apps comme Hevy via Health Connect d\'Android. C\'est facultatif et désactivé par défaut. Le suivi, les limites et les blocages n\'en dépendent jamais.';

  @override
  String get healthConnectDataTitle => 'Ce que FocusTrace lit';

  @override
  String get healthConnectDataBody =>
      'Uniquement les séances d\'exercice : le type d\'entraînement, son nom, son début et sa fin, et l\'app qui l\'a enregistré. Rien d\'autre, comme la fréquence cardiaque, les parcours ou les séries, et FocusTrace n\'écrit rien dans Health Connect. Les entraînements importés restent sur cet appareil : la synchronisation ne les envoie pas et les sauvegardes ne les incluent pas.';

  @override
  String get healthConnectImportSwitch => 'Importer les entraînements';

  @override
  String get healthConnectAutoImport => 'Importer automatiquement';

  @override
  String get healthConnectAutoImportBody =>
      'Recherche de nouveaux entraînements toutes les quelques heures. Les apps se synchronisent avec Health Connect à leur rythme, un entraînement peut donc mettre du temps à apparaître.';

  @override
  String get healthConnectAutoImportUnsupported =>
      'L\'import automatique nécessite une version plus récente de Health Connect. Importer maintenant fonctionne toujours.';

  @override
  String get healthConnectAutoImportBlocked =>
      'Health Connect n\'autorise pas FocusTrace à lire en arrière-plan, l\'import automatique ne peut donc pas s\'exécuter. Autorisez-le dans Health Connect ou utilisez Importer maintenant.';

  @override
  String get healthConnectImportNow => 'Importer maintenant';

  @override
  String healthConnectLastSuccess(String time) {
    return 'Dernier import réussi : $time';
  }

  @override
  String get healthConnectNeverImported => 'Rien d\'importé pour l\'instant';

  @override
  String healthConnectOutcomeImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Dernière vérification : $count entraînements ajoutés ou mis à jour',
      one: 'Dernière vérification : 1 entraînement ajouté ou mis à jour',
    );
    return '$_temp0';
  }

  @override
  String get healthConnectOutcomeNoNew =>
      'Dernière vérification : aucun nouvel entraînement';

  @override
  String get healthConnectOutcomeUnavailable =>
      'Échec de la dernière vérification : Health Connect n\'est pas disponible';

  @override
  String get healthConnectOutcomePermission =>
      'Échec de la dernière vérification : l\'accès aux données d\'exercice est désactivé dans Health Connect';

  @override
  String get healthConnectOutcomeBackground =>
      'La dernière vérification automatique n\'a pas pu s\'exécuter en arrière-plan';

  @override
  String get healthConnectOutcomeFailed =>
      'La dernière vérification n\'a pas abouti. Elle sera retentée.';

  @override
  String get healthConnectUnavailable =>
      'Health Connect n\'est pas disponible sur cet appareil. Il nécessite Android 9 ou plus récent.';

  @override
  String get healthConnectUpdateRequired =>
      'Installez ou mettez à jour Health Connect depuis Google Play pour utiliser cette fonction.';

  @override
  String get healthConnectGetApp => 'Ouvrir Google Play';

  @override
  String get healthConnectRevoked =>
      'FocusTrace n\'a plus accès à vos données d\'exercice. Accordez-le à nouveau pour continuer l\'import.';

  @override
  String get healthConnectGrantAgain => 'Accorder l\'accès';

  @override
  String get healthConnectManage => 'Gérer l\'accès dans Health Connect';

  @override
  String get healthConnectOffNote =>
      'Désactiver arrête toute lecture et tout import programmé. Cela ne retire pas l\'autorisation de FocusTrace et ne change rien dans Health Connect ; gérez cela là-bas. Les entraînements déjà importés restent sur cet appareil jusqu\'à ce que vous les supprimiez.';

  @override
  String get healthConnectDeleteImported =>
      'Supprimer les entraînements importés';

  @override
  String get healthConnectDeleteTitle =>
      'Supprimer les entraînements importés ?';

  @override
  String get healthConnectDeleteBody =>
      'Cela retire les entraînements que FocusTrace a copiés sur cet appareil. Rien ne change dans Health Connect ni dans les apps qui les ont enregistrés.';

  @override
  String get healthConnectDelete => 'Supprimer';

  @override
  String get healthConnectWorkoutsTitle => 'Entraînements importés';

  @override
  String get healthConnectNoWorkouts =>
      'Aucun entraînement pour l\'instant. Le premier import couvre les 30 derniers jours ; les plus anciens ne sont pas importés.';

  @override
  String healthConnectWorkoutSource(String duration, String app) {
    return '$duration · depuis $app';
  }

  @override
  String get workoutStrength => 'Musculation';

  @override
  String get workoutRunning => 'Course';

  @override
  String get workoutWalking => 'Marche';

  @override
  String get workoutCycling => 'Vélo';

  @override
  String get workoutSwimming => 'Natation';

  @override
  String get workoutYoga => 'Yoga';

  @override
  String get workoutOther => 'Entraînement';

  @override
  String get onboardingHealthTitle => 'Ajoutez vos entraînements';

  @override
  String get onboardingHealthBody =>
      'Facultatif. Importez des entraînements depuis des apps comme Hevy via Health Connect. FocusTrace ne lit que les séances d\'exercice et les garde sur cet appareil. Vous pouvez changer cela à tout moment dans les réglages.';

  @override
  String get onboardingHealthConnect => 'Connecter Health Connect';

  @override
  String get onboardingHealthSkip => 'Pas maintenant';

  @override
  String get onboardingHealthConnected =>
      'Connecté. Vos entraînements sont dans les réglages, sous Health Connect.';

  @override
  String get onboardingHealthDenied =>
      'Aucun accès accordé. Vous pourrez connecter plus tard dans les réglages.';

  @override
  String get settingsClearDataHealth =>
      'L\'import Health Connect est désactivé et les entraînements importés sont supprimés. Rien ne change dans Health Connect.';
}
