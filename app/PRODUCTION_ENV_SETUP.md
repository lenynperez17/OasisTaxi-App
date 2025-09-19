# 🔐 Production Environment Setup - OasisTaxi

## Overview
This document explains how to set up and manage production environment variables for OasisTaxi.

## Local Development

### 1. Create `.env` file
```bash
# Copy the example file
cp .env.example .env

# Edit with your production values
nano .env
```

### 2. Validate Configuration
```bash
# Run validation script
bash validate_env.sh
```

## Production CI/CD Setup

### 1. Create Secret in Google Secret Manager

```bash
# Create secret from .env file
gcloud secrets create oasis-taxi-env-production \
    --data-file=.env \
    --project=oasis-taxi-peru

# Grant access to Cloud Build
gcloud secrets add-iam-policy-binding oasis-taxi-env-production \
    --member="serviceAccount:YOUR-PROJECT-NUMBER@cloudbuild.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor" \
    --project=oasis-taxi-peru
```

### 2. Update Secret (when needed)

```bash
# Create new version
gcloud secrets versions add oasis-taxi-env-production \
    --data-file=.env \
    --project=oasis-taxi-peru
```

## Critical Variables Required

All these variables MUST be set without `CHANGE_ME_IN_PROD` placeholders:

### Firebase Configuration
- `FIREBASE_PROJECT_ID` - Firebase project identifier
- `FIREBASE_API_KEY` - Web API key
- `FIREBASE_APP_CHECK_SITE_KEY` - App Check site key for web
- `FIREBASE_SERVICE_ACCOUNT_EMAIL` - Service account email
- `FIREBASE_PRIVATE_KEY` - Service account private key (multiline, quoted)
- `FIREBASE_CLIENT_EMAIL` - Client email
- `FIREBASE_CLIENT_ID` - Client ID

### Google Services
- `GOOGLE_MAPS_API_KEY` - Maps, Places, and Directions API key
- `ENCRYPTION_KEY_ID` - Cloud KMS key (format: `projects/PROJECT/locations/LOCATION/keyRings/KEYRING/cryptoKeys/KEY`)

### Security
- `JWT_SECRET` - JWT signing secret (min 32 chars)
- `JWT_REFRESH_SECRET` - Refresh token secret
- `SESSION_SECRET` - Session encryption secret
- `SECURITY_SALT` - Password hashing salt
- `DATA_ENCRYPTION_KEY` - Data encryption key (base64, 32 bytes)

### Payment Integration
- `MERCADOPAGO_PUBLIC_KEY` - MercadoPago public key
- `MERCADOPAGO_ACCESS_TOKEN` - MercadoPago access token
- `MERCADOPAGO_WEBHOOK_SECRET` - Webhook validation secret

### Communication Services
- `TWILIO_ACCOUNT_SID` - Twilio account identifier
- `TWILIO_AUTH_TOKEN` - Twilio authentication token
- `TWILIO_PHONE_NUMBER` - Twilio phone number for SMS
- `SENDGRID_API_KEY` - SendGrid API key for emails

## Environment Validation

### Runtime Validation
The app validates critical variables at startup:

1. **Missing Variables**: App won't start if critical variables are missing
2. **Placeholder Detection**: Rejects values containing:
   - `CHANGE_ME_IN_PROD`
   - `PLACEHOLDER`
   - `EXAMPLE`
   - `your-`
   - `xxx`

3. **Format Validation**:
   - `ENCRYPTION_KEY_ID` must match: `projects/*/locations/*/keyRings/*/cryptoKeys/*`
   - `FIREBASE_PRIVATE_KEY` must contain: `-----BEGIN PRIVATE KEY-----`

### CI/CD Validation
Cloud Build performs these checks:
1. Loads `.env` from Secret Manager
2. Checks for placeholders
3. Validates critical variables
4. Runs Dart validation script
5. Fails build if validation fails

## Security Best Practices

1. **Never commit `.env` to repository** - It's in `.gitignore`
2. **Use Secret Manager in production** - Don't store secrets in code
3. **Rotate secrets regularly** - Update in Secret Manager
4. **Limit access** - Only Cloud Build service account should access secrets
5. **Audit access** - Review Secret Manager access logs

## Troubleshooting

### Error: "Variables de entorno de producción no configuradas"
**Solution**: Ensure all critical variables are set in `.env` without placeholders

### Error: "ENCRYPTION_KEY_ID con formato inválido"
**Solution**: Use format: `projects/oasis-taxi-peru/locations/global/keyRings/oasis-taxi-keyring/cryptoKeys/oasis-taxi-encryption-key`

### Error: "FIREBASE_PRIVATE_KEY no parece ser una clave privada válida"
**Solution**: Ensure the key is properly quoted with `\n` for newlines:
```
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIIE...\n-----END PRIVATE KEY-----\n"
```

### CI/CD Error: "Secret 'oasis-taxi-env-production' not found"
**Solution**: Create the secret in Google Secret Manager (see setup instructions above)

## Testing Production Configuration

```bash
# Local test
cd app
flutter run --dart-define=ENVIRONMENT=production

# Verify validation passes
flutter test test/environment_config_test.dart
```

## Support
For issues with environment configuration, contact the DevOps team.