#!/bin/bash

# Script para actualizar todos los archivos a Firebase real

echo "🔄 Actualizando todos los archivos para usar Firebase real..."

# Lista de archivos a actualizar
files=(
  "lib/screens/driver/earnings_details_screen.dart"
  "lib/screens/passenger/favorites_screen.dart"
  "lib/screens/passenger/profile_edit_screen.dart"
  "lib/screens/driver/modern_driver_home.dart"
  "lib/screens/passenger/ratings_history_screen.dart"
  "lib/screens/passenger/promotions_screen.dart"
)

for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    echo "Actualizando: $file"
    
    # Agregar import de Firestore si no existe
    if ! grep -q "cloud_firestore" "$file"; then
      sed -i "s/import 'package:flutter\/material.dart';/import 'package:flutter\/material.dart';\nimport 'package:cloud_firestore\/cloud_firestore.dart';/" "$file"
    fi
    
    # Agregar FirebaseFirestore instance después de la clase State
    if grep -q "class _.*State extends State<" "$file" && ! grep -q "FirebaseFirestore _firestore" "$file"; then
      sed -i "/class _.*State extends State<.*{/a\\
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;\\
  bool _isLoading = true;" "$file"
    fi
    
    echo "✅ Actualizado: $file"
  else
    echo "❌ No encontrado: $file"
  fi
done

echo "✅ Proceso completado!"