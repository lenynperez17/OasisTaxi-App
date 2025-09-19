import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_logger.dart';
import '../services/firebase_service.dart';
import '../services/emergency_service.dart'
    show EmergencyType, EmergencyService;

// Modelo para contacto de emergencia
class EmergencyContact {
  final String id;
  final String userId;
  final String name;
  final String phone;
  final String? relationship;
  final bool isPrimary;
  final bool notifyAutomatically;

  EmergencyContact({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    this.relationship,
    required this.isPrimary,
    required this.notifyAutomatically,
  });

  factory EmergencyContact.fromMap(Map<String, dynamic> map, String id) {
    return EmergencyContact(
      id: id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      relationship: map['relationship'],
      isPrimary: map['isPrimary'] ?? false,
      notifyAutomatically: map['notifyAutomatically'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'isPrimary': isPrimary,
      'notifyAutomatically': notifyAutomatically,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

// Modelo para alerta de emergencia
class EmergencyAlert {
  final String id;
  final String userId;
  final String userName;
  final String? tripId;
  final EmergencyType type;
  final String status; // 'active', 'resolved', 'cancelled'
  final GeoPoint location;
  final String? address;
  final String? description;
  final List<String> notifiedContacts;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final Map<String, dynamic>? metadata;

  EmergencyAlert({
    required this.id,
    required this.userId,
    required this.userName,
    this.tripId,
    required this.type,
    required this.status,
    required this.location,
    this.address,
    this.description,
    required this.notifiedContacts,
    required this.createdAt,
    this.resolvedAt,
    this.metadata,
  });

  factory EmergencyAlert.fromMap(Map<String, dynamic> map, String id) {
    return EmergencyAlert(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      tripId: map['tripId'],
      type: EmergencyProvider._getEmergencyTypeFromString(
          map['type'] ?? 'general'),
      status: map['status'] ?? 'active',
      location: map['location'] ?? const GeoPoint(0, 0),
      address: map['address'],
      description: map['description'],
      notifiedContacts: List<String>.from(map['notifiedContacts'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
      metadata: map['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'tripId': tripId,
      'type': type.id,
      'status': status,
      'location': location,
      'address': address,
      'description': description,
      'notifiedContacts': notifiedContacts,
      'createdAt': Timestamp.fromDate(createdAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'metadata': metadata,
    };
  }
}

// EmergencyType ahora se importa de emergency_service.dart
// Eliminado enum para evitar conflictos

class EmergencyProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseService().firestore;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Estado
  List<EmergencyContact> _contacts = [];
  EmergencyAlert? _activeAlert;
  List<EmergencyAlert> _alertHistory = [];
  bool _isLoading = false;
  String? _error;
  bool _sosActive = false;
  Position? _currentLocation;

  // Números de emergencia locales
  final Map<String, String> _emergencyNumbers = {
    'police': '105',
    'medical': '106',
    'fire': '116',
    'serenazgo': '101',
  };

  // Streams
  Stream<QuerySnapshot>? _contactsStream;
  Stream<QuerySnapshot>? _alertsStream;

  // Getters
  List<EmergencyContact> get contacts => _contacts;
  EmergencyAlert? get activeAlert => _activeAlert;
  List<EmergencyAlert> get alertHistory => _alertHistory;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get sosActive => _sosActive;
  Position? get currentLocation => _currentLocation;
  Map<String, String> get emergencyNumbers => _emergencyNumbers;

  EmergencyProvider() {
    _initialize();
  }

  void _initialize() {
    final user = _auth.currentUser;
    if (user != null) {
      // Stream de contactos de emergencia
      _contactsStream = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('emergencyContacts')
          .orderBy('isPrimary', descending: true)
          .snapshots();

      _contactsStream?.listen((snapshot) {
        _contacts = snapshot.docs
            .map((doc) => EmergencyContact.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList();
        notifyListeners();
      });

      // Stream de alertas de emergencia
      _alertsStream = _firestore
          .collection('emergencyAlerts')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots();

      _alertsStream?.listen((snapshot) {
        _alertHistory = snapshot.docs
            .map((doc) => EmergencyAlert.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList();

        // Verificar si hay alerta activa
        _activeAlert = _alertHistory.firstWhere(
          (alert) => alert.status == 'active',
          orElse: () => EmergencyAlert(
            id: '',
            userId: '',
            userName: '',
            type: _getDefaultEmergencyType(),
            status: 'resolved',
            location: const GeoPoint(0, 0),
            notifiedContacts: [],
            createdAt: DateTime.now(),
          ),
        );

        _sosActive = _activeAlert?.status == 'active';
        notifyListeners();
      });
    }
  }

  // Activar SOS de emergencia
  Future<bool> activateSOS({
    required EmergencyType type,
    String? tripId,
    String? description,
    bool notifyContacts = true,
    bool callEmergency = false,
  }) async {
    _setLoading(true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      // Obtener ubicación actual
      await _getCurrentLocation();
      if (_currentLocation == null) {
        throw Exception('No se pudo obtener la ubicación');
      }

      // Obtener información del usuario
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      // Crear alerta de emergencia
      final alert = EmergencyAlert(
        id: '',
        userId: user.uid,
        userName: userData['name'] ?? 'Usuario',
        tripId: tripId,
        type: type,
        status: 'active',
        location:
            GeoPoint(_currentLocation!.latitude, _currentLocation!.longitude),
        address: await _getAddressFromLocation(_currentLocation!),
        description: description,
        notifiedContacts: [],
        createdAt: DateTime.now(),
        metadata: {
          'deviceInfo': {
            'platform': 'mobile',
            'batteryLevel': await _getBatteryLevel(),
          },
          'userInfo': {
            'phone': userData['phone'],
            'email': userData['email'],
          },
        },
      );

      // Guardar alerta
      final docRef =
          await _firestore.collection('emergencyAlerts').add(alert.toMap());

      _activeAlert = EmergencyAlert(
        id: docRef.id,
        userId: alert.userId,
        userName: alert.userName,
        tripId: alert.tripId,
        type: alert.type,
        status: alert.status,
        location: alert.location,
        address: alert.address,
        description: alert.description,
        notifiedContacts: alert.notifiedContacts,
        createdAt: alert.createdAt,
        metadata: alert.metadata,
      );

      _sosActive = true;

      // Notificar contactos de emergencia
      if (notifyContacts) {
        await _notifyEmergencyContacts(docRef.id);
      }

      // Llamar a emergencias si es necesario
      if (callEmergency) {
        await callEmergencyNumber(_getEmergencyNumberByType(type));
      }

      // Enviar ubicación en tiempo real
      _startLocationTracking(docRef.id);

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Error al activar SOS: $e');
      _setLoading(false);
      return false;
    }
  }

  // Desactivar SOS
  Future<bool> deactivateSOS({String? resolution}) async {
    if (_activeAlert == null) return false;

    _setLoading(true);
    try {
      await _firestore
          .collection('emergencyAlerts')
          .doc(_activeAlert!.id)
          .update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolution': resolution,
      });

      _sosActive = false;
      _activeAlert = null;
      _stopLocationTracking();

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Error al desactivar SOS: $e');
      _setLoading(false);
      return false;
    }
  }

  // Agregar contacto de emergencia
  Future<bool> addEmergencyContact({
    required String name,
    required String phone,
    String? relationship,
    bool isPrimary = false,
    bool notifyAutomatically = true,
  }) async {
    _setLoading(true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      // Si es primario, desmarcar otros
      if (isPrimary) {
        final batch = _firestore.batch();
        for (var contact in _contacts) {
          if (contact.isPrimary) {
            final ref = _firestore
                .collection('users')
                .doc(user.uid)
                .collection('emergencyContacts')
                .doc(contact.id);
            batch.update(ref, {'isPrimary': false});
          }
        }
        await batch.commit();
      }

      final contact = EmergencyContact(
        id: '',
        userId: user.uid,
        name: name,
        phone: phone,
        relationship: relationship,
        isPrimary: isPrimary,
        notifyAutomatically: notifyAutomatically,
      );

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('emergencyContacts')
          .add({
        ...contact.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error al agregar contacto: $e');
      _setLoading(false);
      return false;
    }
  }

  // Eliminar contacto de emergencia
  Future<bool> removeEmergencyContact(String contactId) async {
    _setLoading(true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('emergencyContacts')
          .doc(contactId)
          .delete();

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error al eliminar contacto: $e');
      _setLoading(false);
      return false;
    }
  }

  // Notificar contactos de emergencia
  Future<void> _notifyEmergencyContacts(String alertId) async {
    try {
      final notifiedContacts = <String>[];

      for (var contact in _contacts) {
        if (contact.notifyAutomatically) {
          // Enviar SMS
          await _sendEmergencySMS(contact.phone, alertId);
          notifiedContacts.add(contact.id);
        }
      }

      // Actualizar lista de contactos notificados
      await _firestore.collection('emergencyAlerts').doc(alertId).update({
        'notifiedContacts': notifiedContacts,
        'notificationSentAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.error('Error notificando contactos', e);
    }
  }

  // Enviar SMS de emergencia
  Future<void> _sendEmergencySMS(String phone, String alertId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final message = '''
🚨 EMERGENCIA - Oasis Taxi
Tu contacto necesita ayuda.
Ubicación: https://maps.google.com/?q=${_currentLocation?.latitude},${_currentLocation?.longitude}
Ver detalles: https://oasistaxis.com/emergency/$alertId
''';

      final smsUrl = 'sms:$phone?body=${Uri.encodeComponent(message)}';
      if (await canLaunchUrl(Uri.parse(smsUrl))) {
        await launchUrl(Uri.parse(smsUrl));
      }
    } catch (e) {
      AppLogger.error('Error enviando SMS', e);
    }
  }

  // Llamar número de emergencia
  Future<void> callEmergencyNumber(String number) async {
    try {
      final telUrl = 'tel:$number';
      if (await canLaunchUrl(Uri.parse(telUrl))) {
        await launchUrl(Uri.parse(telUrl));
      }
    } catch (e) {
      AppLogger.error('Error llamando emergencia', e);
    }
  }

  // Obtener ubicación actual
  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      _currentLocation = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 100,
        ),
      );
    } catch (e) {
      AppLogger.error('Error obteniendo ubicación', e);
    }
  }

  // Obtener dirección desde ubicación
  Future<String?> _getAddressFromLocation(Position position) async {
    try {
      // Aquí integrarías con un servicio de geocoding
      return '${position.latitude}, ${position.longitude}';
    } catch (e) {
      return null;
    }
  }

  // Obtener nivel de batería
  Future<int> _getBatteryLevel() async {
    try {
      // Aquí obtendrías el nivel de batería real
      return 100;
    } catch (e) {
      return 0;
    }
  }

  // Obtener número de emergencia por tipo
  String _getEmergencyNumberByType(EmergencyType type) {
    // Usar el número definido en el tipo, o fallback a números locales
    return type.phoneNumber;
  }

  // Obtener EmergencyType desde string
  static EmergencyType _getEmergencyTypeFromString(String typeId) {
    final availableTypes = EmergencyService.getEmergencyTypes();
    return availableTypes.firstWhere(
      (type) => type.id == typeId,
      orElse: () => availableTypes.first,
    );
  }

  // Obtener tipo de emergencia por defecto
  static EmergencyType _getDefaultEmergencyType() {
    return EmergencyService.getEmergencyTypes().first;
  }

  // Iniciar tracking de ubicación
  void _startLocationTracking(String alertId) {
    // Actualizar ubicación cada 30 segundos
    Stream.periodic(const Duration(seconds: 30)).listen((_) async {
      if (!_sosActive) return;

      await _getCurrentLocation();
      if (_currentLocation != null) {
        await _firestore.collection('emergencyAlerts').doc(alertId).update({
          'location':
              GeoPoint(_currentLocation!.latitude, _currentLocation!.longitude),
          'locationUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // Detener tracking de ubicación
  void _stopLocationTracking() {
    // Cancelar stream de ubicación
  }

  // Enviar mensaje rápido de emergencia
  Future<bool> sendQuickEmergencyMessage(String template) async {
    final templates = {
      'help': 'Necesito ayuda urgente',
      'unsafe': 'Me siento inseguro/a',
      'accident': 'He tenido un accidente',
      'medical': 'Necesito asistencia médica',
      'breakdown': 'El vehículo se ha averiado',
    };

    final message = templates[template] ?? template;
    return await activateSOS(
      type: _getDefaultEmergencyType(),
      description: message,
    );
  }

  // Compartir ubicación en tiempo real
  Future<String> shareRealtimeLocation() async {
    try {
      await _getCurrentLocation();
      if (_currentLocation == null) return '';

      final user = _auth.currentUser;
      if (user == null) return '';

      // Crear enlace de compartir ubicación
      final shareDoc = await _firestore.collection('sharedLocations').add({
        'userId': user.uid,
        'location':
            GeoPoint(_currentLocation!.latitude, _currentLocation!.longitude),
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt':
            Timestamp.fromDate(DateTime.now().add(const Duration(hours: 2))),
      });

      return 'https://oasistaxis.com/track/${shareDoc.id}';
    } catch (e) {
      AppLogger.error('Error compartiendo ubicación', e);
      return '';
    }
  }

  // Helpers
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    if (error != null) {
      AppLogger.info(error);
    }
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopLocationTracking();
    super.dispose();
  }
}
