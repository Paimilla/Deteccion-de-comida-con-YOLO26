import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifoto_app/application/usecases/insights_usecases.dart';
import 'package:nutrifoto_app/domain/models/tracking_models.dart';
import 'package:nutrifoto_app/domain/models/nutrition_models.dart';

void main() {
  group('InsightsUseCases', () {
    final insightsUseCases = InsightsUseCases();

    test('caloriesByMeal calculates correctly for empty summary', () {
      final summary = DailySummary(
        day: DateTime.now(),
        entries: [],
        goals: const NutritionGoals(kcal: 2200, proteinG: 110, carbsG: 275, fatG: 61),
        hydrationMl: 0,
      );

      final result = insightsUseCases.caloriesByMeal(summary);

      expect(result[MealSlot.desayuno], 0);
      expect(result[MealSlot.almuerzo], 0);
      expect(result[MealSlot.cena], 0);
      expect(result[MealSlot.once], 0);
      expect(result[MealSlot.snack], 0);
    });

    test('completionPct returns 0 when goal is 0 or negative', () {
      expect(insightsUseCases.completionPct(100, 0), 0);
      expect(insightsUseCases.completionPct(100, -1), 0);
    });

    test('completionPct returns 0 when total is negative', () {
      expect(insightsUseCases.completionPct(-100, 2200), 0);
    });

    test('completionPct returns correct value when total < goal', () {
      final result = insightsUseCases.completionPct(1100, 2200);
      expect(result, 0.5);
    });

    test('completionPct clamps to 1.0 when total > goal', () {
      final result = insightsUseCases.completionPct(3000, 2200);
      expect(result, 1.0);
    });

    test('hydrationGoalPct calculates correctly', () {
      expect(insightsUseCases.hydrationGoalPct(hydrationMl: 1400, goalMl: 2800), 50);
      expect(insightsUseCases.hydrationGoalPct(hydrationMl: 2800, goalMl: 2800), 100);
      expect(insightsUseCases.hydrationGoalPct(hydrationMl: 2900, goalMl: 2800), 100);
      expect(insightsUseCases.hydrationGoalPct(hydrationMl: 0, goalMl: 2800), 0);
    });

    test('hydrationGoalPct handles invalid goal', () {
      expect(insightsUseCases.hydrationGoalPct(hydrationMl: 100, goalMl: 0), 0);
      expect(insightsUseCases.hydrationGoalPct(hydrationMl: 100, goalMl: -1), 0);
    });

    test('streakDays calculates consecutive days correctly', () {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));

      final streak = insightsUseCases.streakDays([today, yesterday, twoDaysAgo]);
      expect(streak, 3);
    });

    test('streakDays breaks on non-consecutive day', () {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final threeDaysAgo = today.subtract(const Duration(days: 3));

      final streak = insightsUseCases.streakDays([today, yesterday, threeDaysAgo]);
      expect(streak, 2);
    });

    test('streakDays returns 0 for empty list', () {
      final streak = insightsUseCases.streakDays([]);
      expect(streak, 0);
    });

    test('streakDays returns 1 for single day', () {
      final today = DateTime.now();
      final streak = insightsUseCases.streakDays([today]);
      expect(streak, 1);
    });
  });
}
