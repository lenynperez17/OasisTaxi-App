import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/notification_provider.dart';
import '../../models/notification_types.dart';
import '../../utils/app_logger.dart';

/// Pantalla de notificaciones completa
/// ✅ IMPLEMENTACIÓN REAL COMPLETA
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  NotificationsScreenState createState() => NotificationsScreenState();
}

class NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('NotificationsScreen', 'initState');
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Notificaciones',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.oasisWhite,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, child) {
              return PopupMenuButton<String>(
                onSelected: (value) => _handleMenuSelection(value, provider),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'mark_all_read',
                    child: Row(
                      children: [
                        Icon(Icons.mark_email_read,
                            color: AppColors.oasisGreen),
                        const SizedBox(width: 8),
                        Text('Marcar todas como leídas'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'clear_all',
                    child: Row(
                      children: [
                        Icon(Icons.clear_all, color: AppColors.error),
                        const SizedBox(width: 8),
                        Text('Limpiar todas'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.oasisGreen,
          labelColor: AppColors.oasisGreen,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            Consumer<NotificationProvider>(
              builder: (context, provider, child) {
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Todas'),
                      if (provider.unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            provider.unreadCount.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            Tab(text: 'No leídas'),
            Tab(text: 'Configuración'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllNotificationsTab(),
          _buildUnreadNotificationsTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  void _handleMenuSelection(String value, NotificationProvider provider) {
    switch (value) {
      case 'mark_all_read':
        provider.markAllAsRead();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Todas las notificaciones marcadas como leídas'),
            backgroundColor: AppColors.success,
          ),
        );
        break;
      case 'clear_all':
        _showClearAllDialog(provider);
        break;
    }
  }

  void _showClearAllDialog(NotificationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Limpiar notificaciones'),
        content: Text(
            '¿Estás seguro de que quieres eliminar todas las notificaciones?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.clearAllNotifications();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Todas las notificaciones eliminadas'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildAllNotificationsTab() {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        if (provider.notifications.isEmpty) {
          return _buildEmptyState('No tienes notificaciones');
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: provider.notifications.length,
          itemBuilder: (context, index) {
            final notification = provider.notifications[index];
            return _buildNotificationCard(notification, provider);
          },
        );
      },
    );
  }

  Widget _buildUnreadNotificationsTab() {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        final unreadNotifications = provider.unreadNotifications;

        if (unreadNotifications.isEmpty) {
          return _buildEmptyState('No tienes notificaciones sin leer');
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: unreadNotifications.length,
          itemBuilder: (context, index) {
            final notification = unreadNotifications[index];
            return _buildNotificationCard(notification, provider);
          },
        );
      },
    );
  }

  Widget _buildSettingsTab() {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        return ListView(
          padding: EdgeInsets.all(16),
          children: [
            _buildSettingsSection(
              'General',
              [
                _buildSwitchTile(
                  'Notificaciones habilitadas',
                  'Recibir notificaciones push',
                  provider.notificationsEnabled,
                  (value) => provider.setNotificationsEnabled(value),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSettingsSection(
              'Suscripciones',
              [
                _buildTopicTile('Usuarios generales', 'all_users', provider),
                _buildTopicTile(
                    'Actualizaciones de la app', 'app_updates', provider),
                _buildTopicTile('Pasajeros', 'passengers', provider),
                _buildTopicTile('Conductores', 'drivers', provider),
                _buildTopicTile('Administradores', 'admins', provider),
                _buildTopicTile(
                    'Promociones', 'passenger_promotions', provider),
                _buildTopicTile(
                    'Alertas del sistema', 'system_alerts', provider),
              ],
            ),
            const SizedBox(height: 24),
            _buildSettingsSection(
              'Información',
              [
                _buildInfoTile(
                    'Token FCM', provider.fcmToken ?? 'No disponible'),
                _buildInfoTile(
                    'Estado',
                    provider.isInitialized
                        ? 'Inicializado'
                        : 'No inicializado'),
                _buildInfoTile('Total de notificaciones',
                    provider.notifications.length.toString()),
                _buildInfoTile('No leídas', provider.unreadCount.toString()),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildNotificationCard(
      NotificationData notification, NotificationProvider provider) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: notification.isRead ? 1 : 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (!notification.isRead) {
            provider.markAsRead(notification.id);
          }
        },
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: notification.isRead
                ? null
                : Border.all(
                    color: AppColors.oasisGreen.withValues(alpha: 0.3),
                    width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getNotificationTypeColor(notification.type)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getNotificationTypeIcon(notification.type),
                      color: _getNotificationTypeColor(notification.type),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: notification.isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm')
                              .format(notification.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!notification.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.oasisGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        provider.removeNotification(notification.id);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: AppColors.error),
                            const SizedBox(width: 8),
                            Text('Eliminar'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                notification.body,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              // Imagen removida - no disponible en modelo demo
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
      String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      thumbColor: WidgetStateProperty.all(AppColors.oasisGreen),
    );
  }

  Widget _buildTopicTile(
      String title, String topic, NotificationProvider provider) {
    final isSubscribed = provider.topicSubscriptions[topic] ?? false;
    return SwitchListTile(
      title: Text(title),
      subtitle: Text('Suscripción a $topic'),
      value: isSubscribed,
      onChanged: (value) {
        if (value) {
          provider.subscribeToTopic(topic);
        } else {
          provider.unsubscribeFromTopic(topic);
        }
      },
      thumbColor: WidgetStateProperty.all(AppColors.oasisGreen),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return ListTile(
      title: Text(title),
      subtitle: Text(
        value,
        style: TextStyle(fontFamily: 'monospace'),
      ),
      dense: true,
    );
  }

  Color _getNotificationTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.general:
        return AppColors.info;
      case NotificationType.tripRequest:
        return AppColors.warning;
      case NotificationType.tripAccepted:
        return AppColors.success;
      case NotificationType.tripStarted:
        return AppColors.oasisGreen;
      case NotificationType.tripCancelled:
        return AppColors.error;
      case NotificationType.tripCompleted:
        return AppColors.oasisGreen;
      case NotificationType.driverArrived:
        return AppColors.info;
      case NotificationType.payment:
        return AppColors.oasisGreen;
      case NotificationType.promotion:
        return AppColors.warning;
      case NotificationType.support:
        return AppColors.info;
      case NotificationType.system:
        return AppColors.textSecondary;
      default:
        return AppColors.info;
    }
  }

  IconData _getNotificationTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.general:
        return Icons.notifications;
      case NotificationType.tripRequest:
        return Icons.car_rental;
      case NotificationType.tripAccepted:
        return Icons.check_circle;
      case NotificationType.tripStarted:
        return Icons.play_arrow;
      case NotificationType.tripCancelled:
        return Icons.cancel;
      case NotificationType.tripCompleted:
        return Icons.flag;
      case NotificationType.driverArrived:
        return Icons.location_on;
      case NotificationType.payment:
        return Icons.payment;
      case NotificationType.promotion:
        return Icons.local_offer;
      case NotificationType.support:
        return Icons.support_agent;
      case NotificationType.system:
        return Icons.settings;
      default:
        return Icons.notifications;
    }
  }
}
