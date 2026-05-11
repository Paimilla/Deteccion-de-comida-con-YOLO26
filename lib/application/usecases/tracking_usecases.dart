import '../../domain/models/nutrition_models.dart';
import '../../domain/models/tracking_models.dart';
import '../../domain/repositories/tracking_repository.dart';

class TrackingUseCases {
  final TrackingRepository repository;

  TrackingUseCases(this.repository);

  Future<void> addFoodEntry({
    required MealSlot mealSlot,
    required FoodItem food,
    DateTime? timestamp,
  }) async {
    final ts = timestamp ?? DateTime.now();

    final existing = await repository.getEntriesForDay(ts);
    final isDuplicate = existing.any((entry) {
      if (entry.mealSlot != mealSlot) {
        return false;
      }

      final sameItem = entry.food.itemId == food.itemId ||
          entry.food.nameEs.trim().toLowerCase() == food.nameEs.trim().toLowerCase();
      if (!sameItem) {
        return false;
      }

      final secondsDiff = entry.timestamp.difference(ts).inSeconds.abs();
      final kcalDiff = (entry.food.nutrition.kcal - food.nutrition.kcal).abs();
      return secondsDiff <= 45 && kcalDiff < 1;
    });

    if (isDuplicate) {
      return;
    }

    final id = '${ts.microsecondsSinceEpoch}_${food.itemId}';
    final entry = DiaryEntry(
      id: id,
      timestamp: ts,
      mealSlot: mealSlot,
      food: food,
    );
    await repository.saveEntry(entry);
  }

  Future<void> removeFoodEntry(String entryId) {
    return repository.deleteEntry(entryId);
  }

  /// Duplicate an existing entry by creating a new one with the same food
  /// and meal slot but a fresh timestamp and ID.
  Future<void> duplicateFoodEntry(DiaryEntry original) async {
    final now = DateTime.now();
    final id = '${now.microsecondsSinceEpoch}_${original.food.itemId}_dup';
    final duplicate = DiaryEntry(
      id: id,
      timestamp: now,
      mealSlot: original.mealSlot,
      food: original.food,
    );
    await repository.saveEntry(duplicate);
  }

  /// Mueve un alimento de un MealSlot a otro (usado por Drag & Drop).
  /// Elimina la entrada original y crea una nueva en el slot destino.
  /// Retorna la entrada eliminada para poder hacer Undo.
  Future<DiaryEntry?> moveFoodEntry({
    required String entryId,
    required MealSlot targetSlot,
  }) async {
    final original = await repository.getEntryById(entryId);
    if (original == null) return null;

    // Si ya está en el mismo slot, no hacer nada
    if (original.mealSlot == targetSlot) return null;

    // Eliminar la original
    await repository.deleteEntry(entryId);

    // Crear nueva entrada en el slot destino
    final now = DateTime.now();
    final id = '${now.microsecondsSinceEpoch}_${original.food.itemId}_moved';
    final moved = DiaryEntry(
      id: id,
      timestamp: original.timestamp,
      mealSlot: targetSlot,
      food: original.food,
    );
    await repository.saveEntry(moved);

    return original; // Retorna la original para Undo
  }

  /// Restaura una entrada previamente eliminada (Undo).
  /// Recibe la DiaryEntry original completa y la vuelve a guardar.
  Future<void> undoDelete(DiaryEntry deletedEntry) async {
    await repository.saveEntry(deletedEntry);
  }

  /// Copia un alimento a otro día y opcionalmente a otro MealSlot.
  Future<void> copyFoodToDay({
    required FoodItem food,
    required DateTime targetDay,
    required MealSlot targetSlot,
  }) async {
    final ts = DateTime(
      targetDay.year,
      targetDay.month,
      targetDay.day,
      12, 0, 0, // Hora genérica del mediodía
    );
    final id = '${ts.microsecondsSinceEpoch}_${food.itemId}_copy';
    final entry = DiaryEntry(
      id: id,
      timestamp: ts,
      mealSlot: targetSlot,
      food: food,
    );
    await repository.saveEntry(entry);
  }

  Future<DailySummary> getDailySummary(DateTime day) async {
    final entries = await repository.getEntriesForDay(day);
    final goals = await repository.getGoals();
    final hydrationMl = await repository.getHydrationForDay(day);

    return DailySummary(
      day: DateTime(day.year, day.month, day.day),
      entries: entries,
      goals: goals,
      hydrationMl: hydrationMl,
    );
  }

  Future<void> setNutritionGoals(NutritionGoals goals) {
    return repository.saveGoals(goals);
  }

  Future<void> addHydrationMl(int ml, {DateTime? timestamp}) {
    return repository.addHydration(ml, timestamp ?? DateTime.now());
  }

  Future<void> saveUserProfile(UserProfile profile) {
    return repository.saveUserProfile(profile);
  }

  Future<UserProfile?> getUserProfile() {
    return repository.getUserProfile();
  }

  Future<bool> hasUserProfile() {
    return repository.hasUserProfile();
  }

  Future<void> clearUserProfile() async {
    await repository.deleteUserProfile();
  }
}
