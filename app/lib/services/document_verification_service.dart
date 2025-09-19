import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../utils/app_logger.dart';

/// Servicio de verificación de documentos con Google Cloud Vision API
///
/// Este servicio maneja la verificación automática de documentos de conductores
/// utilizando Google Cloud Vision API para OCR, detección de rostros y validación.
///
/// Características principales:
/// - OCR automático de licencias de conducir peruanas
/// - Detección y análisis de rostros en fotografías
/// - Validación de legibilidad y autenticidad de documentos
/// - Extracción automática de datos (nombres, números, fechas)
/// - Verificación de documentos SOAT y revisión técnica
/// - Integración con Firebase Storage y Firestore
/// - Logging seguro y auditoría completa
///
/// Configurado específicamente para documentos peruanos:
/// - DNI (8 dígitos)
/// - Licencias de conducir (formato Perú)
/// - SOAT (pólizas de seguro)
/// - Revisión técnica vehicular
/// - Tarjeta de propiedad vehicular
class DocumentVerificationService {
  static DocumentVerificationService? _instance;

  DocumentVerificationService._internal();

  static DocumentVerificationService get instance {
    _instance ??= DocumentVerificationService._internal();
    return _instance!;
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Patrones de validación para documentos peruanos
  static final Map<String, RegExp> _documentPatterns = {
    'dni': RegExp(r'^\d{8}$'),
    'licencia': RegExp(r'^[A-Z]\d{8}$'),
    'soat': RegExp(r'^[A-Z0-9]{10,15}$'),
    'revision_tecnica': RegExp(r'^RT\d{8,12}$'),
    'tarjeta_propiedad': RegExp(r'^[A-Z0-9]{8,12}$'),
  };

  // Tipos de documentos soportados
  static const List<String> supportedDocumentTypes = [
    'dni',
    'licencia_conducir',
    'soat',
    'revision_tecnica',
    'tarjeta_propiedad',
    'foto_perfil',
    'foto_vehiculo',
  ];

  // Configuración de calidad mínima para imágenes
  static const Map<String, double> _qualityThresholds = {
    'min_confidence': 0.7,
    'min_text_confidence': 0.6,
    'min_face_confidence': 0.8,
    'max_blur_score': 0.3,
    'min_brightness': 0.2,
    'max_brightness': 0.9,
  };

  /// Verifica un documento específico usando Cloud Vision API
  ///
  /// [driverId] ID del conductor
  /// [documentType] Tipo de documento a verificar
  /// [imageBytes] Bytes de la imagen del documento
  /// [fileName] Nombre del archivo original
  ///
  /// Retorna resultado detallado de la verificación
  Future<DocumentVerificationResult> verifyDocument({
    required String driverId,
    required String documentType,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      AppLogger.info(
          'Iniciando verificación de documento: $documentType para conductor: $driverId');

      // Validar tipo de documento soportado
      if (!supportedDocumentTypes.contains(documentType)) {
        throw Exception('Tipo de documento no soportado: $documentType');
      }

      // Validar tamaño de imagen (máximo 20MB para Cloud Vision)
      if (imageBytes.length > 20 * 1024 * 1024) {
        throw Exception('Imagen demasiado grande. Máximo 20MB permitido.');
      }

      // Subir imagen a Cloud Storage temporalmente
      final storageRef = await _uploadImageToStorage(
        driverId: driverId,
        documentType: documentType,
        imageBytes: imageBytes,
        fileName: fileName,
      );

      // Analizar imagen con Cloud Vision API
      final visionResults = await _analyzeImageWithCloudVision(imageBytes);

      // Procesar resultados según tipo de documento
      final extractedData = await _processDocumentData(
        documentType: documentType,
        visionResults: visionResults,
      );

      // Verificar calidad de imagen
      final qualityCheck = await _checkImageQuality(visionResults);

      // Validar datos extraídos
      final validationResult = await _validateExtractedData(
        documentType: documentType,
        extractedData: extractedData,
      );

      // Calcular puntuación de confianza general
      final overallConfidence = _calculateOverallConfidence(
        visionResults: visionResults,
        qualityCheck: qualityCheck,
        validationResult: validationResult,
      );

      // Determinar si el documento es aprobado automáticamente
      final isAutoApproved =
          overallConfidence >= _qualityThresholds['min_confidence']! &&
              qualityCheck.isGoodQuality &&
              validationResult.isValid;

      // Crear resultado de verificación
      final result = DocumentVerificationResult(
        driverId: driverId,
        documentType: documentType,
        fileName: fileName,
        storageUrl: storageRef.fullPath,
        extractedData: extractedData,
        qualityCheck: qualityCheck,
        validationResult: validationResult,
        overallConfidence: overallConfidence,
        isAutoApproved: isAutoApproved,
        needsManualReview: !isAutoApproved,
        verificationTimestamp: DateTime.now(),
        visionApiResults: visionResults,
      );

      // Guardar resultado en Firestore
      await _saveVerificationResult(result);

      // Log del resultado (sin datos sensibles)
      AppLogger.info('Verificación completada para $documentType. '
          'Confianza: ${(overallConfidence * 100).toStringAsFixed(1)}%. '
          'Auto-aprobado: $isAutoApproved');

      return result;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error verificando documento $documentType para conductor $driverId',
        e,
        stackTrace,
      );

      return DocumentVerificationResult.error(
        driverId: driverId,
        documentType: documentType,
        fileName: fileName,
        error: e.toString(),
      );
    }
  }

  /// Sube imagen a Cloud Storage
  Future<Reference> _uploadImageToStorage({
    required String driverId,
    required String documentType,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = fileName.split('.').last.toLowerCase();
    final storagePath =
        'drivers/$driverId/documents/$documentType/$timestamp.$extension';

    final storageRef = _storage.ref().child(storagePath);

    // Metadata con información adicional
    final metadata = SettableMetadata(
      contentType: 'image/$extension',
      customMetadata: {
        'driver_id': driverId,
        'document_type': documentType,
        'original_filename': fileName,
        'upload_timestamp': timestamp.toString(),
        'verification_status': 'pending',
      },
    );

    await storageRef.putData(imageBytes, metadata);

    AppLogger.info('Imagen subida a Storage: $storagePath');
    return storageRef;
  }

  /// Analiza imagen usando Google Cloud Vision API a través de Cloud Functions
  Future<Map<String, dynamic>> _analyzeImageWithCloudVision(
      Uint8List imageBytes) async {
    try {
      AppLogger.info('Analizando imagen con Cloud Vision API vía Cloud Functions');

      // Convertir imagen a base64
      final base64Image = base64Encode(imageBytes);

      // Llamar Cloud Function para procesar imagen
      final callable = _functions.httpsCallable('annotateImage');
      final result = await callable.call({
        'imageContent': base64Image,
      });

      final response = result.data as Map<String, dynamic>;

      if (response['success'] != true) {
        throw Exception('Cloud Vision API falló en el servidor');
      }

      AppLogger.info('Análisis Cloud Vision completado exitosamente');

      // Formatear respuesta para compatibilidad con el código existente
      return {
        'textAnnotations': response['textAnnotations'] ?? [],
        'fullTextAnnotation': response['documentTextAnnotation'],
        'faceAnnotations': response['faceAnnotations'] ?? [],
        'imagePropertiesAnnotation': response['imagePropertiesAnnotation'],
        'safeSearchAnnotation': response['safeSearchAnnotation'] ?? {},
        'objectAnnotations': response['objectAnnotations'] ?? [],
      };
    } catch (e) {
      AppLogger.error('Error en análisis Cloud Vision API', e);
      rethrow;
    }
  }

  /// Procesa datos extraídos según tipo de documento
  Future<Map<String, dynamic>> _processDocumentData({
    required String documentType,
    required Map<String, dynamic> visionResults,
  }) async {
    final extractedData = <String, dynamic>{};

    try {
      // Extraer texto completo
      final fullText = _extractFullText(visionResults);
      extractedData['full_text'] = fullText;

      // Extraer texto estructurado si está disponible
      final structuredText = _extractStructuredText(visionResults);
      extractedData['structured_text'] = structuredText;

      // Procesar según tipo específico de documento
      switch (documentType) {
        case 'dni':
          extractedData.addAll(await _processDNI(fullText, structuredText));
          break;

        case 'licencia_conducir':
          extractedData
              .addAll(await _processLicenciaConducir(fullText, structuredText));
          break;

        case 'soat':
          extractedData.addAll(await _processSOAT(fullText, structuredText));
          break;

        case 'revision_tecnica':
          extractedData
              .addAll(await _processRevisionTecnica(fullText, structuredText));
          break;

        case 'tarjeta_propiedad':
          extractedData
              .addAll(await _processTarjetaPropiedad(fullText, structuredText));
          break;

        case 'foto_perfil':
          extractedData.addAll(await _processFotoPerfil(visionResults));
          break;

        case 'foto_vehiculo':
          extractedData.addAll(await _processFotoVehiculo(visionResults));
          break;

        default:
          extractedData['generic_text'] = fullText;
      }

      // Extraer metadatos generales
      extractedData['detected_languages'] = _detectLanguages(visionResults);
      extractedData['text_confidence'] =
          _calculateTextConfidence(visionResults);
      extractedData['processing_timestamp'] = DateTime.now().toIso8601String();

      return extractedData;
    } catch (e) {
      AppLogger.error('Error procesando datos del documento $documentType', e);
      return {
        'error': e.toString(),
        'raw_text': _extractFullText(visionResults),
      };
    }
  }

  /// Extrae texto completo de la respuesta de Vision API
  String _extractFullText(Map<String, dynamic> visionResults) {
    if (visionResults['fullTextAnnotation'] != null) {
      return visionResults['fullTextAnnotation']['text'] ?? '';
    }

    if (visionResults['textAnnotations'] != null &&
        visionResults['textAnnotations'].isNotEmpty) {
      return visionResults['textAnnotations'][0]['description'] ?? '';
    }

    return '';
  }

  /// Extrae texto estructurado por bloques
  List<Map<String, dynamic>> _extractStructuredText(
      Map<String, dynamic> visionResults) {
    final structuredText = <Map<String, dynamic>>[];

    if (visionResults['fullTextAnnotation']?['pages'] != null) {
      for (final page in visionResults['fullTextAnnotation']['pages']) {
        if (page['blocks'] != null) {
          for (final block in page['blocks']) {
            final blockText = _extractBlockText(block);
            if (blockText.isNotEmpty) {
              structuredText.add({
                'text': blockText,
                'confidence': block['confidence'] ?? 0.0,
                'bounding_box': block['boundingBox'],
                'block_type': block['blockType'] ?? 'TEXT',
              });
            }
          }
        }
      }
    }

    return structuredText;
  }

  /// Extrae texto de un bloque específico
  String _extractBlockText(Map<String, dynamic> block) {
    final textParts = <String>[];

    if (block['paragraphs'] != null) {
      for (final paragraph in block['paragraphs']) {
        if (paragraph['words'] != null) {
          final words = <String>[];
          for (final word in paragraph['words']) {
            if (word['symbols'] != null) {
              final symbols = <String>[];
              for (final symbol in word['symbols']) {
                symbols.add(symbol['text'] ?? '');
              }
              words.add(symbols.join());
            }
          }
          textParts.add(words.join(' '));
        }
      }
    }

    return textParts.join('\n');
  }

  /// Procesa DNI peruano
  Future<Map<String, dynamic>> _processDNI(
      String fullText, List<Map<String, dynamic>> structuredText) async {
    final dniData = <String, dynamic>{};

    // Buscar número de DNI (8 dígitos)
    final dniPattern = RegExp(r'\b\d{8}\b');
    final dniMatch = dniPattern.firstMatch(fullText);
    if (dniMatch != null) {
      dniData['numero_dni'] = dniMatch.group(0);
    }

    // Buscar nombres (típicamente después de "NOMBRES" o "APELLIDOS")
    final nombresPattern =
        RegExp(r'NOMBRES?\s*:?\s*([A-ZÁÉÍÓÚÑ\s]+)', caseSensitive: false);
    final nombresMatch = nombresPattern.firstMatch(fullText);
    if (nombresMatch != null) {
      dniData['nombres'] = nombresMatch.group(1)?.trim();
    }

    final apellidosPattern =
        RegExp(r'APELLIDOS?\s*:?\s*([A-ZÁÉÍÓÚÑ\s]+)', caseSensitive: false);
    final apellidosMatch = apellidosPattern.firstMatch(fullText);
    if (apellidosMatch != null) {
      dniData['apellidos'] = apellidosMatch.group(1)?.trim();
    }

    // Buscar fecha de nacimiento
    final fechaPattern = RegExp(r'\b(\d{2})[\/\-](\d{2})[\/\-](\d{4})\b');
    final fechaMatch = fechaPattern.firstMatch(fullText);
    if (fechaMatch != null) {
      dniData['fecha_nacimiento'] =
          '${fechaMatch.group(1)}/${fechaMatch.group(2)}/${fechaMatch.group(3)}';
    }

    // Buscar sexo
    if (fullText.toUpperCase().contains('MASCULINO') ||
        fullText.toUpperCase().contains('M')) {
      dniData['sexo'] = 'M';
    } else if (fullText.toUpperCase().contains('FEMENINO') ||
        fullText.toUpperCase().contains('F')) {
      dniData['sexo'] = 'F';
    }

    // Verificar que el DNI contiene las palabras clave esperadas
    final expectedKeywords = ['REPÚBLICA', 'PERÚ', 'NACIONAL', 'IDENTIDAD'];
    var keywordCount = 0;
    for (final keyword in expectedKeywords) {
      if (fullText.toUpperCase().contains(keyword)) {
        keywordCount++;
      }
    }
    dniData['keyword_match_score'] = keywordCount / expectedKeywords.length;

    return dniData;
  }

  /// Procesa licencia de conducir peruana
  Future<Map<String, dynamic>> _processLicenciaConducir(
      String fullText, List<Map<String, dynamic>> structuredText) async {
    final licenciaData = <String, dynamic>{};

    // Buscar número de licencia (letra seguida de 8 dígitos)
    final licenciaPattern = RegExp(r'\b[A-Z]\d{8}\b');
    final licenciaMatch = licenciaPattern.firstMatch(fullText);
    if (licenciaMatch != null) {
      licenciaData['numero_licencia'] = licenciaMatch.group(0);
    }

    // Buscar clase de licencia
    final clasePattern =
        RegExp(r'CLASE?\s*:?\s*([A-Z0-9]+)', caseSensitive: false);
    final claseMatch = clasePattern.firstMatch(fullText);
    if (claseMatch != null) {
      licenciaData['clase'] = claseMatch.group(1);
    }

    // Buscar fecha de vencimiento
    final vencimientoPattern = RegExp(
        r'VENC?\w*\s*:?\s*(\d{2})[\/\-](\d{2})[\/\-](\d{4})',
        caseSensitive: false);
    final vencimientoMatch = vencimientoPattern.firstMatch(fullText);
    if (vencimientoMatch != null) {
      licenciaData['fecha_vencimiento'] =
          '${vencimientoMatch.group(1)}/${vencimientoMatch.group(2)}/${vencimientoMatch.group(3)}';

      // Verificar si está vigente
      final vencimiento = DateTime(
        int.parse(vencimientoMatch.group(3)!),
        int.parse(vencimientoMatch.group(2)!),
        int.parse(vencimientoMatch.group(1)!),
      );
      licenciaData['esta_vigente'] = vencimiento.isAfter(DateTime.now());
    }

    // Buscar restricciones
    final restriccionesPattern =
        RegExp(r'RESTRICC?\w*\s*:?\s*([A-Z0-9\s,]+)', caseSensitive: false);
    final restriccionesMatch = restriccionesPattern.firstMatch(fullText);
    if (restriccionesMatch != null) {
      licenciaData['restricciones'] = restriccionesMatch.group(1)?.trim();
    }

    // Verificar keywords específicas de licencia peruana
    final expectedKeywords = ['LICENCIA', 'CONDUCIR', 'MTC', 'PERÚ'];
    var keywordCount = 0;
    for (final keyword in expectedKeywords) {
      if (fullText.toUpperCase().contains(keyword)) {
        keywordCount++;
      }
    }
    licenciaData['keyword_match_score'] =
        keywordCount / expectedKeywords.length;

    return licenciaData;
  }

  /// Procesa SOAT (Seguro Obligatorio de Accidentes de Tránsito)
  Future<Map<String, dynamic>> _processSOAT(
      String fullText, List<Map<String, dynamic>> structuredText) async {
    final soatData = <String, dynamic>{};

    // Buscar número de póliza
    final polizaPattern =
        RegExp(r'P[ÓO]LIZA\s*:?\s*([A-Z0-9]+)', caseSensitive: false);
    final polizaMatch = polizaPattern.firstMatch(fullText);
    if (polizaMatch != null) {
      soatData['numero_poliza'] = polizaMatch.group(1);
    }

    // Buscar placa del vehículo
    final placaPattern =
        RegExp(r'PLACA\s*:?\s*([A-Z0-9]{6,7})', caseSensitive: false);
    final placaMatch = placaPattern.firstMatch(fullText);
    if (placaMatch != null) {
      soatData['placa'] = placaMatch.group(1);
    }

    // Buscar vigencia
    final vigenciaPattern = RegExp(
        r'VIGENCIA\s*:?\s*(\d{2})[\/\-](\d{2})[\/\-](\d{4})\s*AL?\s*(\d{2})[\/\-](\d{2})[\/\-](\d{4})',
        caseSensitive: false);
    final vigenciaMatch = vigenciaPattern.firstMatch(fullText);
    if (vigenciaMatch != null) {
      soatData['fecha_inicio'] =
          '${vigenciaMatch.group(1)}/${vigenciaMatch.group(2)}/${vigenciaMatch.group(3)}';
      soatData['fecha_fin'] =
          '${vigenciaMatch.group(4)}/${vigenciaMatch.group(5)}/${vigenciaMatch.group(6)}';

      // Verificar si está vigente
      final fechaFin = DateTime(
        int.parse(vigenciaMatch.group(6)!),
        int.parse(vigenciaMatch.group(5)!),
        int.parse(vigenciaMatch.group(4)!),
      );
      soatData['esta_vigente'] = fechaFin.isAfter(DateTime.now());
    }

    // Buscar compañía aseguradora
    final companiaPattern = RegExp(
        r'(RIMAC|MAPFRE|PACÍFICO|LA POSITIVA|INTERSEGURO)',
        caseSensitive: false);
    final companiaMatch = companiaPattern.firstMatch(fullText);
    if (companiaMatch != null) {
      soatData['compania'] = companiaMatch.group(1);
    }

    // Verificar keywords del SOAT
    final expectedKeywords = ['SOAT', 'SEGURO', 'ACCIDENTES', 'TRÁNSITO'];
    var keywordCount = 0;
    for (final keyword in expectedKeywords) {
      if (fullText.toUpperCase().contains(keyword)) {
        keywordCount++;
      }
    }
    soatData['keyword_match_score'] = keywordCount / expectedKeywords.length;

    return soatData;
  }

  /// Procesa revisión técnica vehicular
  Future<Map<String, dynamic>> _processRevisionTecnica(
      String fullText, List<Map<String, dynamic>> structuredText) async {
    final revisionData = <String, dynamic>{};

    // Buscar número de certificado
    final certificadoPattern =
        RegExp(r'CERTIFICADO\s*:?\s*([A-Z0-9]+)', caseSensitive: false);
    final certificadoMatch = certificadoPattern.firstMatch(fullText);
    if (certificadoMatch != null) {
      revisionData['numero_certificado'] = certificadoMatch.group(1);
    }

    // Buscar placa
    final placaPattern =
        RegExp(r'PLACA\s*:?\s*([A-Z0-9]{6,7})', caseSensitive: false);
    final placaMatch = placaPattern.firstMatch(fullText);
    if (placaMatch != null) {
      revisionData['placa'] = placaMatch.group(1);
    }

    // Buscar resultado de la revisión
    if (fullText.toUpperCase().contains('APROBADO')) {
      revisionData['resultado'] = 'APROBADO';
    } else if (fullText.toUpperCase().contains('RECHAZADO') ||
        fullText.toUpperCase().contains('DESAPROBADO')) {
      revisionData['resultado'] = 'RECHAZADO';
    }

    // Buscar fecha de vencimiento
    final vencimientoPattern = RegExp(
        r'VENC?\w*\s*:?\s*(\d{2})[\/\-](\d{2})[\/\-](\d{4})',
        caseSensitive: false);
    final vencimientoMatch = vencimientoPattern.firstMatch(fullText);
    if (vencimientoMatch != null) {
      revisionData['fecha_vencimiento'] =
          '${vencimientoMatch.group(1)}/${vencimientoMatch.group(2)}/${vencimientoMatch.group(3)}';

      final vencimiento = DateTime(
        int.parse(vencimientoMatch.group(3)!),
        int.parse(vencimientoMatch.group(2)!),
        int.parse(vencimientoMatch.group(1)!),
      );
      revisionData['esta_vigente'] = vencimiento.isAfter(DateTime.now());
    }

    return revisionData;
  }

  /// Procesa tarjeta de propiedad vehicular
  Future<Map<String, dynamic>> _processTarjetaPropiedad(
      String fullText, List<Map<String, dynamic>> structuredText) async {
    final propiedadData = <String, dynamic>{};

    // Buscar placa
    final placaPattern =
        RegExp(r'PLACA\s*:?\s*([A-Z0-9]{6,7})', caseSensitive: false);
    final placaMatch = placaPattern.firstMatch(fullText);
    if (placaMatch != null) {
      propiedadData['placa'] = placaMatch.group(1);
    }

    // Buscar marca y modelo
    final marcaPattern = RegExp(r'MARCA\s*:?\s*([A-Z]+)', caseSensitive: false);
    final marcaMatch = marcaPattern.firstMatch(fullText);
    if (marcaMatch != null) {
      propiedadData['marca'] = marcaMatch.group(1);
    }

    final modeloPattern =
        RegExp(r'MODELO\s*:?\s*([A-Z0-9\s]+)', caseSensitive: false);
    final modeloMatch = modeloPattern.firstMatch(fullText);
    if (modeloMatch != null) {
      propiedadData['modelo'] = modeloMatch.group(1)?.trim();
    }

    // Buscar anio de fabricacion
    final anioPattern = RegExp(r'A[ÑN]O\s*:?\s*(\d{4})', caseSensitive: false);
    final anioMatch = anioPattern.firstMatch(fullText);
    if (anioMatch != null) {
      propiedadData['anio_fabricacion'] = anioMatch.group(1);
    }

    // Buscar número de motor
    final motorPattern =
        RegExp(r'MOTOR\s*:?\s*([A-Z0-9]+)', caseSensitive: false);
    final motorMatch = motorPattern.firstMatch(fullText);
    if (motorMatch != null) {
      propiedadData['numero_motor'] = motorMatch.group(1);
    }

    return propiedadData;
  }

  /// Procesa foto de perfil del conductor
  Future<Map<String, dynamic>> _processFotoPerfil(
      Map<String, dynamic> visionResults) async {
    final fotoData = <String, dynamic>{};

    // Analizar detección de rostros
    if (visionResults['faceAnnotations'] != null) {
      final faces = visionResults['faceAnnotations'] as List;

      fotoData['numero_rostros'] = faces.length;

      if (faces.isNotEmpty) {
        final face = faces.first;
        fotoData['confianza_deteccion'] = face['detectionConfidence'] ?? 0.0;

        // Analizar emociones y características
        fotoData['joy_likelihood'] = face['joyLikelihood'] ?? 'UNKNOWN';
        fotoData['sorrow_likelihood'] = face['sorrowLikelihood'] ?? 'UNKNOWN';
        fotoData['anger_likelihood'] = face['angerLikelihood'] ?? 'UNKNOWN';
        fotoData['surprise_likelihood'] =
            face['surpriseLikelihood'] ?? 'UNKNOWN';

        // Verificar calidad del rostro
        fotoData['under_exposed'] = face['underExposedLikelihood'] ?? 'UNKNOWN';
        fotoData['blurred'] = face['blurredLikelihood'] ?? 'UNKNOWN';
        fotoData['headwear'] = face['headwearLikelihood'] ?? 'UNKNOWN';

        // Determinar si es una buena foto para verificación
        final isGoodPhoto = _evaluateFaceQuality(face);
        fotoData['es_buena_foto'] = isGoodPhoto;
      }
    } else {
      fotoData['numero_rostros'] = 0;
      fotoData['es_buena_foto'] = false;
    }

    return fotoData;
  }

  /// Procesa foto de vehículo
  Future<Map<String, dynamic>> _processFotoVehiculo(
      Map<String, dynamic> visionResults) async {
    final vehiculoData = <String, dynamic>{};

    // Analizar objetos detectados
    if (visionResults['localizedObjectAnnotations'] != null) {
      final objects = visionResults['localizedObjectAnnotations'] as List;

      final vehicleObjects = objects
          .where((obj) =>
              obj['name'].toString().toLowerCase().contains('car') ||
              obj['name'].toString().toLowerCase().contains('vehicle') ||
              obj['name'].toString().toLowerCase().contains('truck') ||
              obj['name'].toString().toLowerCase().contains('taxi'))
          .toList();

      vehiculoData['vehiculos_detectados'] = vehicleObjects.length;

      if (vehicleObjects.isNotEmpty) {
        final vehicle = vehicleObjects.first;
        vehiculoData['confianza_vehiculo'] = vehicle['score'] ?? 0.0;
        vehiculoData['tipo_vehiculo'] = vehicle['name'] ?? 'unknown';
      }
    }

    // Buscar texto que pueda ser una placa
    final fullText = _extractFullText(visionResults);
    final placaPattern = RegExp(r'\b[A-Z0-9]{6,7}\b');
    final placaMatches = placaPattern.allMatches(fullText);

    if (placaMatches.isNotEmpty) {
      vehiculoData['posibles_placas'] =
          placaMatches.map((m) => m.group(0)).toList();
    }

    return vehiculoData;
  }

  /// Evalúa la calidad de un rostro detectado
  bool _evaluateFaceQuality(Map<String, dynamic> face) {
    final confidence = face['detectionConfidence'] ?? 0.0;
    final underExposed = face['underExposedLikelihood'] ?? 'UNKNOWN';
    final blurred = face['blurredLikelihood'] ?? 'UNKNOWN';
    final headwear = face['headwearLikelihood'] ?? 'UNKNOWN';

    // Verificar confianza mínima
    if (confidence < _qualityThresholds['min_face_confidence']!) {
      return false;
    }

    // Verificar que no esté subexpuesta
    if (underExposed == 'LIKELY' || underExposed == 'VERY_LIKELY') {
      return false;
    }

    // Verificar que no esté borrosa
    if (blurred == 'LIKELY' || blurred == 'VERY_LIKELY') {
      return false;
    }

    // Preferir fotos sin accesorios en la cabeza para mejor identificación
    if (headwear == 'LIKELY' || headwear == 'VERY_LIKELY') {
      return false;
    }

    return true;
  }

  /// Detecta idiomas en el texto
  List<String> _detectLanguages(Map<String, dynamic> visionResults) {
    final languages = <String>[];

    if (visionResults['fullTextAnnotation']?['pages'] != null) {
      for (final page in visionResults['fullTextAnnotation']['pages']) {
        if (page['property']?['detectedLanguages'] != null) {
          for (final lang in page['property']['detectedLanguages']) {
            final languageCode = lang['languageCode'];
            if (languageCode != null && !languages.contains(languageCode)) {
              languages.add(languageCode);
            }
          }
        }
      }
    }

    return languages.isEmpty ? ['es'] : languages; // Default español para Perú
  }

  /// Calcula confianza promedio del texto detectado
  double _calculateTextConfidence(Map<String, dynamic> visionResults) {
    var totalConfidence = 0.0;
    var count = 0;

    if (visionResults['textAnnotations'] != null) {
      for (final annotation in visionResults['textAnnotations']) {
        if (annotation['confidence'] != null) {
          totalConfidence += annotation['confidence'];
          count++;
        }
      }
    }

    return count > 0 ? totalConfidence / count : 0.0;
  }

  /// Verifica calidad general de la imagen
  Future<ImageQualityCheck> _checkImageQuality(
      Map<String, dynamic> visionResults) async {
    var isGoodQuality = true;
    final issues = <String>[];
    var qualityScore = 1.0;

    // Verificar propiedades de la imagen
    if (visionResults['imagePropertiesAnnotation'] != null) {
      final properties = visionResults['imagePropertiesAnnotation'];

      // Verificar brillo
      if (properties['dominantColors']?['colors'] != null) {
        final colors = properties['dominantColors']['colors'] as List;
        var brightness = 0.0;

        for (final color in colors) {
          final rgb = color['color'];
          final pixelFraction = color['pixelFraction'] ?? 0.0;

          if (rgb != null) {
            final r = rgb['red'] ?? 0;
            final g = rgb['green'] ?? 0;
            final b = rgb['blue'] ?? 0;

            // Calcular brillo percibido
            final perceivedBrightness =
                (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
            brightness += perceivedBrightness * pixelFraction;
          }
        }

        if (brightness < _qualityThresholds['min_brightness']!) {
          isGoodQuality = false;
          issues.add('Imagen muy oscura');
          qualityScore *= 0.7;
        } else if (brightness > _qualityThresholds['max_brightness']!) {
          isGoodQuality = false;
          issues.add('Imagen muy brillante');
          qualityScore *= 0.7;
        }
      }
    }

    // Verificar detección de contenido inapropiado
    if (visionResults['safeSearchAnnotation'] != null) {
      final safeSearch = visionResults['safeSearchAnnotation'];

      if (safeSearch['adult'] == 'LIKELY' ||
          safeSearch['adult'] == 'VERY_LIKELY') {
        isGoodQuality = false;
        issues.add('Contenido inapropiado detectado');
        qualityScore *= 0.1;
      }

      if (safeSearch['violence'] == 'LIKELY' ||
          safeSearch['violence'] == 'VERY_LIKELY') {
        isGoodQuality = false;
        issues.add('Contenido violento detectado');
        qualityScore *= 0.1;
      }
    }

    // Verificar cantidad de texto detectado
    final textConfidence = _calculateTextConfidence(visionResults);
    if (textConfidence < _qualityThresholds['min_text_confidence']!) {
      isGoodQuality = false;
      issues.add('Texto poco legible');
      qualityScore *= 0.8;
    }

    return ImageQualityCheck(
      isGoodQuality: isGoodQuality,
      qualityScore: qualityScore,
      issues: issues,
      brightness: 0.5, // Placeholder - se calcularía realmente
      contrast: 0.7, // Placeholder
      sharpness: 0.8, // Placeholder
    );
  }

  /// Valida datos extraídos según reglas específicas
  Future<ValidationResult> _validateExtractedData({
    required String documentType,
    required Map<String, dynamic> extractedData,
  }) async {
    var isValid = true;
    final errors = <String>[];
    final warnings = <String>[];

    try {
      switch (documentType) {
        case 'dni':
          final validationDNI = await _validateDNI(extractedData);
          isValid = validationDNI.isValid;
          errors.addAll(validationDNI.errors);
          warnings.addAll(validationDNI.warnings);
          break;

        case 'licencia_conducir':
          final validationLicencia =
              await _validateLicenciaConducir(extractedData);
          isValid = validationLicencia.isValid;
          errors.addAll(validationLicencia.errors);
          warnings.addAll(validationLicencia.warnings);
          break;

        case 'soat':
          final validationSOAT = await _validateSOAT(extractedData);
          isValid = validationSOAT.isValid;
          errors.addAll(validationSOAT.errors);
          warnings.addAll(validationSOAT.warnings);
          break;

        case 'foto_perfil':
          final validationFoto = await _validateFotoPerfil(extractedData);
          isValid = validationFoto.isValid;
          errors.addAll(validationFoto.errors);
          warnings.addAll(validationFoto.warnings);
          break;
      }

      return ValidationResult(
        isValid: isValid,
        errors: errors,
        warnings: warnings,
        validationScore: errors.isEmpty ? 1.0 : (warnings.isEmpty ? 0.5 : 0.0),
      );
    } catch (e) {
      AppLogger.error('Error validando datos extraídos', e);
      return ValidationResult(
        isValid: false,
        errors: ['Error en validación: ${e.toString()}'],
        warnings: [],
        validationScore: 0.0,
      );
    }
  }

  /// Valida datos de DNI extraídos
  Future<ValidationResult> _validateDNI(Map<String, dynamic> data) async {
    final errors = <String>[];
    final warnings = <String>[];

    // Validar número de DNI
    final numeroDNI = data['numero_dni']?.toString();
    if (numeroDNI == null || !_documentPatterns['dni']!.hasMatch(numeroDNI)) {
      errors.add('Número de DNI inválido o no detectado');
    }

    // Validar nombres
    if (data['nombres'] == null ||
        data['nombres'].toString().trim().length < 2) {
      errors.add('Nombres no detectados correctamente');
    }

    // Validar apellidos
    if (data['apellidos'] == null ||
        data['apellidos'].toString().trim().length < 2) {
      errors.add('Apellidos no detectados correctamente');
    }

    // Validar fecha de nacimiento
    if (data['fecha_nacimiento'] != null) {
      try {
        final fechaParts = data['fecha_nacimiento'].toString().split('/');
        if (fechaParts.length == 3) {
          final anio = int.parse(fechaParts[2]);
          final anioActual = DateTime.now().year;

          if (anio > anioActual || anio < (anioActual - 120)) {
            warnings.add('Fecha de nacimiento sospechosa');
          }
        }
      } catch (e) {
        warnings.add('Formato de fecha de nacimiento inválido');
      }
    }

    // Validar keyword match score
    final keywordScore = data['keyword_match_score'] ?? 0.0;
    if (keywordScore < 0.5) {
      warnings.add('Documento no parece ser un DNI peruano válido');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      validationScore: errors.isEmpty ? (warnings.isEmpty ? 1.0 : 0.8) : 0.0,
    );
  }

  /// Valida datos de licencia de conducir
  Future<ValidationResult> _validateLicenciaConducir(
      Map<String, dynamic> data) async {
    final errors = <String>[];
    final warnings = <String>[];

    // Validar número de licencia
    final numeroLicencia = data['numero_licencia']?.toString();
    if (numeroLicencia == null ||
        !_documentPatterns['licencia']!.hasMatch(numeroLicencia)) {
      errors.add('Número de licencia inválido o no detectado');
    }

    // Validar vigencia
    if (data['esta_vigente'] == false) {
      errors.add('Licencia de conducir vencida');
    } else if (data['fecha_vencimiento'] == null) {
      warnings.add('Fecha de vencimiento no detectada');
    }

    // Validar clase de licencia (debe ser válida para taxi)
    final clase = data['clase']?.toString().toUpperCase();
    final clasesValidasTaxi = ['A-IIA', 'A-IIB', 'A-IIIA', 'A-IIIB', 'A-IIIC'];

    if (clase != null &&
        !clasesValidasTaxi.any((validClass) => clase.contains(validClass))) {
      warnings.add('Clase de licencia puede no ser válida para taxi');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      validationScore: errors.isEmpty ? (warnings.isEmpty ? 1.0 : 0.8) : 0.0,
    );
  }

  /// Valida datos de SOAT
  Future<ValidationResult> _validateSOAT(Map<String, dynamic> data) async {
    final errors = <String>[];
    final warnings = <String>[];

    // Validar vigencia
    if (data['esta_vigente'] == false) {
      errors.add('SOAT vencido');
    }

    // Validar número de póliza
    if (data['numero_poliza'] == null) {
      errors.add('Número de póliza no detectado');
    }

    // Validar placa
    final placa = data['placa']?.toString();
    if (placa == null || placa.length < 6) {
      warnings.add('Placa del vehículo no detectada correctamente');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      validationScore: errors.isEmpty ? (warnings.isEmpty ? 1.0 : 0.8) : 0.0,
    );
  }

  /// Valida foto de perfil
  Future<ValidationResult> _validateFotoPerfil(
      Map<String, dynamic> data) async {
    final errors = <String>[];
    final warnings = <String>[];

    // Validar que se detectó exactamente un rostro
    final numeroRostros = data['numero_rostros'] ?? 0;
    if (numeroRostros == 0) {
      errors.add('No se detectó ningún rostro en la imagen');
    } else if (numeroRostros > 1) {
      errors.add('Se detectaron múltiples rostros. Use una foto individual.');
    }

    // Validar calidad de la foto
    if (data['es_buena_foto'] == false) {
      errors.add('Calidad de la foto insuficiente para verificación');
    }

    // Validar confianza de detección
    final confianza = data['confianza_deteccion'] ?? 0.0;
    if (confianza < _qualityThresholds['min_face_confidence']!) {
      warnings.add('Confianza de detección de rostro baja');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      validationScore: errors.isEmpty ? (warnings.isEmpty ? 1.0 : 0.8) : 0.0,
    );
  }

  /// Calcula confianza general del resultado
  double _calculateOverallConfidence({
    required Map<String, dynamic> visionResults,
    required ImageQualityCheck qualityCheck,
    required ValidationResult validationResult,
  }) {
    final textConfidence = _calculateTextConfidence(visionResults);
    final qualityScore = qualityCheck.qualityScore;
    final validationScore = validationResult.validationScore;

    // Peso balanceado entre todos los factores
    final overallConfidence =
        (textConfidence * 0.4) + (qualityScore * 0.3) + (validationScore * 0.3);

    return overallConfidence.clamp(0.0, 1.0);
  }

  /// Guarda resultado de verificación en Firestore
  Future<void> _saveVerificationResult(
      DocumentVerificationResult result) async {
    try {
      final docRef = _firestore
          .collection('drivers')
          .doc(result.driverId)
          .collection('document_verifications')
          .doc(
              '${result.documentType}_${result.verificationTimestamp.millisecondsSinceEpoch}');

      // Preparar datos para Firestore (sin información sensible de Vision API)
      final firestoreData = {
        'driver_id': result.driverId,
        'document_type': result.documentType,
        'file_name': result.fileName,
        'storage_url': result.storageUrl,
        'extracted_data': _sanitizeExtractedData(result.extractedData),
        'overall_confidence': result.overallConfidence,
        'is_auto_approved': result.isAutoApproved,
        'needs_manual_review': result.needsManualReview,
        'verification_timestamp':
            Timestamp.fromDate(result.verificationTimestamp),
        'quality_check': {
          'is_good_quality': result.qualityCheck.isGoodQuality,
          'quality_score': result.qualityCheck.qualityScore,
          'issues': result.qualityCheck.issues,
        },
        'validation_result': {
          'is_valid': result.validationResult.isValid,
          'errors': result.validationResult.errors,
          'warnings': result.validationResult.warnings,
          'validation_score': result.validationResult.validationScore,
        },
        'error': result.error,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      await docRef.set(firestoreData);

      // Actualizar estado general del conductor si es necesario
      await _updateDriverVerificationStatus(result);

      AppLogger.info(
          'Resultado de verificación guardado en Firestore: ${docRef.id}');
    } catch (e, stackTrace) {
      AppLogger.error(
          'Error guardando resultado de verificación', e, stackTrace);
      rethrow;
    }
  }

  /// Sanitiza datos extraídos para almacenamiento seguro
  Map<String, dynamic> _sanitizeExtractedData(
      Map<String, dynamic> extractedData) {
    final sanitized = Map<String, dynamic>.from(extractedData);

    // Remover datos sensibles que no deben persistirse
    sanitized
        .remove('full_text'); // Texto completo puede contener info sensible
    sanitized.remove('visionApiResults'); // Resultados completos de Vision API

    // Mantener solo datos necesarios para la aplicación
    return sanitized;
  }

  /// Actualiza estado de verificación general del conductor
  Future<void> _updateDriverVerificationStatus(
      DocumentVerificationResult result) async {
    try {
      final driverRef = _firestore.collection('drivers').doc(result.driverId);

      await _firestore.runTransaction((transaction) async {
        final driverDoc = await transaction.get(driverRef);

        if (!driverDoc.exists) {
          throw Exception('Conductor no encontrado: ${result.driverId}');
        }

        final driverData = driverDoc.data()!;
        final verificationStatus =
            driverData['verification_status'] as Map<String, dynamic>? ?? {};

        // Actualizar estado del documento específico
        verificationStatus[result.documentType] = {
          'status': result.isAutoApproved ? 'approved' : 'pending_review',
          'confidence': result.overallConfidence,
          'last_verification': Timestamp.fromDate(result.verificationTimestamp),
          'needs_manual_review': result.needsManualReview,
        };

        // Calcular estado general
        final requiredDocs = [
          'dni',
          'licencia_conducir',
          'soat',
          'foto_perfil'
        ];
        var allDocsApproved = true;
        var pendingReview = false;

        for (final docType in requiredDocs) {
          final docStatus = verificationStatus[docType];
          if (docStatus == null || docStatus['status'] != 'approved') {
            allDocsApproved = false;
          }
          if (docStatus?['needs_manual_review'] == true) {
            pendingReview = true;
          }
        }

        String generalStatus;
        if (allDocsApproved) {
          generalStatus = 'approved';
        } else if (pendingReview) {
          generalStatus = 'pending_review';
        } else {
          generalStatus = 'pending_documents';
        }

        // Actualizar documento del conductor
        transaction.update(driverRef, {
          'verification_status': verificationStatus,
          'general_verification_status': generalStatus,
          'last_document_update': FieldValue.serverTimestamp(),
        });
      });

      AppLogger.info(
          'Estado de verificación del conductor actualizado: ${result.driverId}');
    } catch (e, stackTrace) {
      AppLogger.error('Error actualizando estado de verificación del conductor',
          e, stackTrace);
      // No re-lanzar error para no afectar el flujo principal
    }
  }

  /// Obtiene estado de verificación de un conductor
  Future<Map<String, dynamic>?> getDriverVerificationStatus(
      String driverId) async {
    try {
      final driverDoc =
          await _firestore.collection('drivers').doc(driverId).get();

      if (!driverDoc.exists) {
        return null;
      }

      final data = driverDoc.data()!;
      return {
        'general_status':
            data['general_verification_status'] ?? 'pending_documents',
        'verification_status': data['verification_status'] ?? {},
        'last_update': data['last_document_update'],
      };
    } catch (e, stackTrace) {
      AppLogger.error('Error obteniendo estado de verificación', e, stackTrace);
      return null;
    }
  }

  /// Obtiene historial de verificaciones de un documento
  Future<List<DocumentVerificationResult>> getDocumentVerificationHistory({
    required String driverId,
    required String documentType,
    int limit = 10,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('document_verifications')
          .where('document_type', isEqualTo: documentType)
          .orderBy('verification_timestamp', descending: true)
          .limit(limit)
          .get();

      final results = <DocumentVerificationResult>[];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        // Reconstruir resultado desde Firestore
        final result = DocumentVerificationResult.fromFirestore(data);
        results.add(result);
      }

      return results;
    } catch (e, stackTrace) {
      AppLogger.error(
          'Error obteniendo historial de verificaciones', e, stackTrace);
      return [];
    }
  }

  /// Re-procesa un documento ya verificado
  Future<DocumentVerificationResult> reprocessDocument({
    required String driverId,
    required String documentType,
    required String storageUrl,
  }) async {
    try {
      AppLogger.info(
          'Re-procesando documento: $documentType para conductor: $driverId');

      // Descargar imagen desde Storage
      final storageRef = _storage.ref().child(storageUrl);
      final imageBytes = await storageRef.getData();

      if (imageBytes == null) {
        throw Exception('No se pudo descargar la imagen desde Storage');
      }

      // Obtener nombre del archivo desde metadata
      final metadata = await storageRef.getMetadata();
      final fileName =
          metadata.customMetadata?['original_filename'] ?? 'reprocess.jpg';

      // Verificar documento nuevamente
      return await verifyDocument(
        driverId: driverId,
        documentType: documentType,
        imageBytes: imageBytes,
        fileName: fileName,
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error re-procesando documento', e, stackTrace);
      rethrow;
    }
  }

  /// Libera recursos utilizados por el servicio
  /// Debe llamarse cuando el servicio ya no se necesita
  void dispose() {
    // No hay recursos que liberar actualmente ya que usamos Cloud Functions
    // Este método está disponible para futuras extensiones
    AppLogger.debug('DocumentVerificationService disposed');
  }
}

/// Resultado de verificación de documento
class DocumentVerificationResult {
  final String driverId;
  final String documentType;
  final String fileName;
  final String? storageUrl;
  final Map<String, dynamic> extractedData;
  final ImageQualityCheck qualityCheck;
  final ValidationResult validationResult;
  final double overallConfidence;
  final bool isAutoApproved;
  final bool needsManualReview;
  final DateTime verificationTimestamp;
  final Map<String, dynamic>? visionApiResults;
  final String? error;

  DocumentVerificationResult({
    required this.driverId,
    required this.documentType,
    required this.fileName,
    this.storageUrl,
    required this.extractedData,
    required this.qualityCheck,
    required this.validationResult,
    required this.overallConfidence,
    required this.isAutoApproved,
    required this.needsManualReview,
    required this.verificationTimestamp,
    this.visionApiResults,
    this.error,
  });

  /// Constructor para errores
  factory DocumentVerificationResult.error({
    required String driverId,
    required String documentType,
    required String fileName,
    required String error,
  }) {
    return DocumentVerificationResult(
      driverId: driverId,
      documentType: documentType,
      fileName: fileName,
      extractedData: {},
      qualityCheck: ImageQualityCheck.error(),
      validationResult: ValidationResult.error(error),
      overallConfidence: 0.0,
      isAutoApproved: false,
      needsManualReview: true,
      verificationTimestamp: DateTime.now(),
      error: error,
    );
  }

  /// Constructor desde datos de Firestore
  factory DocumentVerificationResult.fromFirestore(Map<String, dynamic> data) {
    return DocumentVerificationResult(
      driverId: data['driver_id'] ?? '',
      documentType: data['document_type'] ?? '',
      fileName: data['file_name'] ?? '',
      storageUrl: data['storage_url'],
      extractedData: Map<String, dynamic>.from(data['extracted_data'] ?? {}),
      qualityCheck: ImageQualityCheck.fromMap(data['quality_check'] ?? {}),
      validationResult:
          ValidationResult.fromMap(data['validation_result'] ?? {}),
      overallConfidence: (data['overall_confidence'] ?? 0.0).toDouble(),
      isAutoApproved: data['is_auto_approved'] ?? false,
      needsManualReview: data['needs_manual_review'] ?? true,
      verificationTimestamp:
          (data['verification_timestamp'] as Timestamp?)?.toDate() ??
              DateTime.now(),
      error: data['error'],
    );
  }

  bool get hasError => error != null;
  bool get isSuccessful => error == null;
}

/// Resultado de verificación de calidad de imagen
class ImageQualityCheck {
  final bool isGoodQuality;
  final double qualityScore;
  final List<String> issues;
  final double brightness;
  final double contrast;
  final double sharpness;

  ImageQualityCheck({
    required this.isGoodQuality,
    required this.qualityScore,
    required this.issues,
    required this.brightness,
    required this.contrast,
    required this.sharpness,
  });

  factory ImageQualityCheck.error() {
    return ImageQualityCheck(
      isGoodQuality: false,
      qualityScore: 0.0,
      issues: ['Error en análisis de calidad'],
      brightness: 0.0,
      contrast: 0.0,
      sharpness: 0.0,
    );
  }

  factory ImageQualityCheck.fromMap(Map<String, dynamic> map) {
    return ImageQualityCheck(
      isGoodQuality: map['is_good_quality'] ?? false,
      qualityScore: (map['quality_score'] ?? 0.0).toDouble(),
      issues: List<String>.from(map['issues'] ?? []),
      brightness: (map['brightness'] ?? 0.0).toDouble(),
      contrast: (map['contrast'] ?? 0.0).toDouble(),
      sharpness: (map['sharpness'] ?? 0.0).toDouble(),
    );
  }
}

/// Resultado de validación de datos extraídos
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final double validationScore;

  ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    required this.validationScore,
  });

  factory ValidationResult.error(String error) {
    return ValidationResult(
      isValid: false,
      errors: [error],
      warnings: [],
      validationScore: 0.0,
    );
  }

  factory ValidationResult.fromMap(Map<String, dynamic> map) {
    return ValidationResult(
      isValid: map['is_valid'] ?? false,
      errors: List<String>.from(map['errors'] ?? []),
      warnings: List<String>.from(map['warnings'] ?? []),
      validationScore: (map['validation_score'] ?? 0.0).toDouble(),
    );
  }
}
