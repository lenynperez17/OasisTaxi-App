import '../utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firebase_service.dart';
import '../models/document_model.dart';

/// Provider para gestión de documentos desde el panel de administrador
class AdminDocumentProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseService().firestore;

  // Estados
  bool _isLoading = false;
  String? _error;

  // Datos
  final List<DriverDocumentBatch> _pendingVerifications = [];
  List<AdminNotification> _notifications = [];
  final Map<String, DriverInfo> _driversCache = {};

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<DriverDocumentBatch> get pendingVerifications => _pendingVerifications;
  List<AdminNotification> get notifications => _notifications;
  int get pendingCount => _pendingVerifications.length;
  int get unreadNotificationsCount =>
      _notifications.where((n) => !n.read).length;

  /// Cargar conductores pendientes de verificación
  Future<void> loadPendingVerifications() async {
    _setLoading(true);
    _clearError();

    try {
      // Obtener conductores con verificación pendiente
      final driversSnapshot = await _firestore.collection('drivers').where(
          'verificationStatus',
          whereIn: ['under_review', 'pending']).get();

      _pendingVerifications.clear();

      for (final driverDoc in driversSnapshot.docs) {
        final driverId = driverDoc.id;
        final driverData = driverDoc.data();

        // Cargar información del conductor
        final driverInfo = await _loadDriverInfo(driverId, driverData);
        _driversCache[driverId] = driverInfo;

        // Cargar documentos del conductor
        final documentsSnapshot = await _firestore
            .collection('drivers')
            .doc(driverId)
            .collection('documents')
            .get();

        final documents = documentsSnapshot.docs.map((doc) {
          return DocumentModel.fromFirestore(doc.data(), doc.id);
        }).toList();

        // Filtrar solo documentos que necesitan revisión
        final documentsToReview = documents
            .where((doc) =>
                doc.status == DocumentStatus.underReview ||
                (doc.status == DocumentStatus.pending && doc.url != null))
            .toList();

        if (documentsToReview.isNotEmpty) {
          _pendingVerifications.add(DriverDocumentBatch(
            driverInfo: driverInfo,
            documents: documentsToReview,
            verificationStatus: driverData['verificationStatus'] ?? 'pending',
            requestedAt: driverData['verificationRequestedAt'] is Timestamp
                ? (driverData['verificationRequestedAt'] as Timestamp).toDate()
                : DateTime.now(),
          ));
        }
      }

      // Ordenar por fecha de solicitud (más recientes primero)
      _pendingVerifications
          .sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    } catch (e) {
      _setError('Error al cargar verificaciones pendientes: $e');
    }

    _setLoading(false);
  }

  /// Cargar información del conductor
  Future<DriverInfo> _loadDriverInfo(
      String driverId, Map<String, dynamic> driverData) async {
    // Obtener datos del usuario
    final userDoc = await _firestore.collection('users').doc(driverId).get();
    final userData = userDoc.data() ?? {};

    return DriverInfo(
      id: driverId,
      name: userData['name'] ?? driverData['name'] ?? 'Sin nombre',
      email: userData['email'] ?? driverData['email'] ?? 'Sin email',
      phone: userData['phone'] ?? driverData['phone'] ?? 'Sin teléfono',
      photoUrl: userData['photoUrl'] ?? driverData['photoUrl'],
      rating: (driverData['rating'] ?? 0.0).toDouble(),
      totalTrips: driverData['totalTrips'] ?? 0,
      joinDate: userData['createdAt'] is Timestamp
          ? (userData['createdAt'] as Timestamp).toDate()
          : driverData['memberSince'] is Timestamp
              ? (driverData['memberSince'] as Timestamp).toDate()
              : null,
      vehicleInfo: driverData['vehicle'] != null
          ? VehicleInfo.fromMap(driverData['vehicle'])
          : null,
    );
  }

  /// Aprobar documento
  Future<bool> approveDocument({
    required String driverId,
    required DocumentType documentType,
    String? comments,
    DateTime? expiryDate,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Actualizar documento en Firestore
      await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('documents')
          .doc(documentType.value)
          .update({
        'status': DocumentStatus.approved.value,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': FirebaseAuth.instance.currentUser?.uid ?? 'admin',
        'rejectionReason': null,
        'comments': comments,
        if (expiryDate != null) 'expiryDate': Timestamp.fromDate(expiryDate),
      });

      // Actualizar documento local
      _updateLocalDocument(driverId, documentType, DocumentStatus.approved);

      // Verificar si todos los documentos requeridos están aprobados
      await _checkAndUpdateDriverVerificationStatus(driverId);

      // Crear notificación para el conductor
      await _createDriverNotification(
        driverId,
        'document_approved',
        'Tu documento ${documentType.displayName} ha sido aprobado',
        {'documentType': documentType.value},
      );

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error al aprobar documento: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Rechazar documento
  Future<bool> rejectDocument({
    required String driverId,
    required DocumentType documentType,
    required String rejectionReason,
    String? comments,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Actualizar documento en Firestore
      await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('documents')
          .doc(documentType.value)
          .update({
        'status': DocumentStatus.rejected.value,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': FirebaseAuth.instance.currentUser?.uid ?? 'admin',
        'rejectionReason': rejectionReason,
        'comments': comments,
      });

      // Actualizar documento local
      _updateLocalDocument(driverId, documentType, DocumentStatus.rejected);

      // Actualizar estado del conductor a rechazado
      await _firestore.collection('drivers').doc(driverId).update({
        'verificationStatus': 'rejected',
        'rejectionReason': rejectionReason,
      });

      // Crear notificación para el conductor
      await _createDriverNotification(
        driverId,
        'document_rejected',
        'Tu documento ${documentType.displayName} ha sido rechazado',
        {
          'documentType': documentType.value,
          'reason': rejectionReason,
        },
      );

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error al rechazar documento: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Verificar y actualizar estado de verificación del conductor
  Future<void> _checkAndUpdateDriverVerificationStatus(String driverId) async {
    try {
      // Obtener todos los documentos del conductor
      final documentsSnapshot = await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('documents')
          .get();

      final documents = documentsSnapshot.docs.map((doc) {
        return DocumentModel.fromFirestore(doc.data(), doc.id);
      }).toList();

      // Verificar si todos los documentos requeridos están aprobados
      final requiredTypes =
          DocumentType.values.where((type) => type.isRequired);
      final allRequiredApproved = requiredTypes.every((type) {
        final document = documents.firstWhere(
          (doc) => doc.type == type,
          orElse: () => DocumentModel(
            id: type.value,
            type: type,
            status: DocumentStatus.pending,
          ),
        );
        return document.status == DocumentStatus.approved;
      });

      if (allRequiredApproved) {
        // Aprobar conductor
        await _firestore.collection('drivers').doc(driverId).update({
          'verificationStatus': 'approved',
          'isVerified': true,
          'verificationDate': FieldValue.serverTimestamp(),
          'rejectionReason': null,
        });

        // Crear notificación de aprobación completa
        await _createDriverNotification(
          driverId,
          'verification_approved',
          '¡Felicidades! Tu verificación de documentos ha sido aprobada. Ya puedes comenzar a trabajar.',
          {},
        );

        // Remover de la lista local
        _pendingVerifications
            .removeWhere((batch) => batch.driverInfo.id == driverId);
        notifyListeners();
      }
    } catch (e) {
      AppLogger.debug('Error al verificar estado del conductor: $e');
    }
  }

  /// Actualizar documento en la lista local
  void _updateLocalDocument(
      String driverId, DocumentType documentType, DocumentStatus status) {
    final batchIndex = _pendingVerifications.indexWhere(
      (batch) => batch.driverInfo.id == driverId,
    );

    if (batchIndex != -1) {
      final documentIndex =
          _pendingVerifications[batchIndex].documents.indexWhere(
                (doc) => doc.type == documentType,
              );

      if (documentIndex != -1) {
        _pendingVerifications[batchIndex].documents[documentIndex] =
            _pendingVerifications[batchIndex].documents[documentIndex].copyWith(
                  status: status,
                  reviewedAt: DateTime.now(),
                );

        notifyListeners();
      }
    }
  }

  /// Crear notificación para el conductor
  Future<void> _createDriverNotification(
    String driverId,
    String type,
    String message,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': driverId,
        'type': type,
        'title': 'Estado de Documentos',
        'message': message,
        'data': data,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      AppLogger.debug('Error al crear notificación para conductor: $e');
    }
  }

  /// Cargar notificaciones del admin
  Future<void> loadAdminNotifications() async {
    try {
      final snapshot = await _firestore
          .collection('admin_notifications')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      _notifications = snapshot.docs.map((doc) {
        return AdminNotification.fromFirestore(doc.data(), doc.id);
      }).toList();

      notifyListeners();
    } catch (e) {
      AppLogger.debug('Error al cargar notificaciones de admin: $e');
    }
  }

  /// Marcar notificación como leída
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('admin_notifications')
          .doc(notificationId)
          .update({'read': true});

      // Actualizar localmente
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(read: true);
        notifyListeners();
      }
    } catch (e) {
      AppLogger.debug('Error al marcar notificación como leída: $e');
    }
  }

  /// Obtener información del conductor desde caché
  DriverInfo? getDriverInfo(String driverId) {
    return _driversCache[driverId];
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
    _pendingVerifications.clear();
    _notifications.clear();
    _driversCache.clear();
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}

/// Modelo para lote de documentos de un conductor
class DriverDocumentBatch {
  final DriverInfo driverInfo;
  final List<DocumentModel> documents;
  final String verificationStatus;
  final DateTime requestedAt;

  DriverDocumentBatch({
    required this.driverInfo,
    required this.documents,
    required this.verificationStatus,
    required this.requestedAt,
  });

  int get pendingDocumentsCount => documents
      .where((doc) =>
          doc.status == DocumentStatus.underReview ||
          doc.status == DocumentStatus.pending)
      .length;

  bool get hasUrgentDocuments =>
      documents.any((doc) => doc.isExpired || doc.isExpiringSoon);
}

/// Modelo de información del conductor para admin
class DriverInfo {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? photoUrl;
  final double rating;
  final int totalTrips;
  final DateTime? joinDate;
  final VehicleInfo? vehicleInfo;

  DriverInfo({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.photoUrl,
    required this.rating,
    required this.totalTrips,
    this.joinDate,
    this.vehicleInfo,
  });
}

/// Modelo de información del vehículo
class VehicleInfo {
  final String brand;
  final String model;
  final int year;
  final String plate;
  final String color;
  final String type;

  VehicleInfo({
    required this.brand,
    required this.model,
    required this.year,
    required this.plate,
    required this.color,
    required this.type,
  });

  factory VehicleInfo.fromMap(Map<String, dynamic> map) {
    return VehicleInfo(
      brand: map['brand'] ?? '',
      model: map['model'] ?? '',
      year: map['year'] ?? 0,
      plate: map['plate'] ?? '',
      color: map['color'] ?? '',
      type: map['type'] ?? 'standard',
    );
  }

  String get displayName => '$year $brand $model';
}

/// Modelo de notificación para admin
class AdminNotification {
  final String id;
  final String type;
  final String driverId;
  final String? documentType;
  final DateTime createdAt;
  final bool read;
  final String priority;

  AdminNotification({
    required this.id,
    required this.type,
    required this.driverId,
    this.documentType,
    required this.createdAt,
    required this.read,
    required this.priority,
  });

  factory AdminNotification.fromFirestore(
      Map<String, dynamic> data, String id) {
    return AdminNotification(
      id: id,
      type: data['type'] ?? '',
      driverId: data['driverId'] ?? '',
      documentType: data['documentType'],
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      read: data['read'] ?? false,
      priority: data['priority'] ?? 'normal',
    );
  }

  AdminNotification copyWith({
    String? id,
    String? type,
    String? driverId,
    String? documentType,
    DateTime? createdAt,
    bool? read,
    String? priority,
  }) {
    return AdminNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      driverId: driverId ?? this.driverId,
      documentType: documentType ?? this.documentType,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
      priority: priority ?? this.priority,
    );
  }

  String get displayMessage {
    switch (type) {
      case 'document_uploaded':
        final docType = DocumentType.values.firstWhere(
          (type) => type.value == documentType,
          orElse: () => DocumentType.license,
        );
        return 'Nuevo documento subido: ${docType.displayName}';
      case 'verification_request':
        return 'Solicitud de verificación de documentos';
      default:
        return 'Nueva notificación';
    }
  }
}
