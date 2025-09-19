import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

void main() async {
  print('================================================');
  print('🔍 SMOKE TEST - VALIDACIÓN DE CONFIGURACIÓN');
  print('================================================');

  try {
    // Step 1: Load .env file
    print('\n📁 Cargando archivo .env...');
    await dotenv.load(fileName: '.env');
    print('✅ Archivo .env cargado exitosamente');

    // Step 2: Check for placeholders
    print('\n🔍 Verificando placeholders...');
    bool hasPlaceholders = false;

    dotenv.env.forEach((key, value) {
      if (value.contains('CHANGE_ME_IN_PROD') ||
          value.contains('PLACEHOLDER') ||
          value.contains('EXAMPLE') && !key.contains('FIREBASE') && !key.contains('AWS')) {
        print('❌ Placeholder encontrado en $key');
        hasPlaceholders = true;
      }
    });

    if (!hasPlaceholders) {
      print('✅ No se encontraron placeholders');
    }

    // Step 3: Validate critical variables
    print('\n🔐 Validando variables críticas...');
    final criticalVars = [
      'FIREBASE_PROJECT_ID',
      'FIREBASE_API_KEY',
      'GOOGLE_MAPS_API_KEY',
      'ENCRYPTION_KEY_ID',
      'JWT_SECRET',
      'FIREBASE_SERVICE_ACCOUNT_EMAIL',
      'FIREBASE_PRIVATE_KEY',
      'FIREBASE_CLIENT_EMAIL',
      'FIREBASE_CLIENT_ID',
      'CLOUD_KMS_PROJECT_ID',
      'FIREBASE_APP_CHECK_SITE_KEY',
      'MERCADOPAGO_PUBLIC_KEY',
      'MERCADOPAGO_ACCESS_TOKEN',
      'TWILIO_ACCOUNT_SID',
      'SENDGRID_API_KEY'
    ];

    bool allValid = true;
    for (final varName in criticalVars) {
      final value = dotenv.env[varName];
      if (value == null || value.isEmpty) {
        print('❌ $varName: FALTANTE');
        allValid = false;
      } else {
        // Validate specific formats
        if (varName == 'ENCRYPTION_KEY_ID') {
          final pattern = RegExp(r'^projects/[^/]+/locations/[^/]+/keyRings/[^/]+/cryptoKeys/[^/]+$');
          if (pattern.hasMatch(value)) {
            print('✅ $varName: Formato válido');
          } else {
            print('❌ $varName: Formato inválido');
            allValid = false;
          }
        } else if (varName == 'FIREBASE_PRIVATE_KEY') {
          if (value.contains('-----BEGIN PRIVATE KEY-----')) {
            print('✅ $varName: Clave privada válida');
          } else {
            print('❌ $varName: No es una clave privada válida');
            allValid = false;
          }
        } else {
          print('✅ $varName: Configurado');
        }
      }
    }

    // Step 4: Log non-sensitive configuration
    print('\n📊 Configuración no sensible:');
    print('- ENVIRONMENT: ${dotenv.env['ENVIRONMENT']}');
    print('- APP_NAME: ${dotenv.env['APP_NAME']}');
    print('- APP_VERSION: ${dotenv.env['APP_VERSION']}');
    print('- COMPANY_NAME: ${dotenv.env['COMPANY_NAME']}');
    print('- FIREBASE_PROJECT_ID: ${dotenv.env['FIREBASE_PROJECT_ID']}');
    print('- CLOUD_KMS_PROJECT_ID: ${dotenv.env['CLOUD_KMS_PROJECT_ID']}');

    // Final result
    print('\n================================================');
    if (allValid && !hasPlaceholders) {
      print('✅ SMOKE TEST EXITOSO');
      print('La configuración de entorno está lista para producción');
      exit(0);
    } else {
      print('❌ SMOKE TEST FALLIDO');
      print('Corrija los errores antes de continuar');
      exit(1);
    }

  } catch (e) {
    print('❌ ERROR CRÍTICO: $e');
    exit(1);
  }
}