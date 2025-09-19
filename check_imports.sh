#!/bin/bash
# Script para encontrar unused imports comunes en Flutter

APP_DIR="/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppOasisTaxi/app"
cd "$APP_DIR"

echo "🔍 BUSCANDO UNUSED IMPORTS EN APP OASIS TAXI"
echo "=============================================="

# Contadores
unused_count=0

# Función para verificar si un import se usa
check_import_usage() {
    local file="$1"
    local import_line="$2"
    local search_patterns="$3"
    
    # Obtener el contenido sin los imports
    content=$(sed '/^import /d' "$file")
    
    # Verificar cada patrón
    for pattern in $search_patterns; do
        if echo "$content" | grep -q "\b$pattern\b"; then
            return 0  # Se usa
        fi
    done
    return 1  # No se usa
}

echo ""
echo "📋 VERIFICANDO IMPORTS ESPECÍFICOS:"
echo "-----------------------------------"

# 1. Verificar dart:math sin uso
echo "🔢 Verificando dart:math..."
for file in $(find lib -name "*.dart" -exec grep -l "import 'dart:math'" {} \;); do
    if ! check_import_usage "$file" "dart:math" "min max sqrt pow Random pi cos sin tan log"; then
        echo "❌ $file - dart:math sin usar"
        ((unused_count++))
    fi
done

# 2. Verificar package:intl sin uso
echo "🌐 Verificando package:intl..."
for file in $(find lib -name "*.dart" -exec grep -l "package:intl" {} \;); do
    if ! check_import_usage "$file" "package:intl" "DateFormat NumberFormat Intl"; then
        echo "❌ $file - package:intl sin usar"
        ((unused_count++))
    fi
done

# 3. Verificar package:collection sin uso
echo "📦 Verificando package:collection..."
for file in $(find lib -name "*.dart" -exec grep -l "package:collection" {} \;); do
    if ! check_import_usage "$file" "package:collection" "ListEquality SetEquality MapEquality"; then
        echo "❌ $file - package:collection sin usar"
        ((unused_count++))
    fi
done

# 4. Verificar modelos que no se usan
echo "🏗️ Verificando modelos sin uso..."
for file in $(find lib -name "*.dart" -exec grep -l "models/" {} \;); do
    # Extraer nombre del modelo del import
    model_imports=$(grep "models/" "$file" | sed "s/.*models\/\([^']*\)'.*/\1/" | sed 's/\.dart//' | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1))tolower(substr($i,2))}1' | sed 's/ //g')
    
    for model in $model_imports; do
        if ! check_import_usage "$file" "$model" "$model"; then
            echo "❌ $file - Modelo $model sin usar"
            ((unused_count++))
        fi
    done
done

# 5. Verificar imports de Material que podrían no usarse
echo "🎨 Verificando imports específicos de Material..."
for file in $(find lib -name "*.dart" -exec grep -l "package:flutter/cupertino" {} \;); do
    if ! check_import_usage "$file" "cupertino" "CupertinoPageRoute CupertinoButton CupertinoTextField CupertinoActivityIndicator"; then
        echo "❌ $file - package:flutter/cupertino sin usar"
        ((unused_count++))
    fi
done

# 6. Verificar dart:typed_data
echo "💾 Verificando dart:typed_data..."
for file in $(find lib -name "*.dart" -exec grep -l "dart:typed_data" {} \;); do
    if ! check_import_usage "$file" "typed_data" "Uint8List Uint16List Uint32List Int8List ByteData"; then
        echo "❌ $file - dart:typed_data sin usar"
        ((unused_count++))
    fi
done

# 7. Verificar package:path sin uso
echo "📂 Verificando package:path..."
for file in $(find lib -name "*.dart" -exec grep -l "package:path" {} \;); do
    if ! check_import_usage "$file" "package:path" "join basename dirname extension"; then
        echo "❌ $file - package:path sin usar"
        ((unused_count++))
    fi
done

echo ""
echo "🎯 RESULTADOS:"
echo "=============="
echo "Total de unused imports encontrados: $unused_count"

if [ $unused_count -eq 0 ]; then
    echo "✅ ¡No se encontraron unused imports obvios!"
else
    echo "⚠️  Se encontraron $unused_count posibles unused imports"
    echo ""
    echo "💡 Para eliminar estos imports, ejecuta los comandos correspondientes"
fi