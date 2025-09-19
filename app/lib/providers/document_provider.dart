import '../utils/app_logger.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../services/firebase_service.dart';
import '../models/document_model.dart';

class DocumentProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseService().firestore;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  // Estados
  bool _isLoading = false;
  String? _error;
  double _uploadProgress = 0.0;

  // Documentos usando el nuevo modelo
  List<DocumentModel> _documents = [];
  DriverVerificationStatus? _verificationStatus;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get uploadProgress => _uploadProgress;
  List<DocumentModel> get documents => _documents;
  DriverVerificationStatus? get verificationStatus => _verificationStatus;

  // Obtener todos los tipos de documentos requeridos
  List<DocumentType> get requiredDocumentTypes =>
      DocumentType.values.where((type) => type.isRequired).toList();

  /// Cargar documentos del conductor
  Future<void> loadDriverDocuments(String driverId) async {
    _setLoading(true);
    _clearError();

    try {
      // Cargar documentos desde Firestore
      final documentsSnapshot = await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('documents')
          .get();

      _documents = documentsSnapshot.docs.map((doc) {
        return DocumentModel.fromFirestore(doc.data(), doc.id);
      }).toList();

      // Cargar estado de verificación del conductor
      await _loadDriverVerificationStatus(driverId);

      // Crear documentos faltantes con estado pending
      await _createMissingDocuments(driverId);
    } catch (e) {
      _setError('Error al cargar documentos: $e');
    }

    _setLoading(false);
  }

  /// Cargar estado de verificación del conductor
  Future<void> _loadDriverVerificationStatus(String driverId) async {
    try {
      final driverDoc =
          await _firestore.collection('drivers').doc(driverId).get();

      if (driverDoc.exists) {
        _verificationStatus = DriverVerificationStatus.fromFirestore(
          driverDoc.data() ?? {},
          _documents,
        );
      }
    } catch (e) {
      AppLogger.debug('Error al cargar estado de verificación: $e');
    }
  }

  /// Crear documentos faltantes con estado pending
  Future<void> _createMissingDocuments(String driverId) async {
    final existingTypes = _documents.map((doc) => doc.type).toSet();

    for (final type in DocumentType.values) {
      if (!existingTypes.contains(type)) {
        final newDocument = DocumentModel(
          id: type.value,
          type: type,
          status: DocumentStatus.pending,
        );

        _documents.add(newDocument);

        // Crear documento en Firestore
        try {
          await _firestore
              .collection('drivers')
              .doc(driverId)
              .collection('documents')
              .doc(type.value)
              .set(newDocument.toFirestore());
        } catch (e) {
          AppLogger.debug(
              'Error al crear documento faltante ${type.value}: $e');
        }
      }
    }

    // Ordenar documentos por tipo
    _documents.sort((a, b) => a.type.displayName.compareTo(b.type.displayName));
  }

  /// Tomar foto desde cámara
  Future<bool> takePhotoFromCamera({
    required String driverId,
    required DocumentType documentType,
  }) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image != null) {
        return await _uploadDocument(
          driverId: driverId,
          documentType: documentType,
          file: File(image.path),
          fileName: image.name,
        );
      }
      return false;
    } catch (e) {
      _setError('Error al acceder a la cámara: $e');
      return false;
    }
  }

  /// Seleccionar foto desde galería
  Future<bool> pickImageFromGallery({
    required String driverId,
    required DocumentType documentType,
  }) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image != null) {
        return await _uploadDocument(
          driverId: driverId,
          documentType: documentType,
          file: File(image.path),
          fileName: image.name,
        );
      }
      return false;
    } catch (e) {
      _setError('Error al acceder a la galería: $e');
      return false;
    }
  }

  /// Subir documento a Firebase Storage y actualizar Firestore
  Future<bool> _uploadDocument({
    required String driverId,
    required DocumentType documentType,
    required File file,
    String? fileName,
  }) async {
    _setLoading(true);
    _uploadProgress = 0.0;
    _clearError();

    try {
      // Generar nombre único para el archivo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = fileName?.split('.').last ?? 'jpg';
      final uniqueFileName = '${documentType.value}_$timestamp.$extension';

      // Crear referencia en Storage
      final storageRef = _storage
          .ref()
          .child('drivers')
          .child(driverId)
          .child('documents')
          .child(uniqueFileName);

      // Subir archivo con progreso
      final uploadTask = storageRef.putFile(file);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        notifyListeners();
      });

      // Esperar a que termine la subida
      await uploadTask;

      // Obtener URL de descarga
      final downloadUrl = await storageRef.getDownloadURL();

      // Crear documento actualizado
      final updatedDocument = DocumentModel(
        id: documentType.value,
        type: documentType,
        status: DocumentStatus.pending,
        url: downloadUrl,
        fileName: uniqueFileName,
        uploadedAt: DateTime.now(),
      );

      // Actualizar en Firestore
      await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('documents')
          .doc(documentType.value)
          .set(updatedDocument.toFirestore(), SetOptions(merge: true));

      // Actualizar documento local
      final index = _documents.indexWhere((doc) => doc.type == documentType);
      if (index != -1) {
        _documents[index] = updatedDocument;
      } else {
        _documents.add(updatedDocument);
      }

      // Crear notificación para admin si es la primera vez que sube este tipo
      await _createAdminNotification(
          driverId, documentType, 'document_uploaded');

      _setLoading(false);
      _uploadProgress = 0.0;
      return true;
    } catch (e) {
      _setError('Error al subir documento: $e');
      _setLoading(false);
      _uploadProgress = 0.0;
      return false;
    }
  }

  /// Eliminar documento
  Future<bool> deleteDocument({
    required String driverId,
    required DocumentType documentType,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final document = _documents.firstWhere(
        (doc) => doc.type == documentType,
        orElse: () => throw Exception('Documento no encontrado'),
      );

      // Eliminar archivo de Storage si existe
      if (document.fileName != null) {
        try {
          final storageRef = _storage
              .ref()
              .child('drivers')
              .child(driverId)
              .child('documents')
              .child(document.fileName!);
          await storageRef.delete();
        } catch (e) {
          AppLogger.debug('Error al eliminar archivo de Storage: $e');
        }
      }

      // Actualizar documento en Firestore (resetear a estado inicial)
      final resetDocument = DocumentModel(
        id: documentType.value,
        type: documentType,
        status: DocumentStatus.pending,
      );

      await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('documents')
          .doc(documentType.value)
          .set(resetDocument.toFirestore());

      // Actualizar documento local
      final index = _documents.indexWhere((doc) => doc.type == documentType);
      if (index != -1) {
        _documents[index] = resetDocument;
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error al eliminar documento: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Solicitar verificación de documentos
  Future<bool> requestVerification(String driverId) async {
    if (!_canRequestVerification()) {
      _setError(
          'Por favor sube todos los documentos requeridos antes de solicitar verificación');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      // Actualizar estado del conductor
      await _firestore.collection('drivers').doc(driverId).update({
        'verificationStatus': 'under_review',
        'verificationRequestedAt': FieldValue.serverTimestamp(),
      });

      // Actualizar todos los documentos a estado "under_review"
      final batch = _firestore.batch();

      for (final document in _documents) {
        if (document.url != null && document.type.isRequired) {
          final docRef = _firestore
              .collection('drivers')
              .doc(driverId)
              .collection('documents')
              .doc(document.type.value);

          batch.update(docRef, {
            'status': DocumentStatus.underReview.value,
          });
        }
      }

      await batch.commit();

      // Crear notificación para admin
      await _createAdminNotification(driverId, null, 'verification_request');

      // Actualizar estado local
      for (int i = 0; i < _documents.length; i++) {
        if (_documents[i].url != null && _documents[i].type.isRequired) {
          _documents[i] = _documents[i].copyWith(
            status: DocumentStatus.underReview,
          );
        }
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error al solicitar verificación: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Verificar si se puede solicitar verificación
  bool _canRequestVerification() {
    final requiredDocuments = _documents.where((doc) => doc.type.isRequired);
    return requiredDocuments.every((doc) => doc.url != null);
  }

  /// Crear notificación para administrador
  Future<void> _createAdminNotification(
      String driverId, DocumentType? documentType, String type) async {
    try {
      await _firestore.collection('admin_notifications').add({
        'type': type,
        'driverId': driverId,
        'documentType': documentType?.value,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'priority': type == 'verification_request' ? 'high' : 'normal',
      });
    } catch (e) {
      AppLogger.debug('Error al crear notificación de admin: $e');
    }
  }

  /// Obtener documento por tipo
  DocumentModel? getDocumentByType(DocumentType type) {
    try {
      return _documents.firstWhere((doc) => doc.type == type);
    } catch (e) {
      return null;
    }
  }

  /// Obtener documentos que necesitan acción del conductor
  List<DocumentModel> getDocumentsNeedingAction() {
    return _documents.where((doc) => doc.needsDriverAction).toList();
  }

  /// Obtener documentos por estado
  List<DocumentModel> getDocumentsByStatus(DocumentStatus status) {
    return _documents.where((doc) => doc.status == status).toList();
  }

  /// Verificar si todos los documentos requeridos están aprobados
  bool get allRequiredDocumentsApproved {
    final requiredDocuments = _documents.where((doc) => doc.type.isRequired);
    return requiredDocuments.isNotEmpty &&
        requiredDocuments.every((doc) => doc.status == DocumentStatus.approved);
  }

  /// Obtener progreso de verificación (0.0 a 1.0)
  double get verificationProgress {
    final requiredDocuments = _documents.where((doc) => doc.type.isRequired);
    if (requiredDocuments.isEmpty) return 0.0;

    final approvedCount = requiredDocuments
        .where((doc) => doc.status == DocumentStatus.approved)
        .length;

    return approvedCount / requiredDocuments.length;
  }

  /// Métodos auxiliares de estado
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  /// Limpiar todos los datos
  void clearData() {
    _documents.clear();
    _verificationStatus = null;
    _error = null;
    _isLoading = false;
    _uploadProgress = 0.0;
    notifyListeners();
  }

  /// Escuchar cambios en tiempo real (para futuras implementaciones)
  Stream<List<DocumentModel>> streamDriverDocuments(String driverId) {
    return _firestore
        .collection('drivers')
        .doc(driverId)
        .collection('documents')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return DocumentModel.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }
}
