import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/nutrition_models.dart';
import '../../domain/models/tracking_models.dart';
import '../../domain/repositories/tracking_repository.dart';

class SharedPrefsTrackingRepository implements TrackingRepository {
  final SharedPreferences _prefs;
  static const String _key = 'nutrifoto_db';

  SharedPrefsTrackingRepository(this._prefs);

  Future<Map<String, dynamic>> _loadDb() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return {
        'entries': <dynamic>[],
        'hydration': <dynamic>[],
        'user_profile': null,
      };
    }
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) {
        return parsed;
      }
    } catch (_) {}
    return {
      'entries': <dynamic>[],
      'hydration': <dynamic>[],
      'user_profile': null,
    };
  }

  Future<void> _saveDb(Map<String, dynamic> db) async {
    await _prefs.setString(_key, jsonEncode(db));
  }

  @override
  Future<void> saveEntry(DiaryEntry entry) async {
    final db = await _loadDb();
    final entries = (db['entries'] as List?) ?? <dynamic>[];
    entries.removeWhere((e) => (e as Map<String, dynamic>)['id'] == entry.id);
    entries.add(_entryToJson(entry));
    db['entries'] = entries;
    await _saveDb(db);
  }

  @override
  Future<void> deleteEntry(String entryId) async {
    final db = await _loadDb();
    final entries = (db['entries'] as List?) ?? <dynamic>[];
    entries.removeWhere((e) => (e as Map<String, dynamic>)['id'] == entryId);
    db['entries'] = entries;
    await _saveDb(db);
  }

  @override
  Future<DiaryEntry?> getEntryById(String entryId) async {
    final db = await _loadDb();
    final entries = (db['entries'] as List?) ?? <dynamic>[];
    for (final raw in entries.whereType<Map>()) {
      final data = raw.cast<String, dynamic>();
      if (data['id']?.toString() == entryId) {
        return _entryFromJson(data);
      }
    }
    return null;
  }

  @override
  Future<List<DiaryEntry>> getEntriesForDay(DateTime day) async {
    final db = await _loadDb();
    final entries = (db['entries'] as List?) ?? <dynamic>[];
    return entries
        .whereType<Map>()
        .map((e) => _entryFromJson(e.cast<String, dynamic>()))
        .where((entry) => _sameDate(entry.timestamp, day))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  @override
  Future<List<DiaryEntry>> getEntriesBetween(DateTime from, DateTime to) async {
    final db = await _loadDb();
    final entries = (db['entries'] as List?) ?? <dynamic>[];
    final fromDay = DateTime(from.year, from.month, from.day);
    final toDay = DateTime(to.year, to.month, to.day, 23, 59, 59);
    return entries
        .whereType<Map>()
        .map((e) => _entryFromJson(e.cast<String, dynamic>()))
        .where((entry) => !entry.timestamp.isBefore(fromDay) && !entry.timestamp.isAfter(toDay))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  @override
  Future<void> saveGoals(NutritionGoals goals) async {
    final db = await _loadDb();
    db['goals'] = {
      'kcal': goals.kcal,
      'protein_g': goals.proteinG,
      'carbs_g': goals.carbsG,
      'fat_g': goals.fatG,
    };
    await _saveDb(db);
  }

  @override
  Future<NutritionGoals> getGoals() async {
    final db = await _loadDb();
    final goals = (db['goals'] as Map?)?.cast<String, dynamic>();
    if (goals == null) {
      return const NutritionGoals(kcal: 2000, proteinG: 120, carbsG: 250, fatG: 70);
    }
    return NutritionGoals(
      kcal: _asDouble(goals['kcal']) ?? 2000,
      proteinG: _asDouble(goals['protein_g']) ?? 120,
      carbsG: _asDouble(goals['carbs_g']) ?? 250,
      fatG: _asDouble(goals['fat_g']) ?? 70,
    );
  }

  @override
  Future<void> addHydration(int milliliters, DateTime timestamp) async {
    final db = await _loadDb();
    final hydration = (db['hydration'] as List?) ?? <dynamic>[];
    hydration.add({'timestamp': timestamp.toIso8601String(), 'ml': milliliters});
    db['hydration'] = hydration;
    await _saveDb(db);
  }

  @override
  Future<int> getHydrationForDay(DateTime day) async {
    final db = await _loadDb();
    final hydration = (db['hydration'] as List?) ?? <dynamic>[];
    var total = 0;
    for (final row in hydration.whereType<Map>()) {
      final data = row.cast<String, dynamic>();
      final ts = DateTime.tryParse(data['timestamp']?.toString() ?? '');
      if (ts != null && _sameDate(ts, day)) {
        total += (data['ml'] as num?)?.toInt() ?? 0;
      }
    }
    return total;
  }

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    final db = await _loadDb();
    db['user_profile'] = {
      'name': profile.name,
      'gender': profile.gender,
      'weight_kg': profile.weightKg,
      'height_cm': profile.heightCm,
      'age': profile.age,
      'exercise_per_week': profile.exercisePerWeek,
      'created_at': profile.createdAt.toIso8601String(),
    };
    await _saveDb(db);
  }

  @override
  Future<UserProfile?> getUserProfile() async {
    final db = await _loadDb();
    final raw = (db['user_profile'] as Map?)?.cast<String, dynamic>();
    if (raw == null) return null;
    return UserProfile(
      name: raw['name']?.toString() ?? '',
      gender: raw['gender']?.toString() ?? 'otro',
      weightKg: _asDouble(raw['weight_kg']) ?? 70,
      heightCm: _asDouble(raw['height_cm']) ?? 170,
      age: (raw['age'] as num?)?.toInt() ?? 25,
      exercisePerWeek: (raw['exercise_per_week'] as num?)?.toInt() ?? 3,
      createdAt: DateTime.tryParse(raw['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  @override
  Future<bool> hasUserProfile() async {
    return (await getUserProfile()) != null;
  }

  @override
  Future<void> deleteUserProfile() async {
    final db = await _loadDb();
    db['user_profile'] = null;
    db['entries'] = <dynamic>[];
    db['hydration'] = <dynamic>[];
    await _saveDb(db);
  }

  Map<String, dynamic> _entryToJson(DiaryEntry entry) {
    return {
      'id': entry.id,
      'timestamp': entry.timestamp.toIso8601String(),
      'meal_slot': entry.mealSlot.name,
      'food': {
        'source': entry.food.source.name,
        'item_id': entry.food.itemId,
        'name_es': entry.food.nameEs,
        'name_en': entry.food.nameEn,
        'portion': {'amount': entry.food.portion.amount, 'unit': entry.food.portion.unit},
        'nutrition': {
          'kcal': entry.food.nutrition.kcal,
          'protein_g': entry.food.nutrition.proteinG,
          'carbs_g': entry.food.nutrition.carbsG,
          'fat_g': entry.food.nutrition.fatG,
        },
        'confidence': entry.food.confidence,
        'image_url': entry.food.imageUrl,
        'metadata': entry.food.metadata,
      },
    };
  }

  DiaryEntry _entryFromJson(Map<String, dynamic> json) {
    final food = (json['food'] as Map?)?.cast<String, dynamic>() ?? {};
    final portion = (food['portion'] as Map?)?.cast<String, dynamic>() ?? {};
    final nutrition = (food['nutrition'] as Map?)?.cast<String, dynamic>() ?? {};
    final source = FoodSource.values.firstWhere((s) => s.name == food['source'], orElse: () => FoodSource.unknown);
    final mealSlot = MealSlot.values.firstWhere((m) => m.name == json['meal_slot'], orElse: () => MealSlot.snack);
    return DiaryEntry(
      id: json['id']?.toString() ?? DateTime.now().toString(),
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      mealSlot: mealSlot,
      food: FoodItem(
        source: source,
        itemId: food['item_id']?.toString() ?? 'item',
        nameEs: food['name_es']?.toString() ?? 'Alimento',
        nameEn: food['name_en']?.toString(),
        portion: Portion(amount: _asDouble(portion['amount']) ?? 100, unit: portion['unit']?.toString() ?? 'g'),
        nutrition: Nutrition(
          kcal: _asDouble(nutrition['kcal']) ?? 0,
          proteinG: _asDouble(nutrition['protein_g']) ?? 0,
          carbsG: _asDouble(nutrition['carbs_g']) ?? 0,
          fatG: _asDouble(nutrition['fat_g']) ?? 0,
        ),
        confidence: _asDouble(food['confidence']) ?? 1,
        imageUrl: food['image_url']?.toString(),
        metadata: (food['metadata'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
    );
  }

  bool _sameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  double? _asDouble(dynamic v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
}
