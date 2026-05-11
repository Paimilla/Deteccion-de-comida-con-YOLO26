import 'package:flutter/material.dart';

import 'nutrifoto_ui.dart';

class LoadingBlock extends StatelessWidget {
  final String message;

  const LoadingBlock({super.key, this.message = 'Cargando...'});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: NutrifotoColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorBlock extends StatelessWidget {
  final String message;

  const ErrorBlock({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF3A1E35),
        border: Border.all(color: const Color(0xFF8E3B73)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF79C6)),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class EmptyBlock extends StatelessWidget {
  final String message;

  const EmptyBlock({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NutrifotoColors.surface,
        border: Border.all(color: const Color(0xFF2A3B67)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.inbox_outlined, color: NutrifotoColors.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
