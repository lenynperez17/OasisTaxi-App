# 🔐 Google Secret Manager Setup for OasisTaxi

## Prerequisites

- Google Cloud SDK installed
- Project ID: `oasis-taxi-peru`
- Appropriate permissions in GCP

## Step 1: Enable Secret Manager API

```bash
gcloud services enable secretmanager.googleapis.com --project=oasis-taxi-peru
```

## Step 2: Create the Secret

```bash
# Navigate to app directory
cd app

# Create secret from .env file
gcloud secrets create oasis-taxi-env-production \
  --data-file=.env \
  --project=oasis-taxi-peru \
  --replication-policy="automatic"
```

## Step 3: Grant Cloud Build Access

```bash
# Get project number
PROJECT_NUMBER=$(gcloud projects describe oasis-taxi-peru --format="value(projectNumber)")

# Grant access to Cloud Build service account
gcloud secrets add-iam-policy-binding oasis-taxi-env-production \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project=oasis-taxi-peru
```

## Step 4: Verify Secret

```bash
# List versions
gcloud secrets versions list oasis-taxi-env-production --project=oasis-taxi-peru

# Test access (this should display your .env content)
gcloud secrets versions access latest --secret=oasis-taxi-env-production --project=oasis-taxi-peru
```

## Step 5: Update Secret (When Needed)

```bash
# When you need to update the .env in production
gcloud secrets versions add oasis-taxi-env-production \
  --data-file=.env \
  --project=oasis-taxi-peru
```

## Cloud Build Integration

The `cloudbuild.yaml` is already configured to:

1. **Retrieve the secret** (Step 1.5):
   ```yaml
   gcloud secrets versions access latest --secret="oasis-taxi-env-production" > app/.env
   ```

2. **Validate no placeholders**:
   ```bash
   if grep -q "CHANGE_ME_IN_PROD" app/.env; then
     exit 1
   fi
   ```

3. **Run Dart validation** (Step 1.6):
   - Loads `.env` with dotenv
   - Validates all critical variables
   - Checks format of `ENCRYPTION_KEY_ID`
   - Validates `FIREBASE_PRIVATE_KEY` format

## Security Best Practices

1. **Never commit `.env` to repository** - Already in `.gitignore`
2. **Rotate secrets regularly** - Update via `gcloud secrets versions add`
3. **Audit access** - Check who has access:
   ```bash
   gcloud secrets get-iam-policy oasis-taxi-env-production --project=oasis-taxi-peru
   ```
4. **Use least privilege** - Only grant `secretAccessor` role, not `admin`
5. **Monitor usage** - Check Secret Manager logs in Cloud Console

## Validation Commands

```bash
# Run local smoke test
bash smoke_test.sh

# Test Cloud Build locally (dry-run)
gcloud builds submit --config=cloudbuild.yaml --no-source --substitutions=_BRANCH_NAME=main

# View build logs
gcloud builds list --limit=5 --project=oasis-taxi-peru
gcloud builds log <BUILD_ID> --project=oasis-taxi-peru
```

## Troubleshooting

### Error: "Permission denied accessing secret"
```bash
# Check service account permissions
gcloud secrets get-iam-policy oasis-taxi-env-production

# Re-grant permissions if needed
gcloud secrets add-iam-policy-binding oasis-taxi-env-production \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### Error: "Secret not found"
```bash
# Create the secret
gcloud secrets create oasis-taxi-env-production --data-file=.env
```

### Error: "Invalid .env format"
```bash
# Validate locally first
bash smoke_test.sh

# Check for Windows line endings
dos2unix .env || sed -i 's/\r$//' .env
```

## Environment Variables Required

All these must be present in the secret without `CHANGE_ME_IN_PROD`:

- `FIREBASE_PROJECT_ID`
- `FIREBASE_API_KEY`
- `FIREBASE_APP_CHECK_SITE_KEY`
- `GOOGLE_MAPS_API_KEY`
- `ENCRYPTION_KEY_ID` (format: `projects/.../locations/.../keyRings/.../cryptoKeys/...`)
- `JWT_SECRET`
- `FIREBASE_SERVICE_ACCOUNT_EMAIL`
- `FIREBASE_PRIVATE_KEY` (multiline with `\n`)
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_CLIENT_ID`
- `CLOUD_KMS_PROJECT_ID`
- `MERCADOPAGO_PUBLIC_KEY`
- `MERCADOPAGO_ACCESS_TOKEN`
- `TWILIO_ACCOUNT_SID`
- `SENDGRID_API_KEY`

## CI/CD Pipeline Flow

1. Cloud Build starts
2. Clones repository
3. **Retrieves `.env` from Secret Manager**
4. **Validates no placeholders**
5. **Runs Dart validation script**
6. Continues with build if validation passes
7. Deploys to Firebase

## Next Steps

1. Create the secret in GCP using the commands above
2. Trigger a Cloud Build to test the integration
3. Monitor the build logs for any issues
4. Verify the app runs with the production configuration