import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/tracking_models.dart';
import 'nutrifoto_ui.dart';

/// A swipeable food card that supports swipe-to-delete (left)
/// and swipe-to-duplicate (right) gestures.
class SwipeableFoodCard extends StatelessWidget {
  final DiaryEntry entry;
  final Color accentColor;
  final VoidCallback? onDelete;
  final VoidCallback? onDuplicate;
  final VoidCallback? onTapSubstitute;

  const SwipeableFoodCard({
    super.key,
    required this.entry,
    required this.accentColor,
    this.onDelete,
    this.onDuplicate,
    this.onTapSubstitute,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.82)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72);

    final imageUrl = entry.food.imageUrl;
    ImageProvider? provider;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      provider = imageUrl.startsWith('http')
          ? NetworkImage(imageUrl)
          : FileImage(File(imageUrl));
    }

    final nutrition = entry.food.nutrition;

    final card = Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Swipe left → Delete
          HapticFeedback.mediumImpact();
          return true;
        } else if (direction == DismissDirection.startToEnd) {
          // Swipe right → Duplicate
          HapticFeedback.lightImpact();
          onDuplicate?.call();
          return false;
        }
        return false;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          onDelete?.call();
        }
      },
      background: _buildSwipeBackground(
        alignment: Alignment.centerLeft,
        color: NutrifotoColors.accentBlue,
        icon: Icons.copy_rounded,
        label: 'Duplicar',
      ),
      secondaryBackground: _buildSwipeBackground(
        alignment: Alignment.centerRight,
        color: const Color(0xFFFF4D4D),
        icon: Icons.delete_outline_rounded,
        label: 'Eliminar',
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            // Food image/icon
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                image: provider != null
                    ? DecorationImage(image: provider, fit: BoxFit.cover)
                    : null,
              ),
              child: provider == null
                  ? Icon(Icons.flatware_rounded,
                      color: Colors.white.withValues(alpha: 0.7), size: 20)
                  : null,
            ),
            const SizedBox(width: 10),
            // Name + nutrients
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.food.nameEs,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${nutrition.kcal.toStringAsFixed(0)} kcal  •  P ${nutrition.proteinG.toStringAsFixed(1)}g  •  C ${nutrition.carbsG.toStringAsFixed(1)}g  •  G ${nutrition.fatG.toStringAsFixed(1)}g',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: subtitleColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Substitute button
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
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    color: NutrifotoColors.primary,
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return LongPressDraggable<DiaryEntry>(
      data: entry,
      delay: const Duration(milliseconds: 250),
      hapticFeedbackOnStart: true,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.8,
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width - 32, // approx width
            child: card,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: card,
      ),
      child: card,
    );
  }

  Widget _buildSwipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
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
        children: alignment == Alignment.centerRight
            ? [
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const SizedBox(width: 6),
                Icon(icon, color: color, size: 22),
              ]
            : [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ],
      ),
    );
  }
}
