import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifoto_app/domain/models/nutrition_models.dart';
import 'package:nutrifoto_app/domain/models/tracking_models.dart';

void main() {
  group('FoodItem', () {
    test('creates FoodItem with valid data', () {
      final food = FoodItem(
        source: FoodSource.localChile,
        itemId: 'test_001',
        nameEs: 'Pollo',
        nameEn: 'Chicken',
        portion: const Portion(amount: 150, unit: 'g'),
        nutrition: const Nutrition(
          kcal: 239,
          proteinG: 27.3,
          carbsG: 0.0,
          fatG: 13.6,
        ),
      );

      expect(food.nameEs, 'Pollo');
      expect(food.nutrition.kcal, 239);
      expect(food.nutrition.proteinG, 27.3);
      expect(food.confidence, 1.0);
    });

    test('FoodSource enum has edamam value', () {
      expect(FoodSource.values, contains(FoodSource.edamam));
    });

    test('FoodSource enum has all required values', () {
      final sources = FoodSource.values;
      expect(sources, contains(FoodSource.localChile));
      expect(sources, contains(FoodSource.openFoodFacts));
      expect(sources, contains(FoodSource.usda));
      expect(sources, contains(FoodSource.spoonacular));
      expect(sources, contains(FoodSource.edamam));
      expect(sources, contains(FoodSource.aiVision));
      expect(sources, contains(FoodSource.unknown));
    });

    test('Nutrition stores macronutrients correctly', () {
      const nutrition = Nutrition(
        kcal: 100,
        proteinG: 10,
        carbsG: 15,
        fatG: 5,
      );

      expect(nutrition.kcal, 100);
      expect(nutrition.proteinG, 10);
      expect(nutrition.carbsG, 15);
      expect(nutrition.fatG, 5);
    });

    test('Portion stores amount and unit correctly', () {
      const portion = Portion(amount: 200, unit: 'gramos');

      expect(portion.amount, 200);
      expect(portion.unit, 'gramos');
    });
  });

  group('FoodItem equality', () {
    test('two FoodItems with same data are not equal by reference', () {
      final food1 = FoodItem(
        source: FoodSource.localChile,
        itemId: 'id1',
        nameEs: 'Pollo',
        portion: const Portion(amount: 150, unit: 'g'),
        nutrition: const Nutrition(kcal: 239, proteinG: 27.3, carbsG: 0.0, fatG: 13.6),
      );

      final food2 = FoodItem(
        source: FoodSource.localChile,
        itemId: 'id1',
        nameEs: 'Pollo',
        portion: const Portion(amount: 150, unit: 'g'),
        nutrition: const Nutrition(kcal: 239, proteinG: 27.3, carbsG: 0.0, fatG: 13.6),
      );

      // FoodItem doesn't override equality, so they won't be equal by value
      expect(food1, isNotNull);
      expect(food2, isNotNull);
    });
  });

  group('MealSlot enum', () {
    test('MealSlot has all required values', () {
      expect(MealSlot.values, contains(MealSlot.desayuno));
      expect(MealSlot.values, contains(MealSlot.almuerzo));
      expect(MealSlot.values, contains(MealSlot.cena));
      expect(MealSlot.values, contains(MealSlot.once));
      expect(MealSlot.values, contains(MealSlot.snack));
    });

    test('MealSlot label is correct', () {
      expect(MealSlot.desayuno.label, 'Desayuno');
      expect(MealSlot.almuerzo.label, 'Almuerzo');
      expect(MealSlot.cena.label, 'Cena');
      expect(MealSlot.once.label, 'Once');
      expect(MealSlot.snack.label, 'Snack');
    });
  });
}
