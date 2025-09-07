import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';

class AdminProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseService().firestore;

  // Estados de carga
  bool _isLoading = false;
  String? _error;

  // Datos de administración
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _drivers = [];
  Map<String, dynamic>? _statistics;
  Map<String, dynamic>? _financialData;
  List<Map<String, dynamic>> _transactions = [];
  Map<String, dynamic>? _settings;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get users => _users;
  List<Map<String, dynamic>> get drivers => _drivers;
  Map<String, dynamic>? get statistics => _statistics;
  Map<String, dynamic>? get financialData => _financialData;
  List<Map<String, dynamic>> get transactions => _transactions;
  Map<String, dynamic>? get settings => _settings;

  // Cargar usuarios
  Future<void> loadUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestore.collection('users').get();
      _users = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      _error = 'Error al cargar usuarios: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Cargar conductores
  Future<void> loadDrivers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .get();
      
      _drivers = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      _error = 'Error al cargar conductores: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Cargar estadísticas
  Future<void> loadStatistics() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Cargar estadísticas generales
      final usersSnapshot = await _firestore.collection('users').get();
      final tripsSnapshot = await _firestore.collection('trips').get();
      
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      
      final monthlyTrips = await _firestore
          .collection('trips')
          .where('createdAt', isGreaterThanOrEqualTo: startOfMonth)
          .get();

      _statistics = {
        'totalUsers': usersSnapshot.docs.where((doc) => 
            doc.data()['role'] == 'passenger').length,
        'totalDrivers': usersSnapshot.docs.where((doc) => 
            doc.data()['role'] == 'driver').length,
        'activeDrivers': usersSnapshot.docs.where((doc) => 
            doc.data()['role'] == 'driver' && 
            doc.data()['isOnline'] == true).length,
        'totalTrips': tripsSnapshot.docs.length,
        'monthlyTrips': monthlyTrips.docs.length,
        'completedTrips': tripsSnapshot.docs.where((doc) => 
            doc.data()['status'] == 'completed').length,
      };
    } catch (e) {
      _error = 'Error al cargar estadísticas: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Cargar datos financieros
  Future<void> loadFinancialData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final tripsSnapshot = await _firestore
          .collection('trips')
          .where('status', isEqualTo: 'completed')
          .get();

      double totalRevenue = 0;
      double totalCommission = 0;
      double totalDriverEarnings = 0;

      for (var doc in tripsSnapshot.docs) {
        final data = doc.data();
        final fare = (data['fare'] ?? 0).toDouble();
        final commission = fare * 0.20; // 20% de comisión
        
        totalRevenue += fare;
        totalCommission += commission;
        totalDriverEarnings += (fare - commission);
      }

      _financialData = {
        'totalRevenue': totalRevenue,
        'totalCommission': totalCommission,
        'totalDriverEarnings': totalDriverEarnings,
        'averageTripValue': tripsSnapshot.docs.isNotEmpty 
            ? totalRevenue / tripsSnapshot.docs.length 
            : 0,
      };
    } catch (e) {
      _error = 'Error al cargar datos financieros: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Cargar transacciones
  Future<void> loadTransactions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('transactions')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      _transactions = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      _error = 'Error al cargar transacciones: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Verificar conductor
  Future<bool> verifyDriver(String driverId) async {
    try {
      await _firestore.collection('users').doc(driverId).update({
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
      });
      
      await loadDrivers();
      return true;
    } catch (e) {
      _error = 'Error al verificar conductor: $e';
      notifyListeners();
      return false;
    }
  }

  // Suspender usuario
  Future<bool> suspendUser(String userId, String reason) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isSuspended': true,
        'suspendedAt': FieldValue.serverTimestamp(),
        'suspensionReason': reason,
      });
      
      await loadUsers();
      return true;
    } catch (e) {
      _error = 'Error al suspender usuario: $e';
      notifyListeners();
      return false;
    }
  }

  // Reactivar usuario
  Future<bool> reactivateUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isSuspended': false,
        'suspendedAt': null,
        'suspensionReason': null,
      });
      
      await loadUsers();
      return true;
    } catch (e) {
      _error = 'Error al reactivar usuario: $e';
      notifyListeners();
      return false;
    }
  }

  // Actualizar estado del conductor
  Future<bool> updateDriverStatus(String driverId, String status) async {
    try {
      await _firestore.collection('users').doc(driverId).update({
        'isActive': status == 'active',
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      await loadDrivers();
      return true;
    } catch (e) {
      _error = 'Error al actualizar estado del conductor: $e';
      notifyListeners();
      return false;
    }
  }

  // Eliminar conductor
  Future<bool> deleteDriver(String driverId) async {
    try {
      await _firestore.collection('users').doc(driverId).delete();
      await loadDrivers();
      return true;
    } catch (e) {
      _error = 'Error al eliminar conductor: $e';
      notifyListeners();
      return false;
    }
  }

  // Actualizar estado del usuario
  Future<bool> updateUserStatus(String userId, bool isActive) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      await loadUsers();
      return true;
    } catch (e) {
      _error = 'Error al actualizar estado del usuario: $e';
      notifyListeners();
      return false;
    }
  }

  // Eliminar usuario
  Future<bool> deleteUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
      await loadUsers();
      return true;
    } catch (e) {
      _error = 'Error al eliminar usuario: $e';
      notifyListeners();
      return false;
    }
  }

  // Actualizar configuración
  Future<bool> updateSettings(Map<String, dynamic> settings) async {
    try {
      await _firestore
          .collection('settings')
          .doc('admin')
          .set(settings, SetOptions(merge: true));
      
      _settings = settings;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al actualizar configuración: $e';
      notifyListeners();
      return false;
    }
  }

  // Cargar configuración
  Future<void> loadSettings() async {
    try {
      final doc = await _firestore
          .collection('settings')
          .doc('admin')
          .get();
      
      if (doc.exists) {
        _settings = doc.data();
      } else {
        // Configuración por defecto
        _settings = {
          'commissionRate': 0.20,
          'minFare': 5.0,
          'maxRadius': 10000,
          'surgeMultiplier': 1.0,
          'maintenanceMode': false,
        };
      }
      notifyListeners();
    } catch (e) {
      _error = 'Error al cargar configuración: $e';
      notifyListeners();
    }
  }

  // Buscar usuarios
  void searchUsers(String query) {
    if (query.isEmpty) {
      loadUsers();
      return;
    }

    final lowerQuery = query.toLowerCase();
    _users = _users.where((user) {
      final name = (user['name'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      final phone = (user['phone'] ?? '').toString().toLowerCase();
      
      return name.contains(lowerQuery) ||
             email.contains(lowerQuery) ||
             phone.contains(lowerQuery);
    }).toList();
    
    notifyListeners();
  }

  // Buscar conductores
  void searchDrivers(String query) {
    if (query.isEmpty) {
      loadDrivers();
      return;
    }

    final lowerQuery = query.toLowerCase();
    _drivers = _drivers.where((driver) {
      final name = (driver['name'] ?? '').toString().toLowerCase();
      final email = (driver['email'] ?? '').toString().toLowerCase();
      final phone = (driver['phone'] ?? '').toString().toLowerCase();
      final vehicle = (driver['vehiclePlate'] ?? '').toString().toLowerCase();
      
      return name.contains(lowerQuery) ||
             email.contains(lowerQuery) ||
             phone.contains(lowerQuery) ||
             vehicle.contains(lowerQuery);
    }).toList();
    
    notifyListeners();
  }

  // Limpiar error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}