import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/restriction_rule.dart';
import '../../domain/models/usage_item.dart';

final usageBubbleViewModelProvider =
    StateNotifierProvider.autoDispose<UsageBubbleViewModel, UsageBubbleState>(
      (ref) => UsageBubbleViewModel(),
    );

class UsageBubbleState {
  const UsageBubbleState({this.selectedItemId});

  final String? selectedItemId;

  UsageBubbleState copyWith({
    String? selectedItemId,
    bool clearSelection = false,
  }) {
    return UsageBubbleState(
      selectedItemId: clearSelection
          ? null
          : selectedItemId ?? this.selectedItemId,
    );
  }
}

class UsageBubbleViewModel extends StateNotifier<UsageBubbleState> {
  UsageBubbleViewModel() : super(const UsageBubbleState());

  static const nearLimitThreshold = 0.85;

  List<UsageItem> itemsFor(List<AppUsageSummary> summaries) {
    final items = summaries.map(UsageItem.fromSummary).toList()
      ..sort(
        (first, second) =>
            second.totalDurationSeconds.compareTo(first.totalDurationSeconds),
      );
    // ponytail: chart layout has 10 position slots; more bubbles just overlap.
    return items.take(10).toList();
  }

  UsageItem? selectedItemFor(List<UsageItem> items, String? selectedItemId) {
    if (selectedItemId == null) {
      return null;
    }
    for (final item in items) {
      if (item.id == selectedItemId) {
        return item;
      }
    }
    return null;
  }

  Set<String> nearLimitItemIds({
    required Iterable<AppUsageSummary> summaries,
    required Iterable<RestrictionRule> rules,
    required DateTime now,
  }) {
    final rulesByApp = <String, List<RestrictionRule>>{};
    for (final rule in rules) {
      rulesByApp.putIfAbsent(rule.appKey, () => []).add(rule);
    }

    return {
      for (final summary in summaries)
        if (_isNearLimit(summary, rulesByApp[summary.appKey] ?? const [], now))
          summary.appKey,
    };
  }

  bool _isNearLimit(
    AppUsageSummary summary,
    List<RestrictionRule> rules,
    DateTime now,
  ) {
    if (rules.any((rule) => rule.blocksAt(now, summary.totalDurationSeconds))) {
      return false;
    }
    for (final rule in rules) {
      if (rule.type != RestrictionRuleType.dailyLimit) {
        continue;
      }
      final limitMinutes = rule.limitMinutes;
      if (limitMinutes == null || limitMinutes <= 0) {
        continue;
      }
      final progress = summary.totalDurationSeconds / (limitMinutes * 60);
      if (progress >= nearLimitThreshold && progress < 1) {
        return true;
      }
    }
    return false;
  }

  void selectItem(UsageItem item) {
    state = state.copyWith(selectedItemId: item.id);
  }

  void clearSelection() {
    state = state.copyWith(clearSelection: true);
  }
}
