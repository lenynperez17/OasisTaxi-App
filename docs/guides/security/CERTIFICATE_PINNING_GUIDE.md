# Certificate Pinning Rotation Guide

## Overview
This guide describes the process for rotating certificate pins in the OasisTaxi application.

## Current Pin Configuration

### Expiry Date: 2025-12-31

### Pinned Certificates

#### Firebase/Google Services
- **GTS Root R1**: `Vjs8r4z+80wjNcr1YKepWQboSIRi63WsWXhIMN+eWys=`
- **GTS Root R2**: `CLOmM1/OXvSPjw5UOYbAf9GKOxImEp9hhku9W90fHMk=` (backup)
- **GTS CA 1C3**: `W5rhIQ2ZbJKFkRvsGDwQVS/H/NSixP33+Z/fpJ0O25Q=`
- **Backup Pin**: `hxqRlPTu1bMS/0DITB1SSu0vd4u/8l8TjPgfaAp63Gc=`

#### MercadoPago
- **DigiCert Global Root CA**: `r/mIkG3eEpVdm+u/ko/cwxzOMo1bk4TyHIlByibiA5E=`
- **DigiCert SHA2 Secure Server CA**: `5kJvNEMw0KjrCAu7eXY5HmQkP/Ulb5/OlyMoIIWDGA=`
- **Backup Pin**: `K87oWBWM9UZfyddvDfoxL+8lpNyoUB2ptGtn0fv6G2Q=`

## Certificate Pin Rotation Process

### 1. Pre-Rotation (90 days before expiry)

**Timeline: October 1, 2025**

- [ ] Generate new certificate pins for all services
- [ ] Test new pins in staging environment
- [ ] Add new pins as backup pins in configuration
- [ ] Deploy app update with both old and new pins

### 2. Transition Period (60 days)

**Timeline: October 1 - November 30, 2025**

- [ ] Monitor for pin validation failures
- [ ] Ensure majority of users have updated app
- [ ] Coordinate with backend teams for certificate updates
- [ ] Test with new certificates in production

### 3. Pin Rotation (30 days before expiry)

**Timeline: December 1, 2025**

- [ ] Switch primary pins to new certificates
- [ ] Keep old pins as backup
- [ ] Deploy mandatory app update
- [ ] Monitor error rates closely

### 4. Cleanup (After expiry)

**Timeline: January 1, 2026**

- [ ] Remove expired pins from configuration
- [ ] Update documentation
- [ ] Archive old pin configurations

## How to Generate Certificate Pins

### For Android (SPKI Pins)

```bash
# Get certificate from server
echo | openssl s_client -connect example.com:443 2>/dev/null | \
  openssl x509 -pubkey -noout | \
  openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | \
  openssl enc -base64
```

### For Firebase/Google Services

```bash
# Firebase domains to check
domains=(
  "firebaseapp.com"
  "firebase.com"
  "firebaseio.com"
  "googleapis.com"
)

for domain in "${domains[@]}"; do
  echo "Checking $domain..."
  echo | openssl s_client -connect $domain:443 2>/dev/null | \
    openssl x509 -pubkey -noout | \
    openssl pkey -pubin -outform der | \
    openssl dgst -sha256 -binary | \
    openssl enc -base64
done
```

## Files to Update

1. **Android**: `/app/android/app/src/main/res/xml/network_security_config.xml`
2. **Dart/Flutter**: `/app/lib/services/network_client.dart`
3. **Remote Config**: Update `certificate_pins` parameter in Firebase Console

## Monitoring and Alerts

### Setup Monitoring (6 months before expiry)

**Timeline: July 1, 2025**

1. Create calendar reminders for key dates
2. Setup monitoring alerts in Google Cloud:
   ```bash
   gcloud monitoring policies create --notification-channels=CHANNEL_ID \
     --display-name="Certificate Pin Expiry Warning" \
     --condition-display-name="Pins expire in 90 days" \
     --condition-threshold-value=90 \
     --condition-threshold-duration=0s
   ```

3. Add to team runbook and on-call documentation

### Key Metrics to Monitor

- SSL/TLS handshake failures
- Network request error rates
- App crash rates related to networking
- User reports of connectivity issues

## Emergency Rollback Plan

If certificate pinning causes widespread issues:

1. **Immediate Response** (< 1 hour)
   - Deploy Remote Config update to disable pinning
   - Alert all on-call engineers
   - Open incident channel

2. **Short-term Fix** (< 24 hours)
   - Release hotfix removing problematic pins
   - Fast-track app store review
   - Communicate with users via in-app messaging

3. **Post-Incident**
   - Root cause analysis
   - Update rotation procedures
   - Test in broader staging environment

## Testing Checklist

- [ ] Test with current production certificates
- [ ] Test with new/rotated certificates
- [ ] Test with expired certificates (should fail)
- [ ] Test with invalid certificates (should fail)
- [ ] Test backup pin functionality
- [ ] Test on all supported OS versions
- [ ] Test with Remote Config updates
- [ ] Test rollback procedures

## Responsible Teams

- **Security Team**: Generate and validate new pins
- **Mobile Team**: Update app configurations
- **DevOps Team**: Coordinate certificate updates
- **QA Team**: Test certificate rotation
- **Support Team**: Handle user issues

## Contact Information

- Security Team: security@oasistaxiperu.com
- On-Call: +51 999 999 999
- Escalation: CTO/Security Lead

## References

- [Android Network Security Configuration](https://developer.android.com/training/articles/security-config)
- [Certificate Pinning Best Practices](https://owasp.org/www-community/controls/Certificate_and_Public_Key_Pinning)
- [Firebase Certificate Pins](https://firebase.google.com/support/guides/security-checklist)

## Revision History

- 2025-01-16: Initial document creation
- Next Review: 2025-07-01 (6 months before expiry)