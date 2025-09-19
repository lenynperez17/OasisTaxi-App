import 'package:flutter/material.dart';
import '../../core/theme/modern_theme.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: ModernTheme.oasisGreen,
        elevation: 0,
        title: const Text(
          'Términos y Condiciones',
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
                    Icons.description,
                    size: 48,
                    color: Colors.white,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Términos y Condiciones',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'OasisTaxi Perú - Vigente desde Enero 2025',
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

            // Contenido
            _buildSection('1. ACEPTACIÓN DE LOS TÉRMINOS',
                'Al descargar, instalar o utilizar la aplicación OasisTaxi, usted acepta cumplir con estos Términos y Condiciones. Si no está de acuerdo con algún término, no utilice nuestros servicios.'),

            _buildSection('2. DESCRIPCIÓN DEL SERVICIO',
                'OasisTaxi es una plataforma tecnológica que conecta pasajeros con conductores independientes para servicios de transporte. No somos una empresa de transporte, sino una plataforma de intermediación tecnológica.'),

            _buildSection(
                '3. REGISTRO Y CUENTA DE USUARIO',
                '• Debe proporcionar información veraz y actualizada\n'
                    '• Es responsable de mantener la confidencialidad de su cuenta\n'
                    '• Debe ser mayor de 18 años para registrarse como conductor\n'
                    '• Se prohíbe crear múltiples cuentas'),

            _buildSection(
                '4. PARA CONDUCTORES',
                '• Debe poseer licencia de conducir vigente\n'
                    '• Vehículo con SOAT y revisión técnica actualizada\n'
                    '• Cumplir con las normas de tránsito del Perú\n'
                    '• Mantener el vehículo en buenas condiciones\n'
                    '• Tratar con respeto a los pasajeros'),

            _buildSection(
                '5. PARA PASAJEROS',
                '• Proporcionar información correcta del destino\n'
                    '• Estar presente en el punto de recojo acordado\n'
                    '• Tratar con respeto al conductor\n'
                    '• Pagar la tarifa acordada'),

            _buildSection('6. NEGOCIACIÓN DE PRECIOS',
                'OasisTaxi permite la negociación de precios entre conductores y pasajeros. Las tarifas acordadas son vinculantes para ambas partes. La plataforma no interviene en las negociaciones.'),

            _buildSection(
                '7. PAGOS Y FACTURACIÓN',
                '• Los pagos se realizan según el método acordado\n'
                    '• OasisTaxi cobra una comisión del 20% a los conductores\n'
                    '• Los reembolsos se procesan según nuestra política\n'
                    '• Las facturas electrónicas están disponibles bajo solicitud'),

            _buildSection(
                '8. RESPONSABILIDADES',
                'Los conductores son responsables de:\n'
                    '• Su comportamiento y el de su vehículo\n'
                    '• Los daños causados durante el servicio\n'
                    '• El cumplimiento de las normas de tránsito\n\n'
                    'OasisTaxi no se responsabiliza por:\n'
                    '• Accidentes durante el servicio\n'
                    '• Pérdida de objetos personales\n'
                    '• Disputas entre usuarios'),

            _buildSection(
                '9. PROHIBICIONES',
                'Se prohíbe:\n'
                    '• Uso de la plataforma para actividades ilegales\n'
                    '• Comportamiento discriminatorio o abusivo\n'
                    '• Manipular el sistema de calificaciones\n'
                    '• Compartir credenciales de acceso'),

            _buildSection('10. SUSPENSIÓN Y TERMINACIÓN',
                'OasisTaxi se reserva el derecho de suspender o cancelar cuentas que violen estos términos, sin previo aviso y sin reembolso de pagos realizados.'),

            _buildSection('11. PRIVACIDAD',
                'El manejo de datos personales se rige por nuestra Política de Privacidad, la cual forma parte integral de estos términos.'),

            _buildSection('12. MODIFICACIONES',
                'OasisTaxi puede modificar estos términos en cualquier momento. Las modificaciones entran en vigor al ser publicadas en la aplicación. El uso continuado constituye aceptación de los nuevos términos.'),

            _buildSection('13. LEY APLICABLE',
                'Estos términos se rigen por las leyes de la República del Perú. Cualquier disputa será resuelta en los tribunales de Lima, Perú.'),

            _buildSection(
                '14. CONTACTO',
                'Para consultas sobre estos términos:\n'
                    'Email: legal@oasistaxiapp.com\n'
                    'Teléfono: +51 999 999 999\n'
                    'Dirección: Lima, Perú'),

            const SizedBox(height: 32),

            // Footer
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
                  Text(
                    '© 2025 OasisTaxi Perú',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: ModernTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
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
