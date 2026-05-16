import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/models/nutrition_models.dart';

/// Curated high-quality food images from Unsplash for Chilean foods
const Map<String, String> _foodImages = {
  'arroz': 'https://images.unsplash.com/photo-1516684732162-798a0062be99?auto=format&fit=crop&q=80&w=800',
  'arvejas': 'https://images.unsplash.com/photo-1563565375-f3fdfdbefa83?auto=format&fit=crop&q=80&w=800',
  'brocoli': 'https://images.unsplash.com/photo-1459411552884-841db9b3cc2a?auto=format&fit=crop&q=80&w=800',
  'calzones_rotos': 'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?auto=format&fit=crop&q=80&w=800',
  'carne': 'https://images.unsplash.com/photo-1588168333986-5078d3ae3976?auto=format&fit=crop&q=80&w=800',
  'cazuela': 'https://images.unsplash.com/photo-1547592166-23ac45744acd?auto=format&fit=crop&q=80&w=800',
  'charquican': 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&q=80&w=800',
  'choripan': 'https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?auto=format&fit=crop&q=80&w=800',
  'completos': 'https://images.unsplash.com/photo-1619740455993-9d701c84f1b7?auto=format&fit=crop&q=80&w=800',
  'durazno': 'https://images.unsplash.com/photo-1629226182768-37f27e2e0a92?auto=format&fit=crop&q=80&w=800',
  'empanada': 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&q=80&w=800',
  'ensalada_a_la_chilena': 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&q=80&w=800',
  'huevos_fritos': 'https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&q=80&w=800',
  'humitas': 'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?auto=format&fit=crop&q=80&w=800',
  'manzana': 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?auto=format&fit=crop&q=80&w=800',
  'mote_con_huesillo': 'https://images.unsplash.com/photo-1497534446932-c925b458314e?auto=format&fit=crop&q=80&w=800',
  'naranja': 'https://images.unsplash.com/photo-1547514701-42782101795e?auto=format&fit=crop&q=80&w=800',
  'palomitas': 'https://images.unsplash.com/photo-1585735285261-5e8e3e5e0f2b?auto=format&fit=crop&q=80&w=800',
  'palta': 'https://images.unsplash.com/photo-1523049673857-eb18f1d7b578?auto=format&fit=crop&q=80&w=800',
  'papas_fritas': 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?auto=format&fit=crop&q=80&w=800',
  'pasta': 'https://images.unsplash.com/photo-1551892374-ecf8754cf8b0?auto=format&fit=crop&q=80&w=800',
  'pastel_de_choclo': 'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?auto=format&fit=crop&q=80&w=800',
  'pescado frito': 'https://images.unsplash.com/photo-1580476262798-bddd9f4b7369?auto=format&fit=crop&q=80&w=800',
  'pizza': 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&q=80&w=800',
  'platano': 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?auto=format&fit=crop&q=80&w=800',
  'pollo': 'https://images.unsplash.com/photo-1598103442097-8b74394b95c6?auto=format&fit=crop&q=80&w=800',
  'porotos_con_riendas': 'https://images.unsplash.com/photo-1511910849309-0dffb8785146?auto=format&fit=crop&q=80&w=800',
  'salmon': 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&q=80&w=800',
  'sopaipillas': 'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?auto=format&fit=crop&q=80&w=800',
  'tiramisu': 'https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?auto=format&fit=crop&q=80&w=800',
};

/// Short contextual descriptions for Chilean foods
const Map<String, String> _foodDescriptions = {
  'arroz': 'Grano base de la cocina chilena, acompañamiento versátil y nutritivo.',
  'arvejas': 'Legumbre verde rica en proteína vegetal y fibra dietaria.',
  'brocoli': 'Verdura crucífera cargada de vitaminas C y K.',
  'calzones_rotos': 'Dulce clásico chileno frito y espolvoreado con azúcar flor.',
  'carne': 'Proteína animal de alta calidad, fuente de hierro y B12.',
  'cazuela': 'Guiso tradicional chileno con carne, papa, zapallo y choclo.',
  'charquican': 'Plato reconfortante de carne picada con verduras y puré.',
  'choripan': 'El clásico sándwich de chorizo asado en pan marraqueta.',
  'completos': 'Hot dog chileno con palta, tomate, mayo y chucrut.',
  'durazno': 'Fruta de temporada, dulce y jugosa, rica en vitamina A.',
  'empanada': 'Empanada de pino: carne, cebolla, huevo duro y aceituna.',
  'ensalada_a_la_chilena': 'Ensalada fresca de tomate y cebolla con limón y cilantro.',
  'huevos_fritos': 'Huevos de campo fritos en aceite, un clásico del desayuno.',
  'humitas': 'Pasta de choclo fresco envuelta en hojas de maíz.',
  'manzana': 'Fruta crujiente y refrescante, perfecta como snack saludable.',
  'mote_con_huesillo': 'Bebida refrescante tradicional con trigo y durazno deshidratado.',
  'naranja': 'Cítrico vitamínico, ideal para jugos naturales matutinos.',
  'palomitas': 'Snack de maíz inflado, liviano y crujiente.',
  'palta': 'Palta Hass chilena, cremosa y rica en grasas saludables.',
  'papas_fritas': 'Papas crujientes fritas, clásico acompañamiento chileno.',
  'pasta': 'Carbohdrato versátil, base de múltiples preparaciones.',
  'pastel_de_choclo': 'Pastel clásico con pino de carne y crema de choclo gratinada.',
  'pescado frito': 'Pescado fresco rebozado y frito, fuente de omega-3.',
  'pizza': 'Pizza artesanal con ingredientes frescos y queso fundido.',
  'platano': 'Fruta energética rica en potasio, ideal pre-entrenamiento.',
  'pollo': 'Proteína magra versátil, base de la dieta chilena.',
  'porotos_con_riendas': 'Porotos con fideos, plato contundente de la cocina popular.',
  'salmon': 'Salmón chileno premium, rico en omega-3 y proteínas.',
  'sopaipillas': 'Masa frita de zapallo, tradición chilena de días lluviosos.',
  'tiramisu': 'Postre italiano con café, mascarpone y cacao.',
};

/// Servicio para buscar comidas chilenas en la base de datos local
class LocalChileSearchService {
  static final LocalChileSearchService _instance = LocalChileSearchService._internal();
  
  Map<String, dynamic> _chileFood = {};
  bool _isLoaded = false;

  factory LocalChileSearchService() {
    return _instance;
  }

  LocalChileSearchService._internal();

  /// Carga la base de datos local de comidas chilenas (solo una vez)
  Future<void> initialize() async {
    if (_isLoaded) return;

    try {
      final jsonString = await rootBundle.loadString('assets/data/chile_food_44.sample.json');
      _chileFood = jsonDecode(jsonString) as Map<String, dynamic>;
      _isLoaded = true;
      debugPrint('✅ Base de datos chilena cargada: ${_chileFood.length} alimentos');
    } catch (e) {
      debugPrint('❌ Error cargando base de datos chilena: $e');
    }
  }

  /// Busca alimentos locales por término (en español o inglés)
  Future<List<FoodItem>> searchLocal(String query) async {
    await initialize();
    if (_chileFood.isEmpty) return const [];

    final normalizedQuery = query.toLowerCase().trim();
    final results = <FoodItem>[];

    for (final entry in _chileFood.entries) {
      final foodData = entry.value as Map<String, dynamic>;
      final nameEs = (foodData['name_es'] as String?)?.toLowerCase() ?? '';
      final nameEn = (foodData['name_en'] as String?)?.toLowerCase() ?? '';

      // Búsqueda por coincidencia parcial
      if (nameEs.contains(normalizedQuery) || nameEn.contains(normalizedQuery)) {
        final imageUrl = _foodImages[entry.key];
        final description = _foodDescriptions[entry.key];
        
        results.add(
          FoodItem(
            source: FoodSource.localChile,
            itemId: foodData['id']?.toString() ?? entry.key,
            nameEs: foodData['name_es']?.toString() ?? entry.key,
            nameEn: foodData['name_en']?.toString() ?? entry.key,
            portion: const Portion(amount: 100, unit: 'g'),
            nutrition: Nutrition(
              kcal: (foodData['kcal'] as num?)?.toDouble() ?? 0,
              proteinG: (foodData['protein_g'] as num?)?.toDouble() ?? 0,
              carbsG: (foodData['carbs_g'] as num?)?.toDouble() ?? 0,
              fatG: (foodData['fat_g'] as num?)?.toDouble() ?? 0,
            ),
            imageUrl: imageUrl,
            metadata: {
              'source': 'chile_local',
              'key': entry.key,
              'short_description_es': description ?? '',
            },
          ),
        );
      }
    }

    debugPrint('🇨🇱 Búsqueda local: ${results.length} resultados para "$query"');
    return results;
  }

  /// Obtiene todos los alimentos cargados
  Future<List<FoodItem>> getAllLocal() async {
    await initialize();
    final results = <FoodItem>[];

    for (final entry in _chileFood.entries) {
      final foodData = entry.value as Map<String, dynamic>;
      final imageUrl = _foodImages[entry.key];
      final description = _foodDescriptions[entry.key];
      
      results.add(
        FoodItem(
          source: FoodSource.localChile,
          itemId: foodData['id']?.toString() ?? entry.key,
          nameEs: foodData['name_es']?.toString() ?? entry.key,
          nameEn: foodData['name_en']?.toString() ?? entry.key,
          portion: const Portion(amount: 100, unit: 'g'),
          nutrition: Nutrition(
            kcal: (foodData['kcal'] as num?)?.toDouble() ?? 0,
            proteinG: (foodData['protein_g'] as num?)?.toDouble() ?? 0,
            carbsG: (foodData['carbs_g'] as num?)?.toDouble() ?? 0,
            fatG: (foodData['fat_g'] as num?)?.toDouble() ?? 0,
          ),
          imageUrl: imageUrl,
          metadata: {
            'source': 'chile_local',
            'key': entry.key,
            'short_description_es': description ?? '',
          },
        ),
      );
    }

    return results;
  }

  /// Verifica si la DB local está cargada
  bool get isLoaded => _isLoaded;

  /// Obtiene el número de alimentos en la DB local
  int get foodCount => _chileFood.length;
}
