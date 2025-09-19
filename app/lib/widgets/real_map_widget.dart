import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/app_logger.dart';

class RealMapWidget extends StatefulWidget {
  final Function(LatLng)? onLocationSelected;
  final bool showCurrentLocation;
  final bool enableInteraction;
  final LatLng? pickupLocation;
  final LatLng? dropoffLocation;
  final Set<Polyline>? polylines;
  final double? zoom;
  final LatLng? initialCenter;

  const RealMapWidget({
    super.key,
    this.onLocationSelected,
    this.showCurrentLocation = true,
    this.enableInteraction = true,
    this.pickupLocation,
    this.dropoffLocation,
    this.polylines,
    this.zoom = 14.0,
    this.initialCenter,
  });

  @override
  State<RealMapWidget> createState() => RealMapWidgetState();
}

class RealMapWidgetState extends State<RealMapWidget> {
  GoogleMapController? _controller;
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  LatLng _currentCenter =
      const LatLng(-12.0464, -77.0428); // Lima, Perú por defecto

  @override
  void initState() {
    super.initState();
    // Postergar inicialización del mapa para evitar setState durante build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMap();
    });
  }

  Future<void> _initializeMap() async {
    try {
      // Usar ubicación inicial proporcionada o ubicación actual
      if (widget.initialCenter != null) {
        _currentCenter = widget.initialCenter!;
      } else if (widget.showCurrentLocation) {
        await _getCurrentLocation();
      }

      _updateMarkers();

      setState(() {
        _isLoading = false;
      });

      AppLogger.info('Mapa real inicializado correctamente');
    } catch (e) {
      AppLogger.error('Error inicializando mapa real', e);
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
      AppLogger.info(
          'Ubicación actual obtenida: ${_currentCenter.latitude}, ${_currentCenter.longitude}');
    } catch (e) {
      AppLogger.warning('No se pudo obtener la ubicación actual', e);
      // Mantener Lima, Perú como centro por defecto
    }
  }

  void _updateMarkers() {
    _markers.clear();

    // Marcador de recogida
    if (widget.pickupLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: widget.pickupLocation!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(
            title: 'Punto de recogida',
            snippet: 'Aquí te recogeremos',
          ),
        ),
      );
    }

    // Marcador de destino
    if (widget.dropoffLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: widget.dropoffLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(
            title: 'Destino',
            snippet: 'Tu destino',
          ),
        ),
      );
    }
  }

  Future<void> _centerOnLocation() async {
    if (_controller == null) return;

    try {
      await _getCurrentLocation();
      await _controller!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentCenter,
            zoom: widget.zoom!,
          ),
        ),
      );
      AppLogger.info('Mapa centrado en ubicación actual');
    } catch (e) {
      AppLogger.error('Error centrando mapa en ubicación', e);
    }
  }

  Future<void> _zoomIn() async {
    if (_controller == null) return;

    try {
      await _controller!.animateCamera(CameraUpdate.zoomIn());
    } catch (e) {
      AppLogger.error('Error haciendo zoom in', e);
    }
  }

  Future<void> _zoomOut() async {
    if (_controller == null) return;

    try {
      await _controller!.animateCamera(CameraUpdate.zoomOut());
    } catch (e) {
      AppLogger.error('Error haciendo zoom out', e);
    }
  }

  @override
  void didUpdateWidget(RealMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Actualizar marcadores si las ubicaciones cambiaron
    if (widget.pickupLocation != oldWidget.pickupLocation ||
        widget.dropoffLocation != oldWidget.dropoffLocation) {
      _updateMarkers();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C800)),
              ),
              SizedBox(height: 16),
              Text(
                'Cargando mapa...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Google Maps
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _currentCenter,
            zoom: widget.zoom!,
          ),
          onMapCreated: (GoogleMapController controller) {
            _controller = controller;
            AppLogger.info('Google Map creado correctamente');
          },
          markers: _markers,
          polylines: widget.polylines ?? {},
          myLocationEnabled: widget.showCurrentLocation,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          gestureRecognizers: widget.enableInteraction
              ? <Factory<OneSequenceGestureRecognizer>>{}
              : <Factory<OneSequenceGestureRecognizer>>{},
          onTap: widget.enableInteraction && widget.onLocationSelected != null
              ? (LatLng position) {
                  widget.onLocationSelected!(position);
                  AppLogger.info(
                      'Ubicación seleccionada: ${position.latitude}, ${position.longitude}');
                }
              : null,
        ),

        // Controles del mapa
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón de zoom in
              FloatingActionButton(
                mini: true,
                backgroundColor: Colors.white,
                onPressed: _zoomIn,
                heroTag: 'zoom_in',
                child: const Icon(Icons.add, color: Colors.black87),
              ),
              const SizedBox(height: 8),

              // Botón de zoom out
              FloatingActionButton(
                mini: true,
                backgroundColor: Colors.white,
                onPressed: _zoomOut,
                heroTag: 'zoom_out',
                child: const Icon(Icons.remove, color: Colors.black87),
              ),
              const SizedBox(height: 8),

              // Botón de ubicación actual
              if (widget.showCurrentLocation)
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _centerOnLocation,
                  heroTag: 'my_location',
                  child: const Icon(
                    Icons.my_location,
                    color: Color(0xFF00C800),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
