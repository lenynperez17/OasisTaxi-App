import '../../utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/modern_theme.dart';

class TransactionsHistoryScreen extends StatefulWidget {
  const TransactionsHistoryScreen({super.key});

  @override
  TransactionsHistoryScreenState createState() =>
      TransactionsHistoryScreenState();
}

class TransactionsHistoryScreenState extends State<TransactionsHistoryScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  // Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Filter state
  String _selectedFilter = 'all';
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';

  // Transactions data - Ahora cargados desde Firebase
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Summary data
  Map<String, dynamic> _summary = {
    'totalEarnings': 0.0,
    'totalTrips': 0,
    'totalWithdrawals': 0.0,
    'pendingBalance': 0.0,
    'thisWeek': 0.0,
    'lastWeek': 0.0,
  };

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('TransactionsHistoryScreen', 'initState');

    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    );

    _fadeController.forward();
    _slideController.forward();

    _loadTransactionsFromFirebase();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  /// Cargar transacciones reales desde Firebase
  Future<void> _loadTransactionsFromFirebase() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'No hay usuario autenticado';
          _isLoading = false;
        });
        return;
      }

      // Cargar transacciones del conductor
      final QuerySnapshot snapshot = await _firestore
          .collection('drivers')
          .doc(user.uid)
          .collection('transactions')
          .orderBy('date', descending: true)
          .limit(100)
          .get();

      final List<Transaction> loadedTransactions = [];
      double totalEarnings = 0.0;
      double totalWithdrawals = 0.0;
      int totalTrips = 0;
      double thisWeek = 0.0;
      double lastWeek = 0.0;

      final now = DateTime.now();
      final thisWeekStart = now.subtract(Duration(days: now.weekday - 1));
      final lastWeekStart = thisWeekStart.subtract(Duration(days: 7));

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Determinar tipo de transacción
        TransactionType type = TransactionType.trip;
        if (data['type'] != null) {
          switch (data['type']) {
            case 'trip':
              type = TransactionType.trip;
              break;
            case 'withdrawal':
              type = TransactionType.withdrawal;
              break;
            case 'bonus':
              type = TransactionType.bonus;
              break;
            case 'refund':
              type = TransactionType.refund;
              break;
            case 'commission':
              type = TransactionType.commission;
              break;
          }
        }

        // Determinar estado
        TransactionStatus status = TransactionStatus.completed;
        if (data['status'] != null) {
          switch (data['status']) {
            case 'completed':
              status = TransactionStatus.completed;
              break;
            case 'pending':
              status = TransactionStatus.pending;
              break;
            case 'cancelled':
              status = TransactionStatus.cancelled;
              break;
          }
        }

        final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        final amount = (data['amount'] ?? 0.0).toDouble();

        // Crear transacción
        final transaction = Transaction(
          id: doc.id,
          type: type,
          date: date,
          amount: amount,
          status: status,
          passenger: data['passengerName'],
          pickup: data['pickupAddress'],
          destination: data['destinationAddress'],
          distance: data['distance']?.toDouble(),
          duration: data['duration'],
          paymentMethod: data['paymentMethod'],
          commission: data['commission']?.toDouble(),
          netEarnings: data['netEarnings']?.toDouble(),
          tip: data['tip']?.toDouble(),
          withdrawalMethod: data['withdrawalMethod'],
          bankAccount: data['bankAccount'],
          bonusType: data['bonusType'],
          description: data['description'],
          refundReason: data['refundReason'],
          originalTransaction: data['originalTransaction'],
          cancellationReason: data['cancellationReason'],
          cancellationFee: data['cancellationFee']?.toDouble(),
        );

        loadedTransactions.add(transaction);

        // Calcular resumen
        if (type == TransactionType.trip &&
            status == TransactionStatus.completed) {
          totalTrips++;
          totalEarnings += transaction.netEarnings ?? amount;
        } else if (type == TransactionType.withdrawal) {
          totalWithdrawals += amount.abs();
        } else if (type == TransactionType.bonus) {
          totalEarnings += amount;
        }

        // Calcular ganancias semanales
        if (date.isAfter(thisWeekStart)) {
          if (type == TransactionType.trip || type == TransactionType.bonus) {
            thisWeek += transaction.netEarnings ?? amount;
          }
        } else if (date.isAfter(lastWeekStart) &&
            date.isBefore(thisWeekStart)) {
          if (type == TransactionType.trip || type == TransactionType.bonus) {
            lastWeek += transaction.netEarnings ?? amount;
          }
        }
      }

      // Si no hay transacciones, mostrar lista vacía
      if (loadedTransactions.isEmpty) {
        setState(() {
          _transactions = [];
          _summary = {
            'totalEarnings': 0.0,
            'totalTrips': 0,
            'totalWithdrawals': 0.0,
            'pendingBalance': 0.0,
            'thisWeek': 0.0,
            'lastWeek': 0.0,
          };
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _transactions = loadedTransactions;
        _summary = {
          'totalEarnings': totalEarnings,
          'totalTrips': totalTrips,
          'totalWithdrawals': totalWithdrawals,
          'pendingBalance': totalEarnings - totalWithdrawals,
          'thisWeek': thisWeek,
          'lastWeek': lastWeek,
        };
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('cargando transacciones', e);
      setState(() {
        _errorMessage = 'Error al cargar las transacciones: $e';
        _isLoading = false;
      });
    }
  }

  List<Transaction> get _filteredTransactions {
    var filtered = _transactions.where((transaction) {
      // Filter by type
      if (_selectedFilter != 'all') {
        if (_selectedFilter == 'trips' &&
            transaction.type != TransactionType.trip) {
          return false;
        }
        if (_selectedFilter == 'withdrawals' &&
            transaction.type != TransactionType.withdrawal) {
          return false;
        }
        if (_selectedFilter == 'bonuses' &&
            transaction.type != TransactionType.bonus) {
          return false;
        }
        if (_selectedFilter == 'refunds' &&
            transaction.type != TransactionType.refund) {
          return false;
        }
      }

      // Filter by date range
      if (_selectedDateRange != null) {
        if (transaction.date.isBefore(_selectedDateRange!.start) ||
            transaction.date.isAfter(_selectedDateRange!.end)) {
          return false;
        }
      }

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return transaction.id.toLowerCase().contains(query) ||
            (transaction.passenger?.toLowerCase().contains(query) ?? false) ||
            (transaction.pickup?.toLowerCase().contains(query) ?? false) ||
            (transaction.destination?.toLowerCase().contains(query) ?? false);
      }

      return true;
    }).toList();

    // Sort by date (newest first)
    filtered.sort((a, b) => b.date.compareTo(a.date));

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: ModernTheme.oasisGreen,
        elevation: 0,
        title: Text(
          'Historial de Transacciones',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.download, color: Colors.white),
            onPressed: _exportTransactions,
          ),
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.white),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadTransactionsFromFirebase,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: ModernTheme.oasisGreen,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando transacciones...',
                    style: TextStyle(color: ModernTheme.textSecondary),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: ModernTheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error al cargar transacciones',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: ModernTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadTransactionsFromFirebase,
                        icon: Icon(Icons.refresh),
                        label: Text('Reintentar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ModernTheme.oasisGreen,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Summary cards
                    _buildSummarySection(),

                    // Search bar
                    _buildSearchBar(),

                    // Filter chips
                    _buildFilterChips(),

                    // Transactions list
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _fadeAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _fadeAnimation.value,
                            child: _buildTransactionsList(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSummarySection() {
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.all(16),
        children: [
          _buildSummaryCard(
            'Balance Pendiente',
            'S/ ${_summary['pendingBalance'].toStringAsFixed(2)}',
            Icons.account_balance_wallet,
            ModernTheme.oasisGreen,
            true,
          ),
          _buildSummaryCard(
            'Total Ganado',
            'S/ ${_summary['totalEarnings'].toStringAsFixed(2)}',
            Icons.attach_money,
            ModernTheme.primaryBlue,
            false,
          ),
          _buildSummaryCard(
            'Viajes',
            '${_summary['totalTrips']}',
            Icons.directions_car,
            Colors.orange,
            false,
          ),
          _buildSummaryCard(
            'Retiros',
            'S/ ${_summary['totalWithdrawals'].toStringAsFixed(2)}',
            Icons.money_off,
            Colors.purple,
            false,
          ),
          _buildSummaryCard(
            'Esta Semana',
            'S/ ${_summary['thisWeek'].toStringAsFixed(2)}',
            Icons.trending_up,
            ModernTheme.success,
            false,
          ),
          _buildSummaryCard(
            'Semana Pasada',
            'S/ ${_summary['lastWeek'].toStringAsFixed(2)}',
            Icons.history,
            ModernTheme.info,
            false,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color, bool highlight) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(50 * (1 - _slideAnimation.value), 0),
          child: Container(
            width: 140,
            margin: EdgeInsets.only(right: 12),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: highlight ? color : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: ModernTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: highlight ? Colors.white : color,
                  size: 28,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color:
                            highlight ? Colors.white : ModernTheme.textPrimary,
                      ),
                    ),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        color: highlight
                            ? Colors.white70
                            : ModernTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Buscar por ID, pasajero o dirección...',
            border: InputBorder.none,
            icon: Icon(Icons.search, color: ModernTheme.textSecondary),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 20),
                    onPressed: () {
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value);
          },
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _buildFilterChip('Todos', 'all', Icons.list),
          _buildFilterChip('Viajes', 'trips', Icons.directions_car),
          _buildFilterChip('Retiros', 'withdrawals', Icons.money_off),
          _buildFilterChip('Bonos', 'bonuses', Icons.card_giftcard),
          _buildFilterChip('Reembolsos', 'refunds', Icons.replay),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _selectedFilter == value;

    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : ModernTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        onSelected: (selected) {
          setState(() => _selectedFilter = value);
        },
        selectedColor: ModernTheme.oasisGreen,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : ModernTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    if (_filteredTransactions.isEmpty) {
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
            const SizedBox(height: 8),
            Text(
              _selectedFilter != 'all'
                  ? 'Intenta cambiar los filtros'
                  : 'Completa viajes para ver transacciones',
              style: TextStyle(
                color: ModernTheme.textSecondary.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Group transactions by date
    Map<String, List<Transaction>> groupedTransactions = {};
    for (var transaction in _filteredTransactions) {
      final dateKey = _getDateKey(transaction.date);
      if (!groupedTransactions.containsKey(dateKey)) {
        groupedTransactions[dateKey] = [];
      }
      groupedTransactions[dateKey]!.add(transaction);
    }

    return RefreshIndicator(
      color: ModernTheme.oasisGreen,
      onRefresh: _loadTransactionsFromFirebase,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: groupedTransactions.length,
        itemBuilder: (context, index) {
          final dateKey = groupedTransactions.keys.elementAt(index);
          final transactions = groupedTransactions[dateKey]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  dateKey,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.textSecondary,
                  ),
                ),
              ),
              // Transactions for this date
              ...transactions
                  .map((transaction) => _buildTransactionCard(transaction)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
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
              // Transaction icon
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getTransactionColor(transaction.type)
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getTransactionIcon(transaction.type),
                  color: _getTransactionColor(transaction.type),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // Transaction details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTransactionTitle(transaction),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getTransactionSubtitle(transaction),
                      style: TextStyle(
                        color: ModernTheme.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (transaction.status == TransactionStatus.cancelled)
                      Container(
                        margin: EdgeInsets.only(top: 4),
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: ModernTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Cancelado',
                          style: TextStyle(
                            color: ModernTheme.error,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${transaction.amount >= 0 ? '+' : ''}S/ ${transaction.amount.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: transaction.amount >= 0
                          ? ModernTheme.success
                          : ModernTheme.error,
                    ),
                  ),
                  if (transaction.netEarnings != null)
                    Text(
                      'Neto: S/ ${transaction.netEarnings!.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: ModernTheme.textSecondary,
                      ),
                    ),
                  Text(
                    _formatTime(transaction.date),
                    style: TextStyle(
                      fontSize: 11,
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

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Hoy';
    } else if (dateOnly == yesterday) {
      return 'Ayer';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  IconData _getTransactionIcon(TransactionType type) {
    switch (type) {
      case TransactionType.trip:
        return Icons.directions_car;
      case TransactionType.withdrawal:
        return Icons.money_off;
      case TransactionType.bonus:
        return Icons.card_giftcard;
      case TransactionType.refund:
        return Icons.replay;
      case TransactionType.commission:
        return Icons.percent;
    }
  }

  Color _getTransactionColor(TransactionType type) {
    switch (type) {
      case TransactionType.trip:
        return ModernTheme.primaryBlue;
      case TransactionType.withdrawal:
        return Colors.purple;
      case TransactionType.bonus:
        return ModernTheme.oasisGreen;
      case TransactionType.refund:
        return ModernTheme.error;
      case TransactionType.commission:
        return Colors.orange;
    }
  }

  String _getTransactionTitle(Transaction transaction) {
    switch (transaction.type) {
      case TransactionType.trip:
        return transaction.passenger ?? 'Viaje';
      case TransactionType.withdrawal:
        return 'Retiro';
      case TransactionType.bonus:
        return transaction.bonusType ?? 'Bono';
      case TransactionType.refund:
        return 'Reembolso';
      case TransactionType.commission:
        return 'Comisión';
    }
  }

  String _getTransactionSubtitle(Transaction transaction) {
    switch (transaction.type) {
      case TransactionType.trip:
        if (transaction.status == TransactionStatus.cancelled) {
          return transaction.cancellationReason ?? 'Viaje cancelado';
        }
        if (transaction.pickup != null && transaction.destination != null) {
          return '${transaction.pickup} → ${transaction.destination}';
        }
        return 'Viaje completado';
      case TransactionType.withdrawal:
        return transaction.withdrawalMethod ?? 'Retiro de fondos';
      case TransactionType.bonus:
        return transaction.description ?? '';
      case TransactionType.refund:
        return transaction.refundReason ?? '';
      case TransactionType.commission:
        return 'Comisión de plataforma';
    }
  }

  void _showTransactionDetails(Transaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getTransactionColor(transaction.type)
                          .withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getTransactionIcon(transaction.type),
                      color: _getTransactionColor(transaction.type),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getTransactionTitle(transaction),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'ID: ${transaction.id}',
                          style: TextStyle(
                            color: ModernTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${transaction.amount >= 0 ? '+' : ''}S/ ${transaction.amount.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: transaction.amount >= 0
                          ? ModernTheme.success
                          : ModernTheme.error,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(),

            // Details
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (transaction.type == TransactionType.trip) ...[
                      _buildDetailSection('Información del Viaje', [
                        _buildDetailRow(
                            'Pasajero', transaction.passenger ?? ''),
                        _buildDetailRow('Recogida', transaction.pickup ?? ''),
                        _buildDetailRow(
                            'Destino', transaction.destination ?? ''),
                        _buildDetailRow(
                            'Distancia', '${transaction.distance ?? 0} km'),
                        _buildDetailRow(
                            'Duración', '${transaction.duration ?? 0} min'),
                      ]),
                      const SizedBox(height: 20),
                      _buildDetailSection('Detalles Financieros', [
                        _buildDetailRow('Tarifa',
                            'S/ ${transaction.amount.toStringAsFixed(2)}'),
                        if (transaction.tip != null)
                          _buildDetailRow('Propina',
                              'S/ ${transaction.tip!.toStringAsFixed(2)}'),
                        _buildDetailRow('Comisión (-20%)',
                            'S/ ${(transaction.commission ?? 0).toStringAsFixed(2)}'),
                        const Divider(),
                        _buildDetailRow('Ganancia Neta',
                            'S/ ${(transaction.netEarnings ?? 0).toStringAsFixed(2)}',
                            bold: true),
                      ]),
                      const SizedBox(height: 20),
                      _buildDetailSection('Pago', [
                        _buildDetailRow(
                            'Método', transaction.paymentMethod ?? ''),
                        _buildDetailRow(
                            'Estado',
                            transaction.status == TransactionStatus.completed
                                ? 'Completado'
                                : 'Cancelado'),
                      ]),
                    ],
                    if (transaction.type == TransactionType.withdrawal) ...[
                      _buildDetailSection('Detalles del Retiro', [
                        _buildDetailRow('Monto',
                            'S/ ${transaction.amount.abs().toStringAsFixed(2)}'),
                        _buildDetailRow(
                            'Método', transaction.withdrawalMethod ?? ''),
                        _buildDetailRow(
                            'Cuenta', transaction.bankAccount ?? ''),
                        _buildDetailRow('Estado', 'Completado'),
                      ]),
                    ],
                    if (transaction.type == TransactionType.bonus) ...[
                      _buildDetailSection('Detalles del Bono', [
                        _buildDetailRow('Tipo', transaction.bonusType ?? ''),
                        _buildDetailRow(
                            'Descripción', transaction.description ?? ''),
                        _buildDetailRow('Monto',
                            'S/ ${transaction.amount.toStringAsFixed(2)}'),
                      ]),
                    ],
                    const SizedBox(height: 20),
                    _buildDetailSection('Información General', [
                      _buildDetailRow('Fecha',
                          '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}'),
                      _buildDetailRow('Hora', _formatTime(transaction.date)),
                      _buildDetailRow('ID Transacción', transaction.id),
                    ]),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _shareTransaction(transaction);
                      },
                      icon: Icon(Icons.share),
                      label: Text('Compartir'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ModernTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _reportIssue(transaction);
                      },
                      icon: Icon(Icons.report),
                      label: Text('Reportar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ModernTheme.error,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: ModernTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ModernTheme.backgroundLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: ModernTheme.textSecondary,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: bold ? ModernTheme.oasisGreen : ModernTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filtrar Transacciones'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Date range picker button
            ListTile(
              leading: Icon(Icons.date_range),
              title: Text(_selectedDateRange != null
                  ? '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}'
                  : 'Seleccionar rango de fechas'),
              onTap: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime.now().subtract(Duration(days: 365)),
                  lastDate: DateTime.now(),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: ModernTheme.oasisGreen,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (range != null) {
                  setState(() => _selectedDateRange = range);
                }
              },
            ),
            if (_selectedDateRange != null)
              TextButton(
                onPressed: () {
                  setState(() => _selectedDateRange = null);
                },
                child: Text('Limpiar fechas'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.oasisGreen,
            ),
            child: Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  void _exportTransactions() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exportando transacciones...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }

  void _shareTransaction(Transaction transaction) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Compartiendo transacción ${transaction.id}'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }

  void _reportIssue(Transaction transaction) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reportando problema con ${transaction.id}'),
        backgroundColor: ModernTheme.warning,
      ),
    );
  }
}

// Transaction model
class Transaction {
  final String id;
  final TransactionType type;
  final DateTime date;
  final double amount;
  final TransactionStatus status;

  // Trip details
  final String? passenger;
  final String? pickup;
  final String? destination;
  final double? distance;
  final int? duration;
  final String? paymentMethod;
  final double? commission;
  final double? netEarnings;
  final double? tip;

  // Withdrawal details
  final String? withdrawalMethod;
  final String? bankAccount;

  // Bonus details
  final String? bonusType;
  final String? description;

  // Refund details
  final String? refundReason;
  final String? originalTransaction;

  // Cancellation details
  final String? cancellationReason;
  final double? cancellationFee;

  Transaction({
    required this.id,
    required this.type,
    required this.date,
    required this.amount,
    required this.status,
    this.passenger,
    this.pickup,
    this.destination,
    this.distance,
    this.duration,
    this.paymentMethod,
    this.commission,
    this.netEarnings,
    this.tip,
    this.withdrawalMethod,
    this.bankAccount,
    this.bonusType,
    this.description,
    this.refundReason,
    this.originalTransaction,
    this.cancellationReason,
    this.cancellationFee,
  });
}

enum TransactionType { trip, withdrawal, bonus, refund, commission }

enum TransactionStatus { completed, pending, cancelled }
