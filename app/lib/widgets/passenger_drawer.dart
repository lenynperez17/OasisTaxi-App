import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../screens/shared/settings_screen.dart';
import '../providers/auth_provider.dart';
import '../utils/app_logger.dart';

class PassengerDrawer extends StatelessWidget {
  const PassengerDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Header del drawer
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                bottom: 20,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.oasisTurquoise,
                    AppColors.oasisTurquoiseLight,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar del usuario
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: AppColors.oasisTurquoise,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      final user = authProvider.currentUser;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? 'Usuario',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? 'Sin correo registrado',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IntrinsicWidth(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 14,
                          ),
                          const SizedBox(width: 3),
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, child) {
                              final user = authProvider.currentUser;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${user?.rating ?? 5.0}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      ' • ${user?.totalTrips ?? 0} viajes',
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.9),
                                        fontSize: 11,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Opciones del menú
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildMenuItem(
                    icon: Icons.person_outline,
                    title: 'Mi perfil',
                    onTap: () {
                      AppLogger.info('Botón mi perfil presionado');
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/profile');
                      AppLogger.info('Navegación a perfil ejecutada');
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.history,
                    title: 'Historial de viajes',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/trip-history');
                    },
                  ),
                  // _buildMenuItem(
                  //   icon: Icons.account_balance_wallet,
                  //   title: 'Mi Billetera',
                  //   onTap: () {
                  //     Navigator.pop(context);
                  //     Navigator.pushNamed(context, '/wallet');
                  //   },
                  // ),
                  _buildMenuItem(
                    icon: Icons.payment,
                    title: 'Métodos de pago',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                          context, '/passenger/payment-methods');
                    },
                  ),
                  // _buildMenuItem(
                  //   icon: Icons.local_offer,
                  //   title: 'Promociones',
                  //   badge: 'Nuevo',
                  //   badgeColor: Color(0xFF10B981),
                  //   onTap: () {
                  //     Navigator.pop(context);
                  //     Navigator.pushNamed(context, '/passenger/promotions'); // ELIMINADO
                  //   },
                  // ),
                  // _buildMenuItem(
                  //   icon: Icons.favorite,
                  //   title: 'Lugares favoritos',
                  //   onTap: () {
                  //     Navigator.pop(context);
                  //     Navigator.pushNamed(context, '/passenger/favorites'); // ELIMINADO
                  //   },
                  // ),
                  Divider(height: 1),
                  // _buildMenuItem(
                  //   icon: Icons.help_outline,
                  //   title: 'Ayuda y soporte',
                  //   onTap: () {
                  //     Navigator.pop(context);
                  //     Navigator.pushNamed(context, '/help'); // NO EXISTE
                  //   },
                  // ),
                  _buildMenuItem(
                    icon: Icons.info_outline,
                    title: 'Acerca de Oasis Taxi',
                    onTap: () {
                      Navigator.pop(context);
                      _showAboutDialog(context);
                    },
                  ),
                  // Botón de configuración - Solución simplificada
                  _buildMenuItem(
                    icon: Icons.settings_rounded,
                    title: 'Configuración',
                    onTap: () {
                      AppLogger.info('Botón configuración presionado');
                      // Cerrar el drawer primero
                      Navigator.pop(context);
                      // Navegar directamente con MaterialPageRoute (como el botón rojo que SÍ funciona)
                      Navigator.of(context)
                          .push(
                        MaterialPageRoute(
                          builder: (context) =>
                              SettingsScreen(userType: 'passenger'),
                        ),
                      )
                          .then((_) {
                        AppLogger.info('Navegación a configuración completada');
                      }).catchError((error) {
                        AppLogger.error('Error en navegación', error);
                      });
                    },
                  ),
                ],
              ),
            ),

            // Botón de cerrar sesión
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.logout,
                  color: Colors.red,
                ),
                title: Text(
                  'Cerrar sesión',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  _showLogoutDialog(context);
                },
              ),
            ),

            // Versión de la app
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Versión 1.0.0',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.oasisTurquoise),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: badge != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor ?? AppColors.oasisTurquoise,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.oasisTurquoise,
                    AppColors.oasisTurquoiseLight
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.local_taxi,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text('Oasis Taxi'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tu servicio de taxi confiable y seguro.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              'Versión: 1.0.0',
              style: TextStyle(color: Colors.grey[600]),
            ),
            Text(
              'Desarrollado por: Oasis Tech',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Cerrar sesión'),
        content: Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}
