import '../../domain/models/tracking_models.dart';
import '../../domain/repositories/tracking_repository.dart';

class HistoryUseCases {
  final TrackingRepository repository;

  HistoryUseCases(this.repository);

  Future<List<DailySummary>> lastNDays(int days) async {
    final today = DateTime.now();
    final summaries = <DailySummary>[];

    for (var i = 0; i < days; i++) {
      final day = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: i));
      final entries = await repository.getEntriesForDay(day);
      final goals = await repository.getGoals();
      final hydration = await repository.getHydrationForDay(day);
      summaries.add(
        DailySummary(
          day: day,
          entries: entries,
          goals: goals,
          hydrationMl: hydration,
        ),
      );
    }

    return summaries;
  }

  Future<Map<String, double>> weeklyAverages(DateTime referenceDay) async {
    final start = DateTime(referenceDay.year, referenceDay.month, referenceDay.day)
        .subtract(const Duration(days: 6));
    final end = DateTime(referenceDay.year, referenceDay.month, referenceDay.day);

    final entries = await repository.getEntriesBetween(start, end);
    if (entries.isEmpty) {
      return {
        'kcal_avg': 0,
        'protein_avg': 0,
        'carbs_avg': 0,
        'fat_avg': 0,
      };
    }

    const days = 7.0;
    final kcal = entries.fold<double>(0, (s, e) => s + e.food.nutrition.kcal);
    final protein =
        entries.fold<double>(0, (s, e) => s + e.food.nutrition.proteinG);
    final carbs =
        entries.fold<double>(0, (s, e) => s + e.food.nutrition.carbsG);
    final fat = entries.fold<double>(0, (s, e) => s + e.food.nutrition.fatG);

    return {
      'kcal_avg': kcal / days,
      'protein_avg': protein / days,
      'carbs_avg': carbs / days,
      'fat_avg': fat / days,
    };
  }
}
