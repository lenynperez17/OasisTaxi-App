#!/bin/bash

echo "================================================"
echo "🔍 SMOKE TEST - VALIDACIÓN DE CONFIGURACIÓN"
echo "================================================"

cd "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppOasisTaxi2/app"

# Check .env exists
if [ ! -f ".env" ]; then
  echo "❌ ERROR: .env file not found"
  exit 1
fi
echo "✅ Archivo .env encontrado"

# Check for placeholders
echo -e "\n🔍 Verificando placeholders..."
if grep -q "CHANGE_ME_IN_PROD" .env; then
  echo "❌ ERROR: Se encontraron placeholders CHANGE_ME_IN_PROD"
  grep "CHANGE_ME_IN_PROD" .env | head -5
  exit 1
fi
echo "✅ No hay placeholders CHANGE_ME_IN_PROD"

# Check critical variables
echo -e "\n🔐 Validando variables críticas..."
CRITICAL_VARS=(
  "FIREBASE_PROJECT_ID"
  "FIREBASE_API_KEY"
  "GOOGLE_MAPS_API_KEY"
  "ENCRYPTION_KEY_ID"
  "JWT_SECRET"
  "FIREBASE_APP_CHECK_SITE_KEY"
  "MERCADOPAGO_PUBLIC_KEY"
)

ERRORS=0
for VAR in "${CRITICAL_VARS[@]}"; do
  if grep -q "^$VAR=" .env; then
    VALUE=$(grep "^$VAR=" .env | cut -d'=' -f2-)
    if [ -z "$VALUE" ]; then
      echo "❌ $VAR: VACÍO"
      ERRORS=$((ERRORS + 1))
    else
      echo "✅ $VAR: Configurado"
    fi
  else
    echo "❌ $VAR: NO ENCONTRADO"
    ERRORS=$((ERRORS + 1))
  fi
done

# Check ENCRYPTION_KEY_ID format
echo -e "\n🔑 Validando formato ENCRYPTION_KEY_ID..."
ENCRYPTION_KEY=$(grep "^ENCRYPTION_KEY_ID=" .env | cut -d'=' -f2-)
if [[ "$ENCRYPTION_KEY" =~ ^projects/[^/]+/locations/[^/]+/keyRings/[^/]+/cryptoKeys/[^/]+$ ]]; then
  echo "✅ ENCRYPTION_KEY_ID tiene formato válido"
else
  echo "❌ ENCRYPTION_KEY_ID formato inválido"
  ERRORS=$((ERRORS + 1))
fi

# Check FIREBASE_PRIVATE_KEY
echo -e "\n🔐 Validando FIREBASE_PRIVATE_KEY..."
if grep -q "FIREBASE_PRIVATE_KEY.*BEGIN PRIVATE KEY" .env; then
  echo "✅ FIREBASE_PRIVATE_KEY contiene clave privada válida"
else
  echo "❌ FIREBASE_PRIVATE_KEY no parece válida"
  ERRORS=$((ERRORS + 1))
fi

# Display non-sensitive config
echo -e "\n📊 Configuración no sensible:"
echo "- ENVIRONMENT: $(grep '^ENVIRONMENT=' .env | cut -d'=' -f2)"
echo "- APP_NAME: $(grep '^APP_NAME=' .env | cut -d'=' -f2)"
echo "- APP_VERSION: $(grep '^APP_VERSION=' .env | cut -d'=' -f2)"
echo "- FIREBASE_PROJECT_ID: $(grep '^FIREBASE_PROJECT_ID=' .env | cut -d'=' -f2)"

echo -e "\n================================================"
if [ $ERRORS -eq 0 ]; then
  echo "✅ SMOKE TEST EXITOSO"
  echo "La configuración está lista para producción"
  echo "EnvironmentConfig.validateCriticalVariables() debería retornar true"
  exit 0
else
  echo "❌ SMOKE TEST FALLIDO"
  echo "Se encontraron $ERRORS errores"
  exit 1
fi