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

  Future<void> _saveItem(FoodItem item) async {
    if (_saving) {
      return;
    }
    
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);

    await widget.services.trackingUseCases.addFoodEntry(
      mealSlot: _mealSlot,
      food: item,
    );

    if (!mounted) {
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _saving = false);
    AppNotifier.success(
      context,
      '${item.nameEs} agregado en ${_mealSlot.label}',
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
      appBar: AppBar(title: const Text('Comidas y Recetas')),
      bottomNavigationBar: const AppBottomNav(currentRoute: AppRoutes.explorar),
      body: AnimatedScreenBody(
        child: ListView(
          padding: EdgeInsets.all(horizontalPadding),
          children: [
            HeroPanel(
              title: 'Buscar Alimentos',
              subtitle: 'Consulta por nombre y guarda en tu dia',
              gradient: NutrifotoColors.searchGradient,
              trailing: IconButton.filledTonal(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.recipes),
                icon: const Icon(Icons.menu_book_outlined),
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _ModeTag(label: 'Alimentos', selected: true),
                      _ModeTag(label: 'Recetas', selected: false),
                    ],
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
                  if (_loading)
                    const LoadingBlock(message: 'Consultando alimentos...'),
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
              (item) => GlassCard(
                margin: const EdgeInsets.only(top: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: NutrifotoColors.primary.withValues(
                          alpha: 0.2,
                        ),
                        child: const Icon(Icons.restaurant_menu, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.nameEs,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _MacroChip(
                                  label: '${item.nutrition.kcal.toInt()} kcal',
                                  color: Colors.deepOrange,
                                ),
                                _MacroChip(
                                  label: 'P ${item.nutrition.proteinG.toInt()}g',
                                  color: Colors.blue,
                                ),
                                _MacroChip(
                                  label: 'C ${item.nutrition.carbsG.toInt()}g',
                                  color: Colors.green,
                                ),
                                _MacroChip(
                                  label: 'G ${item.nutrition.fatG.toInt()}g',
                                  color: Colors.red.shade300,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        label: 'Agregar ${item.nameEs} al diario',
                        child: IconButton(
                          onPressed: _saving ? null : () => _saveItem(item),
                          icon: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.add_circle_outline),
                          tooltip: 'Agregar al diario',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MacroChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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

class _ModeTag extends StatelessWidget {
  final String label;
  final bool selected;

  const _ModeTag({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? NutrifotoColors.primary.withValues(alpha: 0.3)
            : (isDark
                  ? NutrifotoColors.surfaceSoft
                  : Theme.of(context).colorScheme.surfaceContainerHighest),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected
              ? Colors.black87
              : (isDark ? Colors.white : Colors.black87),
        ),
      ),
    );
  }
}
