# Quickstart Guide - OasisTaxi App Testing

**Feature**: Auditoría y Optimización Completa
**Branch**: 001-auditor-a-y
**Date**: 2025-01-14

## Prerequisites

1. **Environment Setup**
   - Flutter 3.35.3+ installed
   - Android device/emulator (API 21+) or iOS simulator (iOS 12+)
   - Firebase project: `oasis-taxi-peru`
   - Google Maps API key configured
   - Test accounts created (see below)

2. **Test Accounts**
   ```
   Passenger:
   Email: passenger@oasistaxiperu.com
   Password: Pass123!
   Phone: +51 987654321

   Driver:
   Email: driver@oasistaxiperu.com
   Password: Driver123!
   Phone: +51 987654322

   Admin:
   Email: admin@oasistaxiperu.com
   Password: Admin123!
   Phone: +51 987654323
   ```

## Quick Validation Tests

### 🚀 Test 1: Build & Launch (5 min)

```bash
# 1. Navigate to app directory
cd app

# 2. Get dependencies
flutter pub get

# 3. Run app
flutter run

# Expected: App launches without errors
# Success Criteria:
# ✅ No compilation errors
# ✅ No runtime crashes
# ✅ Splash screen appears
# ✅ Login screen loads
```

### 👤 Test 2: Passenger Flow (15 min)

```bash
# Launch app as passenger
flutter run
```

**Steps:**
1. **Login**
   - Tap "Iniciar Sesión"
   - Enter: passenger@oasistaxiperu.com / Pass123!
   - ✅ Should login successfully

2. **Request Trip**
   - Allow location permissions
   - Set pickup: Current location
   - Set destination: Search "Plaza de Armas Lima"
   - Select vehicle type: Economy
   - Enter initial price: S/ 15.00
   - Tap "Solicitar Viaje"
   - ✅ Should create trip request

3. **Price Negotiation**
   - Wait for driver offers
   - Review counter-offers
   - Accept an offer
   - ✅ Should match with driver

4. **Track Trip**
   - View driver approaching on map
   - Verify driver details shown
   - See verification code (4 digits)
   - ✅ Real-time tracking works

5. **Complete Trip**
   - Select payment: Cash
   - Rate driver: 5 stars
   - Add comment: "Excelente servicio"
   - ✅ Trip completes successfully

### 🚗 Test 3: Driver Flow (15 min)

```bash
# Launch app as driver
flutter run
```

**Steps:**
1. **Login**
   - Enter: driver@oasistaxiperu.com / Driver123!
   - ✅ Dashboard loads

2. **Go Online**
   - Toggle availability switch
   - ✅ Status changes to "Disponible"

3. **Receive Request**
   - Wait for trip request notification
   - View request details
   - Make counter-offer or accept
   - ✅ Negotiation works

4. **Navigate to Passenger**
   - Start navigation
   - Mark "Llegué"
   - Verify passenger code
   - ✅ Navigation integration works

5. **Complete Trip**
   - Start trip
   - Follow route
   - End trip
   - ✅ Earnings reflected in wallet

### 👨‍💼 Test 4: Admin Flow (10 min)

```bash
# Launch app as admin
flutter run
```

**Steps:**
1. **Login with 2FA**
   - Enter: admin@oasistaxiperu.com / Admin123!
   - Enter 2FA code (if enabled)
   - ✅ Admin dashboard loads

2. **Verify Documents**
   - Go to "Verificación Documentos"
   - Select pending document
   - Review and approve/reject
   - ✅ Status updates

3. **View Metrics**
   - Check active trips count
   - View today's revenue
   - Check driver statistics
   - ✅ Real-time data shown

4. **User Management**
   - Search for user
   - View user details
   - Toggle active status
   - ✅ Changes persist

## Integration Tests

### 🔥 Test 5: Firebase Integration (10 min)

```bash
# Run Firebase integration tests
cd app
flutter test integration_test/firebase_test.dart
```

**Manual Verification:**
1. Open Firebase Console
2. Check Firestore for:
   - New trip documents
   - User updates
   - Payment records
3. Check Authentication for:
   - Active sessions
   - User logins
4. ✅ All data syncs correctly

### 🗺️ Test 6: Google Maps Integration (5 min)

**Steps:**
1. Request new trip
2. Verify:
   - Map loads correctly
   - Markers appear
   - Route polyline draws
   - Real-time tracking updates
3. ✅ Maps fully functional

### 💳 Test 7: Payment Integration (10 min)

**Steps:**
1. Complete a trip
2. Select card payment
3. Enter test card:
   ```
   Number: 4111 1111 1111 1111
   CVV: 123
   Expiry: 12/25
   ```
4. Process payment
5. ✅ Payment processes (sandbox mode)

## Performance Tests

### ⚡ Test 8: App Performance (5 min)

```bash
# Run performance profiling
flutter run --profile
```

**Metrics to Check:**
- App launch: <3 seconds
- Screen transitions: <300ms
- Map rendering: 60 FPS
- Memory usage: <200MB
- ✅ All metrics within targets

### 📱 Test 9: Offline Capability (5 min)

**Steps:**
1. Login to app
2. Enable airplane mode
3. Try to:
   - View trip history
   - Access profile
   - View cached maps
4. Re-enable connectivity
5. ✅ Data syncs automatically

## Edge Case Tests

### 🔴 Test 10: Error Handling (10 min)

**Scenarios:**
1. **Invalid Login**
   - Wrong password → Error message
   - Non-existent user → Error message

2. **Network Loss During Trip**
   - Disconnect during trip
   - Should show reconnecting
   - Auto-resume when connected

3. **Payment Failure**
   - Use declined card
   - Should offer alternative payment

4. **Driver Cancellation**
   - Driver cancels accepted trip
   - Passenger notified
   - Can request new trip

## Validation Checklist

### Code Quality
- [ ] `flutter analyze` - 0 issues
- [ ] No TODO/FIXME comments
- [ ] No mock data in code
- [ ] No hardcoded credentials
- [ ] No commented code blocks

### Functionality
- [ ] All 3 user flows work
- [ ] Real-time updates functional
- [ ] Push notifications working
- [ ] GPS tracking accurate
- [ ] Chat system operational

### UI/UX
- [ ] Consistent button styles
- [ ] Uniform spacing (8, 16, 24, 32px)
- [ ] All text in Spanish
- [ ] Responsive on all screen sizes
- [ ] No UI glitches or overlaps

### Integration
- [ ] Firebase Auth working
- [ ] Firestore sync working
- [ ] Google Maps functional
- [ ] Payment gateway connected
- [ ] Push notifications delivered

### Performance
- [ ] App launches <3 seconds
- [ ] No memory leaks
- [ ] 60 FPS maintained
- [ ] Handles 100+ concurrent users
- [ ] APK size <50MB

## Troubleshooting

### Common Issues

1. **Build Errors**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Firebase Connection**
   - Check `google-services.json` exists
   - Verify Firebase project settings
   - Check internet connectivity

3. **Maps Not Loading**
   - Verify API key in `.env`
   - Check API key restrictions
   - Ensure billing enabled

4. **Login Issues**
   - Clear app data
   - Check Firebase Auth settings
   - Verify user exists in Firestore

## Final Release Checklist

Before marking as production-ready:

1. **Technical**
   - [ ] Zero compilation errors
   - [ ] Zero runtime warnings
   - [ ] All tests passing
   - [ ] Performance targets met

2. **Functional**
   - [ ] All user stories working
   - [ ] All edge cases handled
   - [ ] All integrations verified
   - [ ] Security measures active

3. **Business**
   - [ ] Pricing logic correct
   - [ ] Commission calculation accurate
   - [ ] Payment processing working
   - [ ] Analytics tracking enabled

4. **Deployment**
   - [ ] Production Firebase config
   - [ ] Release APK signed
   - [ ] Version number updated
   - [ ] Store listing prepared

## Support

For issues during testing:
1. Check logs: `flutter logs`
2. Review Firebase Console
3. Check error tracking in Crashlytics
4. Contact: support@oasistaxiperu.com

---
*Quickstart Guide v1.0 - OasisTaxi App*
*Estimated completion time: 90 minutes*