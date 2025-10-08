// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/modern_theme.dart';
import '../../widgets/animated/modern_animated_widgets.dart';

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
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final bool _isLoading = true;
  
  // Balance desde Firebase
  double _currentBalance = 0.0;
  final double _weeklyEarnings = 0.0;
  final double _monthlyEarnings = 0.0;
  
  // Método de retiro seleccionado
  String _selectedWithdrawalMethod = 'bank';
  final TextEditingController _withdrawalAmountController = TextEditingController();
  
  // Transacciones mock
  final List<Transaction> _transactions = [
    Transaction(
      id: 'T001',
      type: TransactionType.tripEarning,
      amount: 25.50,
      date: DateTime.now().subtract(Duration(hours: 2)),
      description: 'Viaje #T001',
      passenger: 'Juan Pérez',
      status: 'completed',
      commission: 5.10,
    ),
    Transaction(
      id: 'W001',
      type: TransactionType.withdrawal,
      amount: -200.00,
      date: DateTime.now().subtract(Duration(days: 1)),
      description: 'Retiro a cuenta bancaria',
      status: 'completed',
    ),
    Transaction(
      id: 'T002',
      type: TransactionType.tripEarning,
      amount: 45.00,
      date: DateTime.now().subtract(Duration(days: 1)),
      description: 'Viaje #T002',
      passenger: 'María García',
      status: 'completed',
      commission: 9.00,
    ),
    Transaction(
      id: 'B001',
      type: TransactionType.bonus,
      amount: 50.00,
      date: DateTime.now().subtract(Duration(days: 2)),
      description: 'Bono por 50 viajes completados',
      status: 'completed',
    ),
    Transaction(
      id: 'T003',
      type: TransactionType.tripEarning,
      amount: 18.75,
      date: DateTime.now().subtract(Duration(days: 2)),
      description: 'Viaje #T003',
      passenger: 'Carlos López',
      status: 'completed',
      commission: 3.75,
    ),
  ];
  
  // Estadísticas
  Map<String, dynamic> get _statistics {
    final today = DateTime.now();
    final todayEarnings = _transactions
        .where((t) =>
            t.type == TransactionType.tripEarning &&
            t.date.day == today.day &&
            t.date.month == today.month &&
            t.date.year == today.year)
        .fold<double>(0, (total, t) => total + t.amount);

    final totalTrips = _transactions
        .where((t) => t.type == TransactionType.tripEarning)
        .length;

    final totalCommission = _transactions
        .where((t) => t.type == TransactionType.tripEarning)
        .fold<double>(0, (total, t) => total + (t.commission ?? 0));
    
    return {
      'todayEarnings': todayEarnings,
      'totalTrips': totalTrips,
      'totalCommission': totalCommission,
      'avgPerTrip': totalTrips > 0 ? _weeklyEarnings / totalTrips : 0,
    };
  }
  
  @override
  void initState() {
    super.initState();
    
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
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
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
                  SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: _balanceController,
                    builder: (context, child) {
                      final displayBalance = _currentBalance * _balanceController.value;
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
                padding: EdgeInsets.all(12),
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
          
          SizedBox(height: 20),
          
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
        SizedBox(height: 4),
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
          padding: EdgeInsets.all(16),
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
              SizedBox(height: 16),
              
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
              
              SizedBox(height: 24),
              
              // Gráfico de ganancias
              Text(
                'Ganancias de la Semana',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ModernTheme.textPrimary,
                ),
              ),
              SizedBox(height: 16),
              
              Container(
                height: 200,
                padding: EdgeInsets.all(16),
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
              
              SizedBox(height: 24),
              
              // Metas y objetivos
              Text(
                'Metas del Mes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ModernTheme.textPrimary,
                ),
              ),
              SizedBox(height: 16),
              
              _buildGoalCard(
                'Meta de Ganancias',
                _monthlyEarnings,
                3000.00,
                ModernTheme.oasisGreen,
              ),
              SizedBox(height: 12),
              _buildGoalCard(
                'Viajes Completados',
                127,
                150,
                ModernTheme.primaryBlue,
              ),
              SizedBox(height: 12),
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
    return AnimatedBuilder(
      animation: _transactionsController,
      builder: (context, child) {
        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: _transactions.length,
          itemBuilder: (context, index) {
            final transaction = _transactions[index];
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
  }
  
  Widget _buildWithdrawTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance disponible
          Container(
            padding: EdgeInsets.all(16),
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
                SizedBox(width: 12),
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
          
          SizedBox(height: 24),
          
          // Monto a retirar
          Text(
            'Monto a Retirar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ModernTheme.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          
          TextField(
            controller: _withdrawalAmountController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.attach_money, color: ModernTheme.oasisGreen),
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
          
          SizedBox(height: 12),
          
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
          
          SizedBox(height: 24),
          
          // Método de retiro
          Text(
            'Método de Retiro',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ModernTheme.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          
          _buildWithdrawalMethod(
            'bank',
            'Cuenta Bancaria',
            '**** **** **** 1234',
            Icons.account_balance,
          ),
          SizedBox(height: 12),
          _buildWithdrawalMethod(
            'card',
            'Tarjeta de Débito',
            '**** **** **** 5678',
            Icons.credit_card,
          ),
          SizedBox(height: 12),
          _buildWithdrawalMethod(
            'cash',
            'Efectivo en Oficina',
            'Av. Principal 123',
            Icons.store,
          ),
          
          SizedBox(height: 24),
          
          // Información importante
          Container(
            padding: EdgeInsets.all(12),
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
                SizedBox(width: 8),
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
                      SizedBox(height: 4),
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
          
          SizedBox(height: 24),
          
          // Botón de retirar
          AnimatedPulseButton(
            text: 'Solicitar Retiro',
            icon: Icons.send,
            onPressed: _processWithdrawal,
            color: ModernTheme.oasisGreen,
          ),
          
          SizedBox(height: 24),
          
          // Historial de retiros
          Text(
            'Retiros Recientes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ModernTheme.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          
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
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: ModernTheme.cardShadow,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                SizedBox(height: 8),
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
      padding: EdgeInsets.all(16),
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
          SizedBox(height: 8),
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
          SizedBox(height: 8),
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
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              SizedBox(width: 12),
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
                      color: isEarning ? ModernTheme.success : ModernTheme.error,
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
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
            ? ModernTheme.oasisGreen.withValues(alpha: 0.1)
            : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
              ? ModernTheme.oasisGreen 
              : Colors.grey.shade300,
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
            SizedBox(width: 12),
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
            Radio<String>(
              value: value,
              groupValue: _selectedWithdrawalMethod,
              onChanged: (val) => setState(() => _selectedWithdrawalMethod = val!),
              activeColor: ModernTheme.oasisGreen,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWithdrawalHistoryItem(Transaction transaction) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
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
          SizedBox(width: 12),
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
      case TransactionType.tripEarning:
        return Icons.directions_car;
      case TransactionType.withdrawal:
        return Icons.account_balance;
      case TransactionType.bonus:
        return Icons.card_giftcard;
      case TransactionType.penalty:
        return Icons.warning;
    }
  }
  
  Color _getTransactionColor(TransactionType type) {
    switch (type) {
      case TransactionType.tripEarning:
        return ModernTheme.success;
      case TransactionType.withdrawal:
        return ModernTheme.primaryBlue;
      case TransactionType.bonus:
        return Colors.purple;
      case TransactionType.penalty:
        return ModernTheme.error;
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
        padding: EdgeInsets.all(20),
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
            SizedBox(height: 20),
            Text(
              'Detalles de la Transacción',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            _buildDetailRow('ID', transaction.id),
            _buildDetailRow('Tipo', transaction.type.toString().split('.').last),
            _buildDetailRow('Descripción', transaction.description),
            if (transaction.passenger != null)
              _buildDetailRow('Pasajero', transaction.passenger!),
            _buildDetailRow('Fecha', _formatDate(transaction.date)),
            _buildDetailRow('Hora', 
              '${transaction.date.hour.toString().padLeft(2, '0')}:${transaction.date.minute.toString().padLeft(2, '0')}'),
            _buildDetailRow('Monto', '\$${transaction.amount.abs().toStringAsFixed(2)}'),
            if (transaction.commission != null)
              _buildDetailRow('Comisión', '\$${transaction.commission!.toStringAsFixed(2)}'),
            _buildDetailRow('Estado', transaction.status),
            SizedBox(height: 20),
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
      padding: EdgeInsets.symmetric(vertical: 6),
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
  
  void _processWithdrawal() {
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
    
    // Procesar retiro
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
            SizedBox(height: 20),
            Text('Procesando retiro...'),
          ],
        ),
      ),
    );
    
    Future.delayed(Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pop(context);
      if (mounted) {
        setState(() {
          _currentBalance -= amount;
          _withdrawalAmountController.clear();
        });
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
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
    });
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
              SizedBox(height: 8),
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
enum TransactionType { tripEarning, withdrawal, bonus, penalty }

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