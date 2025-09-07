#!/bin/bash

# Corregir campos final que no deberían serlo en los providers
echo "Corrigiendo campos final en providers..."

# Lista de archivos de providers
providers=(
  "lib/providers/wallet_provider.dart"
  "lib/providers/vehicle_provider.dart"
  "lib/providers/preferences_provider.dart"
  "lib/providers/payment_provider.dart"
  "lib/providers/emergency_provider.dart"
  "lib/providers/document_provider.dart"
  "lib/providers/chat_provider.dart"
  "lib/providers/admin_provider.dart"
)

for file in "${providers[@]}"; do
  if [ -f "$file" ]; then
    echo "Procesando $file..."
    
    # Cambiar final bool _isLoading a bool _isLoading
    sed -i 's/final bool _isLoading/bool _isLoading/g' "$file"
    
    # Cambiar final bool _isSaving a bool _isSaving
    sed -i 's/final bool _isSaving/bool _isSaving/g' "$file"
    
    # Cambiar final bool _isDeleting a bool _isDeleting
    sed -i 's/final bool _isDeleting/bool _isDeleting/g' "$file"
    
    # Cambiar final bool _isSendingMessage a bool _isSendingMessage
    sed -i 's/final bool _isSendingMessage/bool _isSendingMessage/g' "$file"
    
    # Cambiar final bool _isUpdating a bool _isUpdating
    sed -i 's/final bool _isUpdating/bool _isUpdating/g' "$file"
  fi
done

echo "Correcciones aplicadas en providers"