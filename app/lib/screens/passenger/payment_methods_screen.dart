import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/widgets/oasis_button.dart';
import '../../widgets/common/oasis_app_bar.dart';
import '../../services/security_integration_service.dart';
import '../../utils/app_logger.dart';

enum CardType { visa, mastercard, amex, discover, other }

enum PaymentMethodType { card, cash, wallet, paypal }

class PaymentMethod {
  final String id;
  final PaymentMethodType type;
  final String name;
  final String? cardNumber;
  final String? cardHolder;
  final String? expiryDate;
  final CardType? cardType;
  final bool isDefault;
  final String? walletBalance;
  final IconData icon;
  final Color color;

  PaymentMethod({
    required this.id,
    required this.type,
    required this.name,
    this.cardNumber,
    this.cardHolder,
    this.expiryDate,
    this.cardType,
    required this.isDefault,
    this.walletBalance,
    required this.icon,
    required this.color,
  });
}

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  PaymentMethodsScreenState createState() => PaymentMethodsScreenState();
}

class PaymentMethodsScreenState extends State<PaymentMethodsScreen>
    with TickerProviderStateMixin {
  late AnimationController _listAnimationController;
  late AnimationController _cardFlipController;
  late AnimationController _fabAnimationController;

  String _defaultMethodId = 'cash';
  bool _isLoading = true;
  double _walletBalance = 0.0;

  List<PaymentMethod> _paymentMethods = [];
  List<Map<String, dynamic>> _transactionHistory = [];

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('PaymentMethodsScreen', 'initState');

    _listAnimationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _cardFlipController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _fabAnimationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    _loadPaymentMethods();
    _loadTransactionHistory();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Cargar métodos de pago desde Firebase
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('payment_methods')
            .orderBy('createdAt', descending: true)
            .get();

        // Cargar balance de billetera
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        setState(() {
          _walletBalance = (userDoc.data()?['walletBalance'] ?? 0.0).toDouble();

          _paymentMethods = snapshot.docs.map((doc) {
            final data = doc.data();
            return PaymentMethod(
              id: doc.id,
              type: _getPaymentType(data['type'] ?? 'cash'),
              name: data['name'] ?? '',
              cardNumber: data['cardNumber'],
              cardHolder: data['cardHolder'],
              expiryDate: data['expiryDate'],
              cardType: data['cardType'] != null
                  ? _getCardType(data['cardType'])
                  : null,
              isDefault: data['isDefault'] ?? false,
              icon: _getPaymentIcon(data['type'] ?? 'cash'),
              color: _getPaymentColor(data['type'] ?? 'cash'),
              walletBalance: null,
            );
          }).toList();

          // Agregar método de efectivo si no existe
          if (!_paymentMethods.any((m) => m.type == PaymentMethodType.cash)) {
            _paymentMethods.add(PaymentMethod(
              id: 'cash',
              type: PaymentMethodType.cash,
              name: 'Efectivo',
              isDefault: _paymentMethods.isEmpty,
              icon: Icons.money,
              color: ModernTheme.success,
              walletBalance: null,
            ));
          }

          // Agregar billetera Oasis
          _paymentMethods.insert(
              0,
              PaymentMethod(
                id: 'wallet',
                type: PaymentMethodType.wallet,
                name: 'Billetera Oasis',
                walletBalance: _walletBalance.toStringAsFixed(2),
                isDefault: false,
                icon: Icons.account_balance_wallet,
                color: ModernTheme.oasisGreen,
              ));

          // Establecer método predeterminado
          final defaultMethod = _paymentMethods.firstWhere(
            (m) => m.isDefault,
            orElse: () => _paymentMethods.first,
          );
          _defaultMethodId = defaultMethod.id;
        });
      }
    } catch (e) {
      AppLogger.error('cargando métodos de pago', e);
      // Por defecto, solo efectivo
      setState(() {
        _paymentMethods = [
          PaymentMethod(
            id: 'cash',
            type: PaymentMethodType.cash,
            name: 'Efectivo',
            isDefault: true,
            icon: Icons.money,
            color: ModernTheme.success,
            walletBalance: null,
          ),
        ];
        _defaultMethodId = 'cash';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTransactionHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .orderBy('date', descending: true)
            .limit(20)
            .get();

        setState(() {
          _transactionHistory = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'date': (data['date'] as Timestamp).toDate(),
              'amount': (data['amount'] ?? 0.0).toDouble(),
              'method': data['method'] ?? 'Efectivo',
              'status': data['status'] ?? 'completed',
              'tripId': data['tripId'] ?? '',
            };
          }).toList();
        });
      }
    } catch (e) {
      AppLogger.error('cargando historial', e);
    }
  }

  PaymentMethodType _getPaymentType(String type) {
    switch (type) {
      case 'card':
        return PaymentMethodType.card;
      case 'wallet':
        return PaymentMethodType.wallet;
      case 'paypal':
        return PaymentMethodType.paypal;
      default:
        return PaymentMethodType.cash;
    }
  }

  CardType _getCardType(String type) {
    switch (type) {
      case 'visa':
        return CardType.visa;
      case 'mastercard':
        return CardType.mastercard;
      case 'amex':
        return CardType.amex;
      case 'discover':
        return CardType.discover;
      default:
        return CardType.other;
    }
  }

  IconData _getPaymentIcon(String type) {
    switch (type) {
      case 'card':
        return Icons.credit_card;
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'paypal':
        return Icons.payment;
      default:
        return Icons.money;
    }
  }

  Color _getPaymentColor(String type) {
    switch (type) {
      case 'card':
        return Colors.blue;
      case 'wallet':
        return ModernTheme.oasisGreen;
      case 'paypal':
        return Colors.indigo;
      default:
        return ModernTheme.success;
    }
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    _cardFlipController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: ModernTheme.backgroundLight,
        appBar: OasisAppBar.standard(
          title: 'Métodos de Pago',
          showBackButton: true,
        ),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.oasisGreen),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: ModernTheme.backgroundLight,
        appBar: OasisAppBar.standard(
          title: 'Métodos de Pago',
          showBackButton: true,
          actions: [
            IconButton(
              icon: Icon(Icons.help_outline, color: Colors.white),
              onPressed: _showHelp,
            ),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Métodos de Pago'),
              Tab(text: 'Historial'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPaymentMethodsTab(),
            _buildHistoryTab(),
          ],
        ),
        floatingActionButton: AnimatedBuilder(
          animation: _fabAnimationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _fabAnimationController.value,
              child: OasisButton.primary(
                text: 'Agregar Método',
                icon: Icons.add,
                onPressed: _addPaymentMethod,
                size: OasisButtonSize.large,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPaymentMethodsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance card for wallet
          _buildWalletBalance(),

          const SizedBox(height: 24),

          // Payment methods section
          Text(
            'Métodos Guardados',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ModernTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Payment methods list
          ..._paymentMethods.asMap().entries.map((entry) {
            final index = entry.key;
            final method = entry.value;
            final delay = index * 0.1;

            return AnimatedBuilder(
              animation: _listAnimationController,
              builder: (context, child) {
                final animation = Tween<double>(
                  begin: 0,
                  end: 1,
                ).animate(
                  CurvedAnimation(
                    parent: _listAnimationController,
                    curve: Interval(
                      delay,
                      delay + 0.5,
                      curve: Curves.easeOutBack,
                    ),
                  ),
                );

                return Transform.translate(
                  offset: Offset(50 * (1 - animation.value), 0),
                  child: Opacity(
                    opacity: animation.value,
                    child: method.type == PaymentMethodType.card
                        ? _buildCreditCard(method)
                        : _buildPaymentMethodCard(method),
                  ),
                );
              },
            );
          }),

          const SizedBox(height: 24),

          // Security info
          _buildSecurityInfo(),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _transactionHistory.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHistorySummary();
        }

        final transaction = _transactionHistory[index - 1];
        return _buildTransactionCard(transaction);
      },
    );
  }

  Widget _buildWalletBalance() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: ModernTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ModernTheme.oasisGreen.withValues(alpha: 0.3),
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
                    'Billetera Oasis',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  AppSpacing.verticalSpaceXS,
                  Text(
                    'S/ ${_walletBalance.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
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
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OasisButton.secondary(
                  text: 'Recargar',
                  icon: Icons.add,
                  onPressed: _rechargeWallet,
                ),
              ),
              AppSpacing.horizontalSpaceSM,
              Expanded(
                child: OasisButton.outlined(
                  text: 'Historial',
                  icon: Icons.history,
                  onPressed: _viewWalletHistory,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCard(PaymentMethod method) {
    final isDefault = method.id == _defaultMethodId;

    return GestureDetector(
      onTap: () => _showCardDetails(method),
      onLongPress: () => _setDefaultMethod(method),
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        height: 200,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _getCardGradient(method.cardType!),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: method.color.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Card pattern
            Positioned.fill(
              child: CustomPaint(
                painter: CardPatternPainter(),
              ),
            ),

            // Card content
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _getCardLogo(method.cardType!),
                      if (isDefault)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'PREDETERMINADO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method.cardNumber ?? '',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          letterSpacing: 2,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TITULAR',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                method.cardHolder ?? '',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'VENCE',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                method.expiryDate ?? '',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Delete button
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white54, size: 20),
                onPressed: () => _deletePaymentMethod(method),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard(PaymentMethod method) {
    final isDefault = method.id == _defaultMethodId;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
        border: Border.all(
          color: isDefault ? ModernTheme.oasisGreen : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: method.color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            method.icon,
            color: method.color,
            size: 24,
          ),
        ),
        title: Text(
          method.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: ModernTheme.textPrimary,
          ),
        ),
        subtitle: method.walletBalance != null
            ? Text('Saldo: S/ ${method.walletBalance}')
            : Text(_getMethodDescription(method.type)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDefault)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Predeterminado',
                  style: TextStyle(
                    color: ModernTheme.oasisGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert),
              onSelected: (value) => _handleMethodAction(method, value),
              itemBuilder: (context) => [
                if (!isDefault)
                  PopupMenuItem(
                    value: 'default',
                    child: Row(
                      children: [
                        Icon(Icons.star, size: 20),
                        AppSpacing.horizontalSpaceSM,
                        Text('Hacer predeterminado'),
                      ],
                    ),
                  ),
                if (method.type != PaymentMethodType.cash)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: ModernTheme.error),
                        AppSpacing.horizontalSpaceSM,
                        Text('Eliminar',
                            style: TextStyle(color: ModernTheme.error)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        onTap: () {
          if (!isDefault) {
            _setDefaultMethod(method);
          }
        },
      ),
    );
  }

  Widget _buildHistorySummary() {
    final totalSpent = _transactionHistory.fold<double>(
        0, (total, t) => total + (t['amount'] as double));
    final successfulTransactions =
        _transactionHistory.where((t) => t['status'] == 'completed').length;

    return Container(
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ModernTheme.primaryBlue,
            ModernTheme.primaryBlue.withValues(alpha: 0.8)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            'Resumen del Mes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                'Total Gastado',
                'S/ ${totalSpent.toStringAsFixed(2)}',
                Icons.attach_money,
              ),
              _buildSummaryItem(
                'Transacciones',
                _transactionHistory.length.toString(),
                Icons.receipt,
              ),
              _buildSummaryItem(
                'Exitosas',
                '$successfulTransactions/${_transactionHistory.length}',
                Icons.check_circle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        AppSpacing.verticalSpaceXS,
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

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final isSuccess = transaction['status'] == 'completed';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isSuccess ? ModernTheme.success : ModernTheme.error)
                .withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: isSuccess ? ModernTheme.success : ModernTheme.error,
          ),
        ),
        title: Text(
          'Viaje ${transaction['tripId']}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(transaction['method']),
            Text(
              _formatDate(transaction['date']),
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'S/ ${transaction['amount'].toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: ModernTheme.textPrimary,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (isSuccess ? ModernTheme.success : ModernTheme.error)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isSuccess ? 'Exitoso' : 'Fallido',
                style: TextStyle(
                  color: isSuccess ? ModernTheme.success : ModernTheme.error,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        onTap: () => _showTransactionDetails(transaction),
      ),
    );
  }

  Widget _buildSecurityInfo() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ModernTheme.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ModernTheme.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.security, color: ModernTheme.info),
          AppSpacing.horizontalSpaceSM,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tus pagos están protegidos',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.info,
                  ),
                ),
                Text(
                  'Utilizamos encriptación de grado bancario para proteger tu información.',
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
    );
  }

  List<Color> _getCardGradient(CardType type) {
    switch (type) {
      case CardType.visa:
        return [Colors.blue.shade600, Colors.blue.shade400];
      case CardType.mastercard:
        return [Colors.orange.shade600, Colors.orange.shade400];
      case CardType.amex:
        return [Colors.green.shade600, Colors.green.shade400];
      case CardType.discover:
        return [Colors.purple.shade600, Colors.purple.shade400];
      default:
        return [Colors.grey.shade600, Colors.grey.shade400];
    }
  }

  Widget _getCardLogo(CardType type) {
    String logoText;
    switch (type) {
      case CardType.visa:
        logoText = 'VISA';
        break;
      case CardType.mastercard:
        logoText = 'MasterCard';
        break;
      case CardType.amex:
        logoText = 'AMEX';
        break;
      case CardType.discover:
        logoText = 'Discover';
        break;
      default:
        logoText = 'CARD';
    }

    return Text(
      logoText,
      style: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  String _getMethodDescription(PaymentMethodType type) {
    switch (type) {
      case PaymentMethodType.cash:
        return 'Pago al finalizar el viaje';
      case PaymentMethodType.wallet:
        return 'Pago con saldo de billetera';
      case PaymentMethodType.paypal:
        return 'Pago seguro con PayPal';
      default:
        return 'Método de pago';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inHours < 24) {
      return 'Hoy, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Ayer, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _setDefaultMethod(PaymentMethod method) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Actualizar en Firebase
        final batch = FirebaseFirestore.instance.batch();

        // Quitar default de todos
        final methods = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('payment_methods')
            .get();

        for (var doc in methods.docs) {
          batch.update(doc.reference, {'isDefault': false});
        }

        // Establecer nuevo default
        if (method.id != 'cash' && method.id != 'wallet') {
          batch.update(
            FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('payment_methods')
                .doc(method.id),
            {'isDefault': true},
          );
        }

        await batch.commit();

        // Actualizar preferencia de usuario
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'defaultPaymentMethod': method.id});
      }

      setState(() {
        _defaultMethodId = method.id;
        // Actualizar estado local
        for (int i = 0; i < _paymentMethods.length; i++) {
          _paymentMethods[i] = PaymentMethod(
            id: _paymentMethods[i].id,
            type: _paymentMethods[i].type,
            name: _paymentMethods[i].name,
            cardNumber: _paymentMethods[i].cardNumber,
            cardHolder: _paymentMethods[i].cardHolder,
            expiryDate: _paymentMethods[i].expiryDate,
            cardType: _paymentMethods[i].cardType,
            isDefault: _paymentMethods[i].id == method.id,
            icon: _paymentMethods[i].icon,
            color: _paymentMethods[i].color,
            walletBalance: _paymentMethods[i].walletBalance,
          );
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${method.name} es ahora tu método predeterminado'),
          backgroundColor: ModernTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar método predeterminado'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  void _deletePaymentMethod(PaymentMethod method) {
    if (method.type == PaymentMethodType.cash ||
        method.type == PaymentMethodType.wallet) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se puede eliminar este método de pago'),
          backgroundColor: ModernTheme.warning,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('Eliminar método de pago'),
        content: Text('¿Estás seguro de que deseas eliminar ${method.name}?'),
        actions: [
          OasisButton.text(
            text: 'Cancelar',
            onPressed: () => Navigator.pop(context),
          ),
          OasisButton.danger(
            text: 'Eliminar',
            onPressed: () async {
              Navigator.pop(context);

              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  // Eliminar de Firebase
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('payment_methods')
                      .doc(method.id)
                      .delete();

                  setState(() {
                    _paymentMethods.removeWhere((m) => m.id == method.id);
                    if (_defaultMethodId == method.id &&
                        _paymentMethods.isNotEmpty) {
                      _defaultMethodId = _paymentMethods.first.id;
                    }
                  });

                  _showSnackBar(
                      'Método de pago eliminado', ModernTheme.success);
                }
              } catch (e) {
                _showSnackBar(
                    'Error al eliminar método de pago', ModernTheme.error);
              }
            },
          ),
        ],
      ),
    );
  }

  void _handleMethodAction(PaymentMethod method, String action) {
    switch (action) {
      case 'default':
        _setDefaultMethod(method);
        break;
      case 'delete':
        _deletePaymentMethod(method);
        break;
    }
  }

  void _addPaymentMethod() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: AddPaymentMethodSheet(
              scrollController: scrollController,
              onMethodAdded: (method) {
                setState(() {
                  _paymentMethods.add(method);
                });
              },
            ),
          );
        },
      ),
    );
  }

  void _showCardDetails(PaymentMethod method) {
    _cardFlipController.forward().then((_) {
      Future.delayed(Duration(seconds: 2), () {
        _cardFlipController.reverse();
      });
    });
  }

  void _rechargeWallet() {
    final TextEditingController amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Recargar Billetera',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Amount chips
            Wrap(
              spacing: 12,
              children: [10, 20, 50, 100, 200].map((amount) {
                return ChoiceChip(
                  label: Text('S/ $amount'),
                  selected: false,
                  onSelected: (selected) async {
                    Navigator.pop(context);
                    await _processRecharge(amount.toDouble());
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: 'Monto personalizado',
                prefixText: 'S/ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 24),

            OasisButton.primary(
              text: 'Recargar',
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount > 0) {
                  Navigator.pop(context);
                  await _processRecharge(amount);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ingrese un monto válido'),
                      backgroundColor: ModernTheme.error,
                    ),
                  );
                }
              },
              size: OasisButtonSize.large,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processRecharge(double amount) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Actualizar balance en Firebase
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'walletBalance': FieldValue.increment(amount),
        });

        // Registrar transacción
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .add({
          'amount': amount,
          'type': 'recharge',
          'method': 'Recarga de billetera',
          'status': 'completed',
          'date': FieldValue.serverTimestamp(),
          'description': 'Recarga de billetera Oasis',
        });

        // Actualizar UI
        setState(() {
          _walletBalance += amount;
          // Actualizar balance en el método de pago de billetera
          final walletIndex =
              _paymentMethods.indexWhere((m) => m.id == 'wallet');
          if (walletIndex != -1) {
            _paymentMethods[walletIndex] = PaymentMethod(
              id: 'wallet',
              type: PaymentMethodType.wallet,
              name: 'Billetera Oasis',
              walletBalance: _walletBalance.toStringAsFixed(2),
              isDefault: _paymentMethods[walletIndex].isDefault,
              icon: Icons.account_balance_wallet,
              color: ModernTheme.oasisGreen,
            );
          }
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recarga de S/ ${amount.toStringAsFixed(2)} exitosa'),
            backgroundColor: ModernTheme.success,
          ),
        );

        // Recargar historial de transacciones
        _loadTransactionHistory();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al recargar billetera'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  void _viewWalletHistory() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cargando historial de billetera...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }

  void _showTransactionDetails(Map<String, dynamic> transaction) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Detalles de Transacción',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildDetailRow('ID Transacción', transaction['id']),
            _buildDetailRow('Viaje', transaction['tripId']),
            _buildDetailRow('Fecha', _formatDate(transaction['date'])),
            _buildDetailRow('Método', transaction['method']),
            _buildDetailRow(
                'Monto', 'S/ ${transaction['amount'].toStringAsFixed(2)}'),
            _buildDetailRow(
              'Estado',
              transaction['status'] == 'completed' ? 'Exitoso' : 'Fallido',
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OasisButton.outlined(
                    text: 'Descargar',
                    icon: Icons.download,
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Descargando recibo...'),
                          backgroundColor: ModernTheme.info,
                        ),
                      );
                    },
                  ),
                ),
                AppSpacing.horizontalSpaceSM,
                Expanded(
                  child: OasisButton.primary(
                    text: 'Ayuda',
                    icon: Icons.help,
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Abriendo soporte...'),
                          backgroundColor: ModernTheme.oasisGreen,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: ModernTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.help_outline, color: ModernTheme.oasisGreen),
            const SizedBox(width: 8),
            Text('Ayuda'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpItem(
              '• Para establecer un método predeterminado, mantén presionado sobre él.',
            ),
            _buildHelpItem(
              '• Puedes eliminar métodos de pago deslizando hacia la izquierda.',
            ),
            _buildHelpItem(
              '• Tu información está encriptada y segura.',
            ),
            _buildHelpItem(
              '• La billetera Oasis te permite pagar sin tarjetas.',
            ),
          ],
        ),
        actions: [
          OasisButton.text(
            text: 'Entendido',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 14),
      ),
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// Add payment method sheet
class AddPaymentMethodSheet extends StatefulWidget {
  final ScrollController scrollController;
  final Function(PaymentMethod) onMethodAdded;

  const AddPaymentMethodSheet({
    super.key,
    required this.scrollController,
    required this.onMethodAdded,
  });

  @override
  AddPaymentMethodSheetState createState() => AddPaymentMethodSheetState();
}

class AddPaymentMethodSheetState extends State<AddPaymentMethodSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  final CardType _selectedCardType = CardType.visa;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: ListView(
          controller: widget.scrollController,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Agregar Tarjeta',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SecurityIntegrationService.buildSecureTextField(
              context: context,
              controller: _cardNumberController,
              label: 'Número de tarjeta',
              fieldType: 'creditcard',
              prefixIcon: Icon(Icons.credit_card),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            SecurityIntegrationService.buildSecureTextField(
              context: context,
              controller: _cardHolderController,
              label: 'Titular de la tarjeta',
              fieldType: 'fullname',
              prefixIcon: Icon(Icons.person),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SecurityIntegrationService.buildSecureTextField(
                    context: context,
                    controller: _expiryController,
                    label: 'MM/AA',
                    fieldType: 'cardexpiry',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                ),
                AppSpacing.horizontalSpaceMD,
                Expanded(
                  child: SecurityIntegrationService.buildSecureTextField(
                    context: context,
                    controller: _cvvController,
                    label: 'CVV',
                    fieldType: 'cvv',
                    prefixIcon: Icon(Icons.lock),
                    obscureText: true,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            OasisButton.primary(
              text: 'Agregar Tarjeta',
              onPressed: _addCard,
              size: OasisButtonSize.large,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Tus datos están seguros y encriptados',
                style: TextStyle(
                  color: ModernTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addCard() async {
    if (_formKey.currentState!.validate()) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Guardar en Firebase
          final docRef = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('payment_methods')
              .add({
            'type': 'card',
            'name':
                '${_selectedCardType.name.toUpperCase()} •••• ${_cardNumberController.text.substring(_cardNumberController.text.length - 4)}',
            'cardNumber': _cardNumberController.text,
            'cardHolder': _cardHolderController.text.toUpperCase(),
            'expiryDate': _expiryController.text,
            'cardType': _selectedCardType.name,
            'isDefault': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

          final newMethod = PaymentMethod(
            id: docRef.id,
            type: PaymentMethodType.card,
            name:
                '${_selectedCardType.name.toUpperCase()} •••• ${_cardNumberController.text.substring(_cardNumberController.text.length - 4)}',
            cardNumber: _cardNumberController.text,
            cardHolder: _cardHolderController.text.toUpperCase(),
            expiryDate: _expiryController.text,
            cardType: _selectedCardType,
            isDefault: false,
            icon: Icons.credit_card,
            color: Colors.blue,
          );

          widget.onMethodAdded(newMethod);
          if (!mounted) return;
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tarjeta agregada exitosamente'),
              backgroundColor: ModernTheme.success,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al agregar tarjeta'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }
}

// Custom painter for card pattern
class CardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw pattern
    for (int i = 0; i < 5; i++) {
      final y = size.height * (i + 1) / 6;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    for (int i = 0; i < 8; i++) {
      final x = size.width * (i + 1) / 9;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
