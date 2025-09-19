import 'package:flutter/material.dart';
import '../../core/theme/modern_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: ModernTheme.oasisGreen,
        elevation: 0,
        title: const Text(
          'Política de Privacidad',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: ModernTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: ModernTheme.cardShadow,
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.privacy_tip,
                    size: 48,
                    color: Colors.white,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Política de Privacidad',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tu privacidad es importante para nosotros',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildSection(
                '1. INFORMACIÓN QUE RECOPILAMOS',
                'Recopilamos la siguiente información:\n\n'
                    'Información personal:\n'
                    '• Nombre completo y documento de identidad\n'
                    '• Número de teléfono y correo electrónico\n'
                    '• Fotografía de perfil (opcional)\n'
                    '• Datos de contacto de emergencia\n\n'
                    'Información del vehículo (conductores):\n'
                    '• Licencia de conducir y documentos del vehículo\n'
                    '• SOAT y revisión técnica\n'
                    '• Antecedentes penales y policiales\n\n'
                    'Información de ubicación:\n'
                    '• Ubicación GPS durante el uso del servicio\n'
                    '• Historial de viajes y rutas\n\n'
                    'Información de pago:\n'
                    '• Datos de tarjetas de crédito/débito (encriptados)\n'
                    '• Historial de transacciones'),

            _buildSection(
                '2. CÓMO USAMOS TU INFORMACIÓN',
                'Utilizamos tu información para:\n\n'
                    '• Proporcionar y mejorar nuestros servicios\n'
                    '• Conectar pasajeros con conductores\n'
                    '• Procesar pagos y facturación\n'
                    '• Verificar la identidad de usuarios\n'
                    '• Enviar notificaciones del servicio\n'
                    '• Brindar soporte al cliente\n'
                    '• Cumplir con obligaciones legales\n'
                    '• Prevenir fraudes y actividades ilegales'),

            _buildSection(
                '3. COMPARTIR INFORMACIÓN',
                'Solo compartimos tu información en estas situaciones:\n\n'
                    'Con otros usuarios:\n'
                    '• Nombre y foto de perfil durante el servicio\n'
                    '• Calificaciones y comentarios\n'
                    '• Información de contacto necesaria para el viaje\n\n'
                    'Con terceros:\n'
                    '• Procesadores de pagos (MercadoPago)\n'
                    '• Servicios de mapas y navegación (Google Maps)\n'
                    '• Servicios de mensajería y notificaciones\n\n'
                    'Por obligación legal:\n'
                    '• Cuando lo requiera la ley peruana\n'
                    '• Para proteger derechos y seguridad\n'
                    '• En caso de emergencias'),

            _buildSection(
                '4. SEGURIDAD DE DATOS',
                'Implementamos medidas de seguridad avanzadas:\n\n'
                    '• Encriptación de extremo a extremo\n'
                    '• Servidores seguros con certificados SSL\n'
                    '• Autenticación de dos factores disponible\n'
                    '• Monitoreo continuo de seguridad\n'
                    '• Acceso restringido a datos sensibles\n'
                    '• Auditorías regulares de seguridad'),

            _buildSection(
                '5. RETENCIÓN DE DATOS',
                'Conservamos tu información durante:\n\n'
                    '• Datos de cuenta: Mientras mantengas tu cuenta activa\n'
                    '• Historial de viajes: 5 años desde el último viaje\n'
                    '• Datos de pago: Según regulaciones bancarias\n'
                    '• Documentos de verificación: Según normativa de transporte\n'
                    '• Logs de seguridad: 2 años máximo\n\n'
                    'Puedes solicitar la eliminación de tus datos contactándonos.'),

            _buildSection(
                '6. TUS DERECHOS',
                'Tienes derecho a:\n\n'
                    '• Acceder a tu información personal\n'
                    '• Rectificar datos incorrectos\n'
                    '• Solicitar eliminación de datos\n'
                    '• Portar tus datos a otros servicios\n'
                    '• Revocar consentimientos otorgados\n'
                    '• Presentar quejas ante autoridades\n\n'
                    'Para ejercer estos derechos, contáctanos en:\nprivacidad@oasistaxiapp.com'),

            _buildSection(
                '7. COOKIES Y TECNOLOGÍAS SIMILARES',
                'Utilizamos cookies para:\n\n'
                    '• Mantener tu sesión activa\n'
                    '• Recordar preferencias\n'
                    '• Analizar uso de la aplicación\n'
                    '• Mejorar la experiencia del usuario\n\n'
                    'Puedes gestionar las cookies desde la configuración de tu dispositivo.'),

            _buildSection('8. MENORES DE EDAD',
                'Nuestros servicios están dirigidos a personas mayores de 18 años. No recopilamos intencionalmente información de menores de edad.'),

            _buildSection('9. TRANSFERENCIAS INTERNACIONALES',
                'Algunos de nuestros proveedores pueden procesar datos fuera del Perú. Garantizamos que cumplan con estándares de protección equivalentes.'),

            _buildSection('10. CAMBIOS A ESTA POLÍTICA',
                'Podemos actualizar esta política periódicamente. Te notificaremos sobre cambios significativos a través de la aplicación o por email.'),

            _buildSection(
                '11. CONTACTO',
                'Para consultas sobre privacidad:\n\n'
                    'Email: privacidad@oasistaxiapp.com\n'
                    'Teléfono: +51 999 999 999\n'
                    'Dirección: Lima, Perú\n\n'
                    'Oficial de Protección de Datos:\ndpo@oasistaxiapp.com'),

            const SizedBox(height: 32),

            // Footer con certificaciones
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: ModernTheme.cardShadow,
              ),
              child: const Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_user,
                        color: ModernTheme.oasisGreen,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Cumple con Ley N° 29733 - Protección de Datos Personales',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: ModernTheme.oasisGreen,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    '© 2025 OasisTaxi Perú',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: ModernTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Última actualización: Enero 2025',
                    style: TextStyle(
                      fontSize: 12,
                      color: ModernTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ModernTheme.oasisGreen,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: ModernTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
