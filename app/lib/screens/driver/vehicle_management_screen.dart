import 'package:flutter/material.dart';
import '../../core/theme/modern_theme.dart';
import '../../services/security_integration_service.dart';
import '../../utils/app_logger.dart';
import 'package:provider/provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/auth_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

class VehicleManagementScreen extends StatefulWidget {
  const VehicleManagementScreen({super.key});

  @override
  VehicleManagementScreenState createState() => VehicleManagementScreenState();
}

class VehicleManagementScreenState extends State<VehicleManagementScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // UI state
  int _selectedTab = 0;
  bool _isEditing = false;
  final ImagePicker _imagePicker = ImagePicker();

  // Loading states per section
  bool _loadingVehicle = false;
  bool _loadingDocuments = false;
  bool _loadingMaintenance = false;
  bool _loadingReminders = false;

  // Error states per section
  String? _vehicleError;
  String? _documentsError;
  String? _maintenanceError;
  String? _remindersError;

  // Form controllers for adding new items
  final TextEditingController _documentTypeController = TextEditingController();
  final TextEditingController _documentNumberController = TextEditingController();
  final TextEditingController _maintenanceTypeController = TextEditingController();
  final TextEditingController _workshopController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _reminderTitleController = TextEditingController();
  final TextEditingController _reminderDescriptionController = TextEditingController();

  // Vehicle form controllers and key
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _vinController = TextEditingController();
  final TextEditingController _transmissionController = TextEditingController();
  final TextEditingController _fuelTypeController = TextEditingController();
  final TextEditingController _seatsController = TextEditingController();
  final TextEditingController _mileageController = TextEditingController();

  // Remove all mock data - will use real data from VehicleProvider
  // All data will come from Provider instead of being hardcoded

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('VehicleManagementScreen', 'initState');

    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _fadeController.forward();

    // Load vehicle data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVehicleData();
    });
  }

  Future<void> _loadVehicleData() async {
    if (!mounted) return;

    setState(() {
      _loadingVehicle = true;
      _loadingDocuments = true;
      _loadingMaintenance = true;
      _loadingReminders = true;
      // Clear previous errors
      _vehicleError = null;
      _documentsError = null;
      _maintenanceError = null;
      _remindersError = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);

    // Use currentUser.id instead of user.uid
    if (authProvider.currentUser != null) {
      try {
        await vehicleProvider.loadVehicleData(authProvider.currentUser!.id);
      } catch (e) {
        AppLogger.error('Error loading vehicle data', e);
        if (mounted) {
          setState(() {
            _vehicleError = 'Error al cargar datos del vehículo';
            _documentsError = 'Error al cargar documentos';
            _maintenanceError = 'Error al cargar mantenimientos';
            _remindersError = 'Error al cargar recordatorios';
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _vehicleError = 'Usuario no autenticado';
          _documentsError = 'Usuario no autenticado';
          _maintenanceError = 'Usuario no autenticado';
          _remindersError = 'Usuario no autenticado';
        });
      }
    }

    if (mounted) {
      setState(() {
        _loadingVehicle = false;
        _loadingDocuments = false;
        _loadingMaintenance = false;
        _loadingReminders = false;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _documentTypeController.dispose();
    _documentNumberController.dispose();
    _maintenanceTypeController.dispose();
    _workshopController.dispose();
    _costController.dispose();
    _reminderTitleController.dispose();
    _reminderDescriptionController.dispose();
    // Dispose vehicle form controllers
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _plateController.dispose();
    _colorController.dispose();
    _vinController.dispose();
    _transmissionController.dispose();
    _fuelTypeController.dispose();
    _seatsController.dispose();
    _mileageController.dispose();
    super.dispose();
  }

  Future<void> _handleDocumentUpload() async {
    try {
      // Implementación para manejar la carga de documentos
      AppLogger.info('📄 Iniciando carga de documento del vehículo');

      // Aquí se implementaría la lógica real de carga de documentos
      // Por ejemplo: seleccionar archivo, validar, subir a Firebase Storage

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Documento cargado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      AppLogger.error('❌ Error al cargar documento: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar documento'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VehicleProvider>(
      builder: (context, vehicleProvider, child) {
        if (vehicleProvider.isLoading && vehicleProvider.vehicleData.isEmpty) {
          return Scaffold(
            backgroundColor: ModernTheme.backgroundLight,
            appBar: _buildAppBar(null),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.oasisGreen),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando información del vehículo...',
                    style: TextStyle(color: ModernTheme.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        if (vehicleProvider.error != null) {
          return Scaffold(
            backgroundColor: ModernTheme.backgroundLight,
            appBar: _buildAppBar(null),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: ModernTheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error cargando datos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ModernTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    vehicleProvider.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ModernTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      vehicleProvider.clearError();
                      _loadVehicleData();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ModernTheme.oasisGreen,
                    ),
                    child: Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: ModernTheme.backgroundLight,
          appBar: _buildAppBar(vehicleProvider),
          body: AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Column(
                  children: [
                    _buildTabBar(),
                    Expanded(
                      child: IndexedStack(
                        index: _selectedTab,
                        children: [
                          _buildVehicleInfo(vehicleProvider),
                          _buildDocuments(vehicleProvider),
                          _buildMaintenance(vehicleProvider),
                          _buildReminders(vehicleProvider),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          floatingActionButton: _selectedTab > 0
              ? FloatingActionButton(
                  onPressed: () => _showAddDialog(),
                  backgroundColor: ModernTheme.oasisGreen,
                  child: vehicleProvider.isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(Icons.add, color: Colors.white),
                )
              : null,
        );
      },
    );
  }

  AppBar _buildAppBar(VehicleProvider? vehicleProvider) {
    return AppBar(
      backgroundColor: ModernTheme.oasisGreen,
      elevation: 0,
      title: Text(
        'Mi Vehículo',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        if (vehicleProvider != null)
          IconButton(
            icon: Icon(
              _isEditing ? Icons.save : Icons.edit,
              color: Colors.white,
            ),
            onPressed: vehicleProvider.isSaving
                ? null
                : () {
                    if (_isEditing) {
                      // Save changes
                      _saveVehicleChanges(vehicleProvider);
                    } else {
                      // Enter edit mode and initialize controllers
                      final vehicleData = vehicleProvider.vehicleData;
                      _brandController.text = vehicleData['brand']?.toString() ?? '';
                      _modelController.text = vehicleData['model']?.toString() ?? '';
                      _yearController.text = vehicleData['year']?.toString() ?? '';
                      _plateController.text = vehicleData['plate']?.toString() ?? '';
                      _colorController.text = vehicleData['color']?.toString() ?? '';
                      _vinController.text = vehicleData['vin']?.toString() ?? '';
                      _transmissionController.text = vehicleData['transmission']?.toString() ?? '';
                      _fuelTypeController.text = vehicleData['fuelType']?.toString() ?? '';
                      _seatsController.text = vehicleData['seats']?.toString() ?? '';
                      _mileageController.text = vehicleData['mileage']?.toString() ?? '';
                      setState(() => _isEditing = true);
                    }
                  },
          ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          _buildTab('Vehículo', Icons.directions_car, 0),
          _buildTab('Documentos', Icons.folder, 1),
          _buildTab('Mantenimiento', Icons.build, 2),
          _buildTab('Recordatorios', Icons.notifications, 3),
        ],
      ),
    );
  }

  Widget _buildTab(String label, IconData icon, int index) {
    final isSelected = _selectedTab == index;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? ModernTheme.oasisGreen : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? ModernTheme.oasisGreen
                    : ModernTheme.textSecondary,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? ModernTheme.oasisGreen
                      : ModernTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleInfo(VehicleProvider vehicleProvider) {
    if (_loadingVehicle) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: ModernTheme.oasisGreen),
            const SizedBox(height: 16),
            Text('Cargando información del vehículo...', style: TextStyle(color: ModernTheme.textSecondary)),
          ],
        ),
      );
    }

    // Show error state if there's an error
    if (_vehicleError != null) {
      return _buildErrorState(_vehicleError!, _loadVehicleData);
    }

    final vehicleData = vehicleProvider.vehicleData;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle header card
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ModernTheme.oasisGreen,
                  ModernTheme.oasisGreen.withValues(alpha: 0.8)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: ModernTheme.cardShadow,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.directions_car,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${vehicleData['brand'] ?? 'Sin marca'} ${vehicleData['model'] ?? 'Sin modelo'}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${vehicleData['year'] ?? 'Sin año'} • ${vehicleData['plate'] ?? 'Sin placa'}',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: (vehicleData['isActive'] ?? false)
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            (vehicleData['isActive'] ?? false) ? 'Activo' : 'Inactivo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildVehicleStat('Kilometraje',
                        '${vehicleData['mileage'] ?? 0} km', Icons.speed),
                    _buildVehicleStat('Asientos', '${vehicleData['seats'] ?? 4}',
                        Icons.event_seat),
                    _buildVehicleStat('Combustible', vehicleData['fuelType'] ?? 'Gasolina',
                        Icons.local_gas_station),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Photos section
          Text(
            'Fotos del Vehículo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildPhotosSection(vehicleProvider),

          const SizedBox(height: 24),

          // Vehicle details
          Text(
            'Información Detallada',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildDetailCard(vehicleProvider),

          const SizedBox(height: 24),

          // Technical specs
          Text(
            'Especificaciones Técnicas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildSpecsCard(vehicleProvider),
        ],
      ),
    );
  }

  Widget _buildVehicleStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotosSection(VehicleProvider vehicleProvider) {
    final vehicleData = vehicleProvider.vehicleData;
    final photos = List<String>.from(vehicleData['photos'] ?? []);

    return Container(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _isEditing ? photos.length + 1 : photos.length,
        itemBuilder: (context, index) {
          if (_isEditing && index == photos.length) {
            return _buildAddPhotoCard(vehicleProvider);
          }
          return _buildPhotoCard(photos[index], index, vehicleProvider);
        },
      ),
    );
  }

  Widget _buildPhotoCard(String photoUrl, int index, VehicleProvider vehicleProvider) {
    return Container(
      width: 160,
      margin: EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: photoUrl.isNotEmpty
              ? NetworkImage(photoUrl) as ImageProvider
              : AssetImage('assets/images/car_placeholder.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: _isEditing
          ? Align(
              alignment: Alignment.topRight,
              child: Container(
                margin: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ModernTheme.error,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white, size: 16),
                  onPressed: () async {
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final driverId = authProvider.currentUser?.id;

                    if (driverId != null) {
                      final success = await vehicleProvider.removeVehiclePhoto(driverId, index);

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Foto eliminada' : 'Error al eliminar foto'),
                            backgroundColor: success ? ModernTheme.success : ModernTheme.error,
                          ),
                        );
                      }
                    }
                  },
                  padding: EdgeInsets.all(4),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildAddPhotoCard(VehicleProvider vehicleProvider) {
    return Container(
      width: 160,
      margin: EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ModernTheme.oasisGreen,
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: InkWell(
        onTap: () => _addPhoto(vehicleProvider),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, color: ModernTheme.oasisGreen, size: 32),
            const SizedBox(height: 8),
            Text(
              'Agregar Foto',
              style: TextStyle(
                color: ModernTheme.oasisGreen,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(VehicleProvider vehicleProvider) {
    final vehicleData = vehicleProvider.vehicleData;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Column(
        children: [
          _buildDetailRow(
              'Marca', vehicleData['brand'] ?? '', Icons.branding_watermark),
          _buildDetailRow(
              'Modelo', vehicleData['model'] ?? '', Icons.model_training),
          _buildDetailRow(
              'Año', (vehicleData['year'] ?? '').toString(), Icons.calendar_today),
          _buildDetailRow('Placa', vehicleData['plate'] ?? '', Icons.badge),
          _buildDetailRow('Color', vehicleData['color'] ?? '', Icons.palette),
          _buildDetailRow('VIN', vehicleData['vin'] ?? '', Icons.fingerprint),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: ModernTheme.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: ModernTheme.textSecondary,
              ),
            ),
          ),
          _isEditing
              ? Expanded(
                  flex: 2,
                  child: SecurityIntegrationService.buildSecureTextField(
                    context: context,
                    controller: TextEditingController(text: value),
                    label: '',
                    fieldType: label.toLowerCase().contains('placa')
                        ? 'vehicleplate'
                        : 'text',
                  ),
                )
              : Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSpecsCard(VehicleProvider vehicleProvider) {
    final vehicleData = vehicleProvider.vehicleData;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Column(
        children: [
          _buildSpecRow(
              'Transmisión', vehicleData['transmission'] ?? 'Manual', Icons.settings),
          _buildSpecRow('Tipo de Combustible', vehicleData['fuelType'] ?? 'Gasolina',
              Icons.local_gas_station),
          _buildSpecRow('Número de Asientos',
              '${vehicleData['seats'] ?? 4} pasajeros', Icons.event_seat),
          _buildSpecRow('Kilometraje Actual', '${vehicleData['mileage'] ?? 0} km',
              Icons.speed),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: ModernTheme.oasisGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: ModernTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocuments(VehicleProvider vehicleProvider) {
    if (_loadingDocuments) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: ModernTheme.oasisGreen),
            const SizedBox(height: 16),
            Text('Cargando documentos...', style: TextStyle(color: ModernTheme.textSecondary)),
          ],
        ),
      );
    }

    // Show error state if there's an error
    if (_documentsError != null) {
      return _buildErrorState(_documentsError!, _loadVehicleData);
    }

    final documents = vehicleProvider.documents;

    if (documents.isEmpty && !_isEditing) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.description_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No hay documentos registrados',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _isEditing ? documents.length + 1 : documents.length,
      itemBuilder: (context, index) {
        if (_isEditing && index == documents.length) {
          return _buildAddDocumentButton(vehicleProvider);
        }
        final doc = documents[index];
        return _buildDocumentCard(doc, vehicleProvider);
      },
    );
  }

  Widget _buildDocumentCard(VehicleDocument doc, VehicleProvider vehicleProvider) {
    final expiryDate = doc.expiryDate;
    final daysUntilExpiry = expiryDate?.difference(DateTime.now()).inDays;
    final isExpiringSoon = daysUntilExpiry != null && daysUntilExpiry < 30;
    final isExpired = daysUntilExpiry != null && daysUntilExpiry < 0;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getDocumentColor(doc.type).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(_getDocumentIcon(doc.type), color: _getDocumentColor(doc.type)),
        ),
        title: Text(
          doc.type,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Número: ${doc.number}'),
            if (expiryDate != null)
              Text(
                'Vence: ${_formatDate(expiryDate)}',
                style: TextStyle(
                  color: isExpired
                      ? ModernTheme.error
                      : isExpiringSoon
                          ? ModernTheme.warning
                          : ModernTheme.textSecondary,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(doc.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _getStatusText(doc.status),
                style: TextStyle(
                  color: _getStatusColor(doc.status),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (daysUntilExpiry != null &&
                daysUntilExpiry > 0 &&
                daysUntilExpiry < 30)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '$daysUntilExpiry días',
                  style: TextStyle(
                    fontSize: 11,
                    color: ModernTheme.warning,
                  ),
                ),
              ),
          ],
        ),
        onTap: _isEditing ? () => _showDocumentForm(vehicleProvider, doc) : null,
      ),
    );
  }

  Widget _buildMaintenance(VehicleProvider vehicleProvider) {
    if (_loadingMaintenance) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: ModernTheme.oasisGreen),
            const SizedBox(height: 16),
            Text('Cargando mantenimientos...', style: TextStyle(color: ModernTheme.textSecondary)),
          ],
        ),
      );
    }

    // Show error state if there's an error
    if (_maintenanceError != null) {
      return _buildErrorState(_maintenanceError!, _loadVehicleData);
    }

    final maintenanceRecords = vehicleProvider.maintenanceRecords;

    if (maintenanceRecords.isEmpty && !_isEditing) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.build_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No hay registros de mantenimiento',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _isEditing ? maintenanceRecords.length + 1 : maintenanceRecords.length,
      itemBuilder: (context, index) {
        if (_isEditing && index == maintenanceRecords.length) {
          return _buildAddMaintenanceButton(vehicleProvider);
        }
        final record = maintenanceRecords[index];
        return _buildMaintenanceCard(record, vehicleProvider);
      },
    );
  }

  Widget _buildMaintenanceCard(MaintenanceRecord record, VehicleProvider vehicleProvider) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.all(16),
        childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ModernTheme.primaryBlue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(_getMaintenanceIcon(record.type), color: ModernTheme.primaryBlue),
        ),
        title: Text(
          record.type,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          '${_formatDate(record.date)} • ${record.mileage} km',
          style: TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'S/ ${record.cost.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ModernTheme.oasisGreen,
              ),
            ),
            if (record.nextDue != null)
              Text(
                'Próximo: ${_formatDate(record.nextDue!)}',
                style: TextStyle(
                  fontSize: 11,
                  color: ModernTheme.textSecondary,
                ),
              ),
          ],
        ),
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ModernTheme.backgroundLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildMaintenanceDetail('Taller', record.workshop, Icons.store),
                _buildMaintenanceDetail(
                    'Kilometraje', '${record.mileage} km', Icons.speed),
                _buildMaintenanceDetail('Costo',
                    'S/ ${record.cost.toStringAsFixed(2)}', Icons.attach_money),
                if (record.notes != null)
                  _buildMaintenanceDetail('Notas', record.notes!, Icons.note),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceDetail(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ModernTheme.textSecondary),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              color: ModernTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminders(VehicleProvider vehicleProvider) {
    if (_loadingReminders) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: ModernTheme.oasisGreen),
            const SizedBox(height: 16),
            Text('Cargando recordatorios...', style: TextStyle(color: ModernTheme.textSecondary)),
          ],
        ),
      );
    }

    // Show error state if there's an error
    if (_remindersError != null) {
      return _buildErrorState(_remindersError!, _loadVehicleData);
    }

    final reminders = vehicleProvider.reminders;

    if (reminders.isEmpty && !_isEditing) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notification_important_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No hay recordatorios activos',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _isEditing ? reminders.length + 1 : reminders.length,
      itemBuilder: (context, index) {
        if (_isEditing && index == reminders.length) {
          return _buildAddReminderButton(vehicleProvider);
        }
        final reminder = reminders[index];
        return _buildReminderCard(reminder);
      },
    );
  }

  Widget _buildReminderCard(Reminder reminder) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: _getPriorityColor(reminder.priority),
            width: 4,
          ),
        ),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getReminderColor(reminder.type).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getReminderIcon(reminder.type),
            color: _getReminderColor(reminder.type),
          ),
        ),
        title: Text(
          reminder.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reminder.description),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 14, color: ModernTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  _formatDate(reminder.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: ModernTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Text('Editar'),
            ),
            PopupMenuItem(
              value: 'complete',
              child: Text('Marcar como completado'),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text('Eliminar'),
            ),
          ],
          onSelected: (value) {
            // Handle action
          },
        ),
      ),
    );
  }

  Color _getStatusColor(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.valid:
        return ModernTheme.success;
      case DocumentStatus.expiringSoon:
        return ModernTheme.warning;
      case DocumentStatus.expired:
        return ModernTheme.error;
      case DocumentStatus.pending:
        return ModernTheme.info;
    }
  }

  String _getStatusText(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.valid:
        return 'Vigente';
      case DocumentStatus.expiringSoon:
        return 'Por vencer';
      case DocumentStatus.expired:
        return 'Vencido';
      case DocumentStatus.pending:
        return 'Pendiente';
    }
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.high:
        return ModernTheme.error;
      case Priority.medium:
        return ModernTheme.warning;
      case Priority.low:
        return ModernTheme.info;
    }
  }

  Color _getReminderColor(ReminderType type) {
    switch (type) {
      case ReminderType.document:
        return Colors.purple;
      case ReminderType.maintenance:
        return ModernTheme.primaryBlue;
      case ReminderType.payment:
        return ModernTheme.oasisGreen;
      case ReminderType.other:
        return Colors.grey;
    }
  }

  IconData _getReminderIcon(ReminderType type) {
    switch (type) {
      case ReminderType.document:
        return Icons.description;
      case ReminderType.maintenance:
        return Icons.build;
      case ReminderType.payment:
        return Icons.payment;
      case ReminderType.other:
        return Icons.info;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }


  void _saveChanges() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cambios guardados exitosamente'),
        backgroundColor: ModernTheme.success,
      ),
    );
  }

  void _showDocumentDetails(VehicleDocument doc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(doc.icon, color: doc.color, size: 32),
                const SizedBox(width: 12),
                Text(
                  doc.type,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDocumentDetailRow('Número', doc.number),
            _buildDocumentDetailRow(
                'Fecha de emisión', _formatDate(doc.issueDate)),
            if (doc.expiryDate != null)
              _buildDocumentDetailRow(
                  'Fecha de vencimiento', _formatDate(doc.expiryDate!)),
            _buildDocumentDetailRow('Estado', _getStatusText(doc.status)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // Show document
                    },
                    icon: Icon(Icons.visibility),
                    label: Text('Ver Documento'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ModernTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // Update document
                    },
                    icon: Icon(Icons.upload),
                    label: Text('Actualizar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ModernTheme.oasisGreen,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: ModernTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    String title = '';
    switch (_selectedTab) {
      case 1:
        title = 'Agregar Documento';
        break;
      case 2:
        title = 'Registrar Mantenimiento';
        break;
      case 3:
        title = 'Crear Recordatorio';
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text('Formulario para agregar nuevo elemento'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Elemento agregado exitosamente'),
                  backgroundColor: ModernTheme.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.oasisGreen,
            ),
            child: Text('Agregar'),
          ),
        ],
      ),
    );
  }

  // Comment 4 & 12: Implement photo management with permission handling
  Future<void> _addPhoto(VehicleProvider vehicleProvider) async {
    try {
      // Check camera/gallery permissions
      final PermissionStatus cameraStatus = await Permission.camera.status;
      final PermissionStatus galleryStatus = await Permission.photos.status;

      if (!cameraStatus.isGranted && !galleryStatus.isGranted) {
        // Request permissions
        final Map<Permission, PermissionStatus> statuses = await [
          Permission.camera,
          Permission.photos,
        ].request();

        if (statuses[Permission.camera]!.isDenied &&
            statuses[Permission.photos]!.isDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Se requieren permisos para acceder a la cámara o galería'),
                backgroundColor: ModernTheme.warning,
                action: SnackBarAction(
                  label: 'Configuración',
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
          }
          return;
        }
      }

      // Show image source dialog
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Seleccionar fuente'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Cámara'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Galería'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        // Show loading indicator
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Center(
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.oasisGreen),
                    ),
                    const SizedBox(height: 16),
                    Text('Subiendo foto...'),
                  ],
                ),
              ),
            ),
          );
        }

        // Upload photo
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final driverId = authProvider.currentUser?.id;
        if (driverId == null) {
          throw Exception('Usuario no autenticado');
        }
        final success = await vehicleProvider.uploadVehiclePhoto(driverId, File(image.path));

        if (mounted) {
          Navigator.pop(context); // Dismiss loading

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success
                ? 'Foto agregada exitosamente'
                : 'Error al agregar foto'),
              backgroundColor: success ? ModernTheme.success : ModernTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('Error adding photo', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar la foto: $e'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  // Save vehicle changes
  Future<void> _saveVehicleChanges(VehicleProvider vehicleProvider) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final driverId = authProvider.currentUser?.id;

    if (driverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: Usuario no autenticado'),
          backgroundColor: ModernTheme.error,
        ),
      );
      return;
    }

    try {
      final updates = {
        'brand': _brandController.text,
        'model': _modelController.text,
        'year': int.tryParse(_yearController.text) ?? 0,
        'plate': _plateController.text,
        'color': _colorController.text,
        'vin': _vinController.text,
        'transmission': _transmissionController.text,
        'fuelType': _fuelTypeController.text,
        'seats': int.tryParse(_seatsController.text) ?? 4,
        'mileage': int.tryParse(_mileageController.text) ?? 0,
      };

      final success = await vehicleProvider.updateVehicleInfo(driverId, updates);

      if (mounted) {
        setState(() {
          _isEditing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
              ? 'Cambios guardados exitosamente'
              : 'Error al guardar cambios'),
            backgroundColor: success ? ModernTheme.success : ModernTheme.error,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error saving vehicle changes', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  // Helper method to build add document button
  Widget _buildAddDocumentButton(VehicleProvider vehicleProvider) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.add, color: ModernTheme.oasisGreen),
        ),
        title: Text('Agregar Documento'),
        subtitle: Text('Registrar nuevo documento del vehículo'),
        onTap: () => _showDocumentForm(vehicleProvider),
      ),
    );
  }

  // Helper method to build add maintenance button
  Widget _buildAddMaintenanceButton(VehicleProvider vehicleProvider) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ModernTheme.primaryBlue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.add, color: ModernTheme.primaryBlue),
        ),
        title: Text('Registrar Mantenimiento'),
        subtitle: Text('Agregar nuevo registro de mantenimiento'),
        onTap: () => _showMaintenanceForm(vehicleProvider),
      ),
    );
  }

  // Helper method to build add reminder button
  Widget _buildAddReminderButton(VehicleProvider vehicleProvider) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.add, color: Colors.purple),
        ),
        title: Text('Crear Recordatorio'),
        subtitle: Text('Agregar nuevo recordatorio'),
        onTap: () => _showReminderForm(vehicleProvider),
      ),
    );
  }

  // Form for maintenance records
  void _showMaintenanceForm(VehicleProvider vehicleProvider, [MaintenanceRecord? record]) {
    // Initialize controllers with existing values if editing
    if (record != null) {
      _maintenanceTypeController.text = record.type;
      _workshopController.text = record.workshop;
      _costController.text = record.cost.toString();
    } else {
      _maintenanceTypeController.clear();
      _workshopController.clear();
      _costController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record != null ? 'Editar Mantenimiento' : 'Registrar Mantenimiento',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _maintenanceTypeController,
              decoration: InputDecoration(
                labelText: 'Tipo de Mantenimiento',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _workshopController,
              decoration: InputDecoration(
                labelText: 'Taller',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _costController,
              decoration: InputDecoration(
                labelText: 'Costo (S/)',
                border: OutlineInputBorder(),
                prefixText: 'S/ ',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final driverId = authProvider.currentUser?.id;

                    if (driverId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: Usuario no autenticado'),
                          backgroundColor: ModernTheme.error,
                        ),
                      );
                      return;
                    }

                    try {
                      if (record != null) {
                        // Editing existing record
                        await vehicleProvider.updateMaintenanceRecord(
                          driverId,
                          record.id,
                          {
                            'type': _maintenanceTypeController.text,
                            'workshop': _workshopController.text,
                            'cost': double.tryParse(_costController.text) ?? 0.0,
                            'mileage': vehicleProvider.vehicleData['mileage'] ?? 0,
                            'date': Timestamp.fromDate(DateTime.now()),
                          },
                        );
                      } else {
                        // Creating new record
                        await vehicleProvider.addMaintenanceRecord(
                          driverId: driverId,
                          type: _maintenanceTypeController.text,
                          date: DateTime.now(),
                          mileage: vehicleProvider.vehicleData['mileage'] ?? 0,
                          cost: double.tryParse(_costController.text) ?? 0.0,
                          workshop: _workshopController.text,
                        );
                      }

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(record != null ? 'Mantenimiento actualizado' : 'Mantenimiento registrado'),
                            backgroundColor: ModernTheme.success,
                          ),
                        );
                      }
                    } catch (e) {
                      AppLogger.error('Error saving maintenance', e);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al guardar: $e'),
                            backgroundColor: ModernTheme.error,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModernTheme.oasisGreen,
                  ),
                  child: Text(record != null ? 'Actualizar' : 'Registrar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Form for reminders
  void _showReminderForm(VehicleProvider vehicleProvider, [Reminder? reminder]) {
    // Initialize controllers with existing values if editing
    if (reminder != null) {
      _reminderTitleController.text = reminder.title;
      _reminderDescriptionController.text = reminder.description;
    } else {
      _reminderTitleController.clear();
      _reminderDescriptionController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reminder != null ? 'Editar Recordatorio' : 'Crear Recordatorio',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _reminderTitleController,
              decoration: InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reminderDescriptionController,
              decoration: InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final driverId = authProvider.currentUser?.id;

                    if (driverId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: Usuario no autenticado'),
                          backgroundColor: ModernTheme.error,
                        ),
                      );
                      return;
                    }

                    try {
                      if (reminder != null) {
                        // Editing existing reminder
                        await vehicleProvider.updateReminder(
                          driverId,
                          reminder.id,
                          {
                            'title': _reminderTitleController.text,
                            'description': _reminderDescriptionController.text,
                            'date': Timestamp.fromDate(DateTime.now()),
                            'type': ReminderType.maintenance.index,
                            'priority': Priority.medium.index,
                          },
                        );
                      } else {
                        // Creating new reminder
                        await vehicleProvider.addReminder(
                          driverId: driverId,
                          title: _reminderTitleController.text,
                          description: _reminderDescriptionController.text,
                          date: DateTime.now(),
                          type: ReminderType.maintenance,
                          priority: Priority.medium,
                        );
                      }

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(reminder != null ? 'Recordatorio actualizado' : 'Recordatorio creado'),
                            backgroundColor: ModernTheme.success,
                          ),
                        );
                      }
                    } catch (e) {
                      AppLogger.error('Error saving reminder', e);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al guardar: $e'),
                            backgroundColor: ModernTheme.error,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModernTheme.oasisGreen,
                  ),
                  child: Text(reminder != null ? 'Actualizar' : 'Crear'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build error state widget
  Widget _buildErrorState(String errorMessage, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: ModernTheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ModernTheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: ModernTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh),
              label: Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.oasisGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get document color based on type
  Color _getDocumentColor(String documentType) {
    switch (documentType.toLowerCase()) {
      case 'license':
      case 'licencia':
        return ModernTheme.primaryBlue;
      case 'soat':
        return ModernTheme.oasisGreen;
      case 'criminal_record':
      case 'antecedentes':
        return ModernTheme.warning;
      case 'vehicle_photo':
      case 'foto':
        return ModernTheme.textSecondary;
      default:
        return ModernTheme.textSecondary;
    }
  }

  // Helper method to get document icon based on type
  IconData _getDocumentIcon(String documentType) {
    switch (documentType.toLowerCase()) {
      case 'license':
      case 'licencia':
        return Icons.badge;
      case 'soat':
        return Icons.security;
      case 'criminal_record':
      case 'antecedentes':
        return Icons.verified_user;
      case 'vehicle_photo':
      case 'foto':
        return Icons.photo_camera;
      default:
        return Icons.description;
    }
  }

  // Helper method to get maintenance icon based on type
  IconData _getMaintenanceIcon(String maintenanceType) {
    switch (maintenanceType.toLowerCase()) {
      case 'oil_change':
      case 'cambio_aceite':
        return Icons.oil_barrel;
      case 'tire_rotation':
      case 'rotacion_neumaticos':
        return Icons.tire_repair;
      case 'brake_service':
      case 'servicio_frenos':
        return Icons.build;
      case 'general_inspection':
      case 'inspeccion':
        return Icons.search;
      default:
        return Icons.build_circle;
    }
  }

  // Show document form for adding/editing documents
  void _showDocumentForm(VehicleProvider vehicleProvider, [VehicleDocument? document]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                document != null ? 'Editar Documento' : 'Agregar Documento',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              // Document type dropdown
              DropdownButtonFormField<String>(
                value: document?.type,
                decoration: InputDecoration(
                  labelText: 'Tipo de Documento',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: [
                  DropdownMenuItem(value: 'license', child: Text('Licencia de Conducir')),
                  DropdownMenuItem(value: 'soat', child: Text('SOAT')),
                  DropdownMenuItem(value: 'criminal_record', child: Text('Antecedentes')),
                  DropdownMenuItem(value: 'vehicle_photo', child: Text('Foto del Vehículo')),
                ],
                onChanged: (value) {
                  // Handle document type selection
                },
              ),
              SizedBox(height: 16),
              // Upload button
              ElevatedButton.icon(
                onPressed: () async {
                  // Handle document upload
                  Navigator.pop(context);
                  _handleDocumentUpload();
                },
                icon: Icon(Icons.upload_file),
                label: Text('Cargar Documento'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ModernTheme.oasisGreen,
                  minimumSize: Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
