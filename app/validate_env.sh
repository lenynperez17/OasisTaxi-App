#!/bin/bash

# 🔍 VALIDACIÓN DE CONFIGURACIÓN DE ENTORNO - OASISTAXI
# Este script verifica que todas las variables críticas estén configuradas

echo "================================================"
echo "🔍 VALIDACIÓN DE CONFIGURACIÓN OASISTAXI"
echo "================================================"

# Verificar que .env existe
if [ ! -f ".env" ]; then
  echo "❌ ERROR: Archivo .env no encontrado"
  exit 1
fi

echo "✅ Archivo .env encontrado"

# Verificar que no hay placeholders CHANGE_ME_IN_PROD
if grep -q "CHANGE_ME_IN_PROD" .env; then
  echo "❌ ERROR: Se encontraron placeholders CHANGE_ME_IN_PROD en .env"
  echo "Variables con placeholders:"
  grep "CHANGE_ME_IN_PROD" .env | cut -d'=' -f1
  exit 1
fi

echo "✅ No se encontraron placeholders CHANGE_ME_IN_PROD"

# Variables críticas a verificar
CRITICAL_VARS=(
  "FIREBASE_PROJECT_ID"
  "FIREBASE_API_KEY"
  "GOOGLE_MAPS_API_KEY"
  "ENCRYPTION_KEY_ID"
  "JWT_SECRET"
  "FIREBASE_SERVICE_ACCOUNT_EMAIL"
  "FIREBASE_PRIVATE_KEY"
  "FIREBASE_CLIENT_EMAIL"
  "FIREBASE_CLIENT_ID"
  "CLOUD_KMS_PROJECT_ID"
  "FIREBASE_APP_CHECK_SITE_KEY"
  "MERCADOPAGO_PUBLIC_KEY"
  "MERCADOPAGO_ACCESS_TOKEN"
  "TWILIO_ACCOUNT_SID"
  "SENDGRID_API_KEY"
)

# Cargar variables desde .env
export $(grep -v '^#' .env | xargs)

ERRORS=0

echo ""
echo "Validando variables críticas..."
echo "--------------------------------"

for VAR in "${CRITICAL_VARS[@]}"; do
  VALUE="${!VAR}"

  if [ -z "$VALUE" ]; then
    echo "❌ $VAR: FALTANTE"
    ERRORS=$((ERRORS + 1))
  elif [[ "$VALUE" == *"PLACEHOLDER"* ]] || [[ "$VALUE" == *"EXAMPLE"* ]] || [[ "$VALUE" == *"change"* ]]; then
    echo "❌ $VAR: Contiene placeholder o valor de ejemplo"
    ERRORS=$((ERRORS + 1))
  else
    # Verificación específica para ENCRYPTION_KEY_ID
    if [ "$VAR" == "ENCRYPTION_KEY_ID" ]; then
      if [[ ! "$VALUE" =~ ^projects/[^/]+/locations/[^/]+/keyRings/[^/]+/cryptoKeys/[^/]+$ ]]; then
        echo "❌ $VAR: Formato inválido (debe ser projects/PROJECT/locations/LOCATION/keyRings/KEYRING/cryptoKeys/KEY)"
        ERRORS=$((ERRORS + 1))
      else
        echo "✅ $VAR: Configurado correctamente"
      fi
    # Verificación específica para FIREBASE_PRIVATE_KEY
    elif [ "$VAR" == "FIREBASE_PRIVATE_KEY" ]; then
      if [[ ! "$VALUE" == *"-----BEGIN PRIVATE KEY-----"* ]]; then
        echo "❌ $VAR: No parece ser una clave privada válida"
        ERRORS=$((ERRORS + 1))
      else
        echo "✅ $VAR: Configurado correctamente"
      fi
    else
      echo "✅ $VAR: Configurado"
    fi
  fi
done

echo ""
echo "================================================"

if [ $ERRORS -eq 0 ]; then
  echo "✅ VALIDACIÓN EXITOSA"
  echo "Todas las variables críticas están configuradas correctamente"
  echo "La aplicación está lista para ejecutarse en producción"
  exit 0
else
  echo "❌ VALIDACIÓN FALLIDA"
  echo "Se encontraron $ERRORS errores en la configuración"
  echo "Por favor, revise y corrija las variables marcadas con ❌"
  exit 1
fi