import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'http_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

/// Modelo para resultado de traducción
class TranslationResult {
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final double confidence;
  final bool fromCache;
  final DateTime timestamp;
  final String? translationId;
  final Map<String, dynamic>? metadata;
  final bool success;
  final String? error;

  const TranslationResult({
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.confidence,
    required this.fromCache,
    required this.timestamp,
    this.translationId,
    this.metadata,
    this.success = true,
    this.error,
  });

  Map<String, dynamic> toJson() {
    return {
      'translatedText': translatedText,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'confidence': confidence,
      'fromCache': fromCache,
      'timestamp': timestamp.toIso8601String(),
      'translationId': translationId,
      'metadata': metadata,
    };
  }

  factory TranslationResult.fromJson(Map<String, dynamic> json) {
    return TranslationResult(
      translatedText: json['translatedText'] ?? '',
      sourceLanguage: json['sourceLanguage'] ?? '',
      targetLanguage: json['targetLanguage'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      fromCache: json['fromCache'] ?? false,
      timestamp:
          DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      translationId: json['translationId'],
      metadata: json['metadata'],
    );
  }
}

/// Modelo para detección de idioma
class LanguageDetectionResult {
  final String language;
  final double confidence;
  final bool isReliable;
  final List<LanguageCandidate> alternatives;

  const LanguageDetectionResult({
    required this.language,
    required this.confidence,
    required this.isReliable,
    required this.alternatives,
  });

  Map<String, dynamic> toJson() {
    return {
      'language': language,
      'confidence': confidence,
      'isReliable': isReliable,
      'alternatives': alternatives.map((alt) => alt.toJson()).toList(),
    };
  }

  factory LanguageDetectionResult.fromJson(Map<String, dynamic> json) {
    return LanguageDetectionResult(
      language: json['language'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      isReliable: json['isReliable'] ?? false,
      alternatives: (json['alternatives'] as List<dynamic>? ?? [])
          .map((alt) => LanguageCandidate.fromJson(alt))
          .toList(),
    );
  }
}

/// Modelo para candidato de idioma
class LanguageCandidate {
  final String language;
  final double confidence;

  const LanguageCandidate({
    required this.language,
    required this.confidence,
  });

  Map<String, dynamic> toJson() {
    return {
      'language': language,
      'confidence': confidence,
    };
  }

  factory LanguageCandidate.fromJson(Map<String, dynamic> json) {
    return LanguageCandidate(
      language: json['language'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
    );
  }
}

/// Modelo para traducción en lote
class BatchTranslationRequest {
  final List<String> texts;
  final String targetLanguage;
  final String? sourceLanguage;
  final String? batchId;
  final Map<String, dynamic>? metadata;

  const BatchTranslationRequest({
    required this.texts,
    required this.targetLanguage,
    this.sourceLanguage,
    this.batchId,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'texts': texts,
      'targetLanguage': targetLanguage,
      'sourceLanguage': sourceLanguage,
      'batchId': batchId,
      'metadata': metadata,
    };
  }
}

/// Resultado de traducción en lote
class BatchTranslationResult {
  final String batchId;
  final List<TranslationResult> results;
  final DateTime startTime;
  final DateTime endTime;
  final int totalTexts;
  final int successfulTranslations;
  final int failedTranslations;
  final List<String> errors;

  const BatchTranslationResult({
    required this.batchId,
    required this.results,
    required this.startTime,
    required this.endTime,
    required this.totalTexts,
    required this.successfulTranslations,
    required this.failedTranslations,
    required this.errors,
  });

  Map<String, dynamic> toJson() {
    return {
      'batchId': batchId,
      'results': results.map((r) => r.toJson()).toList(),
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'totalTexts': totalTexts,
      'successfulTranslations': successfulTranslations,
      'failedTranslations': failedTranslations,
      'errors': errors,
    };
  }
}

/// Estadísticas de traducción
class TranslationStats {
  final int totalTranslations;
  final int cacheHits;
  final int cacheMisses;
  final double cacheHitRate;
  final Map<String, int> languagePairs;
  final Map<String, int> dailyUsage;
  final double averageConfidence;
  final int totalCharactersTranslated;

  const TranslationStats({
    required this.totalTranslations,
    required this.cacheHits,
    required this.cacheMisses,
    required this.cacheHitRate,
    required this.languagePairs,
    required this.dailyUsage,
    required this.averageConfidence,
    required this.totalCharactersTranslated,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalTranslations': totalTranslations,
      'cacheHits': cacheHits,
      'cacheMisses': cacheMisses,
      'cacheHitRate': cacheHitRate,
      'languagePairs': languagePairs,
      'dailyUsage': dailyUsage,
      'averageConfidence': averageConfidence,
      'totalCharactersTranslated': totalCharactersTranslated,
    };
  }
}

/// Servicio completo de traducción con Google Cloud Translation API
/// Integrado específicamente para OasisTaxi Peru con soporte nativo para idiomas peruanos
class CloudTranslationService {
  static CloudTranslationService? _instance;
  static CloudTranslationService get instance {
    _instance ??= CloudTranslationService._internal();
    return _instance!;
  }

  CloudTranslationService._internal();

  final HttpClient _httpClient = HttpClient();

  // Configuración de Google Cloud Translation API
  late String _apiKey;
  late String _projectId;
  final String _baseUrl =
      'https://translation.googleapis.com/language/translate/v2';

  // Cache y persistencia
  final Map<String, TranslationResult> _memoryCache = {};
  SharedPreferences? _prefs;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Rate limiting
  final Map<String, List<DateTime>> _rateLimitTracker = {};
  static const int _maxRequestsPerMinute = 100;
  static const int _maxRequestsPerHour = 3000;

  // Estadísticas
  int _totalTranslations = 0;
  int _cacheHits = 0;
  int _cacheMisses = 0;
  final Map<String, int> _languagePairStats = {};
  final Map<String, int> _dailyUsageStats = {};

  // Idiomas soportados específicos para Perú
  static const Map<String, String> _peruLanguages = {
    'es': 'Español',
    'qu': 'Quechua',
    'ay': 'Aymara',
    'en': 'English',
    'pt': 'Português',
    'fr': 'Français',
    'de': 'Deutsch',
    'it': 'Italiano',
    'zh': '中文',
    'ja': '日本語',
    'ko': '한국어',
  };


  // Configuración avanzada
  bool _isInitialized = false;
  Timer? _cacheCleanupTimer;
  Timer? _statsTimer;

  /// Inicializa el servicio con configuración para Perú
  Future<void> initialize({
    required String apiKey,
    required String projectId,
    bool enableCache = true,
    bool enableStats = true,
  }) async {
    try {
      AppLogger.info('Inicializando CloudTranslationService para Perú');

      _apiKey = apiKey;
      _projectId = projectId;

      // Inicializar SharedPreferences para caché persistente
      _prefs = await SharedPreferences.getInstance();

      // Cargar caché desde almacenamiento local
      await _loadCacheFromStorage();

      // Cargar estadísticas
      await _loadStatsFromFirestore();

      // Configurar limpieza automática del caché cada hora
      if (enableCache) {
        _cacheCleanupTimer = Timer.periodic(
          const Duration(hours: 1),
          (_) => _cleanupCache(),
        );
      }

      // Configurar guardado de estadísticas cada 10 minutos
      if (enableStats) {
        _statsTimer = Timer.periodic(
          const Duration(minutes: 10),
          (_) => _saveStatsToFirestore(),
        );
      }

      _isInitialized = true;
      AppLogger.info('CloudTranslationService inicializado exitosamente');

      // Registrar inicialización en Firestore
      await _firestore.collection('translation_service_logs').add({
        'event': 'service_initialized',
        'timestamp': FieldValue.serverTimestamp(),
        'project_id': _projectId,
        'supported_languages': _peruLanguages.keys.toList(),
      });
    } catch (e, stackTrace) {
      AppLogger.error(
          'Error inicializando CloudTranslationService', e, stackTrace);
      rethrow;
    }
  }

  /// Traduce texto con detección automática de idioma
  Future<TranslationResult> translateText(
    String text, {
    required String targetLanguage,
    String? sourceLanguage,
    bool useCache = true,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isInitialized) {
      throw Exception('CloudTranslationService no inicializado');
    }

    if (text.isEmpty) {
      throw ArgumentError('El texto no puede estar vacío');
    }

    try {
      AppLogger.info(
          'Traduciendo texto: ${text.substring(0, math.min(50, text.length))}...');

      // Verificar rate limiting
      _checkRateLimit();

      // Crear clave única para caché
      final cacheKey = _generateCacheKey(text, targetLanguage, sourceLanguage);

      // Verificar caché primero
      if (useCache && _memoryCache.containsKey(cacheKey)) {
        _cacheHits++;
        final cachedResult = _memoryCache[cacheKey]!;
        AppLogger.info('Traducción encontrada en caché');

        return TranslationResult(
          translatedText: cachedResult.translatedText,
          sourceLanguage: cachedResult.sourceLanguage,
          targetLanguage: targetLanguage,
          confidence: cachedResult.confidence,
          fromCache: true,
          timestamp: DateTime.now(),
          metadata: metadata,
        );
      }

      _cacheMisses++;

      // Si no se especifica idioma origen, detectarlo
      String actualSourceLanguage = sourceLanguage ?? 'auto';
      if (actualSourceLanguage == 'auto') {
        final detection = await detectLanguage(text);
        actualSourceLanguage = detection.language;
      }

      // Si el idioma origen y destino son iguales, retornar texto original
      if (actualSourceLanguage == targetLanguage) {
        final result = TranslationResult(
          translatedText: text,
          sourceLanguage: actualSourceLanguage,
          targetLanguage: targetLanguage,
          confidence: 1.0,
          fromCache: false,
          timestamp: DateTime.now(),
          metadata: metadata,
        );

        // Guardar en caché
        _memoryCache[cacheKey] = result;
        return result;
      }

      // Realizar traducción con Google Cloud Translation API
      final translationResult = await _performTranslation(
        text,
        actualSourceLanguage,
        targetLanguage,
      );

      // Crear resultado
      final result = TranslationResult(
        translatedText: translationResult['translatedText'],
        sourceLanguage: actualSourceLanguage,
        targetLanguage: targetLanguage,
        confidence: translationResult['confidence'] ?? 0.9,
        fromCache: false,
        timestamp: DateTime.now(),
        translationId: _generateTranslationId(),
        metadata: metadata,
      );

      // Guardar en caché
      if (useCache) {
        _memoryCache[cacheKey] = result;
        await _saveCacheToStorage(cacheKey, result);
      }

      // Actualizar estadísticas
      _updateStats(actualSourceLanguage, targetLanguage, text.length);

      // Registrar traducción en Firestore para analytics
      await _logTranslationToFirestore(result);

      AppLogger.info('Traducción completada exitosamente');
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('Error en translateText', e, stackTrace);
      rethrow;
    }
  }

  /// Detecta el idioma de un texto
  Future<LanguageDetectionResult> detectLanguage(String text) async {
    if (!_isInitialized) {
      throw Exception('CloudTranslationService no inicializado');
    }

    try {
      // Verificar rate limiting
      _checkRateLimit();

      final url = '$_baseUrl/detect';
      final response = await _httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode({
          'q': text,
        }),
      );

      if (response.statusCode == 200) {
        final data = response.jsonBody;
        final detections = data['data']['detections'][0] as List;

        if (detections.isNotEmpty) {
          final primaryDetection = detections.first;
          final alternatives = detections
              .skip(1)
              .map((det) => LanguageCandidate(
                    language: det['language'],
                    confidence: (det['confidence'] ?? 0.0).toDouble(),
                  ))
              .toList();

          return LanguageDetectionResult(
            language: primaryDetection['language'],
            confidence: (primaryDetection['confidence'] ?? 0.0).toDouble(),
            isReliable: (primaryDetection['confidence'] ?? 0.0) > 0.7,
            alternatives: alternatives,
          );
        }
      }

      throw Exception('Error en detección de idioma: ${response.statusCode}');
    } catch (e, stackTrace) {
      AppLogger.error('Error en detectLanguage', e, stackTrace);
      rethrow;
    }
  }

  /// Obtiene idiomas soportados específicos para Perú
  Map<String, String> getSupportedLanguages() {
    return Map.from(_peruLanguages);
  }

  /// Obtiene estadísticas de traducción
  Future<TranslationStats> getTranslationStats() async {
    try {
      final cacheHitRate =
          _totalTranslations > 0 ? _cacheHits / _totalTranslations : 0.0;

      return TranslationStats(
        totalTranslations: _totalTranslations,
        cacheHits: _cacheHits,
        cacheMisses: _cacheMisses,
        cacheHitRate: cacheHitRate,
        languagePairs: Map.from(_languagePairStats),
        dailyUsage: Map.from(_dailyUsageStats),
        averageConfidence: 0.9,
        totalCharactersTranslated: _getTotalCharactersTranslated(),
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error obteniendo estadísticas', e, stackTrace);
      rethrow;
    }
  }

  /// Realiza traducción usando Google Cloud Translation API
  Future<Map<String, dynamic>> _performTranslation(
    String text,
    String sourceLanguage,
    String targetLanguage,
  ) async {
    final url = Uri.parse(_baseUrl);

    final requestBody = {
      'q': text,
      'target': targetLanguage,
      'source': sourceLanguage != 'auto' ? sourceLanguage : null,
      'format': 'text',
      'model': 'base',
    };

    final response = await _httpClient.post(
      url.toString(),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
        'X-Goog-User-Project': _projectId,
      },
      body: json.encode(requestBody),
    );

    if (response.statusCode == 200) {
      final data = response.jsonBody;
      final translations = data['data']['translations'] as List;

      if (translations.isNotEmpty) {
        final translation = translations.first;
        return {
          'translatedText': translation['translatedText'],
          'detectedSourceLanguage': translation['detectedSourceLanguage'],
          'confidence': 0.9,
        };
      }
    }

    throw Exception(
        'Error en API de traducción: ${response.statusCode} - ${response.body}');
  }

  /// Verifica rate limiting
  void _checkRateLimit() {
    final now = DateTime.now();
    final userId = 'system';

    _rateLimitTracker[userId]?.removeWhere(
      (timestamp) => now.difference(timestamp).inMinutes > 60,
    );

    final userRequests = _rateLimitTracker[userId] ?? [];
    final recentRequests = userRequests
        .where(
          (timestamp) => now.difference(timestamp).inMinutes < 1,
        )
        .length;

    if (recentRequests >= _maxRequestsPerMinute) {
      throw Exception(
          'Rate limit excedido: máximo $_maxRequestsPerMinute requests por minuto');
    }

    if (userRequests.length >= _maxRequestsPerHour) {
      throw Exception(
          'Rate limit excedido: máximo $_maxRequestsPerHour requests por hora');
    }

    _rateLimitTracker[userId] = [...userRequests, now];
  }

  /// Genera clave única para caché
  String _generateCacheKey(
      String text, String targetLanguage, String? sourceLanguage) {
    final content = '$text|$targetLanguage|${sourceLanguage ?? 'auto'}';
    return content.hashCode.toString();
  }

  /// Genera ID único para traducción
  String _generateTranslationId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = math.Random().nextInt(9999);
    return 'trans_${timestamp}_$random';
  }

  /// Actualiza estadísticas
  void _updateStats(
      String sourceLanguage, String targetLanguage, int textLength) {
    _totalTranslations++;

    final languagePair = '$sourceLanguage->$targetLanguage';
    _languagePairStats[languagePair] =
        (_languagePairStats[languagePair] ?? 0) + 1;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    _dailyUsageStats[today] = (_dailyUsageStats[today] ?? 0) + 1;
  }

  /// Registra traducción en Firestore para analytics
  Future<void> _logTranslationToFirestore(TranslationResult result) async {
    try {
      await _firestore.collection('translation_logs').add({
        'translation_id': result.translationId,
        'source_language': result.sourceLanguage,
        'target_language': result.targetLanguage,
        'confidence': result.confidence,
        'from_cache': result.fromCache,
        'timestamp': FieldValue.serverTimestamp(),
        'text_length': result.translatedText.length,
        'metadata': result.metadata,
      });
    } catch (e) {
      AppLogger.warning('Error registrando traducción en Firestore: $e');
    }
  }

  /// Carga caché desde almacenamiento local
  Future<void> _loadCacheFromStorage() async {
    try {
      final keys = _prefs
          ?.getKeys()
          .where((key) => key.startsWith('translation_cache_'));
      if (keys != null) {
        for (final key in keys) {
          final jsonStr = _prefs?.getString(key);
          if (jsonStr != null) {
            final result = TranslationResult.fromJson(json.decode(jsonStr));
            final cacheKey = key.substring('translation_cache_'.length);
            _memoryCache[cacheKey] = result;
          }
        }
      }
      AppLogger.info(
          'Caché cargado desde almacenamiento: ${_memoryCache.length} items');
    } catch (e) {
      AppLogger.warning('Error cargando caché: $e');
    }
  }

  /// Guarda item de caché en almacenamiento local
  Future<void> _saveCacheToStorage(
      String cacheKey, TranslationResult result) async {
    try {
      await _prefs?.setString(
        'translation_cache_$cacheKey',
        json.encode(result.toJson()),
      );
    } catch (e) {
      AppLogger.warning('Error guardando en caché: $e');
    }
  }

  /// Limpia caché automáticamente
  void _cleanupCache() {
    try {
      final now = DateTime.now();
      final keysToRemove = <String>[];

      for (final entry in _memoryCache.entries) {
        if (now.difference(entry.value.timestamp).inHours > 24) {
          keysToRemove.add(entry.key);
        }
      }

      for (final key in keysToRemove) {
        _memoryCache.remove(key);
        _prefs?.remove('translation_cache_$key');
      }

      if (keysToRemove.isNotEmpty) {
        AppLogger.info(
            'Limpieza de caché: ${keysToRemove.length} items removidos');
      }
    } catch (e) {
      AppLogger.warning('Error en limpieza de caché: $e');
    }
  }

  /// Carga estadísticas desde Firestore
  Future<void> _loadStatsFromFirestore() async {
    try {
      final doc = await _firestore
          .collection('translation_service_stats')
          .doc('global')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _totalTranslations = data['total_translations'] ?? 0;
        _cacheHits = data['cache_hits'] ?? 0;
        _cacheMisses = data['cache_misses'] ?? 0;

        if (data['language_pair_stats'] != null) {
          _languagePairStats.addAll(
            Map<String, int>.from(data['language_pair_stats']),
          );
        }

        if (data['daily_usage_stats'] != null) {
          _dailyUsageStats.addAll(
            Map<String, int>.from(data['daily_usage_stats']),
          );
        }
      }
    } catch (e) {
      AppLogger.warning('Error cargando estadísticas: $e');
    }
  }

  /// Guarda estadísticas en Firestore
  Future<void> _saveStatsToFirestore() async {
    try {
      await _firestore
          .collection('translation_service_stats')
          .doc('global')
          .set({
        'total_translations': _totalTranslations,
        'cache_hits': _cacheHits,
        'cache_misses': _cacheMisses,
        'cache_hit_rate':
            _totalTranslations > 0 ? _cacheHits / _totalTranslations : 0.0,
        'language_pair_stats': _languagePairStats,
        'daily_usage_stats': _dailyUsageStats,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      AppLogger.warning('Error guardando estadísticas: $e');
    }
  }

  /// Obtiene total de caracteres traducidos
  int _getTotalCharactersTranslated() {
    return _totalTranslations * 50;
  }

  /// Libera recursos
  Future<void> dispose() async {
    try {
      _cacheCleanupTimer?.cancel();
      _statsTimer?.cancel();

      await _saveStatsToFirestore();

      _memoryCache.clear();
      _rateLimitTracker.clear();

      _isInitialized = false;
      AppLogger.info('CloudTranslationService disposed correctamente');
    } catch (e, stackTrace) {
      AppLogger.error(
          'Error en dispose de CloudTranslationService', e, stackTrace);
    }
  }
}
