import 'package:flutter/material.dart';

import '../../data/datasources/screen_time_channel.dart';
import '../localization/app_localizations_x.dart';
import '../widgets/ios_usage_report_view.dart';
import '../widgets/selection_icons.dart';

/// iOS usage details of one picked group of apps (an `ios-sel:` rule or
/// routine member): the Screen Time report extension draws the numbers,
/// filtered to the stored selection; Flutter keeps the title, the group's
/// icons and the range selector. It is reached from restriction rules and
/// routine members, because a tap inside a native report cannot navigate
/// Flutter.
class IosSelectionUsageScreen extends StatefulWidget {
  const IosSelectionUsageScreen({
    required this.appKey,
    required this.appName,
    super.key,
  });

  final String appKey;
  final String appName;

  @override
  State<IosSelectionUsageScreen> createState() =>
      _IosSelectionUsageScreenState();
}

class _IosSelectionUsageScreenState extends State<IosSelectionUsageScreen> {
  var _range = IosUsageReportRange.today;

  @override
  Widget build(BuildContext context) {
    final selectionId = iosSelectionId(widget.appKey);
    final theme = Theme.of(context);
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: Text(widget.appName)),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('ios-selection-usage-scroll-view'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Row(
              children: [
                SelectionIcons(
                  appKey: widget.appKey,
                  appName: widget.appName,
                  size: 36,
                  maxIcons: 4,
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<IosUsageReportRange>(
              key: const ValueKey('ios-usage-range-selector'),
              segments: [
                ButtonSegment(
                  value: IosUsageReportRange.today,
                  label: Text(context.l10n.dashboardDayToday),
                ),
                ButtonSegment(
                  value: IosUsageReportRange.week,
                  label: Text(context.l10n.usageDetailsPeriodSevenDays),
                ),
                ButtonSegment(
                  value: IosUsageReportRange.month,
                  label: Text(context.l10n.usageDetailsPeriodMonth),
                ),
              ],
              selected: {_range},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  setState(() => _range = selection.single),
            ),
            const SizedBox(height: 16),
            if (selectionId == null)
              // Only picked groups have Screen Time usage to show.
              Text(
                context.l10n.iosReportNoData,
                style: theme.textTheme.bodyMedium,
              )
            else
              IosUsageReportGate(
                children: [
                  IosUsageReportView(
                    kind: IosUsageReportKind.appDetail,
                    date: DateTime(now.year, now.month, now.day),
                    range: _range,
                    selectionId: selectionId,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
