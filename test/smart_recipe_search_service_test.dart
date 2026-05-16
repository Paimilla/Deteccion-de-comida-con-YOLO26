import 'package:flutter_test/flutter_test.dart';

import 'package:nutrifoto_app/infrastructure/services/smart_recipe_search_service.dart';

void main() {
  group('SmartRecipeSearchService', () {
    test('expandSearchTerms expands "desayuno chileno" to multiple ingredients', () {
      final terms = SmartRecipeSearchService.expandSearchTerms('desayuno chileno');
      
      expect(terms, isNotEmpty);
      expect(terms.contains('desayuno chileno'), true);
      expect(terms.any((t) => ['huevo', 'pan', 'poroto', 'tomate'].contains(t)), true);
    });

    test('expandSearchTerms includes synonyms for known foods', () {
      final terms = SmartRecipeSearchService.expandSearchTerms('pollo');
      
      expect(terms, isNotEmpty);
      expect(terms.contains('pollo'), true);
      expect(terms.any((t) => ['pechuga', 'ala', 'muslo', 'chicken', 'ave'].contains(t)), true);
    });

    test('expandSearchTerms returns at least the original term', () {
      final terms = SmartRecipeSearchService.expandSearchTerms('manzana');
      
      expect(terms, isNotEmpty);
      expect(terms.first, 'manzana');
    });

    test('getBaseIngredientsForMealSlot returns ingredients for known meals', () {
      final breakfast = SmartRecipeSearchService.getBaseIngredientsForMealSlot('desayuno');
      expect(breakfast, isNotEmpty);
      expect(breakfast, contains('huevo'));

      final lunch = SmartRecipeSearchService.getBaseIngredientsForMealSlot('almuerzo');
      expect(lunch, isNotEmpty);
      expect(lunch, contains('arroz'));
    });

    test('isKnownCategory recognizes meal categories', () {
      expect(SmartRecipeSearchService.isKnownCategory('desayuno'), true);
      expect(SmartRecipeSearchService.isKnownCategory('almuerzo'), true);
      expect(SmartRecipeSearchService.isKnownCategory('random term'), false);
    });
  });
}
