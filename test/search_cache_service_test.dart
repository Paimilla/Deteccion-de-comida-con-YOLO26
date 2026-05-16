import 'package:flutter_test/flutter_test.dart';

import 'package:nutrifoto_app/infrastructure/services/search_cache_service.dart';

void main() {
  group('SearchCacheService', () {
    late SearchCacheService cacheService;

    setUp(() {
      cacheService = SearchCacheService();
    });

    test('setTranslation and getTranslation store and retrieve translations', () {
      cacheService.setTranslation('pollo', 'chicken');
      
      expect(cacheService.getTranslation('pollo'), 'chicken');
    });

    test('setRecipeSearch and getRecipeSearch store and retrieve searches', () {
      final results = ['pollo grillado', 'pechuga a la plancha', 'pollo con arroz'];
      cacheService.setRecipeSearch('pollo', results);
      
      final retrieved = cacheService.getRecipeSearch('pollo');
      expect(retrieved, isNotEmpty);
      expect(retrieved?.length, 3);
    });

    test('getRecipeSearch returns null for missing keys', () {
      expect(cacheService.getRecipeSearch('non_existent'), null);
    });

    test('setDescriptions and getDescriptions work correctly', () {
      final descriptions = ['Pollo tierno | Delicioso', 'Arroz blanco | Nutritivo'];
      cacheService.setDescriptions('pollo_batch', descriptions);
      
      final retrieved = cacheService.getDescriptions('pollo_batch');
      expect(retrieved?.length, 2);
    });

    test('clearAll removes all cached data', () {
      cacheService.setTranslation('pollo', 'chicken');
      cacheService.setRecipeSearch('desayuno', ['huevo', 'pan']);
      
      cacheService.clearAll();
      
      expect(cacheService.getTranslation('pollo'), null);
      expect(cacheService.getRecipeSearch('desayuno'), null);
    });

    test('getStats returns correct cache sizes', () {
      cacheService.setTranslation('pollo', 'chicken');
      cacheService.setRecipeSearch('desayuno', ['huevo']);
      cacheService.setDescriptions('batch1', ['desc1', 'desc2']);
      
      final stats = cacheService.getStats();
      expect(stats['translations'], 1);
      expect(stats['searches'], 1);
      expect(stats['descriptions'], 1);
    });
  });
}
