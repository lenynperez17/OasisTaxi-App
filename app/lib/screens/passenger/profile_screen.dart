// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../core/theme/modern_theme.dart';
import '../../widgets/animated/modern_animated_widgets.dart';
import '../../providers/auth_provider.dart';
// import '../../providers/ride_provider.dart'; // Se usará para estadísticas reales

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _statsController;
  late AnimationController _settingsController;
  late TabController _tabController;
  
  // Controllers para edición
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();
  
  bool _isEditing = false;
  File? _imageFile;
  
  // Preferencias
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _promotionsEnabled = false;
  bool _newsEnabled = false;
  String _defaultPayment = 'cash';
  String _language = 'es';
  
  // Estadísticas del usuario (se cargan de Firebase)
  Map<String, dynamic> _userStats = {
    'totalTrips': 0,
    'totalSpent': 0.0,
    'totalDistance': 0.0,
    'savedPlaces': 0,
    'referrals': 0,
    'memberSince': DateTime.now(),
    'rating': 0.0,
    'level': 'Bronze',
    'points': 0,
  };
  
  bool _isLoadingProfile = true;
  
  @override
  void initState() {
    super.initState();
    
    _headerController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    
    _statsController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    )..forward();
    
    _settingsController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    )..forward();
    
    _tabController = TabController(length: 3, vsync: this);
    
    // Cargar datos del usuario
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserProfile();
    });
  }

  // Cargar perfil del usuario desde Firebase
  Future<void> _loadUserProfile() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // final rideProvider = Provider.of<RideProvider>(context, listen: false); // Se usará para estadísticas reales
      final user = authProvider.currentUser;
      
      if (user != null) {
        // Cargar datos básicos del usuario
        _nameController.text = user.fullName;
        _emailController.text = user.email;
        _phoneController.text = user.phone;
        
        // Cargar estadísticas del usuario (simuladas por ahora)
        final userStats = {
          'totalTrips': user.totalTrips,
          'totalSpent': user.balance,
          'totalDistance': 0.0,
          'savedPlaces': 0,
          'referrals': 0,
          'memberSince': user.createdAt,
          'rating': user.rating,
          'level': _getUserLevel(user.totalTrips),
          'points': user.totalTrips * 10,
        };
        
        setState(() {
          _userStats = userStats;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando perfil: $e');
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }
  
  // Obtener nivel del usuario basado en viajes
  String _getUserLevel(int totalTrips) {
    if (totalTrips >= 100) return 'Platinum';
    if (totalTrips >= 50) return 'Gold';
    if (totalTrips >= 20) return 'Silver';
    return 'Bronze';
  }
  
  @override
  void dispose() {
    _headerController.dispose();
    _statsController.dispose();
    _settingsController.dispose();
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }
  
  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        // Guardar cambios
        _saveProfile();
      }
    });
  }
  
  void _saveProfile() {
    // Simular guardado
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Perfil actualizado exitosamente'),
          ],
        ),
        backgroundColor: ModernTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
  
  void _pickImage() {
    // Simular selección de imagen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Seleccionar imagen desde galería'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      body: _isLoadingProfile 
        ? Center(
            child: CircularProgressIndicator(
              color: ModernTheme.oasisGreen,
            ),
          )
        : CustomScrollView(
        slivers: [
          // AppBar animado con foto de perfil
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: ModernTheme.oasisGreen,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isEditing ? Icons.check : Icons.edit,
                  color: Colors.white,
                ),
                onPressed: _toggleEdit,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: AnimatedBuilder(
                animation: _headerController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: ModernTheme.primaryGradient,
                    ),
                    child: Stack(
                      children: [
                        // Patrón de fondo
                        Positioned.fill(
                          child: CustomPaint(
                            painter: ProfileBackgroundPainter(
                              animation: _headerController,
                            ),
                          ),
                        ),
                        // Contenido del perfil
                        Center(
                          child: Transform.scale(
                            scale: 0.8 + (0.2 * _headerController.value),
                            child: Opacity(
                              opacity: _headerController.value,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(height: 60),
                                  // Foto de perfil
                                  Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 20,
                                              offset: Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: CircleAvatar(
                                          radius: 60,
                                          backgroundColor: Colors.white,
                                          backgroundImage: _imageFile != null
                                              ? FileImage(_imageFile!)
                                              : null,
                                          child: _imageFile == null
                                              ? Icon(
                                                  Icons.person,
                                                  size: 60,
                                                  color: ModernTheme.oasisGreen,
                                                )
                                              : null,
                                        ),
                                      ),
                                      if (_isEditing)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: ModernTheme.cardShadow,
                                            ),
                                            child: IconButton(
                                              icon: Icon(
                                                Icons.camera_alt,
                                                color: ModernTheme.oasisGreen,
                                              ),
                                              onPressed: _pickImage,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 16),
                                  // Nombre y nivel
                                  Text(
                                    _nameController.text,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.star,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          '${_userStats['level']} • ${_userStats['points']} pts',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Tabs
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: ModernTheme.oasisGreen,
                unselectedLabelColor: ModernTheme.textSecondary,
                indicatorColor: ModernTheme.oasisGreen,
                tabs: [
                  Tab(text: 'Información', icon: Icon(Icons.person)),
                  Tab(text: 'Estadísticas', icon: Icon(Icons.bar_chart)),
                  Tab(text: 'Preferencias', icon: Icon(Icons.settings)),
                ],
              ),
            ),
          ),
          
          // Contenido de tabs
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPersonalInfoTab(),
                _buildStatisticsTab(),
                _buildPreferencesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPersonalInfoTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Información Personal',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ModernTheme.textPrimary,
            ),
          ),
          SizedBox(height: 20),
          
          // Campos de información
          _buildTextField(
            controller: _nameController,
            label: 'Nombre completo',
            icon: Icons.person,
            enabled: _isEditing,
          ),
          SizedBox(height: 16),
          
          _buildTextField(
            controller: _emailController,
            label: 'Correo electrónico',
            icon: Icons.email,
            enabled: _isEditing,
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: 16),
          
          _buildTextField(
            controller: _phoneController,
            label: 'Teléfono',
            icon: Icons.phone,
            enabled: _isEditing,
            keyboardType: TextInputType.phone,
          ),
          SizedBox(height: 16),
          
          _buildTextField(
            controller: _birthDateController,
            label: 'Fecha de nacimiento',
            icon: Icons.calendar_today,
            enabled: _isEditing,
            onTap: _isEditing ? () => _selectDate() : null,
          ),
          
          SizedBox(height: 30),
          
          // Verificación de cuenta
          Text(
            'Verificación',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ModernTheme.textPrimary,
            ),
          ),
          SizedBox(height: 16),
          
          _buildVerificationItem(
            'Email verificado',
            true,
            Icons.email,
          ),
          _buildVerificationItem(
            'Teléfono verificado',
            true,
            Icons.phone,
          ),
          _buildVerificationItem(
            'Documento de identidad',
            false,
            Icons.badge,
          ),
          
          SizedBox(height: 30),
          
          // Botones de acción
          if (!_isEditing) ...[
            AnimatedPulseButton(
              text: 'Cambiar contraseña',
              icon: Icons.lock,
              onPressed: () {
                _showChangePasswordDialog();
              },
              color: ModernTheme.primaryBlue,
            ),
            SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                _showDeleteAccountDialog();
              },
              icon: Icon(Icons.delete_forever, color: ModernTheme.error),
              label: Text(
                'Eliminar cuenta',
                style: TextStyle(color: ModernTheme.error),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 48),
                side: BorderSide(color: ModernTheme.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildStatisticsTab() {
    return AnimatedBuilder(
      animation: _statsController,
      builder: (context, child) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tus Estadísticas',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ModernTheme.textPrimary,
                ),
              ),
              SizedBox(height: 20),
              
              // Grid de estadísticas
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.3,
                children: [
                  _buildStatCard(
                    'Viajes Totales',
                    '${_userStats['totalTrips']}',
                    Icons.route,
                    ModernTheme.primaryBlue,
                    0,
                  ),
                  _buildStatCard(
                    'Gasto Total',
                    '\$${_userStats['totalSpent'].toStringAsFixed(2)}',
                    Icons.attach_money,
                    ModernTheme.success,
                    1,
                  ),
                  _buildStatCard(
                    'Distancia',
                    '${_userStats['totalDistance'].toStringAsFixed(1)} km',
                    Icons.map,
                    ModernTheme.warning,
                    2,
                  ),
                  _buildStatCard(
                    'Calificación',
                    '${_userStats['rating']}',
                    Icons.star,
                    Colors.amber,
                    3,
                  ),
                ],
              ),
              
              SizedBox(height: 30),
              
              // Logros
              Text(
                'Logros Desbloqueados',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ModernTheme.textPrimary,
                ),
              ),
              SizedBox(height: 16),
              
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildAchievementBadge(
                      'Viajero Frecuente',
                      Icons.flight_takeoff,
                      true,
                    ),
                    _buildAchievementBadge(
                      'Puntual',
                      Icons.access_time,
                      true,
                    ),
                    _buildAchievementBadge(
                      'Explorador',
                      Icons.explore,
                      true,
                    ),
                    _buildAchievementBadge(
                      'VIP',
                      Icons.workspace_premium,
                      false,
                    ),
                    _buildAchievementBadge(
                      'Embajador',
                      Icons.people,
                      false,
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 30),
              
              // Gráfico de actividad
              Text(
                'Actividad Mensual',
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
                  painter: ActivityChartPainter(
                    animation: _statsController,
                  ),
                  child: Container(),
                ),
              ),
              
              SizedBox(height: 30),
              
              // Información adicional
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: ModernTheme.oasisGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.cake,
                          color: ModernTheme.oasisGreen,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Miembro desde',
                          style: TextStyle(
                            color: ModernTheme.textSecondary,
                          ),
                        ),
                        Spacer(),
                        Text(
                          '${_userStats['memberSince'].day}/${_userStats['memberSince'].month}/${_userStats['memberSince'].year}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: ModernTheme.oasisGreen,
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 24),
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          color: ModernTheme.oasisGreen,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Amigos referidos',
                          style: TextStyle(
                            color: ModernTheme.textSecondary,
                          ),
                        ),
                        Spacer(),
                        Text(
                          '${_userStats['referrals']}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: ModernTheme.oasisGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildPreferencesTab() {
    return AnimatedBuilder(
      animation: _settingsController,
      builder: (context, child) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notificaciones
              Text(
                'Notificaciones',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ModernTheme.textPrimary,
                ),
              ),
              SizedBox(height: 16),
              
              _buildSwitchTile(
                'Notificaciones push',
                'Recibe alertas de viajes y ofertas',
                _notificationsEnabled,
                (value) => setState(() => _notificationsEnabled = value),
                Icons.notifications,
                0,
              ),
              _buildSwitchTile(
                'Sonido',
                'Activa sonidos de notificación',
                _soundEnabled,
                (value) => setState(() => _soundEnabled = value),
                Icons.volume_up,
                1,
              ),
              _buildSwitchTile(
                'Vibración',
                'Vibra al recibir notificaciones',
                _vibrationEnabled,
                (value) => setState(() => _vibrationEnabled = value),
                Icons.vibration,
                2,
              ),
              _buildSwitchTile(
                'Promociones',
                'Recibe ofertas y descuentos especiales',
                _promotionsEnabled,
                (value) => setState(() => _promotionsEnabled = value),
                Icons.local_offer,
                3,
              ),
              _buildSwitchTile(
                'Novedades',
                'Entérate de nuevas funciones',
                _newsEnabled,
                (value) => setState(() => _newsEnabled = value),
                Icons.new_releases,
                4,
              ),
              
              SizedBox(height: 30),
              
              // Preferencias de viaje
              Text(
                'Preferencias de Viaje',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ModernTheme.textPrimary,
                ),
              ),
              SizedBox(height: 16),
              
              // Método de pago predeterminado
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: ModernTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.payment,
                          color: ModernTheme.oasisGreen,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Método de pago predeterminado',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        _buildPaymentOption('Efectivo', 'cash', Icons.money),
                        SizedBox(width: 8),
                        _buildPaymentOption('Tarjeta', 'card', Icons.credit_card),
                        SizedBox(width: 8),
                        _buildPaymentOption('Billetera', 'wallet', Icons.account_balance_wallet),
                      ],
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 16),
              
              // Idioma
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: ModernTheme.cardShadow,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.language,
                      color: ModernTheme.oasisGreen,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Idioma',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: ModernTheme.backgroundLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _language,
                        underline: SizedBox(),
                        isDense: true,
                        items: [
                          DropdownMenuItem(
                            value: 'es',
                            child: Text('Español'),
                          ),
                          DropdownMenuItem(
                            value: 'en',
                            child: Text('English'),
                          ),
                          DropdownMenuItem(
                            value: 'pt',
                            child: Text('Português'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _language = value!);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 30),
              
              // Privacidad
              Text(
                'Privacidad y Seguridad',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ModernTheme.textPrimary,
                ),
              ),
              SizedBox(height: 16),
              
              _buildPrivacyOption(
                'Términos y condiciones',
                Icons.description,
                () {},
              ),
              _buildPrivacyOption(
                'Política de privacidad',
                Icons.privacy_tip,
                () {},
              ),
              _buildPrivacyOption(
                'Gestionar permisos',
                Icons.security,
                () {},
              ),
              _buildPrivacyOption(
                'Exportar mis datos',
                Icons.download,
                () {},
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: ModernTheme.oasisGreen),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ModernTheme.oasisGreen, width: 2),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : ModernTheme.backgroundLight,
      ),
    );
  }
  
  Widget _buildVerificationItem(String title, bool verified, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: verified 
          ? ModernTheme.success.withValues(alpha: 0.1)
          : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: verified 
            ? ModernTheme.success.withValues(alpha: 0.3)
            : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: verified ? ModernTheme.success : Colors.grey,
          ),
          SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: verified ? ModernTheme.textPrimary : Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          Spacer(),
          Icon(
            verified ? Icons.check_circle : Icons.add_circle_outline,
            color: verified ? ModernTheme.success : Colors.grey,
          ),
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
        parent: _statsController,
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
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                SizedBox(height: 12),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
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
  
  Widget _buildAchievementBadge(String title, IconData icon, bool unlocked) {
    return Container(
      width: 80,
      margin: EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: unlocked 
                ? ModernTheme.oasisGreen 
                : Colors.grey.shade300,
              shape: BoxShape.circle,
              boxShadow: unlocked ? ModernTheme.cardShadow : null,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 30,
            ),
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: unlocked 
                ? ModernTheme.textPrimary 
                : ModernTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
    IconData icon,
    int index,
  ) {
    final delay = index * 0.1;
    final animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _settingsController,
        curve: Interval(
          delay,
          delay + 0.5,
          curve: Curves.easeOut,
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
            child: Container(
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: ModernTheme.cardShadow,
              ),
              child: ListTile(
                leading: Icon(icon, color: ModernTheme.oasisGreen),
                title: Text(title),
                subtitle: Text(
                  subtitle,
                  style: TextStyle(fontSize: 12),
                ),
                trailing: Switch(
                  value: value,
                  onChanged: onChanged,
                  thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildPaymentOption(String label, String value, IconData icon) {
    final isSelected = _defaultPayment == value;
    
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _defaultPayment = value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected 
              ? ModernTheme.oasisGreen.withValues(alpha: 0.1)
              : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected 
                ? ModernTheme.oasisGreen 
                : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected 
                  ? ModernTheme.oasisGreen 
                  : ModernTheme.textSecondary,
                size: 20,
              ),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected 
                    ? ModernTheme.oasisGreen 
                    : ModernTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPrivacyOption(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: ModernTheme.cardShadow,
        ),
        child: Row(
          children: [
            Icon(icon, color: ModernTheme.oasisGreen),
            SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: ModernTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
  
  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990, 3, 15),
      firstDate: DateTime(1900),
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
    
    if (picked != null) {
      setState(() {
        _birthDateController.text = 
          '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }
  
  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('Cambiar Contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Contraseña actual',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Nueva contraseña',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirmar nueva contraseña',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Contraseña actualizada'),
                  backgroundColor: ModernTheme.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.oasisGreen,
            ),
            child: Text('Cambiar'),
          ),
        ],
      ),
    );
  }
  
  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('Eliminar Cuenta'),
        content: Text(
          '¿Estás seguro de que deseas eliminar tu cuenta? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Lógica de eliminación
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
}

// Delegate para el tab bar fijo
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  
  _SliverAppBarDelegate(this._tabBar);
  
  @override
  double get minExtent => _tabBar.preferredSize.height;
  
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }
  
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

// Painter para el fondo del perfil
class ProfileBackgroundPainter extends CustomPainter {
  final Animation<double> animation;
  
  const ProfileBackgroundPainter({super.repaint, required this.animation});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // Círculos animados
    for (int i = 0; i < 3; i++) {
      final radius = (50 + i * 30) * animation.value;
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        radius,
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Painter para el gráfico de actividad
class ActivityChartPainter extends CustomPainter {
  final Animation<double> animation;
  
  const ActivityChartPainter({super.repaint, required this.animation});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ModernTheme.oasisGreen
      ..style = PaintingStyle.fill;
    
    final data = [0.3, 0.5, 0.8, 0.6, 0.9, 0.7, 0.4];
    final barWidth = size.width / (data.length * 2);
    
    for (int i = 0; i < data.length; i++) {
      final barHeight = size.height * data[i] * animation.value;
      final x = i * (barWidth * 2) + barWidth / 2;
      final y = size.height - barHeight;
      
      // Barra
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        Radius.circular(4),
      );
      canvas.drawRRect(rect, paint);
      
      // Etiqueta
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'D${i + 1}',
          style: TextStyle(
            color: ModernTheme.textSecondary,
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + barWidth / 2 - textPainter.width / 2, size.height + 4),
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}