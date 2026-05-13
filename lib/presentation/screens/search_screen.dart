import 'package:flutter/material.dart';

import '../../application/app_routes.dart';
import '../../application/app_services.dart';
import '../../domain/models/nutrition_models.dart';
import '../../domain/models/tracking_models.dart';
import '../widgets/animated_screen_body.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_notifier.dart';
import '../widgets/feedback_widgets.dart';
import '../widgets/nutrifoto_ui.dart';

class SearchScreen extends StatefulWidget {
  final AppServices services;

  const SearchScreen({super.key, required this.services});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryCtrl = TextEditingController();
  bool _loading = false;
  bool _saving = false;
  MealSlot _mealSlot = MealSlot.almuerzo;
  bool _argsApplied = false;
  List<FoodItem> _results = const [];
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsApplied) {
      return;
    }
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['mealSlot'] is MealSlot) {
      _mealSlot = args['mealSlot'] as MealSlot;
    }
    _argsApplied = true;
  }

  void _showFoodDetail(FoodItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FoodDetailSheet(
        item: item,
        mealSlot: _mealSlot,
        onSave: (finalItem) async {
          if (_saving) return;
          setState(() => _saving = true);
          await widget.services.trackingUseCases.addFoodEntry(
            mealSlot: _mealSlot,
            food: finalItem,
          );
          if (mounted) {
            setState(() => _saving = false);
            AppNotifier.success(context, '${finalItem.nameEs} guardado');
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty) {
      setState(() => _error = 'Ingresa una busqueda');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _results = const [];
    });

    final items = await widget.services.foodOrchestrator.searchFoodInSpanish(q);
    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
      _results = items;
      if (items.isEmpty) {
        _error = 'Sin resultados';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width < 360 ? 12.0 : 16.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Buscador de Alimentos')),
      bottomNavigationBar: const AppBottomNav(currentRoute: AppRoutes.explorar),
      body: AnimatedScreenBody(
        child: ListView(
          padding: EdgeInsets.all(horizontalPadding),
          children: [
            HeroPanel(
              title: 'Buscador',
              subtitle: 'Encuentra cualquier alimento y ajusta su porción',
              gradient: NutrifotoColors.searchGradient,
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Búsqueda Global',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: NutrifotoColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _queryCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Buscar alimento',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _search,
                      icon: const Icon(Icons.search),
                      label: Text(_loading ? 'Buscando...' : 'Buscar'),
                    ),
                  ),
                  if (_loading) ...[
                    const SizedBox(height: 12),
                    ...List.generate(3, (index) => const SkeletonCard()),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<MealSlot>(
                    initialValue: _mealSlot,
                    decoration: const InputDecoration(
                      labelText: 'Bloque comida para guardar',
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
            if (_error != null) ...[ErrorBlock(message: _error!)],
            const SizedBox(height: 8),
            if (!_loading && _results.isEmpty && _error == null)
              const EmptyBlock(
                message: 'Busca un alimento para ver resultados.',
              ),
            ..._results.map(
              (item) => _FoodResultCard(
                item: item,
                saving: _saving,
                onTap: () => _showFoodDetail(item),
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
  final VoidCallback onTap;

  const _FoodResultCard({
    required this.item,
    required this.saving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  child: AspectRatio(
                    aspectRatio: 1.5, // Slightly smaller than recipes but still large
                    child: NutrifotoImage(
                      imageUrl: item.imageUrl,
                      name: item.nameEs,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: NutrifotoColors.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                    ),
                    child: Text(
                      '${item.nutrition.kcal.round()} Kcal',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      item.source.name.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nameEs,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, height: 1.1, letterSpacing: -0.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.metadata['short_description_es'] ?? 'Un alimento nutritivo detectado en la búsqueda global.',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _MacroDot(label: 'PROT', value: item.nutrition.proteinG, target: 176, color: Colors.blue),
                      _MacroDot(label: 'CARB', value: item.nutrition.carbsG, target: 231, color: Colors.green),
                      _MacroDot(label: 'GRAS', value: item.nutrition.fatG, target: 63, color: Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('CONFIGURAR PORCIÓN', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5)),
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                        foregroundColor: isDark ? Colors.white : Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                        ),
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

class _MacroDot extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final Color color;

  const _MacroDot({
    required this.label,
    required this.value,
    required this.target,
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
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                value: percent,
                strokeWidth: 3.5,
                backgroundColor: color.withValues(alpha: isDark ? 0.1 : 0.05),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            Text(
              '${(percent * 100).toInt()}%',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${value.round()}g',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Detail Sheet for Search Results
// ═══════════════════════════════════════════════════════════════════════════════

class _FoodDetailSheet extends StatefulWidget {
  final FoodItem item;
  final MealSlot mealSlot;
  final Function(FoodItem) onSave;
  const _FoodDetailSheet({required this.item, required this.mealSlot, required this.onSave});

  @override
  State<_FoodDetailSheet> createState() => _FoodDetailSheetState();
}

class _FoodDetailSheetState extends State<_FoodDetailSheet> {
  late double _grams;
  late MealSlot _selectedSlot;

  @override
  void initState() {
    super.initState();
    _grams = widget.item.portion.amount;
    _selectedSlot = widget.mealSlot;
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _grams / widget.item.portion.amount;
    final kcal = widget.item.nutrition.kcal * ratio;
    final protein = widget.item.nutrition.proteinG * ratio;
    final carbs = widget.item.nutrition.carbsG * ratio;
    final fat = widget.item.nutrition.fatG * ratio;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: NutrifotoColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: NutrifotoImage(imageUrl: widget.item.imageUrl, name: widget.item.nameEs),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.item.nameEs, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(
                        widget.item.metadata['short_description_es'] ?? widget.item.source.name.toUpperCase(),
                        style: const TextStyle(color: NutrifotoColors.primary, fontSize: 13, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text('Cantidad: ${_grams.round()} g', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: NutrifotoColors.primary)),
            Slider(
              value: _grams,
              min: 5,
              max: 1000,
              divisions: 199,
              activeColor: NutrifotoColors.primary,
              onChanged: (val) => setState(() => _grams = val),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CircularMacro(
                    label: 'Calorías',
                    value: kcal,
                    unit: 'kcal',
                    target: 2200,
                    color: Colors.orange,
                  ),
                  _CircularMacro(
                    label: 'Prot',
                    value: protein,
                    unit: 'g',
                    target: 176,
                    color: Colors.blue,
                  ),
                  _CircularMacro(
                    label: 'Carb',
                    value: carbs,
                    unit: 'g',
                    target: 231,
                    color: Colors.green,
                  ),
                  _CircularMacro(
                    label: 'Gras',
                    value: fat,
                    unit: 'g',
                    target: 63,
                    color: Colors.red,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('Agregar a:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: MealSlot.values.map((slot) => ChoiceChip(
                label: Text(slot.label),
                selected: _selectedSlot == slot,
                onSelected: (val) => setState(() => _selectedSlot = slot),
              )).toList(),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: () {
                  final finalItem = FoodItem(
                    source: widget.item.source,
                    itemId: widget.item.itemId,
                    nameEs: widget.item.nameEs,
                    portion: Portion(amount: _grams, unit: 'g'),
                    nutrition: Nutrition(kcal: kcal, proteinG: protein, carbsG: carbs, fatG: fat),
                    imageUrl: widget.item.imageUrl,
                  );
                  widget.onSave(finalItem);
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: NutrifotoColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Guardar Alimento', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
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

// _MacroChip ha sido movido a nutrifoto_ui.dart como MacroChip (global)
