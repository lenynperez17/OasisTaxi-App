// ignore_for_file: prefer_interpolation_to_compose_strings
// Script para migrar automáticamente pantallas al patrón Provider
// Este script identifica las pantallas que necesitan migración y las actualiza

import 'dart:io';

void main() async {
  print('🚀 Iniciando migración masiva a Provider pattern...\n');
  
  // Lista de pantallas a migrar con sus providers necesarios
  final screensToMigrate = {
    // Pantallas de Admin
    'screens/admin/drivers_management_screen.dart': ['AdminProvider', 'AuthProvider'],
    'screens/admin/users_management_screen.dart': ['AdminProvider', 'AuthProvider'],
    'screens/admin/admin_dashboard_screen.dart': ['AdminProvider', 'AuthProvider', 'RideProvider'],
    'screens/admin/admin_login_screen.dart': ['AuthProvider', 'AdminProvider'],
    'screens/admin/analytics_screen.dart': ['AdminProvider', 'RideProvider'],
    'screens/admin/financial_screen.dart': ['AdminProvider', 'PaymentProvider'],
    'screens/admin/settings_admin_screen.dart': ['AdminProvider', 'PreferencesProvider'],
    
    // Pantallas Compartidas
    'screens/shared/chat_screen.dart': ['ChatProvider', 'AuthProvider'],
    'screens/shared/live_tracking_map_screen.dart': ['LocationProvider', 'RideProvider'],
    'screens/shared/map_picker_screen.dart': ['LocationProvider'],
    'screens/shared/notifications_screen.dart': ['NotificationProvider', 'AuthProvider'],
    'screens/shared/settings_screen.dart': ['PreferencesProvider', 'AuthProvider'],
    'screens/shared/trip_tracking_screen.dart': ['RideProvider', 'LocationProvider'],
    
    // Pantallas de Conductor restantes
    'screens/driver/communication_screen.dart': ['ChatProvider', 'AuthProvider'],
    'screens/driver/documents_screen.dart': ['DocumentProvider', 'AuthProvider'],
    'screens/driver/driver_profile_screen.dart': ['AuthProvider', 'DocumentProvider'],
    'screens/driver/driver_verification_screen.dart': ['DocumentProvider', 'AuthProvider'],
    'screens/driver/earnings_details_screen.dart': ['WalletProvider', 'AuthProvider'],
    'screens/driver/earnings_withdrawal_screen.dart': ['WalletProvider', 'PaymentProvider', 'AuthProvider'],
    'screens/driver/metrics_screen.dart': ['RideProvider', 'WalletProvider', 'AuthProvider'],
    'screens/driver/navigation_screen.dart': ['LocationProvider', 'RideProvider'],
    'screens/driver/transactions_history_screen.dart': ['WalletProvider', 'AuthProvider'],
    'screens/driver/vehicle_management_screen.dart': ['DocumentProvider', 'AuthProvider'],
    
    // Pantallas de Pasajero restantes
    'screens/passenger/ratings_history_screen.dart': ['RideProvider', 'AuthProvider'],
    'screens/passenger/payment_methods_screen.dart': ['PaymentProvider', 'AuthProvider'],
    'screens/passenger/favorites_screen.dart': ['RideProvider', 'AuthProvider'],
    'screens/passenger/profile_edit_screen.dart': ['AuthProvider'],
    'screens/passenger/trip_details_screen.dart': ['RideProvider', 'AuthProvider'],
    'screens/passenger/emergency_sos_screen.dart': ['EmergencyProvider', 'LocationProvider', 'AuthProvider'],
    'screens/passenger/payment_method_selection_screen.dart': ['PaymentProvider', 'RideProvider'],
    'screens/passenger/tracking_screen.dart': ['RideProvider', 'LocationProvider'],
    'screens/passenger/profile_screen.dart': ['AuthProvider', 'PreferencesProvider'],
  };
  
  int migratedCount = 0;
  int failedCount = 0;
  
  for (var entry in screensToMigrate.entries) {
    final filePath = 'lib/${entry.key}';
    final providers = entry.value;
    
    print('📝 Migrando: $filePath');
    
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('  ⚠️  Archivo no encontrado: $filePath');
        failedCount++;
        continue;
      }
      
      var content = await file.readAsString();
      
      // Verificar si ya usa Provider
      if (content.contains('import \'package:provider/provider.dart\';')) {
        print('  ✅ Ya migrado anteriormente');
        migratedCount++;
        continue;
      }
      
      // Agregar imports de Provider
      final importSection = _generateImports(providers);
      content = content.replaceFirst(
        'import \'package:flutter/material.dart\';',
        'import \'package:flutter/material.dart\';\nimport \'package:provider/provider.dart\';\n$importSection'
      );
      
      // Reemplazar setState con notifyListeners (simplificado)
      if (content.contains('setState')) {
        print('  ⚡ Detectado uso de setState - requiere revisión manual');
      }
      
      // Agregar inicialización en initState
      if (content.contains('void initState()')) {
        content = _addProviderInitialization(content, providers);
      }
      
      // Guardar archivo modificado
      await file.writeAsString(content);
      print('  ✅ Migración completada');
      migratedCount++;
      
    } catch (e) {
      print('  ❌ Error: $e');
      failedCount++;
    }
  }
  
  print('\n' + '=' * 50);
  print('📊 RESUMEN DE MIGRACIÓN:');
  print('  ✅ Migradas exitosamente: $migratedCount');
  print('  ❌ Fallidas: $failedCount');
  print('  📁 Total procesadas: ${screensToMigrate.length}');
  print('=' * 50);
  
  if (failedCount > 0) {
    print('\n⚠️  Algunas migraciones fallaron. Revisa los archivos manualmente.');
  } else {
    print('\n🎉 ¡Migración completada exitosamente!');
  }
}

String _generateImports(List<String> providers) {
  final imports = <String>[];
  
  for (var provider in providers) {
    final providerFile = provider.replaceAll('Provider', '_provider')
        .replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m[0]!.toLowerCase()}')
        .replaceFirst('_', '')
        .toLowerCase();
    imports.add('import \'../../providers/$providerFile.dart\';');
  }
  
  return imports.join('\n');
}

String _addProviderInitialization(String content, List<String> providers) {
  final initialization = '''
    // Cargar datos iniciales con Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });''';
  
  final loadMethod = '''
  
  Future<void> _loadInitialData() async {
    ${providers.map((p) => 'final ${_getProviderVariable(p)} = Provider.of<$p>(context, listen: false);').join('\n    ')}
    
    // TODO: Implementar carga de datos específica para esta pantalla
  }''';
  
  // Insertar después de super.initState();
  content = content.replaceFirst(
    'super.initState();',
    'super.initState();\n    $initialization'
  );
  
  // Agregar método de carga antes del @override void dispose
  content = content.replaceFirst(
    '@override\n  void dispose()',
    '$loadMethod\n  \n  @override\n  void dispose()'
  );
  
  return content;
}

String _getProviderVariable(String providerName) {
  return providerName[0].toLowerCase() + providerName.substring(1);
}