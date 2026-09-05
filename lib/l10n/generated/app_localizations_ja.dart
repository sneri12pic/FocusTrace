// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'FocusTrace';

  @override
  String get durationLessThanOneMinute => '1分未満';

  @override
  String durationMinutesShort(int minutes) {
    return '$minutes分';
  }

  @override
  String durationHoursShort(int hours) {
    return '$hours時間';
  }

  @override
  String durationHoursMinutesShort(int hours, int minutes) {
    return '$hours時間$minutes分';
  }

  @override
  String get categoryEntertainment => 'エンターテインメント';

  @override
  String get categoryProductivity => '仕事効率化';

  @override
  String get categoryWeb => 'ウェブ';

  @override
  String get categoryCommunication => 'コミュニケーション';

  @override
  String get categorySystem => 'システム';

  @override
  String get categoryActivity => 'アクティビティ';

  @override
  String get onboardingSkip => 'スキップ';

  @override
  String get onboardingGetStarted => 'はじめる';

  @override
  String get onboardingContinue => '続ける';

  @override
  String get onboardingStartSoftBlocks => 'ソフトブロックを開始';

  @override
  String get onboardingChooseLater => '後で選ぶ';

  @override
  String get onboardingChooseWhatToLimit => '制限するアプリを選ぶ';

  @override
  String get onboardingChooseWhatToLimitDescription =>
      'アプリを選び、ソフトブロックの1日の目標を設定します。';

  @override
  String get onboardingNoAppsToChooseTitle => '選べるアプリがまだありません';

  @override
  String get onboardingNoAppsToChooseBody =>
      'FocusTraceでアプリを表示するには、現在の使用状況データが必要です。設定をスキップし、後で「設定」から制限を追加できます。';

  @override
  String get onboardingNoMatchingAppsTitle => '一致するアプリがありません';

  @override
  String get onboardingNoMatchingAppsBody => '別の検索語をお試しください。';

  @override
  String get onboardingWelcomeTitle => 'スクリーンタイムを取り戻そう';

  @override
  String get onboardingWelcomeBody =>
      '時間の使い方を把握しましょう。\n無理のない制限を設定しましょう。\n自分のペースでより良い習慣を身につけましょう。';

  @override
  String get onboardingAccessTitle => 'FocusTraceにアクセスを許可';

  @override
  String get onboardingAccessBody =>
      'FocusTraceが機能するには2つの権限が必要です。\nすべてのデータは端末内に保存されます。';

  @override
  String get onboardingNoPermissionsTitle => '許可する項目はありません';

  @override
  String get onboardingNoPermissionsBody => 'これらの権限が必要なのはAndroidだけです。';

  @override
  String get onboardingUsageAccessTitle => '使用状況へのアクセス';

  @override
  String get onboardingUsageAccessSubtitle => 'アプリの使用時間を計測するため';

  @override
  String get onboardingOverlayAccessTitle => '他のアプリの上に表示';

  @override
  String get onboardingOverlayAccessSubtitle => '制限したアプリの上にブロック画面を表示するため';

  @override
  String get onboardingPermissionsSettingsHint => '最初の2つの権限はAndroidの設定で管理されます。';

  @override
  String get onboardingAllow => '許可';

  @override
  String get onboardingOpenSettings => '設定を開く';

  @override
  String get onboardingNotificationsTitle => '通知';

  @override
  String get onboardingNotificationsSubtitle => '任意：1日の上限に達する前にお知らせします';

  @override
  String get onboardingSearchApps => 'アプリを検索';

  @override
  String onboardingAppUsageToday(String appKey, String duration) {
    return '$appKey・今日 $duration';
  }

  @override
  String get onboardingDailyTarget => '1日の目標';

  @override
  String get restrictionsTitle => '制限';

  @override
  String get restrictionsSearchApps => 'アプリを検索';

  @override
  String get restrictionsAddRestriction => '制限を追加';

  @override
  String get restrictionsAddRoutine => '新しいルーティン';

  @override
  String get restrictionsRoutinesTitle => 'ブロックルーティン';

  @override
  String get restrictionsRoutinesEmptyTitle => 'ブロックルーティンはありません';

  @override
  String get restrictionsRoutinesEmptyBody =>
      'アプリをルーティンにまとめ、グループ全体をオンまたはオフにできます。';

  @override
  String get restrictionsIndividualRulesTitle => '個別の制限';

  @override
  String restrictionsRoutineAppCount(int count) {
    return '$count個のアプリ';
  }

  @override
  String get restrictionsDeleteRoutine => 'ルーティンを削除';

  @override
  String get routineEditorNewTitle => '新しいブロックルーティン';

  @override
  String get routineEditorEditTitle => 'ブロックルーティンを編集';

  @override
  String get routineEditorName => 'ルーティン名';

  @override
  String get routineEditorSearchApps => 'アプリを検索';

  @override
  String get routineEditorNoMatchingApps => '一致するアプリはありません';

  @override
  String get routineEditorSave => 'ルーティンを保存';

  @override
  String get routineDailyLimit => '共有の1日上限';

  @override
  String get routineNoDailyLimit => '1日上限なし';

  @override
  String get routineCustomDuration => 'カスタム';

  @override
  String get routineChooseDuration => '1日上限を選択';

  @override
  String get routineNotFound => 'このルーティンは存在しません。';

  @override
  String get routineRename => 'ルーティン名を変更';

  @override
  String get routineAppsTitle => 'アプリ';

  @override
  String get routineAddApp => 'アプリを追加';

  @override
  String routineAppUsage(String duration) {
    return '今日 $duration · 上限に含む';
  }

  @override
  String routineAppUsageExcluded(String duration) {
    return '今日 $duration · 上限から除外';
  }

  @override
  String get routineRemoveApp => 'アプリを削除';

  @override
  String get routineKeepOneApp => 'ルーティンには1つ以上のアプリが必要です。';

  @override
  String routineDeleteConfirmation(String name) {
    return '$nameを削除しますか？この操作は元に戻せません。';
  }

  @override
  String get routineUsageToday => '今日のカウント対象時間';

  @override
  String get routineNoIncludedApps => '上限を有効にするにはアプリを1つ以上含めてください';

  @override
  String get routineLimitReached => '上限に到達 · 対象アプリは午前0時までブロックされます';

  @override
  String get routineActive => '有効';

  @override
  String get routinePaused => '一時停止';

  @override
  String routineUsageOfLimit(String used, String limit) {
    return '$limit中 $used';
  }

  @override
  String routineRemaining(String duration) {
    return '残り $duration';
  }

  @override
  String get routineSetLimit => '上限を設定';

  @override
  String get routineEditLimit => '上限を編集';

  @override
  String get routineRemoveLimit => '上限を削除';

  @override
  String routineUsageOnly(String duration) {
    return '今日 $duration';
  }

  @override
  String get restrictionsPlatformStatusTitle => 'このプラットフォームの状態のみ';

  @override
  String get restrictionsPlatformStatusBody =>
      'ルールは保存され、ここに表示されます。全画面ブロックは現在Androidでのみ動作します。';

  @override
  String get restrictionsEmptyTitle => 'アプリの制限はありません';

  @override
  String get restrictionsEmptyBody => '使用状況バブルまたは現在のリストでアプリを長押しすると、ルールを追加できます。';

  @override
  String get restrictionsNoAppsAvailable =>
      '利用できるアプリはまだありません。使用状況データが取得されたらダッシュボードを開き、ここで検索してください。';

  @override
  String get restrictionsNoMatchingApps => '一致するアプリがありません';

  @override
  String get restrictionsDeleteRule => 'ルールを削除';

  @override
  String get restrictionsUnblockNow => '今すぐブロック解除';

  @override
  String restrictionsBlockedUntil(String time) {
    return '$timeまでブロック';
  }

  @override
  String get restrictionsTemporaryBlockExpired => '一時ブロックは終了しました';

  @override
  String restrictionsDailyLimitStatus(
    String limitDuration,
    String usedDuration,
  ) {
    return '1日の上限 $limitDuration・$usedDuration 使用済み';
  }

  @override
  String restrictionsScheduleStatus(String startTime, String endTime) {
    return 'スケジュール $startTime～$endTime';
  }

  @override
  String get restrictionsOverlayPermissionTitle => 'オーバーレイ権限が必要です';

  @override
  String get restrictionsOverlayPermissionBody =>
      'FocusTraceがブロック画面を表示するには、Androidの「他のアプリの上に表示」権限が必要です。';

  @override
  String get restrictionsOpenOverlaySettings => 'オーバーレイ設定を開く';

  @override
  String get restrictionsRecheck => '再確認';

  @override
  String get restrictionEditorAllowFullScreenTitle => '全画面ブロックを許可しますか？';

  @override
  String get restrictionEditorAllowFullScreenBody =>
      '制限したアプリが開いたときにブロック画面を表示するには、FocusTraceに「他のアプリの上に表示」権限が必要です。';

  @override
  String get restrictionEditorLater => '後で';

  @override
  String get restrictionEditorOpenSettings => '設定を開く';

  @override
  String get restrictionEditorTypeNow => '今すぐ';

  @override
  String get restrictionEditorTypeLimit => '上限';

  @override
  String get restrictionEditorTypeSchedule => 'スケジュール';

  @override
  String get restrictionEditorSaveRule => 'ルールを保存';

  @override
  String get restrictionEditorTomorrow => '明日';

  @override
  String restrictionEditorDailyLimitPerDay(String duration) {
    return '1日あたり $duration';
  }

  @override
  String dashboardDayTracked(String duration) {
    return '記録・$duration';
  }

  @override
  String get dashboardDayToday => '今日';

  @override
  String get dashboardDayYesterday => '昨日';

  @override
  String get dashboardPreviousDayTooltip => '前の日';

  @override
  String get dashboardNextDayTooltip => '次の日';

  @override
  String get navHome => 'ホーム';

  @override
  String get trackingRunsWhileOpen => 'FocusTraceを開いている間のみ追跡します。';

  @override
  String get dashboardStopTracking => '追跡を停止';

  @override
  String get dashboardStartTracking => '追跡を開始';

  @override
  String get dashboardNoUsageToday => '今日は使用記録がありません。';

  @override
  String get dashboardNoUsageDay => 'この日は使用記録がありません。';

  @override
  String get dashboardAllTimeMostUsedTitle => '最もよく使うアプリ';

  @override
  String get dashboardUnsupportedPlatform =>
      'FocusTrace MVPはAndroidとWindowsに対応しています。その他のプラットフォームは、独立したプラットフォームデータソースを通じて今後追加できます。';

  @override
  String get commonRetry => '再試行';

  @override
  String get commonUnexpectedError => '問題が発生しました。もう一度お試しください。';

  @override
  String get usageBubblesTitle => '使用状況バブル';

  @override
  String get usageBubblesDescription => 'バブルが大きいほど使用時間が長いことを示します';

  @override
  String get usageBubblesCurrentList => '現在のリスト';

  @override
  String get actionUnblockNow => '今すぐブロック解除';

  @override
  String get actionUnblockNowDescription => '有効なブロックルールを削除';

  @override
  String get actionRestrictApp => 'アプリを制限...';

  @override
  String get actionRestrictAppDescription => '今すぐブロック、上限設定、スケジュール追加';

  @override
  String percentageValue(String percentage) {
    return '$percentage%';
  }

  @override
  String get actionRemoveFromToday => '今日から削除';

  @override
  String get actionRemoveFromTodayDescription => '今日の統計からこのアプリを非表示';

  @override
  String get actionExcludeFromTracking => '追跡から除外';

  @override
  String get actionExcludeFromTrackingDescription => '追跡を停止し、すべての統計から非表示';

  @override
  String excludeAppDialogTitle(String appName) {
    return '$appNameを除外しますか？';
  }

  @override
  String get excludeAppDialogBody => 'このアプリは追跡されず、統計にも表示されなくなります。「設定」から元に戻せます。';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get actionExclude => '除外';

  @override
  String sessionTotal(String duration) {
    return '合計・$duration';
  }

  @override
  String get sessionDetailsUnavailable => 'このプラットフォームではセッションの詳細を利用できません。';

  @override
  String get sessionNoneRecorded => '記録されたセッションはありません。';

  @override
  String get sessionLongestTitle => '最長のセッション';

  @override
  String sessionOngoingLabel(String startTime, String duration) {
    return '$startTime・$duration';
  }

  @override
  String sessionRangeLabel(String startTime, String endTime, String duration) {
    return '$startTime～$endTime・$duration';
  }

  @override
  String get permissionWindowsPrivacyTitle => 'Windowsのプライバシー';

  @override
  String get permissionUsageAccessRequiredTitle => '使用状況へのアクセスが必要です';

  @override
  String get permissionUsageAccessRequiredBody =>
      'FocusTraceがアプリの使用状況を読み取るには、Androidの「使用状況へのアクセス」が必要です。データはこの端末内に保存されます。';

  @override
  String get permissionOpenUsageAccessSettings => '使用状況へのアクセス設定を開く';

  @override
  String get commonRecheck => '再確認';

  @override
  String get trackingWindowsRunning => 'FocusTraceを開いている間、Windowsの追跡が実行されています。';

  @override
  String get trackingWindowsIdle => 'Windowsの追跡はFocusTraceを開いている間のみ実行されます。';

  @override
  String get trackingAndroidUsageAccess =>
      'Androidの使用状況は「使用状況へのアクセス」から読み取られます。';

  @override
  String get trackingUnsupportedPlatform => 'このプラットフォームでは使用状況の追跡にまだ対応していません。';

  @override
  String get trackingError => '追跡中に問題が発生しました。自動的に再試行します。';

  @override
  String bubblePercentageOfToday(String percentage) {
    return '今日の$percentage%';
  }

  @override
  String usageBubbleSemanticsLabel(String appName, String category) {
    return '$appName、$category';
  }

  @override
  String usageBubbleNearLimitSemanticsLabel(String appName, String category) {
    return '$appName、$category、1日の上限にまもなく到達';
  }

  @override
  String summaryLaunchCount(int count) {
    return '起動回数: $count';
  }

  @override
  String get usageTrendDayShort => '日';

  @override
  String get usageTrendWeekShort => '週';

  @override
  String get usageTrendMonthShort => '月';

  @override
  String usageTrendIncrease(String period, int percentage) {
    return '$period: 使用時間が$percentage%増加';
  }

  @override
  String usageTrendDecrease(String period, int percentage) {
    return '$period: 使用時間が$percentage%減少';
  }

  @override
  String usageTrendUnchanged(String period) {
    return '$period: 使用時間に変化なし';
  }

  @override
  String get usageDetailsLastSevenDays => '過去7日間';

  @override
  String get usageDetailsTimeTracked => '追跡時間';

  @override
  String get usageDetailsPeriodSevenDays => '7日間';

  @override
  String get usageDetailsPeriodTwoWeeks => '2週間';

  @override
  String get usageDetailsPeriodMonth => '1か月';

  @override
  String get usageDetailsPeriodYear => '1年間';

  @override
  String usageDetailsPeriodTotal(String period, String duration) {
    return '$period: $duration';
  }

  @override
  String usageDetailsMoreThanYesterday(int percentage) {
    return '昨日より$percentage%多い';
  }

  @override
  String usageDetailsLessThanYesterday(int percentage) {
    return '昨日より$percentage%少ない';
  }

  @override
  String get usageDetailsSameAsYesterday => '昨日と同じ';

  @override
  String get usageDetailsNoYesterdayComparison => '昨日との比較はまだありません';

  @override
  String usageDetailsRankLabel(int rank) {
    return '利用時間第$rank位';
  }

  @override
  String usageDetailsRankLead(String duration, String appName) {
    return '$appNameより$duration多い';
  }

  @override
  String usageDetailsDayValue(String date, String duration) {
    return '$date: $duration';
  }

  @override
  String get reportsTitle => 'レポート';

  @override
  String get reportsWeekly => '週間';

  @override
  String get reportsMonthly => '月間';

  @override
  String get reportsYearly => '年間';

  @override
  String get reportsTotalUsage => '合計使用時間';

  @override
  String get reportsDailyAverage => '1日平均';

  @override
  String get reportsActiveDays => '利用日数';

  @override
  String get reportsTimeOfDayTitle => '時間帯別の使用状況';

  @override
  String get reportsHabitTitle => '習慣形成';

  @override
  String get reportsPeakTime => '最も活発な時間';

  @override
  String get reportsFirstUse => '平均初回使用時刻';

  @override
  String get reportsFirstApp => '最も多い最初のアプリ';

  @override
  String get reportsConsistency => '初回使用の一貫性';

  @override
  String reportsVariationMinutes(int minutes) {
    return '± $minutes分';
  }

  @override
  String get reportsWakeHeuristic =>
      '初回使用は、4時間以上操作がなく、04:00〜14:00の間に使われた時刻から推定されます。';

  @override
  String get reportsTopApps => '最も使用したアプリ';

  @override
  String get reportsRestrictionsTitle => '制限アクティビティ';

  @override
  String get reportsBlockedAttempts => 'ブロック回数';

  @override
  String get reportsManualUnblocks => '手動解除回数';

  @override
  String get reportsBlocked => 'ブロック';

  @override
  String get reportsUnblocked => '解除';

  @override
  String get reportsEmpty => 'このレポートを作成するためのローカルデータがまだ十分ではありません。';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsGeneralSection => '一般';

  @override
  String get settingsActivityDataSection => 'アクティビティとデータ';

  @override
  String get settingsSupportSection => 'サポート';

  @override
  String get settingsPrivacyTitle => 'データとプライバシー';

  @override
  String get settingsPrivacyBody =>
      '使用履歴と設定は、バックアップを書き出さない限りこの端末内に保存されます。FocusTrace がそれらをアップロードすることはありません。';

  @override
  String get settingsClearLocalData => 'ローカルデータを削除';

  @override
  String get settingsDataTransferTitle => 'バックアップと復元';

  @override
  String get settingsDataTransferBody =>
      '持ち運べるバックアップを保存するか、別の FocusTrace インストールからデータを復元できます。読み込んだデータは、この端末にあるデータと統合されます。';

  @override
  String get settingsExportData => 'データを書き出す';

  @override
  String get settingsImportData => 'データを読み込む';

  @override
  String get settingsExportSuccess => 'FocusTrace のバックアップを保存しました。';

  @override
  String get settingsImportSuccess => 'FocusTrace のバックアップを読み込みました。';

  @override
  String get settingsImportDialogTitle => 'FocusTrace のデータを読み込みますか？';

  @override
  String get settingsImportDialogBody =>
      'バックアップは既存のローカルデータと統合されます。同じレコードと設定には、読み込んだ値が使用されます。';

  @override
  String get settingsLanguageTitle => '言語';

  @override
  String get settingsLanguageSystemDefault => 'システムのデフォルト';

  @override
  String get settingsChooseLanguage => '言語を選択';

  @override
  String get settingsLanguageUpdateError => '言語設定を適用できませんでした。もう一度お試しください。';

  @override
  String get settingsExcludedAppsTitle => '追跡から除外したアプリ';

  @override
  String get settingsExcludedAppsEmpty =>
      '追跡から除外したアプリはありません。ダッシュボードでアプリを長押しすると、ここに追加できます。';

  @override
  String get settingsStopExcluding => '除外を解除';

  @override
  String get settingsWindowsTrackingComingSoon => '近日公開: Windows追跡';

  @override
  String get settingsSendFeedback => 'フィードバックを送信';

  @override
  String get settingsWindowsTrackingInterval => 'Windowsの追跡間隔';

  @override
  String get settingsWindowsIdleTimeout => 'Windowsのアイドルタイムアウト';

  @override
  String get settingsClearDataDialogTitle => 'すべてのローカルデータを削除しますか？';

  @override
  String get settingsClearDataDialogBody =>
      '使用履歴と設定がこの端末から完全に削除されます。言語の選択は保持されます。後でデータが必要になる可能性がある場合は、先にバックアップを書き出してください。';

  @override
  String get settingsCancel => 'キャンセル';

  @override
  String get settingsClear => '削除';

  @override
  String get settingsSave => '保存';

  @override
  String secondsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count秒',
    );
    return '$_temp0';
  }
}
