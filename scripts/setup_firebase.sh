#!/bin/bash

# 🚖 OASIS TAXI PERÚ - Script de Configuración Firebase REAL
# Este script configura Firebase completamente para el proyecto

set -e  # Salir si cualquier comando falla

echo "🚖 Configurando Firebase REAL para OASIS TAXI PERÚ"
echo "=================================================="

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Verificar dependencias
check_dependencies() {
    echo -e "${BLUE}📋 Verificando dependencias...${NC}"
    
    # Verificar Node.js
    if ! command -v node &> /dev/null; then
        echo -e "${RED}❌ Node.js no está instalado${NC}"
        exit 1
    fi
    
    # Verificar Firebase CLI
    if ! command -v firebase &> /dev/null; then
        echo -e "${YELLOW}⚠️  Firebase CLI no está instalado. Instalando...${NC}"
        npm install -g firebase-tools
    fi
    
    # Verificar Flutter
    if ! command -v flutter &> /dev/null; then
        echo -e "${RED}❌ Flutter no está instalado${NC}"
        exit 1
    fi
    
    # Verificar FlutterFire CLI
    if ! command -v flutterfire &> /dev/null; then
        echo -e "${YELLOW}⚠️  FlutterFire CLI no está instalado. Instalando...${NC}"
        dart pub global activate flutterfire_cli
    fi
    
    echo -e "${GREEN}✅ Todas las dependencias están instaladas${NC}"
}

# Verificar archivos de configuración
check_config_files() {
    echo -e "${BLUE}📁 Verificando archivos de configuración...${NC}"
    
    # Verificar firebase_options.dart
    if [ ! -f "lib/firebase_options.dart" ]; then
        echo -e "${RED}❌ firebase_options.dart no encontrado${NC}"
        exit 1
    fi
    
    # Verificar google-services.json
    if [ ! -f "android/app/google-services.json" ]; then
        echo -e "${RED}❌ google-services.json no encontrado${NC}"
        exit 1
    fi
    
    # Verificar GoogleService-Info.plist
    if [ ! -f "ios/Runner/GoogleService-Info.plist" ]; then
        echo -e "${RED}❌ GoogleService-Info.plist no encontrado${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Archivos de configuración encontrados${NC}"
}

# Configurar Firebase project
setup_firebase_project() {
    echo -e "${BLUE}🔥 Configurando proyecto Firebase...${NC}"
    
    # Login a Firebase
    echo -e "${YELLOW}🔐 Iniciando sesión en Firebase...${NC}"
    firebase login
    
    # Inicializar Firebase en el directorio
    echo -e "${YELLOW}🚀 Inicializando Firebase en el proyecto...${NC}"
    firebase init --project=oasis-taxi-peru-prod
    
    echo -e "${GREEN}✅ Proyecto Firebase configurado${NC}"
}

# Configurar Firestore
setup_firestore() {
    echo -e "${BLUE}🗄️  Configurando Firestore...${NC}"
    
    # Desplegar reglas de Firestore
    echo -e "${YELLOW}📋 Desplegando reglas de Firestore...${NC}"
    firebase deploy --only firestore:rules --project=oasis-taxi-peru-prod
    
    echo -e "${GREEN}✅ Firestore configurado${NC}"
}

# Configurar Storage
setup_storage() {
    echo -e "${BLUE}📦 Configurando Firebase Storage...${NC}"
    
    # Desplegar reglas de Storage
    echo -e "${YELLOW}📋 Desplegando reglas de Storage...${NC}"
    firebase deploy --only storage --project=oasis-taxi-peru-prod
    
    echo -e "${GREEN}✅ Storage configurado${NC}"
}

# Configurar Functions (si existen)
setup_functions() {
    if [ -d "functions" ]; then
        echo -e "${BLUE}⚡ Configurando Cloud Functions...${NC}"
        
        cd functions
        npm install
        cd ..
        
        # Desplegar functions
        echo -e "${YELLOW}🚀 Desplegando Cloud Functions...${NC}"
        firebase deploy --only functions --project=oasis-taxi-peru-prod
        
        echo -e "${GREEN}✅ Cloud Functions configuradas${NC}"
    else
        echo -e "${YELLOW}⚠️  No se encontraron Cloud Functions${NC}"
    fi
}

# Verificar configuración de Flutter
verify_flutter_config() {
    echo -e "${BLUE}📱 Verificando configuración de Flutter...${NC}"
    
    # Limpiar proyecto Flutter
    flutter clean
    
    # Obtener dependencias
    flutter pub get
    
    # Ejecutar build runner si existe
    if grep -q "build_runner" pubspec.yaml; then
        flutter packages pub run build_runner build
    fi
    
    echo -e "${GREEN}✅ Configuración de Flutter verificada${NC}"
}

# Configurar variables de entorno
setup_environment() {
    echo -e "${BLUE}🌍 Configurando variables de entorno...${NC}"
    
    # Verificar si existe .env
    if [ ! -f ".env" ]; then
        echo -e "${YELLOW}⚠️  Archivo .env no encontrado, copiando desde .env.example${NC}"
        if [ -f ".env.example" ]; then
            cp .env.example .env
        else
            echo -e "${RED}❌ .env.example tampoco existe${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}✅ Variables de entorno configuradas${NC}"
}

# Prueba de conexión
test_firebase_connection() {
    echo -e "${BLUE}🧪 Probando conexión con Firebase...${NC}"
    
    # Compilar para web y probar
    echo -e "${YELLOW}🌐 Compilando para web...${NC}"
    flutter build web
    
    # Servir localmente
    echo -e "${YELLOW}🚀 Iniciando servidor local...${NC}"
    firebase serve --project=oasis-taxi-peru-prod &
    SERVE_PID=$!
    
    sleep 5
    
    # Verificar que esté funcionando
    if curl -f http://localhost:5000 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Servidor local funcionando correctamente${NC}"
    else
        echo -e "${RED}❌ Error al iniciar servidor local${NC}"
    fi
    
    # Matar el servidor
    kill $SERVE_PID
}

# Función principal
main() {
    echo -e "${GREEN}🚖 Iniciando configuración Firebase para OASIS TAXI PERÚ${NC}"
    echo ""
    
    # Cambiar al directorio de la app si no estamos ahí
    if [ ! -f "pubspec.yaml" ]; then
        if [ -d "app" ]; then
            cd app
        else
            echo -e "${RED}❌ No se encontró el directorio de la app Flutter${NC}"
            exit 1
        fi
    fi
    
    check_dependencies
    check_config_files
    setup_firebase_project
    setup_firestore
    setup_storage
    setup_functions
    verify_flutter_config
    setup_environment
    test_firebase_connection
    
    echo ""
    echo -e "${GREEN}🎉 ¡Configuración completada exitosamente!${NC}"
    echo ""
    echo -e "${BLUE}📋 Próximos pasos:${NC}"
    echo -e "1. Reemplaza los API keys en .env con valores reales de Firebase Console"
    echo -e "2. Configura métodos de autenticación en Firebase Console"
    echo -e "3. Configura Google Maps API keys"
    echo -e "4. Prueba la app con: flutter run"
    echo -e "5. Despliega a producción con: firebase deploy"
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANTE: Mantén seguros todos los API keys${NC}"
}

# Ejecutar función principal
main "$@"