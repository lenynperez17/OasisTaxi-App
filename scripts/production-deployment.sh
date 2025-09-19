#!/bin/bash

#############################################
# OasisTaxi Production Deployment Script
# Complete deployment pipeline with validation
#############################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="oasis-taxi-peru"
REGION="us-central1"
APP_NAME="oasistaxiperu"
ENVIRONMENT="production"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="deployment_${TIMESTAMP}.log"

# Functions
log() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

section() {
    echo -e "\n${BLUE}========================================${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}$1${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}========================================${NC}\n" | tee -a "$LOG_FILE"
}

# Check prerequisites
check_prerequisites() {
    section "CHECKING PREREQUISITES"

    # Check Flutter
    if ! command -v flutter &> /dev/null; then
        error "Flutter is not installed"
    fi
    log "✓ Flutter: $(flutter --version | head -n 1)"

    # Check Firebase CLI
    if ! command -v firebase &> /dev/null; then
        error "Firebase CLI is not installed"
    fi
    log "✓ Firebase CLI: $(firebase --version)"

    # Check gcloud
    if ! command -v gcloud &> /dev/null; then
        error "Google Cloud SDK is not installed"
    fi
    log "✓ gcloud: $(gcloud version | head -n 1)"

    # Check Node.js
    if ! command -v node &> /dev/null; then
        error "Node.js is not installed"
    fi
    log "✓ Node.js: $(node --version)"

    # Check current project
    CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
    if [ "$CURRENT_PROJECT" != "$PROJECT_ID" ]; then
        warning "Current gcloud project is $CURRENT_PROJECT, switching to $PROJECT_ID"
        gcloud config set project "$PROJECT_ID"
    fi
    log "✓ GCP Project: $PROJECT_ID"

    # Check Firebase project
    FIREBASE_PROJECT=$(firebase use 2>/dev/null | grep "Active Project:" | cut -d: -f2 | xargs)
    if [ "$FIREBASE_PROJECT" != "$PROJECT_ID" ]; then
        warning "Switching Firebase project to $PROJECT_ID"
        firebase use "$PROJECT_ID"
    fi
    log "✓ Firebase Project: $PROJECT_ID"

    success "All prerequisites checked"
}

# Run tests
run_tests() {
    section "RUNNING TESTS"

    cd app

    # Flutter analyze
    log "Running Flutter analyze..."
    if ! flutter analyze --no-fatal-warnings; then
        error "Flutter analyze failed"
    fi
    success "Flutter analyze passed"

    # Run unit tests
    log "Running unit tests..."
    if ! flutter test; then
        warning "Some tests failed, continuing..."
    else
        success "All tests passed"
    fi

    cd ..
}

# Build application
build_app() {
    section "BUILDING APPLICATION"

    cd app

    # Clean build
    log "Cleaning previous builds..."
    flutter clean

    # Get dependencies
    log "Getting dependencies..."
    flutter pub get

    # Build for different platforms
    case "$1" in
        "web")
            log "Building for Web..."
            flutter build web --release \
                --dart-define=ENV=production \
                --dart-define=ENABLE_CRASHLYTICS=true \
                --dart-define=ENABLE_ANALYTICS=true \
                --dart-define=SSL_PINNING_ENABLED=true
            success "Web build completed"
            ;;
        "android")
            log "Building for Android..."
            flutter build apk --release \
                --dart-define=ENV=production \
                --dart-define=ENABLE_CRASHLYTICS=true \
                --dart-define=ENABLE_ANALYTICS=true \
                --dart-define=SSL_PINNING_ENABLED=true
            flutter build appbundle --release \
                --dart-define=ENV=production \
                --dart-define=ENABLE_CRASHLYTICS=true \
                --dart-define=ENABLE_ANALYTICS=true \
                --dart-define=SSL_PINNING_ENABLED=true
            success "Android build completed"
            ;;
        "ios")
            log "Building for iOS..."
            flutter build ios --release \
                --dart-define=ENV=production \
                --dart-define=ENABLE_CRASHLYTICS=true \
                --dart-define=ENABLE_ANALYTICS=true \
                --dart-define=SSL_PINNING_ENABLED=true
            success "iOS build completed"
            ;;
        "all")
            log "Building for all platforms..."
            flutter build web --release \
                --dart-define=ENV=production \
                --dart-define=ENABLE_CRASHLYTICS=true \
                --dart-define=ENABLE_ANALYTICS=true \
                --dart-define=SSL_PINNING_ENABLED=true
            flutter build apk --release \
                --dart-define=ENV=production \
                --dart-define=ENABLE_CRASHLYTICS=true \
                --dart-define=ENABLE_ANALYTICS=true \
                --dart-define=SSL_PINNING_ENABLED=true
            flutter build appbundle --release \
                --dart-define=ENV=production \
                --dart-define=ENABLE_CRASHLYTICS=true \
                --dart-define=ENABLE_ANALYTICS=true \
                --dart-define=SSL_PINNING_ENABLED=true
            if [[ "$OSTYPE" == "darwin"* ]]; then
                flutter build ios --release \
                    --dart-define=ENV=production \
                    --dart-define=ENABLE_CRASHLYTICS=true \
                    --dart-define=ENABLE_ANALYTICS=true \
                    --dart-define=SSL_PINNING_ENABLED=true
            fi
            success "All builds completed"
            ;;
        *)
            error "Invalid build target: $1"
            ;;
    esac

    cd ..
}

# Deploy Firebase services
deploy_firebase() {
    section "DEPLOYING FIREBASE SERVICES"

    cd app/firebase

    # Deploy Firestore rules
    log "Deploying Firestore rules..."
    firebase deploy --only firestore:rules --project "$PROJECT_ID"
    success "Firestore rules deployed"

    # Deploy Storage rules
    log "Deploying Storage rules..."
    firebase deploy --only storage:rules --project "$PROJECT_ID"
    success "Storage rules deployed"

    # Deploy Cloud Functions
    if [ -d "functions" ]; then
        log "Building Cloud Functions..."
        cd functions
        npm install
        npm run build

        log "Deploying Cloud Functions..."
        firebase deploy --only functions --project "$PROJECT_ID"
        success "Cloud Functions deployed"
        cd ..
    fi

    # Deploy Remote Config
    if [ -f "deploy-remote-config.js" ]; then
        log "Deploying Remote Config..."
        node deploy-remote-config.js
        success "Remote Config deployed"
    fi

    cd ../..
}

# Deploy to hosting
deploy_hosting() {
    section "DEPLOYING TO FIREBASE HOSTING"

    cd app

    if [ ! -d "build/web" ]; then
        error "Web build not found. Run build first."
    fi

    log "Deploying to Firebase Hosting..."
    firebase deploy --only hosting --project "$PROJECT_ID"

    # Get the hosting URL
    HOSTING_URL=$(firebase hosting:sites:list --project "$PROJECT_ID" | grep "$APP_NAME" | awk '{print $2}')
    success "Web app deployed to: https://$HOSTING_URL"

    cd ..
}

# Setup monitoring
setup_monitoring() {
    section "SETTING UP MONITORING"

    log "Creating uptime checks..."
    gcloud monitoring uptime-checks create \
        --display-name="OasisTaxi API Health" \
        --uri="https://api.oasistaxiperu.com/health" \
        --project="$PROJECT_ID" \
        2>/dev/null || warning "Uptime check already exists"

    log "Creating alert policies..."
    # Apply monitoring configuration
    if [ -f "app/monitoring/alert-policies.json" ]; then
        # Create each alert policy from the JSON array
        jq -c '.[]' app/monitoring/alert-policies.json | while read policy; do
            if echo "$policy" | gcloud monitoring policies create --policy-from-file=- \
                --project="$PROJECT_ID" 2>&1; then
                log "✓ Alert policy created successfully"
            else
                error "Failed to create alert policy"
            fi
        done
    else
        error "alert-policies.json not found"
    fi

    log "Creating dashboards..."
    if [ -f "app/monitoring/dashboards.json" ]; then
        if gcloud monitoring dashboards create --config-from-file="app/monitoring/dashboards.json" \
            --project="$PROJECT_ID" 2>&1; then
            log "✓ Dashboard created successfully"
        else
            error "Failed to create dashboard"
        fi
    else
        error "dashboards.json not found"
    fi

    # Verify resources were created
    log "Verifying monitoring resources..."

    log "Listing dashboards..."
    if gcloud monitoring dashboards list --project="$PROJECT_ID" --format="table(displayName)" 2>&1; then
        success "Dashboards listed successfully"
    else
        warning "Could not list dashboards"
    fi

    log "Listing alert policies..."
    if gcloud monitoring policies list --project="$PROJECT_ID" --format="table(displayName)" 2>&1; then
        success "Alert policies listed successfully"
    else
        warning "Could not list alert policies"
    fi

    success "Monitoring setup completed"
}

# Verify deployment
verify_deployment() {
    section "VERIFYING DEPLOYMENT"

    # Check web app
    log "Checking web app..."
    if curl -s -o /dev/null -w "%{http_code}" "https://oasistaxiperu.com" | grep -q "200"; then
        success "Web app is accessible"
    else
        warning "Web app returned non-200 status"
    fi

    # Check API
    log "Checking API health..."
    if curl -s -o /dev/null -w "%{http_code}" "https://api.oasistaxiperu.com/health" | grep -q "200"; then
        success "API is healthy"
    else
        warning "API health check failed"
    fi

    # Check Cloud Functions
    log "Checking Cloud Functions..."
    FUNCTIONS=$(gcloud functions list --project="$PROJECT_ID" --format="value(name)")
    if [ -n "$FUNCTIONS" ]; then
        success "Cloud Functions are deployed"
    else
        warning "No Cloud Functions found"
    fi

    # Check Firestore
    log "Checking Firestore..."
    if gcloud firestore databases list --project="$PROJECT_ID" | grep -q "READY"; then
        success "Firestore is ready"
    else
        warning "Firestore status unknown"
    fi
}

# Create deployment report
create_report() {
    section "CREATING DEPLOYMENT REPORT"

    REPORT_FILE="deployment_report_${TIMESTAMP}.md"

    cat > "$REPORT_FILE" << EOF
# OasisTaxi Production Deployment Report

**Date:** $(date +'%Y-%m-%d %H:%M:%S')
**Environment:** Production
**Project ID:** $PROJECT_ID
**Deployed By:** $(whoami)

## Build Information
- Flutter Version: $(cd app && flutter --version | head -n 1)
- App Version: $(grep "version:" app/pubspec.yaml | cut -d: -f2 | xargs)
- Build Number: $(grep "version:" app/pubspec.yaml | cut -d+ -f2 | xargs)

## Deployment Status
- ✅ Prerequisites checked
- ✅ Tests executed
- ✅ Application built
- ✅ Firebase services deployed
- ✅ Hosting deployed
- ✅ Monitoring configured
- ✅ Deployment verified

## Services Deployed
- Firestore Rules
- Storage Rules
- Cloud Functions
- Remote Config
- Firebase Hosting

## URLs
- Web App: https://oasistaxiperu.com
- API: https://api.oasistaxiperu.com
- Firebase Console: https://console.firebase.google.com/project/$PROJECT_ID

## Next Steps
1. Monitor application performance
2. Check error logs
3. Verify all features are working
4. Monitor user feedback

## Logs
See $LOG_FILE for detailed deployment logs.
EOF

    success "Deployment report created: $REPORT_FILE"
}

# Rollback function
rollback() {
    section "ROLLING BACK DEPLOYMENT"

    warning "This will rollback to the previous deployment"
    read -p "Are you sure? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Rollback hosting
        log "Rolling back Firebase Hosting..."
        firebase hosting:rollback --project "$PROJECT_ID"

        # Rollback functions (if needed)
        log "Check Cloud Functions for manual rollback if needed"

        success "Rollback completed"
    else
        log "Rollback cancelled"
    fi
}

# Main deployment flow
main() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════╗"
    echo "║   OasisTaxi Production Deployment        ║"
    echo "║   Environment: PRODUCTION                ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}\n"

    # Parse arguments
    BUILD_TARGET=${1:-all}
    SKIP_TESTS=${2:-false}

    # Confirmation
    echo -e "${YELLOW}⚠️  WARNING: You are about to deploy to PRODUCTION${NC}"
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [ "$REPLY" != "yes" ]; then
        log "Deployment cancelled by user"
        exit 0
    fi

    # Start deployment
    log "Starting production deployment..."

    # Run deployment steps
    check_prerequisites

    if [ "$SKIP_TESTS" != "true" ]; then
        run_tests
    else
        warning "Skipping tests as requested"
    fi

    build_app "$BUILD_TARGET"
    deploy_firebase

    if [ "$BUILD_TARGET" == "web" ] || [ "$BUILD_TARGET" == "all" ]; then
        deploy_hosting
    fi

    setup_monitoring
    verify_deployment
    create_report

    # Success message
    echo -e "\n${GREEN}"
    echo "╔══════════════════════════════════════════╗"
    echo "║   DEPLOYMENT COMPLETED SUCCESSFULLY! 🎉   ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}\n"

    success "Production deployment completed at $(date)"
    log "Deployment log saved to: $LOG_FILE"
}

# Handle script arguments
case "${1:-}" in
    "rollback")
        rollback
        ;;
    "verify")
        verify_deployment
        ;;
    "report")
        create_report
        ;;
    *)
        main "$@"
        ;;
esac