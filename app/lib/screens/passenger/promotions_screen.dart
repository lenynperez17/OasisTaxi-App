// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/modern_theme.dart';

enum PromotionType { percentage, fixed, freeRide, loyalty }
enum PromotionStatus { active, used, expired }

class Promotion {
  final String id;
  final String code;
  final String title;
  final String description;
  final PromotionType type;
  final PromotionStatus status;
  final double value;
  final DateTime validUntil;
  final int? maxUses;
  final int? usedCount;
  final double? minAmount;
  final List<String>? validZones;
  final String imageUrl;
  final Color color;

  Promotion({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.value,
    required this.validUntil,
    this.maxUses,
    this.usedCount,
    this.minAmount,
    this.validZones,
    required this.imageUrl,
    required this.color,
  });

  bool get isValid => status == PromotionStatus.active && validUntil.isAfter(DateTime.now());
  int get remainingUses => maxUses != null ? (maxUses! - (usedCount ?? 0)) : 999;
  int get daysRemaining => validUntil.difference(DateTime.now()).inDays;
}

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  _PromotionsScreenState createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId; // Se obtendrá del usuario actual
  bool _isLoading = true;
  
  late TabController _tabController;
  late AnimationController _listAnimationController;
  late AnimationController _headerAnimationController;
  
  final TextEditingController _promoCodeController = TextEditingController();
  
  // Lista de promociones desde Firebase
  List<Promotion> _promotions = [];
  
  // Loyalty program data
  final Map<String, dynamic> _loyaltyData = {
    'currentPoints': 750,
    'nextRewardPoints': 1000,
    'level': 'Gold',
    'totalTrips': 45,
    'savedAmount': 234.50,
  };
  
  List<Promotion> get _activePromotions => 
    _promotions.where((p) => p.status == PromotionStatus.active).toList();
    
  List<Promotion> get _usedPromotions => 
    _promotions.where((p) => p.status == PromotionStatus.used).toList();
    
  List<Promotion> get _expiredPromotions => 
    _promotions.where((p) => p.status == PromotionStatus.expired).toList();
  
  @override
  void initState() {
    super.initState();
    
    _tabController = TabController(length: 3, vsync: this);
    _listAnimationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    _headerAnimationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    )..forward();
    
    _loadPromotionsFromFirebase();
  }
  
  Future<void> _loadPromotionsFromFirebase() async {
    try {
      setState(() => _isLoading = true);
      
      // Por ahora usar un userId de ejemplo
      // En producción, esto vendría del usuario autenticado
      _userId = 'test_user_id';
      
      // Cargar promociones activas desde Firebase
      final promotionsSnapshot = await _firestore
          .collection('promotions')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();
      
      List<Promotion> loadedPromotions = [];
      
      for (var doc in promotionsSnapshot.docs) {
        final data = doc.data();
        
        // Determinar el tipo de promoción
        PromotionType type = PromotionType.percentage;
        if (data['type'] == 'fixed') {
          type = PromotionType.fixed;
        } else if (data['type'] == 'freeRide') {
          type = PromotionType.freeRide;
        } else if (data['type'] == 'loyalty') {
          type = PromotionType.loyalty;
        }
        
        // Determinar el estado de la promoción
        PromotionStatus status = PromotionStatus.active;
        final validUntil = data['validUntil'] != null 
            ? (data['validUntil'] as Timestamp).toDate() 
            : DateTime.now().add(Duration(days: 30));
        
        // Verificar si el usuario ya usó esta promoción
        final userUsageDoc = await _firestore
            .collection('users')
            .doc(_userId)
            .collection('used_promotions')
            .doc(doc.id)
            .get();
        
        if (userUsageDoc.exists) {
          final usageData = userUsageDoc.data()!;
          final usedCount = usageData['usedCount'] ?? 0;
          final maxUses = data['maxUses'] ?? 1;
          
          if (usedCount >= maxUses) {
            status = PromotionStatus.used;
          }
        }
        
        if (validUntil.isBefore(DateTime.now())) {
          status = PromotionStatus.expired;
        }
        
        // Determinar el color basado en el tipo
        Color color = ModernTheme.primaryBlue;
        if (type == PromotionType.fixed) {
          color = ModernTheme.success;
        } else if (type == PromotionType.freeRide) {
          color = ModernTheme.warning;
        } else if (type == PromotionType.loyalty) {
          color = ModernTheme.oasisGreen;
        }
        
        loadedPromotions.add(Promotion(
          id: doc.id,
          code: data['code'] ?? '',
          title: data['title'] ?? 'Promoción',
          description: data['description'] ?? '',
          type: type,
          status: status,
          value: (data['value'] ?? 0).toDouble(),
          validUntil: validUntil,
          maxUses: data['maxUses'],
          usedCount: data['usedCount'] ?? 0,
          minAmount: data['minAmount']?.toDouble(),
          validZones: data['validZones'] != null 
              ? List<String>.from(data['validZones']) 
              : null,
          imageUrl: data['imageUrl'] ?? 'assets/promo.jpg',
          color: color,
        ));
      }
      
      // Si no hay promociones, mostrar lista vacía (sin crear datos de ejemplo)
      
      setState(() {
        _promotions = loadedPromotions;
        _isLoading = false;
      });
      
    } catch (e) {
      print('Error cargando promociones: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar promociones'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }
  
  
  @override
  void dispose() {
    _tabController.dispose();
    _listAnimationController.dispose();
    _headerAnimationController.dispose();
    _promoCodeController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: ModernTheme.oasisGreen,
        title: Text(
          'Promociones y Cupones',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.card_giftcard, color: Colors.white),
            onPressed: _showLoyaltyProgram,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Container(
            color: ModernTheme.oasisGreen,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(text: 'Activas (${_activePromotions.length})'),
                Tab(text: 'Usadas (${_usedPromotions.length})'),
                Tab(text: 'Expiradas (${_expiredPromotions.length})'),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Promo code input
          _buildPromoCodeInput(),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPromotionsList(_activePromotions, PromotionStatus.active),
                _buildPromotionsList(_usedPromotions, PromotionStatus.used),
                _buildPromotionsList(_expiredPromotions, PromotionStatus.expired),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPromoCodeInput() {
    return AnimatedBuilder(
      animation: _headerAnimationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -50 * (1 - _headerAnimationController.value)),
          child: Opacity(
            opacity: _headerAnimationController.value,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promoCodeController,
                      decoration: InputDecoration(
                        hintText: 'Ingresa tu código promocional',
                        prefixIcon: Icon(Icons.local_offer, color: ModernTheme.oasisGreen),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: ModernTheme.oasisGreen, width: 2),
                        ),
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _applyPromoCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ModernTheme.oasisGreen,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Aplicar'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildPromotionsList(List<Promotion> promotions, PromotionStatus status) {
    if (promotions.isEmpty) {
      return _buildEmptyState(status);
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: promotions.length + (status == PromotionStatus.active ? 1 : 0),
      itemBuilder: (context, index) {
        if (status == PromotionStatus.active && index == 0) {
          return _buildLoyaltyCard();
        }
        
        final promoIndex = status == PromotionStatus.active ? index - 1 : index;
        final promotion = promotions[promoIndex];
        final delay = promoIndex * 0.1;
        
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
                child: _buildPromotionCard(promotion),
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildLoyaltyCard() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ModernTheme.oasisGreen, ModernTheme.oasisGreen.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ModernTheme.oasisGreen.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: InkWell(
        onTap: _showLoyaltyProgram,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.all(20),
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
                        'Programa de Fidelidad',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Nivel ${_loyaltyData['level']}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
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
                      Icons.star,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              
              // Points progress
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_loyaltyData['currentPoints']} pts',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_loyaltyData['nextRewardPoints']} pts',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _loyaltyData['currentPoints'] / _loyaltyData['nextRewardPoints'],
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Te faltan ${_loyaltyData['nextRewardPoints'] - _loyaltyData['currentPoints']} puntos para tu próxima recompensa',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              
              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLoyaltyStat('Viajes', '${_loyaltyData['totalTrips']}'),
                  Container(width: 1, height: 30, color: Colors.white24),
                  _buildLoyaltyStat('Ahorrado', 'S/ ${_loyaltyData['savedAmount']}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLoyaltyStat(String label, String value) {
    return Column(
      children: [
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
  
  Widget _buildPromotionCard(Promotion promotion) {
    final isActive = promotion.status == PromotionStatus.active;
    final isExpired = promotion.status == PromotionStatus.expired;
    final isUsed = promotion.status == PromotionStatus.used;
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: ModernTheme.cardShadow,
        border: Border.all(
          color: isActive ? promotion.color.withValues(alpha: 0.3) : Colors.grey.shade200,
          width: isActive ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: isActive ? () => _showPromotionDetails(promotion) : null,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Promotion image/header
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isActive 
                    ? [promotion.color, promotion.color.withValues(alpha: 0.7)]
                    : [Colors.grey, Colors.grey.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Stack(
                children: [
                  // Pattern decoration
                  Positioned.fill(
                    child: CustomPaint(
                      painter: PromotionPatternPainter(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  
                  // Content
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                promotion.code,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (isActive)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _getPromotionValue(promotion),
                                  style: TextStyle(
                                    color: promotion.color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          promotion.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // Status overlay
                  if (isUsed || isExpired)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Center(
                          child: Transform.rotate(
                            angle: -0.2,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              decoration: BoxDecoration(
                                color: isUsed ? ModernTheme.success : ModernTheme.error,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isUsed ? 'USADO' : 'EXPIRADO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Promotion details
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    promotion.description,
                    style: TextStyle(
                      color: ModernTheme.textSecondary,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 12),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Validity
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: isActive 
                              ? (promotion.daysRemaining <= 3 ? ModernTheme.warning : ModernTheme.textSecondary)
                              : Colors.grey,
                          ),
                          SizedBox(width: 4),
                          Text(
                            isActive
                              ? (promotion.daysRemaining == 0 
                                  ? 'Expira hoy'
                                  : 'Válido por ${promotion.daysRemaining} días')
                              : 'Expirado',
                            style: TextStyle(
                              color: isActive
                                ? (promotion.daysRemaining <= 3 ? ModernTheme.warning : ModernTheme.textSecondary)
                                : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      
                      // Uses remaining
                      if (promotion.maxUses != null && isActive)
                        Row(
                          children: [
                            Icon(
                              Icons.confirmation_number,
                              size: 16,
                              color: ModernTheme.textSecondary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '${promotion.remainingUses} usos',
                              style: TextStyle(
                                color: ModernTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      
                      // Action button
                      if (isActive)
                        ElevatedButton(
                          onPressed: () => _usePromotion(promotion),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: promotion.color,
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            'Usar',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  
                  // Conditions
                  if (promotion.minAmount != null || promotion.validZones != null) ...[
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (promotion.minAmount != null)
                          _buildConditionChip(
                            Icons.attach_money,
                            'Mín. S/ ${promotion.minAmount}',
                          ),
                        if (promotion.validZones != null)
                          ...(promotion.validZones!.map((zone) => 
                            _buildConditionChip(Icons.location_on, zone))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildConditionChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ModernTheme.backgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: ModernTheme.textSecondary),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: ModernTheme.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState(PromotionStatus status) {
    IconData icon;
    String title;
    String subtitle;
    
    switch (status) {
      case PromotionStatus.active:
        icon = Icons.local_offer;
        title = 'No hay promociones activas';
        subtitle = 'Vuelve pronto para ver nuevas ofertas';
        break;
      case PromotionStatus.used:
        icon = Icons.check_circle;
        title = 'No has usado promociones';
        subtitle = 'Aprovecha las ofertas disponibles';
        break;
      case PromotionStatus.expired:
        icon = Icons.timer_off;
        title = 'No hay promociones expiradas';
        subtitle = 'Todas tus promociones están activas';
        break;
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ModernTheme.textSecondary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: ModernTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  String _getPromotionValue(Promotion promotion) {
    switch (promotion.type) {
      case PromotionType.percentage:
        return '${promotion.value.toInt()}%';
      case PromotionType.fixed:
        return 'S/ ${promotion.value.toInt()}';
      case PromotionType.freeRide:
        return 'GRATIS';
      case PromotionType.loyalty:
        return '${promotion.value.toInt()}%';
    }
  }
  
  void _applyPromoCode() {
    final code = _promoCodeController.text.trim();
    if (code.isEmpty) return;
    
    // Check if code exists
    final promotion = _promotions.firstWhere(
      (p) => p.code == code && p.isValid,
      orElse: () => _promotions.first,
    );
    
    if (promotion.code == code && promotion.isValid) {
      _promoCodeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Código $code aplicado exitosamente!'),
          backgroundColor: ModernTheme.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Código inválido o expirado'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }
  
  void _usePromotion(Promotion promotion) {
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
            Icon(
              Icons.check_circle,
              color: ModernTheme.success,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'Promoción Activada',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              promotion.title,
              style: TextStyle(
                fontSize: 16,
                color: ModernTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ModernTheme.backgroundLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Código: ',
                    style: TextStyle(color: ModernTheme.textSecondary),
                  ),
                  Text(
                    promotion.code,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Se aplicará automáticamente en tu próximo viaje',
              style: TextStyle(
                color: ModernTheme.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.oasisGreen,
                minimumSize: Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Entendido'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showPromotionDetails(Promotion promotion) {
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
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.all(24),
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
                
                // Header
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [promotion.color, promotion.color.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _getPromotionValue(promotion),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        promotion.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 24),
                
                // Description
                Text(
                  'Descripción',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  promotion.description,
                  style: TextStyle(
                    color: ModernTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                
                SizedBox(height: 24),
                
                // Terms and conditions
                Text(
                  'Términos y Condiciones',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                
                _buildTermItem('Válido hasta ${_formatDate(promotion.validUntil)}'),
                if (promotion.maxUses != null)
                  _buildTermItem('Máximo ${promotion.maxUses} usos por usuario'),
                if (promotion.minAmount != null)
                  _buildTermItem('Compra mínima de S/ ${promotion.minAmount}'),
                if (promotion.validZones != null)
                  _buildTermItem('Válido solo en: ${promotion.validZones!.join(', ')}'),
                _buildTermItem('No acumulable con otras promociones'),
                _buildTermItem('Sujeto a disponibilidad de conductores'),
                
                SizedBox(height: 24),
                
                // Use button
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _usePromotion(promotion);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: promotion.color,
                    minimumSize: Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Usar Promoción'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildTermItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 16, color: ModernTheme.success),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: ModernTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showLoyaltyProgram() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoyaltyProgramScreen(loyaltyData: _loyaltyData),
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Loyalty program screen
class LoyaltyProgramScreen extends StatelessWidget {
  final Map<String, dynamic> loyaltyData;
  
  const LoyaltyProgramScreen({super.key, required this.loyaltyData});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: ModernTheme.oasisGreen,
        title: Text(
          'Programa de Fidelidad',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Level card
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [ModernTheme.oasisGreen, ModernTheme.oasisGreen.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.star,
                    color: Colors.white,
                    size: 64,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Nivel ${loyaltyData['level']}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${loyaltyData['currentPoints']} puntos acumulados',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 24),
            
            // Benefits
            Text(
              'Beneficios de tu nivel',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            _buildBenefitCard(
              Icons.percent,
              '15% de descuento',
              'En todos tus viajes',
            ),
            _buildBenefitCard(
              Icons.flash_on,
              'Prioridad en horas pico',
              'Conexión más rápida con conductores',
            ),
            _buildBenefitCard(
              Icons.card_giftcard,
              'Promociones exclusivas',
              'Acceso anticipado a ofertas',
            ),
            _buildBenefitCard(
              Icons.support_agent,
              'Soporte prioritario',
              'Atención preferencial 24/7',
            ),
            
            SizedBox(height: 24),
            
            // How it works
            Text(
              'Cómo funciona',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            _buildHowItWorksItem(
              '1',
              'Acumula puntos',
              'Gana 10 puntos por cada S/ 1 gastado',
            ),
            _buildHowItWorksItem(
              '2',
              'Sube de nivel',
              'Alcanza nuevos niveles con más puntos',
            ),
            _buildHowItWorksItem(
              '3',
              'Disfruta beneficios',
              'Mejores descuentos y ventajas exclusivas',
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBenefitCard(IconData icon, String title, String subtitle) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: ModernTheme.oasisGreen),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: ModernTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHowItWorksItem(String number, String title, String subtitle) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: ModernTheme.oasisGreen,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: ModernTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for promotion pattern
class PromotionPatternPainter extends CustomPainter {
  final Color color;
  
  const PromotionPatternPainter({super.repaint, required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // Draw circles pattern
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 3; j++) {
        final x = size.width * (i + 1) / 5;
        final y = size.height * (j + 1) / 4;
        canvas.drawCircle(Offset(x, y), 8, paint);
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}