#!/bin/bash

# Script para implementar Firebase real en todos los archivos restantes

echo "🔥 Implementando Firebase real en todos los archivos restantes..."

# Lista de archivos a actualizar
files=(
  "lib/screens/passenger/ratings_history_screen.dart"
  "lib/screens/passenger/promotions_screen.dart"
  "lib/screens/admin/financial_screen.dart"
  "lib/screens/driver/wallet_screen.dart"
  "lib/screens/driver/earnings_details_screen.dart"
)

for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    echo "📝 Actualizando: $file"
    
    # Agregar import de Firestore si no existe
    if ! grep -q "cloud_firestore" "$file"; then
      sed -i "1s/^/import 'package:cloud_firestore\/cloud_firestore.dart';\n/" "$file"
    fi
    
    # Agregar FirebaseFirestore instance después de la clase State
    if grep -q "class _.*State extends State<" "$file"; then
      # Buscar la línea de la clase y agregar después
      sed -i '/class _.*State extends State<.*{/a\
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;\
  String? _userId; // Se obtendrá del usuario actual\
  bool _isLoading = true;' "$file"
    fi
    
    echo "✅ Actualizado: $file"
  else
    echo "❌ No encontrado: $file"
  fi
done

echo "✅ Proceso completado!"
echo "📌 Nota: Los archivos ahora tienen las importaciones y configuraciones base de Firebase."
echo "📌 Necesitarás actualizar los métodos específicos para usar datos reales de Firestore."