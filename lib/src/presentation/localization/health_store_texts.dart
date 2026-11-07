import '../../../l10n/generated/app_localizations.dart';

/// The workout-import texts that name the health store: Health Connect on
/// Android, Apple Health on iOS (`PlatformCapabilities.appleHealth`). Texts
/// that name no store are used directly from [AppLocalizations].
class HealthStoreTexts {
  const HealthStoreTexts(this._l, {required this.appleHealth});

  final AppLocalizations _l;
  final bool appleHealth;

  String get title => appleHealth ? _l.appleHealthTitle : _l.healthConnectTitle;

  String get intro => appleHealth ? _l.appleHealthIntro : _l.healthConnectIntro;

  String get dataBody =>
      appleHealth ? _l.appleHealthDataBody : _l.healthConnectDataBody;

  String get autoImportBody => appleHealth
      ? _l.appleHealthAutoImportBody
      : _l.healthConnectAutoImportBody;

  String get outcomeUnavailable => appleHealth
      ? _l.appleHealthOutcomeUnavailable
      : _l.healthConnectOutcomeUnavailable;

  String get outcomePermission => appleHealth
      ? _l.appleHealthOutcomePermission
      : _l.healthConnectOutcomePermission;

  String get unavailable =>
      appleHealth ? _l.appleHealthUnavailable : _l.healthConnectUnavailable;

  String get manage =>
      appleHealth ? _l.appleHealthManage : _l.healthConnectManage;

  String get offNote =>
      appleHealth ? _l.appleHealthOffNote : _l.healthConnectOffNote;

  String get deleteBody =>
      appleHealth ? _l.appleHealthDeleteBody : _l.healthConnectDeleteBody;

  String get onboardingBody =>
      appleHealth ? _l.onboardingAppleHealthBody : _l.onboardingHealthBody;

  String get onboardingConnect => appleHealth
      ? _l.onboardingAppleHealthConnect
      : _l.onboardingHealthConnect;

  String get onboardingConnected => appleHealth
      ? _l.onboardingAppleHealthConnected
      : _l.onboardingHealthConnected;

  String get clearDataNote => appleHealth
      ? _l.settingsClearDataAppleHealth
      : _l.settingsClearDataHealth;
}
