import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifoto_app/application/usecases/tracking_usecases.dart';
import 'package:nutrifoto_app/domain/models/nutrition_models.dart';
import 'package:nutrifoto_app/domain/models/tracking_models.dart';
import 'package:nutrifoto_app/domain/repositories/tracking_repository.dart';

class FakeTrackingRepository implements TrackingRepository {
  final List<DiaryEntry> entries = [];
  NutritionGoals goals = const NutritionGoals(kcal: 2000, proteinG: 100, carbsG: 200, fatG: 60);

  @override
  Stream<void> get onRepositoryUpdated => const Stream.empty();
  
  @override
  void notifyUpdate() {}

  @override
  Future<void> saveEntry(DiaryEntry entry) async {
    entries.add(entry);
  }

  @override
  Future<void> saveEntries(List<DiaryEntry> items) async {
    entries.addAll(items);
  }

  @override
  Future<List<DiaryEntry>> getEntriesForDay(DateTime day) async {
    return entries.where((e) => 
      e.timestamp.year == day.year && 
      e.timestamp.month == day.month && 
      e.timestamp.day == day.day
    ).toList();
  }

  @override
  Future<void> deleteEntry(String id) async {
    entries.removeWhere((e) => e.id == id);
  }

  @override
  Future<DiaryEntry?> getEntryById(String id) async {
    try {
      return entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<NutritionGoals> getGoals() async => goals;
  
  @override
  Future<List<DiaryEntry>> getEntriesBetween(DateTime from, DateTime to) async {
    return entries.where((e) => 
      !e.timestamp.isBefore(from) && !e.timestamp.isAfter(to)
    ).toList();
  }

  @override
  Future<void> saveGoals(NutritionGoals g) async => goals = g;

  @override
  Future<void> addHydration(int ml, DateTime ts) async {}
  @override
  Future<int> getHydrationForDay(DateTime d) async => 0;
  @override
  Future<void> saveUserProfile(UserProfile p) async {}
  @override
  Future<UserProfile?> getUserProfile() async => null;
  @override
  Future<bool> hasUserProfile() async => false;
  @override
  Future<void> deleteUserProfile() async {}
}

void main() {
  late TrackingUseCases useCases;
  late FakeTrackingRepository repository;

  setUp(() {
    repository = FakeTrackingRepository();
    useCases = TrackingUseCases(repository);
  });

  test('Should add a food entry', () async {
    final food = FoodItem(
      source: FoodSource.localChile,
      itemId: 'test_1',
      nameEs: 'Manzana',
      portion: const Portion(amount: 1, unit: 'unidad'),
      nutrition: const Nutrition(kcal: 50, proteinG: 0, carbsG: 12, fatG: 0),
    );

    await useCases.addFoodEntry(mealSlot: MealSlot.desayuno, food: food);

    expect(repository.entries.length, 1);
    expect(repository.entries.first.food.nameEs, 'Manzana');
  });

  test('Should not add duplicate entry within 45 seconds', () async {
    final food = FoodItem(
      source: FoodSource.localChile,
      itemId: 'test_1',
      nameEs: 'Manzana',
      portion: const Portion(amount: 1, unit: 'unidad'),
      nutrition: const Nutrition(kcal: 50, proteinG: 0, carbsG: 12, fatG: 0),
    );

    final now = DateTime.now();
    await useCases.addFoodEntry(mealSlot: MealSlot.desayuno, food: food, timestamp: now);
    await useCases.addFoodEntry(mealSlot: MealSlot.desayuno, food: food, timestamp: now.add(const Duration(seconds: 10)));

    expect(repository.entries.length, 1);
  });

  test('Should move entry between slots', () async {
    final food = FoodItem(
      source: FoodSource.localChile,
      itemId: 'test_1',
      nameEs: 'Cafe',
      portion: const Portion(amount: 1, unit: 'taza'),
      nutrition: const Nutrition(kcal: 2, proteinG: 0, carbsG: 0.5, fatG: 0),
    );

    await useCases.addFoodEntry(mealSlot: MealSlot.desayuno, food: food);
    final entry = repository.entries.first;
    
    await useCases.moveFoodEntry(entryId: entry.id, targetSlot: MealSlot.snack);

    expect(repository.entries.length, 1);
    expect(repository.entries.first.mealSlot, MealSlot.snack);
  });
}
