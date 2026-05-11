import 'nutrition_models.dart';

enum MealSlot {
  desayuno,
  almuerzo,
  cena,
  once,
  snack,
}

extension MealSlotX on MealSlot {
  String get label {
    switch (this) {
      case MealSlot.desayuno:
        return 'Desayuno';
      case MealSlot.almuerzo:
        return 'Almuerzo';
      case MealSlot.cena:
        return 'Cena';
      case MealSlot.once:
        return 'Once';
      case MealSlot.snack:
        return 'Snack';
    }
  }
}

class NutritionGoals {
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;

  const NutritionGoals({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });
}

class UserProfile {
  final String name;
  final String gender;
  final double weightKg;
  final double heightCm;
  final int age;
  final int exercisePerWeek;
  final DateTime createdAt;

  const UserProfile({
    required this.name,
    required this.gender,
    required this.weightKg,
    required this.heightCm,
    required this.age,
    required this.exercisePerWeek,
    required this.createdAt,
  });
}

class DiaryEntry {
  final String id;
  final DateTime timestamp;
  final MealSlot mealSlot;
  final FoodItem food;

  const DiaryEntry({
    required this.id,
    required this.timestamp,
    required this.mealSlot,
    required this.food,
  });
}

class HydrationLog {
  final DateTime timestamp;
  final int milliliters;

  const HydrationLog({required this.timestamp, required this.milliliters});
}

class DailySummary {
  final DateTime day;
  final List<DiaryEntry> entries;
  final NutritionGoals goals;
  final int hydrationMl;

  const DailySummary({
    required this.day,
    required this.entries,
    required this.goals,
    required this.hydrationMl,
  });

  double get kcalTotal =>
      entries.fold(0, (sum, e) => sum + e.food.nutrition.kcal);

  double get proteinTotal =>
      entries.fold(0, (sum, e) => sum + e.food.nutrition.proteinG);

  double get carbsTotal =>
      entries.fold(0, (sum, e) => sum + e.food.nutrition.carbsG);

  double get fatTotal =>
      entries.fold(0, (sum, e) => sum + e.food.nutrition.fatG);
}
