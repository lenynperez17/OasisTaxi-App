// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter
import 'package:flutter/material.dart';
import '../../core/theme/modern_theme.dart';

class SettingsScreen extends StatefulWidget {
  final String? userType; // 'passenger', 'driver', 'admin'
  
  SettingsScreen({super.key, this.userType});
  
  @override
  // ignore: library_private_types_in_public_api
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> 
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  // General settings
  bool _notificationsEnabled = true;
  bool _locationServices = true;
  bool _darkMode = false;
  String _language = 'es';
  String _currency = 'PEN';
  
  // Privacy settings
  bool _shareLocation = true;
  bool _shareTrips = false;
  bool _analytics = true;
  bool _crashReports = true;
  
  // Notification settings
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _tripUpdates = true;
  bool _promotions = true;
  bool _newsUpdates = false;
  
  // Security settings
  bool _biometricAuth = false;
  bool _twoFactorAuth = false;
  int _autoLockTime = 5; // minutes
  
  // App settings
  bool _autoUpdate = true;
  bool _offlineMaps = false;
  String _mapStyle = 'standard';
  bool _soundEffects = true;
  bool _hapticFeedback = true;
  
  // Data settings
  bool _syncOnWiFiOnly = false;
  bool _compressImages = true;
  String _cacheSize = '150 MB';
  
  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    
    _fadeController.forward();
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: ModernTheme.oasisGreen,
        elevation: 0,
        title: Text(
          'Configuración',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.restore, color: Colors.white),
            onPressed: _resetToDefaults,
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // General section
                  _buildSection(
                    'General',
                    Icons.settings,
                    ModernTheme.primaryBlue,
                    [
                      _buildLanguageTile(),
                      _buildCurrencyTile(),
                      _buildSwitchTile(
                        'Modo Oscuro',
                        'Cambiar apariencia de la app',
                        Icons.dark_mode,
                        _darkMode,
                        (value) => setState(() => _darkMode = value),
                      ),
                      _buildSwitchTile(
                        'Servicios de Ubicación',
                        'Permitir acceso a tu ubicación',
                        Icons.location_on,
                        _locationServices,
                        (value) => setState(() => _locationServices = value),
                      ),
                    ],
                  ),
                  
                  // Notifications section
                  _buildSection(
                    'Notificaciones',
                    Icons.notifications,
                    Colors.orange,
                    [
                      _buildSwitchTile(
                        'Notificaciones Push',
                        'Recibir notificaciones en tu dispositivo',
                        Icons.notifications_active,
                        _pushNotifications,
                        (value) => setState(() => _pushNotifications = value),
                      ),
                      _buildSwitchTile(
                        'Notificaciones por Email',
                        'Recibir emails informativos',
                        Icons.email,
                        _emailNotifications,
                        (value) => setState(() => _emailNotifications = value),
                      ),
                      _buildSwitchTile(
                        'Mensajes SMS',
                        'Recibir mensajes de texto',
                        Icons.sms,
                        _smsNotifications,
                        (value) => setState(() => _smsNotifications = value),
                      ),
                      Divider(),
                      _buildSwitchTile(
                        'Actualizaciones de Viaje',
                        'Estados del viaje y conductor',
                        Icons.directions_car,
                        _tripUpdates,
                        (value) => setState(() => _tripUpdates = value),
                      ),
                      _buildSwitchTile(
                        'Promociones',
                        'Ofertas y descuentos especiales',
                        Icons.local_offer,
                        _promotions,
                        (value) => setState(() => _promotions = value),
                      ),
                      _buildSwitchTile(
                        'Noticias y Actualizaciones',
                        'Novedades de la plataforma',
                        Icons.newspaper,
                        _newsUpdates,
                        (value) => setState(() => _newsUpdates = value),
                      ),
                    ],
                  ),
                  
                  // Privacy section
                  _buildSection(
                    'Privacidad',
                    Icons.privacy_tip,
                    Colors.purple,
                    [
                      _buildSwitchTile(
                        'Compartir Ubicación',
                        'Compartir ubicación durante viajes',
                        Icons.share_location,
                        _shareLocation,
                        (value) => setState(() => _shareLocation = value),
                      ),
                      _buildSwitchTile(
                        'Compartir Viajes',
                        'Permitir que otros vean tus viajes',
                        Icons.share,
                        _shareTrips,
                        (value) => setState(() => _shareTrips = value),
                      ),
                      _buildSwitchTile(
                        'Análisis de Uso',
                        'Ayudar a mejorar la app',
                        Icons.analytics,
                        _analytics,
                        (value) => setState(() => _analytics = value),
                      ),
                      _buildSwitchTile(
                        'Reportes de Errores',
                        'Enviar reportes automáticos',
                        Icons.bug_report,
                        _crashReports,
                        (value) => setState(() => _crashReports = value),
                      ),
                      Divider(),
                      _buildActionTile(
                        'Ver Política de Privacidad',
                        'Consulta cómo manejamos tus datos',
                        Icons.policy,
                        _showPrivacyPolicy,
                      ),
                      _buildActionTile(
                        'Descargar Mis Datos',
                        'Obtener copia de tu información',
                        Icons.download,
                        _downloadData,
                      ),
                    ],
                  ),
                  
                  // Security section
                  _buildSection(
                    'Seguridad',
                    Icons.security,
                    ModernTheme.error,
                    [
                      _buildSwitchTile(
                        'Autenticación Biométrica',
                        'Usar huella dactilar o Face ID',
                        Icons.fingerprint,
                        _biometricAuth,
                        (value) => setState(() => _biometricAuth = value),
                      ),
                      _buildSwitchTile(
                        'Autenticación de Dos Factores',
                        'Seguridad adicional para tu cuenta',
                        Icons.security,
                        _twoFactorAuth,
                        (value) => setState(() => _twoFactorAuth = value),
                      ),
                      _buildAutoLockTile(),
                      Divider(),
                      _buildActionTile(
                        'Cambiar Contraseña',
                        'Actualizar tu contraseña',
                        Icons.lock,
                        _changePassword,
                      ),
                      _buildActionTile(
                        'Dispositivos Conectados',
                        'Ver sesiones activas',
                        Icons.devices,
                        _showConnectedDevices,
                      ),
                    ],
                  ),
                  
                  // App preferences
                  _buildSection(
                    'Preferencias de la App',
                    Icons.tune,
                    ModernTheme.oasisGreen,
                    [
                      _buildSwitchTile(
                        'Actualización Automática',
                        'Descargar actualizaciones automáticamente',
                        Icons.system_update,
                        _autoUpdate,
                        (value) => setState(() => _autoUpdate = value),
                      ),
                      _buildSwitchTile(
                        'Mapas Sin Conexión',
                        'Descargar mapas para uso offline',
                        Icons.map,
                        _offlineMaps,
                        (value) => setState(() => _offlineMaps = value),
                      ),
                      _buildMapStyleTile(),
                      _buildSwitchTile(
                        'Efectos de Sonido',
                        'Reproducir sonidos en la app',
                        Icons.volume_up,
                        _soundEffects,
                        (value) => setState(() => _soundEffects = value),
                      ),
                      _buildSwitchTile(
                        'Vibración',
                        'Retroalimentación háptica',
                        Icons.vibration,
                        _hapticFeedback,
                        (value) => setState(() => _hapticFeedback = value),
                      ),
                    ],
                  ),
                  
                  // Data & Storage
                  _buildSection(
                    'Datos y Almacenamiento',
                    Icons.storage,
                    Colors.teal,
                    [
                      _buildSwitchTile(
                        'Sincronizar Solo con Wi-Fi',
                        'Ahorrar datos móviles',
                        Icons.wifi,
                        _syncOnWiFiOnly,
                        (value) => setState(() => _syncOnWiFiOnly = value),
                      ),
                      _buildSwitchTile(
                        'Comprimir Imágenes',
                        'Reducir calidad para ahorrar espacio',
                        Icons.compress,
                        _compressImages,
                        (value) => setState(() => _compressImages = value),
                      ),
                      _buildInfoTile(
                        'Tamaño de Caché',
                        _cacheSize,
                        Icons.folder,
                      ),
                      Divider(),
                      _buildActionTile(
                        'Limpiar Caché',
                        'Liberar espacio de almacenamiento',
                        Icons.cleaning_services,
                        _clearCache,
                      ),
                      _buildActionTile(
                        'Gestionar Almacenamiento',
                        'Ver uso detallado del espacio',
                        Icons.pie_chart,
                        _manageStorage,
                      ),
                    ],
                  ),
                  
                  // Support & About
                  _buildSection(
                    'Soporte y Acerca de',
                    Icons.help,
                    Colors.indigo,
                    [
                      _buildActionTile(
                        'Centro de Ayuda',
                        'Preguntas frecuentes y tutoriales',
                        Icons.help_center,
                        _openHelpCenter,
                      ),
                      _buildActionTile(
                        'Contactar Soporte',
                        'Obtener ayuda personalizada',
                        Icons.support_agent,
                        _contactSupport,
                      ),
                      _buildActionTile(
                        'Reportar Problema',
                        'Informar errores o sugerencias',
                        Icons.report,
                        _reportIssue,
                      ),
                      Divider(),
                      _buildActionTile(
                        'Acerca de la App',
                        'Versión e información legal',
                        Icons.info,
                        _showAbout,
                      ),
                      _buildActionTile(
                        'Calificar la App',
                        'Ayúdanos con tu opinión',
                        Icons.star_rate,
                        _rateApp,
                      ),
                    ],
                  ),
                  
                  // Account management
                  _buildSection(
                    'Gestión de Cuenta',
                    Icons.account_circle,
                    Colors.grey,
                    [
                      _buildActionTile(
                        'Cerrar Sesión',
                        'Salir de tu cuenta',
                        Icons.logout,
                        _logout,
                        color: ModernTheme.warning,
                      ),
                      _buildActionTile(
                        'Eliminar Cuenta',
                        'Borrar permanentemente tu cuenta',
                        Icons.delete_forever,
                        _deleteAccount,
                        color: ModernTheme.error,
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 32),
                  
                  // App version
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Oasis Taxi v1.0.0 (Build 100)',
                      style: TextStyle(
                        color: ModernTheme.textSecondary,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildSection(String title, IconData icon, Color color, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16),
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
          child: Column(children: children),
        ),
      ],
    );
  }
  
  Widget _buildSwitchTile(String title, String subtitle, IconData icon, bool value, Function(bool) onChanged) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: ModernTheme.oasisGreen, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: ModernTheme.textSecondary),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
      ),
    );
  }
  
  Widget _buildActionTile(String title, String subtitle, IconData icon, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? ModernTheme.primaryBlue).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color ?? ModernTheme.primaryBlue, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: ModernTheme.textSecondary),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
  
  Widget _buildInfoTile(String title, String value, IconData icon) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ModernTheme.textSecondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: ModernTheme.textSecondary, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      trailing: Text(
        value,
        style: TextStyle(
          color: ModernTheme.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  Widget _buildLanguageTile() {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.language, color: ModernTheme.oasisGreen, size: 20),
      ),
      title: Text(
        'Idioma',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _language == 'es' ? 'Español' : 'English',
        style: TextStyle(fontSize: 12, color: ModernTheme.textSecondary),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16),
      onTap: _showLanguageDialog,
    );
  }
  
  Widget _buildCurrencyTile() {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.attach_money, color: ModernTheme.oasisGreen, size: 20),
      ),
      title: Text(
        'Moneda',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _currency == 'PEN' ? 'Soles (S/)' : 'Dólares (\$)',
        style: TextStyle(fontSize: 12, color: ModernTheme.textSecondary),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16),
      onTap: _showCurrencyDialog,
    );
  }
  
  Widget _buildAutoLockTile() {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ModernTheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.lock_clock, color: ModernTheme.error, size: 20),
      ),
      title: Text(
        'Bloqueo Automático',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        'Bloquear después de $_autoLockTime minutos',
        style: TextStyle(fontSize: 12, color: ModernTheme.textSecondary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.remove, size: 20),
            onPressed: () {
              if (_autoLockTime > 1) {
                setState(() => _autoLockTime--);
              }
            },
          ),
          Text('$_autoLockTime'),
          IconButton(
            icon: Icon(Icons.add, size: 20),
            onPressed: () {
              setState(() => _autoLockTime++);
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildMapStyleTile() {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.map, color: ModernTheme.oasisGreen, size: 20),
      ),
      title: Text(
        'Estilo de Mapa',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _getMapStyleText(),
        style: TextStyle(fontSize: 12, color: ModernTheme.textSecondary),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16),
      onTap: _showMapStyleDialog,
    );
  }
  
  String _getMapStyleText() {
    switch (_mapStyle) {
      case 'standard':
        return 'Estándar';
      case 'satellite':
        return 'Satélite';
      case 'terrain':
        return 'Terreno';
      case 'hybrid':
        return 'Híbrido';
      default:
        return 'Estándar';
    }
  }
  
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Seleccionar Idioma'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Radio<String>(
                value: 'es',
                groupValue: _language,
                onChanged: (value) {
                  setState(() => _language = value!);
                  Navigator.pop(context);
                },
              ),
              title: Text('Español'),
              onTap: () {
                setState(() => _language = 'es');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Radio<String>(
                value: 'en',
                groupValue: _language,
                onChanged: (value) {
                  setState(() => _language = value!);
                  Navigator.pop(context);
                },
              ),
              title: Text('English'),
              onTap: () {
                setState(() => _language = 'en');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _showCurrencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Seleccionar Moneda'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Radio<String>(
                value: 'PEN',
                groupValue: _currency,
                onChanged: (value) {
                  setState(() => _currency = value!);
                  Navigator.pop(context);
                },
              ),
              title: Text('Soles Peruanos (S/)'),
              onTap: () {
                setState(() => _currency = 'PEN');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Radio<String>(
                value: 'USD',
                groupValue: _currency,
                onChanged: (value) {
                  setState(() => _currency = value!);
                  Navigator.pop(context);
                },
              ),
              title: Text('Dólares Americanos (\$)'),
              onTap: () {
                setState(() => _currency = 'USD');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _showMapStyleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Estilo de Mapa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Radio<String>(
                value: 'standard',
                groupValue: _mapStyle,
                onChanged: (value) {
                  setState(() => _mapStyle = value!);
                  Navigator.pop(context);
                },
              ),
              title: Text('Estándar'),
              onTap: () {
                setState(() => _mapStyle = 'standard');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Radio<String>(
                value: 'satellite',
                groupValue: _mapStyle,
                onChanged: (value) {
                  setState(() => _mapStyle = value!);
                  Navigator.pop(context);
                },
              ),
              title: Text('Satélite'),
              onTap: () {
                setState(() => _mapStyle = 'satellite');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Radio<String>(
                value: 'terrain',
                groupValue: _mapStyle,
                onChanged: (value) {
                  setState(() => _mapStyle = value!);
                  Navigator.pop(context);
                },
              ),
              title: Text('Terreno'),
              onTap: () {
                setState(() => _mapStyle = 'terrain');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Radio<String>(
                value: 'hybrid',
                groupValue: _mapStyle,
                onChanged: (value) {
                  setState(() => _mapStyle = value!);
                  Navigator.pop(context);
                },
              ),
              title: Text('Híbrido'),
              onTap: () {
                setState(() => _mapStyle = 'hybrid');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _resetToDefaults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restablecer Configuración'),
        content: Text('¿Estás seguro de que deseas restablecer todas las configuraciones a sus valores predeterminados?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _notificationsEnabled = true;
                _locationServices = true;
                _darkMode = false;
                _language = 'es';
                _currency = 'PEN';
                // Reset all other settings to defaults...
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Configuración restablecida'),
                  backgroundColor: ModernTheme.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.error,
            ),
            child: Text('Restablecer'),
          ),
        ],
      ),
    );
  }
  
  void _showPrivacyPolicy() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Abriendo política de privacidad...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _downloadData() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Iniciando descarga de datos...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _changePassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Redirigiendo a cambio de contraseña...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _showConnectedDevices() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mostrando dispositivos conectados...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _clearCache() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Limpiar Caché'),
        content: Text('Esto liberará $_cacheSize de espacio. ¿Continuar?'),
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
                  content: Text('Caché limpiado exitosamente'),
                  backgroundColor: ModernTheme.success,
                ),
              );
              setState(() => _cacheSize = '0 MB');
            },
            child: Text('Limpiar'),
          ),
        ],
      ),
    );
  }
  
  void _manageStorage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Abriendo gestión de almacenamiento...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _openHelpCenter() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Abriendo centro de ayuda...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _contactSupport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contactando con soporte...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _reportIssue() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Abriendo reporte de problemas...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _showAbout() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mostrando información de la app...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _rateApp() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Abriendo tienda de aplicaciones...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cerrar Sesión'),
        content: Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.warning,
            ),
            child: Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }
  
  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Eliminar Cuenta',
          style: TextStyle(color: ModernTheme.error),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Esta acción es irreversible. Se eliminará:'),
            SizedBox(height: 8),
            Text('• Todos tus datos personales'),
            Text('• Historial de viajes'),
            Text('• Métodos de pago'),
            Text('• Calificaciones y comentarios'),
            SizedBox(height: 16),
            Text(
              '¿Estás completamente seguro?',
              style: TextStyle(fontWeight: FontWeight.bold),
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
                  content: Text('Solicitud de eliminación enviada'),
                  backgroundColor: ModernTheme.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.error,
            ),
            child: Text('Eliminar Cuenta'),
          ),
        ],
      ),
    );
  }
}