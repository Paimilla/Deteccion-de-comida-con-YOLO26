import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/app_routes.dart';
import '../../application/app_services.dart';
import '../../domain/models/nutrition_models.dart';
import '../../domain/models/tracking_models.dart';
import '../../infrastructure/services/meal_slot_suggestions_service.dart';
import '../widgets/animated_screen_body.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_notifier.dart';
import '../widgets/feedback_widgets.dart';
import '../widgets/nutrifoto_ui.dart';

class RecipesScreen extends StatefulWidget {
  final AppServices services;

  const RecipesScreen({super.key, required this.services});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final _ingredientCtrl = TextEditingController();
  bool _loading = false;
  MealSlot _mealSlot = MealSlot.cena;
  bool _argsApplied = false;
  List<FoodItem> _results = const [];
  List<FoodItem> _frequentItems = const [];
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsApplied) return;
    
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['mealSlot'] is MealSlot) {
      _mealSlot = args['mealSlot'] as MealSlot;
    }
    _argsApplied = true;
    _loadInitialSuggestions();
    _loadFrequentFoods();
  }

  // Sugerencias populares para búsqueda rápida - DINÁMICAS por tipo de comida

  // Sugerencias estáticas para carga instantánea (mientras cargan las de API)
  // ── Catálogos Premium por Horario para Video Demo ──
  static List<FoodItem> _getStaticFeaturedFor(MealSlot slot) {
    switch (slot) {
      case MealSlot.desayuno:
        return [
          _buildDemoItem('demo_huevos', 'Paila de Huevos de Campo', 'Eggs', 280, 18, 2, 22, 'https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&q=80&w=800', 'Huevos recién preparados con un toque de ciboulette y tostadas.'),
          _buildDemoItem('demo_avena', 'Bowl de Avena y Frutos Rojos', 'Oatmeal', 320, 12, 45, 8, 'https://images.unsplash.com/photo-1517673132405-a56a62b18caf?auto=format&fit=crop&q=80&w=800', 'Energía natural con avena integral, arándanos y miel.'),
        ];
      case MealSlot.once:
        return [
          _buildDemoItem('demo_once_1', 'Sándwich de Pavo y Palta', 'Turkey Sandwich', 420, 25, 35, 18, 'https://images.unsplash.com/photo-1550507992-eb63ffee0847?auto=format&fit=crop&q=80&w=800', 'La clásica once chilena: pan integral, pechuga de pavo y palta hass.'),
          _buildDemoItem('demo_once_2', 'Quesillo con Tomate y Albahaca', 'Fresh Cheese', 210, 15, 8, 12, 'https://images.unsplash.com/photo-1560684352-8497838a2229?auto=format&fit=crop&q=80&w=800', 'Una opción liviana y fresca para terminar el día.'),
        ];
      case MealSlot.snack:
        return [
          _buildDemoItem('demo_snack_1', 'Mix de Frutos Secos Premium', 'Nut Mix', 180, 6, 8, 14, 'https://images.unsplash.com/photo-1511112181181-026b860c5bb7?auto=format&fit=crop&q=80&w=800', 'Combinación de nueces, almendras y castañas de cajú.'),
          _buildDemoItem('demo_snack_2', 'Yogurt Griego con Granola', 'Greek Yogurt', 240, 18, 22, 6, 'https://images.unsplash.com/photo-1488477181946-6428a0291777?auto=format&fit=crop&q=80&w=800', 'Snack proteico con granola crujiente y semillas de chía.'),
        ];
      case MealSlot.almuerzo:
      case MealSlot.cena:
        return [
          _buildDemoItem('demo_pastel', 'Pastel de Choclo Tradicional', 'Corn Pie', 450, 22, 45, 18, 'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?auto=format&fit=crop&q=80&w=800', 'Pino de carne, pollo y crema de maíz tostado.'),
          _buildDemoItem('demo_paila', 'Paila Marina de la Costa', 'Seafood Soup', 320, 35, 12, 8, 'https://images.unsplash.com/photo-1534080564607-198f9dd5d61a?auto=format&fit=crop&q=80&w=800', 'Mix de mariscos frescos en caldo caliente reconfortante.'),
        ];
    }
  }

  static FoodItem _buildDemoItem(String id, String name, String nameEn, double kcal, double p, double c, double f, String url, String desc) {
    // Estimate prep time and difficulty from calorie complexity
    final prepTime = kcal > 400 ? 35 : (kcal > 250 ? 25 : 15);
    final difficulty = kcal > 400 ? 'Alta' : (kcal > 200 ? 'Media' : 'Fácil');
    
    return FoodItem(
      source: FoodSource.localChile,
      itemId: id,
      nameEs: name,
      nameEn: nameEn,
      portion: const Portion(amount: 100, unit: 'g'),
      nutrition: Nutrition(kcal: kcal, proteinG: p, carbsG: c, fatG: f),
      imageUrl: url,
      metadata: {
        'short_description_es': desc,
        'prep_time': prepTime,
        'difficulty': difficulty,
        'instructions_es': _generateContextualInstructions(name),
      },
    );
  }

  /// Generates contextual preparation instructions based on food name
  static String _generateContextualInstructions(String foodName) {
    final lower = foodName.toLowerCase();
    if (lower.contains('huevo') || lower.contains('paila')) {
      return 'Calentar una sartén con un poco de aceite a fuego medio.\nCascar los huevos con cuidado directamente en la sartén caliente.\nCocinar por 3-4 minutos hasta que la clara esté firme.\nSazonar con sal, pimienta y ciboulette fresco al servir.';
    }
    if (lower.contains('avena') || lower.contains('bowl')) {
      return 'Hervir la leche o agua en una olla pequeña.\nAgregar la avena y revolver durante 5 minutos a fuego bajo.\nServir en un bowl y agregar frutos rojos frescos encima.\nEndulzar con miel natural y añadir semillas de chía.';
    }
    if (lower.contains('sándwich') || lower.contains('sandwich')) {
      return 'Tostar ligeramente el pan integral en la tostadora.\nUntar una capa generosa de palta madura sobre el pan.\nAgregar las láminas de pavo y vegetales frescos.\nSazonar con limón, sal y pimienta al gusto.';
    }
    if (lower.contains('pastel') || lower.contains('choclo')) {
      return 'Preparar el pino con carne molida, cebolla y especias.\nColocar la base de pino en fuentes individuales de greda.\nCubrir con pasta de choclo fresco y espolvorear azúcar.\nGratinar al horno a 200°C por 25-30 minutos hasta dorar.';
    }
    if (lower.contains('paila') || lower.contains('marina') || lower.contains('marisco')) {
      return 'Preparar un caldo base con cebolla, ajo y vino blanco.\nAgregar los mariscos frescos comenzando por los de cocción más larga.\nDejar hervir a fuego medio por 10-12 minutos.\nServir caliente con limón y cilantro fresco picado.';
    }
    if (lower.contains('yogurt') || lower.contains('granola')) {
      return 'Servir el yogurt griego natural en un bowl amplio.\nAgregar la granola crujiente formando una capa uniforme.\nDecorar con frutas frescas de temporada.\nFinalizar con un toque de miel y semillas de chía.';
    }
    if (lower.contains('frutos secos') || lower.contains('mix')) {
      return 'Seleccionar una mezcla variada de frutos secos de calidad.\nTostar ligeramente en sartén seca por 3-4 minutos.\nDejar enfriar y mezclar con un toque de sal marina.\nPorcionar en bolsas individuales para snacks de la semana.';
    }
    if (lower.contains('quesillo') || lower.contains('queso')) {
      return 'Cortar el quesillo fresco en rodajas de 1cm de espesor.\nDisponerlas en un plato intercaladas con rodajas de tomate.\nAgregar hojas de albahaca fresca y un hilo de aceite de oliva.\nSazonar con sal de mar, pimienta y orégano.';
    }
    // Default contextual
    return 'Reunir y preparar todos los ingredientes frescos necesarios.\nCocinar siguiendo las proporciones indicadas en la receta.\nAjustar la sazón al gusto personal con especias naturales.\nEmplatar de forma atractiva y servir de inmediato.';
  }

  late List<FoodItem> _featuredItems;

  @override
  void initState() {
    super.initState();
    _featuredItems = _getStaticFeaturedFor(_mealSlot);
    // Ya no cargamos aquí, esperamos a didChangeDependencies para tener el MealSlot
  }

  Future<void> _loadFrequentFoods() async {
    try {
      final frequent = await widget.services.trackingUseCases.getFrequentFoods(limit: 6);
      if (mounted && frequent.isNotEmpty) {
        setState(() {
          _frequentItems = frequent;
        });
      }
    } catch (e) {
      debugPrint('Error loading frequent foods: $e');
    }
  }

  Future<void> _loadInitialSuggestions() async {
    if (!mounted) return;
    
    // Limpiar resultados anteriores inmediatamente para evitar el efecto "buggy"
    setState(() {
      _featuredItems = []; 
      _loading = true;
    });

    try {
      // Usar búsqueda específica para el tipo de comida seleccionado
      final query = MealSlotSuggestionsService.getSearchQueryForMealSlot(_mealSlot);
      debugPrint('🤖 Buscando sugerencias para ${_mealSlot.label}: $query');
      
      final items = await widget.services.foodOrchestrator.searchRecipesInSpanish(query);
      
      // Filtrar resultados que NO tengan imagen para asegurar la estética
      final filteredItems = items.where((item) => 
        item.imageUrl != null && 
        item.imageUrl!.isNotEmpty && 
        !item.imageUrl!.contains('placeholder')
      ).toList();

      if (mounted) {
        setState(() {
          _loading = false;
          if (filteredItems.isNotEmpty) {
            _featuredItems = filteredItems.take(12).toList();
          } else {
            // Si la búsqueda no trajo nada estético, usamos nuestro catálogo premium por horario
            _featuredItems = _getStaticFeaturedFor(_mealSlot);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading initial suggestions: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveItem(FoodItem item) async {
    // 1. Feedback táctil inmediato
    HapticFeedback.mediumImpact();
    
    // 2. Notificación instantánea (UI Optimista)
    AppNotifier.success(
      context,
      '${item.nameEs} registrado con éxito',
    );

    // 3. Guardado en segundo plano (sin bloquear la UI)
    widget.services.trackingUseCases.addFoodEntry(
      mealSlot: _mealSlot,
      food: item,
    ).then((_) {
      if (mounted) _loadFrequentFoods();
    });
  }

  @override
  void dispose() {
    _ingredientCtrl.dispose();
    super.dispose();
  }

  Future<void> _search([String? override]) async {
    final ingredient = override ?? _ingredientCtrl.text.trim();
    if (ingredient.isEmpty) {
      setState(() => _error = 'Ingresa un ingrediente');
      return;
    }

    if (override != null) {
      _ingredientCtrl.text = ingredient;
    }

    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();

    setState(() {
      _loading = true;
      _error = null;
      _results = const [];
    });

    try {
      final items = await widget.services.foodOrchestrator.searchRecipesInSpanish(
        ingredient,
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
        _results = items;
        if (items.isEmpty) {
          _error = 'Sin resultados para "$ingredient"';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Ocurrió un error en la búsqueda. Prueba de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width < 360 ? 12.0 : 16.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comidas y Recetas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Limpiar caché y refrescar',
            onPressed: () {
              // Limpiamos el caché global de búsquedas
              widget.services.searchCache?.clearAll();
              widget.services.foodOrchestrator.clearFullItemCache();
              // Forzamos carga fresca
              _loadInitialSuggestions();
              _loadFrequentFoods();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Caché limpiado. Buscando recetas frescas...')),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: AppRoutes.hoy),
      body: AnimatedScreenBody(
        child: ListView(
          padding: EdgeInsets.all(horizontalPadding),
          children: [
            HeroPanel(
              title: 'Recetas',
              subtitle: 'Descubre alimentos y su información nutricional',
              gradient: NutrifotoColors.searchGradient,
            ),
            const SizedBox(height: 12),

            // ── Barra de búsqueda ──
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _ingredientCtrl,
                    decoration: InputDecoration(
                      labelText: 'Buscar alimento o ingrediente',
                      hintText: 'Ej: pollo, arroz, manzana...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _ingredientCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _ingredientCtrl.clear();
                                setState(() {
                                  _results = const [];
                                  _error = null;
                                });
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _search(),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _search,
                      icon: const Icon(Icons.restaurant_menu),
                      label:
                          Text(_loading ? 'Buscando...' : 'Buscar'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<MealSlot>(
                    initialValue: _mealSlot,
                    decoration: const InputDecoration(
                      labelText: 'Guardar en',
                      isDense: true,
                    ),
                    items: MealSlot.values
                        .map(
                          (slot) => DropdownMenuItem(
                            value: slot,
                            child: Text(slot.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _mealSlot = value);
                        _loadInitialSuggestions(); // Actualizar sugerencias al cambiar el horario
                      }
                    },
                  ),
                ],
              ),
            ),

            // ── Categorías populares ──
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: MealSlotSuggestionsService.getQuickSuggestionsForMealSlot(_mealSlot)
                    .map((label) {
                      final parts = label.split(' ');
                      final emoji = parts.length > 1 ? parts[0] : '🔍';
                      final text = parts.length > 1 ? parts.sublist(1).join(' ') : label;
                      
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _SuggestionChip(
                          suggestion: _Suggestion(emoji, text),
                          onTap: () {
                            _ingredientCtrl.text = text;
                            _search(text);
                          },
                        ),
                      );
                    })
                    .toList(),
              ),
            ),
            const SizedBox(height: 24),

            // ── Sugerencias iniciales ──
            if (_results.isEmpty) ...[
              // ── NUEVA SECCIÓN: Alimentos frecuentes (Historial) ──
              if (_frequentItems.isNotEmpty && _results.isEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.history, color: NutrifotoColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Lo que más comes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _frequentItems.length,
                    itemBuilder: (context, index) {
                      final item = _frequentItems[index];
                      return _FrequentFoodChip(
                        item: item,
                        onTap: () => _showDetail(item),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
              ],

              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sugerencias de ${_mealSlot.label}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          MealSlotSuggestionsService.getDescriptionForMealSlot(_mealSlot),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_featuredItems.isNotEmpty)
                ..._featuredItems.map((item) => _FoodResultCard(
                      item: item,
                      onSave: () => _showDetail(item),
                      onTap: () => _showDetail(item),
                      isFeatured: true,
                    ))
              else
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      'Busca ingredientes para ver recetas',
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

            ],

            // ── Loading ──
            if (_loading)
              ...List.generate(4, (index) => const SkeletonCard()),

            // ── Error ──
            if (_error != null && !_loading && _results.isEmpty) ...[
              const SizedBox(height: 12),
              ErrorBlock(message: _error!),
            ],

            // ── Resultados ──
            if (!_loading && _results.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '${_results.length} resultado(s)',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const SizedBox(height: 8),
              ..._results.map((item) => _FoodResultCard(
                    item: item,
                    onTap: () => _showDetail(item),
                    onSave: () => _showDetail(item),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetail(FoodItem item) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RecipeDetailSheet(
        item: item,
        mealSlot: _mealSlot,
        services: widget.services, // Pasar servicios para traducción on-demand
        onSave: (finalItem) {
          _saveItem(finalItem);
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Widgets privados
// ═══════════════════════════════════════════════════════════════════════════════

class _Suggestion {
  final String emoji;
  final String label;
  const _Suggestion(this.emoji, this.label);
}

class _SuggestionChip extends StatelessWidget {
  final _Suggestion suggestion;
  final VoidCallback onTap;

  const _SuggestionChip({required this.suggestion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? NutrifotoColors.surfaceSoft
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(suggestion.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              suggestion.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrequentFoodChip extends StatelessWidget {
  final FoodItem item;
  final VoidCallback onTap;

  const _FrequentFoodChip({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              height: 70,
              width: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: ClipOval(
                child: NutrifotoImage(
                  imageUrl: item.imageUrl,
                  name: item.nameEs,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.nameEs,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodResultCard extends StatelessWidget {
  final FoodItem item;
  final VoidCallback onSave;
  final VoidCallback onTap;
  final bool isFeatured;

  const _FoodResultCard({
    required this.item,
    required this.onSave,
    required this.onTap,
    this.isFeatured = false,
  });

  /// Estimates prep time from metadata or caloric complexity
  static int _estimatePrepTime(FoodItem item) {
    // Use metadata if available
    final metaTime = item.metadata['prep_time'];
    if (metaTime is int) return metaTime;
    if (metaTime is num) return metaTime.toInt();
    
    // Smart estimate based on food characteristics
    final kcal = item.nutrition.kcal;
    final hasInstructions = item.metadata['instructions'] != null || 
                           item.metadata['instructions_es'] != null;
    
    if (kcal > 500) return 45;
    if (kcal > 350) return 35;
    if (kcal > 200) return 25;
    if (hasInstructions) return 20;
    return 15;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.1),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Magazine-style Cover ──
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
                  child: AspectRatio(
                    aspectRatio: 1.1,
                    child: Hero(
                      tag: 'food_img_${item.itemId}',
                      child: NutrifotoImage(
                        imageUrl: item.imageUrl,
                        name: item.nameEs,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                // Gradient Overlays
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                // Badges
                Positioned(
                  top: 20,
                  right: 20,
                  child: _SourceBadge(source: item.source),
                ),
                if (isFeatured)
                  Positioned(
                    top: 20,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                      ),
                      child: const Text(
                        '✨ POPULAR',
                        style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                // Floating Macro Pill on bottom
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: NutrifotoColors.primary,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: NutrifotoColors.primary.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 5))],
                        ),
                        child: Text(
                          '${item.nutrition.kcal.round()} Kcal',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                      ),
                      const Spacer(),
                      _TimeBadge(minutes: _estimatePrepTime(item)),
                    ],
                  ),
                ),
              ],
            ),
            // ── Elegant Info ──
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nameEs.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      letterSpacing: -1.2,
                      height: 1.0,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    item.metadata['short_description_es'] ?? 'Una opción equilibrada para tu día. Rica en nutrientes esenciales y preparada con ingredientes frescos.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : Colors.black54,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _MacroMini(label: 'PROT', value: item.nutrition.proteinG, target: 176, unit: 'g', color: Colors.blue),
                        const SizedBox(width: 24),
                        _MacroMini(label: 'CARBS', value: item.nutrition.carbsG, target: 231, unit: 'g', color: Colors.green),
                        const SizedBox(width: 24),
                        _MacroMini(label: 'GRASAS', value: item.nutrition.fatG, target: 63, unit: 'g', color: Colors.orange),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NutrifotoColors.primary.withValues(alpha: 0.1),
                        foregroundColor: NutrifotoColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: const BorderSide(color: NutrifotoColors.primary, width: 1.5),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('VER RECETA Y AJUSTAR', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.2)),
                          SizedBox(width: 12),
                          Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeBadge extends StatelessWidget {
  final int minutes;
  const _TimeBadge({required this.minutes});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text('$minutes min', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MacroMini extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final String unit;
  final Color color;

  const _MacroMini({
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (value / target).clamp(0.0, 1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 38,
              height: 38,
              child: CircularProgressIndicator(
                value: percent,
                strokeWidth: 4,
                backgroundColor: color.withValues(alpha: isDark ? 0.1 : 0.05),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            Text(
              '${(percent * 100).toInt()}%',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white38 : Colors.black38,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${value.round()}$unit',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }
}

class _RecipeDetailSheet extends StatefulWidget {
  final FoodItem item;
  final MealSlot mealSlot;
  final AppServices services;
  final Function(FoodItem) onSave;
  const _RecipeDetailSheet(
      {required this.item, required this.mealSlot, required this.services, required this.onSave});
  @override
  State<_RecipeDetailSheet> createState() => _RecipeDetailSheetState();
}

class _RecipeDetailSheetState extends State<_RecipeDetailSheet> {
  late double _grams;
  late double _portions;
  bool _isGramsMode = false; // Default to portions as it's more "recipe-like"
  late MealSlot _selectedSlot;
  late FoodItem _item;
  bool _translating = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _grams = _item.portion.amount;
    _portions = 1.0;
    _selectedSlot = widget.mealSlot;

    // Si no tiene traducción de detalles, iniciarla on-demand
    if (_item.metadata['summary_es'] == null && 
       (_item.metadata['summary'] != null || _item.metadata['instructions'] != null)) {
      _translateDetails();
    }
  }

  Future<void> _translateDetails() async {
    setState(() => _translating = true);
    try {
      final updated = await widget.services.foodOrchestrator.translateRecipeDetails(_item);
      if (mounted) {
        setState(() {
          _item = updated;
          _translating = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _translating = false);
    }
  }

  String _getDifficulty() {
    final meta = _item.metadata['difficulty'];
    if (meta is String && meta.isNotEmpty) return meta;
    
    final kcal = _item.nutrition.kcal;
    if (kcal > 500) return 'Alta';
    if (kcal > 250) return 'Media';
    return 'Fácil';
  }

  int _getPrepTime() {
    final meta = _item.metadata['prep_time'];
    if (meta is int) return meta;
    if (meta is num) return meta.toInt();
    
    final kcal = _item.nutrition.kcal;
    if (kcal > 500) return 45;
    if (kcal > 350) return 35;
    if (kcal > 200) return 25;
    return 15;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double currentGrams = _isGramsMode ? _grams : _portions * _item.portion.amount;
    final ratio = currentGrams / _item.portion.amount;
    final kcal = _item.nutrition.kcal * ratio;
    final protein = _item.nutrition.proteinG * ratio;
    final carbs = _item.nutrition.carbsG * ratio;
    final fat = _item.nutrition.fatG * ratio;

    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.7,
      maxChildSize: 0.98,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
            color: isDark ? NutrifotoColors.bg : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40))),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          children: [
            Center(
                child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : Colors.black12,
                          borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 32),
            ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: AspectRatio(
                    aspectRatio: 1.2,
                    child: Hero(
                        tag: 'food_img_${_item.itemId}',
                        child: NutrifotoImage(
                            imageUrl: _item.imageUrl,
                            name: _item.nameEs,
                            fit: BoxFit.cover)))),
            const SizedBox(height: 32),
            Text(_item.nameEs,
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                    height: 1.0)),
            const SizedBox(height: 16),
            Row(
              children: [
                _SourceBadge(source: _item.source),
                const SizedBox(width: 12),
                Icon(Icons.restaurant_rounded,
                    color: NutrifotoColors.primary.withValues(alpha: 0.6), size: 18),
                const SizedBox(width: 4),
                Text(_getDifficulty(),
                    style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Icon(Icons.timer_outlined,
                    color: NutrifotoColors.accentBlue.withValues(alpha: 0.6), size: 18),
                const SizedBox(width: 4),
                Text('${_getPrepTime()} min',
                    style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 40),
            
            // ── Section Title: Ajustar Porción ──
            const Text('¿CUÁNTO VAS A COMER?',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2.0, color: NutrifotoColors.primary)),
            const SizedBox(height: 16),
            
            // ── Mode Switcher ──
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ModeToggleBtn(
                      label: 'PORCIONES',
                      isSelected: !_isGramsMode,
                      onTap: () => setState(() => _isGramsMode = false),
                    ),
                  ),
                  Expanded(
                    child: _ModeToggleBtn(
                      label: 'GRAMOS',
                      isSelected: _isGramsMode,
                      onTap: () => setState(() => _isGramsMode = true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_isGramsMode) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Cantidad precisa', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text('${_grams.round()} g',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: NutrifotoColors.primary)),
                ],
              ),
              Slider(
                  value: _grams,
                  min: 10,
                  max: 1000,
                  divisions: 99,
                  activeColor: NutrifotoColors.primary,
                  onChanged: (val) => setState(() => _grams = val)),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Número de porciones', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text(_portions.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: NutrifotoColors.accentBlue)),
                ],
              ),
              Slider(
                  value: _portions,
                  min: 0.5,
                  max: 8.0,
                  divisions: 15,
                  activeColor: NutrifotoColors.accentBlue,
                  onChanged: (val) => setState(() => _portions = val)),
            ],

            const SizedBox(height: 40),
            
            // ── Macro Info ──
            const Text('VALORES NUTRICIONALES (Impacto diario)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2.0, color: NutrifotoColors.primary)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
              ),
              child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CircularMacro(
                        label: 'Calorías',
                        value: kcal,
                        unit: 'kcal',
                        target: 2200,
                        color: Colors.orange),
                    const SizedBox(width: 20),
                    _CircularMacro(
                        label: 'Prot',
                        value: protein,
                        unit: 'g',
                        target: 176, // 32% of 2200
                        color: Colors.blue),
                    const SizedBox(width: 20),
                    _CircularMacro(
                        label: 'Carbs',
                        value: carbs,
                        unit: 'g',
                        target: 231, // 42% of 2200
                        color: Colors.green),
                    const SizedBox(width: 20),
                    _CircularMacro(
                        label: 'Grasa',
                        value: fat,
                        unit: 'g',
                        target: 63, // 26% of 2200
                        color: Colors.red)
                  ]),
            ),
            ),
            
            const SizedBox(height: 40),
            
            // ── NEW: Summary/Description ──
            if (_translating) ...[
              const Center(child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              )),
              Center(child: Text('Traduciendo detalles con IA...', 
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38))),
              const SizedBox(height: 32),
            ] else if (_item.metadata['summary_es'] != null) ...[
              Text(
                'SOBRE ESTA RECETA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                // Limpiar etiquetas HTML básicas si vienen
                _item.metadata['summary_es'].toString().replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ''),
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white70 : Colors.black87,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
            ],

            // ── Preparation Section ──
            const Text('PASOS DE PREPARACIÓN',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2.0, color: NutrifotoColors.primary)),
            const SizedBox(height: 20),
            
            if (_translating) ...[
               const SizedBox(height: 12),
               Text('Cargando pasos...', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26)),
            ] else if (_item.metadata['instructions_es'] != null) ...[
              ..._item.metadata['instructions_es']
                  .toString()
                  .replaceAll(RegExp(r'<[^>]*>'), '')
                  .split(RegExp(r'\.(?=\s|[A-Z])|\n|;'))
                  .where((s) => s.trim().length > 3)
                  .toList()
                  .asMap()
                  .entries
                  .map((e) => _PreparationStep(number: e.key + 1, text: e.value.trim().endsWith('.') ? e.value.trim() : '${e.value.trim()}.')),
            ] else ...[
              // Fallback: generar instrucciones contextuales según nombre del alimento
              ..._RecipesScreenState._generateContextualInstructions(_item.nameEs)
                  .split('\n')
                  .where((s) => s.trim().isNotEmpty)
                  .toList()
                  .asMap()
                  .entries
                  .map((e) => _PreparationStep(number: e.key + 1, text: e.value.trim())),
            ],

            const SizedBox(height: 48),
            const Text('AGREGAR A MI REGISTRO:',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.0)),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                  children: MealSlot.values
                      .map((slot) => Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: ChoiceChip(
                                label: Text(slot.label.toUpperCase()),
                                selected: _selectedSlot == slot,
                                labelStyle: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: _selectedSlot == slot ? Colors.white : (isDark ? Colors.white54 : Colors.black54),
                                ),
                                selectedColor: NutrifotoColors.primary,
                                onSelected: (val) =>
                                    setState(() => _selectedSlot = slot)),
                          ))
                      .toList()),
            ),
            const SizedBox(height: 48),
            SizedBox(
                width: double.infinity,
                height: 72,
                child: FilledButton(
                    onPressed: () {
                      final finalItem = _item.copyWith(
                          portion: Portion(amount: currentGrams, unit: 'g'),
                          nutrition: Nutrition(
                              kcal: kcal,
                              proteinG: protein,
                              carbsG: carbs,
                              fatG: fat),
                        );
                      widget.onSave(finalItem);
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                        backgroundColor: NutrifotoColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24))),
                    child: const Text('CONFIRMAR Y GUARDAR',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.0)))),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _PreparationStep extends StatelessWidget {
  final int number;
  final String text;
  const _PreparationStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(color: NutrifotoColors.primary, shape: BoxShape.circle),
            child: Center(child: Text('$number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14))),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 15, height: 1.4))),
        ],
      ),
    );
  }
}

class _ModeToggleBtn extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _ModeToggleBtn(
      {required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? NutrifotoColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white54,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _CircularMacro extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final double target;
  final Color color;

  const _CircularMacro({
    required this.label,
    required this.value,
    required this.unit,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (value / target).clamp(0.0, 1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 58,
              height: 58,
              child: CircularProgressIndicator(
                value: percent,
                strokeWidth: 5,
                backgroundColor: color.withValues(alpha: isDark ? 0.1 : 0.05),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            Text(
              '${(percent * 100).toInt()}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white38 : Colors.black38,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${value.round()}$unit',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }
}


class _SourceBadge extends StatelessWidget {
  final FoodSource source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final label = switch (source) {
      FoodSource.localChile => 'CL',
      FoodSource.openFoodFacts => 'OFF',
      FoodSource.usda => 'USDA',
      _ => 'REC',
    };
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: NutrifotoColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: NutrifotoColors.primary,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// _FoodPlaceholder y _MacroChip han sido movidos a nutrifoto_ui.dart
