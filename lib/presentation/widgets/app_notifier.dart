import 'package:flutter/material.dart';

class AppNotifier {
  static void success(BuildContext context, String message) {
    _show(context, message, const Color(0xFF12B886));
  }

  static void info(BuildContext context, String message) {
    _show(context, message, const Color(0xFF3B82F6));
  }

  static void error(BuildContext context, String message) {
    _show(context, message, const Color(0xFFE03131));
  }

  static void _show(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
