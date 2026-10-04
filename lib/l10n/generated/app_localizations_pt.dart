// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

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
  String get settingsClearDataDialogBody =>
      'Isso exclui permanentemente deste dispositivo o histórico de uso e as configurações. Sua escolha de idioma será preservada. Exporte um backup primeiro se você puder precisar desses dados.';

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
      'O seu histórico de uso e as definições ficam neste dispositivo, a menos que exporte uma cópia ou ative a sincronização na nuvem abaixo.';
}
