import 'package:flutter/material.dart';
import '../../core/theme/modern_theme.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: ModernTheme.oasisGreen,
        elevation: 0,
        title: const Text(
          'Centro de Ayuda',
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
            // Búsqueda rápida
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: ModernTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: ModernTheme.cardShadow,
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.help_center,
                    size: 48,
                    color: Colors.white,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '¿En qué podemos ayudarte?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Encuentra respuestas a las preguntas más frecuentes',
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

            // Preguntas frecuentes
            const Text(
              'Preguntas Frecuentes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ModernTheme.textPrimary,
              ),
            ),

            const SizedBox(height: 16),

            // FAQ Items
            _buildFAQSection('Para Pasajeros', [
              {
                'question': '¿Cómo solicitar un viaje?',
                'answer':
                    'Abre la app, ingresa tu destino, selecciona el tipo de vehículo y confirma tu solicitud. Recibirás notificaciones cuando un conductor acepte tu viaje.'
              },
              {
                'question': '¿Puedo negociar el precio?',
                'answer':
                    'Sí, OasisTaxi permite negociar precios con los conductores antes de confirmar el viaje. Esta es una característica única de nuestra plataforma.'
              },
              {
                'question': '¿Cómo pago mi viaje?',
                'answer':
                    'Puedes pagar en efectivo, con tarjeta a través de MercadoPago, o usando tu wallet digital dentro de la app.'
              },
              {
                'question': '¿Qué hago en caso de emergencia?',
                'answer':
                    'Usa el botón SOS en la pantalla de viaje. Se enviará tu ubicación a contactos de emergencia y a las autoridades si es necesario.'
              },
            ]),

            _buildFAQSection('Para Conductores', [
              {
                'question': '¿Cómo me registro como conductor?',
                'answer':
                    'Completa el registro con tus datos personales, sube los documentos requeridos (licencia, SOAT, revisión técnica) y espera la verificación del administrador.'
              },
              {
                'question': '¿Cuál es la comisión por viaje?',
                'answer':
                    'La comisión estándar es del 20% por viaje completado. Esta comisión puede variar según promociones especiales.'
              },
              {
                'question': '¿Cuándo recibo mis ganancias?',
                'answer':
                    'Las ganancias se acumulan en tu wallet digital. Puedes solicitar retiros cuando gustes, con un mínimo de S/ 50.'
              },
            ]),

            _buildFAQSection('Seguridad', [
              {
                'question': '¿Cómo verifican a los conductores?',
                'answer':
                    'Todos los conductores pasan por un proceso de verificación que incluye documentos de identidad, licencia de conducir, antecedentes penales y documentos del vehículo.'
              },
              {
                'question': '¿Mis datos están seguros?',
                'answer':
                    'Sí, utilizamos encriptación de extremo a extremo para proteger tus datos personales y de pago. Nunca compartimos información sensible con terceros.'
              },
            ]),

            _buildFAQSection('Pagos y Facturación', [
              {
                'question': '¿Puedo obtener factura?',
                'answer':
                    'Sí, puedes solicitar factura electrónica desde el historial de viajes. Se enviará a tu correo registrado.'
              },
              {
                'question': '¿Qué métodos de pago aceptan?',
                'answer':
                    'Aceptamos efectivo, tarjetas de débito/crédito (Visa, Mastercard) a través de MercadoPago, y wallet digital OasisTaxi.'
              },
            ]),

            const SizedBox(height: 32),

            // Contacto adicional
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: ModernTheme.cardShadow,
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.support_agent,
                    size: 48,
                    color: ModernTheme.oasisGreen,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '¿No encuentras lo que buscas?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Contáctanos directamente y te ayudaremos',
                    style: TextStyle(
                      color: ModernTheme.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _contactWhatsApp(context),
                          icon: const Icon(Icons.phone),
                          label: const Text('WhatsApp'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ModernTheme.oasisGreen,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _contactEmail(context),
                          icon: const Icon(Icons.email),
                          label: const Text('Email'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ModernTheme.primaryBlue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
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

  Widget _buildFAQSection(String title, List<Map<String, String>> faqs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ModernTheme.oasisGreen,
          ),
        ),
        const SizedBox(height: 12),
        ...faqs.map((faq) => _buildFAQItem(faq['question']!, faq['answer']!)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: const TextStyle(
                color: ModernTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _contactWhatsApp(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Abriendo WhatsApp: +51 999 999 999'),
        backgroundColor: ModernTheme.oasisGreen,
      ),
    );
  }

  void _contactEmail(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Abriendo email: soporte@oasistaxiapp.com'),
        backgroundColor: ModernTheme.primaryBlue,
      ),
    );
  }
}
