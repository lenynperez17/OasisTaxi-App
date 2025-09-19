import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/service_type_model.dart';
import '../core/theme/modern_theme.dart';

class TransportOptionsWidget extends StatefulWidget {
  final ServiceType selectedService;
  final Function(ServiceType) onServiceSelected;
  final double? distance; // En kilómetros
  final ScrollController? scrollController; // Para DraggableScrollableSheet

  const TransportOptionsWidget({
    super.key,
    required this.selectedService,
    required this.onServiceSelected,
    this.distance,
    this.scrollController,
  });

  @override
  TransportOptionsWidgetState createState() => TransportOptionsWidgetState();
}

class TransportOptionsWidgetState extends State<TransportOptionsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  ServiceCategory _selectedCategory = ServiceCategory.transport;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: widget
          .scrollController, // Usar el controller del DraggableScrollableSheet
      physics: ClampingScrollPhysics(),
      child: Column(
        children: [
          // Handle bar mejorado con indicador de arrastre
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.swipe_vertical,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Desliza para ajustar',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Título y tabs de categorías
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Elige tu servicio',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: ModernTheme.textPrimary,
                      ),
                    ),
                    if (widget.distance != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: ModernTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.route,
                              size: 16,
                              color: ModernTheme.primaryBlue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.distance!.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: ModernTheme.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Tabs de categorías
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      _buildCategoryTab(
                        'Transporte',
                        ServiceCategory.transport,
                        Icons.directions_car,
                      ),
                      _buildCategoryTab(
                        'Delivery',
                        ServiceCategory.delivery,
                        Icons.delivery_dining,
                      ),
                      _buildCategoryTab(
                        'Especial',
                        ServiceCategory.special,
                        Icons.build_circle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Lista de servicios con scroll personalizado
          SizedBox(
            height: 180, // Altura fija para las tarjetas de servicio
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _selectedCategory = ServiceCategory.values[index];
                });
              },
              children: ServiceCategory.values.map((category) {
                final services =
                    ServiceTypeConfig.getServicesByCategory(category);

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    return _buildServiceCard(services[index]);
                  },
                );
              }).toList(),
            ),
          ),

          // Espacio vacío al final para separación
          const SizedBox(
              height:
                  20), // Espacio extra reducido ya que el botón está integrado
        ],
      ),
    );
  }

  Widget _buildCategoryTab(
      String label, ServiceCategory category, IconData icon) {
    final isSelected = _selectedCategory == category;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategory = category;
            _pageController.animateToPage(
              category.index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          });
        },
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? ModernTheme.primaryOrange : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCard(ServiceInfo service) {
    final isSelected = widget.selectedService == service.type;
    final estimatedMinutes = widget.distance != null
        ? (widget.distance! * 3).round() // Estimación aproximada
        : 15;
    final price = widget.distance != null
        ? ServiceTypeConfig.calculatePrice(
            service.type, widget.distance!, estimatedMinutes)
        : service.basePrice;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onServiceSelected(service.type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 130, // Ancho aumentado para evitar overflow
        margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
        child: Stack(
          children: [
            // Tarjeta principal mejorada
            Container(
              padding: const EdgeInsets.all(
                  8), // Padding más reducido para dar más espacio
              decoration: BoxDecoration(
                color: isSelected
                    ? service.color.withValues(alpha: 0.12)
                    : Colors.white,
                borderRadius: BorderRadius.circular(24), // Más redondeado
                border: Border.all(
                  color: isSelected ? service.color : Colors.grey.shade300,
                  width: isSelected ? 2.5 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? service.color.withValues(alpha: 0.25)
                        : Colors.black.withValues(alpha: 0.08),
                    blurRadius: isSelected ? 20 : 12,
                    offset: Offset(0, isSelected ? 8 : 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Icono del servicio mejorado
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: service.color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: service.color.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      service.icon,
                      color: service.color,
                      size: 20,
                    ),
                  ),

                  // Nombre del servicio mejorado
                  Column(
                    children: [
                      Text(
                        service.name,
                        style: TextStyle(
                          fontSize: 11, // Reducido ligeramente
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? service.color
                              : ModernTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2, // Permitir 2 líneas
                        overflow: TextOverflow
                            .ellipsis, // Cortar con puntos si es muy largo
                      ),
                      const SizedBox(height: 4),
                      // Descripción mejorada
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          service.description,
                          style: TextStyle(
                            fontSize: 10, // Reducido para evitar overflow
                            color: ModernTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2, // Permitir 2 líneas
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Precio mejorado con indicadores visuales
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6), // Padding reducido
                    decoration: BoxDecoration(
                      color: isSelected
                          ? service.color.withValues(alpha: 0.15)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(
                              color: service.color.withValues(alpha: 0.4),
                              width: 1)
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          ServiceTypeConfig.formatPrice(price),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? service.color
                                : ModernTheme.textPrimary,
                          ),
                        ),
                        if (estimatedMinutes > 0)
                          Container(
                            margin: EdgeInsets.only(top: 2),
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '~$estimatedMinutes min',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Badge de selección
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: service.color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),

            // Badge especial para algunos servicios
            if (service.type == ServiceType.taxiPremium)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'VIP',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            // Badge de capacidad para transporte
            if (service.category == ServiceCategory.transport &&
                service.maxPassengers > 1)
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 12,
                      ),
                      Text(
                        ' ${service.maxPassengers}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
