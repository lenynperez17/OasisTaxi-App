// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import '../../core/theme/modern_theme.dart';

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
  _PaymentMethodsScreenState createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen>
    with TickerProviderStateMixin {
  late AnimationController _listAnimationController;
  late AnimationController _cardFlipController;
  late AnimationController _fabAnimationController;
  
  String _defaultMethodId = 'PM001';
  
  final List<PaymentMethod> _paymentMethods = [
    PaymentMethod(
      id: 'PM001',
      type: PaymentMethodType.card,
      name: 'Visa •••• 1234',
      cardNumber: '4111 1111 1111 1234',
      cardHolder: 'JUAN PEREZ',
      expiryDate: '12/25',
      cardType: CardType.visa,
      isDefault: true,
      icon: Icons.credit_card,
      color: Colors.blue,
    ),
    PaymentMethod(
      id: 'PM002',
      type: PaymentMethodType.card,
      name: 'MasterCard •••• 5678',
      cardNumber: '5500 0000 0000 5678',
      cardHolder: 'JUAN PEREZ',
      expiryDate: '08/26',
      cardType: CardType.mastercard,
      isDefault: false,
      icon: Icons.credit_card,
      color: Colors.orange,
    ),
    PaymentMethod(
      id: 'PM003',
      type: PaymentMethodType.cash,
      name: 'Efectivo',
      isDefault: false,
      icon: Icons.money,
      color: ModernTheme.success,
    ),
    PaymentMethod(
      id: 'PM004',
      type: PaymentMethodType.wallet,
      name: 'Billetera Oasis',
      walletBalance: '45.80',
      isDefault: false,
      icon: Icons.account_balance_wallet,
      color: ModernTheme.oasisGreen,
    ),
    PaymentMethod(
      id: 'PM005',
      type: PaymentMethodType.paypal,
      name: 'PayPal',
      isDefault: false,
      icon: Icons.payment,
      color: Colors.indigo,
    ),
  ];
  
  final List<Map<String, dynamic>> _transactionHistory = [
    {
      'id': 'T001',
      'date': DateTime.now().subtract(Duration(hours: 2)),
      'amount': 25.50,
      'method': 'Visa •••• 1234',
      'status': 'completed',
      'tripId': 'V001',
    },
    {
      'id': 'T002',
      'date': DateTime.now().subtract(Duration(days: 1)),
      'amount': 18.75,
      'method': 'Efectivo',
      'status': 'completed',
      'tripId': 'V002',
    },
    {
      'id': 'T003',
      'date': DateTime.now().subtract(Duration(days: 2)),
      'amount': 32.00,
      'method': 'Billetera Oasis',
      'status': 'completed',
      'tripId': 'V003',
    },
    {
      'id': 'T004',
      'date': DateTime.now().subtract(Duration(days: 3)),
      'amount': 22.50,
      'method': 'MasterCard •••• 5678',
      'status': 'failed',
      'tripId': 'V004',
    },
    {
      'id': 'T005',
      'date': DateTime.now().subtract(Duration(days: 4)),
      'amount': 15.00,
      'method': 'PayPal',
      'status': 'completed',
      'tripId': 'V005',
    },
  ];
  
  @override
  void initState() {
    super.initState();
    
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: ModernTheme.backgroundLight,
        appBar: AppBar(
          backgroundColor: ModernTheme.oasisGreen,
          title: Text(
            'Métodos de Pago',
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
              child: FloatingActionButton.extended(
                onPressed: _addPaymentMethod,
                backgroundColor: ModernTheme.oasisGreen,
                icon: Icon(Icons.add, color: Colors.white),
                label: Text(
                  'Agregar Método',
                  style: TextStyle(color: Colors.white),
                ),
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
          
          SizedBox(height: 24),
          
          // Payment methods section
          Text(
            'Métodos Guardados',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ModernTheme.textPrimary,
            ),
          ),
          SizedBox(height: 16),
          
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
          
          SizedBox(height: 24),
          
          // Security info
          _buildSecurityInfo(),
          
          SizedBox(height: 80),
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
    final wallet = _paymentMethods.firstWhere(
      (m) => m.type == PaymentMethodType.wallet,
      orElse: () => _paymentMethods.first,
    );
    
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
                  SizedBox(height: 8),
                  Text(
                    'S/ ${wallet.walletBalance ?? "0.00"}',
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
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _rechargeWallet,
                  icon: Icon(Icons.add),
                  label: Text('Recargar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: ModernTheme.oasisGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _viewWalletHistory,
                  icon: Icon(Icons.history),
                  label: Text('Historial'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
                      SizedBox(height: 20),
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
                        SizedBox(width: 12),
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
                        SizedBox(width: 12),
                        Text('Eliminar', style: TextStyle(color: ModernTheme.error)),
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
      0, (sum, t) => sum + (t['amount'] as double));
    final successfulTransactions = _transactionHistory
      .where((t) => t['status'] == 'completed').length;
    
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ModernTheme.primaryBlue, ModernTheme.primaryBlue.withValues(alpha: 0.8)],
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
          SizedBox(height: 16),
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
        SizedBox(height: 8),
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
          SizedBox(width: 12),
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
  
  void _setDefaultMethod(PaymentMethod method) {
    setState(() {
      _defaultMethodId = method.id;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${method.name} es ahora tu método predeterminado'),
        backgroundColor: ModernTheme.success,
      ),
    );
  }
  
  void _deletePaymentMethod(PaymentMethod method) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('Eliminar método de pago'),
        content: Text('¿Estás seguro de que deseas eliminar ${method.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _paymentMethods.removeWhere((m) => m.id == method.id);
                if (_defaultMethodId == method.id && _paymentMethods.isNotEmpty) {
                  _defaultMethodId = _paymentMethods.first.id;
                }
              });
              Navigator.pop(context);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Método de pago eliminado'),
                  backgroundColor: ModernTheme.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.error,
            ),
            child: Text('Eliminar'),
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
            SizedBox(height: 24),
            
            // Amount chips
            Wrap(
              spacing: 12,
              children: [10, 20, 50, 100, 200].map((amount) {
                return ChoiceChip(
                  label: Text('S/ $amount'),
                  selected: false,
                  onSelected: (selected) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Recargando S/ $amount...'),
                        backgroundColor: ModernTheme.success,
                      ),
                    );
                  },
                );
              }).toList(),
            ),
            
            SizedBox(height: 16),
            
            TextField(
              decoration: InputDecoration(
                labelText: 'Monto personalizado',
                prefixText: 'S/ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            
            SizedBox(height: 24),
            
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Procesando recarga...'),
                    backgroundColor: ModernTheme.oasisGreen,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.oasisGreen,
                minimumSize: Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Recargar'),
            ),
          ],
        ),
      ),
    );
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
            
            SizedBox(height: 20),
            
            _buildDetailRow('ID Transacción', transaction['id']),
            _buildDetailRow('Viaje', transaction['tripId']),
            _buildDetailRow('Fecha', _formatDate(transaction['date'])),
            _buildDetailRow('Método', transaction['method']),
            _buildDetailRow('Monto', 'S/ ${transaction['amount'].toStringAsFixed(2)}'),
            _buildDetailRow(
              'Estado',
              transaction['status'] == 'completed' ? 'Exitoso' : 'Fallido',
            ),
            
            SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Descargando recibo...'),
                          backgroundColor: ModernTheme.info,
                        ),
                      );
                    },
                    icon: Icon(Icons.download),
                    label: Text('Descargar'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Abriendo soporte...'),
                          backgroundColor: ModernTheme.oasisGreen,
                        ),
                      );
                    },
                    icon: Icon(Icons.help),
                    label: Text('Ayuda'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ModernTheme.oasisGreen,
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
            SizedBox(width: 8),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Entendido'),
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
  _AddPaymentMethodSheetState createState() => _AddPaymentMethodSheetState();
}

class _AddPaymentMethodSheetState extends State<AddPaymentMethodSheet> {
  final _formKey = GlobalKey<FormState>();
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
            
            SizedBox(height: 24),
            
            TextFormField(
              controller: _cardNumberController,
              decoration: InputDecoration(
                labelText: 'Número de tarjeta',
                prefixIcon: Icon(Icons.credit_card),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingresa el número de tarjeta';
                }
                return null;
              },
            ),
            
            SizedBox(height: 16),
            
            TextFormField(
              controller: _cardHolderController,
              decoration: InputDecoration(
                labelText: 'Titular de la tarjeta',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingresa el nombre del titular';
                }
                return null;
              },
            ),
            
            SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _expiryController,
                    decoration: InputDecoration(
                      labelText: 'MM/AA',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.datetime,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Requerido';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _cvvController,
                    decoration: InputDecoration(
                      labelText: 'CVV',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Requerido';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 24),
            
            ElevatedButton(
              onPressed: _addCard,
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.oasisGreen,
                minimumSize: Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Agregar Tarjeta'),
            ),
            
            SizedBox(height: 16),
            
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
  
  void _addCard() {
    if (_formKey.currentState!.validate()) {
      final newMethod = PaymentMethod(
        id: 'PM${DateTime.now().millisecondsSinceEpoch}',
        type: PaymentMethodType.card,
        name: '${_selectedCardType.name.toUpperCase()} •••• ${_cardNumberController.text.substring(_cardNumberController.text.length - 4)}',
        cardNumber: _cardNumberController.text,
        cardHolder: _cardHolderController.text.toUpperCase(),
        expiryDate: _expiryController.text,
        cardType: _selectedCardType,
        isDefault: false,
        icon: Icons.credit_card,
        color: Colors.blue,
      );
      
      widget.onMethodAdded(newMethod);
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tarjeta agregada exitosamente'),
          backgroundColor: ModernTheme.success,
        ),
      );
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