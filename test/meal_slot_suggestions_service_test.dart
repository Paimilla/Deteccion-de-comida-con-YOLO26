import 'package:flutter_test/flutter_test.dart';

import 'package:nutrifoto_app/domain/models/tracking_models.dart';
import 'package:nutrifoto_app/infrastructure/services/meal_slot_suggestions_service.dart';

void main() {
  group('MealSlotSuggestionsService', () {
    test('getSuggestionsForMealSlot returns suggestions for desayuno', () {
      final suggestions = MealSlotSuggestionsService.getSuggestionsForMealSlot(MealSlot.desayuno);
      
      expect(suggestions, isNotEmpty);
      expect(suggestions.contains('desayuno chileno'), true);
      expect(suggestions.contains('huevos fritos'), true);
    });

    test('getSuggestionsForMealSlot returns suggestions for almuerzo', () {
      final suggestions = MealSlotSuggestionsService.getSuggestionsForMealSlot(MealSlot.almuerzo);
      
      expect(suggestions, isNotEmpty);
      expect(suggestions.contains('almuerzo chileno'), true);
      expect(suggestions.contains('pollo a la plancha'), true);
    });

    test('getQuickSuggestionsForMealSlot returns emoji + name pairs', () {
      final suggestions = MealSlotSuggestionsService.getQuickSuggestionsForMealSlot(MealSlot.desayuno);
      
      expect(suggestions, isNotEmpty);
      // Should contain emoji
      expect(suggestions.any((s) => s.contains('🥚')), true);
    });

    test('getSearchQueryForMealSlot returns specific queries', () {
      expect(
        MealSlotSuggestionsService.getSearchQueryForMealSlot(MealSlot.desayuno),
        'healthy breakfast eggs avocado fruit',
      );
      expect(
        MealSlotSuggestionsService.getSearchQueryForMealSlot(MealSlot.almuerzo),
        'healthy lunch chicken salmon salad',
      );
      expect(
        MealSlotSuggestionsService.getSearchQueryForMealSlot(MealSlot.cena),
        'healthy dinner soup grilled vegetables',
      );
    });

    test('getDescriptionForMealSlot returns user-friendly descriptions', () {
      final desc = MealSlotSuggestionsService.getDescriptionForMealSlot(MealSlot.desayuno);
      
      expect(desc, isNotEmpty);
      expect(desc.toLowerCase().contains('energía') || desc.toLowerCase().contains('día'), true);
    });

    test('getThemeForMealSlot returns theme data with emoji and colors', () {
      final theme = MealSlotSuggestionsService.getThemeForMealSlot(MealSlot.desayuno);
      
      expect(theme.containsKey('emoji'), true);
      expect(theme.containsKey('color_primary'), true);
      expect(theme.containsKey('color_secondary'), true);
      expect(theme['emoji'], '🌅');
    });

    test('getInitialSearchForMealSlot returns first suggestion', () {
      final query = MealSlotSuggestionsService.getInitialSearchForMealSlot(MealSlot.almuerzo);
      
      expect(query, 'almuerzo chileno');
    });

    test('shouldShowSuggestions returns true when no results', () {
      expect(
        MealSlotSuggestionsService.shouldShowSuggestions(
          false,  // hasSearchResults
          false,  // isLoading
          [],     // currentResults
        ),
        true,
      );
    });

    test('shouldShowSuggestions returns false when loading', () {
      expect(
        MealSlotSuggestionsService.shouldShowSuggestions(
          false,  // hasSearchResults
          true,   // isLoading
          [],     // currentResults
        ),
        false,
      );
    });

    test('shouldShowSuggestions returns false when has results', () {
      expect(
        MealSlotSuggestionsService.shouldShowSuggestions(
          false,  // hasSearchResults
          false,  // isLoading
          ['item1', 'item2'],  // currentResults
        ),
        false,
      );
    });

    test('All meal slots have suggestions', () {
      for (final slot in MealSlot.values) {
        final suggestions = MealSlotSuggestionsService.getSuggestionsForMealSlot(slot);
        expect(suggestions, isNotEmpty, reason: 'Missing suggestions for $slot');
        
        final query = MealSlotSuggestionsService.getSearchQueryForMealSlot(slot);
        expect(query, isNotEmpty, reason: 'Missing query for $slot');
        
        final description = MealSlotSuggestionsService.getDescriptionForMealSlot(slot);
        expect(description, isNotEmpty, reason: 'Missing description for $slot');
        
        final theme = MealSlotSuggestionsService.getThemeForMealSlot(slot);
        expect(theme, isNotEmpty, reason: 'Missing theme for $slot');
      }
    });
  });
}
