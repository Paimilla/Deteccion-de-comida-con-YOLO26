import 'dart:io' as io show File;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart'
    if (dart.library.js_util) 'tflite_stub.dart'
    if (dart.library.html) 'tflite_stub.dart';

import '../../domain/models/nutrition_models.dart';
import '../../domain/repositories/food_provider.dart';

/// Provider para clasificación de comida usando TFLite (YOLOv11)
/// Modelo: best_float16.tflite entrenado con 30 comidas chilenas
///
/// Funciona con dos modos:
/// 1. TFLite (YOLOv11 float16) - Principal
/// 2. Análisis de colores (fallback) - Si TFLite falla
class OnnxVisionProvider implements VisionProvider {
  Interpreter? _interpreter;
  List<String>? _labels;
  bool _isInitialized = false;
  bool _useTflite = false;
  String _tfliteError = '';

  static const String _labelsPath = 'assets/models/labels.txt';
  static const int _inputSize = 640;
  static const double _confidenceThreshold = 0.15; // Bajado para captar más items

  /// Inicializa el provider y carga el modelo TFLite
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🔄 Iniciando provider TFLite...');

      // Cargar etiquetas
      final labelsData = await rootBundle.loadString(_labelsPath);
      _labels = labelsData
          .split('\n')
          .map((l) => l.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      debugPrint('📋 Etiquetas cargadas: ${_labels?.length} clases');

      // Intentar cargar modelo TFLite (Solo en Mobile/Desktop)
      if (!kIsWeb) {
        try {
          await _initializeTflite();
          _useTflite = true;
          debugPrint('✅ Modo TFLite activado (YOLOv11)');
        } catch (e) {
          debugPrint('⚠️ TFLite falló: $e');
          _tfliteError = e.toString();
          _useTflite = false;
        }
      } else {
        debugPrint('🌐 Web detected: TFLite native disabled, using Color Analysis fallback');
        _useTflite = false;
      }

      _isInitialized = true;
    } catch (e, stack) {
      debugPrint('❌ Error inicializando provider: $e');
      _useTflite = false;
      _isInitialized = true;
      _tfliteError = e.toString();
    }
  }

  Future<void> _initializeTflite() async {
    final options = InterpreterOptions()..threads = 4;

    // Load explicitly via rootBundle to bypass fromAsset path bugs
    final modelBytes = await rootBundle.load('assets/models/best_float16.tflite');
    final buffer = modelBytes.buffer.asUint8List();

    _interpreter = Interpreter.fromBuffer(
      buffer,
      options: options,
    );

    // Log tensor info
    final inputTensors = _interpreter!.getInputTensors();
    final outputTensors = _interpreter!.getOutputTensors();

    debugPrint('📊 Input tensors: ${inputTensors.map((t) => '${t.name}: ${t.shape} ${t.type}').join(', ')}');
    debugPrint('📊 Output tensors: ${outputTensors.map((t) => '${t.name}: ${t.shape} ${t.type}').join(', ')}');

    // Allocate tensors
    _interpreter!.allocateTensors();
    debugPrint('✅ TFLite interpreter ready');
  }

  /// Libera recursos
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }

  @override
  Future<FoodItem?> classifyFood(String imagePath) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_useTflite && _interpreter != null) {
      return _classifyWithTflite(imagePath);
    } else {
      return _classifyWithColorAnalysis(imagePath);
    }
  }

  /// Clasificación usando TFLite (YOLOv11)
  Future<FoodItem?> _classifyWithTflite(String imagePath) async {
    try {
      debugPrint('🤖 Analizando con TFLite: $imagePath');

      // 1. Cargar imagen
      final Uint8List imageBytes;
      if (kIsWeb) {
        // En web, imagePath suele ser un Blob URL o similar
        // Para la demo, podemos intentar cargarlo o usar un mock
        return _classifyWithColorAnalysis(imagePath);
      } else {
        imageBytes = await io.File(imagePath).readAsBytes();
      }
      
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // 2. Crop perfect square from center & resize
      final squared = _centerSquare(image, _inputSize);
      final inputBuffer = _preprocessImage(squared);

      // 3. Prepare output buffer
      // YOLOv11 output: [1, 34, 8400] for 30 classes (4 bbox + 30 classes)
      final outputTensor = _interpreter!.getOutputTensor(0);
      final outShape = outputTensor.shape;
      debugPrint('📊 Output shape: $outShape type: ${outputTensor.type}');

      // Create output based on shape
      final output = _createOutputBuffer(outShape);

      // 4. Run inference
      _interpreter!.run(inputBuffer, output);

      // 5. Parse detections with NMS
      final detections = _parseOutput(output, outShape);

      if (detections == null || detections.isEmpty) {
        debugPrint('⚠️ No se detectó comida con confianza > $_confidenceThreshold');
        // Fallback to color analysis
        return _classifyWithColorAnalysis(imagePath);
      }

      // Combine multiple detections
      final classNames = detections.map((d) => d['class_name'] as String).toSet().toList();
      final combinedName = classNames.join(' y ');
      final avgConf = detections.map((d) => d['confidence'] as double).reduce((a, b) => a + b) / detections.length;
      
      debugPrint('✅ TFLite detectó: $combinedName (confianza media ${(avgConf * 100).toStringAsFixed(1)}%)');

      return _createCombinedFoodItem(detections, combinedName, avgConf, imagePath);
    } catch (e, stack) {
      debugPrint('❌ Error en TFLite: $e');
      debugPrint('Stack: $stack');
      return _classifyWithColorAnalysis(imagePath);
    }
  }

  /// Create output buffer matching the model's output shape
  dynamic _createOutputBuffer(List<int> shape) {
    if (shape.length == 3) {
      // [1, X, Y]
      return List.generate(
          shape[0],
          (_) => List.generate(
              shape[1], (_) => List.filled(shape[2], 0.0)));
    } else if (shape.length == 2) {
      // [X, Y]
      return List.generate(shape[0], (_) => List.filled(shape[1], 0.0));
    }
    // Fallback: flat
    return List.filled(shape.reduce((a, b) => a * b), 0.0);
  }

  /// Parse YOLOv11 output using Non-Maximum Suppression (NMS)
  List<Map<String, dynamic>>? _parseOutput(dynamic output, List<int> shape) {
    if (_labels == null || _labels!.isEmpty) return null;

    final numClasses = _labels!.length; // 30

    try {
      List<List<double>> matrix;

      if (shape.length == 3) {
        final batch = output as List;
        final inner = batch[0] as List;
        matrix = inner
            .map((row) => (row as List).map((v) => (v as num).toDouble()).toList())
            .toList();
      } else if (shape.length == 2) {
        final raw = output as List;
        matrix = raw
            .map((row) => (row as List).map((v) => (v as num).toDouble()).toList())
            .toList();
      } else {
        return null;
      }

      final rows = matrix.length;
      final cols = matrix.isNotEmpty ? matrix[0].length : 0;
      
      // Is this a pre-NMS export? (e.g., [1, 300, 6])
      // In this format: [bbox(4), score(1), class_id(1)]
      final isNmsExport = (cols == 6);

      bool transposed = !isNmsExport && ((rows == 4 + numClasses && cols > rows) || (rows < cols));

      final numPredictions = transposed ? cols : rows;
      final predLength = transposed ? rows : cols;

      List<Map<String, dynamic>> allDetections = [];

      for (int i = 0; i < numPredictions; i++) {
        List<double> pred;
        if (transposed) {
          pred = List.generate(predLength, (r) => matrix[r][i]);
        } else {
          pred = matrix[i];
        }

        if (isNmsExport) {
          if (pred.length < 6) continue;
          final confidence = pred[4];
          final classId = pred[5].toInt();
          
          if (confidence >= _confidenceThreshold && classId >= 0 && classId < numClasses) {
            allDetections.add({
              'class_id': classId,
              'class_name': _labels![classId],
              'confidence': confidence,
              'bbox': [pred[0], pred[1], pred[2], pred[3]],
            });
          }
          continue; // Skip the raw logits parsing
        }

        // Standard raw logits parsing
        if (pred.length < 4 + numClasses) continue;

        final classScores = pred.sublist(4, 4 + numClasses);
        int bestClassId = 0;
        double bestScore = classScores[0];
        for (int c = 1; c < numClasses; c++) {
          if (classScores[c] > bestScore) {
            bestScore = classScores[c];
            bestClassId = c;
          }
        }

        final confidence = bestScore > 1 || bestScore < 0
            ? 1.0 / (1.0 + math.exp(-bestScore))
            : bestScore;

        if (confidence >= _confidenceThreshold) {
          allDetections.add({
            'class_id': bestClassId,
            'class_name': _labels![bestClassId],
            'confidence': confidence,
            'bbox': [pred[0], pred[1], pred[2], pred[3]], 
          });
        }
      }

      // Non-Maximum Suppression (NMS)
      // Even if NMS is baked into the export, doing it again is safe and removes duplicates.
      allDetections.sort((a, b) => (b['confidence'] as double).compareTo(a['confidence'] as double));

      // If the model already did NMS natively, skip our manual NMS
      if (isNmsExport) {
        return allDetections;
      }

      List<Map<String, dynamic>> nmsDetections = [];
      
      for (var det in allDetections) {
        bool keep = true;
        for (var keptDet in nmsDetections) {
          final iou = _calculateIoU(det['bbox'], keptDet['bbox']);
          if (iou > 0.45) { // IOU threshold
            keep = false;
            break;
          }
        }
        if (keep) {
          nmsDetections.add(det);
        }
      }

      return nmsDetections;
    } catch (e) {
      debugPrint('❌ Error parsing output: $e');
      return null;
    }
  }

  /// Calculates Intersection over Union (IoU) for two bounding boxes [x, y, w, h]
  double _calculateIoU(List<double> box1, List<double> box2) {
    // YOLO format is [x_center, y_center, width, height]
    final b1x1 = box1[0] - box1[2] / 2;
    final b1y1 = box1[1] - box1[3] / 2;
    final b1x2 = box1[0] + box1[2] / 2;
    final b1y2 = box1[1] + box1[3] / 2;

    final b2x1 = box2[0] - box2[2] / 2;
    final b2y1 = box2[1] - box2[3] / 2;
    final b2x2 = box2[0] + box2[2] / 2;
    final b2y2 = box2[1] + box2[3] / 2;

    final interX1 = math.max(b1x1, b2x1);
    final interY1 = math.max(b1y1, b2y1);
    final interX2 = math.min(b1x2, b2x2);
    final interY2 = math.min(b1y2, b2y2);

    if (interX2 <= interX1 || interY2 <= interY1) return 0.0;

    final interArea = (interX2 - interX1) * (interY2 - interY1);
    final b1Area = box1[2] * box1[3];
    final b2Area = box2[2] * box2[3];

    return interArea / (b1Area + b2Area - interArea);
  }

  /// Center Square crop: Crops the exact middle of the picture then scales to targetSize
  /// Better than letterbox for capturing food because it maximizes resolution.
  img.Image _centerSquare(img.Image src, int targetSize) {
    int minDim = math.min(src.width, src.height);
    int cropX = (src.width - minDim) ~/ 2;
    int cropY = (src.height - minDim) ~/ 2;

    // Crop the central square of the image
    img.Image cropped = img.copyCrop(src, x: cropX, y: cropY, width: minDim, height: minDim);

    // Resize perfectly to the model's required size (e.g. 640x640)
    img.Image resized = img.copyResize(cropped,
        width: targetSize, height: targetSize, interpolation: img.Interpolation.linear);

    debugPrint('📐 CenterCrop: ${src.width}x${src.height} -> [Square] -> ${targetSize}x$targetSize');
    return resized;
  }

  /// Preprocess image to Float32 NHWC buffer [1, 640, 640, 3]
  /// TFLite typically uses NHWC, unlike ONNX which uses NCHW
  List<List<List<List<double>>>> _preprocessImage(img.Image image) {
    // Check what the model expects
    final inputTensor = _interpreter!.getInputTensor(0);
    final inputShape = inputTensor.shape;

    debugPrint('📊 Input shape expected: $inputShape');

    final h = image.height;
    final w = image.width;

    // Determine if NCHW or NHWC
    // NCHW: [1, 3, 640, 640]
    // NHWC: [1, 640, 640, 3]
    if (inputShape.length == 4 && inputShape[1] == 3) {
      // NCHW format
      debugPrint('📐 Using NCHW format');
      return _preprocessNCHW(image, h, w);
    } else {
      // NHWC format (default for TFLite)
      debugPrint('📐 Using NHWC format');
      return _preprocessNHWC(image, h, w);
    }
  }

  List<List<List<List<double>>>> _preprocessNHWC(img.Image image, int h, int w) {
    final result = List.generate(
        1,
        (_) => List.generate(
            h,
            (y) => List.generate(w, (x) {
                  final pixel = image.getPixel(x, y);
                  return [
                    pixel.r / 255.0,
                    pixel.g / 255.0,
                    pixel.b / 255.0,
                  ];
                })));
    return result;
  }

  List<List<List<List<double>>>> _preprocessNCHW(img.Image image, int h, int w) {
    // For NCHW: [1, 3, H, W] — each channel is a 2D HxW array
    final r = List.generate(
        h, (y) => List.generate(w, (x) => image.getPixel(x, y).r / 255.0));
    final g = List.generate(
        h, (y) => List.generate(w, (x) => image.getPixel(x, y).g / 255.0));
    final b = List.generate(
        h, (y) => List.generate(w, (x) => image.getPixel(x, y).b / 255.0));
    return [
      [r, g, b]
    ];
  }

  /// Crea FoodItem combinando multiples detecciones (ej: Pollo y Papas fritas)
  FoodItem _createCombinedFoodItem(
      List<Map<String, dynamic>> detections, String combinedName, double avgConfidence, String imagePath) {
    
    // Sum nutritional values
    double totalKcal = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    double totalPortion = 0;

    for (var det in detections) {
      final className = det['class_name'] as String;
      final nutrition = _getNutritionForFood(className);
      // For calculation let's assume default portions of 150g per item
      final portion = 150.0;
      totalPortion += portion;
      
      totalKcal += nutrition.kcal;
      totalProtein += nutrition.proteinG;
      totalCarbs += nutrition.carbsG;
      totalFat += nutrition.fatG;
    }

    return FoodItem(
      source: FoodSource.aiVision,
      itemId: 'tflite_${DateTime.now().millisecondsSinceEpoch}',
      nameEs: _formatFoodName(combinedName),
      portion: Portion(amount: totalPortion, unit: 'g'),
      nutrition: Nutrition(
        kcal: totalKcal.roundToDouble(),
        proteinG: double.parse(totalProtein.toStringAsFixed(1)),
        carbsG: double.parse(totalCarbs.toStringAsFixed(1)),
        fatG: double.parse(totalFat.toStringAsFixed(1)),
      ),
      confidence: avgConfidence,
      imageUrl: imagePath,
      metadata: {
        'model': 'yolo_v11_tflite_fp16',
        'classes_detected': detections.map((d) => d['class_name'] as String).toList(),
        'method': 'tflite_nms',
      },
    );
  }

  /// Formatea nombre de clase
  String _formatFoodName(String className) {
    return className
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Obtiene información nutricional por clase
  Nutrition _getNutritionForFood(String className) {
    final nutritionData = {
      'arroz': Nutrition(kcal: 130, proteinG: 2.7, carbsG: 28.0, fatG: 0.3),
      'arvejas': Nutrition(kcal: 81, proteinG: 5.4, carbsG: 14.5, fatG: 0.4),
      'brocoli': Nutrition(kcal: 34, proteinG: 2.8, carbsG: 7.0, fatG: 0.4),
      'calzones_rotos':
          Nutrition(kcal: 350, proteinG: 6.0, carbsG: 45.0, fatG: 16.0),
      'carne': Nutrition(kcal: 250, proteinG: 26.0, carbsG: 0.0, fatG: 15.0),
      'cazuela':
          Nutrition(kcal: 150, proteinG: 12.0, carbsG: 15.0, fatG: 5.0),
      'charquican':
          Nutrition(kcal: 180, proteinG: 10.0, carbsG: 20.0, fatG: 6.0),
      'choripan':
          Nutrition(kcal: 300, proteinG: 12.0, carbsG: 30.0, fatG: 15.0),
      'completos':
          Nutrition(kcal: 320, proteinG: 12.0, carbsG: 35.0, fatG: 14.0),
      'durazno': Nutrition(kcal: 39, proteinG: 0.9, carbsG: 9.5, fatG: 0.3),
      'empanada':
          Nutrition(kcal: 280, proteinG: 10.0, carbsG: 30.0, fatG: 13.0),
      'ensalada_a_la_chilena':
          Nutrition(kcal: 45, proteinG: 1.5, carbsG: 8.0, fatG: 1.0),
      'huevos_fritos':
          Nutrition(kcal: 196, proteinG: 13.6, carbsG: 0.8, fatG: 15.0),
      'humitas':
          Nutrition(kcal: 160, proteinG: 4.0, carbsG: 25.0, fatG: 5.0),
      'manzana': Nutrition(kcal: 52, proteinG: 0.3, carbsG: 14.0, fatG: 0.2),
      'mote_con_huesillo':
          Nutrition(kcal: 120, proteinG: 2.0, carbsG: 28.0, fatG: 0.5),
      'naranja': Nutrition(kcal: 47, proteinG: 0.9, carbsG: 12.0, fatG: 0.1),
      'palomitas':
          Nutrition(kcal: 387, proteinG: 12.0, carbsG: 78.0, fatG: 4.5),
      'palta': Nutrition(kcal: 160, proteinG: 2.0, carbsG: 9.0, fatG: 15.0),
      'papas_fritas':
          Nutrition(kcal: 312, proteinG: 3.4, carbsG: 41.0, fatG: 15.0),
      'pasta': Nutrition(kcal: 131, proteinG: 5.0, carbsG: 25.0, fatG: 1.1),
      'pastel_de_choclo':
          Nutrition(kcal: 190, proteinG: 10.0, carbsG: 22.0, fatG: 7.0),
      'pescado frito':
          Nutrition(kcal: 200, proteinG: 20.0, carbsG: 5.0, fatG: 11.0),
      'pizza': Nutrition(kcal: 266, proteinG: 11.0, carbsG: 33.0, fatG: 10.0),
      'platano': Nutrition(kcal: 89, proteinG: 1.1, carbsG: 23.0, fatG: 0.3),
      'pollo': Nutrition(kcal: 165, proteinG: 31.0, carbsG: 0.0, fatG: 3.6),
      'porotos_con_riendas':
          Nutrition(kcal: 140, proteinG: 8.0, carbsG: 22.0, fatG: 2.0),
      'salmon': Nutrition(kcal: 208, proteinG: 20.0, carbsG: 0.0, fatG: 13.0),
      'sopaipillas':
          Nutrition(kcal: 310, proteinG: 5.0, carbsG: 42.0, fatG: 14.0),
      'tiramisu':
          Nutrition(kcal: 240, proteinG: 4.5, carbsG: 28.0, fatG: 12.0),
    };

    return nutritionData[className] ??
        const Nutrition(kcal: 150, proteinG: 8, carbsG: 20, fatG: 5);
  }

  // ============================================================
  // COLOR ANALYSIS FALLBACK
  // ============================================================

  Future<FoodItem?> _classifyWithColorAnalysis(String imagePath) async {
    try {
      debugPrint('📷 Fallback: analizando por colores: $imagePath');

      final Uint8List imageBytes;
      if (kIsWeb) {
        return _mockWebDetection();
      } else {
        imageBytes = await io.File(imagePath).readAsBytes();
      }
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      final colorProfile = _analyzeColors(image);
      debugPrint('🎨 Perfil: $colorProfile');

      final detection = _matchFoodByColor(colorProfile);
      if (detection == null) return null;

      debugPrint(
          '✅ Color match: ${detection.name} (${(detection.confidence * 100).toStringAsFixed(1)}%)');

      return FoodItem(
        source: FoodSource.aiVision,
        itemId: 'color_${DateTime.now().millisecondsSinceEpoch}',
        nameEs: detection.name,
        portion: Portion(amount: detection.portionG, unit: 'g'),
        nutrition: Nutrition(
          kcal: detection.kcal,
          proteinG: detection.protein,
          carbsG: detection.carbs,
          fatG: detection.fat,
        ),
        confidence: detection.confidence,
        imageUrl: imagePath,
        metadata: {
          'method': 'color_analysis',
          'note': 'TFLite no disponible - análisis de colores',
        },
      );
    } catch (e) {
      debugPrint('❌ Error en análisis de colores: $e');
      return null;
    }
  }

  _ColorProfile _analyzeColors(img.Image image) {
    int redSum = 0, greenSum = 0, blueSum = 0;
    int brownCount = 0,
        greenCount = 0,
        whiteCount = 0,
        yellowCount = 0;
    int orangeCount = 0, redCount = 0;
    int sampleCount = 0;

    for (int y = 0; y < image.height; y += 10) {
      for (int x = 0; x < image.width; x += 10) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        redSum += r;
        greenSum += g;
        blueSum += b;
        sampleCount++;

        if (_isBrown(r, g, b)) brownCount++;
        if (_isGreen(r, g, b)) greenCount++;
        if (_isWhite(r, g, b)) whiteCount++;
        if (_isYellow(r, g, b)) yellowCount++;
        if (_isOrange(r, g, b)) orangeCount++;
        if (_isRed(r, g, b)) redCount++;
      }
    }

    if (sampleCount == 0) sampleCount = 1;

    return _ColorProfile(
      avgRed: redSum ~/ sampleCount,
      avgGreen: greenSum ~/ sampleCount,
      avgBlue: blueSum ~/ sampleCount,
      brownRatio: brownCount / sampleCount,
      greenRatio: greenCount / sampleCount,
      whiteRatio: whiteCount / sampleCount,
      yellowRatio: yellowCount / sampleCount,
      orangeRatio: orangeCount / sampleCount,
      redRatio: redCount / sampleCount,
    );
  }

  bool _isBrown(int r, int g, int b) =>
      r > 100 && r < 200 && g > 50 && g < 150 && b < 100;
  bool _isGreen(int r, int g, int b) => g > r && g > b && g > 80;
  bool _isWhite(int r, int g, int b) => r > 200 && g > 200 && b > 200;
  bool _isYellow(int r, int g, int b) => r > 180 && g > 150 && b < 100;
  bool _isOrange(int r, int g, int b) =>
      r > 200 && g > 100 && g < 180 && b < 80;
  bool _isRed(int r, int g, int b) => r > 180 && g < 100 && b < 100;

  _FoodDetection? _matchFoodByColor(_ColorProfile profile) {
    final foodDatabase = [
      _FoodTemplate('Pollo asado',
          brownRatio: 0.45, yellowRatio: 0.25,
          kcal: 165, protein: 31, carbs: 0, fat: 3.6, portion: 120),
      _FoodTemplate('Carne asada',
          brownRatio: 0.55, redRatio: 0.1,
          kcal: 250, protein: 26, carbs: 0, fat: 15, portion: 150),
      _FoodTemplate('Salmón',
          orangeRatio: 0.45, brownRatio: 0.1,
          kcal: 208, protein: 20, carbs: 0, fat: 13, portion: 150),
      _FoodTemplate('Ensalada',
          greenRatio: 0.55, whiteRatio: 0.1,
          kcal: 25, protein: 1.5, carbs: 4, fat: 0.3, portion: 100),
      _FoodTemplate('Brócoli',
          greenRatio: 0.65,
          kcal: 34, protein: 2.8, carbs: 7, fat: 0.4, portion: 100),
      _FoodTemplate('Arroz',
          whiteRatio: 0.6,
          kcal: 130, protein: 2.7, carbs: 28, fat: 0.3, portion: 150),
      _FoodTemplate('Papas fritas',
          yellowRatio: 0.45, brownRatio: 0.2,
          kcal: 312, protein: 3.4, carbs: 41, fat: 15, portion: 130),
      _FoodTemplate('Empanada',
          brownRatio: 0.45, yellowRatio: 0.25,
          kcal: 280, protein: 10, carbs: 30, fat: 13, portion: 180),
      _FoodTemplate('Huevos fritos',
          yellowRatio: 0.45, whiteRatio: 0.35,
          kcal: 196, protein: 14, carbs: 1.2, fat: 15, portion: 100),
      _FoodTemplate('Plátano',
          yellowRatio: 0.65,
          kcal: 89, protein: 1.1, carbs: 23, fat: 0.3, portion: 120),
      _FoodTemplate('Naranja',
          orangeRatio: 0.65,
          kcal: 47, protein: 0.9, carbs: 12, fat: 0.1, portion: 150),
      _FoodTemplate('Pizza',
          yellowRatio: 0.3, redRatio: 0.25, brownRatio: 0.15,
          kcal: 266, protein: 11, carbs: 33, fat: 10, portion: 200),
      _FoodTemplate('Palta',
          greenRatio: 0.5, yellowRatio: 0.2,
          kcal: 160, protein: 2, carbs: 9, fat: 15, portion: 100),
    ];

    _FoodTemplate? bestMatch;
    double bestScore = 0;

    for (final food in foodDatabase) {
      final score = _cosineSimilarity(profile, food);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = food;
      }
    }

    // Log top-3
    final scored = foodDatabase
        .map((f) => MapEntry(f.name, _cosineSimilarity(profile, f)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = scored
        .take(3)
        .map((e) => '${e.key}:${(e.value * 100).toStringAsFixed(1)}%')
        .join(', ');
      debugPrint('🏆 Top-3 color matches: $top3');

    if (bestMatch != null && bestScore > 0.15) {
      final random = math.Random();
      final variation = 0.9 + random.nextDouble() * 0.2;
      
      String debugName = bestMatch.name;

      return _FoodDetection(
        name: debugName,
        confidence: (bestScore * 0.8 + 0.3).clamp(0.55, 0.90),
        kcal: (bestMatch.kcal * variation).round().toDouble(),
        protein: bestMatch.protein * variation,
        carbs: bestMatch.carbs * variation,
        fat: bestMatch.fat * variation,
        portionG: bestMatch.portion.toDouble(),
      );
    }

    String defaultName = 'Plato mixto';

    return _FoodDetection(
      name: defaultName,
      confidence: 0.55,
      kcal: 250,
      protein: 15,
      carbs: 25,
      fat: 10,
      portionG: 200,
    );
  }

  double _cosineSimilarity(_ColorProfile profile, _FoodTemplate food) {
    final imgVec = [
      profile.brownRatio, profile.greenRatio, profile.whiteRatio,
      profile.yellowRatio, profile.orangeRatio, profile.redRatio,
    ];
    final foodVec = [
      food.brownRatio, food.greenRatio, food.whiteRatio,
      food.yellowRatio, food.orangeRatio, food.redRatio,
    ];

    double dot = 0, magA = 0, magB = 0;
    for (int i = 0; i < 6; i++) {
      dot += imgVec[i] * foodVec[i];
      magA += imgVec[i] * imgVec[i];
      magB += foodVec[i] * foodVec[i];
    }
    final denom = math.sqrt(magA) * math.sqrt(magB);
    if (denom < 1e-9) return 0;

    final cosine = dot / denom;
    final totalImg = imgVec.fold<double>(0.0, (a, b) => a + b);
    final totalFood = foodVec.fold<double>(0.0, (a, b) => a + b);
    final magRatio =
        totalFood > 0 ? (totalImg / totalFood).clamp(0.3, 3.0) : 1.0;
    final magPenalty =
        1.0 - ((magRatio - 1.0).abs() * 0.3).clamp(0.0, 0.5);

    return cosine * magPenalty;
  }

  /// Mock para la demo web
  Future<FoodItem> _mockWebDetection() async {
    // Simular retraso de "procesamiento"
    await Future.delayed(const Duration(milliseconds: 800));
    
    return FoodItem(
      source: FoodSource.aiVision,
      itemId: 'web_mock_${DateTime.now().millisecondsSinceEpoch}',
      nameEs: 'Detección Simulada (Web Demo)',
      portion: const Portion(amount: 150, unit: 'g'),
      nutrition: const Nutrition(
        kcal: 245,
        proteinG: 12.5,
        carbsG: 30.0,
        fatG: 8.0,
      ),
      confidence: 0.95,
      metadata: {
        'method': 'web_mock',
        'note': 'IA Nativa desactivada en versión Web'
      },
    );
  }
}

// Helper classes
class _ColorProfile {
  final int avgRed, avgGreen, avgBlue;
  final double brownRatio, greenRatio, whiteRatio, yellowRatio;
  final double orangeRatio, redRatio;

  _ColorProfile({
    required this.avgRed,
    required this.avgGreen,
    required this.avgBlue,
    required this.brownRatio,
    required this.greenRatio,
    required this.whiteRatio,
    required this.yellowRatio,
    this.orangeRatio = 0,
    this.redRatio = 0,
  });

  @override
  String toString() =>
      'brown:${(brownRatio * 100).toStringAsFixed(0)}% '
      'green:${(greenRatio * 100).toStringAsFixed(0)}% '
      'white:${(whiteRatio * 100).toStringAsFixed(0)}% '
      'yellow:${(yellowRatio * 100).toStringAsFixed(0)}% '
      'orange:${(orangeRatio * 100).toStringAsFixed(0)}% '
      'red:${(redRatio * 100).toStringAsFixed(0)}%';
}

class _FoodTemplate {
  final String name;
  final double brownRatio, greenRatio, whiteRatio, yellowRatio;
  final double orangeRatio, redRatio;
  final double kcal, protein, carbs, fat;
  final int portion;

  _FoodTemplate(
    this.name, {
    this.brownRatio = 0,
    this.greenRatio = 0,
    this.whiteRatio = 0,
    this.yellowRatio = 0,
    this.orangeRatio = 0,
    this.redRatio = 0,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.portion,
  });
}

class _FoodDetection {
  final String name;
  final double confidence;
  final double kcal, protein, carbs, fat, portionG;

  _FoodDetection({
    required this.name,
    required this.confidence,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.portionG,
  });
}
