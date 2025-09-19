#!/bin/bash
# 🚖 OASIS TAXI PERÚ - Docker Entry Point Script
# Script de entrada para builds automatizados en container

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚖 OASIS TAXI PERÚ - Docker Build Environment${NC}"
echo "=============================================="

# Función para logging
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Verificar que estamos en el directorio correcto
if [ ! -f "pubspec.yaml" ]; then
    log_error "No se encontró pubspec.yaml. Asegúrate de montar el código en /workspace/oasistaxi"
    exit 1
fi

# Configurar Git (necesario para algunos packages)
if [ ! -z "$GIT_USER_NAME" ] && [ ! -z "$GIT_USER_EMAIL" ]; then
    git config --global user.name "$GIT_USER_NAME"
    git config --global user.email "$GIT_USER_EMAIL"
    log_info "Git configurado con $GIT_USER_NAME <$GIT_USER_EMAIL>"
fi

# Configurar Flutter
log_info "Configurando Flutter para OasisTaxi..."
flutter config --no-analytics
flutter config --android-sdk $ANDROID_HOME

# Obtener dependencias
log_info "Obteniendo dependencias de Flutter..."
flutter pub get

# Si no se pasan argumentos, ejecutar flutter doctor
if [ $# -eq 0 ]; then
    log_info "Ejecutando Flutter Doctor..."
    flutter doctor -v
    exit 0
fi

# Procesar comandos especiales
case "$1" in
    "build-android")
        log_info "🤖 Building Android APK para OasisTaxi..."
        flutter build apk --release \
            --target lib/main.dart \
            --split-per-abi \
            --obfuscate \
            --split-debug-info=build/app/outputs/symbols
        log_success "Android APK build completado"
        ;;
    
    "build-android-bundle")
        log_info "📦 Building Android App Bundle para OasisTaxi..."
        flutter build appbundle --release \
            --target lib/main.dart \
            --obfuscate \
            --split-debug-info=build/app/outputs/symbols
        log_success "Android App Bundle build completado"
        ;;
    
    "build-web")
        log_info "🌐 Building Web App para OasisTaxi..."
        flutter build web --release \
            --target lib/main.dart \
            --web-renderer html \
            --base-href "/"
        log_success "Web build completado"
        ;;
    
    "test")
        log_info "🧪 Ejecutando tests de OasisTaxi..."
        flutter test --coverage --reporter=json
        log_success "Tests completados"
        ;;
    
    "analyze")
        log_info "🔍 Analizando código de OasisTaxi..."
        flutter analyze --no-pub
        dart format --output=none --set-exit-if-changed .
        log_success "Análisis de código completado"
        ;;
    
    "clean")
        log_info "🧹 Limpiando proyecto..."
        flutter clean
        flutter pub get
        log_success "Proyecto limpiado"
        ;;
    
    "doctor")
        log_info "🏥 Ejecutando Flutter Doctor..."
        flutter doctor -v
        ;;
    
    "full-build")
        log_info "🚀 Build completo de OasisTaxi..."
        
        # Análisis
        log_info "Paso 1/5: Análisis de código..."
        flutter analyze --no-pub
        
        # Tests
        log_info "Paso 2/5: Ejecutando tests..."
        flutter test --coverage
        
        # Build Android
        log_info "Paso 3/5: Build Android..."
        flutter build apk --release --target lib/main.dart --split-per-abi
        flutter build appbundle --release --target lib/main.dart
        
        # Build Web
        log_info "Paso 4/5: Build Web..."
        flutter build web --release --target lib/main.dart
        
        # Resumen
        log_info "Paso 5/5: Generando resumen..."
        echo "📊 Build Summary:"
        echo "- APKs: $(find build/app/outputs/flutter-apk -name "*.apk" | wc -l)"
        echo "- AAB: $(find build/app/outputs/bundle -name "*.aab" | wc -l)"
        echo "- Web: $([ -d "build/web" ] && echo "✅" || echo "❌")"
        
        log_success "Build completo finalizado"
        ;;
    
    *)
        # Ejecutar comando pasado
        log_info "Ejecutando: $@"
        exec "$@"
        ;;
esac