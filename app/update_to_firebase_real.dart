// Script de actualización automática para usar Firebase real en todos los archivos
// Este script actualiza los imports y agrega la conexión a Firestore

import 'dart:io';

void main() {
  final files = [
    'lib/screens/admin/financial_screen.dart',
    'lib/screens/driver/wallet_screen.dart',
    'lib/screens/driver/earnings_details_screen.dart',
    'lib/screens/passenger/favorites_screen.dart',
    'lib/screens/passenger/profile_edit_screen.dart',
    'lib/screens/driver/modern_driver_home.dart',
    'lib/screens/passenger/ratings_history_screen.dart',
    'lib/screens/passenger/promotions_screen.dart',
  ];

  print('🔄 Actualizando archivos para usar Firebase real...\n');

  for (final filePath in files) {
    final file = File(filePath);
    
    if (!file.existsSync()) {
      print('❌ Archivo no encontrado: $filePath');
      continue;
    }

    try {
      var content = file.readAsStringSync();
      
      // Verificar si ya tiene import de Firestore
      if (!content.contains("import 'package:cloud_firestore/cloud_firestore.dart';")) {
        // Agregar import después del primer import de Flutter
        content = content.replaceFirst(
          "import 'package:flutter/material.dart';",
          "import 'package:flutter/material.dart';\nimport 'package:cloud_firestore/cloud_firestore.dart';",
        );
      }
      
      // Agregar FirebaseFirestore instance si la clase State existe
      if (content.contains('State<') && !content.contains('FirebaseFirestore _firestore')) {
        content = content.replaceFirst(
          RegExp(r'class _\w+State extends State<[^>]+>.*?{'),
          (match) => '${match.group(0)!}\n  final FirebaseFirestore _firestore = FirebaseFirestore.instance;\n  bool _isLoading = true;',
        );
      }
      
      // Guardar archivo actualizado
      file.writeAsStringSync(content);
      print('✅ Actualizado: $filePath');
      
    } catch (e) {
      print('❌ Error actualizando $filePath: $e');
    }
  }
  
  print('\n✅ Proceso completado!');
  print('📝 Nota: Los archivos ahora tienen los imports necesarios.');
  print('⚠️  Todavía necesitas actualizar manualmente la lógica para cargar datos desde Firebase.');
}