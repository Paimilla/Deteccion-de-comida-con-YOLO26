import 'dart:convert';

import '../infrastructure/services/api_config.dart';
import 'food_orchestrator.dart';
import 'orchestrator_factory.dart';

class OrchestratorBuilder {
  static Future<FoodOrchestrator> build({
    required ApiConfig config,
    required String chileDatasetJson,
  }) async {
    final dataset = jsonDecode(chileDatasetJson) as Map<String, dynamic>;

    return OrchestratorFactory.create(
      config: config,
      chileDataset: dataset,
    );
  }
}
