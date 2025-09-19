#!/bin/bash

# 🔑 SCRIPT PARA GENERAR SHA CERTIFICATES - OASIS TAXI
# Necesario para Firebase Phone Authentication en Android

echo "================================================"
echo "🔑 GENERADOR DE SHA CERTIFICATES - OASIS TAXI"
echo "================================================"
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para generar SHA de debug
generate_debug_sha() {
    echo -e "${YELLOW}📱 Generando SHA para DEBUG keystore...${NC}"
    echo ""
    
    # Verificar si existe debug.keystore
    if [ -f "$HOME/.android/debug.keystore" ]; then
        echo "Usando debug.keystore en: $HOME/.android/debug.keystore"
        echo ""
        
        keytool -list -v \
            -alias androiddebugkey \
            -keystore "$HOME/.android/debug.keystore" \
            -storepass android \
            -keypass android 2>/dev/null | grep -E "SHA1:|SHA256:"
        
        echo ""
        echo -e "${GREEN}✅ SHA certificates para DEBUG generados${NC}"
    else
        echo -e "${RED}❌ No se encontró debug.keystore${NC}"
        echo "Ejecuta 'flutter run' una vez para generarlo"
    fi
}

# Función para generar SHA de release
generate_release_sha() {
    echo ""
    echo -e "${YELLOW}🚀 Generando SHA para RELEASE keystore...${NC}"
    echo ""
    
    KEYSTORE_PATH="app/android/oasistaxiapp-release.keystore"
    
    if [ -f "$KEYSTORE_PATH" ]; then
        echo "Usando keystore en: $KEYSTORE_PATH"
        echo ""
        echo "Ingresa la contraseña del keystore (no se mostrará):"
        
        keytool -list -v \
            -alias oasistaxiapp \
            -keystore "$KEYSTORE_PATH" 2>/dev/null | grep -E "SHA1:|SHA256:"
        
        echo ""
        echo -e "${GREEN}✅ SHA certificates para RELEASE generados${NC}"
    else
        echo -e "${RED}❌ No se encontró release keystore en $KEYSTORE_PATH${NC}"
        echo "Primero debes crear un keystore de producción"
    fi
}

# Función para generar SHA usando Gradle
generate_gradle_sha() {
    echo ""
    echo -e "${YELLOW}🔧 Generando SHA usando Gradle...${NC}"
    echo ""
    
    if [ -d "app/android" ]; then
        cd app/android
        ./gradlew signingReport 2>/dev/null | grep -E "SHA1:|SHA256:|Variant:"
        cd ../..
        echo ""
        echo -e "${GREEN}✅ SHA certificates generados con Gradle${NC}"
    else
        echo -e "${RED}❌ No se encontró directorio android${NC}"
    fi
}

# Menú principal
echo "Selecciona una opción:"
echo "1) Generar SHA para Debug (desarrollo)"
echo "2) Generar SHA para Release (producción)"
echo "3) Generar usando Gradle (todos)"
echo "4) Generar todos los SHA"
echo ""
read -p "Opción: " option

case $option in
    1)
        generate_debug_sha
        ;;
    2)
        generate_release_sha
        ;;
    3)
        generate_gradle_sha
        ;;
    4)
        generate_debug_sha
        generate_release_sha
        generate_gradle_sha
        ;;
    *)
        echo -e "${RED}Opción inválida${NC}"
        exit 1
        ;;
esac

echo ""
echo "================================================"
echo "📋 PRÓXIMOS PASOS:"
echo "================================================"
echo ""
echo "1. Copia los valores SHA1 y SHA256 generados"
echo ""
echo "2. Ve a Firebase Console:"
echo "   https://console.firebase.google.com/project/oasis-taxi-peru"
echo ""
echo "3. Selecciona la app Android (com.oasistaxis.app)"
echo ""
echo "4. En Configuración → General → Huella digital SHA"
echo ""
echo "5. Agrega AMBOS valores:"
echo "   - SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX"
echo "   - SHA256: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX"
echo ""
echo "6. Descarga el nuevo google-services.json"
echo ""
echo "7. Reemplaza en: app/android/app/google-services.json"
echo ""
echo -e "${GREEN}¡Phone Authentication estará listo! 📱${NC}"
echo ""