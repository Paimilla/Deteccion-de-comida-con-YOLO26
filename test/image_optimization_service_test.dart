import 'package:flutter_test/flutter_test.dart';

import 'package:nutrifoto_app/infrastructure/services/image_optimization_service.dart';

void main() {
  group('ImageOptimizationService', () {
    test('optimizeImageUrl returns empty string for null URL', () {
      expect(ImageOptimizationService.optimizeImageUrl(null), '');
    });

    test('optimizeImageUrl returns empty string for empty URL', () {
      expect(ImageOptimizationService.optimizeImageUrl(''), '');
    });

    test('optimizeImageUrl optimizes Unsplash URLs', () {
      const url = 'https://images.unsplash.com/photo-1532550907401-a500c9a57435?q=80&w=400';
      final optimized = ImageOptimizationService.optimizeImageUrl(url);

      expect(optimized, contains('?w=400'));
      expect(optimized, contains('q=80'));
      expect(optimized, contains('auto=format'));
    });

    test('optimizeImageUrl removes old parameters before adding new', () {
      const url = 'https://images.unsplash.com/photo-1532550907401-a500c9a57435?old=param';
      final optimized = ImageOptimizationService.optimizeImageUrl(url);

      expect(optimized, contains('?w=400'));
      expect(optimized, isNot(contains('?old=param')));
    });

    test('getThumbnailUrl returns smaller optimized URL', () {
      const url = 'https://images.unsplash.com/photo-123456?q=80';
      final thumbnail = ImageOptimizationService.getThumbnailUrl(url, size: 200);

      expect(thumbnail, contains('w=200'));
      expect(thumbnail, contains('q=75'));
    });

    test('getFullImageUrl returns larger optimized URL', () {
      const url = 'https://images.unsplash.com/photo-123456?q=80';
      final full = ImageOptimizationService.getFullImageUrl(url, width: 600);

      expect(full, contains('w=600'));
      expect(full, contains('q=90'));
    });

    test('getOptimalImageWidth returns correct width for screen size', () {
      expect(ImageOptimizationService.getOptimalImageWidth(300), 300);
      expect(ImageOptimizationService.getOptimalImageWidth(500), 400);
      expect(ImageOptimizationService.getOptimalImageWidth(700), 600);
      expect(ImageOptimizationService.getOptimalImageWidth(1000), 800);
    });

    test('isValidImageUrl validates HTTP URLs', () {
      expect(
        ImageOptimizationService.isValidImageUrl('https://example.com/image.jpg'),
        true,
      );
      expect(
        ImageOptimizationService.isValidImageUrl('http://example.com/image.jpg'),
        true,
      );
    });

    test('isValidImageUrl rejects invalid URLs', () {
      expect(ImageOptimizationService.isValidImageUrl(null), false);
      expect(ImageOptimizationService.isValidImageUrl(''), false);
      expect(ImageOptimizationService.isValidImageUrl('not-a-url'), false);
      expect(ImageOptimizationService.isValidImageUrl('ftp://example.com'), false);
    });

    test('getPlaceholderColorForMealType returns correct colors', () {
      expect(ImageOptimizationService.getPlaceholderColorForMealType('desayuno'), '#FFA726');
      expect(ImageOptimizationService.getPlaceholderColorForMealType('almuerzo'), '#66BB6A');
      expect(ImageOptimizationService.getPlaceholderColorForMealType('cena'), '#5C6BC0');
      expect(ImageOptimizationService.getPlaceholderColorForMealType('once'), '#AB47BC');
      expect(ImageOptimizationService.getPlaceholderColorForMealType('snack'), '#FF6E40');
    });

    test('getPlaceholderColorForMealType returns default for unknown types', () {
      expect(
        ImageOptimizationService.getPlaceholderColorForMealType('unknown'),
        '#8F62FF',
      );
      expect(
        ImageOptimizationService.getPlaceholderColorForMealType(null),
        '#8F62FF',
      );
    });

    test('estimateLoadTime calculates duration correctly', () {
      // 40KB at 10 Mbps should be ~32ms
      final duration = ImageOptimizationService.estimateLoadTime(
        'https://example.com/image.jpg',
        connectionSpeed: 10,
      );

      expect(duration, isNotNull);
      expect(duration.inMilliseconds, greaterThan(0));
    });

    test('estimateLoadTime returns zero for empty URL', () {
      final duration = ImageOptimizationService.estimateLoadTime(
        '',
        connectionSpeed: 10,
      );

      expect(duration, Duration.zero);
    });
  });
}
