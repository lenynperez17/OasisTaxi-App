import 'package:flutter/material.dart';
import '../../utils/app_logger.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/modern_theme.dart';
import '../../widgets/animated/modern_animated_widgets.dart';
import '../../providers/auth_provider.dart';
import '../../services/security_integration_service.dart';
import '../../widgets/auth/auth_components.dart';

class ModernRegisterScreen extends StatefulWidget {
  const ModernRegisterScreen({super.key});

  @override
  State<ModernRegisterScreen> createState() => ModernRegisterScreenState();
}

class ModernRegisterScreenState extends State<ModernRegisterScreen>
    with TickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Controladores básicos para todos los usuarios
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Controladores adicionales para conductores
  final _licenseNumberController = TextEditingController();
  final _licenseExpiryController = TextEditingController();
  final _vehicleBrandController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _vehicleCapacityController = TextEditingController();
  final _soatExpiryController = TextEditingController();
  final _technicalReviewController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankNameController = TextEditingController();

  late AnimationController _backgroundController;
  late AnimationController _formController;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _userType = 'passenger';
  String _vehicleType = 'sedan';
  bool _acceptTerms = false;
  int _currentStep = 0;

  // Obtener el número máximo de pasos según el tipo de usuario
  int get _maxSteps => _userType == 'driver' ? 4 : 3;

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('ModernRegisterScreen', 'initState');

    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _formController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }


  @override
  void dispose() {
    // Dispose controladores básicos
    _backgroundController.dispose();
    _formController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    // Dispose controladores de conductor
    _licenseNumberController.dispose();
    _licenseExpiryController.dispose();
    _vehicleBrandController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _vehicleColorController.dispose();
    _vehiclePlateController.dispose();
    _vehicleCapacityController.dispose();
    _soatExpiryController.dispose();
    _technicalReviewController.dispose();
    _bankAccountController.dispose();
    _bankNameController.dispose();

    super.dispose();
  }

  // Función de registro mejorada con información adicional para conductores
  Future<void> _registerUser() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    AppLogger.info('Iniciando registro de usuario tipo: $_userType');

    try {
      setState(() => _isLoading = true);

      // Usar el email proporcionado o crear uno con el teléfono
      String email = _emailController.text.isNotEmpty
          ? _emailController.text
          : '${_phoneController.text}@oasistaxi.com';

      // Registrar usuario en Firebase Auth
      await authProvider.register(
        email: email,
        password: _passwordController.text,
        fullName: _nameController.text,
        phone: _phoneController.text,
        userType: _userType,
      );

      // Si es conductor, guardar información adicional
      if (_userType == 'driver') {
        await _saveDriverAdditionalInfo();
      }

      // Verificar que el widget siga montado antes de usar context
      if (!mounted) return;

      // Mostrar mensaje de éxito diferenciado
      String successMessage = _userType == 'driver'
          ? 'Cuenta de conductor creada. Tu perfil está pendiente de verificación.'
          : 'Cuenta de pasajero creada exitosamente.';

      AppLogger.info('Registro exitoso para usuario tipo: $_userType');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: ModernTheme.oasisGreen,
          duration: const Duration(seconds: 3),
        ),
      );

      // Navegar según el tipo de usuario
      if (_userType == 'passenger') {
        AppLogger.navigation('ModernRegisterScreen', '/passenger/home');
        Navigator.pushReplacementNamed(context, '/passenger/home');
      } else {
        AppLogger.navigation('ModernRegisterScreen', '/driver/home');
        Navigator.pushReplacementNamed(context, '/driver/home');
      }
    } catch (e) {
      if (!mounted) return;
      AppLogger.error('Error en registro de usuario tipo $_userType', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al registrar: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Guardar información adicional del conductor en Firestore
  Future<void> _saveDriverAdditionalInfo() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;

    if (userId == null) return;

    try {
      // Guardar en la colección 'drivers'
      await FirebaseFirestore.instance.collection('drivers').doc(userId).set({
        'userId': userId,
        'status':
            'pending_verification', // Estado inicial pendiente de verificación
        'verifiedAt': null,
        'license': {
          'number': _licenseNumberController.text,
          'expiryDate': _licenseExpiryController.text,
        },
        'vehicle': {
          'brand': _vehicleBrandController.text,
          'model': _vehicleModelController.text,
          'year': int.tryParse(_vehicleYearController.text) ?? 0,
          'color': _vehicleColorController.text,
          'plate': _vehiclePlateController.text,
          'type': _vehicleType,
          'capacity': int.tryParse(_vehicleCapacityController.text) ?? 4,
        },
        'documents': {
          'soatExpiry': _soatExpiryController.text,
          'technicalReviewExpiry': _technicalReviewController.text,
        },
        'bankAccount': {
          'accountNumber': _bankAccountController.text,
          'bankName': _bankNameController.text,
        },
        'rating': 5.0, // Rating inicial
        'totalTrips': 0,
        'totalEarnings': 0.0,
        'isOnline': false,
        'isAvailable': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Actualizar el documento del usuario con el estado de verificación
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'driverStatus': 'pending_verification',
      });
    } catch (e) {
      AppLogger.error('al guardar información del conductor', e);
      rethrow;
    }
  }

  // Seleccionar fecha
  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ModernTheme.oasisGreen,
              onPrimary: Colors.white,
              onSurface: ModernTheme.oasisBlack,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        controller.text =
            "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo animado
          AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ModernTheme.oasisGreen,
                      ModernTheme.oasisBlack,
                      ModernTheme.accentGray,
                    ],
                    transform: GradientRotation(
                        _backgroundController.value * 2 * math.pi),
                  ),
                ),
              );
            },
          ),

          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(ModernTheme.getResponsivePadding(context)),
                child: Column(
                  children: [
                    // Header con AuthComponents
                    Row(
                      children: [
                        IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: AuthComponents.buildAuthHeader(
                            context: context,
                            title: 'Crear cuenta',
                          ),
                        ),
                      ],
                    ),

                    AuthComponents.buildSpacer(context: context, multiplier: 0.8),

                    // Progress indicator mejorado
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          // Texto indicador del paso actual
                          Text(
                            _getStepTitle(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Barra de progreso
                          Row(
                            children: List.generate(_maxSteps, (index) {
                              return Expanded(
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: index <= _currentStep
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),

                    AuthComponents.buildSpacer(context: context, multiplier: 1.2),

                    // Form con AuthComponents
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: AuthComponents.buildFormContainer(
                        context: context,
                        key: ValueKey<int>(_currentStep),
                        child: Form(
                          key: _formKey,
                          child: _buildCurrentStep(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Obtener título del paso actual
  String _getStepTitle() {
    if (_currentStep == 0) return 'Paso 1 de $_maxSteps: Tipo de cuenta';

    if (_userType == 'passenger') {
      switch (_currentStep) {
        case 1:
          return 'Paso 2 de 3: Información personal';
        case 2:
          return 'Paso 3 de 3: Crear contraseña';
        default:
          return '';
      }
    } else {
      switch (_currentStep) {
        case 1:
          return 'Paso 2 de 4: Información personal';
        case 2:
          return 'Paso 3 de 4: Información del vehículo';
        case 3:
          return 'Paso 4 de 4: Documentos y cuenta';
        default:
          return '';
      }
    }
  }

  Widget _buildCurrentStep() {
    if (_currentStep == 0) {
      return _buildUserTypeStep();
    }

    if (_userType == 'passenger') {
      switch (_currentStep) {
        case 1:
          return _buildPersonalInfoStep();
        case 2:
          return _buildPasswordStep();
        default:
          return const SizedBox();
      }
    } else {
      switch (_currentStep) {
        case 1:
          return _buildPersonalInfoStep();
        case 2:
          return _buildVehicleInfoStep();
        case 3:
          return _buildDocumentsStep();
        default:
          return const SizedBox();
      }
    }
  }

  Widget _buildUserTypeStep() {
    return Column(
      children: [
        Text(
          '¿Cómo quieres usar Oasis Taxi?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        AuthComponents.buildSpacer(context: context, multiplier: 0.3),
        Text(
          _userType == 'driver'
              ? 'Los conductores necesitan verificación adicional'
              : 'Elige cómo quieres usar la aplicación',
          style: TextStyle(
            color: ModernTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        AuthComponents.buildSpacer(context: context, multiplier: 1.2),
        AnimatedElevatedCard(
          onTap: () {
            setState(() {
              _userType = 'passenger';
              _currentStep = 1;
            });
          },
          borderRadius: 16,
          color: _userType == 'passenger'
              ? ModernTheme.oasisGreen.withValues(alpha: 0.1)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ModernTheme.oasisGreen.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    color: ModernTheme.oasisGreen,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pasajero',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Solicita viajes y negocia precios',
                        style: TextStyle(
                          color: ModernTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Registro rápido y simple',
                        style: TextStyle(
                          color: ModernTheme.oasisGreen,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios),
              ],
            ),
          ),
        ),
        AuthComponents.buildSpacer(context: context, multiplier: 0.6),
        AnimatedElevatedCard(
          onTap: () {
            setState(() {
              _userType = 'driver';
              _currentStep = 1;
            });
          },
          borderRadius: 16,
          color: _userType == 'driver'
              ? ModernTheme.oasisBlack.withValues(alpha: 0.1)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ModernTheme.oasisBlack.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_car,
                    color: ModernTheme.oasisBlack,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conductor',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Acepta viajes y gana dinero',
                        style: TextStyle(
                          color: ModernTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Requiere verificación de documentos',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoStep() {
    return Column(
      children: [
        Text(
          'Información personal',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (_userType == 'driver') ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Información para verificación',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),

        AuthComponents.buildTextField(
          context: context,
          controller: _nameController,
          label: 'Nombre completo',
          fieldType: 'fullname',
          hintText:
              _userType == 'driver' ? 'Como aparece en tu licencia' : null,
          prefixIcon:
              const Icon(Icons.person_outline, color: ModernTheme.oasisGreen),
        ),

        const SizedBox(height: 16),

        AuthComponents.buildTextField(
          context: context,
          controller: _phoneController,
          label: 'Número de teléfono',
          fieldType: 'phone',
          hintText: 'WhatsApp preferible',
          prefixIcon: const Icon(Icons.phone, color: ModernTheme.oasisGreen),
        ),

        const SizedBox(height: 16),

        AuthComponents.buildTextField(
          context: context,
          controller: _emailController,
          label: 'Correo electrónico',
          fieldType: 'email',
          hintText: 'Para notificaciones importantes',
          prefixIcon:
              const Icon(Icons.email_outlined, color: ModernTheme.oasisGreen),
        ),

        if (_userType == 'driver') ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _licenseNumberController,
            decoration: InputDecoration(
              labelText: 'Número de licencia de conducir',
              prefixIcon: const Icon(Icons.badge_outlined,
                  color: ModernTheme.oasisGreen),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa tu número de licencia';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _licenseExpiryController,
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Fecha de vencimiento de licencia',
              prefixIcon: const Icon(Icons.calendar_today,
                  color: ModernTheme.oasisGreen),
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            onTap: () => _selectDate(_licenseExpiryController),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Selecciona la fecha de vencimiento';
              }
              return null;
            },
          ),
        ],

        // Para pasajeros, agregar campos de contraseña aquí si es el último paso
        if (_userType == 'passenger' && _currentStep == 1) ...[
          const SizedBox(height: 16),
          AuthComponents.buildTextField(
            context: context,
            controller: _passwordController,
            label: 'Contraseña',
            fieldType: 'password',
            hintText: 'Mínimo 8 caracteres, al menos 1 letra y 1 número',
            prefixIcon:
                const Icon(Icons.lock_outline, color: ModernTheme.oasisGreen),
            suffixIcon: IconButton(
              icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            obscureText: _obscurePassword,
          ),
          const SizedBox(height: 16),
          AuthComponents.buildTextField(
            context: context,
            controller: _confirmPasswordController,
            label: 'Confirmar contraseña',
            fieldType: 'password',
            prefixIcon:
                const Icon(Icons.lock_outline, color: ModernTheme.oasisGreen),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword
                  ? Icons.visibility
                  : Icons.visibility_off),
              onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            obscureText: _obscureConfirmPassword,
            onSaved: (value) {
              if (value != _passwordController.text) {
                return 'Las contraseñas no coinciden';
              }
              return null;
            },
          ),
        ],

        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: AuthComponents.buildSecondaryButton(
                context: context,
                text: 'Atrás',
                onPressed: () {
                  setState(() => _currentStep = 0);
                },
                height: 56.0,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: AuthComponents.buildPrimaryButton(
                context: context,
                text: _userType == 'passenger' ? 'Continuar' : 'Siguiente',
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    setState(() {
                      if (_userType == 'passenger') {
                        _currentStep = 2; // Ir al paso de contraseña
                      } else {
                        _currentStep = 2; // Ir a información del vehículo
                      }
                    });
                  }
                },
                height: 56.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Nuevo paso para información del vehículo (solo conductores)
  Widget _buildVehicleInfoStep() {
    return Column(
      children: [
        Text(
          'Información del vehículo',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Datos del vehículo que usarás para trabajar',
          style: TextStyle(
            color: ModernTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),

        // Tipo de vehículo
        DropdownButtonFormField<String>(
          initialValue: _vehicleType,
          decoration: InputDecoration(
            labelText: 'Tipo de vehículo',
            prefixIcon:
                const Icon(Icons.category, color: ModernTheme.oasisGreen),
          ),
          items: [
            const DropdownMenuItem(value: 'sedan', child: Text('Sedán')),
            const DropdownMenuItem(value: 'minivan', child: Text('Minivan')),
            const DropdownMenuItem(value: 'pickup', child: Text('Pickup')),
            const DropdownMenuItem(value: 'cargo', child: Text('Carga')),
          ],
          onChanged: (value) {
            setState(() => _vehicleType = value!);
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Selecciona el tipo de vehículo';
            }
            return null;
          },
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _vehicleBrandController,
                decoration: InputDecoration(
                  labelText: 'Marca',
                  prefixIcon: const Icon(Icons.directions_car,
                      color: ModernTheme.oasisGreen),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa la marca';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _vehicleModelController,
                decoration: InputDecoration(
                  labelText: 'Modelo',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa el modelo';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _vehicleYearController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Año',
                  prefixIcon: const Icon(Icons.calendar_today,
                      color: ModernTheme.oasisGreen),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa el año';
                  }
                  int? year = int.tryParse(value);
                  if (year == null ||
                      year < 2000 ||
                      year > DateTime.now().year) {
                    return 'Año inválido';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _vehicleColorController,
                decoration: InputDecoration(
                  labelText: 'Color',
                  prefixIcon:
                      const Icon(Icons.palette, color: ModernTheme.oasisGreen),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa el color';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _vehiclePlateController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Placa',
                  prefixIcon: const Icon(Icons.confirmation_number,
                      color: ModernTheme.oasisGreen),
                  helperText: 'Ej: ABC-123',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa la placa';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _vehicleCapacityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Capacidad',
                  suffixText: 'pasajeros',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Requerido';
                  }
                  int? capacity = int.tryParse(value);
                  if (capacity == null || capacity < 1 || capacity > 8) {
                    return 'Inválido';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: AuthComponents.buildSecondaryButton(
                context: context,
                text: 'Atrás',
                onPressed: () {
                  setState(() => _currentStep = 1);
                },
                height: 56.0,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: AuthComponents.buildPrimaryButton(
                context: context,
                text: 'Siguiente',
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    setState(() => _currentStep = 3);
                  }
                },
                height: 56.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Nuevo paso para documentos y cuenta bancaria (solo conductores)
  Widget _buildDocumentsStep() {
    return Column(
      children: [
        Text(
          'Documentos y pagos',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.security, size: 20, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tus documentos serán verificados antes de activar tu cuenta',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Documentos del vehículo
        Text(
          'Documentos del vehículo',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _soatExpiryController,
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Vencimiento del SOAT',
            prefixIcon:
                const Icon(Icons.assignment, color: ModernTheme.oasisGreen),
            suffixIcon: Icon(Icons.arrow_drop_down),
            helperText: 'Seguro Obligatorio de Accidentes de Tránsito',
          ),
          onTap: () => _selectDate(_soatExpiryController),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Selecciona la fecha de vencimiento del SOAT';
            }
            return null;
          },
        ),

        const SizedBox(height: 16),

        TextFormField(
          controller: _technicalReviewController,
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Vencimiento de revisión técnica',
            prefixIcon: const Icon(Icons.build, color: ModernTheme.oasisGreen),
            suffixIcon: Icon(Icons.arrow_drop_down),
          ),
          onTap: () => _selectDate(_technicalReviewController),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Selecciona la fecha de vencimiento';
            }
            return null;
          },
        ),

        const SizedBox(height: 24),

        // Información bancaria
        Text(
          'Cuenta para recibir pagos',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _bankNameController,
          decoration: InputDecoration(
            labelText: 'Banco',
            prefixIcon: const Icon(Icons.account_balance,
                color: ModernTheme.oasisGreen),
            helperText: 'Nombre del banco o billetera digital',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Ingresa el nombre del banco';
            }
            return null;
          },
        ),

        const SizedBox(height: 16),

        TextFormField(
          controller: _bankAccountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Número de cuenta',
            prefixIcon:
                const Icon(Icons.credit_card, color: ModernTheme.oasisGreen),
            helperText: 'CCI o número de cuenta bancaria',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Ingresa el número de cuenta';
            }
            return null;
          },
        ),

        const SizedBox(height: 16),

        // Contraseña para conductores
        AuthComponents.buildTextField(
          context: context,
          controller: _passwordController,
          label: 'Contraseña',
          fieldType: 'password',
          hintText: 'Mínimo 8 caracteres, al menos 1 letra y 1 número',
          prefixIcon: Icon(Icons.lock_outline, color: ModernTheme.oasisGreen),
          suffixIcon: IconButton(
            icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          obscureText: _obscurePassword,
        ),

        const SizedBox(height: 16),

        AuthComponents.buildTextField(
          context: context,
          controller: _confirmPasswordController,
          label: 'Confirmar contraseña',
          fieldType: 'password',
          prefixIcon: Icon(Icons.lock_outline, color: ModernTheme.oasisGreen),
          suffixIcon: IconButton(
            icon: Icon(_obscureConfirmPassword
                ? Icons.visibility
                : Icons.visibility_off),
            onPressed: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword),
          ),
          obscureText: _obscureConfirmPassword,
          onSaved: (value) {
            if (value != _passwordController.text) {
              return 'Las contraseñas no coinciden';
            }
            return null;
          },
        ),

        const SizedBox(height: 20),

        CheckboxListTile(
          value: _acceptTerms,
          onChanged: (value) => setState(() => _acceptTerms = value!),
          title: Text(
            'Acepto los términos y condiciones',
            style: TextStyle(fontSize: 14),
          ),
          subtitle: Text(
            'Incluye verificación de documentos y antecedentes',
            style: TextStyle(fontSize: 12, color: ModernTheme.textSecondary),
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),

        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: AuthComponents.buildSecondaryButton(
                context: context,
                text: 'Atrás',
                onPressed: () {
                  setState(() => _currentStep = 2);
                },
                height: 56.0,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: AuthComponents.buildPrimaryButton(
                context: context,
                text: 'Crear cuenta de conductor',
                icon: Icons.check,
                isLoading: _isLoading,
                onPressed: _acceptTerms
                    ? () async {
                        if (_formKey.currentState!.validate()) {
                          await _registerUser();
                        }
                      }
                    : () {},
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Paso de contraseña para pasajeros
  Widget _buildPasswordStep() {
    return Column(
      children: [
        Text(
          'Crea tu contraseña',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Última paso para crear tu cuenta',
          style: TextStyle(
            color: ModernTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: ModernTheme.oasisGreen, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Registro rápido y simple',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: ModernTheme.oasisGreen, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Sin verificación de documentos',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: ModernTheme.oasisGreen, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Empieza a usar la app de inmediato',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        CheckboxListTile(
          value: _acceptTerms,
          onChanged: (value) => setState(() => _acceptTerms = value!),
          title: Text(
            'Acepto los términos y condiciones',
            style: TextStyle(fontSize: 14),
          ),
          subtitle: Text(
            'Y la política de privacidad de Oasis Taxi',
            style: TextStyle(fontSize: 12, color: ModernTheme.textSecondary),
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.payments, size: 20, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Podrás agregar métodos de pago después de crear tu cuenta',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: AuthComponents.buildSecondaryButton(
                context: context,
                text: 'Atrás',
                onPressed: () {
                  setState(() => _currentStep = 1);
                },
                height: 56.0,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: AuthComponents.buildPrimaryButton(
                context: context,
                text: 'Crear mi cuenta',
                icon: Icons.check,
                isLoading: _isLoading,
                onPressed: _acceptTerms
                    ? () async {
                        if (_formKey.currentState!.validate()) {
                          await _registerUser();
                        }
                      }
                    : () {},
                height: 56.0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
