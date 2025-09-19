import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../utils/app_logger.dart';

/// Servicio de seguridad para transacciones
/// Implementa validación, detección de fraude y auditoría
class TransactionSecurityService {
  static final TransactionSecurityService _instance = TransactionSecurityService._internal();
  factory TransactionSecurityService() => _instance;
  TransactionSecurityService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Límites de seguridad
  static const double _maxWithdrawalAmount = 5000.0; // Monto máximo de retiro
  static const double _maxDailyWithdrawal = 10000.0; // Límite diario
  static const int _maxWithdrawalsPerDay = 5; // Número máximo de retiros por día
  static const double _suspiciousAmountThreshold = 2000.0; // Umbral para revisión
  static const int _velocityCheckMinutes = 5; // Ventana de tiempo para velocity check

  /// Valida una transacción antes de procesarla
  Future<ValidationResult> validateTransaction({
    required String userId,
    required String type,
    required double amount,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      AppLogger.info('Validando transacción: $type, monto: $amount');

      // Validaciones básicas
      if (amount <= 0) {
        return ValidationResult(
          isValid: false,
          error: 'Monto inválido',
          riskLevel: RiskLevel.blocked,
        );
      }

      // Validaciones específicas por tipo
      switch (type) {
        case 'withdrawal':
          return await _validateWithdrawal(userId, amount);
        case 'transfer':
          return await _validateTransfer(userId, amount, metadata);
        case 'trip_payment':
          return await _validateTripPayment(userId, amount, metadata);
        default:
          return ValidationResult(isValid: true, riskLevel: RiskLevel.low);
      }
    } catch (e) {
      AppLogger.error('Error validando transacción', e);
      return ValidationResult(
        isValid: false,
        error: 'Error de validación',
        riskLevel: RiskLevel.high,
      );
    }
  }

  /// Valida un retiro
  Future<ValidationResult> _validateWithdrawal(String userId, double amount) async {
    // Verificar límite de monto
    if (amount > _maxWithdrawalAmount) {
      return ValidationResult(
        isValid: false,
        error: 'Monto excede el límite máximo de retiro',
        riskLevel: RiskLevel.blocked,
      );
    }

    // Verificar límites diarios
    final dailyStats = await _getDailyWithdrawalStats(userId);

    if (dailyStats.totalAmount + amount > _maxDailyWithdrawal) {
      return ValidationResult(
        isValid: false,
        error: 'Excede el límite diario de retiros',
        riskLevel: RiskLevel.blocked,
      );
    }

    if (dailyStats.count >= _maxWithdrawalsPerDay) {
      return ValidationResult(
        isValid: false,
        error: 'Número máximo de retiros diarios alcanzado',
        riskLevel: RiskLevel.blocked,
      );
    }

    // Verificar velocity (muchas transacciones en poco tiempo)
    final recentCount = await _getRecentTransactionCount(userId, _velocityCheckMinutes);
    if (recentCount > 2) {
      return ValidationResult(
        isValid: false,
        error: 'Demasiadas transacciones en poco tiempo',
        riskLevel: RiskLevel.high,
        requiresReview: true,
      );
    }

    // Determinar nivel de riesgo
    RiskLevel riskLevel = RiskLevel.low;
    if (amount > _suspiciousAmountThreshold) {
      riskLevel = RiskLevel.medium;
    }

    return ValidationResult(
      isValid: true,
      riskLevel: riskLevel,
      requiresReview: amount > _suspiciousAmountThreshold,
    );
  }

  /// Valida una transferencia
  Future<ValidationResult> _validateTransfer(
    String userId,
    double amount,
    Map<String, dynamic>? metadata,
  ) async {
    // Support both toUserId and toDriverId
    final toUserId = metadata?['toUserId'] ?? metadata?['toDriverId'];

    if (toUserId == null) {
      return ValidationResult(
        isValid: false,
        error: 'Destinatario no especificado',
        riskLevel: RiskLevel.blocked,
      );
    }

    // Verificar que el destinatario existe
    final toUserDoc = await _firestore.collection('users').doc(toUserId).get();
    if (!toUserDoc.exists) {
      return ValidationResult(
        isValid: false,
        error: 'Destinatario no válido',
        riskLevel: RiskLevel.blocked,
      );
    }

    // Verificar que no es una auto-transferencia
    if (userId == toUserId) {
      return ValidationResult(
        isValid: false,
        error: 'No puede transferir a sí mismo',
        riskLevel: RiskLevel.blocked,
      );
    }

    // Aplicar validaciones similares a retiros
    return await _validateWithdrawal(userId, amount);
  }

  /// Valida un pago de viaje
  Future<ValidationResult> _validateTripPayment(
    String userId,
    double amount,
    Map<String, dynamic>? metadata,
  ) async {
    final tripId = metadata?['tripId'];

    if (tripId == null) {
      return ValidationResult(
        isValid: false,
        error: 'ID de viaje no especificado',
        riskLevel: RiskLevel.high,
      );
    }

    // Verificar que el viaje existe y está completado
    final tripDoc = await _firestore.collection('trips').doc(tripId).get();
    if (!tripDoc.exists) {
      return ValidationResult(
        isValid: false,
        error: 'Viaje no encontrado',
        riskLevel: RiskLevel.blocked,
      );
    }

    final tripData = tripDoc.data()!;
    if (tripData['status'] != 'completed') {
      return ValidationResult(
        isValid: false,
        error: 'El viaje no está completado',
        riskLevel: RiskLevel.high,
      );
    }

    // Verificar que el monto coincide con el precio acordado
    final agreedPrice = (tripData['finalPrice'] ?? tripData['estimatedPrice'] ?? 0.0).toDouble();
    final tolerance = agreedPrice * 0.1; // 10% de tolerancia

    if ((amount - agreedPrice).abs() > tolerance) {
      return ValidationResult(
        isValid: true, // Permitir pero marcar para revisión
        riskLevel: RiskLevel.medium,
        requiresReview: true,
        warning: 'El monto difiere del precio acordado',
      );
    }

    return ValidationResult(isValid: true, riskLevel: RiskLevel.low);
  }

  /// Obtiene estadísticas de retiros diarios
  Future<DailyWithdrawalStats> _getDailyWithdrawalStats(String userId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final snapshot = await _firestore
        .collection('walletTransactions')
        .where('walletId', isEqualTo: userId)
        .where('type', isEqualTo: 'withdrawal')
        .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
        .get();

    double totalAmount = 0.0;
    for (var doc in snapshot.docs) {
      final amount = (doc.data()['amount'] ?? 0.0).toDouble();
      totalAmount += amount.abs(); // Use absolute value for withdrawals
    }

    return DailyWithdrawalStats(
      count: snapshot.docs.length,
      totalAmount: totalAmount,
    );
  }

  /// Obtiene el número de transacciones recientes
  Future<int> _getRecentTransactionCount(String userId, int minutes) async {
    final cutoffTime = DateTime.now().subtract(Duration(minutes: minutes));

    // Don't filter by type for velocity checks - we want to catch all rapid activity
    final snapshot = await _firestore
        .collection('walletTransactions')
        .where('walletId', isEqualTo: userId)
        .where('createdAt', isGreaterThanOrEqualTo: cutoffTime)
        .get();

    return snapshot.docs.length;
  }

  /// Registra una transacción en el log de auditoría
  Future<void> auditTransaction({
    required String transactionId,
    required String userId,
    required String type,
    required double amount,
    required ValidationResult validation,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('audit_logs').add({
        'transactionId': transactionId,
        'userId': userId,
        'type': type,
        'amount': amount,
        'riskLevel': validation.riskLevel.toString(),
        'requiresReview': validation.requiresReview,
        'metadata': metadata,
        'timestamp': FieldValue.serverTimestamp(),
        'hash': _generateTransactionHash(transactionId, userId, amount),
      });

      AppLogger.info('Transacción auditada: $transactionId');
    } catch (e) {
      AppLogger.error('Error auditando transacción', e);
    }
  }

  /// Genera un hash único para la transacción
  String _generateTransactionHash(String transactionId, String userId, double amount) {
    final data = '$transactionId|$userId|$amount|${DateTime.now().toIso8601String()}';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Detecta patrones sospechosos en las transacciones
  Future<FraudDetectionResult> detectFraudPatterns(String userId) async {
    try {
      // Obtener transacciones de los últimos 30 días
      final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
      final snapshot = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .where('createdAt', isGreaterThanOrEqualTo: thirtyDaysAgo)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      if (snapshot.docs.isEmpty) {
        return FraudDetectionResult(
          isSuspicious: false,
          riskScore: 0.0,
          patterns: [],
        );
      }

      final patterns = <String>[];
      double riskScore = 0.0;

      // Patrón 1: Muchos retiros pequeños
      final withdrawals = snapshot.docs.where((doc) => doc.data()['type'] == 'withdrawal');
      if (withdrawals.length > 20) {
        patterns.add('Alto número de retiros');
        riskScore += 20;
      }

      // Patrón 2: Incremento súbito en montos
      final amounts = snapshot.docs.map((doc) => (doc.data()['amount'] ?? 0.0).toDouble()).toList();
      if (amounts.isNotEmpty) {
        final avgAmount = amounts.reduce((a, b) => a + b) / amounts.length;
        final recentAmounts = amounts.take(5);
        final recentAvg = recentAmounts.isEmpty ? 0.0 : recentAmounts.reduce((a, b) => a + b) / recentAmounts.length;

        if (recentAvg > avgAmount * 2) {
          patterns.add('Incremento súbito en montos');
          riskScore += 30;
        }
      }

      // Patrón 3: Horarios inusuales
      int nightTransactions = 0;
      for (var doc in snapshot.docs) {
        final timestamp = (doc.data()['createdAt'] as Timestamp).toDate();
        if (timestamp.hour >= 2 && timestamp.hour <= 5) {
          nightTransactions++;
        }
      }

      if (nightTransactions > 5) {
        patterns.add('Transacciones en horarios inusuales');
        riskScore += 15;
      }

      // Patrón 4: Múltiples dispositivos o ubicaciones
      // (Requeriría tracking de IP/dispositivo, simplificado aquí)
      final locations = <String>{};
      for (var doc in snapshot.docs) {
        final location = doc.data()['metadata']?['location'] as String?;
        if (location != null) locations.add(location);
      }

      if (locations.length > 5) {
        patterns.add('Múltiples ubicaciones detectadas');
        riskScore += 25;
      }

      return FraudDetectionResult(
        isSuspicious: riskScore > 50,
        riskScore: riskScore.clamp(0, 100),
        patterns: patterns,
      );

    } catch (e) {
      AppLogger.error('Error detectando patrones de fraude', e);
      return FraudDetectionResult(
        isSuspicious: false,
        riskScore: 0.0,
        patterns: [],
      );
    }
  }

  /// Bloquea temporalmente a un usuario sospechoso
  Future<void> temporaryBlock(String userId, String reason) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'securityStatus': 'blocked',
        'blockedAt': FieldValue.serverTimestamp(),
        'blockReason': reason,
        'unblockAt': DateTime.now().add(Duration(hours: 24)), // Bloqueo de 24 horas
      });

      AppLogger.warning('Usuario bloqueado temporalmente: $userId - $reason');
    } catch (e) {
      AppLogger.error('Error bloqueando usuario', e);
    }
  }

  /// Verifica si un usuario está bloqueado
  Future<bool> isUserBlocked(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      if (data['securityStatus'] != 'blocked') return false;

      final unblockAt = data['unblockAt'] as Timestamp?;
      if (unblockAt != null && unblockAt.toDate().isBefore(DateTime.now())) {
        // Desbloquear automáticamente
        await _firestore.collection('users').doc(userId).update({
          'securityStatus': 'active',
          'blockedAt': FieldValue.delete(),
          'blockReason': FieldValue.delete(),
          'unblockAt': FieldValue.delete(),
        });
        return false;
      }

      return true;
    } catch (e) {
      AppLogger.error('Error verificando bloqueo de usuario', e);
      return false;
    }
  }
}

/// Resultado de validación
class ValidationResult {
  final bool isValid;
  final String? error;
  final String? warning;
  final RiskLevel riskLevel;
  final bool requiresReview;

  ValidationResult({
    required this.isValid,
    this.error,
    this.warning,
    required this.riskLevel,
    this.requiresReview = false,
  });
}

/// Niveles de riesgo
enum RiskLevel {
  low,
  medium,
  high,
  blocked,
}

/// Estadísticas de retiros diarios
class DailyWithdrawalStats {
  final int count;
  final double totalAmount;

  DailyWithdrawalStats({
    required this.count,
    required this.totalAmount,
  });
}

/// Resultado de detección de fraude
class FraudDetectionResult {
  final bool isSuspicious;
  final double riskScore;
  final List<String> patterns;

  FraudDetectionResult({
    required this.isSuspicious,
    required this.riskScore,
    required this.patterns,
  });
}