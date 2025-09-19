#!/bin/bash
# 🚖 OASIS TAXI PERÚ - Script de configuración CI/CD
# Configura automáticamente Google Cloud Build, triggers y secretos

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables del proyecto
PROJECT_ID="oasis-taxi-peru-prod"
REGION="us-central1"
GITHUB_OWNER="tu-organizacion"  # Cambiar por el owner real
GITHUB_REPO="oasistaxi-peru"    # Cambiar por el repo real

echo -e "${BLUE}🚖 CONFIGURANDO CI/CD PARA OASIS TAXI PERÚ${NC}"
echo "======================================================"

# Verificar que gcloud está instalado y autenticado
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ gcloud CLI no está instalado${NC}"
    exit 1
fi

# Configurar proyecto
echo -e "${YELLOW}🔧 Configurando proyecto GCP...${NC}"
gcloud config set project $PROJECT_ID

# Habilitar APIs necesarias
echo -e "${YELLOW}📡 Habilitando APIs de GCP...${NC}"
gcloud services enable cloudbuild.googleapis.com
gcloud services enable secretmanager.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable firebase.googleapis.com
gcloud services enable run.googleapis.com

# Crear service account para Cloud Build
echo -e "${YELLOW}👤 Configurando service accounts...${NC}"
SA_NAME="oasistaxi-cloudbuild"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud iam service-accounts create $SA_NAME \
    --display-name="OasisTaxi Cloud Build Service Account" \
    --description="Service account para CI/CD de OasisTaxi" || true

# Asignar permisos al service account
echo -e "${YELLOW}🔐 Asignando permisos...${NC}"
ROLES=(
    "roles/cloudbuild.builds.builder"
    "roles/storage.admin"
    "roles/secretmanager.secretAccessor"
    "roles/firebase.admin"
    "roles/run.admin"
    "roles/logging.logWriter"
)

for role in "${ROLES[@]}"; do
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:${SA_EMAIL}" \
        --role="$role"
done

# Crear buckets de Storage
echo -e "${YELLOW}🪣 Creando buckets de Cloud Storage...${NC}"
gsutil mb -p $PROJECT_ID gs://${PROJECT_ID}-artifacts || echo "Bucket artifacts ya existe"
gsutil mb -p $PROJECT_ID gs://${PROJECT_ID}-builds || echo "Bucket builds ya existe"

# Configurar secretos en Secret Manager
echo -e "${YELLOW}🔒 Configurando Secret Manager...${NC}"

# Crear secretos vacíos (deben ser llenados manualmente)
SECRETS=(
    "oasistaxi-env-vars"
    "firebase-service-account"
    "android-keystore"
    "android-key-properties"
    "google-services-android"
    "google-services-ios"
    "slack-webhook"
)

for secret in "${SECRETS[@]}"; do
    echo "Placeholder for $secret" | gcloud secrets create $secret \
        --data-file=- \
        --replication-policy="automatic" || echo "Secret $secret ya existe"
done

# Conectar repositorio GitHub
echo -e "${YELLOW}🔗 Configurando conexión con GitHub...${NC}"
echo "IMPORTANTE: Debes conectar manualmente el repositorio GitHub en:"
echo "https://console.cloud.google.com/cloud-build/repos?project=$PROJECT_ID"

# Crear triggers de Cloud Build
echo -e "${YELLOW}⚡ Creando triggers de Cloud Build...${NC}"

# Trigger para desarrollo (branch develop)
gcloud builds triggers create github \
    --repo-name=$GITHUB_REPO \
    --repo-owner=$GITHUB_OWNER \
    --branch-pattern="^develop$" \
    --build-config=cloudbuild.yaml \
    --description="OasisTaxi Development Build" \
    --service-account="projects/$PROJECT_ID/serviceAccounts/$SA_EMAIL" \
    --substitutions="_ENVIRONMENT=dev,_DEPLOYMENT_TARGET=android" || echo "Trigger develop ya existe"

# Trigger para producción (branch main)
gcloud builds triggers create github \
    --repo-name=$GITHUB_REPO \
    --repo-owner=$GITHUB_OWNER \
    --branch-pattern="^main$" \
    --build-config=cloudbuild.yaml \
    --description="OasisTaxi Production Build" \
    --service-account="projects/$PROJECT_ID/serviceAccounts/$SA_EMAIL" \
    --substitutions="_ENVIRONMENT=prod,_DEPLOYMENT_TARGET=all" || echo "Trigger main ya existe"

# Trigger para Pull Requests
gcloud builds triggers create github \
    --repo-name=$GITHUB_REPO \
    --repo-owner=$GITHUB_OWNER \
    --pull-request-pattern=".*" \
    --build-config=cloudbuild-pr.yaml \
    --description="OasisTaxi PR Validation" \
    --service-account="projects/$PROJECT_ID/serviceAccounts/$SA_EMAIL" || echo "Trigger PR ya existe"

# Configurar notificaciones
echo -e "${YELLOW}📢 Configurando notificaciones...${NC}"
gcloud pubsub topics create cloud-builds || echo "Topic cloud-builds ya existe"

# Crear función para notificaciones
cat > /tmp/notification-function.js << 'EOF'
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.sendBuildNotification = functions.https.onCall(async (data, context) => {
    const { buildId, status, project } = data;
    
    // Enviar notificación FCM a administradores
    const message = {
        notification: {
            title: `🚖 OasisTaxi Build ${status}`,
            body: `Build ${buildId} completado: ${status}`
        },
        topic: 'admin-notifications'
    };
    
    await admin.messaging().send(message);
    return { success: true };
});
EOF

echo "Función de notificaciones creada en /tmp/notification-function.js"

echo -e "${GREEN}✅ CONFIGURACIÓN CI/CD COMPLETADA${NC}"
echo "======================================================"
echo -e "${BLUE}📋 PRÓXIMOS PASOS MANUALES:${NC}"
echo ""
echo "1. 🔗 Conectar repositorio GitHub:"
echo "   https://console.cloud.google.com/cloud-build/repos?project=$PROJECT_ID"
echo ""
echo "2. 🔒 Configurar secretos en Secret Manager:"
echo "   - oasistaxi-env-vars: Variables de entorno (.env)"
echo "   - firebase-service-account: Service account JSON"
echo "   - android-keystore: Keystore para signing"
echo "   - android-key-properties: Propiedades del keystore"
echo "   - google-services-android: google-services.json"
echo "   - google-services-ios: GoogleService-Info.plist"
echo ""
echo "3. 🧪 Probar triggers:"
echo "   gcloud builds triggers run oasistaxi-development --branch=develop"
echo ""
echo "4. 📊 Monitor builds:"
echo "   https://console.cloud.google.com/cloud-build/builds?project=$PROJECT_ID"
echo ""
echo -e "${GREEN}🚀 CI/CD listo para OasisTaxi Perú!${NC}"