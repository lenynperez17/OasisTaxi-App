import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Métodos simplificados
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  // Métodos adicionales para compatibilidad
  Future<void> setSecureJson(String key, Map<String, dynamic> value) async {
    await _storage.write(key: key, value: value.toString());
  }

  Future<Map<String, dynamic>?> getSecureJson(String key) async {
    final value = await _storage.read(key: key);
    return value != null ? {'data': value} : null;
  }

  Future<void> setSecureString(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> getSecureString(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> remove(String key) async {
    await _storage.delete(key: key);
  }
}
