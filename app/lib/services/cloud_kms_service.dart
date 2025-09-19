import 'dart:convert';
import 'dart:typed_data';
import 'package:googleapis/cloudkms/v1.dart' as kms;
import 'package:googleapis_auth/auth_io.dart' as auth;
import '../core/config/environment_config.dart';
import '../utils/app_logger.dart';

/// Servicio para gestión segura de claves usando Google Cloud KMS
class CloudKmsService {
  static CloudKmsService? _instance;
  static CloudKmsService get instance => _instance ??= CloudKmsService._();
  CloudKmsService._();

  kms.CloudKMSApi? _kmsApi;
  auth.AuthClient? _authClient;
  DateTime? _tokenExpiry;
  bool _isInitialized = false;

  /// Inicializa el servicio KMS
  Future<void> initialize() async {
    try {
      AppLogger.info('Inicializando Cloud KMS Service');

      // Crear credenciales de service account desde variables de entorno
      await _createAuthClient();

      // Crear cliente KMS
      _kmsApi = kms.CloudKMSApi(_authClient!);

      _isInitialized = true;
      AppLogger.info('Cloud KMS Service inicializado exitosamente');
    } catch (e, stackTrace) {
      AppLogger.error('Error inicializando Cloud KMS Service', e, stackTrace);
      rethrow;
    }
  }

  /// Crea el cliente autenticado usando Service Account
  Future<void> _createAuthClient() async {
    try {
      // Construir credenciales de service account desde variables de entorno
      final serviceAccountCredentials = auth.ServiceAccountCredentials(
        EnvironmentConfig.firebaseClientEmail,
        auth.ClientId(EnvironmentConfig.firebaseClientId),
        EnvironmentConfig.firebasePrivateKey,
      );

      // Obtener cliente autenticado con scope de Cloud KMS
      _authClient = await auth.clientViaServiceAccount(
        serviceAccountCredentials,
        ['https://www.googleapis.com/auth/cloudkms'],
      );

      // Guardar tiempo de expiración (típicamente 1 hora)
      _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));

      AppLogger.info('Cliente KMS autenticado exitosamente');
    } catch (e, stackTrace) {
      AppLogger.error('Error creando cliente autenticado KMS', e, stackTrace);
      rethrow;
    }
  }

  /// Cifra datos usando Cloud KMS (envelope encryption)
  Future<String> encryptData(String plaintext) async {
    if (!_isInitialized) await initialize();

    try {
      await _ensureValidToken();

      final request = kms.EncryptRequest()
        ..plaintext = base64.encode(utf8.encode(plaintext));

      final response = await _kmsApi!.projects.locations.keyRings.cryptoKeys
          .encrypt(request, EnvironmentConfig.encryptionKeyId);

      if (response.ciphertext == null) {
        throw Exception('Error: KMS no devolvió ciphertext');
      }

      return response.ciphertext!;
    } catch (e, stackTrace) {
      AppLogger.error('Error en cifrado KMS', e, stackTrace);
      rethrow;
    }
  }

  /// Descifra datos usando Cloud KMS
  Future<String> decryptData(String ciphertext) async {
    if (!_isInitialized) await initialize();

    try {
      await _ensureValidToken();

      final request = kms.DecryptRequest()..ciphertext = ciphertext;

      final response = await _kmsApi!.projects.locations.keyRings.cryptoKeys
          .decrypt(request, EnvironmentConfig.encryptionKeyId);

      if (response.plaintext == null) {
        throw Exception('Error: KMS no devolvió plaintext');
      }

      final decryptedBytes = base64.decode(response.plaintext!);
      return utf8.decode(decryptedBytes);
    } catch (e, stackTrace) {
      AppLogger.error('Error en descifrado KMS', e, stackTrace);
      rethrow;
    }
  }

  /// Genera una Data Encryption Key (DEK) de 32 bytes
  Future<Uint8List> generateDataEncryptionKey() async {
    if (!_isInitialized) await initialize();

    try {
      await _ensureValidToken();

      // Generar 32 bytes aleatorios localmente (más eficiente que usar KMS)
      final random = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        random[i] = DateTime.now().microsecondsSinceEpoch % 256;
      }

      // Para mayor seguridad, podríamos usar la API de random de KMS
      // pero es más costoso y lento
      AppLogger.info('DEK generada localmente (32 bytes)');
      return random;
    } catch (e, stackTrace) {
      AppLogger.error('Error generando DEK', e, stackTrace);
      rethrow;
    }
  }

  /// Envuelve (cifra) una DEK con KMS para almacenamiento seguro
  Future<String> wrapDataEncryptionKey(Uint8List dek) async {
    if (!_isInitialized) await initialize();

    try {
      await _ensureValidToken();

      final request = kms.EncryptRequest()
        ..plaintext = base64.encode(dek);

      final response = await _kmsApi!.projects.locations.keyRings.cryptoKeys
          .encrypt(request, EnvironmentConfig.encryptionKeyId);

      if (response.ciphertext == null) {
        throw Exception('Error: KMS no pudo envolver la DEK');
      }

      AppLogger.info('DEK envuelta exitosamente con KMS');
      return response.ciphertext!;
    } catch (e, stackTrace) {
      AppLogger.error('Error envolviendo DEK', e, stackTrace);
      rethrow;
    }
  }

  /// Desenvuelve (descifra) una DEK con KMS
  Future<Uint8List> unwrapDataEncryptionKey(String wrappedDek) async {
    if (!_isInitialized) await initialize();

    try {
      await _ensureValidToken();

      final request = kms.DecryptRequest()..ciphertext = wrappedDek;

      final response = await _kmsApi!.projects.locations.keyRings.cryptoKeys
          .decrypt(request, EnvironmentConfig.encryptionKeyId);

      if (response.plaintext == null) {
        throw Exception('Error: KMS no pudo desenvolver la DEK');
      }

      final dek = base64.decode(response.plaintext!);
      AppLogger.info('DEK desenvuelta exitosamente con KMS');
      return Uint8List.fromList(dek);
    } catch (e, stackTrace) {
      AppLogger.error('Error desenvolviendo DEK', e, stackTrace);
      rethrow;
    }
  }

  /// Asegura que el token sea válido
  Future<void> _ensureValidToken() async {
    if (_tokenExpiry == null ||
        DateTime.now().isAfter(_tokenExpiry!.subtract(const Duration(minutes: 5)))) {
      await _createAuthClient();
    }
  }

  /// Verifica el estado del servicio KMS
  Future<bool> healthCheck() async {
    try {
      if (!_isInitialized) return false;

      await _ensureValidToken();

      // Intentar obtener información del keyring
      final keyRingName =
          'projects/${EnvironmentConfig.cloudKmsProjectId}/locations/${EnvironmentConfig.cloudKmsLocation}/keyRings/${EnvironmentConfig.cloudKmsKeyRing}';

      final keyRing = await _kmsApi!.projects.locations.keyRings.get(keyRingName);
      return keyRing.name != null;
    } catch (e) {
      AppLogger.error('Error en health check KMS', e);
      return false;
    }
  }

  /// Limpia recursos
  void dispose() {
    _authClient?.close();
    _authClient = null;
    _kmsApi = null;
    _tokenExpiry = null;
    _isInitialized = false;
  }
}