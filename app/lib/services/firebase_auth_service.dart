import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

/// Servicio completo de Firebase Auth para OasisTaxi
/// Gestiona toda la autenticación y autorización de usuarios
class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Estado del servicio
  bool _isInitialized = false;
  User? _currentUser;
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic> _authConfig = {};

  // Tokens y sesión
  String? _customToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;
  Timer? _tokenRefreshTimer;
  Timer? _sessionTimer;

  // Control de sesión
  static const Duration _sessionTimeout = Duration(hours: 12);
  static const Duration _tokenRefreshInterval = Duration(minutes: 55);
  DateTime? _lastActivity;

  // Intentos de login y seguridad
  final Map<String, LoginAttempts> _loginAttempts = {};
  static const int _maxLoginAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 30);

  // MFA y verificación
  String? _pendingMfaVerificationId;
  PhoneAuthCredential? _pendingPhoneCredential;

  // Listeners y streams
  StreamSubscription<User?>? _authStateSubscription;
  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();

  // Biometría
  bool _biometricEnabled = false;

  /// Stream de estado de autenticación
  Stream<AuthState> get authStateStream => _authStateController.stream;

  /// Usuario actual
  User? get currentUser => _currentUser;

  /// Perfil de usuario actual
  Map<String, dynamic>? get userProfile => _userProfile;

  /// Verifica si el usuario está autenticado
  bool get isAuthenticated => _currentUser != null;

  /// Verifica si es conductor
  bool get isDriver => _userProfile?['userType'] == 'driver';

  /// Verifica si es pasajero
  bool get isPassenger => _userProfile?['userType'] == 'passenger';

  /// Verifica si es admin
  bool get isAdmin => _userProfile?['userType'] == 'admin';

  /// Inicializa el servicio de autenticación
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      AppLogger.info('🔐 Inicializando Firebase Auth Service para OasisTaxi');

      // Cargar configuración
      await _loadAuthConfig();

      // Configurar listeners
      _setupAuthStateListener();

      // Verificar sesión existente
      await _checkExistingSession();

      // Configurar refresh de tokens
      _setupTokenRefresh();

      // Configurar monitoreo de sesión
      _setupSessionMonitoring();

      // Verificar biometría disponible
      await _checkBiometricAvailability();

      _isInitialized = true;
      AppLogger.info('✅ Firebase Auth Service inicializado correctamente');
    } catch (e, stackTrace) {
      AppLogger.error(
          '❌ Error al inicializar Firebase Auth Service', e, stackTrace);
      rethrow;
    }
  }

  /// Carga la configuración de autenticación
  Future<void> _loadAuthConfig() async {
    try {
      final doc =
          await _firestore.collection('configuration').doc('auth_config').get();

      if (doc.exists) {
        _authConfig = doc.data() ?? {};
      } else {
        _authConfig = _getDefaultAuthConfig();
        await _saveAuthConfig();
      }

      AppLogger.info('📋 Configuración de auth cargada');
    } catch (e) {
      AppLogger.error('Error al cargar configuración de auth', e);
      _authConfig = _getDefaultAuthConfig();
    }
  }

  /// Obtiene configuración por defecto
  Map<String, dynamic> _getDefaultAuthConfig() {
    return {
      'enablePhoneAuth': true,
      'enableGoogleAuth': true,
      'enableEmailAuth': true,
      'enableBiometric': true,
      'requireEmailVerification': true,
      'requirePhoneVerification': true,
      'enableMfa': true,
      'mfaRequiredForAdmin': true,
      'sessionTimeoutHours': 12,
      'maxLoginAttempts': 5,
      'lockoutDurationMinutes': 30,
      'passwordMinLength': 8,
      'passwordRequireUppercase': true,
      'passwordRequireLowercase': true,
      'passwordRequireNumbers': true,
      'passwordRequireSpecialChars': true,
      'enableAnonymousAuth': false,
      'allowMultipleSessions': false,
      'region': 'peru',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Guarda configuración de auth
  Future<void> _saveAuthConfig() async {
    try {
      await _firestore
          .collection('configuration')
          .doc('auth_config')
          .set(_authConfig, SetOptions(merge: true));
    } catch (e) {
      AppLogger.error('Error al guardar configuración de auth', e);
    }
  }

  /// Configura listener de estado de autenticación
  void _setupAuthStateListener() {
    _authStateSubscription?.cancel();
    _authStateSubscription =
        _auth.authStateChanges().listen((User? user) async {
      _currentUser = user;

      if (user != null) {
        // Usuario autenticado
        await _loadUserProfile(user.uid);
        _authStateController.add(AuthState.authenticated);
        _updateLastActivity();

        // Log de evento
        await _logAuthEvent('auth_state_change', {
          'userId': user.uid,
          'state': 'authenticated',
        });
      } else {
        // Usuario no autenticado
        _userProfile = null;
        _authStateController.add(AuthState.unauthenticated);
      }
    });
  }

  /// Carga el perfil del usuario
  Future<void> _loadUserProfile(String userId) async {
    try {
      // Intentar cargar de diferentes colecciones según el tipo
      final collections = ['users', 'drivers', 'admins'];

      for (final collection in collections) {
        final doc = await _firestore.collection(collection).doc(userId).get();

        if (doc.exists) {
          _userProfile = doc.data();
          _userProfile!['collection'] = collection;

          // Determinar tipo de usuario
          if (collection == 'drivers') {
            _userProfile!['userType'] = 'driver';
          } else if (collection == 'admins') {
            _userProfile!['userType'] = 'admin';
          } else {
            _userProfile!['userType'] = 'passenger';
          }

          AppLogger.info('✅ Perfil cargado: ${_userProfile!['userType']}');
          break;
        }
      }
    } catch (e) {
      AppLogger.error('Error al cargar perfil de usuario', e);
    }
  }

  /// Verifica sesión existente
  Future<void> _checkExistingSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionToken = prefs.getString('session_token');
      final sessionExpiry = prefs.getString('session_expiry');

      if (sessionToken != null && sessionExpiry != null) {
        final expiry = DateTime.parse(sessionExpiry);

        if (expiry.isAfter(DateTime.now())) {
          // Sesión válida
          _currentUser = _auth.currentUser;

          if (_currentUser != null) {
            await _loadUserProfile(_currentUser!.uid);
            _authStateController.add(AuthState.authenticated);
            AppLogger.info('✅ Sesión existente restaurada');
          }
        } else {
          // Sesión expirada
          await _clearSession();
          AppLogger.info('⏰ Sesión expirada, requiere nuevo login');
        }
      }
    } catch (e) {
      AppLogger.error('Error al verificar sesión existente', e);
    }
  }

  /// Configura refresh automático de tokens
  void _setupTokenRefresh() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = Timer.periodic(_tokenRefreshInterval, (_) async {
      if (_currentUser != null) {
        await _refreshAuthToken();
      }
    });
  }

  /// Refresca el token de autenticación
  Future<void> _refreshAuthToken() async {
    try {
      if (_currentUser != null) {
        final idToken = await _currentUser!.getIdToken(true);
        _customToken = idToken;
        _tokenExpiry = DateTime.now().add(const Duration(hours: 1));

        AppLogger.info('🔄 Token de autenticación refrescado');
      }
    } catch (e) {
      AppLogger.error('Error al refrescar token', e);
    }
  }

  /// Configura monitoreo de sesión
  void _setupSessionMonitoring() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkSessionTimeout();
    });
  }

  /// Verifica timeout de sesión
  void _checkSessionTimeout() {
    if (_lastActivity != null && _currentUser != null) {
      final timeSinceLastActivity = DateTime.now().difference(_lastActivity!);

      if (timeSinceLastActivity > _sessionTimeout) {
        AppLogger.warning('⏰ Sesión expirada por inactividad');
        signOut();
      }
    }
  }

  /// Actualiza última actividad
  void _updateLastActivity() {
    _lastActivity = DateTime.now();
  }

  /// Verifica disponibilidad de biometría
  Future<void> _checkBiometricAvailability() async {
    try {
      _biometricEnabled = await _localAuth.canCheckBiometrics;

      if (_biometricEnabled) {
        final availableBiometrics = await _localAuth.getAvailableBiometrics();
        AppLogger.info(
            '🔒 Biometría disponible: ${availableBiometrics.map((b) => b.toString()).join(", ")}');
      }
    } catch (e) {
      AppLogger.error('Error al verificar biometría', e);
      _biometricEnabled = false;
    }
  }

  /// Registro con email y contraseña
  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String userType,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      AppLogger.info('📝 Iniciando registro con email: $email');

      // Validar contraseña
      final passwordValidation = _validatePassword(password);
      if (!passwordValidation.isValid) {
        return AuthResult(
          success: false,
          error: passwordValidation.errors.join(', '),
        );
      }

      // Crear usuario en Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        throw Exception('No se pudo crear el usuario');
      }

      final user = credential.user!;

      // Enviar verificación de email
      await user.sendEmailVerification();

      // Crear perfil en Firestore
      final collection = userType == 'driver'
          ? 'drivers'
          : userType == 'admin'
              ? 'admins'
              : 'users';

      final profileData = {
        'uid': user.uid,
        'email': email,
        'fullName': fullName,
        'phone': phone,
        'userType': userType,
        'emailVerified': false,
        'phoneVerified': false,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'profileComplete': false,
        'rating': userType == 'driver' ? 5.0 : null,
        'totalTrips': 0,
        'walletBalance': 0.0,
        ...?additionalData,
      };

      await _firestore.collection(collection).doc(user.uid).set(profileData);

      // Log de evento
      await _logAuthEvent('user_registered', {
        'userId': user.uid,
        'userType': userType,
        'method': 'email',
      });

      AppLogger.info('✅ Usuario registrado exitosamente');

      return AuthResult(
        success: true,
        user: user,
        userType: userType,
        message: 'Registro exitoso. Verifica tu email.',
      );
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Error de Firebase Auth', e);
      return AuthResult(
        success: false,
        error: _getAuthErrorMessage(e.code),
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error en registro', e, stackTrace);
      return AuthResult(
        success: false,
        error: 'Error al registrar usuario',
      );
    }
  }

  /// Login con email y contraseña
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      AppLogger.info('🔑 Iniciando login con email: $email');

      // Verificar intentos de login
      if (_isAccountLocked(email)) {
        return AuthResult(
          success: false,
          error: 'Cuenta bloqueada temporalmente. Intenta más tarde.',
        );
      }

      // Intentar login
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        _recordFailedLogin(email);
        throw Exception('Credenciales inválidas');
      }

      final user = credential.user!;

      // Cargar perfil
      await _loadUserProfile(user.uid);

      // Verificar si la cuenta está activa
      if (_userProfile?['isActive'] == false) {
        await _auth.signOut();
        return AuthResult(
          success: false,
          error: 'Tu cuenta ha sido desactivada. Contacta soporte.',
        );
      }

      // Verificar email si es requerido
      if (_authConfig['requireEmailVerification'] == true &&
          !user.emailVerified) {
        await _auth.signOut();
        return AuthResult(
          success: false,
          error: 'Debes verificar tu email antes de iniciar sesión.',
        );
      }

      // Verificar MFA si es requerido
      if (_shouldRequireMfa()) {
        return AuthResult(
          success: false,
          requiresMfa: true,
          user: user,
          message: 'Se requiere verificación adicional',
        );
      }

      // Login exitoso
      await _onSuccessfulLogin(user);

      return AuthResult(
        success: true,
        user: user,
        userType: _userProfile?['userType'],
        message: 'Login exitoso',
      );
    } on FirebaseAuthException catch (e) {
      _recordFailedLogin(email);
      AppLogger.error('Error de Firebase Auth', e);
      return AuthResult(
        success: false,
        error: _getAuthErrorMessage(e.code),
      );
    } catch (e) {
      _recordFailedLogin(email);
      AppLogger.error('Error en login', e);
      return AuthResult(
        success: false,
        error: 'Error al iniciar sesión',
      );
    }
  }

  /// Login con Google
  Future<AuthResult> signInWithGoogle() async {
    try {
      AppLogger.info('🔑 Iniciando login con Google');

      // Iniciar sesión con Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return AuthResult(
          success: false,
          error: 'Login cancelado',
        );
      }

      // Obtener credenciales
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in con Firebase
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;

      // Verificar si es nuevo usuario
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      if (isNewUser) {
        // Crear perfil para nuevo usuario
        await _createGoogleUserProfile(user, googleUser);
      } else {
        // Cargar perfil existente
        await _loadUserProfile(user.uid);
      }

      // Login exitoso
      await _onSuccessfulLogin(user);

      return AuthResult(
        success: true,
        user: user,
        userType: _userProfile?['userType'] ?? 'passenger',
        isNewUser: isNewUser,
        message: isNewUser ? 'Bienvenido a OasisTaxi' : 'Bienvenido de vuelta',
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error en login con Google', e, stackTrace);
      return AuthResult(
        success: false,
        error: 'Error al iniciar sesión con Google',
      );
    }
  }

  /// Crea perfil para usuario de Google
  Future<void> _createGoogleUserProfile(
      User user, GoogleSignInAccount googleUser) async {
    try {
      final profileData = {
        'uid': user.uid,
        'email': user.email,
        'fullName': user.displayName ?? googleUser.displayName,
        'photoUrl': user.photoURL ?? googleUser.photoUrl,
        'userType': 'passenger', // Por defecto pasajero
        'emailVerified': true, // Google ya verifica el email
        'phoneVerified': false,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'profileComplete': false,
        'loginMethod': 'google',
        'totalTrips': 0,
        'walletBalance': 0.0,
      };

      await _firestore.collection('users').doc(user.uid).set(profileData);

      _userProfile = profileData;

      AppLogger.info('✅ Perfil de Google creado');
    } catch (e) {
      AppLogger.error('Error al crear perfil de Google', e);
    }
  }

  /// Login con número de teléfono
  Future<AuthResult> signInWithPhone({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onAutoVerify,
  }) async {
    try {
      AppLogger.info('📱 Iniciando login con teléfono: $phoneNumber');

      final Completer<AuthResult> completer = Completer<AuthResult>();

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verificación (Android)
          AppLogger.info('✅ Auto-verificación completada');
          onAutoVerify(credential.smsCode ?? '');

          final result = await _signInWithPhoneCredential(credential);
          if (!completer.isCompleted) {
            completer.complete(result);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          AppLogger.error('Error en verificación de teléfono', e);
          if (!completer.isCompleted) {
            completer.complete(AuthResult(
              success: false,
              error: _getAuthErrorMessage(e.code),
            ));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          AppLogger.info('📨 Código SMS enviado');
          _pendingMfaVerificationId = verificationId;
          onCodeSent(verificationId);

          if (!completer.isCompleted) {
            completer.complete(AuthResult(
              success: false,
              requiresSmsVerification: true,
              verificationId: verificationId,
              message: 'Código SMS enviado',
            ));
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          AppLogger.info('⏰ Timeout de auto-verificación');
          _pendingMfaVerificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );

      return await completer.future;
    } catch (e, stackTrace) {
      AppLogger.error('Error en login con teléfono', e, stackTrace);
      return AuthResult(
        success: false,
        error: 'Error al verificar número de teléfono',
      );
    }
  }

  /// Verifica código SMS
  Future<AuthResult> verifySmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      AppLogger.info('🔢 Verificando código SMS');

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      return await _signInWithPhoneCredential(credential);
    } catch (e) {
      AppLogger.error('Error al verificar código SMS', e);
      return AuthResult(
        success: false,
        error: 'Código inválido o expirado',
      );
    }
  }

  /// Sign in con credencial de teléfono
  Future<AuthResult> _signInWithPhoneCredential(
      PhoneAuthCredential credential) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;

      // Verificar si es nuevo usuario
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      if (isNewUser) {
        // Crear perfil básico
        await _createPhoneUserProfile(user);
      } else {
        // Cargar perfil existente
        await _loadUserProfile(user.uid);
      }

      // Login exitoso
      await _onSuccessfulLogin(user);

      return AuthResult(
        success: true,
        user: user,
        userType: _userProfile?['userType'] ?? 'passenger',
        isNewUser: isNewUser,
        message: 'Login exitoso',
      );
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Error de Firebase Auth', e);
      return AuthResult(
        success: false,
        error: _getAuthErrorMessage(e.code),
      );
    }
  }

  /// Crea perfil para usuario de teléfono
  Future<void> _createPhoneUserProfile(User user) async {
    try {
      final profileData = {
        'uid': user.uid,
        'phone': user.phoneNumber,
        'userType': 'passenger',
        'phoneVerified': true,
        'emailVerified': false,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'profileComplete': false,
        'loginMethod': 'phone',
        'totalTrips': 0,
        'walletBalance': 0.0,
      };

      await _firestore.collection('users').doc(user.uid).set(profileData);

      _userProfile = profileData;

      AppLogger.info('✅ Perfil de teléfono creado');
    } catch (e) {
      AppLogger.error('Error al crear perfil de teléfono', e);
    }
  }

  /// Login con biometría
  Future<AuthResult> signInWithBiometric() async {
    try {
      if (!_biometricEnabled) {
        return AuthResult(
          success: false,
          error: 'Biometría no disponible en este dispositivo',
        );
      }

      AppLogger.info('🔒 Iniciando login con biometría');

      // Autenticar con biometría
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Usa tu huella o rostro para iniciar sesión',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!authenticated) {
        return AuthResult(
          success: false,
          error: 'Autenticación biométrica fallida',
        );
      }

      // Obtener token guardado
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('biometric_token');
      final savedUserId = prefs.getString('biometric_user_id');

      if (savedToken == null || savedUserId == null) {
        return AuthResult(
          success: false,
          error: 'No hay sesión biométrica guardada',
        );
      }

      // Verificar token personalizado
      await _auth.signInWithCustomToken(savedToken);

      // Cargar perfil
      await _loadUserProfile(savedUserId);

      // Login exitoso
      await _onSuccessfulLogin(_auth.currentUser!);

      return AuthResult(
        success: true,
        user: _auth.currentUser,
        userType: _userProfile?['userType'],
        message: 'Login biométrico exitoso',
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error en login biométrico', e, stackTrace);
      return AuthResult(
        success: false,
        error: 'Error en autenticación biométrica',
      );
    }
  }

  /// Habilita autenticación biométrica
  Future<bool> enableBiometric() async {
    try {
      if (!_biometricEnabled || _currentUser == null) {
        return false;
      }

      // Autenticar primero
      final authenticated = await _localAuth.authenticate(
        localizedReason:
            'Configura tu huella o rostro para futuros inicios de sesión',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!authenticated) {
        return false;
      }

      // Generar y guardar token personalizado
      final token = await _generateCustomToken(_currentUser!.uid);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('biometric_token', token);
      await prefs.setString('biometric_user_id', _currentUser!.uid);
      await prefs.setBool('biometric_enabled', true);

      // Actualizar perfil
      await _firestore
          .collection(_userProfile!['collection'])
          .doc(_currentUser!.uid)
          .update({
        'biometricEnabled': true,
        'biometricEnabledAt': FieldValue.serverTimestamp(),
      });

      AppLogger.info('✅ Biometría habilitada');
      return true;
    } catch (e) {
      AppLogger.error('Error al habilitar biometría', e);
      return false;
    }
  }

  /// Genera token personalizado
  Future<String> _generateCustomToken(String userId) async {
    // En producción, esto debería hacerse en el backend
    // Por ahora, simulamos un token
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random.secure();
    final nonce = List.generate(32, (_) => random.nextInt(256));

    final payload = {
      'uid': userId,
      'timestamp': timestamp,
      'nonce': base64Encode(nonce),
    };

    final token = base64Encode(utf8.encode(jsonEncode(payload)));
    return token;
  }

  /// Envía código de verificación MFA
  Future<AuthResult> sendMfaCode({String? phoneNumber}) async {
    try {
      final phone = phoneNumber ?? _userProfile?['phone'];

      if (phone == null) {
        return AuthResult(
          success: false,
          error: 'Número de teléfono no configurado',
        );
      }

      AppLogger.info('📱 Enviando código MFA a $phone');

      final completer = Completer<AuthResult>();

      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (credential) {
          _pendingPhoneCredential = credential;
        },
        verificationFailed: (e) {
          if (!completer.isCompleted) {
            completer.complete(AuthResult(
              success: false,
              error: _getAuthErrorMessage(e.code),
            ));
          }
        },
        codeSent: (verificationId, resendToken) {
          _pendingMfaVerificationId = verificationId;
          if (!completer.isCompleted) {
            completer.complete(AuthResult(
              success: true,
              verificationId: verificationId,
              message: 'Código MFA enviado',
            ));
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _pendingMfaVerificationId = verificationId;
        },
      );

      return await completer.future;
    } catch (e) {
      AppLogger.error('Error al enviar código MFA', e);
      return AuthResult(
        success: false,
        error: 'Error al enviar código de verificación',
      );
    }
  }

  /// Verifica código MFA
  Future<AuthResult> verifyMfaCode(String code) async {
    try {
      if (_pendingMfaVerificationId == null) {
        return AuthResult(
          success: false,
          error: 'No hay verificación MFA pendiente',
        );
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _pendingMfaVerificationId!,
        smsCode: code,
      );

      // Vincular credencial si ya hay usuario
      if (_currentUser != null) {
        await _currentUser!.linkWithCredential(credential);

        await _onSuccessfulLogin(_currentUser!);

        return AuthResult(
          success: true,
          user: _currentUser,
          message: 'MFA verificado exitosamente',
        );
      }

      return AuthResult(
        success: false,
        error: 'No hay sesión activa',
      );
    } catch (e) {
      AppLogger.error('Error al verificar MFA', e);
      return AuthResult(
        success: false,
        error: 'Código MFA inválido',
      );
    }
  }

  /// Resetea contraseña
  Future<AuthResult> resetPassword(String email) async {
    try {
      AppLogger.info('🔑 Enviando email de reset a $email');

      await _auth.sendPasswordResetEmail(email: email);

      // Log evento
      await _logAuthEvent('password_reset_requested', {
        'email': email,
      });

      return AuthResult(
        success: true,
        message: 'Email de recuperación enviado',
      );
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Error al resetear contraseña', e);
      return AuthResult(
        success: false,
        error: _getAuthErrorMessage(e.code),
      );
    }
  }

  /// Cambia contraseña
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      if (_currentUser == null || _currentUser!.email == null) {
        return AuthResult(
          success: false,
          error: 'No hay sesión activa',
        );
      }

      // Validar nueva contraseña
      final validation = _validatePassword(newPassword);
      if (!validation.isValid) {
        return AuthResult(
          success: false,
          error: validation.errors.join(', '),
        );
      }

      // Re-autenticar
      final credential = EmailAuthProvider.credential(
        email: _currentUser!.email!,
        password: currentPassword,
      );

      await _currentUser!.reauthenticateWithCredential(credential);

      // Cambiar contraseña
      await _currentUser!.updatePassword(newPassword);

      // Log evento
      await _logAuthEvent('password_changed', {
        'userId': _currentUser!.uid,
      });

      return AuthResult(
        success: true,
        message: 'Contraseña actualizada exitosamente',
      );
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Error al cambiar contraseña', e);
      return AuthResult(
        success: false,
        error: _getAuthErrorMessage(e.code),
      );
    }
  }

  /// Actualiza perfil de usuario
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      if (_currentUser == null || _userProfile == null) {
        return false;
      }

      final collection = _userProfile!['collection'] ?? 'users';

      // Agregar timestamp
      data['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(collection)
          .doc(_currentUser!.uid)
          .update(data);

      // Actualizar cache local
      _userProfile!.addAll(data);

      AppLogger.info('✅ Perfil actualizado');
      return true;
    } catch (e) {
      AppLogger.error('Error al actualizar perfil', e);
      return false;
    }
  }

  /// Elimina cuenta de usuario
  Future<AuthResult> deleteAccount({String? password}) async {
    try {
      if (_currentUser == null) {
        return AuthResult(
          success: false,
          error: 'No hay sesión activa',
        );
      }

      // Re-autenticar si es necesario
      if (_currentUser!.email != null && password != null) {
        final credential = EmailAuthProvider.credential(
          email: _currentUser!.email!,
          password: password,
        );

        await _currentUser!.reauthenticateWithCredential(credential);
      }

      // Marcar perfil como eliminado (soft delete)
      final collection = _userProfile!['collection'] ?? 'users';
      await _firestore.collection(collection).doc(_currentUser!.uid).update({
        'isActive': false,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletionReason': 'user_requested',
      });

      // Log evento
      await _logAuthEvent('account_deleted', {
        'userId': _currentUser!.uid,
        'userType': _userProfile?['userType'],
      });

      // Eliminar de Firebase Auth
      await _currentUser!.delete();

      // Limpiar sesión
      await _clearSession();

      return AuthResult(
        success: true,
        message: 'Cuenta eliminada exitosamente',
      );
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Error al eliminar cuenta', e);
      return AuthResult(
        success: false,
        error: _getAuthErrorMessage(e.code),
      );
    }
  }

  /// Cierra sesión
  Future<void> signOut() async {
    try {
      AppLogger.info('👋 Cerrando sesión');

      // Log evento
      if (_currentUser != null) {
        await _logAuthEvent('user_signed_out', {
          'userId': _currentUser!.uid,
          'userType': _userProfile?['userType'],
        });
      }

      // Cerrar sesiones
      await _auth.signOut();
      await _googleSignIn.signOut();

      // Limpiar estado
      await _clearSession();

      _authStateController.add(AuthState.unauthenticated);

      AppLogger.info('✅ Sesión cerrada');
    } catch (e) {
      AppLogger.error('Error al cerrar sesión', e);
    }
  }

  /// Maneja login exitoso
  Future<void> _onSuccessfulLogin(User user) async {
    try {
      // Actualizar última actividad
      _updateLastActivity();

      // Guardar sesión
      await _saveSession(user);

      // Actualizar último login en Firestore
      final collection = _userProfile!['collection'] ?? 'users';
      await _firestore.collection(collection).doc(user.uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
        'lastLoginIp': await _getDeviceIp(),
        'lastLoginDevice': await _getDeviceInfo(),
      });

      // Limpiar intentos fallidos
      _loginAttempts.remove(user.email);

      // Log evento
      await _logAuthEvent('successful_login', {
        'userId': user.uid,
        'userType': _userProfile?['userType'],
        'method': user.providerData.first.providerId,
      });
    } catch (e) {
      AppLogger.error('Error en onSuccessfulLogin', e);
    }
  }

  /// Guarda sesión
  Future<void> _saveSession(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final sessionToken = await user.getIdToken();
      final sessionExpiry = DateTime.now().add(_sessionTimeout);

      await prefs.setString('session_token', sessionToken ?? '');
      await prefs.setString('session_expiry', sessionExpiry.toIso8601String());
      await prefs.setString('user_id', user.uid);
      await prefs.setString(
          'user_type', _userProfile?['userType'] ?? 'passenger');
    } catch (e) {
      AppLogger.error('Error al guardar sesión', e);
    }
  }

  /// Limpia sesión
  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove('session_token');
      await prefs.remove('session_expiry');
      await prefs.remove('user_id');
      await prefs.remove('user_type');

      _currentUser = null;
      _userProfile = null;
      _lastActivity = null;
      _pendingMfaVerificationId = null;
      _pendingPhoneCredential = null;
    } catch (e) {
      AppLogger.error('Error al limpiar sesión', e);
    }
  }

  /// Valida contraseña
  PasswordValidation _validatePassword(String password) {
    final errors = <String>[];

    if (password.length < (_authConfig['passwordMinLength'] ?? 8)) {
      errors.add(
          'La contraseña debe tener al menos ${_authConfig['passwordMinLength']} caracteres');
    }

    if (_authConfig['passwordRequireUppercase'] == true &&
        !password.contains(RegExp(r'[A-Z]'))) {
      errors.add('Debe contener al menos una mayúscula');
    }

    if (_authConfig['passwordRequireLowercase'] == true &&
        !password.contains(RegExp(r'[a-z]'))) {
      errors.add('Debe contener al menos una minúscula');
    }

    if (_authConfig['passwordRequireNumbers'] == true &&
        !password.contains(RegExp(r'[0-9]'))) {
      errors.add('Debe contener al menos un número');
    }

    if (_authConfig['passwordRequireSpecialChars'] == true &&
        !password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      errors.add('Debe contener al menos un carácter especial');
    }

    return PasswordValidation(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Verifica si debe requerir MFA
  bool _shouldRequireMfa() {
    if (_authConfig['enableMfa'] != true) {
      return false;
    }

    // MFA obligatorio para admins
    if (_authConfig['mfaRequiredForAdmin'] == true && isAdmin) {
      return true;
    }

    // MFA opcional pero habilitado por el usuario
    return _userProfile?['mfaEnabled'] == true;
  }

  /// Registra intento fallido de login
  void _recordFailedLogin(String email) {
    if (!_loginAttempts.containsKey(email)) {
      _loginAttempts[email] = LoginAttempts(
        count: 0,
        firstAttempt: DateTime.now(),
        lastAttempt: DateTime.now(),
      );
    }

    final attempts = _loginAttempts[email]!;
    attempts.count++;
    attempts.lastAttempt = DateTime.now();

    AppLogger.warning('⚠️ Intento fallido #${attempts.count} para $email');
  }

  /// Verifica si la cuenta está bloqueada
  bool _isAccountLocked(String email) {
    if (!_loginAttempts.containsKey(email)) {
      return false;
    }

    final attempts = _loginAttempts[email]!;

    if (attempts.count >= _maxLoginAttempts) {
      final timeSinceLastAttempt =
          DateTime.now().difference(attempts.lastAttempt);

      if (timeSinceLastAttempt < _lockoutDuration) {
        return true;
      } else {
        // Reset intentos después del período de bloqueo
        _loginAttempts.remove(email);
        return false;
      }
    }

    return false;
  }

  /// Obtiene mensaje de error legible
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No existe una cuenta con este email';
      case 'wrong-password':
        return 'Contraseña incorrecta';
      case 'email-already-in-use':
        return 'Este email ya está registrado';
      case 'invalid-email':
        return 'Email inválido';
      case 'weak-password':
        return 'La contraseña es muy débil';
      case 'network-request-failed':
        return 'Error de conexión. Verifica tu internet';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada';
      case 'invalid-verification-code':
        return 'Código de verificación inválido';
      case 'invalid-phone-number':
        return 'Número de teléfono inválido';
      default:
        return 'Error de autenticación: $code';
    }
  }

  /// Obtiene IP del dispositivo (simulado)
  Future<String> _getDeviceIp() async {
    // En producción, obtener IP real
    return '192.168.1.1';
  }

  /// Obtiene info del dispositivo (simulado)
  Future<Map<String, String>> _getDeviceInfo() async {
    // En producción, obtener info real del dispositivo
    return {
      'platform': 'Android',
      'model': 'Device Model',
      'os': 'Android 12',
    };
  }

  /// Log de evento de autenticación
  Future<void> _logAuthEvent(String event, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('auth_events').add({
        'event': event,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
        'ip': await _getDeviceIp(),
        'device': await _getDeviceInfo(),
      });
    } catch (e) {
      AppLogger.error('Error al loggear evento de auth', e);
    }
  }

  /// Limpia recursos
  void dispose() {
    _authStateSubscription?.cancel();
    _tokenRefreshTimer?.cancel();
    _sessionTimer?.cancel();
    _authStateController.close();
    AppLogger.info('🔚 Firebase Auth Service disposed');
  }
}

// Modelos auxiliares

/// Estado de autenticación
enum AuthState {
  authenticated,
  unauthenticated,
  loading,
  error,
}

/// Resultado de autenticación
class AuthResult {
  final bool success;
  final User? user;
  final String? userType;
  final String? error;
  final String? message;
  final bool requiresMfa;
  final bool requiresSmsVerification;
  final String? verificationId;
  final bool isNewUser;

  AuthResult({
    required this.success,
    this.user,
    this.userType,
    this.error,
    this.message,
    this.requiresMfa = false,
    this.requiresSmsVerification = false,
    this.verificationId,
    this.isNewUser = false,
  });
}

/// Validación de contraseña
class PasswordValidation {
  final bool isValid;
  final List<String> errors;

  PasswordValidation({
    required this.isValid,
    required this.errors,
  });
}

/// Intentos de login
class LoginAttempts {
  int count;
  DateTime firstAttempt;
  DateTime lastAttempt;

  LoginAttempts({
    required this.count,
    required this.firstAttempt,
    required this.lastAttempt,
  });
}
