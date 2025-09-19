#!/bin/bash

echo "🧹 INICIANDO LIMPIEZA EXHAUSTIVA DE CÓDIGO NO UTILIZADO"
echo "======================================================"

# Verificar que estamos en el directorio correcto
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: Debe ejecutar este script desde el directorio app/"
    exit 1
fi

# Fase 1: Eliminar servicios completamente no utilizados
echo ""
echo "📁 FASE 1: Eliminando servicios huérfanos..."
SERVICES_TO_DELETE=(
    "lib/services/firebase_email_service.dart"
    "lib/services/cloud_storage_service.dart"
    "lib/services/firebase_crashlytics_service.dart"
    "lib/services/device_security_service.dart"
    "lib/services/firebase_performance_service.dart"
    "lib/services/audit_log_service.dart"
    "lib/services/security_monitor_service.dart"
    "lib/services/admin_analytics_service.dart"
    "lib/services/advanced_analytics_service.dart"
    "lib/services/cloud_functions_service.dart"
    "lib/services/crashlytics_service.dart"
    "lib/services/document_verification_service.dart"
    "lib/services/e2e_encryption_service.dart"
    "lib/services/firebase_analytics_service.dart"
    "lib/services/firestore_database_service.dart"
    "lib/services/geofencing_service.dart"
    "lib/services/mercadopago_service.dart"
    "lib/services/api_quota_manager_service.dart"
    "lib/services/chat_storage_service.dart"
    "lib/services/preference_service.dart"
)

DELETED_COUNT=0
for service in "${SERVICES_TO_DELETE[@]}"; do
    if [ -f "$service" ]; then
        rm "$service"
        echo "   ✅ Eliminado: $service"
        ((DELETED_COUNT++))
    else
        echo "   ⚠️  No encontrado: $service"
    fi
done

echo "   📊 Total eliminados: $DELETED_COUNT servicios"

# Fase 2: Corregir imports no utilizados
echo ""
echo "🔧 FASE 2: Corrigiendo imports no utilizados..."

# profile_screen.dart - eliminar dart:io
if [ -f "lib/screens/passenger/profile_screen.dart" ]; then
    sed -i "/import 'dart:io';/d" lib/screens/passenger/profile_screen.dart
    echo "   ✅ Eliminado import dart:io de profile_screen.dart"
fi

# advanced_maps_service.dart - eliminar dart:async
if [ -f "lib/services/advanced_maps_service.dart" ]; then
    sed -i "/import 'dart:async';/d" lib/services/advanced_maps_service.dart
    echo "   ✅ Eliminado import dart:async de advanced_maps_service.dart"
fi

# Fase 3: Verificar resultado
echo ""
echo "🔍 FASE 3: Verificando limpieza..."
echo "   📋 Conteo de archivos en lib/services/:"
SERVICE_COUNT=$(ls lib/services/*.dart 2>/dev/null | wc -l)
echo "   📊 Servicios restantes: $SERVICE_COUNT"

echo ""
echo "✅ LIMPIEZA COMPLETADA"
echo "======================================================"
echo "📊 RESUMEN:"
echo "   🗑️  Archivos eliminados: $DELETED_COUNT"
echo "   🔧 Imports corregidos: 2"
echo "   📁 Servicios restantes: $SERVICE_COUNT"
echo ""
echo "🚀 PRÓXIMOS PASOS:"
echo "   1. Ejecutar: flutter analyze"
echo "   2. Verificar: 0 advertencias"
echo "   3. Probar: flutter run"
echo ""