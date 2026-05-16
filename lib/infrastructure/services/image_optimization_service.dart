import 'package:flutter/foundation.dart';

/// Servicio de optimización de imágenes para carga rápida
class ImageOptimizationService {
  
  /// Convierte URL de imagen a versión optimizada con parámetros de compresión
  /// Soporta Unsplash, URLs genéricas con query params
  static String optimizeImageUrl(String? originalUrl, {
    int width = 400,
    int quality = 80,
  }) {
    if (originalUrl == null || originalUrl.isEmpty) {
      return '';
    }

    // Si es URL de Unsplash, optimizar con parámetros nativos
    if (originalUrl.contains('unsplash.com')) {
      return _optimizeUnsplashUrl(originalUrl, width: width, quality: quality);
    }

    // Para otras URLs, mantener como está pero con caché
    return originalUrl;
  }

  /// Optimiza URLs de Unsplash específicamente
  static String _optimizeUnsplashUrl(
    String url, {
    int width = 400,
    int quality = 80,
  }) {
    // Si ya tiene parámetros, reemplazar
    if (url.contains('?')) {
      // Remover parámetros anteriores
      url = url.split('?').first;
    }

    // Agregar parámetros de optimización
    // Unsplash soporta: w (width), q (quality), auto (auto format)
    return '$url?w=$width&q=$quality&auto=format&fit=crop';
  }

  /// Obtiene URL de thumbnail (versión pequeña para previews)
  static String getThumbnailUrl(String? imageUrl, {int size = 200}) {
    if (imageUrl == null || imageUrl.isEmpty) return '';
    
    if (imageUrl.contains('unsplash.com')) {
      return _optimizeUnsplashUrl(imageUrl, width: size, quality: 75);
    }
    
    return imageUrl;
  }

  /// Obtiene URL de tamaño completo (para displaying)
  static String getFullImageUrl(String? imageUrl, {int width = 600}) {
    if (imageUrl == null || imageUrl.isEmpty) return '';
    
    if (imageUrl.contains('unsplash.com')) {
      return _optimizeUnsplashUrl(imageUrl, width: width, quality: 90);
    }
    
    return imageUrl;
  }

  /// Calcula tamaño óptimo basado en context de pantalla
  static int getOptimalImageWidth(double screenWidth) {
    if (screenWidth < 400) return 300;
    if (screenWidth < 600) return 400;
    if (screenWidth < 900) return 600;
    return 800;
  }

  /// Valida si URL es válida para descargar
  static bool isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    
    try {
      Uri.parse(url);
      return url.startsWith('http://') || url.startsWith('https://');
    } catch (_) {
      return false;
    }
  }

  /// Obtiene placeholder color según tipo de comida
  static String getPlaceholderColorForMealType(String? mealTypeHint) {
    // Retorna color en formato hex
    switch (mealTypeHint?.toLowerCase()) {
      case 'desayuno':
        return '#FFA726'; // Naranja
      case 'almuerzo':
        return '#66BB6A'; // Verde
      case 'cena':
        return '#5C6BC0'; // Azul
      case 'once':
        return '#AB47BC'; // Púrpura
      case 'snack':
        return '#FF6E40'; // Rojo-naranja
      default:
        return '#8F62FF'; // Purple por defecto
    }
  }

  /// Calcula tiempo estimado de carga
  static Duration estimateLoadTime(String? imageUrl, {
    required double connectionSpeed, // Mbps
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Duration.zero;
    }

    // Estimación: imagen optimizada ~30-50KB
    const estimatedSizeKb = 40;
    final timeMsPerKb = 1000 / (connectionSpeed * 1000 / 8);
    final estimatedMs = (estimatedSizeKb * timeMsPerKb).toInt();
    
    debugPrint('📊 Estimated load time: ${estimatedMs}ms');
    return Duration(milliseconds: estimatedMs);
  }
}
