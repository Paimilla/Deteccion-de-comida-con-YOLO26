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
  List<FoodItem> _results = const [];
  String? _error;

  // Sugerencias populares para búsqueda rápida
  static const _suggestions = [
    _Suggestion('🍗', 'Pollo'),
    _Suggestion('🍚', 'Arroz'),
    _Suggestion('🥚', 'Huevo'),
    _Suggestion('🍝', 'Pasta'),
    _Suggestion('🥩', 'Carne'),
    _Suggestion('🐟', 'Pescado'),
    _Suggestion('🥑', 'Palta'),
    _Suggestion('🧀', 'Queso'),
    _Suggestion('🍌', 'Plátano'),
    _Suggestion('🥛', 'Leche'),
    _Suggestion('🥗', 'Ensalada'),
    _Suggestion('🍞', 'Pan'),
  ];

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
      '${item.nameEs} agregado en ${_mealSlot.label}',
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
              trailing: IconButton.filledTonal(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.search),
                icon: const Icon(Icons.search),
              ),
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

            // ── Sugerencias rápidas ──
            if (_results.isEmpty && !_loading) ...[
              const SizedBox(height: 16),
              Text(
                'Sugerencias populares',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
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
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: LoadingBlock(message: 'Buscando alimentos...'),
              ),

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
                    onSave: () => _saveItem(item),
                  )),
            ],
          ],
        ),
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

  const _FoodResultCard({
    required this.item,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Imagen del alimento ──
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 72,
              child: hasImage
                  ? Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    (loadingProgress.expectedTotalBytes ?? 1)
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => _FoodPlaceholder(
                        name: item.nameEs,
                      ),
                    )
                  : _FoodPlaceholder(name: item.nameEs),
            ),
          ),
          const SizedBox(width: 12),

          // ── Info nutricional ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nameEs,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.portion.amount.round()} ${item.portion.unit}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 6),
                // Macros chips
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _MacroChip(
                      label: '${item.nutrition.kcal.round()} kcal',
                      color: Colors.orange,
                    ),
                    _MacroChip(
                      label: 'P ${item.nutrition.proteinG.toStringAsFixed(1)}g',
                      color: Colors.blue,
                    ),
                    _MacroChip(
                      label: 'C ${item.nutrition.carbsG.toStringAsFixed(1)}g',
                      color: Colors.green,
                    ),
                    _MacroChip(
                      label: 'G ${item.nutrition.fatG.toStringAsFixed(1)}g',
                      color: Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Botón agregar ──
          SizedBox(
            width: 36,
            child: IconButton(
              onPressed: saving ? null : onSave,
              padding: EdgeInsets.zero,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_circle, size: 28),
              color: NutrifotoColors.primary,
              tooltip: 'Agregar al diario',
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodPlaceholder extends StatelessWidget {
  final String name;
  const _FoodPlaceholder({required this.name});

  @override
  Widget build(BuildContext context) {
    // Seleccionar emoji según nombre
    String emoji = '🍽️';
    final lower = name.toLowerCase();
    if (lower.contains('pollo') || lower.contains('chicken')) emoji = '🍗';
    if (lower.contains('arroz') || lower.contains('rice')) emoji = '🍚';
    if (lower.contains('pan') || lower.contains('bread')) emoji = '🍞';
    if (lower.contains('leche') || lower.contains('milk')) emoji = '🥛';
    if (lower.contains('huevo') || lower.contains('egg')) emoji = '🥚';
    if (lower.contains('carne') || lower.contains('meat') || lower.contains('beef')) emoji = '🥩';
    if (lower.contains('pescado') || lower.contains('fish') || lower.contains('salmon')) emoji = '🐟';
    if (lower.contains('fruta') || lower.contains('fruit') || lower.contains('manzana')) emoji = '🍎';
    if (lower.contains('queso') || lower.contains('cheese')) emoji = '🧀';
    if (lower.contains('pasta') || lower.contains('noodle')) emoji = '🍝';

    return Container(
      color: NutrifotoColors.primary.withValues(alpha: 0.15),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 28)),
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MacroChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
