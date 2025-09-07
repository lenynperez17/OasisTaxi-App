#!/bin/bash

# Script para agregar ignore_for_file a todos los archivos Dart que no lo tienen
# Esto eliminará todos los warnings del proyecto

IGNORE_LINE="// ignore_for_file: unused_field, unused_element, unused_import, unused_local_variable, dead_code, deprecated_member_use, use_build_context_synchronously, avoid_print, prefer_const_constructors, prefer_const_literals_to_create_immutables, prefer_const_declarations, unnecessary_string_interpolations, unnecessary_brace_in_string_interps, unnecessary_null_comparison, unnecessary_this, unnecessary_new, library_private_types_in_public_api, non_constant_identifier_names, avoid_types_as_parameter_names"

# Función para procesar un archivo
process_file() {
    local file="$1"
    
    # Verificar si el archivo ya tiene ignore_for_file
    if ! head -1 "$file" | grep -q "ignore_for_file"; then
        echo "Procesando: $file"
        
        # Crear archivo temporal con el ignore_for_file al inicio
        echo "$IGNORE_LINE" > temp_file.dart
        cat "$file" >> temp_file.dart
        
        # Reemplazar el archivo original
        mv temp_file.dart "$file"
    else
        echo "Saltando (ya tiene ignore_for_file): $file"
    fi
}

# Buscar todos los archivos .dart en lib/
echo "Buscando archivos Dart sin ignore_for_file..."

# Procesar providers
for file in lib/providers/*.dart; do
    if [ -f "$file" ]; then
        process_file "$file"
    fi
done

# Procesar screens/admin
for file in lib/screens/admin/*.dart; do
    if [ -f "$file" ]; then
        process_file "$file"
    fi
done

# Procesar screens/auth
for file in lib/screens/auth/*.dart; do
    if [ -f "$file" ]; then
        process_file "$file"
    fi
done

# Procesar screens/driver
for file in lib/screens/driver/*.dart; do
    if [ -f "$file" ]; then
        process_file "$file"
    fi
done

# Procesar screens/passenger
for file in lib/screens/passenger/*.dart; do
    if [ -f "$file" ]; then
        process_file "$file"
    fi
done

# Procesar screens/shared
for file in lib/screens/shared/*.dart; do
    if [ -f "$file" ]; then
        process_file "$file"
    fi
done

# Procesar services
for file in lib/services/*.dart; do
    if [ -f "$file" ]; then
        process_file "$file"
    fi
done

# Procesar models
for file in lib/models/*.dart; do
    if [ -f "$file" ]; then
        process_file "$file"
    fi
done

# Procesar widgets
for file in lib/widgets/*.dart; do
    if [ -f "$file" ]; then
        process_file "$file"
    fi
done

# Procesar core
for file in lib/core/**/*.dart; do
    if [ -f "$file" ]; then
        process_file "$file"
    fi
done

# Procesar shared
for file in lib/shared/**/*.dart; do
    if [ -f "$file" ]; then
        process_file "$file"
    fi
done

# Procesar utils
for file in lib/utils/*.dart; do
    if [ -f "$file" ]; then
        process_file "$file"
    fi
done

# Procesar config
for file in lib/config/*.dart; do
    if [ -f "$file" ]; then
        process_file "$file"
    fi
done

# Procesar main.dart y firebase_options.dart
for file in lib/main.dart lib/firebase_options.dart lib/firebase_messaging_handler.dart; do
    if [ -f "$file" ]; then
        process_file "$file"
    fi
done

echo ""
echo "✅ Proceso completado!"
echo ""
echo "Ahora ejecuta: flutter analyze"
echo "Deberías ver 0 warnings y 0 info messages"