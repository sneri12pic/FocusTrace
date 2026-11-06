import 'usage_session.dart';

/// What the running platform lets FocusTrace do, so screens ask about a
/// capability instead of comparing [UsagePlatform] values.
///
/// iOS describes the Screen Time based app it is being ported to. Until its
/// native side exists, providers still give iOS the unsupported data sources.
class PlatformCapabilities {
  const PlatformCapabilities({
    this.usageNumbersInFlutter = false,
    this.usageAccessPermission = false,
    this.overlayPermission = false,
    this.notificationsPermission = false,
    this.screenTimeAuthorization = false,
    this.installedAppList = false,
    this.nativeAppPicker = false,
    this.appBlocking = false,
    this.activeWindowTracking = false,
    this.osHistoryImport = false,
    this.dataTransfer = false,
    this.workoutsImport = false,
    this.cloudSync = false,
    this.platformLocale = false,
  });

  factory PlatformCapabilities.forPlatform(UsagePlatform platform) {
    return switch (platform) {
      UsagePlatform.android => android,
      UsagePlatform.windows => windows,
      UsagePlatform.ios => ios,
      UsagePlatform.macos ||
      UsagePlatform.linux ||
      UsagePlatform.unsupported => none,
    };
  }

  static const android = PlatformCapabilities(
    usageNumbersInFlutter: true,
    usageAccessPermission: true,
    overlayPermission: true,
    notificationsPermission: true,
    installedAppList: true,
    appBlocking: true,
    osHistoryImport: true,
    dataTransfer: true,
    workoutsImport: true,
    cloudSync: true,
    platformLocale: true,
  );

  static const windows = PlatformCapabilities(
    usageNumbersInFlutter: true,
    activeWindowTracking: true,
  );

  /// Usage is drawn by a native DeviceActivityReport extension and apps are
  /// opaque tokens chosen in Apple's picker, so Flutter never sees numbers,
  /// names or an installed-app list.
  static const ios = PlatformCapabilities(
    screenTimeAuthorization: true,
    nativeAppPicker: true,
    appBlocking: true,
  );

  static const none = PlatformCapabilities();

  /// Per-app usage totals reach Flutter and can be listed and charted.
  final bool usageNumbersInFlutter;

  /// Usage numbers need Android's Usage Access setting.
  final bool usageAccessPermission;

  /// Blocking needs permission to draw over other apps.
  final bool overlayPermission;

  /// Restriction alerts need the runtime notifications permission.
  final bool notificationsPermission;

  /// One Screen Time authorization covers usage and blocking.
  final bool screenTimeAuthorization;

  /// Flutter can list installed apps and look up their names and icons.
  final bool installedAppList;

  /// Apps are chosen in a native system picker rather than a Flutter list.
  final bool nativeAppPicker;

  /// Restriction rules are enforced by blocking the app.
  final bool appBlocking;

  /// Usage is recorded by sampling the foreground window while the app runs,
  /// which also yields per-session rows.
  final bool activeWindowTracking;

  /// Usage history the OS retained before installation can be imported.
  final bool osHistoryImport;

  /// Backups can be exported to and imported from a document.
  final bool dataTransfer;

  /// Workouts can be imported from the platform health store.
  final bool workoutsImport;

  /// The platform side of optional cloud sync (scheduling, execution) exists.
  final bool cloudSync;

  /// The app language can be mirrored to the OS per-app locale setting.
  final bool platformLocale;
}
