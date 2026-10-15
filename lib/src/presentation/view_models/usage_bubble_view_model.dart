import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/restriction_rule.dart';
import '../../domain/models/usage_item.dart';

final usageBubbleViewModelProvider =
    StateNotifierProvider.autoDispose<UsageBubbleViewModel, UsageBubbleState>(
      (ref) => UsageBubbleViewModel(),
    );

class UsageBubbleState {
  const UsageBubbleState({
    this.selectedItemId,
    this.selectedCategory,
    this.listExpanded = false,
  });

  final String? selectedItemId;
  final UsageCategory? selectedCategory;
  final bool listExpanded;

  UsageBubbleState copyWith({
    String? selectedItemId,
    bool clearSelection = false,
  }) {
    return UsageBubbleState(
      selectedItemId: clearSelection
          ? null
          : selectedItemId ?? this.selectedItemId,
      selectedCategory: selectedCategory,
      listExpanded: listExpanded,
    );
  }
}

class UsageBubbleViewModel extends StateNotifier<UsageBubbleState> {
  UsageBubbleViewModel() : super(const UsageBubbleState());

  static const nearLimitThreshold = 0.85;

  /// Apps shown in the chart and, until expanded, in the current list.
  static const topAppCount = 10;

  List<UsageItem> itemsFor(
    List<AppUsageSummary> summaries, {
    Map<String, UsageCategory> categoryOverrides = const {},
  }) {
    final items =
        summaries
            .map(
              (summary) => UsageItem.fromSummary(
                summary,
                categoryOverrides: categoryOverrides,
              ),
            )
            .toList()
          ..sort(
            (first, second) => second.totalDurationSeconds.compareTo(
              first.totalDurationSeconds,
            ),
          );
    // ponytail: chart layout has 10 position slots; more bubbles just overlap.
    return items.take(topAppCount).toList();
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

  void selectCategory(UsageCategory? category) {
    state = UsageBubbleState(
      selectedItemId: state.selectedItemId,
      selectedCategory: category,
    );
  }

  void toggleListExpanded() {
    state = UsageBubbleState(
      selectedItemId: state.selectedItemId,
      selectedCategory: state.selectedCategory,
      listExpanded: !state.listExpanded,
    );
  }

  void collapseList() {
    if (state.listExpanded) toggleListExpanded();
  }
}
