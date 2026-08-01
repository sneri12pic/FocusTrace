// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

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
  String get categoryEntertainment => 'Entretenimiento';

  @override
  String get categoryProductivity => 'Productividad';

  @override
  String get categoryWeb => 'Web';

  @override
  String get categoryCommunication => 'Comunicación';

  @override
  String get categorySystem => 'Sistema';

  @override
  String get categoryActivity => 'Actividad';

  @override
  String get onboardingSkip => 'Omitir';

  @override
  String get onboardingGetStarted => 'Empezar';

  @override
  String get onboardingContinue => 'Continuar';

  @override
  String get onboardingStartSoftBlocks => 'Activar bloqueos flexibles';

  @override
  String get onboardingChooseLater => 'Elegir más tarde';

  @override
  String get onboardingChooseWhatToLimit => 'Elige qué limitar';

  @override
  String get onboardingChooseWhatToLimitDescription =>
      'Selecciona aplicaciones y establece un objetivo diario para los bloqueos flexibles.';

  @override
  String get onboardingNoAppsToChooseTitle =>
      'Aún no hay aplicaciones para elegir';

  @override
  String get onboardingNoAppsToChooseBody =>
      'FocusTrace necesita datos de uso actuales antes de poder mostrar aplicaciones aquí. Puedes omitir la configuración y añadir restricciones más tarde desde Ajustes.';

  @override
  String get onboardingNoMatchingAppsTitle =>
      'No hay aplicaciones coincidentes';

  @override
  String get onboardingNoMatchingAppsBody =>
      'Prueba con otro término de búsqueda.';

  @override
  String get onboardingWelcomeTitle =>
      'Recupera el control de tu tiempo de pantalla';

  @override
  String get onboardingWelcomeBody =>
      'Descubre adónde va tu atención.\nEstablece límites flexibles.\nCrea mejores hábitos a tu ritmo.';

  @override
  String get onboardingAccessTitle => 'Da acceso a FocusTrace';

  @override
  String get onboardingAccessBody =>
      'FocusTrace necesita dos permisos para funcionar.\nTodo permanece en tu dispositivo.';

  @override
  String get onboardingNoPermissionsTitle => 'No hay nada que autorizar aquí';

  @override
  String get onboardingNoPermissionsBody =>
      'Estos permisos solo se necesitan en Android.';

  @override
  String get onboardingUsageAccessTitle => 'Acceso a datos de uso';

  @override
  String get onboardingUsageAccessSubtitle =>
      'Para medir el tiempo que usas tus aplicaciones';

  @override
  String get onboardingOverlayAccessTitle => 'Mostrar sobre otras aplicaciones';

  @override
  String get onboardingOverlayAccessSubtitle =>
      'Para mostrar la pantalla de bloqueo sobre las aplicaciones que limites';

  @override
  String get onboardingPermissionsSettingsHint =>
      'Puedes cambiarlo más adelante en Ajustes.';

  @override
  String get onboardingAllow => 'Permitir';

  @override
  String get onboardingSearchApps => 'Buscar aplicaciones';

  @override
  String onboardingAppUsageToday(String appKey, String duration) {
    return '$appKey · $duration hoy';
  }

  @override
  String get onboardingDailyTarget => 'Objetivo diario';

  @override
  String get restrictionsTitle => 'Restricciones';

  @override
  String get restrictionsSearchApps => 'Buscar aplicaciones';

  @override
  String get restrictionsAddRestriction => 'Añadir restricción';

  @override
  String get restrictionsAddRoutine => 'Nueva rutina';

  @override
  String get restrictionsRoutinesTitle => 'Rutinas de bloqueo';

  @override
  String get restrictionsRoutinesEmptyTitle => 'No hay rutinas de bloqueo';

  @override
  String get restrictionsRoutinesEmptyBody =>
      'Agrupa aplicaciones en una rutina y activa o desactiva todo el grupo.';

  @override
  String get restrictionsIndividualRulesTitle => 'Restricciones individuales';

  @override
  String restrictionsRoutineAppCount(int count) {
    return '$count aplicaciones';
  }

  @override
  String get restrictionsDeleteRoutine => 'Eliminar rutina';

  @override
  String get routineEditorNewTitle => 'Nueva rutina de bloqueo';

  @override
  String get routineEditorEditTitle => 'Editar rutina de bloqueo';

  @override
  String get routineEditorName => 'Nombre de la rutina';

  @override
  String get routineEditorSearchApps => 'Buscar aplicaciones';

  @override
  String get routineEditorNoMatchingApps => 'No hay aplicaciones coincidentes';

  @override
  String get routineEditorSave => 'Guardar rutina';

  @override
  String get restrictionsPlatformStatusTitle =>
      'Estado solo en esta plataforma';

  @override
  String get restrictionsPlatformStatusBody =>
      'Las reglas se guardan y se muestran aquí. Actualmente, el bloqueo a pantalla completa solo funciona en Android.';

  @override
  String get restrictionsEmptyTitle => 'No hay restricciones de aplicaciones';

  @override
  String get restrictionsEmptyBody =>
      'Mantén pulsada una aplicación en las burbujas de uso o en la lista actual para añadir una regla.';

  @override
  String get restrictionsNoAppsAvailable =>
      'Aún no hay aplicaciones disponibles. Abre el panel cuando haya datos de uso y vuelve a buscar aquí.';

  @override
  String get restrictionsNoMatchingApps => 'No hay aplicaciones coincidentes';

  @override
  String get restrictionsDeleteRule => 'Eliminar regla';

  @override
  String get restrictionsUnblockNow => 'Desbloquear ahora';

  @override
  String restrictionsBlockedUntil(String time) {
    return 'Bloqueada hasta las $time';
  }

  @override
  String get restrictionsTemporaryBlockExpired =>
      'El bloqueo temporal ha caducado';

  @override
  String restrictionsDailyLimitStatus(
    String limitDuration,
    String usedDuration,
  ) {
    return 'Límite diario: $limitDuration · Uso: $usedDuration';
  }

  @override
  String restrictionsScheduleStatus(String startTime, String endTime) {
    return 'Horario: $startTime–$endTime';
  }

  @override
  String get restrictionsOverlayPermissionTitle =>
      'Se requiere permiso para mostrar sobre otras aplicaciones';

  @override
  String get restrictionsOverlayPermissionBody =>
      'Android necesita el permiso para mostrar sobre otras aplicaciones antes de que FocusTrace pueda mostrar una pantalla de bloqueo.';

  @override
  String get restrictionsOpenOverlaySettings =>
      'Abrir ajustes de superposición';

  @override
  String get restrictionsRecheck => 'Volver a comprobar';

  @override
  String get restrictionEditorAllowFullScreenTitle =>
      '¿Permitir el bloqueo a pantalla completa?';

  @override
  String get restrictionEditorAllowFullScreenBody =>
      'FocusTrace necesita el permiso para mostrar sobre otras aplicaciones a fin de mostrar una pantalla de bloqueo cuando se abre una aplicación restringida.';

  @override
  String get restrictionEditorLater => 'Más tarde';

  @override
  String get restrictionEditorOpenSettings => 'Abrir ajustes';

  @override
  String get restrictionEditorTypeNow => 'Ahora';

  @override
  String get restrictionEditorTypeLimit => 'Límite';

  @override
  String get restrictionEditorTypeSchedule => 'Horario';

  @override
  String get restrictionEditorSaveRule => 'Guardar regla';

  @override
  String get restrictionEditorTomorrow => 'Mañana';

  @override
  String restrictionEditorDailyLimitPerDay(String duration) {
    return '$duration al día';
  }

  @override
  String dashboardDayTracked(String duration) {
    return 'Registrado · $duration';
  }

  @override
  String get dashboardDayToday => 'Hoy';

  @override
  String get dashboardDayYesterday => 'Ayer';

  @override
  String get dashboardPreviousDayTooltip => 'Día anterior';

  @override
  String get dashboardNextDayTooltip => 'Día siguiente';

  @override
  String get navHome => 'Inicio';

  @override
  String get trackingRunsWhileOpen =>
      'El seguimiento solo funciona mientras FocusTrace está abierto.';

  @override
  String get dashboardStopTracking => 'Detener seguimiento';

  @override
  String get dashboardStartTracking => 'Iniciar seguimiento';

  @override
  String get dashboardNoUsageToday => 'No se ha registrado uso hoy.';

  @override
  String get dashboardNoUsageDay => 'No se ha registrado uso este día.';

  @override
  String get dashboardAllTimeMostUsedTitle => 'Más usada de todos los tiempos';

  @override
  String get dashboardUnsupportedPlatform =>
      'La versión MVP de FocusTrace es compatible con Android y Windows. Se pueden añadir otras plataformas más adelante mediante fuentes de datos específicas para cada plataforma.';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonUnexpectedError => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get usageBubblesTitle => 'Burbujas de uso';

  @override
  String get usageBubblesDescription =>
      'Las burbujas más grandes indican más tiempo de uso';

  @override
  String get usageBubblesCurrentList => 'Lista actual';

  @override
  String get actionUnblockNow => 'Desbloquear ahora';

  @override
  String get actionUnblockNowDescription =>
      'Eliminar las reglas de bloqueo activas';

  @override
  String get actionRestrictApp => 'Restringir aplicación...';

  @override
  String get actionRestrictAppDescription =>
      'Bloquear ahora, establecer un límite o añadir un horario';

  @override
  String percentageValue(String percentage) {
    return '$percentage%';
  }

  @override
  String get actionRemoveFromToday => 'Eliminar de hoy';

  @override
  String get actionRemoveFromTodayDescription =>
      'Ocultar esta aplicación de las estadísticas de hoy';

  @override
  String get actionExcludeFromTracking => 'Excluir del seguimiento';

  @override
  String get actionExcludeFromTrackingDescription =>
      'Dejar de registrar y ocultar en todas las estadísticas';

  @override
  String excludeAppDialogTitle(String appName) {
    return '¿Excluir $appName?';
  }

  @override
  String get excludeAppDialogBody =>
      'La aplicación dejará de registrarse y de mostrarse en las estadísticas. Puedes deshacerlo desde Ajustes.';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get actionExclude => 'Excluir';

  @override
  String sessionTotal(String duration) {
    return 'Total · $duration';
  }

  @override
  String get sessionDetailsUnavailable =>
      'Los detalles de las sesiones no están disponibles en esta plataforma.';

  @override
  String get sessionNoneRecorded => 'No hay sesiones registradas.';

  @override
  String get sessionLongestTitle => 'Sesiones más largas';

  @override
  String sessionOngoingLabel(String startTime, String duration) {
    return '$startTime · $duration';
  }

  @override
  String sessionRangeLabel(String startTime, String endTime, String duration) {
    return '$startTime – $endTime · $duration';
  }

  @override
  String get permissionWindowsPrivacyTitle => 'Privacidad de Windows';

  @override
  String get permissionUsageAccessRequiredTitle =>
      'Se requiere acceso a datos de uso';

  @override
  String get permissionUsageAccessRequiredBody =>
      'FocusTrace necesita el acceso a datos de uso de Android para leer el uso de tus propias aplicaciones. Los datos permanecen almacenados localmente en este dispositivo.';

  @override
  String get permissionOpenUsageAccessSettings =>
      'Abrir ajustes de acceso a datos de uso';

  @override
  String get commonRecheck => 'Volver a comprobar';

  @override
  String get trackingWindowsRunning =>
      'El seguimiento en Windows está activo mientras FocusTrace está abierto.';

  @override
  String get trackingWindowsIdle =>
      'El seguimiento en Windows solo funciona mientras FocusTrace está abierto.';

  @override
  String get trackingAndroidUsageAccess =>
      'El uso de Android se obtiene mediante el acceso a datos de uso.';

  @override
  String get trackingUnsupportedPlatform =>
      'El seguimiento de uso aún no es compatible con esta plataforma.';

  @override
  String get trackingError =>
      'Se ha producido un problema con el seguimiento. Se reintentará automáticamente.';

  @override
  String bubblePercentageOfToday(String percentage) {
    return '$percentage% de hoy';
  }

  @override
  String usageBubbleSemanticsLabel(String appName, String category) {
    return '$appName, $category';
  }

  @override
  String usageBubbleNearLimitSemanticsLabel(String appName, String category) {
    return '$appName, $category, límite diario casi alcanzado';
  }

  @override
  String summaryLaunchCount(int count) {
    return 'Inicios: $count';
  }

  @override
  String get usageTrendDayShort => 'D';

  @override
  String get usageTrendWeekShort => 'S';

  @override
  String get usageTrendMonthShort => 'M';

  @override
  String usageTrendIncrease(String period, int percentage) {
    return '$period: el uso aumentó un $percentage%';
  }

  @override
  String usageTrendDecrease(String period, int percentage) {
    return '$period: el uso disminuyó un $percentage%';
  }

  @override
  String usageTrendUnchanged(String period) {
    return '$period: uso sin cambios';
  }

  @override
  String get usageDetailsLastSevenDays => 'Últimos 7 días';

  @override
  String usageDetailsMoreThanYesterday(int percentage) {
    return '$percentage% más que ayer';
  }

  @override
  String usageDetailsLessThanYesterday(int percentage) {
    return '$percentage% menos que ayer';
  }

  @override
  String get usageDetailsSameAsYesterday => 'Igual que ayer';

  @override
  String get usageDetailsNoYesterdayComparison =>
      'Aún no hay comparación con ayer';

  @override
  String usageDetailsRankLabel(int rank) {
    return 'N.º $rank más usada';
  }

  @override
  String usageDetailsRankLead(String duration, String appName) {
    return '$duration más que $appName';
  }

  @override
  String usageDetailsDayValue(String date, String duration) {
    return '$date: $duration';
  }

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsPrivacyTitle => 'Privacidad';

  @override
  String get settingsPrivacyBody =>
      'FocusTrace almacena los datos de uso localmente en este dispositivo. No sube el uso registrado de aplicaciones ni ventanas.';

  @override
  String get settingsClearLocalData => 'Borrar datos locales';

  @override
  String get settingsLanguageTitle => 'Idioma';

  @override
  String get settingsLanguageSystemDefault => 'Idioma del sistema';

  @override
  String get settingsChooseLanguage => 'Elegir idioma';

  @override
  String get settingsLanguageUpdateError =>
      'No se ha podido aplicar la preferencia de idioma. Inténtalo de nuevo.';

  @override
  String get settingsExcludedAppsTitle => 'Aplicaciones excluidas';

  @override
  String get settingsExcludedAppsEmpty =>
      'No hay aplicaciones excluidas. Mantén pulsada una aplicación en el panel para excluirla del seguimiento.';

  @override
  String get settingsStopExcluding => 'Dejar de excluir';

  @override
  String get settingsWindowsTrackingComingSoon =>
      'Próximamente: seguimiento en Windows';

  @override
  String get settingsSendFeedback => 'Enviar comentarios';

  @override
  String get settingsWindowsTrackingInterval =>
      'Intervalo de seguimiento en Windows';

  @override
  String get settingsWindowsIdleTimeout => 'Tiempo de inactividad de Windows';

  @override
  String get settingsClearDataDialogTitle => '¿Borrar los datos locales?';

  @override
  String get settingsClearDataDialogBody =>
      'Esta acción elimina de este dispositivo las sesiones de uso y los ajustes guardados. Tu elección de idioma se conserva.';

  @override
  String get settingsCancel => 'Cancelar';

  @override
  String get settingsClear => 'Borrar';

  @override
  String get settingsSave => 'Guardar';

  @override
  String secondsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segundos',
      one: '1 segundo',
    );
    return '$_temp0';
  }
}
