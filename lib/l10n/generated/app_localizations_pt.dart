// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

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
  String get categoryEntertainment => 'Entretenimento';

  @override
  String get categoryProductivity => 'Produtividade';

  @override
  String get categoryWeb => 'Web';

  @override
  String get categoryCommunication => 'Comunicação';

  @override
  String get categorySystem => 'Sistema';

  @override
  String get categoryActivity => 'Atividade';

  @override
  String get onboardingSkip => 'Pular';

  @override
  String get onboardingGetStarted => 'Começar';

  @override
  String get onboardingContinue => 'Continuar';

  @override
  String get onboardingStartSoftBlocks => 'Ativar bloqueios flexíveis';

  @override
  String get onboardingChooseLater => 'Escolher depois';

  @override
  String get onboardingChooseWhatToLimit => 'Escolha o que limitar';

  @override
  String get onboardingChooseWhatToLimitDescription =>
      'Selecione apps e defina uma meta diária para os bloqueios flexíveis.';

  @override
  String get onboardingNoAppsToChooseTitle => 'Ainda não há apps para escolher';

  @override
  String get onboardingNoAppsToChooseBody =>
      'FocusTrace precisa de dados de uso atuais antes de mostrar apps aqui. Você pode pular a configuração e adicionar restrições depois em Configurações.';

  @override
  String get onboardingNoMatchingAppsTitle => 'Nenhum app encontrado';

  @override
  String get onboardingNoMatchingAppsBody => 'Tente outro termo de busca.';

  @override
  String get onboardingWelcomeTitle => 'Retome o controle do seu tempo de tela';

  @override
  String get onboardingWelcomeBody =>
      'Entenda para onde vai sua atenção.\nDefina limites flexíveis.\nCrie hábitos melhores no seu ritmo.';

  @override
  String get onboardingAccessTitle => 'Dê acesso ao FocusTrace';

  @override
  String get onboardingAccessBody =>
      'FocusTrace precisa de duas permissões para funcionar.\nTudo fica no seu dispositivo.';

  @override
  String get onboardingNoPermissionsTitle => 'Nada para autorizar aqui';

  @override
  String get onboardingNoPermissionsBody =>
      'Estas permissões só são necessárias no Android.';

  @override
  String get onboardingUsageAccessTitle => 'Acesso ao uso';

  @override
  String get onboardingUsageAccessSubtitle => 'Para medir seu tempo nos apps';

  @override
  String get onboardingOverlayAccessTitle => 'Exibir sobre outros apps';

  @override
  String get onboardingOverlayAccessSubtitle =>
      'Para mostrar a tela de bloqueio sobre os apps que você limita';

  @override
  String get onboardingPermissionsSettingsHint =>
      'Você pode alterar isso depois nas configurações.';

  @override
  String get onboardingAllow => 'Permitir';

  @override
  String get onboardingSearchApps => 'Buscar apps';

  @override
  String onboardingAppUsageToday(String appKey, String duration) {
    return '$appKey · $duration hoje';
  }

  @override
  String get onboardingDailyTarget => 'Meta diária';

  @override
  String get restrictionsTitle => 'Restrições';

  @override
  String get restrictionsSearchApps => 'Buscar apps';

  @override
  String get restrictionsAddRestriction => 'Adicionar restrição';

  @override
  String get restrictionsAddRoutine => 'Nova rotina';

  @override
  String get restrictionsRoutinesTitle => 'Rotinas de bloqueio';

  @override
  String get restrictionsRoutinesEmptyTitle => 'Nenhuma rotina de bloqueio';

  @override
  String get restrictionsRoutinesEmptyBody =>
      'Agrupe apps em uma rotina e ative ou desative o grupo inteiro.';

  @override
  String get restrictionsIndividualRulesTitle => 'Restrições individuais';

  @override
  String restrictionsRoutineAppCount(int count) {
    return '$count apps';
  }

  @override
  String get restrictionsDeleteRoutine => 'Excluir rotina';

  @override
  String get routineEditorNewTitle => 'Nova rotina de bloqueio';

  @override
  String get routineEditorEditTitle => 'Editar rotina de bloqueio';

  @override
  String get routineEditorName => 'Nome da rotina';

  @override
  String get routineEditorSearchApps => 'Buscar apps';

  @override
  String get routineEditorNoMatchingApps => 'Nenhum app correspondente';

  @override
  String get routineEditorSave => 'Salvar rotina';

  @override
  String get restrictionsPlatformStatusTitle =>
      'Status somente nesta plataforma';

  @override
  String get restrictionsPlatformStatusBody =>
      'As regras são salvas e exibidas aqui. No momento, o bloqueio em tela cheia funciona apenas no Android.';

  @override
  String get restrictionsEmptyTitle => 'Nenhuma restrição de app';

  @override
  String get restrictionsEmptyBody =>
      'Toque e segure um app nas bolhas de uso ou na lista atual para adicionar uma regra.';

  @override
  String get restrictionsNoAppsAvailable =>
      'Ainda não há apps disponíveis. Abra o painel quando os dados de uso estiverem disponíveis e pesquise aqui.';

  @override
  String get restrictionsNoMatchingApps => 'Nenhum app encontrado';

  @override
  String get restrictionsDeleteRule => 'Excluir regra';

  @override
  String get restrictionsUnblockNow => 'Desbloquear agora';

  @override
  String restrictionsBlockedUntil(String time) {
    return 'Bloqueado até $time';
  }

  @override
  String get restrictionsTemporaryBlockExpired => 'Bloqueio temporário expirou';

  @override
  String restrictionsDailyLimitStatus(
    String limitDuration,
    String usedDuration,
  ) {
    return 'Limite diário: $limitDuration · Usado: $usedDuration';
  }

  @override
  String restrictionsScheduleStatus(String startTime, String endTime) {
    return 'Horário: $startTime–$endTime';
  }

  @override
  String get restrictionsOverlayPermissionTitle =>
      'Permissão para sobreposição necessária';

  @override
  String get restrictionsOverlayPermissionBody =>
      'Android precisa da permissão Exibir sobre outros apps para que FocusTrace possa mostrar uma tela de bloqueio.';

  @override
  String get restrictionsOpenOverlaySettings =>
      'Abrir configurações de sobreposição';

  @override
  String get restrictionsRecheck => 'Verificar novamente';

  @override
  String get restrictionEditorAllowFullScreenTitle =>
      'Permitir bloqueio em tela cheia?';

  @override
  String get restrictionEditorAllowFullScreenBody =>
      'FocusTrace precisa da permissão Exibir sobre outros apps para mostrar uma tela de bloqueio quando um app restrito for aberto.';

  @override
  String get restrictionEditorLater => 'Depois';

  @override
  String get restrictionEditorOpenSettings => 'Abrir configurações';

  @override
  String get restrictionEditorTypeNow => 'Agora';

  @override
  String get restrictionEditorTypeLimit => 'Limite';

  @override
  String get restrictionEditorTypeSchedule => 'Horário';

  @override
  String get restrictionEditorSaveRule => 'Salvar regra';

  @override
  String get restrictionEditorTomorrow => 'Amanhã';

  @override
  String restrictionEditorDailyLimitPerDay(String duration) {
    return '$duration por dia';
  }

  @override
  String dashboardDayTracked(String duration) {
    return 'Registrado · $duration';
  }

  @override
  String get dashboardDayToday => 'Hoje';

  @override
  String get dashboardDayYesterday => 'Ontem';

  @override
  String get dashboardPreviousDayTooltip => 'Dia anterior';

  @override
  String get dashboardNextDayTooltip => 'Próximo dia';

  @override
  String get navHome => 'Início';

  @override
  String get trackingRunsWhileOpen =>
      'O rastreamento só funciona enquanto o FocusTrace está aberto.';

  @override
  String get dashboardStopTracking => 'Parar rastreamento';

  @override
  String get dashboardStartTracking => 'Iniciar rastreamento';

  @override
  String get dashboardNoUsageToday => 'Nenhum uso registrado hoje.';

  @override
  String get dashboardNoUsageDay => 'Nenhum uso registrado neste dia.';

  @override
  String get dashboardAllTimeMostUsedTitle =>
      'App mais usado de todos os tempos';

  @override
  String get dashboardUnsupportedPlatform =>
      'O MVP do FocusTrace é compatível com Android e Windows. Outras plataformas poderão ser adicionadas depois por meio de fontes de dados isoladas.';

  @override
  String get commonRetry => 'Tentar novamente';

  @override
  String get commonUnexpectedError => 'Algo deu errado. Tente novamente.';

  @override
  String get usageBubblesTitle => 'Bolhas de uso';

  @override
  String get usageBubblesDescription =>
      'Bolhas maiores indicam mais tempo de uso';

  @override
  String get usageBubblesCurrentList => 'Lista atual';

  @override
  String get actionUnblockNow => 'Desbloquear agora';

  @override
  String get actionUnblockNowDescription => 'Remover regras de bloqueio ativas';

  @override
  String get actionRestrictApp => 'Restringir app...';

  @override
  String get actionRestrictAppDescription =>
      'Bloquear agora, definir um limite ou adicionar um horário';

  @override
  String percentageValue(String percentage) {
    return '$percentage%';
  }

  @override
  String get actionRemoveFromToday => 'Remover de hoje';

  @override
  String get actionRemoveFromTodayDescription =>
      'Ocultar este app das estatísticas de hoje';

  @override
  String get actionExcludeFromTracking => 'Excluir do rastreamento';

  @override
  String get actionExcludeFromTrackingDescription =>
      'Parar de rastrear e ocultar de todas as estatísticas';

  @override
  String excludeAppDialogTitle(String appName) {
    return 'Excluir $appName?';
  }

  @override
  String get excludeAppDialogBody =>
      'O app não será mais rastreado nem exibido nas estatísticas. Você pode desfazer isso em Configurações.';

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
      'Os detalhes das sessões não estão disponíveis nesta plataforma.';

  @override
  String get sessionNoneRecorded => 'Nenhuma sessão registrada.';

  @override
  String get sessionLongestTitle => 'Sessões mais longas';

  @override
  String sessionOngoingLabel(String startTime, String duration) {
    return '$startTime · $duration';
  }

  @override
  String sessionRangeLabel(String startTime, String endTime, String duration) {
    return '$startTime – $endTime · $duration';
  }

  @override
  String get permissionWindowsPrivacyTitle => 'Privacidade no Windows';

  @override
  String get permissionUsageAccessRequiredTitle => 'Acesso ao uso necessário';

  @override
  String get permissionUsageAccessRequiredBody =>
      'FocusTrace precisa do Acesso ao uso do Android para ler os dados de uso dos seus apps. Os dados ficam armazenados localmente neste dispositivo.';

  @override
  String get permissionOpenUsageAccessSettings =>
      'Abrir configurações de Acesso ao uso';

  @override
  String get commonRecheck => 'Verificar novamente';

  @override
  String get trackingWindowsRunning =>
      'O rastreamento no Windows está ativo enquanto o FocusTrace está aberto.';

  @override
  String get trackingWindowsIdle =>
      'O rastreamento no Windows só funciona enquanto o FocusTrace está aberto.';

  @override
  String get trackingAndroidUsageAccess =>
      'O uso no Android é lido pelo Acesso ao uso.';

  @override
  String get trackingUnsupportedPlatform =>
      'O rastreamento de uso ainda não é compatível com esta plataforma.';

  @override
  String get trackingError =>
      'Ocorreu um problema no rastreamento. Uma nova tentativa será feita automaticamente.';

  @override
  String bubblePercentageOfToday(String percentage) {
    return '$percentage% do total de hoje';
  }

  @override
  String usageBubbleSemanticsLabel(String appName, String category) {
    return '$appName, $category';
  }

  @override
  String usageBubbleNearLimitSemanticsLabel(String appName, String category) {
    return '$appName, $category, limite diário quase atingido';
  }

  @override
  String summaryLaunchCount(int count) {
    return 'Aberturas: $count';
  }

  @override
  String get usageTrendDayShort => 'D';

  @override
  String get usageTrendWeekShort => 'S';

  @override
  String get usageTrendMonthShort => 'M';

  @override
  String usageTrendIncrease(String period, int percentage) {
    return '$period: uso aumentou em $percentage%';
  }

  @override
  String usageTrendDecrease(String period, int percentage) {
    return '$period: uso diminuiu em $percentage%';
  }

  @override
  String usageTrendUnchanged(String period) {
    return '$period: uso sem alteração';
  }

  @override
  String get usageDetailsLastSevenDays => 'Últimos 7 dias';

  @override
  String usageDetailsMoreThanYesterday(int percentage) {
    return '$percentage% a mais que ontem';
  }

  @override
  String usageDetailsLessThanYesterday(int percentage) {
    return '$percentage% a menos que ontem';
  }

  @override
  String get usageDetailsSameAsYesterday => 'Igual a ontem';

  @override
  String get usageDetailsNoYesterdayComparison =>
      'Ainda sem comparação com ontem';

  @override
  String usageDetailsRankLabel(int rank) {
    return 'Nº $rank mais usado';
  }

  @override
  String usageDetailsRankLead(String duration, String appName) {
    return '$duration a mais que $appName';
  }

  @override
  String usageDetailsDayValue(String date, String duration) {
    return '$date: $duration';
  }

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsPrivacyTitle => 'Privacidade';

  @override
  String get settingsPrivacyBody =>
      'O FocusTrace armazena os dados de uso localmente neste dispositivo. Ele não envia o uso rastreado de apps ou janelas.';

  @override
  String get settingsClearLocalData => 'Limpar dados locais';

  @override
  String get settingsLanguageTitle => 'Idioma';

  @override
  String get settingsLanguageSystemDefault => 'Padrão do sistema';

  @override
  String get settingsChooseLanguage => 'Escolher idioma';

  @override
  String get settingsLanguageUpdateError =>
      'Não foi possível aplicar a preferência de idioma. Tente novamente.';

  @override
  String get settingsExcludedAppsTitle => 'Apps excluídos';

  @override
  String get settingsExcludedAppsEmpty =>
      'Nenhum app excluído. Toque e segure um app no painel para excluí-lo do rastreamento.';

  @override
  String get settingsStopExcluding => 'Parar de excluir';

  @override
  String get settingsWindowsTrackingComingSoon =>
      'Em breve: rastreamento no Windows';

  @override
  String get settingsSendFeedback => 'Enviar feedback';

  @override
  String get settingsWindowsTrackingInterval =>
      'Intervalo de rastreamento no Windows';

  @override
  String get settingsWindowsIdleTimeout =>
      'Tempo limite de inatividade do Windows';

  @override
  String get settingsClearDataDialogTitle => 'Limpar dados locais?';

  @override
  String get settingsClearDataDialogBody =>
      'Isso remove deste dispositivo as sessões de uso e as configurações salvas. Sua escolha de idioma será preservada.';

  @override
  String get settingsCancel => 'Cancelar';

  @override
  String get settingsClear => 'Limpar';

  @override
  String get settingsSave => 'Salvar';

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
