// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appCategoryAll => 'Todas';

  @override
  String get appCategoryTitle => 'Categoría de la aplicación';

  @override
  String get appCategoryAutomatic => 'Automática';

  @override
  String get appCategorySave => 'Guardar categoría';

  @override
  String get appCategorySaveError =>
      'No se pudo guardar la categoría. Inténtalo de nuevo.';

  @override
  String get usageDetailsBarChart => 'Gráfico de barras';

  @override
  String get usageDetailsAreaChart => 'Tendencia de uso';

  @override
  String get usageDetailsChartSaveError =>
      'No se pudo guardar tu elección de gráfico. Inténtalo de nuevo.';

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
      'Los dos primeros permisos se controlan desde los ajustes de Android.';

  @override
  String get onboardingAllow => 'Permitir';

  @override
  String get onboardingOpenSettings => 'Abrir ajustes';

  @override
  String get onboardingNotificationsTitle => 'Notificaciones';

  @override
  String get onboardingNotificationsSubtitle =>
      'Opcional: recibe avisos antes de alcanzar un límite diario';

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
  String get routineDailyLimit => 'Límite diario compartido';

  @override
  String get routineNoDailyLimit => 'Sin límite diario';

  @override
  String get routineCustomDuration => 'Personalizado';

  @override
  String get routineChooseDuration => 'Elegir límite diario';

  @override
  String get routineNotFound => 'Esta rutina ya no existe.';

  @override
  String get routineRename => 'Renombrar rutina';

  @override
  String get routineAppsTitle => 'Aplicaciones';

  @override
  String get routineAddApp => 'Añadir aplicación';

  @override
  String routineAppUsage(String duration) {
    return '$duration hoy · Incluida en el límite';
  }

  @override
  String routineAppUsageExcluded(String duration) {
    return '$duration hoy · Excluida del límite';
  }

  @override
  String get routineRemoveApp => 'Eliminar aplicación';

  @override
  String get routineKeepOneApp =>
      'Una rutina debe conservar al menos una aplicación.';

  @override
  String routineDeleteConfirmation(String name) {
    return '¿Eliminar $name? Esta acción no se puede deshacer.';
  }

  @override
  String get routineUsageToday => 'Uso contabilizado hoy';

  @override
  String get routineNoIncludedApps =>
      'Incluye al menos una aplicación para activar el límite';

  @override
  String get routineLimitReached =>
      'Límite alcanzado · las aplicaciones incluidas están bloqueadas hasta medianoche';

  @override
  String get routineActive => 'Activa';

  @override
  String get routinePaused => 'En pausa';

  @override
  String routineUsageOfLimit(String used, String limit) {
    return '$used de $limit';
  }

  @override
  String routineRemaining(String duration) {
    return 'Quedan $duration';
  }

  @override
  String get routineSetLimit => 'Establecer límite';

  @override
  String get routineEditLimit => 'Editar límite';

  @override
  String get routineRemoveLimit => 'Quitar límite';

  @override
  String routineUsageOnly(String duration) {
    return '$duration hoy';
  }

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
  String get dashboardUsageUnavailableDay =>
      'Los datos de uso no están disponibles en este momento para este día.';

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
  String usageListShowAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostrar todo ($count más)',
      one: 'Mostrar todo (1 más)',
    );
    return '$_temp0';
  }

  @override
  String get usageListShowLess => 'Mostrar menos';

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
  String get usageTrendNew => 'Nuevo';

  @override
  String usageTrendNewLabel(String period) {
    return '$period: uso nuevo, sin datos anteriores para comparar';
  }

  @override
  String usageTrendIncreaseAboveCap(String period, int percentage) {
    return '$period: el uso aumentó más de un $percentage%';
  }

  @override
  String get usageDetailsLastSevenDays => 'Últimos 7 días';

  @override
  String get usageDetailsTimeTracked => 'Tiempo registrado';

  @override
  String get usageDetailsPeriodSevenDays => '7 días';

  @override
  String get usageDetailsPeriodTwoWeeks => '2 semanas';

  @override
  String get usageDetailsPeriodMonth => 'Un mes';

  @override
  String get usageDetailsPeriodYear => 'Año';

  @override
  String usageDetailsPeriodTotal(String period, String duration) {
    return '$period: $duration';
  }

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
  String get reportsTitle => 'Informes';

  @override
  String get reportsWeekly => 'Semanal';

  @override
  String get reportsMonthly => 'Mensual';

  @override
  String get reportsYearly => 'Anual';

  @override
  String get reportsTotalUsage => 'Uso total';

  @override
  String get reportsDailyAverage => 'Promedio diario';

  @override
  String get reportsActiveDays => 'Días activos';

  @override
  String get reportsTimeOfDayTitle => 'Uso por hora del día';

  @override
  String get reportsHabitTitle => 'Formación de hábitos';

  @override
  String get reportsPeakTime => 'Hora más activa';

  @override
  String get reportsFirstUse => 'Promedio del primer uso';

  @override
  String get reportsFirstApp => 'Primera app más frecuente';

  @override
  String get reportsConsistency => 'Constancia del primer uso';

  @override
  String reportsVariationMinutes(int minutes) {
    return '± $minutes min';
  }

  @override
  String get reportsWakeHeuristic =>
      'El primer uso se estima tras al menos 4 horas de inactividad, entre las 04:00 y las 14:00.';

  @override
  String get reportsTopApps => 'Apps más usadas';

  @override
  String get reportsRestrictionsTitle => 'Actividad de restricciones';

  @override
  String get reportsBlockedAttempts => 'Intentos bloqueados';

  @override
  String get reportsManualUnblocks => 'Desbloqueos manuales';

  @override
  String get reportsBlocked => 'Bloqueado';

  @override
  String get reportsUnblocked => 'Desbloqueado';

  @override
  String get reportsEmpty =>
      'Todavía no hay suficientes datos locales para este informe.';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsGeneralSection => 'General';

  @override
  String get settingsActivityDataSection => 'Actividad y datos';

  @override
  String get settingsSupportSection => 'Ayuda';

  @override
  String get settingsPrivacyTitle => 'Datos y privacidad';

  @override
  String get settingsPrivacyBody =>
      'Tu historial de uso y tus ajustes permanecen en este dispositivo, salvo que exportes una copia. FocusTrace nunca los sube.';

  @override
  String get settingsClearLocalData => 'Eliminar datos locales';

  @override
  String get settingsDataTransferTitle => 'Copia de seguridad y restauración';

  @override
  String get settingsDataTransferBody =>
      'Guarda una copia portátil o restaura datos de otra instalación de FocusTrace. Los datos importados se combinan con los que ya existen en este dispositivo.';

  @override
  String get settingsExportData => 'Exportar datos';

  @override
  String get settingsImportData => 'Importar datos';

  @override
  String get settingsExportSuccess =>
      'Copia de seguridad de FocusTrace guardada.';

  @override
  String get settingsImportSuccess =>
      'Copia de seguridad de FocusTrace importada.';

  @override
  String get settingsImportDialogTitle => '¿Importar datos de FocusTrace?';

  @override
  String get settingsImportDialogBody =>
      'La copia se combinará con los datos locales existentes. Los registros y ajustes coincidentes usarán los valores importados.';

  @override
  String get settingsImportDialogDetail =>
      'Esto incluye restricciones, rutinas de bloqueo, aplicaciones excluidas y categorías de aplicaciones si la copia las contiene. No se elimina nada de este dispositivo y la sesión de sincronización no cambia.';

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
  String get settingsExcludedAppsTitle => 'Exclusiones de seguimiento';

  @override
  String get settingsExcludedAppsEmpty =>
      'No hay aplicaciones excluidas del seguimiento. Mantén pulsada una aplicación en el panel para añadirla aquí.';

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
  String get settingsClearDataDialogTitle =>
      '¿Eliminar todos los datos locales?';

  @override
  String get settingsClearDataDeletes =>
      'Se elimina de este dispositivo: historial de uso e informes, restricciones y rutinas de bloqueo, aplicaciones excluidas, categorías de aplicaciones y demás ajustes.';

  @override
  String get settingsClearDataKeeps =>
      'Se conserva: tu idioma. Los permisos de Android no cambian. Exporta antes una copia si puedes necesitar estos datos.';

  @override
  String get settingsClearDataKeepsSync =>
      'Tu cuenta en la nube y los datos ya sincronizados no se eliminan. La sincronización se desactiva en este dispositivo.';

  @override
  String get settingsClearDataDone => 'Datos locales eliminados.';

  @override
  String get settingsCancel => 'Cancelar';

  @override
  String get settingsClear => 'Eliminar';

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

  @override
  String get settingsSyncSection => 'Cuenta y sincronización';

  @override
  String get settingsSyncTitle => 'Sincronización en la nube';

  @override
  String get settingsSyncBody =>
      'Inicia sesión para copiar tus totales de uso diario a tu propia cuenta y verlos en otro dispositivo. Desactivada hasta que la actives.';

  @override
  String get settingsSyncEmail => 'Correo electrónico';

  @override
  String get settingsSyncPassword => 'Contraseña';

  @override
  String get settingsSyncPasswordRequirements =>
      'Usa entre 15 y 128 caracteres. Unas pocas palabras sin relación forman una frase de contraseña segura y fácil de recordar. No se aceptan contraseñas comunes.';

  @override
  String get settingsSyncShowPassword => 'Mostrar contraseña';

  @override
  String get settingsSyncHidePassword => 'Ocultar contraseña';

  @override
  String get settingsSyncSignInHeading => 'Inicia sesión en tu cuenta';

  @override
  String get settingsSyncCreateHeading => 'Crea una cuenta de sincronización';

  @override
  String get settingsSyncSwitchToCreate =>
      '¿Primera vez que sincronizas? Crea una cuenta';

  @override
  String get settingsSyncSwitchToSignIn =>
      '¿Ya tienes una cuenta? Inicia sesión';

  @override
  String get settingsSyncSignInInstead => 'Iniciar sesión en su lugar';

  @override
  String get settingsSyncSigningIn => 'Iniciando sesión…';

  @override
  String get settingsSyncCreatingAccount => 'Creando cuenta…';

  @override
  String get settingsSyncAccountCreated => 'Cuenta creada';

  @override
  String settingsSyncSignedInAs(String email) {
    return 'Sesión iniciada como $email';
  }

  @override
  String get settingsSyncCreatedNextStep =>
      'La sincronización sigue desactivada. Actívala cuando quieras copiar los totales diarios de este dispositivo a tu cuenta.';

  @override
  String get settingsSyncTurnOnSync => 'Activar sincronización';

  @override
  String get settingsSyncAccountCreatedSignInRequired =>
      'Tu cuenta se ha creado, pero no se ha podido iniciar sesión automáticamente. Introduce tu contraseña y toca «Iniciar sesión» para continuar.';

  @override
  String get settingsSyncErrorRegistration =>
      'No se ha creado la cuenta. Revisa tu correo electrónico y contraseña e inténtalo de nuevo.';

  @override
  String get settingsSyncErrorEmailRequired =>
      'Introduce tu dirección de correo electrónico.';

  @override
  String get settingsSyncErrorEmailInvalid =>
      'Introduce una dirección de correo electrónico válida, como nombre@example.com.';

  @override
  String get settingsSyncErrorPasswordRequired => 'Introduce tu contraseña.';

  @override
  String settingsSyncErrorPasswordTooShort(int count) {
    return 'Usa al menos 15 caracteres (llevas $count).';
  }

  @override
  String get settingsSyncErrorPasswordTooLong =>
      'Usa como máximo 128 caracteres.';

  @override
  String get settingsSyncErrorPasswordRejected =>
      'Esta contraseña es demasiado común o coincide con tu correo electrónico. Elige otra.';

  @override
  String get settingsSyncErrorThrottled =>
      'Demasiados intentos desde esta red. Espera un poco y vuelve a intentarlo.';

  @override
  String get settingsSyncSignIn => 'Iniciar sesión';

  @override
  String get settingsSyncCreateAccount => 'Crear cuenta';

  @override
  String get settingsSyncSignOut => 'Cerrar sesión';

  @override
  String get settingsSyncEnabledLabel => 'Sincronizar este dispositivo';

  @override
  String get settingsSyncEnabledSubtitle =>
      'Al desactivarlo se deja de enviar datos nuevos. No se borra nada ya sincronizado.';

  @override
  String get settingsSyncNow => 'Sincronizar ahora';

  @override
  String get settingsSyncNeverSynced => 'Aún sin sincronizar';

  @override
  String get settingsSyncStateSyncing => 'Sincronizando...';

  @override
  String get settingsSyncStateSuccess => 'Sincronización completada';

  @override
  String get settingsSyncStateError => 'Error de sincronización';

  @override
  String get settingsSyncErrorOffline =>
      'No se pudo contactar con el servicio. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get settingsSyncErrorCredentials =>
      'Ese correo y esa contraseña no coinciden con ninguna cuenta.';

  @override
  String get settingsSyncErrorEmailTaken =>
      'Ya existe una cuenta con ese correo.';

  @override
  String get settingsSyncErrorWeakPassword =>
      'Elige una contraseña más larga y menos común.';

  @override
  String get settingsSyncErrorSessionExpired =>
      'Tu sesión ha terminado. Vuelve a iniciar sesión.';

  @override
  String get settingsSyncErrorRefused => 'El servicio rechazó la solicitud.';

  @override
  String get settingsSyncErrorUnknown => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get settingsSyncDeleteAccount => 'Eliminar cuenta';

  @override
  String get settingsSyncDeleteTitle => '¿Eliminar tu cuenta de FocusTrace?';

  @override
  String get settingsSyncDeleteBody =>
      'Esto elimina de forma permanente tu cuenta en la nube de FocusTrace y todos los datos de uso sincronizados con el servidor. No se puede deshacer.\n\nEl historial de uso de este dispositivo se conserva y la sincronización se desactivará.';

  @override
  String get settingsSyncDeletePassword => 'Contraseña actual';

  @override
  String get settingsSyncDeleteConfirm => 'Eliminar para siempre';

  @override
  String get settingsSyncDeleted =>
      'Se eliminó tu cuenta de FocusTrace. El historial de uso de este dispositivo se conservó.';

  @override
  String get settingsSyncRepeatPassword => 'Repetir contraseña';

  @override
  String get settingsSyncShowRepeatPassword => 'Mostrar contraseña repetida';

  @override
  String get settingsSyncHideRepeatPassword => 'Ocultar contraseña repetida';

  @override
  String get settingsSyncErrorPasswordMismatch =>
      'Las contraseñas no coinciden.';

  @override
  String get settingsSyncDangerZone => 'Zona de peligro';

  @override
  String get settingsSyncDangerZoneBody =>
      'Eliminar tu cuenta la borra para siempre junto con todos los datos de uso sincronizados con el servidor. El historial de uso de este dispositivo se conserva.';

  @override
  String get settingsSyncDeleteAcknowledge =>
      'Entiendo que esto elimina mi cuenta en la nube para siempre.';

  @override
  String get settingsSyncDeleting => 'Eliminando…';

  @override
  String get settingsSyncErrorWrongPassword =>
      'La contraseña no es correcta. Tu cuenta no se eliminó.';

  @override
  String get settingsPrivacyBodySync =>
      'Tu historial de uso y tus ajustes permanecen en este dispositivo salvo que exportes una copia o actives la sincronización en la nube.';

  @override
  String get usageCalendarTotalThisMonth => 'Total este mes';

  @override
  String get usageCalendarAveragePerDay => 'Promedio por día';

  @override
  String get usageCalendarAppOpens => 'Aperturas';

  @override
  String get usageCalendarLongestSession => 'Sesión más larga';

  @override
  String get usageCalendarVsLastMonth => 'vs. el mes pasado';

  @override
  String get usageCalendarPreviousMonth => 'Mes anterior';

  @override
  String get usageCalendarNextMonth => 'Mes siguiente';

  @override
  String get usageCalendarTotalTime => 'Tiempo total';

  @override
  String get usageCalendarAverageSession => 'Sesión media';

  @override
  String get usageCalendarVsDailyAverage => 'vs. tu promedio diario';

  @override
  String get usageCalendarTimeline => 'Cronología de uso';

  @override
  String get usageCalendarNoTimeline =>
      'No hay detalles de sesiones para este día';

  @override
  String get usageApproximateNote =>
      '≈ Aproximado: del resumen de uso de Android, antes de que FocusTrace registrara';

  @override
  String get usageApproximateTag => '≈ Aproximado';

  @override
  String get onboardingHistoryChecking => 'Buscando uso anterior…';

  @override
  String get onboardingHistoryNone =>
      'Android no guardó uso anterior en este teléfono';

  @override
  String onboardingHistoryFound(String date) {
    return 'Encontramos tu uso anterior desde el $date';
  }

  @override
  String restrictionsTimeLeft(String duration) {
    return 'Quedan $duration';
  }

  @override
  String get restrictionsLimitReached => 'Límite alcanzado';

  @override
  String get rxWeek => 'Esta semana';

  @override
  String get rxTopApps => 'Tus aplicaciones más usadas';

  @override
  String rxAverage(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Promedio diario · $days días registrados',
      one: 'Promedio diario · 1 día registrado',
    );
    return '$_temp0';
  }

  @override
  String get rxBusiest => 'Tus horas de mayor uso';

  @override
  String rxPeak(String start, String end) {
    return 'La mayor parte del uso registrado es de $start a $end.';
  }

  @override
  String get rxNoInsights =>
      'Aún no hay suficiente uso registrado para sugerir un horario.';

  @override
  String get rxPlanBlock => 'Planificar un horario';

  @override
  String get rxYourRules => 'Tus restricciones';

  @override
  String get rxLimit => 'Límite';

  @override
  String get rxEdit => 'Editar';

  @override
  String rxRestrict(String app) {
    return 'Restringir $app';
  }

  @override
  String rxAverageApp(String duration) {
    return 'Promedio de $duration / día';
  }

  @override
  String get rxType => 'Tipo de restricción';

  @override
  String get rxDailyLimit => 'Límite diario';

  @override
  String get rxBlockNow => 'Bloquear ahora';

  @override
  String get rxDifficulty => 'Dificultad para desbloquear';

  @override
  String get rxEasy => 'Fácil';

  @override
  String get rxModerate => 'Moderada';

  @override
  String get rxHard => 'Difícil';

  @override
  String get rxEasyHint => 'Confirma para desbloquear';

  @override
  String get rxModerateHint => 'Espera 5 minutos para desbloquear';

  @override
  String get rxHardHint => 'Sin desbloqueo anticipado en FocusTrace';

  @override
  String get rxProtectionNote =>
      'También se aplica al cambiar o eliminar una regla activa.';

  @override
  String get rxSetLimit => 'Establecer límite diario';

  @override
  String get rxSetSchedule => 'Establecer horario';

  @override
  String get rxStartBlock => 'Iniciar bloqueo';

  @override
  String rxBelowAverage(String duration) {
    return '$duration menos que tu promedio diario';
  }

  @override
  String get rxRepeat => 'Repetir';

  @override
  String get rxNextDay => 'Termina al día siguiente';

  @override
  String rxEndsAt(String time) {
    return 'Termina a las $time';
  }

  @override
  String get rxHardConfirm =>
      'Mientras esta regla bloquee una aplicación, no podrás desbloquearla, editar la regla ni eliminarla antes de tiempo en FocusTrace.';

  @override
  String get rxConfirm => 'Confirmar';

  @override
  String get rxChangeTitle => '¿Cambiar restricción?';

  @override
  String get rxChangeBody =>
      'Las reglas fáciles se pueden cambiar ahora. Las moderadas requieren cinco minutos de espera. Las difíciles permanecen hasta que termine el bloqueo actual.';

  @override
  String get rxCooldown =>
      'Se ha iniciado una espera de cinco minutos. Inténtalo después; la aplicación seguirá bloqueada hasta que confirmes de nuevo.';

  @override
  String get rxHardLocked =>
      'Esta regla está bloqueada hasta que termine el bloqueo actual.';

  @override
  String get rxUnavailable =>
      'No se pudo verificar esta restricción. Comprueba el acceso al uso e inténtalo de nuevo.';

  @override
  String get rxMinutes => 'Duración en minutos';

  @override
  String get rxRetry => 'Reintentar';

  @override
  String get rxScheduleInvalid =>
      'Elige horas de inicio y fin diferentes y al menos un día.';

  @override
  String get rxNoUsage =>
      'No hay uso registrado en este período. Aún puedes elegir cualquier aplicación para restringir.';

  @override
  String rxNextBlock(String time) {
    return 'Próximo inicio: $time';
  }

  @override
  String rxPerDay(String duration) {
    return '$duration / día';
  }

  @override
  String rxUntil(String time) {
    return 'Hasta las $time';
  }

  @override
  String rxLeftToday(String duration) {
    return 'Quedan $duration hoy';
  }

  @override
  String rxStarts(String time) {
    return 'Empieza $time';
  }

  @override
  String get rxStartLabel => 'Inicio';

  @override
  String get rxEndLabel => 'Fin';

  @override
  String get rxHoursField => 'Horas';

  @override
  String get rxMinutesField => 'Minutos';

  @override
  String get rxAdd => 'Añadir';

  @override
  String get rxNoRulesYet =>
      'Aún no hay restricciones. Elige una app abajo o toca Añadir.';

  @override
  String get rxChooseApps => 'Elige apps para limitar';

  @override
  String get rxSearchAll => 'Buscar en todas las apps';

  @override
  String get rxTodayUsage => 'Uso de hoy hasta ahora';

  @override
  String get rxCreate => 'Crear';

  @override
  String rxSharedLimit(String duration) {
    return 'Límite diario compartido · $duration';
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
  String get rxPaused => 'En pausa';

  @override
  String rxUsed(String duration) {
    return '$duration usado';
  }

  @override
  String rxLeft(String duration) {
    return 'Quedan $duration';
  }

  @override
  String get rxEveryDay => 'Todos los días';

  @override
  String get rxUnblockAfterWait => 'Desbloquear tras 5 minutos de espera';

  @override
  String rxLockedUntil(String time) {
    return 'Bloqueada hasta las $time';
  }

  @override
  String get rxEditDuration => 'Editar duración';

  @override
  String get rxSaveChanges => 'Guardar cambios';

  @override
  String get rxEasyExplain =>
      'Puedes desbloquear antes tras confirmarlo. Editar o eliminar esta regla mientras bloquea también pide confirmación.';

  @override
  String get rxModerateExplain =>
      'Desbloquear antes, o editar o eliminar esta regla mientras bloquea, inicia una espera de cinco minutos. La app sigue bloqueada mientras tanto. Cuando termine, repite la acción y confirma de nuevo. Nada se desbloquea solo.';

  @override
  String get rxHardExplain =>
      'Mientras esta regla bloquea, FocusTrace no la desbloquea antes y no puedes editarla ni eliminarla hasta que termine el bloqueo. Fuera de esos periodos puedes cambiarla como siempre.';

  @override
  String get rxModerateUnblockBody =>
      'Esto inicia una espera de cinco minutos. La app sigue bloqueada hasta que termine. Después, elige Desbloquear de nuevo y confirma.';

  @override
  String get routineLastAppPrompt =>
      'Esta rutina ya no tiene apps. ¿Eliminar la rutina?';

  @override
  String get routineKeepRoutine => 'Mantener rutina';

  @override
  String get routineNamePrompt => 'Añade un nombre a la rutina';

  @override
  String get routineEmpty =>
      'Esta rutina aún no tiene apps. Añade apps para volver a usar sus límites.';

  @override
  String get routineNoAppsShort => 'Aún no hay apps';

  @override
  String get routinePickerAll => 'Todas';

  @override
  String routinePickerSelectCategory(String category) {
    return 'Seleccionar todo en $category';
  }

  @override
  String get routineAddApps => 'Añadir apps';

  @override
  String routineAddSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Añadir $count apps',
      one: 'Añadir 1 app',
    );
    return '$_temp0';
  }

  @override
  String routineAppLimit(String duration) {
    return 'Límite de app $duration';
  }

  @override
  String get routineNoAppLimit => 'Sin límite de app';

  @override
  String routineAppLimitTitle(String app) {
    return 'Límite diario de $app';
  }

  @override
  String get routineAppLimitHint =>
      'Limita solo esta app. Su tiempo sigue contando para el tiempo compartido.';

  @override
  String routineReasonShared(String routine) {
    return '$routine: tiempo compartido agotado';
  }

  @override
  String routineReasonApp(String routine) {
    return '$routine: límite de la app alcanzado';
  }

  @override
  String get reasonDailyAppLimit => 'Límite diario de la app alcanzado';

  @override
  String reasonScheduleUntil(String time) {
    return 'Bloqueada por horario hasta las $time';
  }

  @override
  String reasonTemporaryUntil(String time) {
    return 'Bloqueo temporal hasta las $time';
  }

  @override
  String routineOpenDetails(String app) {
    return 'Abrir detalles de $app';
  }
}
