import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/app_routes.dart';
import '../../application/app_services.dart';
import '../../domain/models/nutrition_models.dart';
import '../../domain/models/tracking_models.dart';
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
  bool _saving = false;
  MealSlot _mealSlot = MealSlot.cena;
  bool _argsApplied = false;
  List<FoodItem> _results = const [];
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
  }

  // Sugerencias populares para búsqueda rápida
  static const _suggestions = [
    _Suggestion('🍗', 'Pollo'),
    _Suggestion('🍚', 'Arroz'),
    _Suggestion('🥚', 'Huevo'),
    _Suggestion('🍝', 'Pasta'),
    _Suggestion('🥩', 'Carne'),
    _Suggestion('🐟', 'Pescado'),
    _Suggestion('🥑', 'Palta'),
    _Suggestion('🍌', 'Fruta'),
    _Suggestion('🥛', 'Lácteos'),
    _Suggestion('🥗', 'Ensalada'),
    _Suggestion('🍞', 'Pan'),
  ];

  // Sugerencias estáticas para carga instantánea (mientras cargan las de API)
  static final List<FoodItem> _staticFeatured = [
    const FoodItem(
      source: FoodSource.localChile,
      itemId: 'st_pollo',
      nameEs: 'Pechuga de Pollo a la Plancha',
      portion: Portion(amount: 150, unit: 'g'),
      nutrition: Nutrition(kcal: 247, proteinG: 46, carbsG: 1, fatG: 5.5),
      imageUrl: 'https://images.unsplash.com/photo-1532550907401-a500c9a57435?q=80&w=400&auto=format&fit=crop',
      metadata: {
        'short_description_es': 'Pechuga tierna y jugosa preparada con finas hierbas.',
        'instructions_es': '1. Sazonar la pechuga.\n2. Cocinar en sartén caliente 6 min por lado.\n3. Reposar y servir.'
      },
    ),
    const FoodItem(
      source: FoodSource.localChile,
      itemId: 'st_salmon',
      nameEs: 'Salmón con Espárragos',
      portion: Portion(amount: 200, unit: 'g'),
      nutrition: Nutrition(kcal: 380, proteinG: 40, carbsG: 2, fatG: 22),
      imageUrl: 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?q=80&w=400&auto=format&fit=crop',
      metadata: {
        'short_description_es': 'Filete de salmón fresco acompañado de vegetales salteados.',
        'instructions_es': '1. Sellar el salmón.\n2. Saltear los espárragos con ajo.\n3. Servir caliente.'
      },
    ),
    const FoodItem(
      source: FoodSource.localChile,
      itemId: 'st_ensalada',
      nameEs: 'Ensalada César con Pollo',
      portion: Portion(amount: 300, unit: 'g'),
      nutrition: Nutrition(kcal: 420, proteinG: 25, carbsG: 15, fatG: 28),
      imageUrl: 'https://images.unsplash.com/photo-1550304943-4f24f54ddde9?q=80&w=400&auto=format&fit=crop',
      metadata: {
        'short_description_es': 'Una opción ligera y saciante con aderezo bajo en grasa.',
        'instructions_es': '1. Picar lechuga.\n2. Agregar pollo a la plancha.\n3. Aderezar y servir.'
      },
    ),
    const FoodItem(
      source: FoodSource.localChile,
      itemId: 'st_avena',
      nameEs: 'Bowl de Avena y Frutos Rojos',
      portion: Portion(amount: 250, unit: 'g'),
      nutrition: Nutrition(kcal: 310, proteinG: 12, carbsG: 45, fatG: 8),
      imageUrl: 'https://images.unsplash.com/photo-1517673132405-a56a62b18caf?q=80&w=400&auto=format&fit=crop',
      metadata: {
        'short_description_es': 'Energía natural con avena integral y antioxidantes frescos.',
        'instructions_es': '1. Cocinar avena con leche o agua.\n2. Agregar frutos rojos frescos.\n3. Endulzar al gusto.'
      },
    ),
  ];

  late List<FoodItem> _featuredItems;

  @override
  void initState() {
    super.initState();
    _featuredItems = List.from(_staticFeatured);
    _loadInitialSuggestions();
  }

  Future<void> _loadInitialSuggestions() async {
    // Ya tenemos los estáticos, cargamos más de la API en segundo plano
    try {
      final items = await widget.services.foodOrchestrator.searchRecipesInSpanish('saludable');
      if (mounted && items.isNotEmpty) {
        setState(() {
          // Combinamos: Estáticos primero, luego API
          _featuredItems = [..._staticFeatured, ...items.take(7)].toList();
        });
      } else if (mounted) {
        // Fallback si 'saludable' no trae nada
        final fallback = await widget.services.foodOrchestrator.searchRecipesInSpanish('pollo');
        if (mounted && fallback.isNotEmpty) {
          setState(() {
            _featuredItems = [..._staticFeatured, ...fallback.take(7)].toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading initial suggestions: $e');
    }
  }

  Future<void> _saveItem(FoodItem item) async {
    if (_saving) return;
    setState(() => _saving = true);

    await widget.services.trackingUseCases.addFoodEntry(
      mealSlot: _mealSlot,
      food: item,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    AppNotifier.success(
      context,
      '${item.nameEs} registrado con éxito',
    );
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
      appBar: AppBar(title: const Text('Comidas y Recetas')),
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
                children: _suggestions
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _SuggestionChip(
                            suggestion: s,
                            onTap: () {
                              _ingredientCtrl.text = s.label;
                              _search(s.label);
                            },
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 24),

            // ── Sugerencias iniciales ──
            if (_results.isEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Sugerencias para ti',
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
              if (_featuredItems.isNotEmpty)
                ..._featuredItems.map((item) => _FoodResultCard(
                      item: item,
                      saving: _saving,
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

              const SizedBox(height: 24),
              Text(
                'Categorías populares',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestions
                    .map((s) => _SuggestionChip(
                          suggestion: s,
                          onTap: () {
                            _ingredientCtrl.text = s.label;
                            _search(s.label);
                          },
                        ))
                    .toList(),
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
                    saving: _saving,
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

class _FoodResultCard extends StatelessWidget {
  final FoodItem item;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onTap;
  final bool isFeatured;

  const _FoodResultCard({
    required this.item,
    required this.saving,
    required this.onSave,
    required this.onTap,
    this.isFeatured = false,
  });

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
                      _TimeBadge(minutes: 15 + (item.itemId.length % 20)),
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
                const SizedBox(width: 16),
                Icon(Icons.restaurant_rounded,
                    color: NutrifotoColors.primary.withValues(alpha: 0.6), size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Dificultad: Media',
                      style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 14, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
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
              // Fallback si no hay instrucciones
              _PreparationStep(number: 1, text: 'Lavar y preparar todos los ingredientes frescos.'),
              _PreparationStep(number: 2, text: 'Cocinar la base según el tiempo recomendado.'),
              _PreparationStep(number: 3, text: 'Sazonar al gusto con especias naturales.'),
              _PreparationStep(number: 4, text: 'Emplatar de forma atractiva y disfrutar.'),
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
