import '../../domain/models/tracking_models.dart';

class InsightsUseCases {
  Map<MealSlot, double> caloriesByMeal(DailySummary summary) {
    final output = <MealSlot, double>{
      MealSlot.desayuno: 0,
      MealSlot.almuerzo: 0,
      MealSlot.cena: 0,
      MealSlot.once: 0,
      MealSlot.snack: 0,
    };

    for (final e in summary.entries) {
      output[e.mealSlot] = (output[e.mealSlot] ?? 0) + e.food.nutrition.kcal;
    }
    return output;
  }

  double completionPct(double total, double goal) {
    if (goal <= 0) {
      return 0;
    }
    final ratio = total / goal;
    if (ratio < 0) {
      return 0;
    }
    if (ratio > 1) {
      return 1;
    }
    return ratio;
  }

  int hydrationGoalPct({required int hydrationMl, required int goalMl}) {
    if (goalMl <= 0) {
      return 0;
    }
    final pct = ((hydrationMl / goalMl) * 100).round();
    if (pct < 0) {
      return 0;
    }
    if (pct > 100) {
      return 100;
    }
    return pct;
  }

  int streakDays(List<DateTime> completedDays) {
    if (completedDays.isEmpty) {
      return 0;
    }

    final normalized = completedDays
        .map((d) => DateTime(d.year, d.month, d.day))
         .toSet()
         .toList()
       ..sort((a, b) => b.compareTo(a));

    var streak = 0;
    var cursor = DateTime(
      normalized.first.year,
      normalized.first.month,
      normalized.first.day,
    );

    for (final day in normalized) {
      if (day == cursor) {
        streak += 1;
        cursor = cursor.subtract(const Duration(days: 1));
      } else if (day.isBefore(cursor)) {
        break;
      }
    }

    return streak;
  }
}
