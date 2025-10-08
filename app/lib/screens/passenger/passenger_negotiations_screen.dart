import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/modern_theme.dart';
import '../../providers/price_negotiation_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/price_negotiation_model.dart';
import 'package:intl/intl.dart';

/// Pantalla de negociaciones para pasajeros
/// Muestra las negociaciones activas y las ofertas de conductores
class PassengerNegotiationsScreen extends StatefulWidget {
  const PassengerNegotiationsScreen({Key? key}) : super(key: key);

  @override
  State<PassengerNegotiationsScreen> createState() => _PassengerNegotiationsScreenState();
}

class _PassengerNegotiationsScreenState extends State<PassengerNegotiationsScreen> {
  @override
  void initState() {
    super.initState();
    _loadMyNegotiations();
  }

  Future<void> _loadMyNegotiations() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final provider = Provider.of<PriceNegotiationProvider>(context, listen: false);

    if (authProvider.currentUser != null) {
      await provider.loadUserNegotiations(authProvider.currentUser!.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Negociaciones'),
        backgroundColor: ModernTheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMyNegotiations,
          ),
        ],
      ),
      body: Consumer<PriceNegotiationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final myNegotiations = provider.userNegotiations
              .where((n) =>
                  n.status == NegotiationStatus.waiting ||
                  n.status == NegotiationStatus.negotiating)
              .toList();

          if (myNegotiations.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: _loadMyNegotiations,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: myNegotiations.length,
              itemBuilder: (context, index) {
                return _buildNegotiationCard(myNegotiations[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No tienes negociaciones activas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Solicita un viaje para comenzar',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildNegotiationCard(PriceNegotiation negotiation) {
    final hasOffers = negotiation.driverOffers.isNotEmpty;
    final bestOffer = negotiation.bestOffer;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Header con estado
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(negotiation.status).withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _getStatusIcon(negotiation.status),
                      color: _getStatusColor(negotiation.status),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getStatusText(negotiation.status),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(negotiation.status),
                      ),
                    ),
                  ],
                ),
                _buildTimer(negotiation),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rutas
                _buildLocationRow(
                  icon: Icons.radio_button_checked,
                  color: ModernTheme.success,
                  label: 'Origen',
                  address: negotiation.pickup.address,
                ),
                const SizedBox(height: 12),
                _buildLocationRow(
                  icon: Icons.location_on,
                  color: ModernTheme.error,
                  label: 'Destino',
                  address: negotiation.destination.address,
                ),
                const SizedBox(height: 16),

                // Tu precio
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ModernTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tu precio ofrecido:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'S/. ${negotiation.offeredPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ModernTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                if (hasOffers) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ofertas recibidas (${negotiation.driverOffers.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (bestOffer != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ModernTheme.success.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.trending_down,
                                size: 16,
                                color: ModernTheme.success,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Mejor: S/. ${bestOffer.acceptedPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: ModernTheme.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Lista de ofertas
                  ...negotiation.driverOffers.map((offer) =>
                    _buildOfferCard(offer, negotiation.id),
                  ),
                ],

                if (!hasOffers) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.hourglass_empty, color: Colors.grey[600]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Esperando ofertas de conductores...',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Botón cancelar
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _cancelNegotiation(negotiation.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ModernTheme.error,
                      side: BorderSide(color: ModernTheme.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancelar solicitud'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(DriverOffer offer, String negotiationId) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: offer.driverPhoto.isNotEmpty
                  ? NetworkImage(offer.driverPhoto)
                  : null,
              child: offer.driverPhoto.isEmpty ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.driverName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.star, size: 14, color: Colors.amber[700]),
                      const SizedBox(width: 4),
                      Text(
                        offer.driverRating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${offer.completedTrips} viajes',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${offer.vehicleModel} • ${offer.vehicleColor}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'S/. ${offer.acceptedPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                ElevatedButton(
                  onPressed: () => _acceptOffer(negotiationId, offer.driverId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModernTheme.success,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                  ),
                  child: const Text(
                    'Aceptar',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimer(PriceNegotiation negotiation) {
    final remaining = negotiation.timeRemaining;
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: minutes < 2 ? ModernTheme.error : ModernTheme.warning,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '$minutes:${seconds.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color color,
    required String label,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(NegotiationStatus status) {
    switch (status) {
      case NegotiationStatus.waiting:
        return ModernTheme.warning;
      case NegotiationStatus.negotiating:
        return ModernTheme.primary;
      case NegotiationStatus.accepted:
        return ModernTheme.success;
      case NegotiationStatus.expired:
      case NegotiationStatus.cancelled:
        return ModernTheme.error;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(NegotiationStatus status) {
    switch (status) {
      case NegotiationStatus.waiting:
        return Icons.hourglass_empty;
      case NegotiationStatus.negotiating:
        return Icons.sync;
      case NegotiationStatus.accepted:
        return Icons.check_circle;
      case NegotiationStatus.expired:
        return Icons.timer_off;
      case NegotiationStatus.cancelled:
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _getStatusText(NegotiationStatus status) {
    switch (status) {
      case NegotiationStatus.waiting:
        return 'Esperando ofertas';
      case NegotiationStatus.negotiating:
        return 'Recibiendo ofertas';
      case NegotiationStatus.accepted:
        return 'Oferta aceptada';
      case NegotiationStatus.expired:
        return 'Expirada';
      case NegotiationStatus.cancelled:
        return 'Cancelada';
      default:
        return 'Desconocido';
    }
  }

  Future<void> _acceptOffer(String negotiationId, String driverId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aceptar oferta'),
        content: const Text(
          '¿Estás seguro de que quieres aceptar esta oferta? '
          'El conductor será notificado y el viaje comenzará.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.success,
            ),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = Provider.of<PriceNegotiationProvider>(
        context,
        listen: false,
      );

      try {
        await provider.acceptDriverOffer(
          negotiationId: negotiationId,
          driverId: driverId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Oferta aceptada. ¡Tu conductor está en camino!'),
              backgroundColor: ModernTheme.success,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al aceptar oferta: $e'),
              backgroundColor: ModernTheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _cancelNegotiation(String negotiationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar solicitud'),
        content: const Text(
          '¿Estás seguro de que quieres cancelar esta solicitud?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.error,
            ),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = Provider.of<PriceNegotiationProvider>(
        context,
        listen: false,
      );

      try {
        await provider.cancelNegotiation(negotiationId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Solicitud cancelada'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cancelar: $e'),
              backgroundColor: ModernTheme.error,
            ),
          );
        }
      }
    }
  }
}
