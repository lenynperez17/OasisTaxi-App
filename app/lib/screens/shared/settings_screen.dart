import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../core/theme/modern_theme.dart';
import '../auth/modern_login_screen.dart';
import 'help_center_screen.dart';
import 'terms_conditions_screen.dart';
import 'privacy_policy_screen.dart';
import '../../utils/app_logger.dart';

class SettingsScreen extends StatefulWidget {
  final String? userType; // 'passenger', 'driver', 'admin'

  const SettingsScreen({super.key, this.userType});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Configuraciones esenciales
  bool _notificationsEnabled = true;
  bool _locationServices = true;

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle(
        'SettingsScreen', 'initState - UserType: ${widget.userType}');

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
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
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: ModernTheme.oasisGreen,
        elevation: 0,
        title: const Text(
          'Configuración',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Información del usuario
                  if (user != null) ...[
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: ModernTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color:
                                ModernTheme.oasisGreen.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.2),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName ?? 'Usuario',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.email ?? user.phoneNumber ?? '',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                if (widget.userType != null) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _getUserTypeLabel(widget.userType!),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Configuración general
                  _buildSection(
                    'General',
                    Icons.settings,
                    ModernTheme.primaryBlue,
                    [
                      _buildSwitchTile(
                        'Notificaciones',
                        'Recibir alertas de viajes y promociones',
                        Icons.notifications,
                        _notificationsEnabled,
                        (value) =>
                            setState(() => _notificationsEnabled = value),
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

                  // Seguridad
                  _buildSection(
                    'Seguridad',
                    Icons.security,
                    ModernTheme.error,
                    [
                      _buildActionTile(
                        'Cambiar Contraseña',
                        'Actualizar tu contraseña',
                        Icons.lock,
                        _changePassword,
                      ),
                    ],
                  ),

                  // Soporte
                  _buildSection(
                    'Soporte',
                    Icons.help,
                    Colors.indigo,
                    [
                      _buildActionTile(
                        'Centro de Ayuda',
                        'Preguntas frecuentes',
                        Icons.help_center,
                        _openHelpCenter,
                      ),
                      _buildActionTile(
                        'Contactar Soporte',
                        'Chat o llamada',
                        Icons.support_agent,
                        _contactSupport,
                      ),
                      _buildActionTile(
                        'Términos y Condiciones',
                        'Lee nuestros términos',
                        Icons.description,
                        _showTerms,
                      ),
                      _buildActionTile(
                        'Política de Privacidad',
                        'Cómo manejamos tus datos',
                        Icons.privacy_tip,
                        _showPrivacyPolicy,
                      ),
                    ],
                  ),

                  // Cuenta
                  _buildSection(
                    'Cuenta',
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

                  const SizedBox(height: 32),

                  // Versión de la app
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Oasis Taxi v1.0.0',
                      style: TextStyle(
                        color: ModernTheme.textSecondary,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getUserTypeLabel(String userType) {
    switch (userType) {
      case 'passenger':
        return 'Pasajero';
      case 'driver':
        return 'Conductor';
      case 'admin':
        return 'Administrador';
      default:
        return 'Usuario';
    }
  }

  Widget _buildSection(
      String title, IconData icon, Color color, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
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
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: ModernTheme.cardShadow,
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return ListTile(
      leading: Icon(icon, color: ModernTheme.textSecondary),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: ModernTheme.textSecondary,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? ModernTheme.textSecondary),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: ModernTheme.textSecondary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: ModernTheme.textSecondary,
      ),
      onTap: onTap,
    );
  }

  void _changePassword() {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Cambiar Contraseña'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña actual',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Nueva contraseña',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirmar nueva contraseña',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              currentPasswordController.dispose();
              newPasswordController.dispose();
              confirmPasswordController.dispose();
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text !=
                  confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Las contraseñas no coinciden'),
                    backgroundColor: ModernTheme.error,
                  ),
                );
                return;
              }

              if (newPasswordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('La contraseña debe tener al menos 6 caracteres'),
                    backgroundColor: ModernTheme.error,
                  ),
                );
                return;
              }

              try {
                // Re-autenticar primero con la contraseña actual
                final user = FirebaseAuth.instance.currentUser;
                if (user != null && user.email != null) {
                  final credential = EmailAuthProvider.credential(
                    email: user.email!,
                    password: currentPasswordController.text,
                  );

                  await user.reauthenticateWithCredential(credential);
                  await user.updatePassword(newPasswordController.text);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Contraseña actualizada correctamente'),
                        backgroundColor: ModernTheme.success,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: ModernTheme.error,
                    ),
                  );
                }
              } finally {
                currentPasswordController.dispose();
                newPasswordController.dispose();
                confirmPasswordController.dispose();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.oasisGreen,
            ),
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
  }

  void _openHelpCenter() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HelpCenterScreen(),
      ),
    );
  }

  void _contactSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Contactar Soporte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone, color: ModernTheme.oasisGreen),
              title: const Text('Llamar'),
              subtitle: const Text('+51 999 999 999'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Llamando a soporte...'),
                    backgroundColor: ModernTheme.oasisGreen,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: ModernTheme.primaryBlue),
              title: const Text('Chat en vivo'),
              subtitle: const Text('Disponible 24/7'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Iniciando chat...'),
                    backgroundColor: ModernTheme.primaryBlue,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.email, color: ModernTheme.warning),
              title: const Text('Email'),
              subtitle: const Text('soporte@oasistaxiapp.com'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Abriendo email...'),
                    backgroundColor: ModernTheme.warning,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTerms() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TermsConditionsScreen(),
      ),
    );
  }

  void _showPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PrivacyPolicyScreen(),
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              // Cerrar sesión con Firebase
              await FirebaseAuth.instance.signOut();

              // Limpiar provider de autenticación
              _handleLogoutNavigation();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.warning,
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Eliminar Cuenta'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning,
              color: ModernTheme.error,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'Esta acción es PERMANENTE y no se puede deshacer.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Se eliminarán todos tus datos, viajes, favoritos y configuraciones.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Por seguridad, contacta a soporte para eliminar tu cuenta'),
                  backgroundColor: ModernTheme.warning,
                  duration: Duration(seconds: 5),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.error,
            ),
            child: const Text('Eliminar Cuenta'),
          ),
        ],
      ),
    );
  }

  void _handleLogoutNavigation() {
    if (!mounted) return;
    context.read<app_auth.AuthProvider>().logout();

    // Navegar a la pantalla de login
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => ModernLoginScreen()),
      (route) => false,
    );
  }
}
