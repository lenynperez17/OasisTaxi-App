import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/modern_theme.dart';
import '../../services/security_integration_service.dart';
import '../../utils/app_logger.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  DriverProfileScreenState createState() => DriverProfileScreenState();
}

class DriverProfileScreenState extends State<DriverProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  // Profile data
  DriverProfile? _profile;
  bool _isLoading = true;
  bool _isEditing = false;

  // Form controllers
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _emergencyContactController =
      TextEditingController();
  final TextEditingController _emergencyPhoneController =
      TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('DriverProfileScreen', 'initState');

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

    _loadProfile();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Cargar datos del conductor desde Firebase
        final driverDoc = await FirebaseFirestore.instance
            .collection('drivers')
            .doc(user.uid)
            .get();

        if (driverDoc.exists) {
          final data = driverDoc.data()!;

          // Cargar estadísticas
          final statsDoc = await FirebaseFirestore.instance
              .collection('drivers')
              .doc(user.uid)
              .collection('statistics')
              .doc('summary')
              .get();

          final stats = statsDoc.data() ?? {};

          // Cargar vehículo
          final vehicleDoc = await FirebaseFirestore.instance
              .collection('drivers')
              .doc(user.uid)
              .collection('vehicles')
              .limit(1)
              .get();

          VehicleInfo? vehicleInfo;
          if (vehicleDoc.docs.isNotEmpty) {
            final vehicleData = vehicleDoc.docs.first.data();
            vehicleInfo = VehicleInfo(
              make: vehicleData['make'] ?? '',
              model: vehicleData['model'] ?? '',
              year: vehicleData['year'] ?? DateTime.now().year,
              color: vehicleData['color'] ?? '',
              plate: vehicleData['plate'] ?? '',
              capacity: vehicleData['capacity'] ?? 4,
            );
          } else {
            vehicleInfo = VehicleInfo(
              make: '',
              model: '',
              year: DateTime.now().year,
              color: '',
              plate: '',
              capacity: 4,
            );
          }

          // Cargar logros
          final achievementsSnapshot = await FirebaseFirestore.instance
              .collection('drivers')
              .doc(user.uid)
              .collection('achievements')
              .get();

          final achievements = achievementsSnapshot.docs.map((doc) {
            final data = doc.data();
            return Achievement(
              id: doc.id,
              name: data['name'] ?? '',
              description: data['description'] ?? '',
              iconUrl: data['iconUrl'] ?? '',
              unlockedDate: (data['unlockedDate'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
            );
          }).toList();

          setState(() {
            _profile = DriverProfile(
              id: user.uid,
              name: data['name'] ?? user.displayName ?? '',
              email: data['email'] ?? user.email ?? '',
              phone: data['phone'] ?? user.phoneNumber ?? '',
              profileImageUrl: data['profileImageUrl'] ?? user.photoURL ?? '',
              rating: (data['rating'] ?? 5.0).toDouble(),
              totalTrips: stats['totalTrips'] ?? 0,
              totalDistance: (stats['totalDistance'] ?? 0.0).toDouble(),
              totalHours: (stats['totalHours'] ?? 0.0).toDouble(),
              totalEarnings: (stats['totalEarnings'] ?? 0.0).toDouble(),
              memberSince:
                  (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              bio: data['bio'] ?? '',
              emergencyContact: EmergencyContact(
                name: data['emergencyContactName'] ?? '',
                phone: data['emergencyContactPhone'] ?? '',
                relationship: data['emergencyContactRelationship'] ?? '',
              ),
              preferences: DriverPreferences(
                acceptPets: data['acceptPets'] ?? false,
                acceptSmoking: data['acceptSmoking'] ?? false,
                musicPreference: data['musicPreference'] ?? 'Ninguna',
                languages: List<String>.from(data['languages'] ?? ['Español']),
                maxTripDistance: (data['maxTripDistance'] ?? 50.0).toDouble(),
                preferredZones: List<String>.from(data['preferredZones'] ?? []),
              ),
              achievements: achievements,
              vehicleInfo: vehicleInfo ??
                  VehicleInfo(
                    brand: '',
                    model: '',
                    year: DateTime.now().year,
                    color: '',
                    plateNumber: '',
                    vehicleType: 'sedan',
                    capacity: 4,
                  ),
              workSchedule: WorkSchedule(
                mondayStart: data['mondayStart'] ?? '07:00',
                mondayEnd: data['mondayEnd'] ?? '22:00',
                tuesdayStart: data['tuesdayStart'] ?? '07:00',
                tuesdayEnd: data['tuesdayEnd'] ?? '22:00',
                wednesdayStart: data['wednesdayStart'] ?? '07:00',
                wednesdayEnd: data['wednesdayEnd'] ?? '22:00',
                thursdayStart: data['thursdayStart'] ?? '07:00',
                thursdayEnd: data['thursdayEnd'] ?? '22:00',
                fridayStart: data['fridayStart'] ?? '07:00',
                fridayEnd: data['fridayEnd'] ?? '22:00',
                saturdayStart: data['saturdayStart'] ?? '08:00',
                saturdayEnd: data['saturdayEnd'] ?? '20:00',
                sundayStart: data['sundayStart'] ?? '10:00',
                sundayEnd: data['sundayEnd'] ?? '18:00',
              ),
            );

            // Inicializar controladores de formulario
            _nameController.text = _profile!.name;
            _phoneController.text = _profile!.phone;
            _emailController.text = _profile!.email;
            _emergencyContactController.text = _profile!.emergencyContact.name;
            _emergencyPhoneController.text = _profile!.emergencyContact.phone;
            _bioController.text = _profile!.bio;
          });
        } else {
          // Si no existe el documento, crear uno nuevo
          await _createNewDriverProfile(user);
        }
      }
    } catch (e) {
      AppLogger.error('cargando perfil', e);
      _createEmptyProfile();
    } finally {
      setState(() => _isLoading = false);
      _fadeController.forward();
      _slideController.forward();
    }
  }

  Future<void> _createNewDriverProfile(User user) async {
    try {
      await FirebaseFirestore.instance.collection('drivers').doc(user.uid).set({
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'phone': user.phoneNumber ?? '',
        'profileImageUrl': user.photoURL ?? '',
        'rating': 5.0,
        'acceptPets': false,
        'acceptSmoking': false,
        'musicPreference': 'Ninguna',
        'languages': ['Español'],
        'maxTripDistance': 50.0,
        'preferredZones': [],
        'bio': '',
        'emergencyContactName': '',
        'emergencyContactPhone': '',
        'emergencyContactRelationship': '',
        'createdAt': FieldValue.serverTimestamp(),
        'mondayStart': '07:00',
        'mondayEnd': '22:00',
        'tuesdayStart': '07:00',
        'tuesdayEnd': '22:00',
        'wednesdayStart': '07:00',
        'wednesdayEnd': '22:00',
        'thursdayStart': '07:00',
        'thursdayEnd': '22:00',
        'fridayStart': '07:00',
        'fridayEnd': '22:00',
        'saturdayStart': '08:00',
        'saturdayEnd': '20:00',
        'sundayStart': '10:00',
        'sundayEnd': '18:00',
      });

      // Cargar el perfil recién creado
      _loadProfile();
    } catch (e) {
      AppLogger.error('creando perfil', e);
      _createEmptyProfile();
    }
  }

  void _createEmptyProfile() {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _profile = DriverProfile(
        id: user?.uid ?? '',
        name: user?.displayName ?? '',
        email: user?.email ?? '',
        phone: user?.phoneNumber ?? '',
        profileImageUrl: user?.photoURL ?? '',
        rating: 5.0,
        totalTrips: 0,
        totalDistance: 0.0,
        totalHours: 0.0,
        totalEarnings: 0.0,
        memberSince: DateTime.now(),
        bio: '',
        emergencyContact: EmergencyContact(
          name: '',
          phone: '',
          relationship: '',
        ),
        preferences: DriverPreferences(
          acceptPets: false,
          acceptSmoking: false,
          musicPreference: 'Ninguna',
          languages: ['Español'],
          maxTripDistance: 50.0,
          preferredZones: [],
        ),
        achievements: [],
        vehicleInfo: VehicleInfo(
          make: '',
          model: '',
          year: DateTime.now().year,
          color: '',
          plate: '',
          capacity: 4,
        ),
        workSchedule: WorkSchedule(
          mondayStart: '07:00',
          mondayEnd: '22:00',
          tuesdayStart: '07:00',
          tuesdayEnd: '22:00',
          wednesdayStart: '07:00',
          wednesdayEnd: '22:00',
          thursdayStart: '07:00',
          thursdayEnd: '22:00',
          fridayStart: '07:00',
          fridayEnd: '22:00',
          saturdayStart: '08:00',
          saturdayEnd: '20:00',
          sundayStart: '10:00',
          sundayEnd: '18:00',
        ),
      );

      _nameController.text = _profile!.name;
      _phoneController.text = _profile!.phone;
      _emailController.text = _profile!.email;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: ModernTheme.oasisGreen,
        elevation: 0,
        title: Text(
          'Mi Perfil',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: Icon(Icons.edit, color: Colors.white),
              onPressed: _toggleEdit,
            ),
          if (_isEditing)
            TextButton(
              onPressed: _saveProfile,
              child: Text(
                'Guardar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading ? _buildLoadingState() : _buildProfile(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.oasisGreen),
          ),
          const SizedBox(height: 16),
          Text(
            'Cargando perfil...',
            style: TextStyle(
              color: ModernTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Profile header
                _buildProfileHeader(),

                // Stats overview
                _buildStatsOverview(),

                // Personal information
                _buildPersonalInfoSection(),

                // Vehicle information
                _buildVehicleInfoSection(),

                // Achievements
                _buildAchievementsSection(),

                // Preferences
                _buildPreferencesSection(),

                // Work schedule
                _buildWorkScheduleSection(),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader() {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - _slideAnimation.value)),
          child: Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: ModernTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: ModernTheme.oasisGreen.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _profile!.profileImageUrl.isEmpty
                            ? LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.3),
                                  Colors.white.withValues(alpha: 0.1)
                                ],
                              )
                            : null,
                        image: _profile!.profileImageUrl.isNotEmpty
                            ? DecorationImage(
                                image: _profile!.profileImageUrl
                                        .startsWith('http')
                                    ? NetworkImage(_profile!.profileImageUrl)
                                        as ImageProvider
                                    : FileImage(
                                        File(_profile!.profileImageUrl)),
                                fit: BoxFit.cover,
                              )
                            : null,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: _profile!.profileImageUrl.isEmpty
                          ? Icon(
                              Icons.person,
                              size: 50,
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
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: ModernTheme.oasisGreen, width: 2),
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            color: ModernTheme.oasisGreen,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _profile!.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          Icons.star,
                          size: 16,
                          color: index < _profile!.rating.floor()
                              ? Colors.amber
                              : Colors.white.withValues(alpha: 0.3),
                        );
                      }),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_profile!.rating} (${_profile!.totalTrips} viajes)',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Miembro desde ${_formatMemberSince(_profile!.memberSince)}',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsOverview() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Viajes',
              '${_profile!.totalTrips}',
              Icons.directions_car,
              ModernTheme.primaryBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Kilómetros',
              '${(_profile!.totalDistance / 1000).toStringAsFixed(1)}K',
              Icons.straighten,
              ModernTheme.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Ganancias',
              'S/ ${(_profile!.totalEarnings / 1000).toStringAsFixed(1)}K',
              Icons.attach_money,
              ModernTheme.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: ModernTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return _buildSection(
      'Información Personal',
      Icons.person,
      ModernTheme.primaryBlue,
      [
        if (_isEditing) ...[
          Form(
            key: _formKey,
            child: Column(
              children: [
                _buildTextFormField(
                  controller: _nameController,
                  label: 'Nombre completo',
                  icon: Icons.person,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa tu nombre completo';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextFormField(
                  controller: _phoneController,
                  label: 'Teléfono',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa tu teléfono';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextFormField(
                  controller: _emailController,
                  label: 'Correo electrónico',
                  icon: Icons.email,
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
                const SizedBox(height: 16),
                _buildTextFormField(
                  controller: _bioController,
                  label: 'Descripción personal',
                  icon: Icons.description,
                  maxLines: 3,
                  validator: (value) {
                    if (value != null && value.length > 200) {
                      return 'Máximo 200 caracteres';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ] else ...[
          _buildInfoRow('Nombre', _profile!.name, Icons.person),
          _buildInfoRow('Teléfono', _profile!.phone, Icons.phone),
          _buildInfoRow('Email', _profile!.email, Icons.email),
          if (_profile!.bio.isNotEmpty)
            _buildInfoRow('Bio', _profile!.bio, Icons.description),
        ],

        const SizedBox(height: 20),

        // Emergency contact
        Text(
          'Contacto de Emergencia',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: ModernTheme.error,
          ),
        ),
        const SizedBox(height: 12),

        if (_isEditing) ...[
          _buildTextFormField(
            controller: _emergencyContactController,
            label: 'Nombre del contacto',
            icon: Icons.emergency,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa el nombre del contacto';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
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
        ] else ...[
          _buildInfoRow(
              'Nombre', _profile!.emergencyContact.name, Icons.emergency),
          _buildInfoRow('Teléfono', _profile!.emergencyContact.phone,
              Icons.phone_in_talk),
          _buildInfoRow('Relación', _profile!.emergencyContact.relationship,
              Icons.family_restroom),
        ],
      ],
    );
  }

  Widget _buildVehicleInfoSection() {
    return _buildSection(
      'Información del Vehículo',
      Icons.directions_car,
      ModernTheme.oasisGreen,
      [
        _buildInfoRow(
            'Marca', _profile!.vehicleInfo.make, Icons.directions_car),
        _buildInfoRow('Modelo', _profile!.vehicleInfo.model, Icons.drive_eta),
        _buildInfoRow(
            'Año', '${_profile!.vehicleInfo.year}', Icons.calendar_today),
        _buildInfoRow('Color', _profile!.vehicleInfo.color, Icons.palette),
        _buildInfoRow(
            'Placa', _profile!.vehicleInfo.plate, Icons.confirmation_number),
        _buildInfoRow('Capacidad',
            '${_profile!.vehicleInfo.capacity} pasajeros', Icons.people),
      ],
    );
  }

  Widget _buildAchievementsSection() {
    return _buildSection(
      'Logros y Reconocimientos',
      Icons.emoji_events,
      Colors.amber,
      [
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: _profile!.achievements.length,
          itemBuilder: (context, index) {
            final achievement = _profile!.achievements[index];
            return _buildAchievementCard(achievement);
          },
        ),
      ],
    );
  }

  Widget _buildAchievementCard(Achievement achievement) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events,
              color: Colors.amber,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            achievement.name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            achievement.description,
            style: TextStyle(
              fontSize: 10,
              color: ModernTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return _buildSection(
      'Preferencias de Trabajo',
      Icons.settings,
      Colors.purple,
      [
        _buildPreferenceRow(
            'Acepta mascotas', _profile!.preferences.acceptPets),
        _buildPreferenceRow(
            'Permite fumar', _profile!.preferences.acceptSmoking),
        _buildInfoRow('Música preferida', _profile!.preferences.musicPreference,
            Icons.music_note),
        _buildInfoRow('Idiomas', _profile!.preferences.languages.join(', '),
            Icons.language),
        _buildInfoRow('Distancia máxima',
            '${_profile!.preferences.maxTripDistance} km', Icons.straighten),
        const SizedBox(height: 12),
        Text(
          'Zonas preferidas:',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: ModernTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _profile!.preferences.preferredZones.map((zone) {
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                zone,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.purple,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildWorkScheduleSection() {
    return _buildSection(
      'Horario de Trabajo',
      Icons.schedule,
      Colors.orange,
      [
        _buildScheduleRow('Lunes', _profile!.workSchedule.mondayStart,
            _profile!.workSchedule.mondayEnd),
        _buildScheduleRow('Martes', _profile!.workSchedule.tuesdayStart,
            _profile!.workSchedule.tuesdayEnd),
        _buildScheduleRow('Miércoles', _profile!.workSchedule.wednesdayStart,
            _profile!.workSchedule.wednesdayEnd),
        _buildScheduleRow('Jueves', _profile!.workSchedule.thursdayStart,
            _profile!.workSchedule.thursdayEnd),
        _buildScheduleRow('Viernes', _profile!.workSchedule.fridayStart,
            _profile!.workSchedule.fridayEnd),
        _buildScheduleRow('Sábado', _profile!.workSchedule.saturdayStart,
            _profile!.workSchedule.saturdayEnd),
        _buildScheduleRow('Domingo', _profile!.workSchedule.sundayStart,
            _profile!.workSchedule.sundayEnd),
      ],
    );
  }

  Widget _buildScheduleRow(String day, String startTime, String endTime) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day,
            style: TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '$startTime - $endTime',
            style: TextStyle(
              color: ModernTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceRow(String label, bool value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            color: value ? ModernTheme.success : ModernTheme.error,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: ModernTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: ModernTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: ModernTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    // Determinar el tipo de campo basado en el label
    String fieldType = 'text';
    if (label.toLowerCase().contains('nombre')) {
      fieldType = 'fullname';
    } else if (label.toLowerCase().contains('teléfono') ||
        label.toLowerCase().contains('phone')) {
      fieldType = 'phone';
    } else if (label.toLowerCase().contains('correo') ||
        label.toLowerCase().contains('email')) {
      fieldType = 'email';
    } else if (label.toLowerCase().contains('descripción')) {
      fieldType = 'text';
    } else if (label.toLowerCase().contains('contacto')) {
      fieldType = 'name';
    }

    return SecurityIntegrationService.buildSecureTextField(
      context: context,
      controller: controller,
      label: label,
      fieldType: fieldType,
      prefixIcon: Icon(icon),
      keyboardType: keyboardType,
      maxLength: maxLines > 1 ? 500 : null,
    );
  }

  String _formatMemberSince(DateTime date) {
    final months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.oasisGreen),
          ),
        ),
      );

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Actualizar datos en Firebase
          await FirebaseFirestore.instance
              .collection('drivers')
              .doc(user.uid)
              .update({
            'name': _nameController.text,
            'email': _emailController.text,
            'phone': _phoneController.text,
            'bio': _bioController.text,
            'emergencyContactName': _emergencyContactController.text,
            'emergencyContactPhone': _emergencyPhoneController.text,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Actualizar el estado local
          setState(() {
            _profile = DriverProfile(
              id: _profile!.id,
              name: _nameController.text,
              email: _emailController.text,
              phone: _phoneController.text,
              profileImageUrl: _profile!.profileImageUrl,
              rating: _profile!.rating,
              totalTrips: _profile!.totalTrips,
              totalDistance: _profile!.totalDistance,
              totalHours: _profile!.totalHours,
              totalEarnings: _profile!.totalEarnings,
              memberSince: _profile!.memberSince,
              bio: _bioController.text,
              emergencyContact: EmergencyContact(
                name: _emergencyContactController.text,
                phone: _emergencyPhoneController.text,
                relationship: _profile!.emergencyContact.relationship,
              ),
              preferences: _profile!.preferences,
              achievements: _profile!.achievements,
              vehicleInfo: _profile!.vehicleInfo,
              workSchedule: _profile!.workSchedule,
            );
            _isEditing = false;
          });

          if (!mounted) return;
          Navigator.pop(context); // Cerrar el diálogo de carga

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Perfil actualizado exitosamente'),
              backgroundColor: ModernTheme.success,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Cerrar el diálogo de carga
        AppLogger.error('guardando perfil', e);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar el perfil'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  void _changeProfileImage() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
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
            const SizedBox(height: 20),
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
                        padding: EdgeInsets.all(16),
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
                      const SizedBox(height: 8),
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
                        padding: EdgeInsets.all(16),
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
                      const SizedBox(height: 8),
                      Text('Galería'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _pickImageFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        await _uploadImage(File(image.path));
      }
    } catch (e) {
      AppLogger.error('tomando foto', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al tomar la foto'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  void _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        await _uploadImage(File(image.path));
      }
    } catch (e) {
      AppLogger.error('seleccionando imagen', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar la imagen'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.oasisGreen),
        ),
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Subir imagen a Firebase Storage
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('drivers')
            .child(user.uid)
            .child('profile_${DateTime.now().millisecondsSinceEpoch}.jpg');

        final uploadTask = await storageRef.putFile(imageFile);
        final imageUrl = await uploadTask.ref.getDownloadURL();

        // Actualizar URL en Firestore
        await FirebaseFirestore.instance
            .collection('drivers')
            .doc(user.uid)
            .update({
          'profileImageUrl': imageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Actualizar estado local
        setState(() {
          _profile = DriverProfile(
            id: _profile!.id,
            name: _profile!.name,
            email: _profile!.email,
            phone: _profile!.phone,
            profileImageUrl: imageUrl,
            rating: _profile!.rating,
            totalTrips: _profile!.totalTrips,
            totalDistance: _profile!.totalDistance,
            totalHours: _profile!.totalHours,
            totalEarnings: _profile!.totalEarnings,
            memberSince: _profile!.memberSince,
            bio: _profile!.bio,
            emergencyContact: _profile!.emergencyContact,
            preferences: _profile!.preferences,
            achievements: _profile!.achievements,
            vehicleInfo: _profile!.vehicleInfo,
            workSchedule: _profile!.workSchedule,
          );
        });

        if (!mounted) return;
        Navigator.pop(context); // Cerrar diálogo de carga

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Foto de perfil actualizada'),
            backgroundColor: ModernTheme.success,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Cerrar diálogo de carga
      AppLogger.error('subiendo imagen', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al subir la imagen'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }
}

// Models
class DriverProfile {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String profileImageUrl;
  final double rating;
  final int totalTrips;
  final double totalDistance;
  final double totalHours;
  final double totalEarnings;
  final DateTime memberSince;
  final String bio;
  final EmergencyContact emergencyContact;
  final DriverPreferences preferences;
  final List<Achievement> achievements;
  final VehicleInfo vehicleInfo;
  final WorkSchedule workSchedule;

  DriverProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.profileImageUrl,
    required this.rating,
    required this.totalTrips,
    required this.totalDistance,
    required this.totalHours,
    required this.totalEarnings,
    required this.memberSince,
    required this.bio,
    required this.emergencyContact,
    required this.preferences,
    required this.achievements,
    required this.vehicleInfo,
    required this.workSchedule,
  });
}

class EmergencyContact {
  final String name;
  final String phone;
  final String relationship;

  EmergencyContact({
    required this.name,
    required this.phone,
    required this.relationship,
  });
}

class DriverPreferences {
  final bool acceptPets;
  final bool acceptSmoking;
  final String musicPreference;
  final List<String> languages;
  final double maxTripDistance;
  final List<String> preferredZones;

  DriverPreferences({
    required this.acceptPets,
    required this.acceptSmoking,
    required this.musicPreference,
    required this.languages,
    required this.maxTripDistance,
    required this.preferredZones,
  });
}

class Achievement {
  final String id;
  final String name;
  final String description;
  final String iconUrl;
  final DateTime unlockedDate;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.unlockedDate,
  });
}

class VehicleInfo {
  final String brand;
  final String make;
  final String model;
  final int year;
  final String color;
  final String plateNumber;
  final String plate;
  final int capacity;
  final String vehicleType;

  VehicleInfo({
    String? brand,
    String? make,
    required this.model,
    required this.year,
    required this.color,
    String? plateNumber,
    String? plate,
    required this.capacity,
    String? vehicleType,
  })  : brand = brand ?? make ?? '',
        make = make ?? brand ?? '',
        plateNumber = plateNumber ?? plate ?? '',
        plate = plate ?? plateNumber ?? '',
        vehicleType = vehicleType ?? 'sedan';
}

class WorkSchedule {
  final String mondayStart;
  final String mondayEnd;
  final String tuesdayStart;
  final String tuesdayEnd;
  final String wednesdayStart;
  final String wednesdayEnd;
  final String thursdayStart;
  final String thursdayEnd;
  final String fridayStart;
  final String fridayEnd;
  final String saturdayStart;
  final String saturdayEnd;
  final String sundayStart;
  final String sundayEnd;

  WorkSchedule({
    required this.mondayStart,
    required this.mondayEnd,
    required this.tuesdayStart,
    required this.tuesdayEnd,
    required this.wednesdayStart,
    required this.wednesdayEnd,
    required this.thursdayStart,
    required this.thursdayEnd,
    required this.fridayStart,
    required this.fridayEnd,
    required this.saturdayStart,
    required this.saturdayEnd,
    required this.sundayStart,
    required this.sundayEnd,
  });
}
