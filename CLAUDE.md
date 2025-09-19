# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OasisTaxi is a Flutter-based ride-hailing application for Peru with price negotiation features. The app has three user interfaces: Passenger, Driver, and Admin.

## Essential Commands

```bash
# Navigate to app directory first
cd app

# Run the application
flutter run -d chrome --web-port=5000        # Web development
flutter run                                   # Default device

# Build commands
flutter build apk --release                   # Android APK
flutter build ios --release                   # iOS build
flutter build web --release                   # Web production
./scripts/build_web.sh                        # Web with env injection

# Development
flutter pub get                               # Install dependencies
flutter analyze                               # Analyze code
flutter test                                  # Run tests
flutter clean                                 # Clean build files

# Firebase deployment (from app/firebase/)
firebase deploy --only firestore:rules       # Deploy Firestore rules
firebase deploy --only storage:rules         # Deploy Storage rules
firebase deploy --only hosting               # Deploy web app
```

## Architecture & Key Patterns

### State Management
- **Provider Pattern**: All state is managed through Provider
- Key providers in `lib/providers/`:
  - `AuthProvider`: User authentication and session management
  - `LocationProvider`: GPS and location services
  - `RideProvider`: Trip management and status
  - `PriceNegotiationProvider`: Price negotiation logic
  - `VehicleProvider`: Vehicle selection and types

### User Flow Architecture
```
lib/screens/
├── auth/ (5 pantallas)      # Login/Register with differentiation
│   ├── modern_login_screen.dart
│   ├── modern_register_screen.dart (3 steps passenger, 4 driver)
│   ├── phone_verification_screen.dart
│   ├── forgot_password_screen.dart
│   └── modern_splash_screen.dart
├── passenger/ (12 pantallas) # Passenger-specific screens
├── driver/ (12 pantallas)    # Driver-specific screens
├── admin/ (8 pantallas)      # Admin dashboard and management
└── shared/ (11 pantallas)    # Shared screens
```

### Complete User Flows (✅ 100% Implementados)

#### 🚖 Passenger Flow
1. **Registro**: Email/Phone → Verificación OTP → Datos personales
2. **Login**: Phone/Google OAuth → Home
3. **Solicitar Viaje**: 
   - Seleccionar origen/destino
   - Elegir tipo de vehículo
   - Negociar precio
   - Esperar conductor
4. **Durante el Viaje**:
   - Tracking en tiempo real
   - Chat con conductor
   - Botón de emergencia
5. **Finalizar**:
   - Pagar (efectivo/tarjeta/wallet)
   - Calificar conductor
   - Ver en historial

#### 🚗 Driver Flow
1. **Registro**: Datos personales → Documentos → Vehículo → Cuenta bancaria
2. **Verificación**: Admin revisa documentos → Aprobación/Rechazo
3. **Operación**:
   - Recibir solicitudes en tiempo real
   - Aceptar/Rechazar/Negociar precio
   - Navegar con GPS
   - Recoger pasajero (verificar código)
   - Completar viaje
4. **Ganancias**:
   - Ver balance en wallet
   - Solicitar retiros
   - Ver métricas de rendimiento

#### 👨‍💼 Admin Flow
1. **Login**: Email/Password → 2FA obligatorio
2. **Dashboard**: Métricas en tiempo real
3. **Gestión**:
   - Verificar documentos de conductores ✓
   - Gestionar usuarios (suspender/activar)
   - Ver reportes financieros
   - Analytics y estadísticas
   - Configurar comisiones y tarifas

### Key Features Implemented
- ✅ Phone Authentication (Firebase)
- ✅ Google OAuth
- ✅ 2FA for Admin
- ✅ Document Verification System
- ✅ Real-time Chat
- ✅ GPS Tracking
- ✅ Price Negotiation
- ✅ Multiple Payment Methods
- ✅ Emergency System
- ✅ Rating System
- ✅ Wallet System
- ✅ Professional Logging (AppLogger)

### Firebase Integration
- Project: `oasis-taxi-peru`
- All Firebase config in `app/firebase/`
- Service account in `app/assets/oasis-taxi-peru-firebase-adminsdk*.json`
- Real-time updates via Firestore listeners
- Authentication with Firebase Auth (Google OAuth configured)

### Environment Configuration
- **Single .env file**: `app/.env` contains ALL configuration
- Loaded via flutter_dotenv in main.dart
- Key variables:
  - `GOOGLE_MAPS_API_KEY`: Maps functionality
  - `FIREBASE_*`: Firebase configuration
  - `MERCADOPAGO_*`: Payment integration
  - OAuth credentials for social login

### Currency & Localization
- All prices in Peruvian Soles (S/)
- Spanish language primary
- Date format: DD/MM/YYYY
- Phone format: +51 XXX XXX XXX

## Critical Implementation Details

### Location Services
- Always check permissions before accessing GPS
- Implement timeout for location requests (10 seconds)
- Use FutureBuilder pattern for async location loading

### Price Negotiation Flow (Sistema Único de OasisTaxi)
1. Passenger requests ride with initial price
2. Creates `PriceNegotiation` document in Firestore
3. Drivers receive real-time notifications via FCM
4. Drivers can:
   - Accept immediately
   - Make counter-offer
   - Reject
5. Status flow: `waitingDriver` → `driverOffered` → `accepted`/`rejected`
6. Passenger can accept/reject counter-offers
7. Once accepted, trip begins automatically

### Driver-Specific Features
- Vehicle registration required (license, SOAT, bank account)
- Real-time trip requests via Firestore listeners
- Wallet system for earnings
- Commission rate: 20% (configurable in Firestore)

### Payment Methods
- Cash (default)
- MercadoPago integration (cards)
- Digital wallet with bonus system

### Map Integration
- Google Maps with real-time tracking
- Custom markers for vehicle types
- Route polylines between pickup/destination
- Address search with Google Places API

## Common Issues & Solutions

### BuildContext Async Gaps
Always check `mounted` before setState in async operations:
```dart
if (mounted) {
  setState(() { ... });
}
```

### Firebase Timestamp Handling
Convert Firebase Timestamps properly:
```dart
final timestamp = data['createdAt'] as Timestamp?;
final date = timestamp?.toDate() ?? DateTime.now();
```

### Provider Access
Always use correct context:
```dart
// Read once
final auth = Provider.of<AuthProvider>(context, listen: false);
// Listen to changes
final auth = context.watch<AuthProvider>();
```

## Project Structure

```
app/
├── lib/
│   ├── core/           # Theme, config, constants
│   ├── models/         # Data models (User, Trip, Vehicle)
│   ├── providers/      # State management
│   ├── screens/        # UI screens by user type
│   ├── services/       # Business logic, Firebase, APIs
│   ├── utils/          # Helpers and utilities
│   └── widgets/        # Reusable components
├── assets/             # Images, fonts, credentials
├── firebase/           # Firebase configuration files
└── .env               # Environment variables (DO NOT COMMIT)
```

## Testing Credentials

### Test Users (Created with create_users.js)
```javascript
// Passenger
Email: passenger@oasistaxiperu.com
Password: Pass123!
Phone: +51 987654321

// Driver (pre-approved documents)
Email: driver@oasistaxiperu.com
Password: Driver123!
Phone: +51 987654322
Documents: Pre-approved
Status: Active

// Admin (with 2FA)
Email: admin@oasistaxiperu.com
Password: Admin123!
Phone: +51 987654323
2FA: Enabled
```

## Testing Approach

- Unit tests in `app/test/`
- Widget tests for critical UI components
- Integration tests for complete flows
- Test with different user roles (passenger, driver, admin)
- Run create_users.js to create test accounts

## Code Quality Standards

### Clean Code Practices
- ✅ No `ignore_for_file` comments
- ✅ No `print()` or `debugPrint()` - Use AppLogger
- ✅ No TODO/FIXME comments in production
- ✅ All imports properly structured
- ✅ Consistent naming conventions
- ✅ Error handling with try-catch blocks
- ✅ Null safety enforced

### Logging System (AppLogger)
```dart
AppLogger.info('General information');
AppLogger.error('Error message', exception, stackTrace);
AppLogger.warning('Warning message');
AppLogger.debug('Debug information');
AppLogger.critical('Critical system error');
AppLogger.api('GET', '/api/endpoint');
AppLogger.firebase('Firestore operation');
AppLogger.navigation('FromScreen', 'ToScreen');
AppLogger.performance('Operation name', milliseconds);
```

## Deployment Checklist

1. Update version in `pubspec.yaml`
2. Verify all OAuth credentials are production-ready
3. Check Firebase security rules are restrictive
4. Ensure .env has production values
5. Run `flutter analyze` - must pass with 0 errors
6. Build and test on target platforms
7. Update app signing for stores (Android keystore, iOS provisioning)
8. Test all 3 user flows completely
9. Verify document verification system works
10. Check payment integration (MercadoPago)