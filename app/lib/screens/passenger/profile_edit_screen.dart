import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/widgets/oasis_button.dart';
import '../../widgets/common/oasis_app_bar.dart';
import '../../widgets/cards/oasis_card.dart';
import '../../services/security_integration_service.dart';
import '../../utils/app_logger.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ProfileEditScreenState createState() => ProfileEditScreenState();
}

class ProfileEditScreenState extends State<ProfileEditScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();
  String? _userId; // Se obtendrá del usuario actual

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  // Form controllers
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emergencyNameController =
      TextEditingController();
  final TextEditingController _emergencyPhoneController =
      TextEditingController();

  // User data
  String _profileImagePath = '';
  String _birthDate = '';
  String _gender = 'Masculino';
  String _documentType = 'DNI';
  String _documentNumber = '';
  bool _notificationsEnabled = true;
  bool _smsEnabled = false;
  bool _emailPromotions = true;
  bool _locationSharing = true;

  // Form state
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('ProfileEditScreen', 'initState');

    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    );

    _loadUserData();
    _fadeController.forward();
    _slideController.forward();

    // Listen for changes
    _nameController.addListener(_onFieldChanged);
    _lastNameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _emergencyNameController.addListener(_onFieldChanged);
    _emergencyPhoneController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _nameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => _isLoading = true);

      // Obtener el usuario autenticado actual
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        // Si no hay usuario autenticado, regresar a la pantalla anterior
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Debe iniciar sesión para editar su perfil'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      _userId = currentUser.uid;

      // Cargar datos del usuario desde Firestore
      final userDoc = await _firestore.collection('users').doc(_userId).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        setState(() {
          _nameController.text = data['firstName'] ?? '';
          _lastNameController.text = data['lastName'] ?? '';
          _emailController.text = data['email'] ?? '';
          _phoneController.text = data['phoneNumber'] ?? '';
          _birthDate = data['birthDate'] ?? '';
          _gender = data['gender'] ?? 'Masculino';
          _documentType = data['documentType'] ?? 'DNI';
          _documentNumber = data['documentNumber'] ?? '';
          _emergencyNameController.text = data['emergencyContactName'] ?? '';
          _emergencyPhoneController.text = data['emergencyContactPhone'] ?? '';
          _profileImagePath = data['profileImage'] ?? '';
          _notificationsEnabled = data['notificationsEnabled'] ?? true;
          _smsEnabled = data['smsEnabled'] ?? false;
          _emailPromotions = data['emailPromotions'] ?? true;
          _locationSharing = data['locationSharing'] ?? true;
        });
      } else {
        // Si no existe el documento, mostrar campos vacíos (sin crear datos por defecto)
        setState(() {
          // Los campos ya están vacíos por defecto
        });
      }
    } catch (e) {
      AppLogger.error('cargando datos del usuario', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos del perfil'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        _handlePop(shouldPop);
      },
      child: Scaffold(
        backgroundColor: ModernTheme.backgroundLight,
        appBar: OasisAppBar.standard(
          title: 'Editar Perfil',
          showBackButton: true,
          actions: [
            if (_hasChanges)
              OasisButton.text(
                text: 'Guardar',
                onPressed: _isLoading ? null : _saveProfile,
                textColor: Colors.white,
              ),
          ],
        ),
        body: AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: ModernTheme.getResponsivePadding(
                    context,
                    mobile: AppSpacing.all(AppSpacing.screenPadding),
                    tablet: AppSpacing.all(AppSpacing.containerPaddingLarge),
                    desktop: AppSpacing.all(AppSpacing.sectionPadding),
                  ),
                  child: Column(
                    children: [
                      // Profile image section
                      _buildProfileImageSection(),

                      AppSpacing.verticalSpaceXXL,

                      // Personal information
                      _buildPersonalInfoSection(),

                      AppSpacing.verticalSpaceLG,

                      // Contact information
                      _buildContactInfoSection(),

                      AppSpacing.verticalSpaceLG,

                      // Document information
                      _buildDocumentInfoSection(),

                      AppSpacing.verticalSpaceLG,

                      // Emergency contact
                      _buildEmergencyContactSection(),

                      AppSpacing.verticalSpaceLG,

                      // Preferences
                      _buildPreferencesSection(),

                      AppSpacing.verticalSpaceXXL,

                      // Save button
                      _buildSaveButton(),

                      AppSpacing.verticalSpaceXXL,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileImageSection() {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - _slideAnimation.value)),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _profileImagePath.isEmpty
                          ? LinearGradient(
                              colors: [
                                ModernTheme.oasisGreen,
                                ModernTheme.oasisGreen.withValues(alpha: 0.7)
                              ],
                            )
                          : null,
                      image: _profileImagePath.isNotEmpty
                          ? DecorationImage(
                              image: _isNetworkImage(_profileImagePath)
                                  ? CachedNetworkImageProvider(
                                      _profileImagePath) as ImageProvider
                                  : FileImage(File(_profileImagePath))
                                      as ImageProvider,
                              fit: BoxFit.cover,
                            )
                          : null,
                      boxShadow: ModernTheme.getCardShadows(context),
                    ),
                    child: _profileImagePath.isEmpty
                        ? Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _changeProfileImage,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: ModernTheme.primaryBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              AppSpacing.verticalSpaceMD,
              Text(
                'Toca para cambiar foto',
                style: TextStyle(
                  color: ModernTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPersonalInfoSection() {
    return _buildSection(
      'Información Personal',
      Icons.person,
      ModernTheme.primaryBlue,
      [
        Row(
          children: [
            Expanded(
              child: _buildTextFormField(
                controller: _nameController,
                label: 'Nombres',
                icon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa tu nombre';
                  }
                  return null;
                },
              ),
            ),
            AppSpacing.horizontalSpaceMD,
            Expanded(
              child: _buildTextFormField(
                controller: _lastNameController,
                label: 'Apellidos',
                icon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa tus apellidos';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        AppSpacing.verticalSpaceMD,
        GestureDetector(
          onTap: _selectBirthDate,
          child: Container(
            padding: AppSpacing.all(AppSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: AppSpacing.borderRadiusMD,
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: ModernTheme.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _birthDate.isEmpty ? 'Fecha de nacimiento' : _birthDate,
                    style: TextStyle(
                      color: _birthDate.isEmpty
                          ? ModernTheme.textSecondary
                          : ModernTheme.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: ModernTheme.textSecondary),
              ],
            ),
          ),
        ),
        AppSpacing.verticalSpaceMD,
        DropdownButtonFormField<String>(
          initialValue: _gender,
          decoration: InputDecoration(
            labelText: 'Género',
            prefixIcon: Icon(Icons.wc),
            border: OutlineInputBorder(
              borderRadius: AppSpacing.borderRadiusMD,
            ),
          ),
          items: ['Masculino', 'Femenino', 'Otro', 'Prefiero no decir']
              .map((gender) {
            return DropdownMenuItem(
              value: gender,
              child: Text(gender),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _gender = value!;
              _hasChanges = true;
            });
          },
        ),
      ],
    );
  }

  Widget _buildContactInfoSection() {
    return _buildSection(
      'Información de Contacto',
      Icons.contact_phone,
      ModernTheme.oasisGreen,
      [
        _buildTextFormField(
          controller: _emailController,
          label: 'Correo electrónico',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Ingresa tu email';
            }
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
              return 'Ingresa un email válido';
            }
            return null;
          },
        ),
        AppSpacing.verticalSpaceMD,
        _buildTextFormField(
          controller: _phoneController,
          label: 'Número de teléfono',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Ingresa tu teléfono';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDocumentInfoSection() {
    return _buildSection(
      'Documento de Identidad',
      Icons.badge,
      Colors.orange,
      [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: _documentType,
                decoration: InputDecoration(
                  labelText: 'Tipo',
                  prefixIcon: Icon(Icons.assignment_ind),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: ['DNI', 'Pasaporte', 'Carné de Extranjería'].map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _documentType = value!;
                    _hasChanges = true;
                  });
                },
              ),
            ),
            AppSpacing.horizontalSpaceMD,
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: TextEditingController(text: _documentNumber),
                decoration: InputDecoration(
                  labelText: 'Número',
                  prefixIcon: Icon(Icons.numbers),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Requerido';
                  }
                  return null;
                },
                onChanged: (value) {
                  _documentNumber = value;
                  _onFieldChanged();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmergencyContactSection() {
    return _buildSection(
      'Contacto de Emergencia',
      Icons.emergency,
      ModernTheme.error,
      [
        _buildTextFormField(
          controller: _emergencyNameController,
          label: 'Nombre completo',
          icon: Icons.person_pin,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Ingresa el nombre del contacto';
            }
            return null;
          },
        ),
        AppSpacing.verticalSpaceMD,
        _buildTextFormField(
          controller: _emergencyPhoneController,
          label: 'Teléfono de emergencia',
          icon: Icons.phone_in_talk,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Ingresa el teléfono de emergencia';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPreferencesSection() {
    return _buildSection(
      'Preferencias',
      Icons.settings,
      Colors.purple,
      [
        SwitchListTile(
          title: Text('Notificaciones push'),
          subtitle: Text('Recibir notificaciones en el dispositivo'),
          value: _notificationsEnabled,
          onChanged: (value) {
            setState(() {
              _notificationsEnabled = value;
              _hasChanges = true;
            });
          },
          thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
        ),
        SwitchListTile(
          title: Text('Notificaciones SMS'),
          subtitle: Text('Recibir actualizaciones por mensaje de texto'),
          value: _smsEnabled,
          onChanged: (value) {
            setState(() {
              _smsEnabled = value;
              _hasChanges = true;
            });
          },
          thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
        ),
        SwitchListTile(
          title: Text('Promociones por email'),
          subtitle: Text('Recibir ofertas y descuentos por correo'),
          value: _emailPromotions,
          onChanged: (value) {
            setState(() {
              _emailPromotions = value;
              _hasChanges = true;
            });
          },
          thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
        ),
        SwitchListTile(
          title: Text('Compartir ubicación'),
          subtitle: Text('Permitir compartir ubicación durante viajes'),
          value: _locationSharing,
          onChanged: (value) {
            setState(() {
              _locationSharing = value;
              _hasChanges = true;
            });
          },
          thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
        ),
      ],
    );
  }

  Widget _buildSection(
      String title, IconData icon, Color color, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: AppSpacing.only(bottom: AppSpacing.md),
          child: Row(
            children: [
              Icon(
                icon,
                color: color,
                size: ModernTheme.getResponsiveIconSize(
                  context,
                  smallSize: AppSpacing.iconSizeSmall,
                  mediumSize: AppSpacing.iconSizeMedium,
                  largeSize: AppSpacing.iconSizeLarge,
                ),
              ),
              AppSpacing.horizontalSpaceSM,
              Text(
                title,
                style: TextStyle(
                  fontSize: ModernTheme.getResponsiveFontSize(context, 18),
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        OasisCard.elevated(
          padding: AppSpacing.cardPaddingLargeAll,
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    // Determinar el tipo de campo basado en el label
    String fieldType = 'text';
    if (label.toLowerCase().contains('nombre') ||
        label.toLowerCase().contains('apellido')) {
      fieldType = 'name';
    } else if (label.toLowerCase().contains('correo') ||
        label.toLowerCase().contains('email')) {
      fieldType = 'email';
    } else if (label.toLowerCase().contains('teléfono') ||
        label.toLowerCase().contains('phone')) {
      fieldType = 'phone';
    }

    return SecurityIntegrationService.buildSecureTextField(
      context: context,
      controller: controller,
      label: label,
      fieldType: fieldType,
      prefixIcon: Icon(icon),
      keyboardType: keyboardType,
    );
  }

  Widget _buildSaveButton() {
    return OasisButton.primary(
      text: 'Guardar Cambios',
      onPressed: _isLoading || !_hasChanges ? null : _saveProfile,
      isLoading: _isLoading,
      width: double.infinity,
    );
  }

  void _changeProfileImage() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: AppSpacing.cardPaddingLargeAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cambiar foto de perfil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            AppSpacing.verticalSpaceLG,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: AppSpacing.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: ModernTheme.primaryBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          color: ModernTheme.primaryBlue,
                          size: 32,
                        ),
                      ),
                      AppSpacing.verticalSpaceSM,
                      Text('Cámara'),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: AppSpacing.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.photo_library,
                          color: ModernTheme.oasisGreen,
                          size: 32,
                        ),
                      ),
                      AppSpacing.verticalSpaceSM,
                      Text('Galería'),
                    ],
                  ),
                ),
                if (_profileImagePath.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _removeProfileImage();
                    },
                    child: Column(
                      children: [
                        Container(
                          padding: AppSpacing.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: ModernTheme.error.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.delete,
                            color: ModernTheme.error,
                            size: 32,
                          ),
                        ),
                        AppSpacing.verticalSpaceSM,
                        Text('Eliminar'),
                      ],
                    ),
                  ),
              ],
            ),
            AppSpacing.verticalSpaceLG,
          ],
        ),
      ),
    );
  }

  void _pickImageFromCamera() async {
    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedImage != null) {
        await _uploadAndSetProfileImage(File(pickedImage.path));
      }
    } catch (e) {
      AppLogger.error('seleccionando imagen desde cámara', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al tomar foto desde la cámara'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  void _pickImageFromGallery() async {
    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedImage != null) {
        await _uploadAndSetProfileImage(File(pickedImage.path));
      }
    } catch (e) {
      AppLogger.error('seleccionando imagen desde galería', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al seleccionar imagen de la galería'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  void _removeProfileImage() async {
    try {
      // Eliminar de Firebase Storage si existe
      if (_profileImagePath.isNotEmpty &&
          _profileImagePath.contains('firebase')) {
        final Reference storageRef =
            FirebaseStorage.instance.refFromURL(_profileImagePath);
        await storageRef.delete();
      }

      setState(() {
        _profileImagePath = '';
        _hasChanges = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto de perfil eliminada'),
            backgroundColor: ModernTheme.warning,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('eliminando imagen de perfil', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al eliminar foto de perfil'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _uploadAndSetProfileImage(File imageFile) async {
    if (!mounted) return;

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Subiendo imagen...'),
          ],
        ),
      ),
    );

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Usuario no autenticado');
      }

      // Crear referencia en Firebase Storage
      final String fileName =
          'profile_${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child(fileName);

      // Subir archivo
      final UploadTask uploadTask = storageRef.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;

      // Obtener URL de descarga
      final String downloadURL = await snapshot.ref.getDownloadURL();

      // Actualizar estado local
      setState(() {
        _profileImagePath = downloadURL;
        _hasChanges = true;
      });

      if (mounted) {
        Navigator.pop(context); // Cerrar dialog de loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagen subida exitosamente'),
            backgroundColor: ModernTheme.success,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('subiendo imagen de perfil', e);

      if (mounted) {
        Navigator.pop(context); // Cerrar dialog de loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir imagen: ${e.toString()}'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  void _selectBirthDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(1990, 1, 1),
      firstDate: DateTime(1950),
      lastDate:
          DateTime.now().subtract(Duration(days: 365 * 18)), // Minimum 18 years
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ModernTheme.oasisGreen,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null && mounted) {
      setState(() {
        _birthDate =
            '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}';
        _hasChanges = true;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Descartar cambios?'),
        content: Text(
            'Tienes cambios sin guardar. ¿Estás seguro de que quieres salir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: OasisButton.danger().style,
            child: Text('Descartar'),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Guardar datos en Firestore
      await _firestore.collection('users').doc(_userId).update({
        'firstName': _nameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'birthDate': _birthDate,
        'gender': _gender,
        'documentType': _documentType,
        'documentNumber': _documentNumber,
        'emergencyContactName': _emergencyNameController.text.trim(),
        'emergencyContactPhone': _emergencyPhoneController.text.trim(),
        'profileImage': _profileImagePath,
        'notificationsEnabled': _notificationsEnabled,
        'smsEnabled': _smsEnabled,
        'emailPromotions': _emailPromotions,
        'locationSharing': _locationSharing,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasChanges = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Perfil actualizado exitosamente'),
            backgroundColor: ModernTheme.success,
            action: SnackBarAction(
              label: 'Ver perfil',
              textColor: Colors.white,
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('guardando perfil', e);

      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar el perfil'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  void _handlePop(bool shouldPop) {
    if (!mounted || !shouldPop) return;
    Navigator.of(context).pop();
  }

  bool _isNetworkImage(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }
}
