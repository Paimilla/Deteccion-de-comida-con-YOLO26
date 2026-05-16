import '../models/tracking_models.dart';

abstract class TrackingRepository {
  Stream<void> get onRepositoryUpdated;
  void notifyUpdate();

  Future<void> saveEntry(DiaryEntry entry);
  Future<void> saveEntries(List<DiaryEntry> entries);
  Future<void> deleteEntry(String entryId);
  Future<DiaryEntry?> getEntryById(String entryId);
  Future<List<DiaryEntry>> getEntriesForDay(DateTime day);
  Future<List<DiaryEntry>> getEntriesBetween(DateTime from, DateTime to);

  Future<void> saveGoals(NutritionGoals goals);
  Future<NutritionGoals> getGoals();

  Future<void> addHydration(int milliliters, DateTime timestamp);
  Future<int> getHydrationForDay(DateTime day);

  Future<void> saveUserProfile(UserProfile profile);
  Future<UserProfile?> getUserProfile();
  Future<bool> hasUserProfile();
  Future<void> deleteUserProfile();
}
