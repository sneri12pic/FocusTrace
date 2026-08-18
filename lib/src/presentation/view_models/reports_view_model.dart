import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/services/report_generation_service.dart';
import '../../domain/models/usage_report.dart';
import '../../domain/repositories/report_repository.dart';

class ReportsState {
  const ReportsState({
    this.period = UsageReportPeriod.weekly,
    this.report,
    this.isLoading = false,
    this.errorMessage,
  });

  final UsageReportPeriod period;
  final UsageReport? report;
  final bool isLoading;
  final String? errorMessage;

  ReportsState copyWith({
    UsageReportPeriod? period,
    UsageReport? report,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ReportsState(
      period: period ?? this.period,
      report: report ?? this.report,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class ReportsViewModel extends StateNotifier<ReportsState> {
  ReportsViewModel({
    required ReportRepository repository,
    ReportGenerationService generationService = const ReportGenerationService(),
    DateTime Function()? now,
  }) : _repository = repository,
       _generationService = generationService,
       _now = now ?? DateTime.now,
       super(const ReportsState());

  final ReportRepository _repository;
  final ReportGenerationService _generationService;
  final DateTime Function() _now;
  int _generation = 0;

  Future<void> load({UsageReportPeriod? period}) async {
    final selectedPeriod = period ?? state.period;
    final generation = ++_generation;
    state = state.copyWith(
      period: selectedPeriod,
      isLoading: true,
      clearError: true,
    );
    final now = _now();
    final from = selectedPeriod.startDate(now);
    final to = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    try {
      final source = await _repository.loadSourceData(from, to);
      if (generation != _generation) {
        return;
      }
      state = ReportsState(
        period: selectedPeriod,
        report: _generationService.generate(
          period: selectedPeriod,
          now: now,
          dailyUsage: source.dailyUsage,
          intervals: source.intervals,
          restrictionEvents: source.restrictionEvents,
        ),
      );
    } catch (error) {
      if (generation == _generation) {
        state = ReportsState(
          period: selectedPeriod,
          errorMessage: error.toString(),
        );
      }
    }
  }

  Future<void> selectPeriod(UsageReportPeriod period) {
    if (period == state.period && state.report != null) {
      return Future<void>.value();
    }
    return load(period: period);
  }
}
