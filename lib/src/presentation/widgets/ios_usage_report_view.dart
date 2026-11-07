import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/screen_time_channel.dart';
import '../localization/app_localizations_x.dart';
import '../providers.dart';
import '../screens/restriction_editor_sheet.dart';

/// The report scenes of the iOS report extension (`UsageReportKind` in
/// ios/FocusTraceKit/UsageReportModels.swift; the names are the
/// DeviceActivityReport contexts).
enum IosUsageReportKind {
  /// Day dial, pickups, notifications, then the per-app list.
  today,

  /// The day's use per hour as bars.
  hourly,

  /// Seven days: totals, bars, most used apps.
  week,

  /// Thirty days: totals, bars, most used apps.
  month,

  /// One picked selection over a range.
  appDetail,
}

/// The span of a report (`UsageReportRange` in Swift).
enum IosUsageReportRange { today, week, month }

/// Shows a native iOS usage report (platform view `focustrace/usage_report`,
/// Runner/UsageReportView.swift). iOS keeps usage numbers inside its report
/// extension, so Flutter only says which report, period and selection to draw
/// and gives it a fixed height: the native view cannot tell Flutter its size,
/// and it does not scroll, so every report is laid out to fit [heightFor].
///
/// Anywhere but iOS (including widget tests) it draws an empty box of the
/// same size, so layouts can be tested.
class IosUsageReportView extends ConsumerWidget {
  const IosUsageReportView({
    required this.kind,
    required this.date,
    this.range,
    this.selectionId,
    super.key,
  });

  final IosUsageReportKind kind;

  /// The last day of the period.
  final DateTime date;

  /// Defaults to the kind's own (today for today/hourly/appDetail).
  final IosUsageReportRange? range;

  /// A stored picker selection to report on (appDetail).
  final String? selectionId;

  IosUsageReportRange get effectiveRange =>
      range ??
      switch (kind) {
        IosUsageReportKind.week => IosUsageReportRange.week,
        IosUsageReportKind.month => IosUsageReportRange.month,
        _ => IosUsageReportRange.today,
      };

  /// Heights the SwiftUI layouts in ios/FocusTraceReport/ReportViews.swift
  /// are made to fit (lists capped: today 10 apps, week/month 8, appDetail 6;
  /// Dynamic Type capped at Large). Change both together.
  static double heightFor(IosUsageReportKind kind, IosUsageReportRange range) {
    return switch (kind) {
      IosUsageReportKind.today => 1170,
      IosUsageReportKind.hourly => 230,
      IosUsageReportKind.week || IosUsageReportKind.month => 920,
      IosUsageReportKind.appDetail =>
        range == IosUsageReportRange.today ? 880 : 820,
    };
  }

  Map<String, Object?> creationParams(Brightness brightness) => {
    'context': kind.name,
    'range': effectiveRange.name,
    'date': DateTime(date.year, date.month, date.day).millisecondsSinceEpoch,
    if (selectionId != null) 'selectionId': selectionId,
    'dark': brightness == Brightness.dark,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final height = heightFor(kind, effectiveRange);
    final params = creationParams(Theme.of(context).brightness);
    final child = kIsWeb || defaultTargetPlatform != TargetPlatform.iOS
        ? const SizedBox.expand()
        : UiKitView(
            // New parameters are a new native report.
            key: ValueKey('usage-report-${params.values.join('|')}'),
            viewType: 'focustrace/usage_report',
            creationParams: params,
            creationParamsCodec: const StandardMessageCodec(),
          );
    return Column(
      children: [
        // The extension reads its texts from the App Group; keep them in the
        // app's language.
        const _ReportStringsSync(),
        SizedBox(
          key: ValueKey('ios-usage-report-${kind.name}'),
          height: height,
          width: double.infinity,
          child: child,
        ),
      ],
    );
  }
}

/// Sends the native texts (block screen and reports) once per locale; a send
/// that failed is tried again by the next report built.
class _ReportStringsSync extends ConsumerStatefulWidget {
  const _ReportStringsSync();

  @override
  ConsumerState<_ReportStringsSync> createState() => _ReportStringsSyncState();
}

class _ReportStringsSyncState extends ConsumerState<_ReportStringsSync> {
  static Locale? _sent;
  static Locale? _sending;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (locale == _sent || locale == _sending) return;
    _sending = locale;
    syncShieldStrings(context, ref).then((sent) {
      if (_sending == locale) _sending = null;
      if (sent) _sent = locale;
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// A native report once Screen Time is allowed; until then a card asking for
/// it (iOS shows no usage without it).
class IosUsageReportGate extends ConsumerWidget {
  const IosUsageReportGate({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(screenTimeAuthorizationProvider);
    if (status == ScreenTimeAuthorizationStatus.approved) {
      return Column(children: children);
    }
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('ios-usage-screen-time-card'),
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.screenTimeAccessTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(context.l10n.iosUsageAccessBody),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () =>
                  ref.read(screenTimeAuthorizationProvider.notifier).request(),
              child: Text(context.l10n.onboardingAllow),
            ),
          ],
        ),
      ),
    );
  }
}
