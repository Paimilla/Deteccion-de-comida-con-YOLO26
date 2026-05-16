import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../infrastructure/services/image_optimization_service.dart';
import 'nutrifoto_ui.dart';

/// Widget mejorado para cargar imágenes con optimizaciones
class OptimizedNutrifotoImage extends StatefulWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final BoxFit fit;
  final String? mealTypeHint;
  final bool useLazyLoading;
  final VoidCallback? onLoadComplete;

  const OptimizedNutrifotoImage({
    super.key,
    required this.imageUrl,
    required this.name,
    this.size = 28,
    this.fit = BoxFit.cover,
    this.mealTypeHint,
    this.useLazyLoading = true,
    this.onLoadComplete,
  });

  @override
  State<OptimizedNutrifotoImage> createState() =>
      _OptimizedNutrifotoImageState();
}

class _OptimizedNutrifotoImageState extends State<OptimizedNutrifotoImage> {
  late bool _isVisible = !widget.useLazyLoading;
  late String _optimizedUrl = '';
  late String _thumbnailUrl = '';

  @override
  void initState() {
    super.initState();
    _optimizedUrl = ImageOptimizationService.getFullImageUrl(widget.imageUrl);
    _thumbnailUrl = ImageOptimizationService.getThumbnailUrl(widget.imageUrl);

    // Simular lazy-loading: mostrar después de 100ms
    if (widget.useLazyLoading) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() => _isVisible = true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return FoodPlaceholder(name: widget.name, size: widget.size);
    }

    if (!ImageOptimizationService.isValidImageUrl(widget.imageUrl)) {
      return FoodPlaceholder(name: widget.name, size: widget.size);
    }

    // Lazy-loading: mostrar placeholder primero
    if (!_isVisible) {
      return Container(
        color: _getPlaceholderColor(),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ),
      );
    }

    return Hero(
      tag: 'optimized_img_${widget.imageUrl}',
      child: CachedNetworkImage(
        imageUrl: _optimizedUrl,
        fit: widget.fit,
        memCacheHeight: _getMemCacheHeight(),
        memCacheWidth: _getMemCacheWidth(),
        maxHeightDiskCache: 800,
        maxWidthDiskCache: 800,
        // Placeholder con thumbnail si disponible
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) =>
            FoodPlaceholder(name: widget.name, size: widget.size),
        // Callback cuando carga completo
        imageBuilder: (context, imageProvider) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onLoadComplete?.call();
          });
          return Image(image: imageProvider, fit: widget.fit);
        },
      ),
    );
  }

  /// Construye placeholder mejorado con thumbnail
  Widget _buildPlaceholder() {
    return Container(
      color: _getPlaceholderColor(),
      child: Stack(
        children: [
          // Thumbnail borroso como fondo
          if (_thumbnailUrl.isNotEmpty)
            Opacity(
              opacity: 0.3,
              child: CachedNetworkImage(
                imageUrl: _thumbnailUrl,
                fit: BoxFit.cover,
              ),
            ),
          // Indicador de carga
          const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],
      ),
    );
  }

  /// Obtiene altura para cache en memoria
  int _getMemCacheHeight() {
    final screenHeight = MediaQuery.of(context).size.height;
    return (screenHeight * 1.5).toInt();
  }

  /// Obtiene ancho para cache en memoria
  int _getMemCacheWidth() {
    final screenWidth = MediaQuery.of(context).size.width;
    return ImageOptimizationService.getOptimalImageWidth(screenWidth);
  }

  /// Obtiene color de placeholder según tipo de comida
  Color _getPlaceholderColor() {
    final colorHex =
        ImageOptimizationService.getPlaceholderColorForMealType(widget.mealTypeHint);
    // Convertir hex a Color
    return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
  }
}
