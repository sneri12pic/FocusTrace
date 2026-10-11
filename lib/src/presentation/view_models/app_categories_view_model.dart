import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/usage_item.dart';
import '../../domain/repositories/settings_repository.dart';

class AppCategoriesViewModel
    extends StateNotifier<AsyncValue<Map<String, UsageCategory>>> {
  AppCategoriesViewModel(this._repository) : super(const AsyncLoading());

  final SettingsRepository _repository;
  bool _saving = false;

  Future<void> load() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(_repository.appCategoryOverrides);
    if (mounted) state = result;
  }

  Future<bool> save(String appKey, UsageCategory? category) async {
    final previous = state.asData?.value;
    if (previous == null || _saving || appKey.isEmpty) return false;
    _saving = true;
    try {
      final updated = Map<String, UsageCategory>.of(previous);
      if (category == null) {
        updated.remove(appKey);
      } else {
        updated[appKey] = category;
      }
      await _repository.setAppCategoryOverrides(updated);
      if (mounted) state = AsyncData(Map.unmodifiable(updated));
      return true;
    } catch (_) {
      return false;
    } finally {
      _saving = false;
    }
  }
}
