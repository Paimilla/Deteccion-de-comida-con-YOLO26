import '../domain/models/tracking_models.dart';

/// A simple singleton-like service to hold the copied food entry for copy/paste functionality.
class MealClipboard {
  static DiaryEntry? _copiedEntry;

  static void copy(DiaryEntry entry) {
    _copiedEntry = entry;
  }

  static DiaryEntry? get copiedEntry => _copiedEntry;

  static bool get hasData => _copiedEntry != null;

  static void clear() {
    _copiedEntry = null;
  }
}
