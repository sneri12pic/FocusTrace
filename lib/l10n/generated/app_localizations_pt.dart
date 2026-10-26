// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appCategoryAll => 'Todas';

  @override
  String get appCategoryTitle => 'Categoria do aplicativo';

  @override
  String get appCategoryAutomatic => 'Automática';

  @override
  String get appCategorySave => 'Salvar categoria';

  @override
  String get appCategorySaveError =>
      'Não foi possível salvar a categoria. Tente novamente.';

  @override
  String get usageDetailsBarChart => 'Gráfico de barras';

  @override
  String get usageDetailsAreaChart => 'Tendência de uso';

  @override
  String get usageDetailsChartSaveError =>
      'Não foi possível salvar sua escolha de gráfico. Tente novamente.';

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
      'As duas primeiras permissões são controladas nas configurações do Android.';

  @override
  String get onboardingAllow => 'Permitir';

  @override
  String get onboardingOpenSettings => 'Abrir configurações';

  @override
  String get onboardingNotificationsTitle => 'Notificações';

  @override
  String get onboardingNotificationsSubtitle =>
      'Opcional: receba alertas antes de atingir um limite diário';

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
  String get routineDailyLimit => 'Limite diário compartilhado';

  @override
  String get routineNoDailyLimit => 'Sem limite diário';

  @override
  String get routineCustomDuration => 'Personalizado';

  @override
  String get routineChooseDuration => 'Escolher limite diário';

  @override
  String get routineNotFound => 'Esta rotina não existe mais.';

  @override
  String get routineRename => 'Renomear rotina';

  @override
  String get routineAppsTitle => 'Apps';

  @override
  String get routineAddApp => 'Adicionar app';

  @override
  String routineAppUsage(String duration) {
    return '$duration hoje · Incluído no limite';
  }

  @override
  String routineAppUsageExcluded(String duration) {
    return '$duration hoje · Excluído do limite';
  }

  @override
  String get routineRemoveApp => 'Remover app';

  @override
  String get routineKeepOneApp => 'Uma rotina deve manter pelo menos um app.';

  @override
  String routineDeleteConfirmation(String name) {
    return 'Excluir $name? Esta ação não pode ser desfeita.';
  }

  @override
  String get routineUsageToday => 'Uso contabilizado hoje';

  @override
  String get routineNoIncludedApps =>
      'Inclua pelo menos um app para ativar o limite';

  @override
  String get routineLimitReached =>
      'Limite atingido · os apps incluídos estão bloqueados até meia-noite';

  @override
  String get routineActive => 'Ativa';

  @override
  String get routinePaused => 'Pausada';

  @override
  String routineUsageOfLimit(String used, String limit) {
    return '$used de $limit';
  }

  @override
  String routineRemaining(String duration) {
    return 'Restam $duration';
  }

  @override
  String get routineSetLimit => 'Definir limite';

  @override
  String get routineEditLimit => 'Editar limite';

  @override
  String get routineRemoveLimit => 'Remover limite';

  @override
  String routineUsageOnly(String duration) {
    return '$duration hoje';
  }

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
  String get dashboardUsageUnavailableDay =>
      'Os dados de uso não estão disponíveis no momento para este dia.';

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
  String usageListShowAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostrar tudo (mais $count)',
      one: 'Mostrar tudo (mais 1)',
    );
    return '$_temp0';
  }

  @override
  String get usageListShowLess => 'Mostrar menos';

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
  String get usageTrendNew => 'Novo';

  @override
  String usageTrendNewLabel(String period) {
    return '$period: uso novo, sem dados anteriores para comparar';
  }

  @override
  String usageTrendIncreaseAboveCap(String period, int percentage) {
    return '$period: uso aumentou mais de $percentage%';
  }

  @override
  String get usageDetailsLastSevenDays => 'Últimos 7 dias';

  @override
  String get usageDetailsTimeTracked => 'Tempo monitorado';

  @override
  String get usageDetailsPeriodSevenDays => '7 dias';

  @override
  String get usageDetailsPeriodTwoWeeks => '2 semanas';

  @override
  String get usageDetailsPeriodMonth => 'Um mês';

  @override
  String get usageDetailsPeriodYear => 'Um ano';

  @override
  String usageDetailsPeriodTotal(String period, String duration) {
    return '$period: $duration';
  }

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
  String get reportsTitle => 'Relatórios';

  @override
  String get reportsWeekly => 'Semanal';

  @override
  String get reportsMonthly => 'Mensal';

  @override
  String get reportsYearly => 'Anual';

  @override
  String get reportsTotalUsage => 'Uso total';

  @override
  String get reportsDailyAverage => 'Média diária';

  @override
  String get reportsActiveDays => 'Dias ativos';

  @override
  String get reportsTimeOfDayTitle => 'Uso por hora do dia';

  @override
  String get reportsHabitTitle => 'Formação de hábitos';

  @override
  String get reportsPeakTime => 'Horário mais ativo';

  @override
  String get reportsFirstUse => 'Média do primeiro uso';

  @override
  String get reportsFirstApp => 'Primeiro app mais frequente';

  @override
  String get reportsConsistency => 'Consistência do primeiro uso';

  @override
  String reportsVariationMinutes(int minutes) {
    return '± $minutes min';
  }

  @override
  String get reportsWakeHeuristic =>
      'O primeiro uso é estimado após pelo menos 4 horas de inatividade, entre 04:00 e 14:00.';

  @override
  String get reportsTopApps => 'Apps mais usados';

  @override
  String get reportsRestrictionsTitle => 'Atividade de restrições';

  @override
  String get reportsBlockedAttempts => 'Tentativas bloqueadas';

  @override
  String get reportsManualUnblocks => 'Desbloqueios manuais';

  @override
  String get reportsBlocked => 'Bloqueado';

  @override
  String get reportsUnblocked => 'Desbloqueado';

  @override
  String get reportsEmpty =>
      'Ainda não há dados locais suficientes para este relatório.';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsGeneralSection => 'Geral';

  @override
  String get settingsActivityDataSection => 'Atividade e dados';

  @override
  String get settingsSupportSection => 'Suporte';

  @override
  String get settingsPrivacyTitle => 'Dados e privacidade';

  @override
  String get settingsPrivacyBody =>
      'Seu histórico de uso e suas configurações ficam neste dispositivo, a menos que você exporte um backup. O FocusTrace nunca os envia.';

  @override
  String get settingsClearLocalData => 'Excluir dados locais';

  @override
  String get settingsDataTransferTitle => 'Backup e restauração';

  @override
  String get settingsDataTransferBody =>
      'Salve um backup portátil ou restaure dados de outra instalação do FocusTrace. Os dados importados são combinados com os que já existem neste dispositivo.';

  @override
  String get settingsExportData => 'Exportar dados';

  @override
  String get settingsImportData => 'Importar dados';

  @override
  String get settingsExportSuccess => 'Backup do FocusTrace salvo.';

  @override
  String get settingsImportSuccess => 'Backup do FocusTrace importado.';

  @override
  String get settingsImportDialogTitle => 'Importar dados do FocusTrace?';

  @override
  String get settingsImportDialogBody =>
      'O backup será combinado com os dados locais existentes. Registros e configurações correspondentes usarão os valores importados.';

  @override
  String get settingsImportDialogDetail =>
      'Isso inclui restrições, rotinas de bloqueio, aplicativos excluídos e categorias de aplicativos, se o backup os tiver. Nada neste dispositivo é excluído e a sessão de sincronização não muda.';

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
  String get settingsExcludedAppsTitle => 'Exclusões do rastreamento';

  @override
  String get settingsExcludedAppsEmpty =>
      'Nenhum app está excluído do rastreamento. Toque e segure um app no painel para adicioná-lo aqui.';

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
  String get settingsClearDataDialogTitle => 'Excluir todos os dados locais?';

  @override
  String get settingsClearDataDeletes =>
      'Será excluído deste dispositivo: histórico de uso e relatórios, restrições e rotinas de bloqueio, aplicativos excluídos, categorias de aplicativos e demais configurações.';

  @override
  String get settingsClearDataKeeps =>
      'Mantido: sua escolha de idioma. As permissões do Android não mudam. Exporte um backup antes se puder precisar desses dados.';

  @override
  String get settingsClearDataKeepsSync =>
      'Sua conta na nuvem e os dados já sincronizados não são excluídos. A sincronização é desativada neste dispositivo.';

  @override
  String get settingsClearDataDone => 'Dados locais excluídos.';

  @override
  String get settingsCancel => 'Cancelar';

  @override
  String get settingsClear => 'Excluir';

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

  @override
  String get settingsSyncSection => 'Conta e sincronização';

  @override
  String get settingsSyncTitle => 'Sincronização na nuvem';

  @override
  String get settingsSyncBody =>
      'Inicie sessão para copiar os seus totais de uso diário para a sua conta e vê-los noutro dispositivo. Desligada até a ativar.';

  @override
  String get settingsSyncEmail => 'E-mail';

  @override
  String get settingsSyncPassword => 'Palavra-passe';

  @override
  String get settingsSyncPasswordRequirements =>
      'Use entre 15 e 128 caracteres. Algumas palavras sem relação formam uma frase-passe segura e fácil de memorizar. Palavras-passe comuns não são aceites.';

  @override
  String get settingsSyncShowPassword => 'Mostrar palavra-passe';

  @override
  String get settingsSyncHidePassword => 'Ocultar palavra-passe';

  @override
  String get settingsSyncSignInHeading => 'Inicie sessão na sua conta';

  @override
  String get settingsSyncCreateHeading => 'Crie uma conta de sincronização';

  @override
  String get settingsSyncSwitchToCreate =>
      'Ainda não usa a sincronização? Crie uma conta';

  @override
  String get settingsSyncSwitchToSignIn => 'Já tem uma conta? Inicie sessão';

  @override
  String get settingsSyncSignInInstead =>
      'Iniciar sessão em vez de criar conta';

  @override
  String get settingsSyncSigningIn => 'A iniciar sessão…';

  @override
  String get settingsSyncCreatingAccount => 'A criar conta…';

  @override
  String get settingsSyncAccountCreated => 'Conta criada';

  @override
  String settingsSyncSignedInAs(String email) {
    return 'Sessão iniciada como $email';
  }

  @override
  String get settingsSyncCreatedNextStep =>
      'A sincronização continua desligada. Ative-a quando quiser copiar os totais diários deste dispositivo para a sua conta.';

  @override
  String get settingsSyncTurnOnSync => 'Ativar sincronização';

  @override
  String get settingsSyncAccountCreatedSignInRequired =>
      'A sua conta foi criada, mas não foi possível iniciar sessão automaticamente. Introduza a palavra-passe e toque em «Iniciar sessão» para continuar.';

  @override
  String get settingsSyncErrorRegistration =>
      'Conta não criada. Verifique o seu e-mail e a palavra-passe e tente novamente.';

  @override
  String get settingsSyncErrorEmailRequired =>
      'Introduza o seu endereço de e-mail.';

  @override
  String get settingsSyncErrorEmailInvalid =>
      'Introduza um endereço de e-mail válido, como nome@example.com.';

  @override
  String get settingsSyncErrorPasswordRequired =>
      'Introduza a sua palavra-passe.';

  @override
  String settingsSyncErrorPasswordTooShort(int count) {
    return 'Use pelo menos 15 caracteres ($count até agora).';
  }

  @override
  String get settingsSyncErrorPasswordTooLong =>
      'Use no máximo 128 caracteres.';

  @override
  String get settingsSyncErrorPasswordRejected =>
      'Esta palavra-passe é demasiado comum ou corresponde ao seu e-mail. Escolha outra.';

  @override
  String get settingsSyncErrorThrottled =>
      'Demasiadas tentativas a partir desta rede. Aguarde um pouco e tente novamente.';

  @override
  String get settingsSyncSignIn => 'Iniciar sessão';

  @override
  String get settingsSyncCreateAccount => 'Criar conta';

  @override
  String get settingsSyncSignOut => 'Terminar sessão';

  @override
  String get settingsSyncEnabledLabel => 'Sincronizar este dispositivo';

  @override
  String get settingsSyncEnabledSubtitle =>
      'Desligar para de enviar dados novos. Nada já sincronizado é apagado.';

  @override
  String get settingsSyncNow => 'Sincronizar agora';

  @override
  String get settingsSyncNeverSynced => 'Ainda não sincronizado';

  @override
  String get settingsSyncStateSyncing => 'A sincronizar...';

  @override
  String get settingsSyncStateSuccess => 'Sincronização concluída';

  @override
  String get settingsSyncStateError => 'Falha na sincronização';

  @override
  String get settingsSyncErrorOffline =>
      'Não foi possível contactar o serviço. Verifique a ligação e tente novamente.';

  @override
  String get settingsSyncErrorCredentials =>
      'Esse e-mail e palavra-passe não correspondem a nenhuma conta.';

  @override
  String get settingsSyncErrorEmailTaken =>
      'Já existe uma conta com esse e-mail.';

  @override
  String get settingsSyncErrorWeakPassword =>
      'Escolha uma palavra-passe mais longa e menos comum.';

  @override
  String get settingsSyncErrorSessionExpired =>
      'A sua sessão terminou. Inicie sessão novamente.';

  @override
  String get settingsSyncErrorRefused => 'O serviço recusou o pedido.';

  @override
  String get settingsSyncErrorUnknown => 'Algo correu mal. Tente novamente.';

  @override
  String get settingsSyncDeleteAccount => 'Excluir conta';

  @override
  String get settingsSyncDeleteTitle => 'Excluir sua conta do FocusTrace?';

  @override
  String get settingsSyncDeleteBody =>
      'Isso exclui permanentemente sua conta na nuvem do FocusTrace e todos os dados de uso sincronizados com o servidor. Não é possível desfazer.\n\nO histórico de uso neste dispositivo é mantido e a sincronização será desativada.';

  @override
  String get settingsSyncDeletePassword => 'Senha atual';

  @override
  String get settingsSyncDeleteConfirm => 'Excluir permanentemente';

  @override
  String get settingsSyncDeleted =>
      'Sua conta do FocusTrace foi excluída. O histórico de uso neste dispositivo foi mantido.';

  @override
  String get settingsSyncRepeatPassword => 'Repetir palavra-passe';

  @override
  String get settingsSyncShowRepeatPassword => 'Mostrar palavra-passe repetida';

  @override
  String get settingsSyncHideRepeatPassword => 'Ocultar palavra-passe repetida';

  @override
  String get settingsSyncErrorPasswordMismatch =>
      'As palavras-passe não coincidem.';

  @override
  String get settingsSyncDangerZone => 'Zona de perigo';

  @override
  String get settingsSyncDangerZoneBody =>
      'Excluir sua conta a remove permanentemente, junto com todos os dados de uso sincronizados com o servidor. O histórico de uso neste dispositivo é mantido.';

  @override
  String get settingsSyncDeleteAcknowledge =>
      'Entendo que isto exclui permanentemente a minha conta na nuvem.';

  @override
  String get settingsSyncDeleting => 'Excluindo…';

  @override
  String get settingsSyncErrorWrongPassword =>
      'Essa senha não está correta. Sua conta não foi excluída.';

  @override
  String get settingsPrivacyBodySync =>
      'O seu histórico de uso e as definições ficam neste dispositivo, a menos que exporte uma cópia ou ative a sincronização na nuvem.';

  @override
  String get usageCalendarTotalThisMonth => 'Total neste mês';

  @override
  String get usageCalendarAveragePerDay => 'Média por dia';

  @override
  String get usageCalendarAppOpens => 'Aberturas';

  @override
  String get usageCalendarLongestSession => 'Sessão mais longa';

  @override
  String get usageCalendarVsLastMonth => 'vs. mês passado';

  @override
  String get usageCalendarPreviousMonth => 'Mês anterior';

  @override
  String get usageCalendarNextMonth => 'Próximo mês';

  @override
  String get usageCalendarTotalTime => 'Tempo total';

  @override
  String get usageCalendarAverageSession => 'Sessão média';

  @override
  String get usageCalendarVsDailyAverage => 'vs. sua média diária';

  @override
  String get usageCalendarTimeline => 'Linha do tempo de uso';

  @override
  String get usageCalendarNoTimeline => 'Sem detalhes de sessão para este dia';

  @override
  String get usageApproximateNote =>
      '≈ Aproximado: do resumo de uso do próprio Android, antes de o FocusTrace registrar';

  @override
  String get usageApproximateTag => '≈ Aproximado';

  @override
  String get onboardingHistoryChecking => 'Procurando uso anterior…';

  @override
  String get onboardingHistoryNone =>
      'O Android não guardou uso anterior neste telefone';

  @override
  String onboardingHistoryFound(String date) {
    return 'Encontramos seu uso anterior desde $date';
  }

  @override
  String restrictionsTimeLeft(String duration) {
    return 'Faltam $duration';
  }

  @override
  String get restrictionsLimitReached => 'Limite atingido';

  @override
  String get rxWeek => 'Esta semana';

  @override
  String get rxTopApps => 'Seus apps mais usados';

  @override
  String rxAverage(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Média diária · $days dias registrados',
      one: 'Média diária · 1 dia registrado',
    );
    return '$_temp0';
  }

  @override
  String get rxBusiest => 'Seus horários de maior uso';

  @override
  String rxPeak(String start, String end) {
    return 'A maior parte do uso registrado ocorre de $start a $end.';
  }

  @override
  String get rxNoInsights =>
      'Ainda não há uso registrado suficiente para sugerir um horário.';

  @override
  String get rxPlanBlock => 'Planejar um horário';

  @override
  String get rxYourRules => 'Suas restrições';

  @override
  String get rxLimit => 'Limite';

  @override
  String get rxEdit => 'Editar';

  @override
  String rxRestrict(String app) {
    return 'Restringir $app';
  }

  @override
  String rxAverageApp(String duration) {
    return 'Média de $duration / dia';
  }

  @override
  String get rxType => 'Tipo de restrição';

  @override
  String get rxDailyLimit => 'Limite diário';

  @override
  String get rxBlockNow => 'Bloquear agora';

  @override
  String get rxDifficulty => 'Dificuldade para desbloquear';

  @override
  String get rxEasy => 'Fácil';

  @override
  String get rxModerate => 'Moderada';

  @override
  String get rxHard => 'Difícil';

  @override
  String get rxEasyHint => 'Confirme para desbloquear';

  @override
  String get rxModerateHint => 'Espere 5 minutos para desbloquear';

  @override
  String get rxHardHint => 'Sem desbloqueio antecipado no FocusTrace';

  @override
  String get rxProtectionNote =>
      'Isso também se aplica à alteração ou remoção de uma regra ativa.';

  @override
  String get rxSetLimit => 'Definir limite diário';

  @override
  String get rxSetSchedule => 'Definir horário';

  @override
  String get rxStartBlock => 'Iniciar bloqueio';

  @override
  String rxBelowAverage(String duration) {
    return '$duration abaixo da sua média diária';
  }

  @override
  String get rxRepeat => 'Repetir';

  @override
  String get rxNextDay => 'Termina no dia seguinte';

  @override
  String rxEndsAt(String time) {
    return 'Termina às $time';
  }

  @override
  String get rxHardConfirm =>
      'Enquanto esta regra bloquear um app, você não poderá desbloqueá-lo, editar a regra ou removê-la antecipadamente no FocusTrace.';

  @override
  String get rxConfirm => 'Confirmar';

  @override
  String get rxChangeTitle => 'Alterar restrição?';

  @override
  String get rxChangeBody =>
      'Regras fáceis podem ser alteradas agora. Regras moderadas exigem cinco minutos de espera. Regras difíceis permanecem até o fim do bloqueio atual.';

  @override
  String get rxCooldown =>
      'A espera de cinco minutos começou. Tente novamente depois; o app fica bloqueado até você confirmar outra vez.';

  @override
  String get rxHardLocked =>
      'Esta regra está bloqueada até o fim do bloqueio atual.';

  @override
  String get rxUnavailable =>
      'Não foi possível verificar esta restrição. Confira o acesso ao uso e tente novamente.';

  @override
  String get rxMinutes => 'Duração em minutos';

  @override
  String get rxRetry => 'Tentar novamente';

  @override
  String get rxScheduleInvalid =>
      'Escolha horários de início e fim diferentes e pelo menos um dia.';

  @override
  String get rxNoUsage =>
      'Nenhum uso registrado neste período. Você ainda pode escolher qualquer app para restringir.';

  @override
  String rxNextBlock(String time) {
    return 'Próximo início: $time';
  }

  @override
  String rxPerDay(String duration) {
    return '$duration / dia';
  }

  @override
  String rxUntil(String time) {
    return 'Até $time';
  }

  @override
  String rxLeftToday(String duration) {
    return 'Faltam $duration hoje';
  }

  @override
  String rxStarts(String time) {
    return 'Começa $time';
  }

  @override
  String get rxStartLabel => 'Início';

  @override
  String get rxEndLabel => 'Fim';

  @override
  String get rxHoursField => 'Horas';

  @override
  String get rxMinutesField => 'Minutos';

  @override
  String get rxAdd => 'Adicionar';

  @override
  String get rxNoRulesYet =>
      'Nenhuma restrição ainda. Escolha um app abaixo ou toque em Adicionar.';

  @override
  String get rxChooseApps => 'Escolha apps para limitar';

  @override
  String get rxSearchAll => 'Pesquisar todos os apps';

  @override
  String get rxTodayUsage => 'Uso de hoje até agora';

  @override
  String get rxCreate => 'Criar';

  @override
  String rxSharedLimit(String duration) {
    return 'Limite diário compartilhado · $duration';
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
  String get rxPaused => 'Pausada';

  @override
  String rxUsed(String duration) {
    return '$duration usado';
  }

  @override
  String rxLeft(String duration) {
    return 'Restam $duration';
  }

  @override
  String get rxEveryDay => 'Todos os dias';

  @override
  String get rxUnblockAfterWait => 'Desbloquear após 5 minutos de espera';

  @override
  String rxLockedUntil(String time) {
    return 'Bloqueada até $time';
  }

  @override
  String get rxEditDuration => 'Editar duração';

  @override
  String get rxSaveChanges => 'Salvar alterações';

  @override
  String get rxEasyExplain =>
      'Você pode desbloquear antes depois de confirmar. Editar ou remover esta regra enquanto ela bloqueia também pede confirmação.';

  @override
  String get rxModerateExplain =>
      'Desbloquear antes, ou editar ou remover esta regra enquanto ela bloqueia, inicia uma espera de cinco minutos. O app continua bloqueado nesse tempo. Quando a espera terminar, repita a ação e confirme de novo. Nada é desbloqueado sozinho.';

  @override
  String get rxHardExplain =>
      'Enquanto esta regra bloqueia, o FocusTrace não desbloqueia antes, e você não pode editá-la nem removê-la até o bloqueio terminar. Fora dos horários de bloqueio, você pode alterá-la normalmente.';

  @override
  String get rxModerateUnblockBody =>
      'Isso inicia uma espera de cinco minutos. O app continua bloqueado até ela terminar. Depois, escolha Desbloquear de novo e confirme.';

  @override
  String get routineLastAppPrompt =>
      'Esta rotina não tem mais apps. Excluir a rotina?';

  @override
  String get routineKeepRoutine => 'Manter rotina';

  @override
  String get routineNamePrompt => 'Adicione um nome à rotina';

  @override
  String get routineEmpty =>
      'Esta rotina ainda não tem apps. Adicione apps para voltar a usar os limites.';

  @override
  String get routineNoAppsShort => 'Nenhum app ainda';

  @override
  String get routinePickerAll => 'Todos';

  @override
  String routinePickerSelectCategory(String category) {
    return 'Selecionar tudo em $category';
  }

  @override
  String get routineAddApps => 'Adicionar apps';

  @override
  String routineAddSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Adicionar $count apps',
      one: 'Adicionar 1 app',
    );
    return '$_temp0';
  }

  @override
  String routineAppLimit(String duration) {
    return 'Limite do app $duration';
  }

  @override
  String get routineNoAppLimit => 'Sem limite do app';

  @override
  String routineAppLimitTitle(String app) {
    return 'Limite diário de $app';
  }

  @override
  String get routineAppLimitHint =>
      'Limita só este app. O tempo dele continua contando para o tempo compartilhado.';

  @override
  String routineReasonShared(String routine) {
    return '$routine: tempo compartilhado esgotado';
  }

  @override
  String routineReasonApp(String routine) {
    return '$routine: limite do app atingido';
  }

  @override
  String get reasonDailyAppLimit => 'Limite diário do app atingido';

  @override
  String reasonScheduleUntil(String time) {
    return 'Bloqueado pelo horário até $time';
  }

  @override
  String reasonTemporaryUntil(String time) {
    return 'Bloqueio temporário até $time';
  }

  @override
  String routineOpenDetails(String app) {
    return 'Abrir detalhes de $app';
  }

  @override
  String get usageTimelineHint =>
      'Toque ou arraste para ver horários exatos · segure para restringir um intervalo';

  @override
  String get rxRangeQuestion => 'Restringir este intervalo?';

  @override
  String get rxRangeHint => 'Arraste ou toque no anel para mover o fim';

  @override
  String get rxRangeAction => 'Restringir';

  @override
  String get rxScheduleDialHint =>
      'Arraste uma das pontas vermelhas ou toque onde ela deve ficar';

  @override
  String get healthConnectTitle => 'Health Connect';

  @override
  String get healthConnectSettingsOff =>
      'Desativado · importe treinos de apps como o Hevy';

  @override
  String healthConnectSettingsOn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ativado · $count treinos importados',
      one: 'Ativado · 1 treino importado',
      zero: 'Ativado · nenhum treino importado ainda',
    );
    return '$_temp0';
  }

  @override
  String get healthConnectIntro =>
      'Importe seus treinos de apps como o Hevy pelo Health Connect do Android. É opcional e vem desativado. O monitoramento, os limites e os bloqueios nunca dependem disso.';

  @override
  String get healthConnectDataTitle => 'O que o FocusTrace lê';

  @override
  String get healthConnectDataBody =>
      'Apenas sessões de exercício: o tipo de treino, o nome, quando começou e terminou e qual app o registrou. Nada além disso, como frequência cardíaca, trajetos ou séries, e o FocusTrace não grava nada no Health Connect. Os treinos importados ficam neste dispositivo: a sincronização não os envia e os backups não os incluem.';

  @override
  String get healthConnectImportSwitch => 'Importar treinos';

  @override
  String get healthConnectAutoImport => 'Importar automaticamente';

  @override
  String get healthConnectAutoImportBody =>
      'Procura treinos novos a cada poucas horas. Os apps sincronizam com o Health Connect no próprio ritmo, então um treino pode demorar a aparecer.';

  @override
  String get healthConnectAutoImportUnsupported =>
      'A importação automática precisa de uma versão mais nova do Health Connect. Importar agora continua funcionando.';

  @override
  String get healthConnectAutoImportBlocked =>
      'O Health Connect não permite que o FocusTrace leia em segundo plano, então a importação automática não pode rodar. Permita no Health Connect ou use Importar agora.';

  @override
  String get healthConnectImportNow => 'Importar agora';

  @override
  String healthConnectLastSuccess(String time) {
    return 'Última importação bem-sucedida: $time';
  }

  @override
  String get healthConnectNeverImported => 'Nada importado ainda';

  @override
  String healthConnectOutcomeImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Última verificação: $count treinos adicionados ou atualizados',
      one: 'Última verificação: 1 treino adicionado ou atualizado',
    );
    return '$_temp0';
  }

  @override
  String get healthConnectOutcomeNoNew =>
      'Última verificação: nenhum treino novo';

  @override
  String get healthConnectOutcomeUnavailable =>
      'A última verificação falhou: o Health Connect não está disponível';

  @override
  String get healthConnectOutcomePermission =>
      'A última verificação falhou: o acesso aos dados de exercício está desativado no Health Connect';

  @override
  String get healthConnectOutcomeBackground =>
      'A última verificação automática não pôde rodar em segundo plano';

  @override
  String get healthConnectOutcomeFailed =>
      'A última verificação não terminou. Ela será tentada de novo.';

  @override
  String get healthConnectUnavailable =>
      'O Health Connect não está disponível neste dispositivo. Ele precisa do Android 9 ou mais recente.';

  @override
  String get healthConnectUpdateRequired =>
      'Instale ou atualize o Health Connect pelo Google Play para usar isto.';

  @override
  String get healthConnectGetApp => 'Abrir o Google Play';

  @override
  String get healthConnectRevoked =>
      'O FocusTrace não tem mais acesso aos seus dados de exercício. Conceda de novo para continuar importando.';

  @override
  String get healthConnectGrantAgain => 'Conceder acesso';

  @override
  String get healthConnectManage => 'Gerenciar acesso no Health Connect';

  @override
  String get healthConnectOffNote =>
      'Desativar interrompe todas as leituras e importações agendadas. Isso não remove a permissão do FocusTrace nem muda nada no Health Connect; gerencie isso por lá. Os treinos já importados ficam neste dispositivo até você excluí-los.';

  @override
  String get healthConnectDeleteImported => 'Excluir treinos importados';

  @override
  String get healthConnectDeleteTitle => 'Excluir treinos importados?';

  @override
  String get healthConnectDeleteBody =>
      'Isso remove os treinos que o FocusTrace copiou para este dispositivo. Nada muda no Health Connect nem nos apps que os registraram.';

  @override
  String get healthConnectDelete => 'Excluir';

  @override
  String get healthConnectWorkoutsTitle => 'Treinos importados';

  @override
  String get healthConnectNoWorkouts =>
      'Nenhum treino ainda. A primeira importação cobre os últimos 30 dias; treinos mais antigos não são importados.';

  @override
  String healthConnectWorkoutSource(String duration, String app) {
    return '$duration · do $app';
  }

  @override
  String get workoutStrength => 'Musculação';

  @override
  String get workoutRunning => 'Corrida';

  @override
  String get workoutWalking => 'Caminhada';

  @override
  String get workoutCycling => 'Ciclismo';

  @override
  String get workoutSwimming => 'Natação';

  @override
  String get workoutYoga => 'Ioga';

  @override
  String get workoutOther => 'Treino';

  @override
  String get onboardingHealthTitle => 'Traga seus treinos';

  @override
  String get onboardingHealthBody =>
      'Opcional. Importe treinos de apps como o Hevy pelo Health Connect. O FocusTrace só lê sessões de exercício e as mantém neste dispositivo. Você pode mudar isso quando quiser nas Configurações.';

  @override
  String get onboardingHealthConnect => 'Conectar o Health Connect';

  @override
  String get onboardingHealthSkip => 'Agora não';

  @override
  String get onboardingHealthConnected =>
      'Conectado. Seus treinos ficam em Configurações, no Health Connect.';

  @override
  String get onboardingHealthDenied =>
      'Nenhum acesso foi concedido. Você pode conectar depois nas Configurações.';

  @override
  String get settingsClearDataHealth =>
      'A importação do Health Connect é desativada e os treinos importados são excluídos. Nada muda no Health Connect.';
}
