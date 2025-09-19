# GUÍA DE IMPLEMENTACIÓN DE SEGURIDAD OASISTAXI
## Seguridad Empresarial para Aplicaciones de Ride-Hailing

### 📋 TABLA DE CONTENIDOS
1. [Autenticación y Autorización](#autenticación-y-autorización)
2. [Seguridad de Datos](#seguridad-de-datos)
3. [Seguridad de Red y API](#seguridad-de-red-y-api)
4. [Seguridad Móvil](#seguridad-móvil)
5. [Compliance y Auditoría](#compliance-y-auditoría)
6. [Monitoreo de Seguridad](#monitoreo-de-seguridad)
7. [Incident Response](#incident-response)

---

## 1. AUTENTICACIÓN Y AUTORIZACIÓN

### 1.1 Firebase Authentication Securizada

```typescript
// services/auth_security_service.ts
export class AuthSecurityService {
  private static readonly MAX_LOGIN_ATTEMPTS = 5;
  private static readonly LOCKOUT_DURATION = 15 * 60 * 1000; // 15 minutos
  private static readonly MFA_REQUIRED_ROLES = ['admin', 'super_admin'];
  
  // Autenticación con rate limiting
  static async secureSignIn(email: string, password: string, userType: UserType) {
    try {
      // Verificar intentos de login
      const attempts = await this.getLoginAttempts(email);
      if (attempts >= this.MAX_LOGIN_ATTEMPTS) {
        const lockoutTime = await this.getLockoutTime(email);
        if (Date.now() < lockoutTime) {
          throw new Error('ACCOUNT_TEMPORARILY_LOCKED');
        }
        await this.resetLoginAttempts(email);
      }

      // Autenticación con Firebase
      const credential = await signInWithEmailAndPassword(auth, email, password);
      
      // Verificar tipo de usuario
      const customClaims = await this.verifyUserType(credential.user, userType);
      
      // MFA para roles específicos
      if (this.MFA_REQUIRED_ROLES.includes(customClaims.userType)) {
        await this.enforceMFA(credential.user);
      }
      
      // Log de seguridad
      await this.logSecurityEvent('LOGIN_SUCCESS', {
        uid: credential.user.uid,
        userType: customClaims.userType,
        timestamp: new Date(),
        ip: await this.getClientIP()
      });
      
      await this.resetLoginAttempts(email);
      return credential;
      
    } catch (error) {
      await this.incrementLoginAttempts(email);
      await this.logSecurityEvent('LOGIN_FAILED', {
        email,
        error: error.message,
        timestamp: new Date(),
        ip: await this.getClientIP()
      });
      throw error;
    }
  }

  // Verificación de claims personalizados
  static async verifyUserType(user: User, expectedType: UserType): Promise<CustomClaims> {
    const idTokenResult = await user.getIdTokenResult();
    const customClaims = idTokenResult.claims as CustomClaims;
    
    if (!customClaims.userType || customClaims.userType !== expectedType) {
      throw new Error('UNAUTHORIZED_USER_TYPE');
    }
    
    if (customClaims.status !== 'active') {
      throw new Error('ACCOUNT_INACTIVE');
    }
    
    return customClaims;
  }

  // Implementación MFA obligatorio
  static async enforceMFA(user: User): Promise<void> {
    const mfaSession = await multiFactor(user).getSession();
    const phoneAuthCredential = PhoneAuthProvider.credential(
      await this.sendMFACode(user),
      await this.promptMFACode()
    );
    
    const mfaAssertion = PhoneMultiFactorGenerator.assertion(phoneAuthCredential);
    await multiFactor(user).enroll(mfaAssertion, mfaSession);
  }
}
```

### 1.2 Custom Claims Seguros

```typescript
// Cloud Function: setCustomClaims
export const setCustomClaims = onCall({
  region: 'us-central1',
  enforceAppCheck: true,
  cors: ['https://oasistaxiperu.com']
}, async (request) => {
  // Verificar admin autenticado
  if (!request.auth?.token.admin) {
    throw new HttpsError('permission-denied', 'Solo administradores');
  }

  const { uid, claims } = request.data;
  
  // Validar claims permitidos
  const allowedClaims = ['userType', 'status', 'permissions', 'region'];
  const validatedClaims = Object.keys(claims)
    .filter(key => allowedClaims.includes(key))
    .reduce((obj, key) => {
      obj[key] = claims[key];
      return obj;
    }, {});

  await getAuth().setCustomUserClaims(uid, validatedClaims);
  
  // Auditoría
  await logAuditEvent({
    action: 'CLAIMS_UPDATED',
    adminUid: request.auth.uid,
    targetUid: uid,
    claims: validatedClaims,
    timestamp: new Date()
  });
  
  return { success: true };
});
```

### 1.3 Seguridad en Flutter

```dart
// lib/services/secure_auth_service.dart
class SecureAuthService {
  static const int _maxLoginAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 15);
  
  // Autenticación segura con biometría
  static Future<User?> authenticateSecurely({
    required String email,
    required String password,
    required UserType userType,
    bool requireBiometric = false,
  }) async {
    try {
      // Verificar biometría si es requerida
      if (requireBiometric) {
        final biometricAuth = await _verifyBiometric();
        if (!biometricAuth) {
          throw SecurityException('Autenticación biométrica fallida');
        }
      }
      
      // Verificar intentos previos
      await _checkLoginAttempts(email);
      
      // Firebase auth
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      
      if (credential.user == null) {
        throw SecurityException('Usuario no encontrado');
      }
      
      // Verificar claims
      final idToken = await credential.user!.getIdTokenResult();
      final claims = CustomClaims.fromMap(idToken.claims ?? {});
      
      if (claims.userType != userType.toString()) {
        await FirebaseAuth.instance.signOut();
        throw SecurityException('Tipo de usuario no autorizado');
      }
      
      if (claims.status != 'active') {
        await FirebaseAuth.instance.signOut();
        throw SecurityException('Cuenta inactiva');
      }
      
      // Reset intentos exitosos
      await _resetLoginAttempts(email);
      
      // Log seguridad
      await AppLogger.logSecurityEvent(
        'LOGIN_SUCCESS',
        {
          'uid': credential.user!.uid,
          'userType': userType.toString(),
          'biometricUsed': requireBiometric,
        },
      );
      
      return credential.user;
      
    } catch (e) {
      await _incrementLoginAttempts(email);
      await AppLogger.logSecurityEvent('LOGIN_FAILED', {
        'email': email,
        'error': e.toString(),
        'userType': userType.toString(),
      });
      rethrow;
    }
  }
  
  // Verificación biométrica
  static Future<bool> _verifyBiometric() async {
    final LocalAuthentication localAuth = LocalAuthentication();
    
    final isAvailable = await localAuth.canCheckBiometrics;
    if (!isAvailable) return false;
    
    return await localAuth.authenticate(
      localizedReason: 'Confirma tu identidad para acceder',
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );
  }
  
  // Gestión de intentos de login
  static Future<void> _checkLoginAttempts(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'login_attempts_$email';
    final attemptsKey = 'login_count_$email';
    
    final lastAttempt = prefs.getInt(key) ?? 0;
    final attempts = prefs.getInt(attemptsKey) ?? 0;
    
    if (attempts >= _maxLoginAttempts) {
      final timeDiff = DateTime.now().millisecondsSinceEpoch - lastAttempt;
      if (timeDiff < _lockoutDuration.inMilliseconds) {
        final remainingTime = _lockoutDuration.inMilliseconds - timeDiff;
        throw SecurityException(
          'Cuenta bloqueada temporalmente. '
          'Intenta en ${Duration(milliseconds: remainingTime).inMinutes} minutos.'
        );
      } else {
        await _resetLoginAttempts(email);
      }
    }
  }
}
```

---

## 2. SEGURIDAD DE DATOS

### 2.1 Encriptación End-to-End

```dart
// lib/services/encryption_service.dart
class EncryptionService {
  static const String _algorithm = 'AES';
  static const int _keyLength = 256;
  
  // Generar clave de encriptación única por usuario
  static Future<Uint8List> generateUserKey(String uid) async {
    final keyDerivation = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: _keyLength,
    );
    
    final saltBytes = await _getOrCreateSalt(uid);
    final secretKey = await keyDerivation.deriveKey(
      secretKey: SecretKey(utf8.encode(uid)),
      nonce: saltBytes,
    );
    
    return Uint8List.fromList(await secretKey.extractBytes());
  }
  
  // Encriptar datos sensibles
  static Future<String> encryptSensitiveData(
    String data, 
    String uid
  ) async {
    final algorithm = AesGcm.with256bits();
    final secretKey = SecretKey(await generateUserKey(uid));
    
    final nonce = algorithm.newNonce();
    final secretBox = await algorithm.encrypt(
      utf8.encode(data),
      secretKey: secretKey,
      nonce: nonce,
    );
    
    final encrypted = {
      'data': base64Encode(secretBox.cipherText),
      'nonce': base64Encode(nonce),
      'mac': base64Encode(secretBox.mac.bytes),
    };
    
    return base64Encode(utf8.encode(jsonEncode(encrypted)));
  }
  
  // Desencriptar datos
  static Future<String> decryptSensitiveData(
    String encryptedData,
    String uid
  ) async {
    final algorithm = AesGcm.with256bits();
    final secretKey = SecretKey(await generateUserKey(uid));
    
    final decodedData = jsonDecode(
      utf8.decode(base64Decode(encryptedData))
    ) as Map<String, dynamic>;
    
    final secretBox = SecretBox(
      base64Decode(decodedData['data']),
      nonce: base64Decode(decodedData['nonce']),
      mac: Mac(base64Decode(decodedData['mac'])),
    );
    
    final decrypted = await algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
    );
    
    return utf8.decode(decrypted);
  }
}
```

### 2.2 Firestore Security Rules Avanzadas

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Función para verificar roles
    function hasRole(role) {
      return request.auth != null && 
             request.auth.token.userType == role &&
             request.auth.token.status == 'active';
    }
    
    // Función para verificar propiedad de documento
    function isOwner(uid) {
      return request.auth != null && request.auth.uid == uid;
    }
    
    // Función para validar datos requeridos
    function hasRequiredFields(fields) {
      return fields.all(field => field in resource.data);
    }
    
    // Función para detectar modificaciones no autorizadas
    function onlyUpdatesAllowedFields(allowedFields) {
      let affectedKeys = request.resource.data.diff(resource.data).affectedKeys();
      return affectedKeys.hasOnly(allowedFields);
    }
    
    // Usuarios - acceso estricto
    match /users/{userId} {
      allow read: if isOwner(userId) || hasRole('admin');
      allow create: if isOwner(userId) && 
                       hasRequiredFields(['email', 'userType', 'createdAt']) &&
                       request.resource.data.userType in ['passenger', 'driver'];
      allow update: if isOwner(userId) && 
                       onlyUpdatesAllowedFields([
                         'profile', 'preferences', 'lastSeen', 'location'
                       ]);
      allow delete: if hasRole('admin');
      
      // Documentos sensibles del conductor
      match /documents/{docId} {
        allow read: if isOwner(userId) || hasRole('admin');
        allow write: if isOwner(userId) && 
                        request.resource.data.status == 'pending' &&
                        request.resource.data.encryptedData is string;
      }
    }
    
    // Viajes - lógica compleja de seguridad
    match /trips/{tripId} {
      allow read: if isOwner(resource.data.passengerId) ||
                     isOwner(resource.data.driverId) ||
                     hasRole('admin');
      
      allow create: if hasRole('passenger') &&
                       isOwner(request.resource.data.passengerId) &&
                       request.resource.data.status == 'searching' &&
                       'driverId' not in request.resource.data;
      
      allow update: if (
        // Conductor puede aceptar/rechazar
        (hasRole('driver') && 
         isOwner(request.resource.data.driverId) &&
         resource.data.status == 'searching' &&
         request.resource.data.status in ['accepted', 'rejected']) ||
        
        // Pasajero puede cancelar antes de accepted
        (hasRole('passenger') && 
         isOwner(resource.data.passengerId) &&
         resource.data.status in ['searching', 'driver_assigned'] &&
         request.resource.data.status == 'cancelled') ||
         
        // Solo campos de tracking permitidos durante viaje
        (resource.data.status in ['in_progress', 'arrived'] &&
         onlyUpdatesAllowedFields(['currentLocation', 'estimatedArrival', 'lastUpdate']))
      );
    }
    
    // Pagos - máxima seguridad
    match /payments/{paymentId} {
      allow read: if isOwner(resource.data.userId) || hasRole('admin');
      allow create: if false; // Solo via Cloud Functions
      allow update: if false; // Solo via Cloud Functions
      allow delete: if false; // Nunca eliminar registros de pago
    }
    
    // Reportes de emergencia - acceso controlado
    match /emergencyReports/{reportId} {
      allow read: if hasRole('admin') || 
                     isOwner(resource.data.reportedBy);
      allow create: if request.auth != null &&
                       isOwner(request.resource.data.reportedBy) &&
                       request.resource.data.status == 'active';
      allow update: if hasRole('admin') && 
                       onlyUpdatesAllowedFields(['status', 'resolvedAt', 'notes']);
    }
    
    // Auditoría - solo lectura para admins
    match /auditLogs/{logId} {
      allow read: if hasRole('admin');
      allow write: if false; // Solo via Cloud Functions
    }
  }
}
```

### 2.3 Validación de Datos en Cloud Functions

```typescript
// functions/src/utils/data_validator.ts
export class DataValidator {
  
  // Esquemas de validación con Joi
  static readonly schemas = {
    user: Joi.object({
      email: Joi.string().email().required(),
      phone: Joi.string().pattern(/^\+51[0-9]{9}$/).required(),
      userType: Joi.string().valid('passenger', 'driver', 'admin').required(),
      profile: Joi.object({
        firstName: Joi.string().min(2).max(50).required(),
        lastName: Joi.string().min(2).max(50).required(),
        dateOfBirth: Joi.date().max('now').required(),
        documentNumber: Joi.string().pattern(/^[0-9]{8}$/).required(),
      }).required()
    }),
    
    trip: Joi.object({
      passengerId: Joi.string().required(),
      pickupLocation: Joi.object({
        latitude: Joi.number().min(-90).max(90).required(),
        longitude: Joi.number().min(-180).max(180).required(),
        address: Joi.string().min(5).max(200).required()
      }).required(),
      destinationLocation: Joi.object({
        latitude: Joi.number().min(-90).max(90).required(),
        longitude: Joi.number().min(-180).max(180).required(),
        address: Joi.string().min(5).max(200).required()
      }).required(),
      vehicleType: Joi.string().valid('sedan', 'suv', 'hatchback').required(),
      estimatedFare: Joi.number().min(3.50).max(500).required()
    }),
    
    payment: Joi.object({
      tripId: Joi.string().required(),
      amount: Joi.number().min(0.01).max(1000).required(),
      currency: Joi.string().valid('PEN').required(),
      method: Joi.string().valid('cash', 'card', 'wallet').required(),
      status: Joi.string().valid('pending', 'processing', 'completed', 'failed').required()
    })
  };
  
  // Validar y sanitizar datos de entrada
  static validateAndSanitize<T>(data: any, schemaName: string): T {
    const schema = this.schemas[schemaName];
    if (!schema) {
      throw new Error(`Esquema de validación '${schemaName}' no encontrado`);
    }
    
    const { error, value } = schema.validate(data, {
      stripUnknown: true,
      abortEarly: false
    });
    
    if (error) {
      throw new HttpsError('invalid-argument', 
        `Datos inválidos: ${error.details.map(d => d.message).join(', ')}`
      );
    }
    
    return value as T;
  }
  
  // Validar coordenadas GPS
  static validateCoordinates(lat: number, lng: number): boolean {
    // Verificar que estén dentro de Perú
    const peruBounds = {
      north: -0.038777,
      south: -18.347975,
      east: -68.677986,
      west: -81.326744
    };
    
    return lat >= peruBounds.south && lat <= peruBounds.north &&
           lng >= peruBounds.west && lng <= peruBounds.east;
  }
  
  // Sanitizar strings para prevenir XSS
  static sanitizeString(input: string): string {
    return input
      .replace(/[<>]/g, '') // Remover < y >
      .replace(/javascript:/gi, '') // Remover javascript:
      .replace(/on\w+=/gi, '') // Remover event handlers
      .trim()
      .substring(0, 1000); // Limitar longitud
  }
}
```

---

## 3. SEGURIDAD DE RED Y API

### 3.1 HTTPS y Certificate Pinning

```dart
// lib/services/secure_http_service.dart
class SecureHttpService {
  static late Dio _dio;
  static const String _baseUrl = 'https://api.oasistaxiperu.com';
  static const List<String> _pinnedCertificates = [
    // SHA-256 fingerprints de certificados
    'sha256/47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=',
    'sha256/YLh1dUR9y6Kja30RrAn7JKnbQG/uEtLMkBgFF2Fuihg=',
  ];
  
  static void initialize() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'OasisTaxi/1.0.0 (Android/iOS)',
      },
    ));
    
    // Interceptor de seguridad
    _dio.interceptors.add(_SecurityInterceptor());
    
    // Certificate pinning
    (_dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
      client.badCertificateCallback = (cert, host, port) {
        final certSha256 = sha256.convert(cert.der).toString();
        return _pinnedCertificates.contains('sha256/$certSha256');
      };
      return client;
    };
  }
  
  // Request con autenticación automática
  static Future<Response> authenticatedRequest(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
    Map<String, String>? headers,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw SecurityException('Usuario no autenticado');
    }
    
    final idToken = await user.getIdToken();
    final requestHeaders = {
      'Authorization': 'Bearer $idToken',
      ...?headers,
    };
    
    return await _dio.request(
      path,
      options: Options(
        method: method,
        headers: requestHeaders,
      ),
      data: data,
    );
  }
}

class _SecurityInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Agregar headers de seguridad
    options.headers.addAll({
      'X-Requested-With': 'XMLHttpRequest',
      'X-App-Version': '1.0.0',
      'X-Platform': Platform.isAndroid ? 'android' : 'ios',
    });
    
    // Rate limiting del cliente
    _checkRateLimit(options.path);
    
    super.onRequest(options, handler);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Log errores de seguridad
    AppLogger.logSecurityEvent('HTTP_ERROR', {
      'url': err.requestOptions.path,
      'statusCode': err.response?.statusCode,
      'error': err.message,
    });
    
    super.onError(err, handler);
  }
  
  void _checkRateLimit(String path) {
    // Implementar rate limiting local
    // Máximo 10 requests por minuto por endpoint
  }
}
```

### 3.2 API Rate Limiting

```typescript
// functions/src/middleware/rate_limiter.ts
export class RateLimiter {
  private static readonly redis = new Redis(process.env.REDIS_URL);
  
  // Rate limiting por usuario
  static async checkUserRateLimit(
    uid: string, 
    action: string, 
    windowMs: number = 60000, 
    maxRequests: number = 10
  ): Promise<boolean> {
    const key = `rate_limit:${uid}:${action}`;
    const current = await this.redis.get(key);
    
    if (!current) {
      await this.redis.setex(key, Math.ceil(windowMs / 1000), '1');
      return true;
    }
    
    const count = parseInt(current);
    if (count >= maxRequests) {
      throw new HttpsError('resource-exhausted', 
        `Rate limit exceeded. Max ${maxRequests} requests per minute.`
      );
    }
    
    await this.redis.incr(key);
    return true;
  }
  
  // Rate limiting por IP
  static async checkIPRateLimit(
    ip: string,
    windowMs: number = 60000,
    maxRequests: number = 100
  ): Promise<boolean> {
    const key = `rate_limit:ip:${ip}`;
    const current = await this.redis.get(key);
    
    if (!current) {
      await this.redis.setex(key, Math.ceil(windowMs / 1000), '1');
      return true;
    }
    
    const count = parseInt(current);
    if (count >= maxRequests) {
      throw new HttpsError('resource-exhausted', 
        'IP rate limit exceeded'
      );
    }
    
    await this.redis.incr(key);
    return true;
  }
  
  // Detectar patrones sospechosos
  static async detectSuspiciousActivity(
    uid: string,
    action: string,
    metadata: any
  ): Promise<void> {
    const key = `suspicious:${uid}:${action}`;
    const count = await this.redis.incr(key);
    await this.redis.expire(key, 3600); // 1 hora
    
    // Umbral de actividad sospechosa
    if (count > 50) {
      await this.flagSuspiciousUser(uid, action, metadata);
    }
  }
  
  private static async flagSuspiciousUser(
    uid: string,
    action: string,
    metadata: any
  ): Promise<void> {
    // Crear alerta de seguridad
    await firestore().collection('security_alerts').add({
      type: 'SUSPICIOUS_ACTIVITY',
      uid,
      action,
      metadata,
      timestamp: FieldValue.serverTimestamp(),
      status: 'active'
    });
    
    // Notificar al equipo de seguridad
    await this.notifySecurityTeam({
      type: 'suspicious_activity',
      uid,
      action,
      metadata
    });
  }
}
```

---

## 4. SEGURIDAD MÓVIL

### 4.1 App Security

```dart
// lib/services/app_security_service.dart
class AppSecurityService {
  static bool _isJailbroken = false;
  static bool _isRooted = false;
  static bool _isDebugMode = false;
  
  // Verificar integridad de la app
  static Future<void> performSecurityChecks() async {
    await _checkDeviceIntegrity();
    await _checkAppIntegrity();
    await _checkNetworkSecurity();
    
    if (_isJailbroken || _isRooted || _isDebugMode) {
      await _handleSecurityThreat();
    }
  }
  
  // Detectar dispositivos comprometidos
  static Future<void> _checkDeviceIntegrity() async {
    try {
      // Verificar root/jailbreak
      final rootBeer = RootBeer();
      _isRooted = await rootBeer.isRooted();
      
      // Verificar modo debug
      _isDebugMode = kDebugMode;
      
      // Verificar emulador
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final isEmulator = androidInfo.isPhysicalDevice == false;
        if (isEmulator) {
          await _logSecurityEvent('EMULATOR_DETECTED', {
            'device': androidInfo.model,
            'fingerprint': androidInfo.fingerprint,
          });
        }
      }
      
    } catch (e) {
      await AppLogger.error('Error checking device integrity', e);
    }
  }
  
  // Verificar integridad de la aplicación
  static Future<void> _checkAppIntegrity() async {
    try {
      // Verificar firma de la app
      final packageInfo = await PackageInfo.fromPlatform();
      final expectedSignature = await _getExpectedSignature();
      
      if (Platform.isAndroid) {
        final signatures = await _getAppSignatures();
        if (!signatures.contains(expectedSignature)) {
          await _logSecurityEvent('INVALID_APP_SIGNATURE', {
            'package': packageInfo.packageName,
            'version': packageInfo.version,
          });
        }
      }
      
    } catch (e) {
      await AppLogger.error('Error checking app integrity', e);
    }
  }
  
  // Proteger contra debugging
  static void enableAntiDebug() {
    if (Platform.isAndroid) {
      // Detectar debugger attached
      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_isDebuggerAttached()) {
          _handleDebuggerDetected();
        }
      });
    }
  }
  
  // Obfuscación de strings sensibles
  static String deobfuscateString(List<int> obfuscated) {
    final key = _getDeobfuscationKey();
    return String.fromCharCodes(
      obfuscated.map((byte) => byte ^ key).toList()
    );
  }
  
  // Screen recording protection
  static void enableScreenProtection() {
    if (Platform.isAndroid) {
      // Prevenir screenshots y grabación
      FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    }
  }
  
  // Manejar amenazas de seguridad
  static Future<void> _handleSecurityThreat() async {
    // Log del incidente
    await _logSecurityEvent('SECURITY_THREAT_DETECTED', {
      'isRooted': _isRooted,
      'isJailbroken': _isJailbroken,
      'isDebugMode': _isDebugMode,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // Desactivar funcionalidades críticas
    await _disableCriticalFeatures();
    
    // Mostrar advertencia al usuario
    _showSecurityWarning();
  }
  
  static void _showSecurityWarning() {
    // Mostrar diálogo de seguridad
    final context = NavigationService.navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Alerta de Seguridad'),
          content: const Text(
            'Se ha detectado una modificación en tu dispositivo que podría '
            'comprometer la seguridad de la aplicación. Algunas funciones '
            'estarán limitadas.'
          ),
          actions: [
            TextButton(
              onPressed: () => SystemNavigator.pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
  }
}
```

### 4.2 Secure Storage

```dart
// lib/services/secure_storage_service.dart
class SecureStorageService {
  static late FlutterSecureStorage _storage;
  
  static void initialize() {
    _storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
        keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
        storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
        synchronizable: false,
      ),
    );
  }
  
  // Almacenar token de manera segura
  static Future<void> storeAuthToken(String token) async {
    final encryptedToken = await _encryptData(token);
    await _storage.write(
      key: 'auth_token',
      value: encryptedToken,
    );
  }
  
  // Recuperar token
  static Future<String?> getAuthToken() async {
    final encryptedToken = await _storage.read(key: 'auth_token');
    if (encryptedToken == null) return null;
    
    return await _decryptData(encryptedToken);
  }
  
  // Almacenar datos biométricos
  static Future<void> storeBiometricData(String data) async {
    if (!await _isBiometricAvailable()) {
      throw SecurityException('Biometría no disponible');
    }
    
    final encryptedData = await _encryptWithBiometric(data);
    await _storage.write(
      key: 'biometric_data',
      value: encryptedData,
    );
  }
  
  // Limpiar datos sensibles al logout
  static Future<void> clearSensitiveData() async {
    final keysToDelete = [
      'auth_token',
      'refresh_token',
      'biometric_data',
      'user_credentials',
      'payment_methods',
    ];
    
    for (final key in keysToDelete) {
      await _storage.delete(key: key);
    }
  }
  
  // Verificar integridad de datos
  static Future<bool> verifyDataIntegrity() async {
    try {
      final allData = await _storage.readAll();
      for (final entry in allData.entries) {
        final decrypted = await _decryptData(entry.value);
        if (decrypted.isEmpty) return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
```

---

## 5. COMPLIANCE Y AUDITORÍA

### 5.1 Auditoría de Acciones

```typescript
// functions/src/services/audit_service.ts
export class AuditService {
  
  // Log de auditoría completo
  static async logAuditEvent(event: AuditEvent): Promise<void> {
    const auditLog: AuditLog = {
      eventId: uuidv4(),
      timestamp: FieldValue.serverTimestamp(),
      eventType: event.type,
      userId: event.userId,
      userType: event.userType,
      action: event.action,
      resource: event.resource,
      resourceId: event.resourceId,
      changes: event.changes || null,
      ipAddress: event.ipAddress,
      userAgent: event.userAgent,
      sessionId: event.sessionId,
      severity: event.severity || 'INFO',
      metadata: event.metadata || {},
      compliance: {
        gdpr: event.gdprRelevant || false,
        pci: event.pciRelevant || false,
        local: event.localComplianceRelevant || false,
      }
    };
    
    // Almacenar en Firestore con particionado por fecha
    const datePartition = new Date().toISOString().split('T')[0];
    await firestore()
      .collection('audit_logs')
      .doc(datePartition)
      .collection('events')
      .doc(auditLog.eventId)
      .set(auditLog);
    
    // Log en BigQuery para análisis
    await this.logToBigQuery(auditLog);
    
    // Alertas en tiempo real para eventos críticos
    if (auditLog.severity === 'CRITICAL') {
      await this.triggerSecurityAlert(auditLog);
    }
  }
  
  // Auditoría específica para datos de usuarios
  static async logUserDataAccess(
    accessorId: string,
    targetUserId: string,
    action: 'READ' | 'update' | 'delete',
    dataFields: string[],
    justification: string,
    request: any
  ): Promise<void> {
    await this.logAuditEvent({
      type: 'USER_DATA_ACCESS',
      userId: accessorId,
      userType: request.auth?.token.userType,
      action: action,
      resource: 'user_data',
      resourceId: targetUserId,
      changes: {
        fields_accessed: dataFields,
        justification: justification,
      },
      ipAddress: request.rawRequest?.connection?.remoteAddress,
      userAgent: request.rawRequest?.headers['user-agent'],
      sessionId: request.auth?.token.session_id,
      severity: 'MEDIUM',
      gdprRelevant: true,
      localComplianceRelevant: true,
      metadata: {
        target_user: targetUserId,
        data_fields: dataFields,
        access_reason: justification,
      }
    });
  }
  
  // Auditoría de transacciones financieras
  static async logFinancialTransaction(
    transaction: FinancialTransaction,
    request: any
  ): Promise<void> {
    await this.logAuditEvent({
      type: 'FINANCIAL_TRANSACTION',
      userId: transaction.userId,
      userType: request.auth?.token.userType,
      action: transaction.type,
      resource: 'payment',
      resourceId: transaction.id,
      changes: {
        amount: transaction.amount,
        currency: transaction.currency,
        method: transaction.method,
        status: transaction.status,
      },
      ipAddress: request.rawRequest?.connection?.remoteAddress,
      userAgent: request.rawRequest?.headers['user-agent'],
      sessionId: request.auth?.token.session_id,
      severity: 'HIGH',
      pciRelevant: true,
      localComplianceRelevant: true,
      metadata: {
        transaction_id: transaction.id,
        merchant_reference: transaction.merchantReference,
        gateway_response: transaction.gatewayResponse,
      }
    });
  }
  
  // Generar reportes de compliance
  static async generateComplianceReport(
    startDate: Date,
    endDate: Date,
    complianceType: 'GDPR' | 'PCI' | 'LOCAL'
  ): Promise<ComplianceReport> {
    const query = firestore()
      .collectionGroup('events')
      .where('timestamp', '>=', startDate)
      .where('timestamp', '<=', endDate)
      .where(`compliance.${complianceType.toLowerCase()}`, '==', true)
      .orderBy('timestamp', 'desc');
    
    const snapshot = await query.get();
    const events = snapshot.docs.map(doc => doc.data() as AuditLog);
    
    return {
      reportId: uuidv4(),
      generatedAt: new Date(),
      complianceType,
      period: { startDate, endDate },
      totalEvents: events.length,
      eventsByType: this.groupEventsByType(events),
      criticalEvents: events.filter(e => e.severity === 'CRITICAL'),
      recommendations: await this.generateComplianceRecommendations(events),
      summary: await this.generateExecutiveSummary(events),
    };
  }
}
```

### 5.2 GDPR Compliance

```dart
// lib/services/gdpr_service.dart
class GDPRService {
  
  // Solicitud de exportación de datos del usuario
  static Future<Map<String, dynamic>> exportUserData(String userId) async {
    final userData = <String, dynamic>{};
    
    try {
      // Datos de perfil
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        userData['profile'] = _sanitizeExportData(userDoc.data()!);
      }
      
      // Historial de viajes
      final tripsQuery = await FirebaseFirestore.instance
          .collection('trips')
          .where('passengerId', isEqualTo: userId)
          .get();
      
      userData['trips'] = tripsQuery.docs
          .map((doc) => _sanitizeExportData(doc.data()))
          .toList();
      
      // Historial de pagos
      final paymentsQuery = await FirebaseFirestore.instance
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .get();
      
      userData['payments'] = paymentsQuery.docs
          .map((doc) => _sanitizeExportData(doc.data()))
          .toList();
      
      // Configuraciones de privacidad
      final preferencesDoc = await FirebaseFirestore.instance
          .collection('user_preferences')
          .doc(userId)
          .get();
      
      if (preferencesDoc.exists) {
        userData['preferences'] = preferencesDoc.data()!;
      }
      
      // Log de la exportación
      await _logDataExport(userId);
      
      return userData;
      
    } catch (e) {
      await AppLogger.error('Error exporting user data', e);
      rethrow;
    }
  }
  
  // Eliminación completa de datos del usuario
  static Future<void> deleteUserData(String userId) async {
    final batch = FirebaseFirestore.instance.batch();
    
    try {
      // Verificar que el usuario autenticado es el propietario
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.uid != userId) {
        throw SecurityException('No autorizado para eliminar estos datos');
      }
      
      // Marcar como eliminado en lugar de borrar (para auditoría)
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);
      
      batch.update(userRef, {
        'deleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'email': 'deleted@oasistaxi.com',
        'phone': null,
        'profile': {
          'firstName': 'Usuario',
          'lastName': 'Eliminado',
        },
        'personalData': FieldValue.delete(),
      });
      
      // Anonimizar viajes
      final tripsQuery = await FirebaseFirestore.instance
          .collection('trips')
          .where('passengerId', isEqualTo: userId)
          .get();
      
      for (final tripDoc in tripsQuery.docs) {
        batch.update(tripDoc.reference, {
          'passengerData': {
            'name': 'Usuario Eliminado',
            'phone': null,
          },
          'personalDataRemoved': true,
        });
      }
      
      // Eliminar datos de pago sensibles
      final paymentsQuery = await FirebaseFirestore.instance
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .get();
      
      for (final paymentDoc in paymentsQuery.docs) {
        batch.update(paymentDoc.reference, {
          'cardData': FieldValue.delete(),
          'personalInfo': FieldValue.delete(),
          'anonymized': true,
        });
      }
      
      await batch.commit();
      
      // Log de eliminación para auditoría
      await _logDataDeletion(userId);
      
      // Eliminar cuenta de Firebase Auth
      await currentUser?.delete();
      
    } catch (e) {
      await AppLogger.error('Error deleting user data', e);
      rethrow;
    }
  }
  
  // Gestión de consentimientos
  static Future<void> updateConsent(
    String userId,
    Map<String, bool> consents
  ) async {
    final consentDoc = {
      'userId': userId,
      'consents': consents,
      'updatedAt': FieldValue.serverTimestamp(),
      'ipAddress': await _getClientIP(),
      'userAgent': await _getUserAgent(),
    };
    
    await FirebaseFirestore.instance
        .collection('user_consents')
        .doc(userId)
        .set(consentDoc, SetOptions(merge: true));
    
    // Log para auditoría GDPR
    await _logConsentUpdate(userId, consents);
  }
  
  // Verificar validez de consentimientos
  static Future<Map<String, bool>> getActiveConsents(String userId) async {
    final consentDoc = await FirebaseFirestore.instance
        .collection('user_consents')
        .doc(userId)
        .get();
    
    if (!consentDoc.exists) {
      return <String, bool>{};
    }
    
    final data = consentDoc.data()!;
    final consents = Map<String, bool>.from(data['consents'] ?? {});
    
    // Verificar si los consentimientos han expirado (1 año)
    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
    if (updatedAt != null) {
      final expiration = updatedAt.add(const Duration(days: 365));
      if (DateTime.now().isAfter(expiration)) {
        await _requestConsentRenewal(userId);
        return <String, bool>{}; // Consentimientos expirados
      }
    }
    
    return consents;
  }
  
  // Portabilidad de datos
  static Future<String> generatePortableDataFile(String userId) async {
    final userData = await exportUserData(userId);
    
    // Generar archivo JSON estructurado
    final portableData = {
      'export_info': {
        'user_id': userId,
        'export_date': DateTime.now().toIso8601String(),
        'format_version': '1.0',
        'app_version': '1.0.0',
      },
      'data': userData,
    };
    
    final jsonString = const JsonEncoder.withIndent('  ')
        .convert(portableData);
    
    // Crear archivo temporal
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/oasistaxi_data_export_$userId.json');
    await file.writeAsString(jsonString);
    
    return file.path;
  }
}
```

---

## 6. MONITOREO DE SEGURIDAD

### 6.1 Security Monitoring

```typescript
// functions/src/services/security_monitoring_service.ts
export class SecurityMonitoringService {
  
  // Monitor de eventos de seguridad en tiempo real
  static async initializeSecurityMonitoring(): Promise<void> {
    // Monitorear intentos de login fallidos
    const failedLoginsRef = firestore()
      .collection('security_events')
      .where('type', '==', 'LOGIN_FAILED');
    
    failedLoginsRef.onSnapshot(snapshot => {
      snapshot.docChanges().forEach(change => {
        if (change.type === 'added') {
          this.analyzeFailedLogin(change.doc.data());
        }
      });
    });
    
    // Monitorear transacciones sospechosas
    const suspiciousTransactionsRef = firestore()
      .collection('payments')
      .where('flags.suspicious', '==', true);
    
    suspiciousTransactionsRef.onSnapshot(snapshot => {
      snapshot.docChanges().forEach(change => {
        if (change.type === 'added') {
          this.analyzeSuspiciousTransaction(change.doc.data());
        }
      });
    });
  }
  
  // Analizar patrones de login fallidos
  static async analyzeFailedLogin(loginEvent: any): Promise<void> {
    const { email, ip, timestamp, userType } = loginEvent;
    
    // Contar intentos fallidos en la última hora
    const oneHourAgo = new Date(Date.now() - 3600000);
    const recentFailures = await firestore()
      .collection('security_events')
      .where('type', '==', 'LOGIN_FAILED')
      .where('email', '==', email)
      .where('timestamp', '>', oneHourAgo)
      .get();
    
    if (recentFailures.size >= 5) {
      await this.triggerBruteForceAlert(email, ip, recentFailures.size);
    }
    
    // Analizar intentos desde IPs múltiples
    const uniqueIPs = new Set(
      recentFailures.docs.map(doc => doc.data().ip)
    );
    
    if (uniqueIPs.size >= 3) {
      await this.triggerDistributedAttackAlert(email, Array.from(uniqueIPs));
    }
  }
  
  // Detectar transacciones sospechosas
  static async analyzeSuspiciousTransaction(transaction: any): Promise<void> {
    const riskScore = await this.calculateTransactionRiskScore(transaction);
    
    if (riskScore >= 80) {
      await this.blockTransaction(transaction.id, 'HIGH_RISK_SCORE');
      await this.notifySecurityTeam({
        type: 'HIGH_RISK_TRANSACTION',
        transactionId: transaction.id,
        riskScore,
        userId: transaction.userId,
        amount: transaction.amount,
      });
    } else if (riskScore >= 60) {
      await this.flagTransactionForReview(transaction.id, riskScore);
    }
  }
  
  // Calcular score de riesgo de transacción
  static async calculateTransactionRiskScore(transaction: any): Promise<number> {
    let riskScore = 0;
    
    // Factor: Monto inusual
    const userAverage = await this.getUserAverageTransaction(transaction.userId);
    if (transaction.amount > userAverage * 5) {
      riskScore += 30;
    }
    
    // Factor: Hora inusual
    const hour = new Date(transaction.timestamp.toDate()).getHours();
    if (hour >= 23 || hour <= 5) {
      riskScore += 20;
    }
    
    // Factor: Ubicación inusual
    const userLocations = await this.getUserFrequentLocations(transaction.userId);
    const transactionLocation = transaction.location;
    
    const isLocationFamiliar = userLocations.some(loc => 
      this.calculateDistance(loc, transactionLocation) < 10 // 10km
    );
    
    if (!isLocationFamiliar) {
      riskScore += 25;
    }
    
    // Factor: Velocidad de transacciones
    const recentTransactions = await this.getRecentTransactions(
      transaction.userId, 
      10 * 60 * 1000 // 10 minutos
    );
    
    if (recentTransactions.length >= 3) {
      riskScore += 40;
    }
    
    // Factor: Dispositivo nuevo
    const isNewDevice = await this.isNewDevice(
      transaction.userId, 
      transaction.deviceFingerprint
    );
    
    if (isNewDevice) {
      riskScore += 35;
    }
    
    return Math.min(riskScore, 100);
  }
  
  // Sistema de alertas de seguridad
  static async triggerSecurityAlert(alert: SecurityAlert): Promise<void> {
    // Almacenar alerta
    const alertDoc = await firestore()
      .collection('security_alerts')
      .add({
        ...alert,
        timestamp: FieldValue.serverTimestamp(),
        status: 'active',
        assignedTo: null,
        resolution: null,
      });
    
    // Notificación inmediata para alertas críticas
    if (alert.severity === 'CRITICAL') {
      await this.sendImmediateNotification(alert);
    }
    
    // Enviar a sistema de tickets
    await this.createSecurityTicket(alertDoc.id, alert);
    
    // Log en BigQuery para análisis
    await this.logAlertToBigQuery(alert);
  }
  
  // Análisis de comportamiento de usuario
  static async analyzeUserBehavior(userId: string): Promise<BehaviorAnalysis> {
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    
    // Patrones de viajes
    const trips = await firestore()
      .collection('trips')
      .where('passengerId', '==', userId)
      .where('createdAt', '>', thirtyDaysAgo)
      .get();
    
    const tripData = trips.docs.map(doc => doc.data());
    
    // Patrones de ubicación
    const locationPattern = this.analyzeLocationPattern(tripData);
    
    // Patrones temporales
    const timePattern = this.analyzeTimePattern(tripData);
    
    // Patrones de gasto
    const spendingPattern = this.analyzeSpendingPattern(tripData);
    
    // Detectar anomalías
    const anomalies = await this.detectBehaviorAnomalies(
      locationPattern,
      timePattern,
      spendingPattern
    );
    
    return {
      userId,
      analysisDate: new Date(),
      locationPattern,
      timePattern,
      spendingPattern,
      anomalies,
      riskLevel: this.calculateUserRiskLevel(anomalies),
    };
  }
}
```

### 6.2 Alertas Automáticas

```dart
// lib/services/security_alerts_service.dart
class SecurityAlertsService {
  static const String _alertsCollection = 'security_alerts';
  
  // Configurar listeners para alertas de seguridad
  static void initializeAlertListeners() {
    // Alertas para el usuario actual
    _listenToUserAlerts();
    
    // Alertas de administrador
    _listenToAdminAlerts();
    
    // Alertas del sistema
    _listenToSystemAlerts();
  }
  
  static void _listenToUserAlerts() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    FirebaseFirestore.instance
        .collection(_alertsCollection)
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _handleUserAlert(change.doc.data()!);
        }
      }
    });
  }
  
  static void _handleUserAlert(Map<String, dynamic> alert) {
    final alertType = alert['type'] as String;
    final severity = alert['severity'] as String;
    
    switch (alertType) {
      case 'SUSPICIOUS_LOGIN':
        _showSuspiciousLoginAlert(alert);
        break;
      case 'NEW_DEVICE_LOGIN':
        _showNewDeviceAlert(alert);
        break;
      case 'ACCOUNT_LOCKED':
        _showAccountLockedAlert(alert);
        break;
      case 'PASSWORD_CHANGE_REQUIRED':
        _showPasswordChangeAlert(alert);
        break;
      case 'SUSPICIOUS_PAYMENT':
        _showSuspiciousPaymentAlert(alert);
        break;
    }
    
    // Log local del alert
    AppLogger.logSecurityEvent('ALERT_RECEIVED', {
      'alertType': alertType,
      'severity': severity,
      'alertId': alert['id'],
    });
  }
  
  static void _showSuspiciousLoginAlert(Map<String, dynamic> alert) {
    final context = NavigationService.navigatorKey.currentContext;
    if (context == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.security, color: Colors.red, size: 48),
        title: const Text('Actividad Sospechosa Detectada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Se ha detectado un intento de acceso sospechoso a tu cuenta:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('Fecha: ${_formatDateTime(alert['timestamp'])}'),
            Text('IP: ${alert['ipAddress'] ?? 'Desconocida'}'),
            Text('Ubicación: ${alert['location'] ?? 'Desconocida'}'),
            const SizedBox(height: 12),
            const Text(
              '¿Fuiste tú quien intentó acceder?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _reportUnauthorizedAccess(alert),
            child: const Text('No fui yo', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => _confirmAuthorizedAccess(alert),
            child: const Text('Sí, fui yo'),
          ),
        ],
      ),
    );
  }
  
  static void _showSuspiciousPaymentAlert(Map<String, dynamic> alert) {
    final context = NavigationService.navigatorKey.currentContext;
    if (context == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.payment, color: Colors.orange, size: 48),
        title: const Text('Transacción Sospechosa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Se ha detectado una transacción inusual en tu cuenta:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('Monto: S/ ${alert['amount']}'),
            Text('Fecha: ${_formatDateTime(alert['timestamp'])}'),
            Text('Método: ${alert['paymentMethod']}'),
            const SizedBox(height: 12),
            const Text('¿Autorizaste esta transacción?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _reportFraudulentTransaction(alert),
            child: const Text('Reportar Fraude', 
                style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => _confirmTransaction(alert),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
  
  // Reportar acceso no autorizado
  static Future<void> _reportUnauthorizedAccess(
    Map<String, dynamic> alert
  ) async {
    try {
      // Cambiar contraseña inmediatamente
      await _forcePasswordChange();
      
      // Cerrar todas las sesiones activas
      await _revokeAllSessions();
      
      // Crear reporte de incidente
      await FirebaseFirestore.instance
          .collection('security_incidents')
          .add({
        'type': 'UNAUTHORIZED_ACCESS',
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'originalAlert': alert,
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'open',
        'severity': 'HIGH',
        'actions_taken': [
          'password_changed',
          'sessions_revoked',
          'incident_created'
        ],
      });
      
      // Notificar al equipo de seguridad
      await _notifySecurityTeam('UNAUTHORIZED_ACCESS_REPORTED', alert);
      
      Navigator.of(NavigationService.navigatorKey.currentContext!)
          .pushNamedAndRemoveUntil('/login', (route) => false);
      
    } catch (e) {
      await AppLogger.error('Error reporting unauthorized access', e);
    }
  }
  
  // Confirmar transacción autorizada
  static Future<void> _confirmTransaction(Map<String, dynamic> alert) async {
    await FirebaseFirestore.instance
        .collection('security_alerts')
        .doc(alert['id'])
        .update({
      'status': 'resolved',
      'resolution': 'confirmed_by_user',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
    
    Navigator.of(NavigationService.navigatorKey.currentContext!).pop();
  }
  
  // Reportar transacción fraudulenta
  static Future<void> _reportFraudulentTransaction(
    Map<String, dynamic> alert
  ) async {
    try {
      // Bloquear tarjeta/método de pago
      await _blockPaymentMethod(alert['paymentMethodId']);
      
      // Crear caso de fraude
      await FirebaseFirestore.instance
          .collection('fraud_cases')
          .add({
        'type': 'FRAUDULENT_TRANSACTION',
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'transactionId': alert['transactionId'],
        'amount': alert['amount'],
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'investigating',
        'priority': 'HIGH',
      });
      
      // Reversar transacción si es posible
      await _initiateTransactionReversal(alert['transactionId']);
      
      Navigator.of(NavigationService.navigatorKey.currentContext!).pop();
      
      _showSuccessMessage('Reporte enviado. Tu método de pago ha sido bloqueado '
          'temporalmente y iniciaremos la investigación.');
      
    } catch (e) {
      await AppLogger.error('Error reporting fraudulent transaction', e);
    }
  }
}
```

---

## 7. INCIDENT RESPONSE

### 7.1 Plan de Respuesta a Incidentes

```typescript
// functions/src/services/incident_response_service.ts
export class IncidentResponseService {
  
  // Clasificación automática de incidentes
  static async classifyIncident(incident: SecurityIncident): Promise<IncidentClassification> {
    const classification: IncidentClassification = {
      severity: await this.calculateIncidentSeverity(incident),
      category: this.categorizeIncident(incident),
      priority: await this.calculatePriority(incident),
      estimatedImpact: await this.estimateImpact(incident),
      requiredResponse: await this.determineRequiredResponse(incident),
    };
    
    return classification;
  }
  
  // Respuesta automática a incidentes críticos
  static async handleCriticalIncident(incident: SecurityIncident): Promise<void> {
    const responseId = uuidv4();
    
    // 1. Contención inmediata
    await this.immediateContainment(incident);
    
    // 2. Notificación de emergencia
    await this.emergencyNotification(incident, responseId);
    
    // 3. Preservación de evidencia
    await this.preserveEvidence(incident);
    
    // 4. Activar equipo de respuesta
    await this.activateResponseTeam(incident, responseId);
    
    // 5. Crear war room
    await this.createWarRoom(incident, responseId);
    
    // 6. Iniciar timeline de respuesta
    await this.initializeResponseTimeline(incident, responseId);
  }
  
  // Contención inmediata de amenazas
  static async immediateContainment(incident: SecurityIncident): Promise<void> {
    switch (incident.type) {
      case 'DATA_BREACH':
        await this.containDataBreach(incident);
        break;
      case 'ACCOUNT_TAKEOVER':
        await this.containAccountTakeover(incident);
        break;
      case 'PAYMENT_FRAUD':
        await this.containPaymentFraud(incident);
        break;
      case 'DDoS_ATTACK':
        await this.containDDoSAttack(incident);
        break;
      case 'MALWARE_DETECTION':
        await this.containMalware(incident);
        break;
    }
  }
  
  // Contención de brechas de datos
  static async containDataBreach(incident: SecurityIncident): Promise<void> {
    const affectedUsers = incident.metadata.affectedUsers || [];
    
    // Revocar tokens de usuarios afectados
    for (const userId of affectedUsers) {
      await getAuth().revokeRefreshTokens(userId);
      
      // Forzar re-autenticación
      await firestore()
        .collection('users')
        .doc(userId)
        .update({
          'security.forceReauth': true,
          'security.lastSecurityUpdate': FieldValue.serverTimestamp(),
        });
    }
    
    // Rotar claves API si es necesario
    if (incident.metadata.apiKeysCompromised) {
      await this.rotateAPIKeys();
    }
    
    // Habilitar logging adicional
    await this.enableEnhancedLogging();
    
    // Bloquear acceso desde IPs sospechosas
    if (incident.metadata.suspiciousIPs) {
      await this.blockSuspiciousIPs(incident.metadata.suspiciousIPs);
    }
  }
  
  // Contención de compromiso de cuentas
  static async containAccountTakeover(incident: SecurityIncident): Promise<void> {
    const compromisedAccounts = incident.metadata.compromisedAccounts || [];
    
    for (const account of compromisedAccounts) {
      // Suspender cuenta temporalmente
      await this.suspendAccount(account.userId, 'SECURITY_INCIDENT');
      
      // Revocar todas las sesiones
      await getAuth().revokeRefreshTokens(account.userId);
      
      // Bloquear métodos de pago
      await this.blockUserPaymentMethods(account.userId);
      
      // Notificar al usuario
      await this.notifyUserOfCompromise(account.userId, incident.id);
    }
  }
  
  // Investigación forense
  static async conductForensicInvestigation(
    incidentId: string
  ): Promise<ForensicReport> {
    const incident = await this.getIncident(incidentId);
    
    // Recopilar logs del período del incidente
    const logs = await this.gatherIncidentLogs(incident);
    
    // Analizar patrones de acceso
    const accessPatterns = await this.analyzeAccessPatterns(logs);
    
    // Identificar vectores de ataque
    const attackVectors = await this.identifyAttackVectors(logs, incident);
    
    // Análisis de impacto
    const impactAnalysis = await this.analyzeIncidentImpact(incident);
    
    // Cronología de eventos
    const timeline = await this.buildIncidentTimeline(logs, incident);
    
    // Recomendaciones de remediación
    const recommendations = await this.generateRemediationRecommendations(
      incident, 
      attackVectors, 
      impactAnalysis
    );
    
    const forensicReport: ForensicReport = {
      incidentId,
      investigationDate: new Date(),
      summary: await this.generateExecutiveSummary(incident, impactAnalysis),
      timeline,
      attackVectors,
      accessPatterns,
      impactAnalysis,
      recommendations,
      evidence: await this.packageEvidence(logs, incident),
      investigator: 'automated_system',
    };
    
    // Almacenar reporte
    await firestore()
      .collection('forensic_reports')
      .doc(incidentId)
      .set(forensicReport);
    
    return forensicReport;
  }
  
  // Recuperación post-incidente
  static async initiateRecovery(incidentId: string): Promise<void> {
    const incident = await this.getIncident(incidentId);
    const forensicReport = await this.getForensicReport(incidentId);
    
    // Plan de recuperación basado en recomendaciones
    const recoveryPlan = await this.createRecoveryPlan(
      incident, 
      forensicReport.recommendations
    );
    
    // Ejecutar pasos de recuperación
    for (const step of recoveryPlan.steps) {
      await this.executeRecoveryStep(step, incidentId);
    }
    
    // Verificar integridad del sistema
    await this.verifySystemIntegrity();
    
    // Restaurar servicios gradualmente
    await this.gradualServiceRestoration(incident);
    
    // Monitoreo post-recuperación
    await this.enablePostRecoveryMonitoring(incident);
  }
  
  // Lecciones aprendidas y mejoras
  static async conductPostIncidentReview(
    incidentId: string
  ): Promise<PostIncidentReport> {
    const incident = await this.getIncident(incidentId);
    const forensicReport = await this.getForensicReport(incidentId);
    const responseTimeline = await this.getResponseTimeline(incidentId);
    
    // Análisis de la respuesta
    const responseAnalysis = this.analyzeResponseEffectiveness(
      responseTimeline,
      incident
    );
    
    // Identificar gaps en seguridad
    const securityGaps = await this.identifySecurityGaps(
      forensicReport,
      incident
    );
    
    // Generar recomendaciones de mejora
    const improvements = await this.generateImprovementRecommendations(
      securityGaps,
      responseAnalysis
    );
    
    const postIncidentReport: PostIncidentReport = {
      incidentId,
      reviewDate: new Date(),
      incidentSummary: forensicReport.summary,
      responseAnalysis,
      securityGaps,
      improvements,
      actionItems: await this.createActionItems(improvements),
      reviewParticipants: await this.getReviewParticipants(incidentId),
    };
    
    // Implementar mejoras automáticas
    await this.implementAutomaticImprovements(improvements);
    
    return postIncidentReport;
  }
}
```

### 7.2 Playbooks de Respuesta

```typescript
// functions/src/playbooks/security_playbooks.ts
export class SecurityPlaybooks {
  
  // Playbook para ataques de fuerza bruta
  static readonly BRUTE_FORCE_PLAYBOOK = {
    name: 'Brute Force Attack Response',
    triggers: ['multiple_failed_logins', 'ip_login_threshold_exceeded'],
    steps: [
      {
        action: 'immediate_containment',
        tasks: [
          'block_attacking_ip',
          'temporary_account_lock',
          'enable_enhanced_monitoring'
        ],
        timeLimit: '5 minutes',
        automated: true,
      },
      {
        action: 'investigation',
        tasks: [
          'analyze_attack_pattern',
          'identify_affected_accounts',
          'check_for_successful_breaches'
        ],
        timeLimit: '30 minutes',
        automated: true,
      },
      {
        action: 'notification',
        tasks: [
          'notify_affected_users',
          'alert_security_team',
          'create_incident_ticket'
        ],
        timeLimit: '1 hour',
        automated: true,
      },
      {
        action: 'remediation',
        tasks: [
          'force_password_reset',
          'implement_additional_protection',
          'update_security_rules'
        ],
        timeLimit: '4 hours',
        automated: false,
      }
    ]
  };
  
  // Playbook para fraude de pagos
  static readonly PAYMENT_FRAUD_PLAYBOOK = {
    name: 'Payment Fraud Response',
    triggers: ['suspicious_transaction', 'fraud_detection_alert'],
    steps: [
      {
        action: 'immediate_containment',
        tasks: [
          'freeze_payment_method',
          'hold_transaction',
          'flag_user_account'
        ],
        timeLimit: '2 minutes',
        automated: true,
      },
      {
        action: 'verification',
        tasks: [
          'contact_cardholder',
          'verify_transaction_legitimacy',
          'check_device_fingerprint'
        ],
        timeLimit: '15 minutes',
        automated: false,
      },
      {
        action: 'decision',
        tasks: [
          'approve_or_decline_transaction',
          'update_fraud_score',
          'adjust_risk_parameters'
        ],
        timeLimit: '30 minutes',
        automated: false,
      }
    ]
  };
  
  // Ejecutor de playbooks
  static async executePlaybook(
    playbookName: string,
    incidentData: any
  ): Promise<PlaybookExecution> {
    const playbook = this.getPlaybook(playbookName);
    const executionId = uuidv4();
    
    const execution: PlaybookExecution = {
      id: executionId,
      playbookName,
      incidentId: incidentData.id,
      startTime: new Date(),
      status: 'running',
      steps: [],
    };
    
    for (const step of playbook.steps) {
      const stepExecution = await this.executePlaybookStep(
        step,
        incidentData,
        executionId
      );
      
      execution.steps.push(stepExecution);
      
      // Si un paso crítico falla, escalar
      if (stepExecution.status === 'failed' && step.critical) {
        await this.escalatePlaybookFailure(executionId, step, stepExecution);
        break;
      }
    }
    
    execution.endTime = new Date();
    execution.status = this.calculatePlaybookStatus(execution.steps);
    
    // Almacenar ejecución para auditoría
    await firestore()
      .collection('playbook_executions')
      .doc(executionId)
      .set(execution);
    
    return execution;
  }
}
```

---

## CONCLUSIÓN

Esta guía de implementación de seguridad proporciona un framework completo para proteger OasisTaxi contra las amenazas más comunes en aplicaciones de ride-hailing. La implementación incluye:

- **Autenticación robusta** con MFA y rate limiting
- **Encriptación end-to-end** para datos sensibles
- **Monitoreo proactivo** de amenazas
- **Compliance GDPR** completo
- **Respuesta automatizada** a incidentes
- **Auditoría exhaustiva** de todas las acciones

### Próximos Pasos
1. Implementar monitoreo en tiempo real
2. Configurar alertas automatizadas
3. Entrenar al equipo en procedimientos de respuesta
4. Realizar pruebas de penetración regulares
5. Actualizar políticas de seguridad periódicamente

### Métricas de Seguridad
- Tiempo de detección de amenazas: < 5 minutos
- Tiempo de respuesta a incidentes: < 15 minutos
- Cobertura de auditoría: 100%
- Compliance GDPR: 100%
- Disponibilidad del sistema: 99.9%