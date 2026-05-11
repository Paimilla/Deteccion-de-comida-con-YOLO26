class FeatureFlags {
  final bool aiVisionEnabled;
  final bool barcodeEnabled;
  final bool recipesEnabled;
  final bool voiceEnabled;
  final bool assistantEnabled;
  final bool hydrationEnabled;

  const FeatureFlags({
    this.aiVisionEnabled = true,
    this.barcodeEnabled = true,
    this.recipesEnabled = true,
    this.voiceEnabled = true,
    this.assistantEnabled = true,
    this.hydrationEnabled = true,
  });
}
