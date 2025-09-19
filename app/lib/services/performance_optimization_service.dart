import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../utils/app_logger.dart';

/// Servicio de optimización de rendimiento para OasisTaxi
/// Maneja caché, lazy loading y optimizaciones de memoria
class PerformanceOptimizationService {
  static PerformanceOptimizationService? _instance;
  static PerformanceOptimizationService get instance {
    _instance ??= PerformanceOptimizationService._internal();
    return _instance!;
  }

  PerformanceOptimizationService._internal();

  // Configuración de optimización
  static const int maxMemoryCacheSize = 100; // MB
  static const int maxDiskCacheSize = 500; // MB
  static const Duration cacheStaleTime = Duration(days: 7);
  static const int itemsPerPage = 20;
  static const double scrollThreshold = 0.8;

  // Métricas de rendimiento
  final Map<String, int> _frameDrops = {};
  final Map<String, Duration> _operationTimes = {};
  Timer? _metricsTimer;

  /// Inicializa el servicio de optimización
  Future<void> initialize() async {
    try {
      AppLogger.info('Inicializando PerformanceOptimizationService');

      // Configurar monitoreo de métricas
      _startMetricsMonitoring();

      // Limpiar caché antiguo
      await _cleanOldCache();

      AppLogger.info('PerformanceOptimizationService inicializado');
    } catch (e, stackTrace) {
      AppLogger.error('Error inicializando PerformanceOptimizationService',
          e, stackTrace);
    }
  }

  /// Widget optimizado para imágenes con caché
  Widget buildOptimizedImage({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 300),
      placeholder: (context, url) =>
          placeholder ?? _buildDefaultPlaceholder(),
      errorWidget: (context, url, error) =>
          errorWidget ?? _buildDefaultErrorWidget(),
      cacheManager: DefaultCacheManager(),
    );
  }

  /// Builder optimizado para listas largas con paginación
  Widget buildOptimizedList<T>({
    required List<T> items,
    required Widget Function(BuildContext, T, int) itemBuilder,
    required VoidCallback onLoadMore,
    bool isLoading = false,
    bool hasMore = true,
    ScrollController? scrollController,
    EdgeInsets? padding,
    Widget? emptyWidget,
    Widget? loadingWidget,
    Widget? errorWidget,
    String? error,
  }) {
    if (items.isEmpty && !isLoading) {
      return Center(
        child: emptyWidget ?? _buildEmptyState(),
      );
    }

    if (error != null) {
      return Center(
        child: errorWidget ?? _buildErrorState(error),
      );
    }

    final controller = scrollController ?? ScrollController();

    // Agregar listener para paginación
    controller.addListener(() {
      if (controller.position.pixels >=
          controller.position.maxScrollExtent * scrollThreshold) {
        if (hasMore && !isLoading) {
          onLoadMore();
        }
      }
    });

    return ListView.builder(
      controller: controller,
      padding: padding ?? const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == items.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: loadingWidget ?? _buildLoadingIndicator(),
            ),
          );
        }

        return itemBuilder(context, items[index], index);
      },
      // Optimizaciones de rendimiento
      cacheExtent: 100,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
    );
  }

  /// Builder optimizado para grids con lazy loading
  Widget buildOptimizedGrid<T>({
    required List<T> items,
    required Widget Function(BuildContext, T, int) itemBuilder,
    required VoidCallback onLoadMore,
    int crossAxisCount = 2,
    double mainAxisSpacing = 16,
    double crossAxisSpacing = 16,
    double childAspectRatio = 1.0,
    bool isLoading = false,
    bool hasMore = true,
    ScrollController? scrollController,
    EdgeInsets? padding,
  }) {
    final controller = scrollController ?? ScrollController();

    // Listener para paginación
    controller.addListener(() {
      if (controller.position.pixels >=
          controller.position.maxScrollExtent * scrollThreshold) {
        if (hasMore && !isLoading) {
          onLoadMore();
        }
      }
    });

    return GridView.builder(
      controller: controller,
      padding: padding ?? const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: items.length + (hasMore ? crossAxisCount : 0),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return Center(child: _buildLoadingIndicator());
        }

        return itemBuilder(context, items[index], index);
      },
      // Optimizaciones
      cacheExtent: 200,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
    );
  }

  /// Ejecuta operación pesada en isolate
  Future<T> runInIsolate<T>(
    ComputeCallback<dynamic, T> callback,
    dynamic message,
  ) async {
    try {
      final stopwatch = Stopwatch()..start();

      final result = await compute(callback, message);

      stopwatch.stop();
      _recordOperationTime('isolate_operation', stopwatch.elapsed);

      return result;
    } catch (e, stackTrace) {
      AppLogger.error('Error en isolate', e, stackTrace);
      rethrow;
    }
  }

  /// Debounce para operaciones frecuentes
  Timer? _debounceTimer;
  void debounce(
    VoidCallback callback, {
    Duration duration = const Duration(milliseconds: 500),
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(duration, callback);
  }

  /// Throttle para operaciones frecuentes
  DateTime? _lastThrottleTime;
  void throttle(
    VoidCallback callback, {
    Duration duration = const Duration(milliseconds: 100),
  }) {
    final now = DateTime.now();
    if (_lastThrottleTime == null ||
        now.difference(_lastThrottleTime!) > duration) {
      _lastThrottleTime = now;
      callback();
    }
  }

  /// Precarga imágenes para mejorar rendimiento
  Future<void> precacheImages(
    BuildContext context,
    List<String> imageUrls,
  ) async {
    try {
      final futures = imageUrls.map((url) {
        return precacheImage(
          CachedNetworkImageProvider(url),
          context,
        );
      }).toList();

      await Future.wait(futures);
      AppLogger.info('${imageUrls.length} imágenes precargadas');
    } catch (e) {
      AppLogger.warning('Error precargando imágenes: $e');
    }
  }

  /// Limpia caché de memoria
  Future<void> clearMemoryCache() async {
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      AppLogger.info('Caché de memoria limpiado');
    } catch (e) {
      AppLogger.warning('Error limpiando caché: $e');
    }
  }

  /// Obtiene métricas de rendimiento
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      'frameDrops': Map.from(_frameDrops),
      'operationTimes': Map.from(_operationTimes),
      'memoryUsage': _getMemoryUsage(),
      'cacheSize': _getCacheSize(),
    };
  }

  // Métodos privados

  void _startMetricsMonitoring() {
    _metricsTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkFrameRate();
      _checkMemoryUsage();
    });
  }

  void _checkFrameRate() {
    // Monitorear frame drops
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final renderTime = WidgetsBinding.instance.window.onReportTimings;
      // Implementar lógica de detección de frame drops
    });
  }

  void _checkMemoryUsage() {
    final imageCache = PaintingBinding.instance.imageCache;
    if (imageCache.currentSizeBytes > maxMemoryCacheSize * 1024 * 1024) {
      clearMemoryCache();
    }
  }

  Future<void> _cleanOldCache() async {
    try {
      final cacheManager = DefaultCacheManager();
      await cacheManager.emptyCache();
      AppLogger.info('Caché antiguo limpiado');
    } catch (e) {
      AppLogger.warning('Error limpiando caché antiguo: $e');
    }
  }

  void _recordOperationTime(String operation, Duration time) {
    _operationTimes[operation] = time;

    if (time.inMilliseconds > 100) {
      AppLogger.warning(
        'Operación lenta detectada: $operation tomó ${time.inMilliseconds}ms',
      );
    }
  }

  Map<String, dynamic> _getMemoryUsage() {
    final imageCache = PaintingBinding.instance.imageCache;
    return {
      'imageCacheSizeMB': imageCache.currentSizeBytes / (1024 * 1024),
      'imageCacheCount': imageCache.currentSize,
      'maxCacheSizeMB': imageCache.maximumSizeBytes / (1024 * 1024),
    };
  }

  int _getCacheSize() {
    final imageCache = PaintingBinding.instance.imageCache;
    return imageCache.currentSizeBytes;
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildDefaultErrorWidget() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(
        Icons.error_outline,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.inbox_outlined,
          size: 64,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 16),
        Text(
          'No hay elementos',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline,
          size: 64,
          color: Colors.red[300],
        ),
        const SizedBox(height: 16),
        Text(
          'Error: $error',
          style: TextStyle(
            fontSize: 16,
            color: Colors.red[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return const SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2,
      ),
    );
  }

  /// Libera recursos
  void dispose() {
    _metricsTimer?.cancel();
    _debounceTimer?.cancel();
    _frameDrops.clear();
    _operationTimes.clear();
    AppLogger.info('PerformanceOptimizationService disposed');
  }
}