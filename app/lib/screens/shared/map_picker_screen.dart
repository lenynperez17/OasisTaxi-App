import 'package:flutter/material.dart';
// ignore_for_file: library_private_types_in_public_api
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../widgets/common/oasis_app_bar.dart';
import '../../utils/logger.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final String? title;

  const MapPickerScreen({
    super.key,
    this.initialLocation,
    this.title = 'Seleccionar ubicación',
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _controller;
  LatLng? _selectedLocation;
  String _selectedAddress = 'Selecciona un punto en el mapa';
  bool _isLoading = true;
  bool _isGettingAddress = false;
  LatLng _currentCenter = const LatLng(-12.0464, -77.0428); // Lima, Perú por defecto

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      // Usar ubicación inicial si se proporciona
      if (widget.initialLocation != null) {
        _currentCenter = widget.initialLocation!;
        _selectedLocation = widget.initialLocation!;
        await _getAddressFromCoordinates(_selectedLocation!);
      } else {
        // Intentar obtener ubicación actual
        await _getCurrentLocation();
      }
    } catch (e) {
      AppLogger.error('Error inicializando mapa picker', e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requestedPermission = await Geolocator.requestPermission();
        if (requestedPermission == LocationPermission.denied) {
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _currentCenter = LatLng(position.latitude, position.longitude);
      AppLogger.info('Ubicación actual obtenida para map picker');
    } catch (e) {
      AppLogger.warning('No se pudo obtener ubicación actual en map picker', e);
    }
  }

  Future<void> _getAddressFromCoordinates(LatLng location) async {
    setState(() {
      _isGettingAddress = true;
    });

    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final addressComponents = [
          placemark.street,
          placemark.subLocality,
          placemark.locality,
          placemark.subAdministrativeArea,
          placemark.administrativeArea,
        ].where((component) => component != null && component.isNotEmpty);

        _selectedAddress = addressComponents.join(', ');
        if (_selectedAddress.isEmpty) {
          _selectedAddress = '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
        }
      } else {
        _selectedAddress = '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
      }
    } catch (e) {
      AppLogger.error('Error obteniendo dirección desde coordenadas', e);
      _selectedAddress = '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
    } finally {
      setState(() {
        _isGettingAddress = false;
      });
    }
  }

  void _onMapTapped(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
    _getAddressFromCoordinates(location);
  }

  void _confirmSelection() {
    if (_selectedLocation != null) {
      Navigator.of(context).pop({
        'location': _selectedAddress,
        'coordinates': {
          'lat': _selectedLocation!.latitude,
          'lng': _selectedLocation!.longitude,
        },
      });
    }
  }

  Future<void> _centerOnCurrentLocation() async {
    if (_controller == null) return;

    try {
      await _getCurrentLocation();
      await _controller!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentCenter,
            zoom: 16.0,
          ),
        ),
      );
      
      // Seleccionar automáticamente la ubicación actual
      setState(() {
        _selectedLocation = _currentCenter;
      });
      await _getAddressFromCoordinates(_currentCenter);
      
      AppLogger.info('Mapa centrado en ubicación actual');
    } catch (e) {
      AppLogger.error('Error centrando mapa en ubicación actual', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: OasisAppBar(title: widget.title!),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C800)),
              ),
              SizedBox(height: 16),
              Text(
                'Cargando mapa...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: OasisAppBar(
        title: widget.title!,
        actions: [
          if (_selectedLocation != null)
            TextButton(
              onPressed: _confirmSelection,
              child: const Text(
                'CONFIRMAR',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Google Maps
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentCenter,
              zoom: 15.0,
            ),
            onMapCreated: (GoogleMapController controller) {
              _controller = controller;
            },
            onTap: _onMapTapped,
            markers: _selectedLocation != null
                ? {
                    Marker(
                      markerId: const MarkerId('selected'),
                      position: _selectedLocation!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen,
                      ),
                      infoWindow: const InfoWindow(
                        title: 'Ubicación seleccionada',
                      ),
                    ),
                  }
                : {},
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // Panel de información inferior
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    offset: Offset(0, -2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Título
                    const Text(
                      'Ubicación seleccionada',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Dirección
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFF00C800),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _isGettingAddress
                              ? const Row(
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFF00C800),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Obteniendo dirección...'),
                                  ],
                                )
                              : Text(
                                  _selectedAddress,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Botones
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _centerOnCurrentLocation,
                            icon: const Icon(Icons.my_location),
                            label: const Text('Mi ubicación'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Color(0xFF00C800)),
                              foregroundColor: const Color(0xFF00C800),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _confirmSelection,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00C800),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Confirmar',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),

          // Botones de zoom
          Positioned(
            bottom: 200,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () {
                    _controller?.animateCamera(CameraUpdate.zoomIn());
                  },
                  heroTag: 'zoom_in_picker',
                  child: const Icon(Icons.add, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () {
                    _controller?.animateCamera(CameraUpdate.zoomOut());
                  },
                  heroTag: 'zoom_out_picker',
                  child: const Icon(Icons.remove, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}