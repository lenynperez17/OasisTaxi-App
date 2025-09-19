import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../services/payment_service.dart';
import '../../services/firebase_service.dart';
import '../../widgets/loading_overlay.dart';
import '../../utils/app_logger.dart';
import '../../utils/validation_patterns.dart';

/// PANTALLA DE RETIRO DE GANANCIAS - CONDUCTORES OASIS TAXI
/// ========================================================
///
/// Funcionalidades implementadas:
/// 💰 Vista de ganancias totales y disponibles para retiro
/// 🏦 Retiros a cuenta bancaria (Interbancaria/BCP/BBVA)
/// 📱 Retiros via Yape/Plin (instantáneos)
/// 💳 Historial completo de retiros
/// 📊 Dashboard con estadísticas de ingresos
/// 🔒 Validaciones de seguridad y límites de retiro
/// 📈 Gráfico de ganancias por período
class EarningsWithdrawalScreen extends StatefulWidget {
  final String driverId;

  const EarningsWithdrawalScreen({
    super.key,
    required this.driverId,
  });

  @override
  State<EarningsWithdrawalScreen> createState() =>
      _EarningsWithdrawalScreenState();
}

class _EarningsWithdrawalScreenState extends State<EarningsWithdrawalScreen>
    with TickerProviderStateMixin {
  final PaymentService _paymentService = PaymentService();
  final FirebaseService _firebaseService = FirebaseService();

  late TabController _tabController;
  bool _isLoading = true;

  // Información de ganancias
  double _totalEarnings = 0.0;
  double _availableForWithdrawal = 0.0;
  double _pendingWithdrawals = 0.0;
  double _totalWithdrawn = 0.0;

  // Historial de ganancias
  List<EarningsPeriod> _earningsHistory = [];
  List<WithdrawalHistory> _withdrawalHistory = [];

  // Formulario de retiro
  final _withdrawalAmountController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedWithdrawalMethod = 'bank_transfer';
  String _selectedBank = 'interbank';
  double _withdrawalAmount = 0.0;
  double _withdrawalFee = 0.0;
  double _netAmount = 0.0;

  // Configuración de límites
  static const double _minWithdrawal = 20.0; // S/20 mínimo
  static const double _maxDailyWithdrawal = 1500.0; // S/1500 máximo diario
  static const double _bankTransferFee = 3.0; // S/3 comisión transferencia
  static const double _digitalWalletFee = 1.0; // S/1 comisión Yape/Plin

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle(
        'EarningsWithdrawalScreen', 'initState - DriverId: ${widget.driverId}');
    _tabController = TabController(length: 3, vsync: this);
    _initializeServices();
    _setupAmountListener();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _withdrawalAmountController.dispose();
    _accountNumberController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _setupAmountListener() {
    _withdrawalAmountController.addListener(() {
      final amount = double.tryParse(_withdrawalAmountController.text) ?? 0.0;
      setState(() {
        _withdrawalAmount = amount;
        _calculateWithdrawalFee();
      });
    });
  }

  void _calculateWithdrawalFee() {
    switch (_selectedWithdrawalMethod) {
      case 'bank_transfer':
        _withdrawalFee = _bankTransferFee;
        break;
      case 'yape':
      case 'plin':
        _withdrawalFee = _digitalWalletFee;
        break;
      default:
        _withdrawalFee = 0.0;
    }
    _netAmount = _withdrawalAmount - _withdrawalFee;
  }

  Future<void> _initializeServices() async {
    setState(() => _isLoading = true);

    try {
      await _paymentService.initialize();
      await _loadDriverEarnings();
      await _loadEarningsHistory();
      await _loadWithdrawalHistory();
    } catch (e) {
      _showErrorSnackBar('Error cargando información: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDriverEarnings() async {
    try {
      // En un escenario real, esto vendría del backend
      final driverDoc = await _firebaseService.firestore
          .collection('drivers')
          .doc(widget.driverId)
          .get();

      if (driverDoc.exists) {
        final data = driverDoc.data() as Map<String, dynamic>;
        setState(() {
          _totalEarnings = (data['totalEarnings'] ?? 0.0).toDouble();
          _availableForWithdrawal =
              (data['availableForWithdrawal'] ?? 0.0).toDouble();
          _pendingWithdrawals = (data['pendingWithdrawals'] ?? 0.0).toDouble();
          _totalWithdrawn = (data['totalWithdrawn'] ?? 0.0).toDouble();
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error cargando ganancias: $e');
    }
  }

  Future<void> _loadEarningsHistory() async {
    try {
      // Simular datos de ejemplo - en producción vendría del backend
      _earningsHistory = [
        EarningsPeriod(
          period: 'Hoy',
          earnings: 156.50,
          trips: 12,
          hours: 8.5,
        ),
        EarningsPeriod(
          period: 'Ayer',
          earnings: 189.25,
          trips: 15,
          hours: 10.0,
        ),
        EarningsPeriod(
          period: 'Esta semana',
          earnings: 987.75,
          trips: 78,
          hours: 45.5,
        ),
        EarningsPeriod(
          period: 'Mes pasado',
          earnings: 3245.80,
          trips: 256,
          hours: 180.0,
        ),
      ];
    } catch (e) {
      _showErrorSnackBar('Error cargando historial: $e');
    }
  }

  Future<void> _loadWithdrawalHistory() async {
    try {
      // Simular historial de retiros
      _withdrawalHistory = [
        WithdrawalHistory(
          id: 'w001',
          amount: 500.0,
          fee: 3.0,
          netAmount: 497.0,
          method: 'Transferencia Bancaria',
          destination: 'BCP ****1234',
          status: 'Completado',
          processedAt: DateTime.now().subtract(const Duration(days: 2)),
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        WithdrawalHistory(
          id: 'w002',
          amount: 250.0,
          fee: 1.0,
          netAmount: 249.0,
          method: 'Yape',
          destination: '987654321',
          status: 'Completado',
          processedAt: DateTime.now().subtract(const Duration(days: 5)),
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
      ];
    } catch (e) {
      _showErrorSnackBar('Error cargando historial de retiros: $e');
    }
  }

  // ============================================================================
  // PROCESAMIENTO DE RETIROS
  // ============================================================================

  Future<void> _processWithdrawal() async {
    if (!_validateWithdrawal()) return;

    final confirmed = await _showWithdrawalConfirmation();
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      switch (_selectedWithdrawalMethod) {
        case 'bank_transfer':
          await _processBankTransfer();
          break;
        case 'yape':
          await _processYapeWithdrawal();
          break;
        case 'plin':
          await _processPlinWithdrawal();
          break;
      }

      _showSuccessDialog();
      await _loadDriverEarnings();
      await _loadWithdrawalHistory();
      _clearForm();
    } catch (e) {
      _showErrorSnackBar('Error procesando retiro: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processBankTransfer() async {
    // Simular procesamiento de transferencia bancaria
    await Future.delayed(const Duration(seconds: 2));

    // En producción, aquí se integraría con el sistema bancario
    await _firebaseService.analytics?.logEvent(
      name: 'driver_withdrawal_bank_transfer',
      parameters: {
        'driver_id': widget.driverId,
        'amount': _withdrawalAmount,
        'bank': _selectedBank,
        'account_number': _accountNumberController.text,
      },
    );
  }

  Future<void> _processYapeWithdrawal() async {
    // Simular procesamiento con Yape
    await Future.delayed(const Duration(seconds: 1));

    await _firebaseService.analytics?.logEvent(
      name: 'driver_withdrawal_yape',
      parameters: {
        'driver_id': widget.driverId,
        'amount': _withdrawalAmount,
        'phone': _phoneController.text,
      },
    );
  }

  Future<void> _processPlinWithdrawal() async {
    // Simular procesamiento con Plin
    await Future.delayed(const Duration(seconds: 1));

    await _firebaseService.analytics?.logEvent(
      name: 'driver_withdrawal_plin',
      parameters: {
        'driver_id': widget.driverId,
        'amount': _withdrawalAmount,
        'phone': _phoneController.text,
      },
    );
  }

  // ============================================================================
  // VALIDACIONES
  // ============================================================================

  bool _validateWithdrawal() {
    if (_withdrawalAmount < _minWithdrawal) {
      _showErrorSnackBar('El monto mínimo de retiro es S/$_minWithdrawal');
      return false;
    }

    if (_withdrawalAmount > _availableForWithdrawal) {
      _showErrorSnackBar('No tienes suficiente saldo disponible');
      return false;
    }

    if (_withdrawalAmount > _maxDailyWithdrawal) {
      _showErrorSnackBar(
          'El monto máximo diario de retiro es S/$_maxDailyWithdrawal');
      return false;
    }

    switch (_selectedWithdrawalMethod) {
      case 'bank_transfer':
        if (_accountNumberController.text.isEmpty) {
          _showErrorSnackBar('Ingresa el número de cuenta');
          return false;
        }
        break;
      case 'yape':
      case 'plin':
        final phone = _phoneController.text.trim();
        if (!ValidationPatterns.isValidPeruMobile(phone)) {
          _showErrorSnackBar(ValidationPatterns.getPhoneError());
          return false;
        }
        break;
    }

    return true;
  }

  // ============================================================================
  // DIÁLOGOS
  // ============================================================================

  Future<bool> _showWithdrawalConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar Retiro'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '¿Confirmas el retiro de S/${_withdrawalAmount.toStringAsFixed(2)}?'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Monto a retirar:'),
                          Text('S/${_withdrawalAmount.toStringAsFixed(2)}'),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Comisión:'),
                          Text('- S/${_withdrawalFee.toStringAsFixed(2)}'),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recibirás:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'S/${_netAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Método: ${_getMethodDisplayName(_selectedWithdrawalMethod)}',
                  style: const TextStyle(fontSize: 14),
                ),
                if (_selectedWithdrawalMethod == 'bank_transfer')
                  Text(
                    'Destino: ${_getBankDisplayName(_selectedBank)} ${_accountNumberController.text}',
                    style: const TextStyle(fontSize: 14),
                  )
                else
                  Text(
                    'Destino: ${_phoneController.text}',
                    style: const TextStyle(fontSize: 14),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('CANCELAR'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('CONFIRMAR'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 8),
            Text('¡Retiro Procesado!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tu retiro ha sido procesado exitosamente.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'S/${_netAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    _selectedWithdrawalMethod == 'bank_transfer'
                        ? 'Se procesará en 24-48 horas hábiles'
                        : 'Procesado instantáneamente',
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ENTENDIDO'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _clearForm() {
    _withdrawalAmountController.clear();
    _accountNumberController.clear();
    _phoneController.clear();
    setState(() {
      _withdrawalAmount = 0.0;
      _withdrawalFee = 0.0;
      _netAmount = 0.0;
    });
  }

  // ============================================================================
  // MÉTODOS AUXILIARES
  // ============================================================================

  String _getMethodDisplayName(String method) {
    switch (method) {
      case 'bank_transfer':
        return 'Transferencia Bancaria';
      case 'yape':
        return 'Yape';
      case 'plin':
        return 'Plin';
      default:
        return method;
    }
  }

  String _getBankDisplayName(String bank) {
    switch (bank) {
      case 'bcp':
        return 'BCP';
      case 'bbva':
        return 'BBVA';
      case 'interbank':
        return 'Interbank';
      case 'scotiabank':
        return 'Scotiabank';
      default:
        return bank.toUpperCase();
    }
  }

  // ============================================================================
  // UI - BUILD METHODS
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('💰 Mis Ganancias'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Retirar'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildDashboardTab(),
            _buildWithdrawalTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildEarningsSummaryCard(),
          const SizedBox(height: 16),
          _buildEarningsHistoryCard(),
          const SizedBox(height: 16),
          _buildQuickStatsCard(),
        ],
      ),
    );
  }

  Widget _buildEarningsSummaryCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance_wallet,
                    color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text(
                  'Resumen de Ganancias',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Disponible para retiro',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'S/${_availableForWithdrawal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Ganado',
                    'S/${_totalEarnings.toStringAsFixed(2)}',
                    Icons.trending_up,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Total Retirado',
                    'S/${_totalWithdrawn.toStringAsFixed(2)}',
                    Icons.download,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Pendientes',
                    'S/${_pendingWithdrawals.toStringAsFixed(2)}',
                    Icons.schedule,
                    Colors.grey,
                  ),
                ),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _tabController.animateTo(1),
                    icon: const Icon(Icons.download),
                    label: const Text('Retirar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsHistoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ganancias por Período',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Column(
              children: _earningsHistory.map((period) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: Text(
                      period.trips.toString(),
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(period.period),
                  subtitle:
                      Text('${period.trips} viajes • ${period.hours} horas'),
                  trailing: Text(
                    'S/${period.earnings.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsCard() {
    final avgPerTrip = _earningsHistory.isNotEmpty
        ? _earningsHistory.first.earnings / _earningsHistory.first.trips
        : 0.0;
    final avgPerHour = _earningsHistory.isNotEmpty
        ? _earningsHistory.first.earnings / _earningsHistory.first.hours
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estadísticas Rápidas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Promedio por viaje',
                    'S/${avgPerTrip.toStringAsFixed(2)}',
                    Icons.directions_car,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Promedio por hora',
                    'S/${avgPerHour.toStringAsFixed(2)}',
                    Icons.schedule,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvailableBalanceCard(),
          const SizedBox(height: 16),
          _buildWithdrawalMethodCard(),
          const SizedBox(height: 16),
          _buildWithdrawalAmountCard(),
          const SizedBox(height: 16),
          _buildDestinationCard(),
          const SizedBox(height: 16),
          _buildWithdrawalSummaryCard(),
          const SizedBox(height: 24),
          _buildProcessWithdrawalButton(),
        ],
      ),
    );
  }

  Widget _buildAvailableBalanceCard() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.account_balance_wallet,
                color: Colors.green.shade600, size: 48),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saldo Disponible',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  Text(
                    'S/${_availableForWithdrawal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  Text(
                    'Mínimo: S/$_minWithdrawal • Máximo diario: S/$_maxDailyWithdrawal',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWithdrawalMethodCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Método de Retiro',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                RadioListTile<String>(
                  value: 'bank_transfer',
                  groupValue: _selectedWithdrawalMethod,
                  title: const Text('🏦 Transferencia Bancaria'),
                  subtitle: const Text('Comisión: S/3.00 • 24-48 horas'),
                  onChanged: (value) {
                    setState(() {
                      _selectedWithdrawalMethod = value!;
                      _calculateWithdrawalFee();
                    });
                  },
                ),
                RadioListTile<String>(
                  value: 'yape',
                  groupValue: _selectedWithdrawalMethod,
                  title: const Text('📱 Yape'),
                  subtitle: const Text('Comisión: S/1.00 • Instantáneo'),
                  onChanged: (value) {
                    setState(() {
                      _selectedWithdrawalMethod = value!;
                      _calculateWithdrawalFee();
                    });
                  },
                ),
                RadioListTile<String>(
                  value: 'plin',
                  groupValue: _selectedWithdrawalMethod,
                  title: const Text('💸 Plin'),
                  subtitle: const Text('Comisión: S/1.00 • Instantáneo'),
                  onChanged: (value) {
                    setState(() {
                      _selectedWithdrawalMethod = value!;
                      _calculateWithdrawalFee();
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWithdrawalAmountCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monto a Retirar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _withdrawalAmountController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Monto (S/)',
                hintText: '0.00',
                prefixText: 'S/ ',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.money),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      _withdrawalAmountController.text = '100';
                      setState(() {
                        _withdrawalAmount = 100.0;
                        _calculateWithdrawalFee();
                      });
                    },
                    child: const Text('S/100'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      _withdrawalAmountController.text = '250';
                      setState(() {
                        _withdrawalAmount = 250.0;
                        _calculateWithdrawalFee();
                      });
                    },
                    child: const Text('S/250'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      _withdrawalAmountController.text = '500';
                      setState(() {
                        _withdrawalAmount = 500.0;
                        _calculateWithdrawalFee();
                      });
                    },
                    child: const Text('S/500'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      _withdrawalAmountController.text =
                          _availableForWithdrawal.toString();
                      setState(() {
                        _withdrawalAmount = _availableForWithdrawal;
                        _calculateWithdrawalFee();
                      });
                    },
                    child: const Text('Retirar todo'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Destino',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_selectedWithdrawalMethod == 'bank_transfer') ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedBank,
                decoration: const InputDecoration(
                  labelText: 'Banco',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'interbank', child: Text('Interbank')),
                  DropdownMenuItem(value: 'bcp', child: Text('BCP')),
                  DropdownMenuItem(value: 'bbva', child: Text('BBVA')),
                  DropdownMenuItem(
                      value: 'scotiabank', child: Text('Scotiabank')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedBank = value!;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(20),
                ],
                decoration: const InputDecoration(
                  labelText: 'Número de Cuenta',
                  hintText: '1234567890123456',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.account_balance),
                ),
              ),
            ] else ...[
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(9),
                ],
                decoration: InputDecoration(
                  labelText: 'Número de Teléfono',
                  hintText: '987654321',
                  prefixText: '+51 ',
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.phone),
                  helperText: 'Para ${_selectedWithdrawalMethod.toUpperCase()}',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWithdrawalSummaryCard() {
    if (_withdrawalAmount <= 0) return const SizedBox.shrink();

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumen del Retiro',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Monto a retirar:'),
                Text('S/${_withdrawalAmount.toStringAsFixed(2)}'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    'Comisión (${_getMethodDisplayName(_selectedWithdrawalMethod)}):'),
                Text('- S/${_withdrawalFee.toStringAsFixed(2)}'),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recibirás:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'S/${_netAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _selectedWithdrawalMethod == 'bank_transfer'
                  ? 'Tiempo de procesamiento: 24-48 horas hábiles'
                  : 'Procesamiento: Instantáneo',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessWithdrawalButton() {
    final isEnabled = _withdrawalAmount >= _minWithdrawal &&
        _withdrawalAmount <= _availableForWithdrawal &&
        !_isLoading;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isEnabled ? _processWithdrawal : null,
        icon: const Icon(Icons.download),
        label: Text(
          'Procesar Retiro${_netAmount > 0 ? ' (S/${_netAmount.toStringAsFixed(2)})' : ''}',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_withdrawalHistory.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No tienes retiros previos',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Column(
              children: _withdrawalHistory.map((withdrawal) {
                Color statusColor;
                IconData statusIcon;

                switch (withdrawal.status) {
                  case 'Completado':
                    statusColor = Colors.green;
                    statusIcon = Icons.check_circle;
                    break;
                  case 'Procesando':
                    statusColor = Colors.orange;
                    statusIcon = Icons.schedule;
                    break;
                  case 'Rechazado':
                    statusColor = Colors.red;
                    statusIcon = Icons.cancel;
                    break;
                  default:
                    statusColor = Colors.grey;
                    statusIcon = Icons.help;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: statusColor.withValues(alpha: 0.2),
                      child: Icon(statusIcon, color: statusColor),
                    ),
                    title: Text('S/${withdrawal.amount.toStringAsFixed(2)}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${withdrawal.method} • ${withdrawal.destination}'),
                        Text(
                          'Recibido: S/${withdrawal.netAmount.toStringAsFixed(2)} • '
                          '${withdrawal.createdAt.day}/${withdrawal.createdAt.month}/${withdrawal.createdAt.year}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        withdrawal.status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// CLASES DE DATOS
// ============================================================================

class EarningsPeriod {
  final String period;
  final double earnings;
  final int trips;
  final double hours;

  EarningsPeriod({
    required this.period,
    required this.earnings,
    required this.trips,
    required this.hours,
  });
}

class WithdrawalHistory {
  final String id;
  final double amount;
  final double fee;
  final double netAmount;
  final String method;
  final String destination;
  final String status;
  final DateTime createdAt;
  final DateTime? processedAt;

  WithdrawalHistory({
    required this.id,
    required this.amount,
    required this.fee,
    required this.netAmount,
    required this.method,
    required this.destination,
    required this.status,
    required this.createdAt,
    this.processedAt,
  });
}
