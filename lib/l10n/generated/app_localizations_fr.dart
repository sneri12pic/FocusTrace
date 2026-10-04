// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

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
  String get settingsClearDataDialogBody =>
      'Cette action supprime définitivement de cet appareil l’historique d’utilisation et les paramètres. Votre choix de langue est conservé. Exportez d’abord une sauvegarde si vous pourriez avoir besoin de ces données.';

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
      'Votre historique d’utilisation et vos réglages restent sur cet appareil, sauf si vous exportez une sauvegarde ou activez la synchronisation cloud ci-dessous.';
}
