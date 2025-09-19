# Monitoring Configuration

## Overview

This directory contains Google Cloud Monitoring resources for the OasisTaxi production environment.

## Files

- `alert-policies.json` - Alert policies for monitoring critical metrics
- `dashboards.json` - Dashboard configuration for visualizing metrics

## How to Edit and Deploy

### Editing Resources

1. **Alert Policies**: Edit `alert-policies.json` following the [Cloud Monitoring v3 AlertPolicy schema](https://cloud.google.com/monitoring/api/ref_v3/rest/v3/projects.alertPolicies)

2. **Dashboards**: Edit `dashboards.json` following the [Cloud Monitoring Dashboard schema](https://cloud.google.com/monitoring/api/ref_v3/rest/v1/projects.dashboards)

### Validating Resources

Before deploying, validate your changes:

```bash
# Validate alert policies
gcloud monitoring policies validate \
  --policy-from-file app/monitoring/alert-policies.json \
  --project $PROJECT_ID

# Test dashboard in a sandbox project first
gcloud monitoring dashboards create \
  --config-from-file=app/monitoring/dashboards.json \
  --project $SANDBOX_PROJECT_ID
```

### Deploying Resources

Use the production deployment script:

```bash
./scripts/production-deployment.sh
```

Or deploy monitoring resources only:

```bash
# Deploy alert policies
jq -c '.[]' app/monitoring/alert-policies.json | while read policy; do
    echo "$policy" | gcloud monitoring policies create \
      --policy-from-file=- \
      --project=oasis-taxi-peru
done

# Deploy dashboards
gcloud monitoring dashboards create \
  --config-from-file=app/monitoring/dashboards.json \
  --project=oasis-taxi-peru
```

### Updating Existing Resources

To update existing resources:

```bash
# List existing resources
gcloud monitoring dashboards list --project=oasis-taxi-peru
gcloud monitoring policies list --project=oasis-taxi-peru

# Update a dashboard (get ID from list command)
gcloud monitoring dashboards update DASHBOARD_ID \
  --config-from-file=app/monitoring/dashboards.json \
  --project=oasis-taxi-peru
```

## Notification Channels

### Current Channels

Notification channels are referenced in alert policies but must be created separately:

1. **Email channels**: Create via Console or API
2. **SMS channels**: Require verification
3. **Slack/PagerDuty**: Require webhook setup

### Rotating Notification Channels

1. Create new notification channel:
```bash
gcloud alpha monitoring channels create \
  --display-name="New Alert Email" \
  --type=email \
  --channel-labels=email_address=newalerts@oasistaxiperu.com
```

2. Get the channel ID from the output

3. Update `alert-policies.json` to reference the new channel ID

4. Redeploy alert policies

5. Delete old channel after verification:
```bash
gcloud alpha monitoring channels delete CHANNEL_ID
```

## Metrics Reference

### Cloud Functions Metrics
- `cloudfunctions.googleapis.com/function/execution_count` - Function invocations
- `cloudfunctions.googleapis.com/function/execution_times` - Function latency
- `cloudfunctions.googleapis.com/function/user_memory_bytes` - Memory usage

### Firestore Metrics
- `firestore.googleapis.com/document/read_count` - Document reads
- `firestore.googleapis.com/document/write_count` - Document writes

### Firebase Auth Metrics
- `identitytoolkit.googleapis.com/user/auth_failures` - Authentication failures

### Storage Metrics
- `storage.googleapis.com/storage/total_bytes` - Storage usage

## Alert Policy Thresholds

Current thresholds that may need tuning:

- **Error Rate**: > 5% triggers alert
- **Latency P95**: > 2000ms triggers alert
- **Firestore Reads**: > 50000/min triggers cost alert
- **Memory Usage**: > 90% triggers alert
- **Auth Failures**: > 10/min triggers security alert

## Dashboard Widgets

The main dashboard includes:
- API Request Rate
- API Latency (P95)
- Active Users
- Error Rate
- Firestore Operations
- Function Execution by Name

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure service account has `roles/monitoring.editor`
2. **Invalid Schema**: Validate JSON against Cloud Monitoring schemas
3. **Duplicate Resources**: Delete existing before recreating or use update commands

### Useful Commands

```bash
# View logs for monitoring operations
gcloud logging read "resource.type=gce_instance AND protoPayload.serviceName=monitoring.googleapis.com"

# Test metric queries
gcloud monitoring metrics list --project=oasis-taxi-peru

# Export existing dashboard for reference
gcloud monitoring dashboards describe DASHBOARD_ID --format=json
```

## Notes

- The `reference.yaml` file in `docs/monitoring/` is for illustration only and should not be applied directly
- Always test changes in a non-production project first
- Keep notification channel lists updated when team members change