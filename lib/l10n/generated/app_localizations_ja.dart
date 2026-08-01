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
  String get onboardingPermissionsSettingsHint => '後で設定から変更できます。';

  @override
  String get onboardingAllow => '許可';

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
  String get settingsTitle => '設定';

  @override
  String get settingsPrivacyTitle => 'プライバシー';

  @override
  String get settingsPrivacyBody =>
      'FocusTraceは使用状況データをこの端末内に保存します。追跡したアプリやウィンドウの使用状況をアップロードすることはありません。';

  @override
  String get settingsClearLocalData => 'ローカルデータを削除';

  @override
  String get settingsLanguageTitle => '言語';

  @override
  String get settingsLanguageSystemDefault => 'システムのデフォルト';

  @override
  String get settingsChooseLanguage => '言語を選択';

  @override
  String get settingsLanguageUpdateError => '言語設定を適用できませんでした。もう一度お試しください。';

  @override
  String get settingsExcludedAppsTitle => '除外したアプリ';

  @override
  String get settingsExcludedAppsEmpty =>
      '除外したアプリはありません。ダッシュボードでアプリを長押しすると、追跡から除外できます。';

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
  String get settingsClearDataDialogTitle => 'ローカルデータを削除しますか？';

  @override
  String get settingsClearDataDialogBody =>
      '保存された使用セッションと設定をこの端末から削除します。言語の選択は保持されます。';

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
