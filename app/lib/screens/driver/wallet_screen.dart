import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/theme/modern_theme.dart';
import '../../widgets/animated/modern_animated_widgets.dart';
import '../../utils/app_logger.dart';
import '../../providers/auth_provider.dart';
import '../../services/payment_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with TickerProviderStateMixin {
  late AnimationController _balanceController;
  late AnimationController _cardsController;
  late AnimationController _transactionsController;
  late TabController _tabController;

  // Balance desde Firebase
  double _currentBalance = 0.0;
  double _pendingAmount = 0.0;
  double _weeklyEarnings = 0.0;
  double _monthlyEarnings = 0.0;

  // Streams
  Stream<DocumentSnapshot>? _walletStream;
  Stream<QuerySnapshot>? _transactionsStream;

  // Transactions list
  List<Transaction> _transactions = [];

  // Services
  final PaymentService _paymentService = PaymentService();

  // Método de retiro seleccionado
  String _selectedWithdrawalMethod = 'bank';
  final TextEditingController _withdrawalAmountController =
      TextEditingController();
  Map<String, dynamic>? _bankAccount;

  // Transacciones mock
  // Verification Comment 3: Remove mock transactions, use real Firestore data
  // Transactions are now loaded from Firestore streams in _transactionsStream

  // Statistics calculated from real data
  double _todayEarnings = 0.0;
  int _todayTrips = 0;
  double _todayCommission = 0.0;

  // Verification Comment 3: Statistics from real-time data
  Map<String, dynamic> get _statistics {
    return {
      'todayEarnings': _todayEarnings,
      'totalTrips': _todayTrips,
      'totalCommission': _todayCommission,
      'avgPerTrip': _todayTrips > 0 ? _todayEarnings / _todayTrips : 0,
    };
  }

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('WalletScreen', 'initState');

    _balanceController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    )..forward();

    _cardsController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _transactionsController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    )..forward();

    _tabController = TabController(length: 3, vsync: this);

    // Inicializar streams de Firestore
    _initializeStreams();
    _loadBankAccount();
    _calculateEarnings();
  }

  void _initializeStreams() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;

    if (userId != null) {
      // Stream de wallet
      _walletStream = FirebaseFirestore.instance
          .collection('wallets')
          .doc(userId)
          .snapshots();

      // Stream de transacciones
      _transactionsStream = FirebaseFirestore.instance
          .collection('walletTransactions')
          .where('walletId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots();

      // Escuchar cambios en el wallet
      _walletStream!.listen((snapshot) {
        if (snapshot.exists && mounted) {
          final data = snapshot.data() as Map<String, dynamic>;
          setState(() {
            _currentBalance = (data['balance'] ?? 0.0).toDouble();
            _pendingAmount = (data['pendingBalance'] ?? 0.0).toDouble();
          });
        }
      });

      // Verification Comment 3: Calculate today's statistics from transactions stream
      _transactionsStream!.listen((snapshot) {
        if (mounted) {
          // Update transactions list
          _transactions = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Transaction.fromFirestore(data, doc.id);
          }).toList();

          double todayEarnings = 0.0;
          int todayTrips = 0;
          double todayCommission = 0.0;
          final today = DateTime.now();

          for (var doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

            if (createdAt != null &&
                createdAt.day == today.day &&
                createdAt.month == today.month &&
                createdAt.year == today.year) {

              if (data['type'] == 'earning' && data['status'] == 'completed') {
                todayEarnings += (data['amount'] ?? 0.0).toDouble();
                todayTrips++;

                // Get commission from metadata if available
                final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
                todayCommission += (metadata['commission'] ?? 0.0).toDouble();
              }
            }
          }

          setState(() {
            _todayEarnings = todayEarnings;
            _todayTrips = todayTrips;
            _todayCommission = todayCommission;
          });
        }
      });
    }
  }

  Future<void> _loadBankAccount() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;

    if (userId != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _bankAccount = data['bankAccount'] as Map<String, dynamic>?;
        });
      }
    }
  }

  Future<void> _calculateEarnings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;

    if (userId != null) {
      final now = DateTime.now();
      final weekAgo = now.subtract(Duration(days: 7));
      final monthAgo = now.subtract(Duration(days: 30));

      // Calcular ganancias semanales
      final weekSnapshot = await FirebaseFirestore.instance
          .collection('walletTransactions')
          .where('walletId', isEqualTo: userId)
          .where('type', isEqualTo: 'earning')
          .where('status', isEqualTo: 'completed')
          .where('createdAt', isGreaterThan: weekAgo)
          .get();

      double weeklyTotal = 0.0;
      for (var doc in weekSnapshot.docs) {
        final amount = (doc.data()['amount'] ?? 0.0).toDouble();
        if (amount > 0) weeklyTotal += amount; // Already net of commission
      }

      // Calcular ganancias mensuales
      final monthSnapshot = await FirebaseFirestore.instance
          .collection('walletTransactions')
          .where('walletId', isEqualTo: userId)
          .where('type', isEqualTo: 'earning')
          .where('status', isEqualTo: 'completed')
          .where('createdAt', isGreaterThan: monthAgo)
          .get();

      double monthlyTotal = 0.0;
      for (var doc in monthSnapshot.docs) {
        final amount = (doc.data()['amount'] ?? 0.0).toDouble();
        if (amount > 0) monthlyTotal += amount; // Already net of commission
      }

      if (mounted) {
        setState(() {
          _weeklyEarnings = weeklyTotal;
          _monthlyEarnings = monthlyTotal;
        });
      }
    }
  }

  @override
  void dispose() {
    _balanceController.dispose();
    _cardsController.dispose();
    _transactionsController.dispose();
    _tabController.dispose();
    _withdrawalAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: ModernTheme.oasisGreen,
        title: Text(
          'Mi Billetera',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, color: Colors.white),
            onPressed: _showHelp,
          ),
        ],
      ),
      body: Column(
        children: [
          // Balance card animado
          AnimatedBuilder(
            animation: _balanceController,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.8 + (0.2 * _balanceController.value),
                child: Opacity(
                  opacity: _balanceController.value,
                  child: _buildBalanceCard(),
                ),
              );
            },
          ),

          // Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: ModernTheme.oasisGreen,
              unselectedLabelColor: ModernTheme.textSecondary,
              indicatorColor: ModernTheme.oasisGreen,
              tabs: [
                Tab(text: 'Resumen'),
                Tab(text: 'Transacciones'),
                Tab(text: 'Retirar'),
              ],
            ),
          ),

          // Contenido de tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSummaryTab(),
                _buildTransactionsTab(),
                _buildWithdrawTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ModernTheme.oasisGreen,
            ModernTheme.oasisGreen.withBlue(50),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ModernTheme.oasisGreen.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Balance Disponible',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: _balanceController,
                    builder: (context, child) {
                      final displayBalance =
                          _currentBalance * _balanceController.value;
                      return Text(
                        '\$${displayBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Estadísticas rápidas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickStat(
                'Esta Semana',
                '\$${_weeklyEarnings.toStringAsFixed(2)}',
                Icons.calendar_today,
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.white24,
              ),
              _buildQuickStat(
                'Este Mes',
                '\$${_monthlyEarnings.toStringAsFixed(2)}',
                Icons.calendar_month,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryTab() {
    final stats = _statistics;

    return AnimatedBuilder(
      animation: _cardsController,
      builder: (context, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estadísticas del Día',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ModernTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Grid de estadísticas
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  _buildStatCard(
                    'Ganancias Hoy',
                    '\$${stats['todayEarnings'].toStringAsFixed(2)}',
                    Icons.today,
                    ModernTheme.success,
                    0,
                  ),
                  _buildStatCard(
                    'Viajes Completados',
                    '${stats['totalTrips']}',
                    Icons.directions_car,
                    ModernTheme.primaryBlue,
                    1,
                  ),
                  _buildStatCard(
                    'Comisión Total',
                    '\$${stats['totalCommission'].toStringAsFixed(2)}',
                    Icons.receipt,
                    ModernTheme.warning,
                    2,
                  ),
                  _buildStatCard(
                    'Promedio/Viaje',
                    '\$${stats['avgPerTrip'].toStringAsFixed(2)}',
                    Icons.analytics,
                    ModernTheme.info,
                    3,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Gráfico de ganancias
              Text(
                'Ganancias de la Semana',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ModernTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              Container(
                height: 200,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: ModernTheme.cardShadow,
                ),
                child: CustomPaint(
                  painter: EarningsChartPainter(
                    animation: _cardsController,
                  ),
                  child: Container(),
                ),
              ),

              const SizedBox(height: 24),

              // Metas y objetivos
              Text(
                'Metas del Mes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ModernTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              _buildGoalCard(
                'Meta de Ganancias',
                _monthlyEarnings,
                3000.00,
                ModernTheme.oasisGreen,
              ),
              const SizedBox(height: 12),
              _buildGoalCard(
                'Viajes Completados',
                127,
                150,
                ModernTheme.primaryBlue,
              ),
              const SizedBox(height: 12),
              _buildGoalCard(
                'Calificación Promedio',
                4.8,
                5.0,
                Colors.amber,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _transactionsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 64,
                  color: ModernTheme.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No hay transacciones',
                  style: TextStyle(
                    color: ModernTheme.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        final transactions = snapshot.data!.docs;

        return AnimatedBuilder(
          animation: _transactionsController,
          builder: (context, child) {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final transactionDoc = transactions[index];
                final transactionData = transactionDoc.data() as Map<String, dynamic>;

                // Convertir a formato Transaction para reutilizar el widget
                final transaction = Transaction(
                  id: transactionDoc.id,
                  type: _getTransactionType(transactionData['type']),
                  amount: (transactionData['amount'] ?? 0.0).toDouble(),
                  date: (transactionData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                  description: transactionData['description'] ?? '',
                  passenger: transactionData['metadata']?['passengerName'],
                  status: transactionData['status'] ?? 'completed',
                  commission: transactionData['metadata']?['commission']?.toDouble(),
                );

                final delay = index * 0.1;
                final animation = Tween<double>(
                  begin: 0,
                  end: 1,
                ).animate(
                  CurvedAnimation(
                    parent: _transactionsController,
                    curve: Interval(
                      delay,
                      delay + 0.5,
                      curve: Curves.easeOutBack,
                    ),
                  ),
                );

                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(50 * (1 - animation.value), 0),
                      child: Opacity(
                        opacity: animation.value,
                        child: _buildTransactionCard(transaction),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  TransactionType _getTransactionType(String? type) {
    switch (type) {
      case 'earning':
        return TransactionType.tripEarning;
      case 'withdrawal':
      case 'withdrawal_request':
        return TransactionType.withdrawal;
      case 'transfer_in':
      case 'bonus':
        return TransactionType.bonus;
      case 'transfer_out':
      case 'penalty':
        return TransactionType.penalty;
      case 'refund':
        return TransactionType.refund;
      default:
        return TransactionType.tripEarning;
    }
  }

  Widget _buildWithdrawTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance disponible
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ModernTheme.oasisGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: ModernTheme.oasisGreen,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disponible para retirar',
                      style: TextStyle(
                        color: ModernTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '\$${_currentBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: ModernTheme.oasisGreen,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Monto a retirar
          Text(
            'Monto a Retirar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ModernTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _withdrawalAmountController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixIcon:
                  Icon(Icons.attach_money, color: ModernTheme.oasisGreen),
              hintText: '0.00',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: ModernTheme.oasisGreen, width: 2),
              ),
            ),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          // Botones rápidos de monto
          Wrap(
            spacing: 8,
            children: [50, 100, 200, 500].map((amount) {
              return ActionChip(
                label: Text('\$$amount'),
                onPressed: () {
                  setState(() {
                    _withdrawalAmountController.text = amount.toString();
                  });
                },
                backgroundColor: ModernTheme.backgroundLight,
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Método de retiro
          Text(
            'Método de Retiro',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ModernTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          _buildWithdrawalMethod(
            'bank',
            'Cuenta Bancaria',
            '**** **** **** 1234',
            Icons.account_balance,
          ),
          const SizedBox(height: 12),
          _buildWithdrawalMethod(
            'card',
            'Tarjeta de Débito',
            '**** **** **** 5678',
            Icons.credit_card,
          ),
          const SizedBox(height: 12),
          _buildWithdrawalMethod(
            'cash',
            'Efectivo en Oficina',
            'Av. Principal 123',
            Icons.store,
          ),

          const SizedBox(height: 24),

          // Información importante
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ModernTheme.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ModernTheme.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: ModernTheme.warning,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Información Importante',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ModernTheme.warning,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Los retiros se procesan en 1-2 días hábiles\n'
                        '• Monto mínimo de retiro: \$10.00\n'
                        '• Sin comisiones por retiro',
                        style: TextStyle(
                          fontSize: 12,
                          color: ModernTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Botón de retirar
          AnimatedPulseButton(
            text: 'Solicitar Retiro',
            icon: Icons.send,
            onPressed: _processWithdrawal,
            color: ModernTheme.oasisGreen,
          ),

          const SizedBox(height: 24),

          // Historial de retiros
          Text(
            'Retiros Recientes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ModernTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          ..._transactions
              .where((t) => t.type == TransactionType.withdrawal)
              .take(3)
              .map((t) => _buildWithdrawalHistoryItem(t)),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    int index,
  ) {
    final delay = index * 0.1;
    final animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _cardsController,
        curve: Interval(
          delay,
          delay + 0.5,
          curve: Curves.easeOutBack,
        ),
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: animation.value,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: ModernTheme.cardShadow,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.textPrimary,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: ModernTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGoalCard(
    String title,
    num current,
    num goal,
    Color color,
  ) {
    final progress = (current / goal).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: ModernTheme.textPrimary,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              AnimatedContainer(
                duration: Duration(milliseconds: 800),
                height: 8,
                width: MediaQuery.of(context).size.width * progress * 0.8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                current is double
                    ? '\$${current.toStringAsFixed(2)}'
                    : current.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: ModernTheme.textSecondary,
                ),
              ),
              Text(
                goal is double
                    ? '\$${goal.toStringAsFixed(2)}'
                    : goal.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: ModernTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    final isEarning = transaction.amount > 0;
    final icon = _getTransactionIcon(transaction.type);
    final color = _getTransactionColor(transaction.type);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: InkWell(
        onTap: () => _showTransactionDetails(transaction),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (transaction.passenger != null)
                      Text(
                        transaction.passenger!,
                        style: TextStyle(
                          fontSize: 12,
                          color: ModernTheme.textSecondary,
                        ),
                      ),
                    Text(
                      _formatDate(transaction.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: ModernTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isEarning ? '+' : ''}\$${transaction.amount.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color:
                          isEarning ? ModernTheme.success : ModernTheme.error,
                    ),
                  ),
                  if (transaction.commission != null)
                    Text(
                      'Comisión: \$${transaction.commission!.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: ModernTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWithdrawalMethod(
    String value,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = _selectedWithdrawalMethod == value;

    return InkWell(
      onTap: () => setState(() => _selectedWithdrawalMethod = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? ModernTheme.oasisGreen.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? ModernTheme.oasisGreen : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? ModernTheme.oasisGreen
                  : ModernTheme.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? ModernTheme.oasisGreen
                          : ModernTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: ModernTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: ModernTheme.oasisGreen,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWithdrawalHistoryItem(Transaction transaction) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ModernTheme.backgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.history,
            color: ModernTheme.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  _formatDate(transaction.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: ModernTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\$${transaction.amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: ModernTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTransactionIcon(TransactionType type) {
    switch (type) {
      case TransactionType.earning:
      case TransactionType.tripEarning:
        return Icons.directions_car;
      case TransactionType.withdrawal:
        return Icons.account_balance;
      case TransactionType.bonus:
        return Icons.card_giftcard;
      case TransactionType.penalty:
        return Icons.warning;
      case TransactionType.refund:
        return Icons.replay;
      case TransactionType.commission:
        return Icons.percent;
    }
  }

  Color _getTransactionColor(TransactionType type) {
    switch (type) {
      case TransactionType.earning:
      case TransactionType.tripEarning:
        return ModernTheme.success;
      case TransactionType.withdrawal:
        return ModernTheme.primaryBlue;
      case TransactionType.bonus:
        return Colors.purple;
      case TransactionType.penalty:
        return ModernTheme.error;
      case TransactionType.refund:
        return Colors.orange;
      case TransactionType.commission:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'Hace ${difference.inMinutes} min';
      }
      return 'Hace ${difference.inHours} horas';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  void _showTransactionDetails(Transaction transaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Detalles de la Transacción',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildDetailRow('ID', transaction.id),
            _buildDetailRow(
                'Tipo', transaction.type.toString().split('.').last),
            _buildDetailRow('Descripción', transaction.description),
            if (transaction.passenger != null)
              _buildDetailRow('Pasajero', transaction.passenger!),
            _buildDetailRow('Fecha', _formatDate(transaction.date)),
            _buildDetailRow('Hora',
                '${transaction.date.hour.toString().padLeft(2, '0')}:${transaction.date.minute.toString().padLeft(2, '0')}'),
            _buildDetailRow(
                'Monto', '\$${transaction.amount.abs().toStringAsFixed(2)}'),
            if (transaction.commission != null)
              _buildDetailRow('Comisión',
                  '\$${transaction.commission!.toStringAsFixed(2)}'),
            _buildDetailRow('Estado', transaction.status),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close),
              label: Text('Cerrar'),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: ModernTheme.textSecondary),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _processWithdrawal() async {
    final amount = double.tryParse(_withdrawalAmountController.text) ?? 0;

    if (amount < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('El monto mínimo de retiro es \$10.00'),
          backgroundColor: ModernTheme.error,
        ),
      );
      return;
    }

    if (amount > _currentBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saldo insuficiente'),
          backgroundColor: ModernTheme.error,
        ),
      );
      return;
    }

    if (_bankAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor configure su cuenta bancaria primero'),
          backgroundColor: ModernTheme.error,
          action: SnackBarAction(
            label: 'Configurar',
            onPressed: () {
              Navigator.pushNamed(context, '/driver/profile');
            },
          ),
        ),
      );
      return;
    }

    // Procesar retiro con servicio real
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ModernLoadingIndicator(color: ModernTheme.oasisGreen),
            const SizedBox(height: 20),
            Text('Procesando retiro...'),
          ],
        ),
      ),
    );

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      if (userId == null) throw Exception('Usuario no autenticado');

      // Verification Comment 8: Don't send driverId, service uses auth context
      final result = await _paymentService.requestWithdrawal(
        amount: amount,
        bankAccount: _bankAccount!,
        notes: 'Retiro vía billetera digital',
      );

      if (!mounted) return;
      Navigator.pop(context); // Cerrar dialog de carga

      if (result.success) {
        setState(() {
          _withdrawalAmountController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Retiro solicitado exitosamente'),
              ],
            ),
            backgroundColor: ModernTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        // Recargar balance
        _calculateEarnings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Error procesando retiro'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Cerrar dialog de carga

      AppLogger.error('Error procesando retiro', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error procesando retiro: ${e.toString()}'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('Ayuda - Billetera'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cómo funciona tu billetera:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '• Las ganancias se acumulan después de cada viaje\n'
                '• Puedes retirar cuando tengas mínimo \$10\n'
                '• Los retiros se procesan en 1-2 días hábiles\n'
                '• No hay comisiones por retiro\n'
                '• Revisa tus estadísticas para mejorar tus ganancias',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

// Modelo de transacción
enum TransactionType {
  tripEarning,
  withdrawal,
  bonus,
  penalty,
  refund,
  earning,  // Para compatibilidad con Firestore
  commission  // Para compatibilidad con Firestore
}

class Transaction {
  final String id;
  final TransactionType type;
  final double amount;
  final DateTime date;
  final String description;
  final String? passenger;
  final String status;
  final double? commission;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.description,
    this.passenger,
    required this.status,
    this.commission,
  });

  // Factory constructor para crear desde Firestore
  static Transaction fromFirestore(Map<String, dynamic> data, String id) {
    return Transaction(
      id: id,
      type: _parseTransactionType(data['type'] ?? 'earning'),
      amount: (data['amount'] ?? 0.0).toDouble(),
      date: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: data['description'] ?? '',
      passenger: data['passenger'],
      status: data['status'] ?? 'pending',
      commission: data['commission']?.toDouble(),
    );
  }
}

// Función helper para parsear el tipo de transacción
TransactionType _parseTransactionType(String type) {
  switch (type) {
    case 'earning':
      return TransactionType.earning;
    case 'tripEarning':
      return TransactionType.tripEarning;
    case 'withdrawal':
      return TransactionType.withdrawal;
    case 'bonus':
      return TransactionType.bonus;
    case 'penalty':
      return TransactionType.penalty;
    case 'refund':
      return TransactionType.refund;
    case 'commission':
      return TransactionType.commission;
    default:
      return TransactionType.earning;
  }
}

// Painter para el gráfico de ganancias
class EarningsChartPainter extends CustomPainter {
  final Animation<double> animation;

  const EarningsChartPainter({super.repaint, required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ModernTheme.oasisGreen
      ..style = PaintingStyle.fill;

    final data = [0.4, 0.6, 0.3, 0.8, 0.5, 0.9, 0.7];
    final days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final barWidth = size.width / (data.length * 2);

    for (int i = 0; i < data.length; i++) {
      final barHeight = size.height * 0.8 * data[i] * animation.value;
      final x = i * (barWidth * 2) + barWidth / 2;
      final y = size.height * 0.8 - barHeight;

      // Barra
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        Radius.circular(4),
      );

      // Gradiente
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          ModernTheme.oasisGreen,
          ModernTheme.oasisGreen.withValues(alpha: 0.6),
        ],
      ).createShader(rect.outerRect);

      canvas.drawRRect(rect, paint);

      // Etiqueta del día
      final textPainter = TextPainter(
        text: TextSpan(
          text: days[i],
          style: TextStyle(
            color: ModernTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + barWidth / 2 - textPainter.width / 2, size.height * 0.85),
      );

      // Valor
      final valuePainter = TextPainter(
        text: TextSpan(
          text: '\$${(data[i] * 100).toInt()}',
          style: TextStyle(
            color: ModernTheme.textPrimary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      valuePainter.layout();
      valuePainter.paint(
        canvas,
        Offset(x + barWidth / 2 - valuePainter.width / 2, y - 15),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
