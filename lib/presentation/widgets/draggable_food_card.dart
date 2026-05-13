import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' as io show File;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/tracking_models.dart';
import 'nutrifoto_ui.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// DraggableFoodCard — Widget arrastrable con LongPressDraggable + menú 3 puntos
// ═══════════════════════════════════════════════════════════════════════════════
// Permite al usuario:
//  • Mantener presionado para arrastrar (Drag & Drop entre MealSlots)
//  • Menú de 3 puntos con: Copiar a otro día, Favorito, Editar porción
//  • Swipe izquierda = eliminar, Swipe derecha = duplicar (delegado al Dismissible padre)
// ═══════════════════════════════════════════════════════════════════════════════

class DraggableFoodCard extends StatelessWidget {
  final DiaryEntry entry;
  final Color accentColor;

  /// Callbacks para acciones del menú de 3 puntos
  final VoidCallback? onDelete;
  final VoidCallback? onDuplicate;
  final VoidCallback? onTapSubstitute;
  final VoidCallback? onCopyToOtherDay;
  final VoidCallback? onSaveAsFavorite;
  final VoidCallback? onEditPortion;

  const DraggableFoodCard({
    super.key,
    required this.entry,
    required this.accentColor,
    this.onDelete,
    this.onDuplicate,
    this.onTapSubstitute,
    this.onCopyToOtherDay,
    this.onSaveAsFavorite,
    this.onEditPortion,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Widget base que se muestra en reposo y en el DragTarget ──
    final cardContent = _FoodCardContent(
      entry: entry,
      accentColor: accentColor,
      isDark: isDark,
      onTapSubstitute: onTapSubstitute,
      onCopyToOtherDay: onCopyToOtherDay,
      onSaveAsFavorite: onSaveAsFavorite,
      onEditPortion: onEditPortion,
    );

    // ── Envolvemos en Dismissible para swipe-to-delete / swipe-to-duplicate ──
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          HapticFeedback.mediumImpact();
          return true; // Confirma eliminación
        } else if (direction == DismissDirection.startToEnd) {
          HapticFeedback.lightImpact();
          onDuplicate?.call();
          return false; // No dismiss, solo duplica
        }
        return false;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          onDelete?.call();
        }
      },
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        color: NutrifotoColors.accentBlue,
        icon: Icons.copy_rounded,
        label: 'Duplicar',
      ),
      secondaryBackground: _SwipeBackground(
        alignment: Alignment.centerRight,
        color: const Color(0xFFFF4D4D),
        icon: Icons.delete_outline_rounded,
        label: 'Eliminar',
      ),
      // ── LongPressDraggable: mantener presionado para arrastrar ──
      child: LongPressDraggable<DiaryEntry>(
        data: entry,
        delay: const Duration(milliseconds: 300),
        hapticFeedbackOnStart: true,
        onDragStarted: () {
          HapticFeedback.mediumImpact();
        },
        // Widget fantasma que sigue al dedo
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: Opacity(
              opacity: 0.85,
              child: Transform.scale(
                scale: 1.05,
                child: _FoodCardContent(
                  entry: entry,
                  accentColor: accentColor,
                  isDark: isDark,
                  elevated: true,
                ),
              ),
            ),
          ),
        ),
        // Widget que queda en el lugar original (atenuado)
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: cardContent,
        ),
        child: cardContent,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _FoodCardContent — Contenido visual del card de alimento
// ═══════════════════════════════════════════════════════════════════════════════

class _FoodCardContent extends StatelessWidget {
  final DiaryEntry entry;
  final Color accentColor;
  final bool isDark;
  final bool elevated;
  final VoidCallback? onTapSubstitute;
  final VoidCallback? onCopyToOtherDay;
  final VoidCallback? onSaveAsFavorite;
  final VoidCallback? onEditPortion;

  const _FoodCardContent({
    required this.entry,
    required this.accentColor,
    required this.isDark,
    this.elevated = false,
    this.onTapSubstitute,
    this.onCopyToOtherDay,
    this.onSaveAsFavorite,
    this.onEditPortion,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.82)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72);

    final imageUrl = entry.food.imageUrl;
    ImageProvider? provider;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('http')) {
        provider = NetworkImage(imageUrl);
      } else if (!kIsWeb) {
        provider = FileImage(io.File(imageUrl));
      }
    }

    final nutrition = entry.food.nutrition;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // ── Imagen/ícono del alimento ──
          Semantics(
            label: 'Imagen de ${entry.food.nameEs}',
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                image: provider != null ? DecorationImage(image: provider, fit: BoxFit.cover) : null,
              ),
              child: provider == null
                  ? Icon(Icons.flatware_rounded, color: Colors.white.withValues(alpha: 0.7), size: 20)
                  : null,
            ),
          ),
          const SizedBox(width: 10),

          // ── Nombre + nutrientes ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.food.nameEs,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: titleColor, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${nutrition.kcal.toStringAsFixed(0)} kcal  •  '
                  'P ${nutrition.proteinG.toStringAsFixed(1)}g  •  '
                  'C ${nutrition.carbsG.toStringAsFixed(1)}g  •  '
                  'G ${nutrition.fatG.toStringAsFixed(1)}g',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: subtitleColor, fontWeight: FontWeight.w500, fontSize: 11),
                ),
              ],
            ),
          ),

          // ── Botón de sustitución ──
          if (onTapSubstitute != null)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onTapSubstitute!();
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: NutrifotoColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.swap_horiz_rounded, color: NutrifotoColors.primary, size: 18),
              ),
            ),
          const SizedBox(width: 4),

          // ── Menú de 3 puntos ──
          if (onCopyToOtherDay != null || onSaveAsFavorite != null || onEditPortion != null)
            _ThreeDotsMenu(
              onCopyToOtherDay: onCopyToOtherDay,
              onSaveAsFavorite: onSaveAsFavorite,
              onEditPortion: onEditPortion,
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _ThreeDotsMenu — Menú contextual de 3 puntos
// ═══════════════════════════════════════════════════════════════════════════════

class _ThreeDotsMenu extends StatelessWidget {
  final VoidCallback? onCopyToOtherDay;
  final VoidCallback? onSaveAsFavorite;
  final VoidCallback? onEditPortion;

  const _ThreeDotsMenu({
    this.onCopyToOtherDay,
    this.onSaveAsFavorite,
    this.onEditPortion,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        color: Colors.white.withValues(alpha: 0.6),
        size: 20,
      ),
      tooltip: 'Opciones del alimento',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: NutrifotoColors.surface,
      elevation: 8,
      offset: const Offset(0, 40),
      onSelected: (value) {
        HapticFeedback.lightImpact();
        switch (value) {
          case 'copy_day':
            onCopyToOtherDay?.call();
            break;
          case 'favorite':
            onSaveAsFavorite?.call();
            break;
          case 'edit_portion':
            onEditPortion?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'copy_day',
          child: Row(
            children: [
              Icon(Icons.date_range_rounded, size: 18, color: NutrifotoColors.accentBlue),
              SizedBox(width: 10),
              Text('Copiar a otro día', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'favorite',
          child: Row(
            children: [
              Icon(Icons.favorite_border_rounded, size: 18, color: Color(0xFFFF6B6B)),
              SizedBox(width: 10),
              Text('Guardar como favorito', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'edit_portion',
          child: Row(
            children: [
              Icon(Icons.straighten_rounded, size: 18, color: NutrifotoColors.primary),
              SizedBox(width: 10),
              Text('Editar porción rápida', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _SwipeBackground — Fondo de swipe (eliminar/duplicar)
// ═══════════════════════════════════════════════════════════════════════════════

class _SwipeBackground extends StatelessWidget {
  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final children = [
      Icon(icon, color: color, size: 22),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: alignment == Alignment.centerRight ? children.reversed.toList() : children,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MealSlotDragTarget — Zona de "soltado" para un bloque de comida
// ═══════════════════════════════════════════════════════════════════════════════
// Envuelve cada sección de MealSlot en la PlanScreen. Cuando el usuario suelta
// un DiaryEntry aquí, se dispara onFoodDropped con el entry original.

class MealSlotDragTarget extends StatefulWidget {
  final MealSlot targetSlot;
  final LinearGradient gradient;
  final Widget child;

  /// Se llama cuando un DiaryEntry es soltado en esta zona.
  /// Recibe el entry original para que la pantalla padre ejecute la lógica de mover.
  final void Function(DiaryEntry droppedEntry) onFoodDropped;

  const MealSlotDragTarget({
    super.key,
    required this.targetSlot,
    required this.gradient,
    required this.child,
    required this.onFoodDropped,
  });

  @override
  State<MealSlotDragTarget> createState() => _MealSlotDragTargetState();
}

class _MealSlotDragTargetState extends State<MealSlotDragTarget> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<DiaryEntry>(
      // Solo aceptamos si el entry viene de un MealSlot distinto
      onWillAcceptWithDetails: (details) {
        final entry = details.data;
        final accepts = entry.mealSlot != widget.targetSlot;
        if (accepts && !_isHovering) {
          HapticFeedback.selectionClick();
          setState(() => _isHovering = true);
        }
        return accepts;
      },
      onLeave: (_) {
        if (_isHovering) {
          setState(() => _isHovering = false);
        }
      },
      onAcceptWithDetails: (details) {
        HapticFeedback.heavyImpact();
        setState(() => _isHovering = false);
        widget.onFoodDropped(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: _isHovering
                ? Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2.5)
                : null,
            boxShadow: _isHovering
                ? [
                    BoxShadow(
                      color: widget.gradient.colors.first.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: widget.child,
        );
      },
    );
  }
}
