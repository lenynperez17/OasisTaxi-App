import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_logger.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../services/location_service.dart';
import '../providers/emergency_provider.dart' show EmergencyContact;

/// Modelo para historial de emergencias
class EmergencyHistory {
  final String id;
  final String userId;
  final String type;
  final String status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? description;
  final Map<String, dynamic>? location;
  final List<String> notifiedContacts;
  final String? resolution;
  final Map<String, dynamic>? metadata;

  EmergencyHistory({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
    this.description,
    this.location,
    required this.notifiedContacts,
    this.resolution,
    this.metadata,
  });

  factory EmergencyHistory.fromMap(Map<String, dynamic> map, String id) {
    return EmergencyHistory(
      id: id,
      userId: map['userId'] ?? '',
      type: map['type'] ?? 'general',
      status: map['status'] ?? 'resolved',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
      description: map['description'],
      location: map['location'] as Map<String, dynamic>?,
      notifiedContacts: List<String>.from(map['notifiedContacts'] ?? []),
      resolution: map['resolution'],
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'description': description,
      'location': location,
      'notifiedContacts': notifiedContacts,
      'resolution': resolution,
      'metadata': metadata,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Tipo de emergencia (reexportado para evitar conflictos)
class EmergencyType {
  final String id;
  final String name;
  final String icon;
  final Color color;
  final String phoneNumber;
  final int priority;

  const EmergencyType({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.phoneNumber,
    required this.priority,
  });
}

/// Servicio de Emergencias Completo
class EmergencyService {
  static EmergencyService? _instance;
  factory EmergencyService() => _instance ??= EmergencyService._internal();
  EmergencyService._internal();

  final FirebaseFirestore _firestore = FirebaseService().firestore;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  final LocationService _locationService = LocationService();

  // Estado de emergencia
  bool _isEmergencyActive = false;
  String? _activeEmergencyId;
  Timer? _autoNotifyTimer;
  StreamSubscription? _locationStream;

  // Configuración
  static const int _autoNotifyDelaySeconds = 30;
  static const int _locationUpdateIntervalSeconds = 10;

  /// Getter para verificar si hay emergencia activa
  bool get isEmergencyActive => _isEmergencyActive;
  String? get activeEmergencyId => _activeEmergencyId;

  /// Inicializar servicio
  Future<void> initialize() async {
    try {
      AppLogger.info('EmergencyService: Inicializando servicio de emergencias');

      // Verificar si hay emergencia activa para el usuario
      await _checkActiveEmergency();

      // Configurar listeners
      _setupEmergencyListeners();

      AppLogger.info('EmergencyService: Servicio inicializado correctamente');
    } catch (e) {
      AppLogger.error('EmergencyService: Error al inicializar', e);
    }
  }

  /// Verificar emergencia activa
  Future<void> _checkActiveEmergency() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final QuerySnapshot activeEmergencies = await _firestore
          .collection('emergencies')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (activeEmergencies.docs.isNotEmpty) {
        _isEmergencyActive = true;
        _activeEmergencyId = activeEmergencies.docs.first.id;
        AppLogger.warning('EmergencyService: Emergencia activa detectada',
            {'emergencyId': _activeEmergencyId});
      }
    } catch (e) {
      AppLogger.error(
          'EmergencyService: Error verificando emergencia activa', e);
    }
  }

  /// Configurar listeners
  void _setupEmergencyListeners() {
    final user = _auth.currentUser;
    if (user == null) return;

    _firestore
        .collection('emergencies')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snapshot) {
      _isEmergencyActive = snapshot.docs.isNotEmpty;
      if (_isEmergencyActive && snapshot.docs.isNotEmpty) {
        _activeEmergencyId = snapshot.docs.first.id;
      } else {
        _activeEmergencyId = null;
      }
    });
  }

  /// Obtener tipos de emergencia disponibles
  static List<EmergencyType> getEmergencyTypes() {
    return [
      EmergencyType(
        id: 'general',
        name: 'Emergencia General',
        icon: '🚨',
        color: Colors.red,
        phoneNumber: '911',
        priority: 1,
      ),
      EmergencyType(
        id: 'medical',
        name: 'Emergencia Médica',
        icon: '🏥',
        color: Colors.blue,
        phoneNumber: '106',
        priority: 1,
      ),
      EmergencyType(
        id: 'security',
        name: 'Seguridad/Robo',
        icon: '👮',
        color: Colors.indigo,
        phoneNumber: '105',
        priority: 1,
      ),
      EmergencyType(
        id: 'accident',
        name: 'Accidente Vehicular',
        icon: '🚗',
        color: Colors.orange,
        phoneNumber: '117',
        priority: 2,
      ),
      EmergencyType(
        id: 'harassment',
        name: 'Acoso/Violencia',
        icon: '🆘',
        color: Colors.purple,
        phoneNumber: '100',
        priority: 1,
      ),
      EmergencyType(
        id: 'breakdown',
        name: 'Avería del Vehículo',
        icon: '🔧',
        color: Colors.grey,
        phoneNumber: '116',
        priority: 3,
      ),
    ];
  }

  /// Obtener contactos de emergencia del usuario
  Future<List<EmergencyContact>> getEmergencyContacts(String userId) async {
    try {
      AppLogger.info('EmergencyService: Obteniendo contactos de emergencia',
          {'userId': userId});

      final QuerySnapshot contactsQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergency_contacts')
          .orderBy('isPrimary', descending: true)
          .get();

      final contacts = contactsQuery.docs
          .map((doc) => EmergencyContact.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .toList();

      AppLogger.info(
          'EmergencyService: ${contacts.length} contactos encontrados');
      return contacts;
    } catch (e) {
      AppLogger.error('EmergencyService: Error obteniendo contactos', e);
      return [];
    }
  }

  /// Obtener historial de emergencias del usuario
  Future<List<EmergencyHistory>> getUserEmergencyHistory(String userId) async {
    try {
      AppLogger.info('EmergencyService: Obteniendo historial de emergencias');

      final QuerySnapshot historyQuery = await _firestore
          .collection('emergencies')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      final history = historyQuery.docs
          .map((doc) => EmergencyHistory.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .toList();

      AppLogger.info(
          'EmergencyService: ${history.length} emergencias en historial');
      return history;
    } catch (e) {
      AppLogger.error('EmergencyService: Error obteniendo historial', e);
      return [];
    }
  }

  /// Activar SOS de emergencia
  Future<Map<String, dynamic>> triggerSOS({
    required String userId,
    required String userType,
    required EmergencyType emergencyType,
    String? rideId,
    String? description,
    List<String>? contactIds,
    bool autoNotify = true,
  }) async {
    try {
      AppLogger.critical('EmergencyService: ACTIVANDO SOS DE EMERGENCIA', {
        'userId': userId,
        'type': emergencyType.id,
        'rideId': rideId,
      });

      // Obtener ubicación actual
      Position? currentPosition;
      try {
        currentPosition = await _locationService.getCurrentLocation();
      } catch (e) {
        AppLogger.warning('EmergencyService: No se pudo obtener ubicación', e);
      }

      // Crear documento de emergencia
      final emergencyData = {
        'userId': userId,
        'userType': userType,
        'type': emergencyType.id,
        'status': 'active',
        'rideId': rideId,
        'description': description,
        'location': currentPosition != null
            ? {
                'lat': currentPosition.latitude,
                'lng': currentPosition.longitude,
                'accuracy': currentPosition.accuracy,
                'timestamp': DateTime.now().toIso8601String(),
              }
            : null,
        'notifiedContacts': [],
        'autoNotify': autoNotify,
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': {
          'deviceInfo': await _getDeviceInfo(),
          'emergencyPhone': emergencyType.phoneNumber,
          'priority': emergencyType.priority,
        },
      };

      final DocumentReference emergencyRef =
          await _firestore.collection('emergencies').add(emergencyData);

      _isEmergencyActive = true;
      _activeEmergencyId = emergencyRef.id;

      // Iniciar tracking de ubicación
      await _startLocationTracking(emergencyRef.id);

      // Notificar contactos de emergencia
      if (contactIds != null && contactIds.isNotEmpty) {
        await _notifyEmergencyContacts(
          emergencyId: emergencyRef.id,
          userId: userId,
          contactIds: contactIds,
          emergencyType: emergencyType,
        );
      }

      // Configurar auto-notificación si está habilitada
      if (autoNotify) {
        _setupAutoNotification(emergencyRef.id, userId);
      }

      // Llamar al número de emergencia
      await _callEmergencyNumber(emergencyType.phoneNumber);

      // Enviar notificación push a administradores
      await _notifyAdmins(emergencyRef.id, userId, emergencyType);

      AppLogger.critical('EmergencyService: SOS ACTIVADO EXITOSAMENTE',
          {'emergencyId': emergencyRef.id});

      return {
        'success': true,
        'emergencyId': emergencyRef.id,
        'message': 'Emergencia activada. Ayuda en camino.',
      };
    } catch (e) {
      AppLogger.error('EmergencyService: Error activando SOS', e);
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Error al activar emergencia',
      };
    }
  }

  /// Cancelar emergencia activa
  Future<bool> cancelEmergency(String reason, {String? resolution}) async {
    try {
      if (!_isEmergencyActive || _activeEmergencyId == null) {
        AppLogger.warning(
            'EmergencyService: No hay emergencia activa para cancelar');
        return false;
      }

      AppLogger.info('EmergencyService: Cancelando emergencia', {
        'emergencyId': _activeEmergencyId,
        'reason': reason,
      });

      // Actualizar estado de emergencia
      await _firestore
          .collection('emergencies')
          .doc(_activeEmergencyId)
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelReason': reason,
        'resolution': resolution,
      });

      // Detener tracking de ubicación
      _stopLocationTracking();

      // Cancelar auto-notificación
      _autoNotifyTimer?.cancel();

      // Notificar a contactos que la emergencia fue cancelada
      await _notifyCancellation(_activeEmergencyId!);

      _isEmergencyActive = false;
      _activeEmergencyId = null;

      AppLogger.info('EmergencyService: Emergencia cancelada exitosamente');
      return true;
    } catch (e) {
      AppLogger.error('EmergencyService: Error cancelando emergencia', e);
      return false;
    }
  }

  /// Iniciar tracking de ubicación
  Future<void> _startLocationTracking(String emergencyId) async {
    try {
      AppLogger.info('EmergencyService: Iniciando tracking de ubicación');

      _locationStream = Stream.periodic(
        Duration(seconds: _locationUpdateIntervalSeconds),
      ).asyncMap((_) async {
        try {
          final position = await _locationService.getCurrentLocation();

          // Actualizar ubicación en Firestore
          await _firestore
              .collection('emergencies')
              .doc(emergencyId)
              .collection('location_updates')
              .add({
            'lat': position?.latitude ?? 0.0,
            'lng': position?.longitude ?? 0.0,
            'accuracy': position?.accuracy ?? 0.0,
            'speed': position?.speed ?? 0.0,
            'heading': position?.heading ?? 0.0,
            'timestamp': FieldValue.serverTimestamp(),
          });

          // Actualizar ubicación principal
          await _firestore.collection('emergencies').doc(emergencyId).update({
            'lastLocation': {
              'lat': position?.latitude ?? 0.0,
              'lng': position?.longitude ?? 0.0,
              'timestamp': DateTime.now().toIso8601String(),
            },
          });
        } catch (e) {
          AppLogger.error('EmergencyService: Error actualizando ubicación', e);
        }
      }).listen((_) {});
    } catch (e) {
      AppLogger.error('EmergencyService: Error iniciando tracking', e);
    }
  }

  /// Detener tracking de ubicación
  void _stopLocationTracking() {
    _locationStream?.cancel();
    _locationStream = null;
    AppLogger.info('EmergencyService: Tracking de ubicación detenido');
  }

  /// Notificar contactos de emergencia
  Future<void> _notifyEmergencyContacts({
    required String emergencyId,
    required String userId,
    required List<String> contactIds,
    required EmergencyType emergencyType,
  }) async {
    try {
      AppLogger.info('EmergencyService: Notificando contactos de emergencia');

      for (String contactId in contactIds) {
        try {
          // Obtener información del contacto
          final contactDoc = await _firestore
              .collection('users')
              .doc(userId)
              .collection('emergency_contacts')
              .doc(contactId)
              .get();

          if (!contactDoc.exists) continue;

          final contactData = contactDoc.data()!;
          final phoneNumber = contactData['phone'];

          // Enviar SMS
          await _sendEmergencySMS(phoneNumber, emergencyType);

          // Registrar notificación
          await _firestore.collection('emergencies').doc(emergencyId).update({
            'notifiedContacts': FieldValue.arrayUnion([contactId]),
          });

          AppLogger.info('EmergencyService: Contacto notificado', {
            'contactId': contactId,
            'phone': phoneNumber,
          });
        } catch (e) {
          AppLogger.error(
              'EmergencyService: Error notificando contacto $contactId', e);
        }
      }
    } catch (e) {
      AppLogger.error('EmergencyService: Error notificando contactos', e);
    }
  }

  /// Enviar SMS de emergencia
  Future<void> _sendEmergencySMS(String phoneNumber, EmergencyType type) async {
    try {
      final message = Uri.encodeComponent('🚨 EMERGENCIA OASIS TAXI 🚨\n'
          'Tipo: ${type.name}\n'
          'Tu contacto de emergencia ha activado el botón SOS.\n'
          'Por favor, contacta inmediatamente.\n'
          'Ubicación: https://maps.google.com/?q=ubicacion');

      final smsUrl = 'sms:$phoneNumber?body=$message';

      if (await canLaunchUrl(Uri.parse(smsUrl))) {
        await launchUrl(Uri.parse(smsUrl));
      }
    } catch (e) {
      AppLogger.error('EmergencyService: Error enviando SMS', e);
    }
  }

  /// Llamar número de emergencia
  Future<void> _callEmergencyNumber(String number) async {
    try {
      AppLogger.critical('EmergencyService: Llamando a emergencias: $number');

      final telUrl = 'tel:$number';

      if (await canLaunchUrl(Uri.parse(telUrl))) {
        await launchUrl(Uri.parse(telUrl));
      }
    } catch (e) {
      AppLogger.error('EmergencyService: Error llamando emergencias', e);
    }
  }

  /// Configurar auto-notificación
  void _setupAutoNotification(String emergencyId, String userId) {
    _autoNotifyTimer = Timer(
      Duration(seconds: _autoNotifyDelaySeconds),
      () async {
        AppLogger.warning('EmergencyService: Auto-notificación activada');

        // Notificar a todos los contactos automáticamente
        final contacts = await getEmergencyContacts(userId);
        final autoNotifyContacts = contacts
            .where((c) => c.notifyAutomatically)
            .map((c) => c.id)
            .toList();

        if (autoNotifyContacts.isNotEmpty) {
          await _notifyEmergencyContacts(
            emergencyId: emergencyId,
            userId: userId,
            contactIds: autoNotifyContacts,
            emergencyType: getEmergencyTypes().first,
          );
        }
      },
    );
  }

  /// Notificar a administradores
  Future<void> _notifyAdmins(
    String emergencyId,
    String userId,
    EmergencyType type,
  ) async {
    try {
      AppLogger.info('EmergencyService: Notificando administradores');

      // Obtener tokens de administradores
      final QuerySnapshot adminsQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .where('fcmToken', isNotEqualTo: null)
          .get();

      for (var adminDoc in adminsQuery.docs) {
        final adminData = adminDoc.data() as Map<String, dynamic>;
        final fcmToken = adminData['fcmToken'] as String?;
        if (fcmToken != null) {
          await _notificationService.showNotification(
            title: '🚨 EMERGENCIA ACTIVADA',
            body: 'Usuario $userId ha activado emergencia tipo: ${type.name}',
            payload: json.encode({
              'type': 'emergency',
              'emergencyId': emergencyId,
              'userId': userId,
            }),
          );
        }
      }
    } catch (e) {
      AppLogger.error('EmergencyService: Error notificando admins', e);
    }
  }

  /// Notificar cancelación
  Future<void> _notifyCancellation(String emergencyId) async {
    try {
      AppLogger.info('EmergencyService: Notificando cancelación de emergencia');

      // Obtener información de la emergencia
      final emergencyDoc =
          await _firestore.collection('emergencies').doc(emergencyId).get();

      if (!emergencyDoc.exists) return;

      final emergencyData = emergencyDoc.data()!;
      final notifiedContacts =
          List<String>.from(emergencyData['notifiedContacts'] ?? []);

      // Notificar a cada contacto
      for (String contactId in notifiedContacts) {
        AppLogger.info(
            'EmergencyService: Notificando cancelación a contacto $contactId');
        // Aquí se enviaría notificación de cancelación
      }
    } catch (e) {
      AppLogger.error('EmergencyService: Error notificando cancelación', e);
    }
  }

  /// Obtener información del dispositivo
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      return {
        'platform': 'mobile',
        'timestamp': DateTime.now().toIso8601String(),
        'appVersion': '1.0.0',
      };
    } catch (e) {
      AppLogger.error(
          'EmergencyService: Error obteniendo info del dispositivo', e);
      return {};
    }
  }

  /// Resolver emergencia
  Future<bool> resolveEmergency(String emergencyId, String resolution) async {
    try {
      AppLogger.info('EmergencyService: Resolviendo emergencia', {
        'emergencyId': emergencyId,
        'resolution': resolution,
      });

      await _firestore.collection('emergencies').doc(emergencyId).update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolution': resolution,
      });

      if (_activeEmergencyId == emergencyId) {
        _isEmergencyActive = false;
        _activeEmergencyId = null;
        _stopLocationTracking();
        _autoNotifyTimer?.cancel();
      }

      AppLogger.info('EmergencyService: Emergencia resuelta exitosamente');
      return true;
    } catch (e) {
      AppLogger.error('EmergencyService: Error resolviendo emergencia', e);
      return false;
    }
  }

  /// Limpiar recursos
  void dispose() {
    _stopLocationTracking();
    _autoNotifyTimer?.cancel();
  }
}
