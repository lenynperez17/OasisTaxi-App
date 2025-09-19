import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../core/services/places_service.dart';
import '../core/theme/modern_theme.dart';

class LocationSearchWidget extends StatefulWidget {
  final Function(String) onLocationSelected;
  final VoidCallback onClose;

  const LocationSearchWidget({
    super.key,
    required this.onLocationSelected,
    required this.onClose,
  });

  @override
  LocationSearchWidgetState createState() => LocationSearchWidgetState();
}

class LocationSearchWidgetState extends State<LocationSearchWidget> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  // Historial de búsquedas recientes
  final List<String> _recentSearches = [
    'Aeropuerto Jorge Chávez',
    'Centro Comercial Jockey Plaza',
    'Plaza de Armas de Lima',
    'Parque Kennedy, Miraflores',
  ];

  // Resultados de búsqueda con Google Places API
  List<PlacesSuggestion> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty && query.length > 2) {
        _searchPlaces(query);
      } else {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _searchPlaces(String query) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final suggestions = await PlacesService.searchPlaces(query);
      if (mounted) {
        setState(() {
          _searchResults = suggestions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al buscar direcciones'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectLocation(String locationText, {String? placeId}) async {
    HapticFeedback.lightImpact();

    if (placeId != null) {
      // Obtener detalles del lugar si tenemos place_id
      try {
        setState(() {
          _isLoading = true;
        });

        final placeDetails = await PlacesService.getPlaceDetails(placeId);
        if (placeDetails != null) {
          widget.onLocationSelected(placeDetails.formattedAddress);
        } else {
          widget.onLocationSelected(locationText);
        }
      } catch (e) {
        widget.onLocationSelected(locationText);
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      widget.onLocationSelected(locationText);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Simular obtención de ubicación actual
      await Future.delayed(Duration(seconds: 2));
      widget.onLocationSelected('Mi ubicación actual');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo obtener la ubicación actual'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header con búsqueda
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onClose,
                  icon: Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Buscar destino...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      prefixIcon:
                          Icon(Icons.search, color: ModernTheme.primaryColor),
                    ),
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      _searchController.clear();
                    },
                    icon: Icon(Icons.clear, color: Colors.grey),
                  ),
              ],
            ),
          ),

          // Indicador de carga global
          if (_isLoading && _searchController.text.isEmpty)
            LinearProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(ModernTheme.primaryColor),
            ),

          // Contenido
          Expanded(
            child: _searchController.text.isEmpty
                ? _buildRecentSearches()
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearches() {
    return ListView(
      padding: EdgeInsets.symmetric(vertical: 8),
      children: [
        // Ubicación actual
        ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ModernTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.my_location,
              color: ModernTheme.primaryColor,
              size: 20,
            ),
          ),
          title: Text(
            'Usar ubicación actual',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: ModernTheme.primaryColor,
            ),
          ),
          subtitle: Text('Detectar mi ubicación automáticamente'),
          onTap: _useCurrentLocation,
        ),

        // Seleccionar en mapa
        ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.map,
              color: Colors.blue,
              size: 20,
            ),
          ),
          title: Text(
            'Seleccionar en el mapa',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
          ),
          subtitle: Text('Elige un punto específico en el mapa'),
          onTap: () {
            // Implementar selección en mapa
            _openMapPicker();
          },
        ),

        Divider(height: 32),

        // Búsquedas recientes
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            'BÚSQUEDAS RECIENTES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
              letterSpacing: 1,
            ),
          ),
        ),

        ..._recentSearches.map((search) => ListTile(
              leading: Icon(Icons.history, color: Colors.grey),
              title: Text(search),
              trailing:
                  Icon(Icons.north_west, color: Colors.grey[400], size: 20),
              onTap: () => _selectLocation(search),
            )),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(ModernTheme.primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              'Buscando direcciones...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No se encontraron resultados',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Intenta con otra dirección',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ModernTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.location_on,
              color: ModernTheme.primaryColor,
              size: 20,
            ),
          ),
          title: Text(
            result.mainText ?? result.description,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle:
              result.secondaryText != null ? Text(result.secondaryText!) : null,
          onTap: () => _selectLocation(
            result.description,
            placeId: result.placeId,
          ),
        );
      },
    );
  }

  // Abrir selector de ubicación en mapa
  void _openMapPicker() {
    Navigator.of(context).pushNamed('/map-picker').then((result) {
      if (result != null && result is Map<String, dynamic>) {
        final location = result['location'] as String;

        widget.onLocationSelected(location);
        widget.onClose();
      }
    });
  }
}
