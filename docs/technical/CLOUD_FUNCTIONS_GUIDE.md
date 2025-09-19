# ⚡ CLOUD FUNCTIONS GUIDE - OASISTAXI
## Guía Completa de Desarrollo y Despliegue de Cloud Functions
### Versión: Production-Ready 1.0 - Enero 2025

---

## 📋 TABLA DE CONTENIDOS

1. [Introducción](#introducción)
2. [Arquitectura de Functions](#arquitectura-de-functions)
3. [Setup y Configuración](#setup-y-configuración)
4. [Desarrollo de Functions](#desarrollo-de-functions)
5. [Authentication Functions](#authentication-functions)
6. [Trip Management Functions](#trip-management-functions)
7. [Payment Functions](#payment-functions)
8. [Notification Functions](#notification-functions)
9. [Analytics Functions](#analytics-functions)
10. [Security y Validation](#security-y-validation)
11. [Performance Optimization](#performance-optimization)
12. [Testing y Debugging](#testing-y-debugging)
13. [Deployment y CI/CD](#deployment-y-cicd)
14. [Monitoring y Observability](#monitoring-y-observability)

---

## 🎯 INTRODUCCIÓN

### Rol de Cloud Functions en OasisTaxi

Cloud Functions actúa como el **backend serverless completo** de OasisTaxi, proporcionando:

- 🔐 **Lógica de autenticación** avanzada con custom claims
- 🚖 **Gestión completa de viajes** desde solicitud hasta completado
- 💳 **Procesamiento de pagos** con MercadoPago y wallets
- 📱 **Sistema de notificaciones** multi-canal y tiempo real
- 📊 **Analytics y reportes** automatizados para business intelligence
- 🔒 **Validaciones de seguridad** y rate limiting
- 🌐 **Integraciones externas** con APIs de terceros

### Principios de Arquitectura

```yaml
Principios Core:
  - Serverless First: Sin gestión de infraestructura
  - Event-Driven: Triggers automáticos y respuesta a eventos
  - Stateless: Functions sin estado para máxima escalabilidad
  - Single Responsibility: Una function, una responsabilidad
  - Error Resilient: Manejo robusto de errores y recuperación
  - Cost Optimized: Pago por ejecución real
  - Security by Design: Validación y autorización en cada layer
```

### Stack Tecnológico

```javascript
Runtime: Node.js 18 (LTS)
Framework: Firebase Functions v2
Language: TypeScript + JavaScript
Database: Firestore Admin SDK
Authentication: Firebase Auth Admin
Storage: Cloud Storage Admin
Messaging: Firebase Cloud Messaging
External APIs:
  - Google Maps API
  - MercadoPago API
  - Twilio SMS API
  - SendGrid Email API
```

---

## 🏗️ ARQUITECTURA DE FUNCTIONS

### Estructura del Proyecto

```
firebase/functions/
├── src/
│   ├── auth/                    # Authentication functions
│   │   ├── onUserCreate.ts
│   │   ├── setUserRole.ts
│   │   └── verifyDriver.ts
│   ├── trips/                   # Trip management functions
│   │   ├── createTrip.ts
│   │   ├── acceptTrip.ts
│   │   ├── startTrip.ts
│   │   ├── completeTrip.ts
│   │   └── cancelTrip.ts
│   ├── payments/                # Payment processing
│   │   ├── processPayment.ts
│   │   ├── refundPayment.ts
│   │   ├── updateWallet.ts
│   │   └── webhooks.ts
│   ├── notifications/           # Notification system
│   │   ├── sendPushNotification.ts
│   │   ├── sendSMS.ts
│   │   └── sendEmail.ts
│   ├── analytics/               # Analytics and reporting
│   │   ├── processAnalytics.ts
│   │   ├── generateReports.ts
│   │   └── exportData.ts
│   ├── utils/                   # Shared utilities
│   │   ├── validation.ts
│   │   ├── security.ts
│   │   ├── logger.ts
│   │   └── external-apis.ts
│   ├── types/                   # TypeScript definitions
│   │   ├── user.types.ts
│   │   ├── trip.types.ts
│   │   └── payment.types.ts
│   └── index.ts                 # Function exports
├── package.json
├── tsconfig.json
└── .env.example
```

### Function Categories

#### 🔐 Authentication Functions
```yaml
Functions:
  - onUserCreate: Setup inicial de usuario
  - setUserRole: Gestión de roles y permisos
  - verifyDriver: Verificación de documentos de conductor
  - updateProfile: Actualización de perfil de usuario

Triggers:
  - Auth onCreate: Nuevo usuario registrado
  - Firestore onChange: Cambios en documentos de usuario
  - HTTPS Callable: Llamadas directas desde cliente
```

#### 🚖 Trip Management Functions
```yaml
Functions:
  - createTrip: Crear solicitud de viaje
  - acceptTrip: Conductor acepta viaje
  - startTrip: Iniciar viaje en curso
  - completeTrip: Finalizar viaje
  - cancelTrip: Cancelar viaje
  - updateLocation: Actualizar ubicación en tiempo real

Triggers:
  - HTTPS Callable: Acciones del usuario
  - Firestore onChange: Cambios de estado de viaje
  - Scheduled: Limpiezas y mantenimiento
```

#### 💳 Payment Functions
```yaml
Functions:
  - processPayment: Procesar pago principal
  - refundPayment: Gestionar reembolsos
  - updateWallet: Actualizar saldo de wallet
  - calculateCommission: Calcular comisiones
  - transferEarnings: Transferir ganancias a conductores

Triggers:
  - HTTPS Callable: Iniciar transacciones
  - HTTP Request: Webhooks de MercadoPago
  - Firestore onChange: Estados de pago
```

---

## ⚙️ SETUP Y CONFIGURACIÓN

### Inicialización del Proyecto

```bash
# Inicializar Firebase Functions
cd firebase
npm install -g firebase-tools
firebase login
firebase init functions

# Configurar TypeScript
npm install --save-dev typescript @types/node
npm install firebase-functions firebase-admin
```

### Configuración Base

```typescript
// src/index.ts - ✅ BEST PRACTICE: Inicialización centralizada
import * as admin from 'firebase-admin';
import { setGlobalOptions } from 'firebase-functions/v2/options';

// ✅ BEST PRACTICE: Configuración global optimizada
setGlobalOptions({
  region: 'us-central1',
  maxInstances: 100,
  timeoutSeconds: 60,
  memory: '256MiB',
});

// ✅ BEST PRACTICE: Inicialización de Firebase Admin
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  databaseURL: process.env.FIREBASE_DATABASE_URL,
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
});

// ✅ BEST PRACTICE: Configuración de Firestore
const db = admin.firestore();
db.settings({
  ignoreUndefinedProperties: true,
  timestampsInSnapshots: true,
});

// Export all functions
export * from './auth';
export * from './trips';
export * from './payments';
export * from './notifications';
export * from './analytics';
```

### Variables de Entorno

```typescript
// src/config/environment.ts
export const config = {
  // Firebase
  projectId: process.env.FIREBASE_PROJECT_ID || 'oasis-taxi-peru',
  databaseURL: process.env.FIREBASE_DATABASE_URL,
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
  
  // External APIs
  googleMapsApiKey: process.env.GOOGLE_MAPS_API_KEY,
  mercadoPagoAccessToken: process.env.MERCADOPAGO_ACCESS_TOKEN,
  mercadoPagoWebhookSecret: process.env.MERCADOPAGO_WEBHOOK_SECRET,
  twilioAccountSid: process.env.TWILIO_ACCOUNT_SID,
  twilioAuthToken: process.env.TWILIO_AUTH_TOKEN,
  sendGridApiKey: process.env.SENDGRID_API_KEY,
  
  // Business Logic
  driverCommissionRate: parseFloat(process.env.DRIVER_COMMISSION_RATE || '0.80'),
  companyCommissionRate: parseFloat(process.env.COMPANY_COMMISSION_RATE || '0.20'),
  maxTripDistance: parseInt(process.env.MAX_TRIP_DISTANCE || '100'),
  defaultCurrency: process.env.DEFAULT_CURRENCY || 'PEN',
  
  // Rate Limiting
  maxTripsPerHour: parseInt(process.env.MAX_TRIPS_PER_HOUR || '10'),
  maxAuthAttemptsPerHour: parseInt(process.env.MAX_AUTH_ATTEMPTS_PER_HOUR || '5'),
};

// ✅ BEST PRACTICE: Validar configuración al inicio
export function validateConfig(): void {
  const required = [
    'GOOGLE_MAPS_API_KEY',
    'MERCADOPAGO_ACCESS_TOKEN',
    'FIREBASE_PROJECT_ID',
  ];
  
  const missing = required.filter(key => !process.env[key]);
  
  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }
}
```

---

## 🔐 AUTHENTICATION FUNCTIONS

### User Creation Handler

```typescript
// src/auth/onUserCreate.ts
import { auth } from 'firebase-functions/v2';
import { onUserCreated } from 'firebase-functions/v2/auth';
import * as admin from 'firebase-admin';
import { logger } from '../utils/logger';
import { sendWelcomeNotification } from '../notifications/sendEmail';

// ✅ BEST PRACTICE: Trigger optimizado para nuevos usuarios
export const onUserCreate = onUserCreated({
  region: 'us-central1',
  memory: '256MiB',
  timeoutSeconds: 30,
}, async (event) => {
  const startTime = Date.now();
  
  try {
    const { uid, email, phoneNumber, displayName } = event.data;
    
    logger.info('New user created', {
      uid,
      email: email || 'N/A',
      phone: phoneNumber || 'N/A',
    });
    
    // ✅ BEST PRACTICE: Crear documento de usuario
    const userData = {
      uid,
      email: email || null,
      phone: phoneNumber || null,
      displayName: displayName || null,
      userType: 'passenger', // Default type
      status: 'active',
      profile: {
        firstName: '',
        lastName: '',
        avatar: '',
        dateOfBirth: null,
      },
      preferences: {
        notifications: true,
        language: 'es',
        currency: 'PEN',
        theme: 'system',
      },
      metadata: {
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
        loginCount: 1,
        platform: 'unknown',
        version: '1.0.0',
      },
      location: {
        latitude: null,
        longitude: null,
        address: '',
        city: 'Lima',
        country: 'PE',
        lastUpdated: null,
      },
    };
    
    // ✅ BEST PRACTICE: Transacción para consistencia
    await admin.firestore().runTransaction(async (transaction) => {
      const userRef = admin.firestore().collection('users').doc(uid);
      transaction.set(userRef, userData);
      
      // Crear documento de estadísticas
      const statsRef = admin.firestore()
        .collection('users')
        .doc(uid)
        .collection('statistics')
        .doc('summary');
      
      transaction.set(statsRef, {
        totalTrips: 0,
        totalSpent: 0,
        averageRating: 0,
        favoriteLocations: [],
        preferredDrivers: [],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    
    // ✅ BEST PRACTICE: Custom claims por defecto
    await admin.auth().setCustomUserClaims(uid, {
      role: 'passenger',
      verified: false,
      permissions: ['trips:create', 'trips:view', 'payments:create'],
      createdAt: Date.now(),
    });
    
    // ✅ BEST PRACTICE: Notificación de bienvenida asíncrona
    await sendWelcomeNotification(uid, email || phoneNumber || '');
    
    // ✅ BEST PRACTICE: Analytics de conversión
    await admin.firestore().collection('analytics').add({
      event: 'user_created',
      userId: uid,
      userType: 'passenger',
      registrationMethod: email ? 'email' : 'phone',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      metadata: {
        platform: 'unknown',
        source: 'organic',
      },
    });
    
    const duration = Date.now() - startTime;
    logger.info('User creation completed', {
      uid,
      duration: `${duration}ms`,
    });
    
  } catch (error) {
    logger.error('User creation failed', {
      error: error.message,
      uid: event.data.uid,
      stack: error.stack,
    });
    
    // No rethrow - user creation should not fail due to post-processing errors
  }
});
```

### Role Management Function

```typescript
// src/auth/setUserRole.ts
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { logger } from '../utils/logger';
import { validateInput } from '../utils/validation';
import { RolePermissions, UserType } from '../types/user.types';

// ✅ BEST PRACTICE: Schema de validación
const setUserRoleSchema = {
  type: 'object',
  properties: {
    targetUserId: { type: 'string', minLength: 1 },
    newRole: { type: 'string', enum: ['passenger', 'driver', 'admin'] },
    reason: { type: 'string', minLength: 1 },
  },
  required: ['targetUserId', 'newRole', 'reason'],
  additionalProperties: false,
};

export const setUserRole = onCall({
  region: 'us-central1',
  memory: '256MiB',
  timeoutSeconds: 30,
  enforceAppCheck: true,
}, async (request) => {
  const startTime = Date.now();
  
  try {
    // ✅ BEST PRACTICE: Validación de autenticación
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    // ✅ BEST PRACTICE: Validación de autorización
    const currentUserRole = request.auth.token.role;
    if (currentUserRole !== 'admin') {
      throw new HttpsError(
        'permission-denied',
        'Only administrators can change user roles'
      );
    }
    
    // ✅ BEST PRACTICE: Validación de entrada
    const validationResult = validateInput(request.data, setUserRoleSchema);
    if (!validationResult.valid) {
      throw new HttpsError('invalid-argument', validationResult.error);
    }
    
    const { targetUserId, newRole, reason } = request.data;
    
    // ✅ BEST PRACTICE: Verificar que el usuario objetivo existe
    const targetUser = await admin.auth().getUser(targetUserId);
    if (!targetUser) {
      throw new HttpsError('not-found', 'Target user not found');
    }
    
    // ✅ BEST PRACTICE: Obtener permisos para el nuevo rol
    const permissions = RolePermissions[newRole as UserType];
    if (!permissions) {
      throw new HttpsError('invalid-argument', `Invalid role: ${newRole}`);
    }
    
    // ✅ BEST PRACTICE: Transacción para consistencia
    await admin.firestore().runTransaction(async (transaction) => {
      const userRef = admin.firestore().collection('users').doc(targetUserId);
      const userDoc = await transaction.get(userRef);
      
      if (!userDoc.exists) {
        throw new HttpsError('not-found', 'User document not found');
      }
      
      const currentData = userDoc.data()!;
      const oldRole = currentData.userType;
      
      // ✅ BEST PRACTICE: Actualizar documento de usuario
      transaction.update(userRef, {
        userType: newRole,
        'metadata.updatedAt': admin.firestore.FieldValue.serverTimestamp(),
        'metadata.lastRoleChange': {
          from: oldRole,
          to: newRole,
          changedBy: request.auth!.uid,
          reason,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        },
      });
      
      // ✅ BEST PRACTICE: Crear log de auditoría
      const auditRef = admin.firestore().collection('audit_logs').doc();
      transaction.set(auditRef, {
        action: 'role_changed',
        performedBy: request.auth!.uid,
        targetUser: targetUserId,
        oldData: { role: oldRole },
        newData: { role: newRole },
        reason,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        metadata: {
          ip: request.rawRequest.ip,
          userAgent: request.rawRequest.headers['user-agent'],
        },
      });
    });
    
    // ✅ BEST PRACTICE: Actualizar custom claims
    await admin.auth().setCustomUserClaims(targetUserId, {
      role: newRole,
      verified: newRole === 'driver' ? false : true, // Drivers need verification
      permissions,
      lastUpdated: Date.now(),
    });
    
    // ✅ BEST PRACTICE: Notificar al usuario del cambio
    await admin.firestore()
      .collection('users')
      .doc(targetUserId)
      .collection('notifications')
      .add({
        type: 'role_changed',
        title: 'Rol actualizado',
        message: `Tu rol ha sido cambiado a ${newRole}`,
        data: { newRole, changedBy: request.auth.uid },
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    
    const duration = Date.now() - startTime;
    logger.info('User role changed successfully', {
      targetUserId,
      newRole,
      changedBy: request.auth.uid,
      duration: `${duration}ms`,
    });
    
    return {
      success: true,
      newRole,
      permissions,
      message: 'User role updated successfully',
    };
    
  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error('Role change failed', {
      error: error.message,
      targetUserId: request.data?.targetUserId,
      requestedBy: request.auth?.uid,
      duration: `${duration}ms`,
    });
    
    if (error instanceof HttpsError) {
      throw error;
    }
    
    throw new HttpsError('internal', 'Internal server error');
  }
});
```

### Driver Verification Function

```typescript
// src/auth/verifyDriver.ts
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { logger } from '../utils/logger';
import { validateDriverDocuments } from '../utils/validation';
import { sendDriverVerificationResult } from '../notifications/sendEmail';

export const verifyDriver = onCall({
  region: 'us-central1',
  memory: '512MiB',
  timeoutSeconds: 60,
  enforceAppCheck: true,
}, async (request) => {
  const startTime = Date.now();
  
  try {
    // ✅ BEST PRACTICE: Verificación de permisos de admin
    if (!request.auth || request.auth.token.role !== 'admin') {
      throw new HttpsError(
        'permission-denied',
        'Only administrators can verify drivers'
      );
    }
    
    const { driverId, action, reason, rejectionReasons } = request.data;
    
    if (!driverId || !['approve', 'reject'].includes(action)) {
      throw new HttpsError('invalid-argument', 'Invalid verification data');
    }
    
    // ✅ BEST PRACTICE: Obtener datos del conductor
    const driverDoc = await admin.firestore()
      .collection('drivers')
      .doc(driverId)
      .get();
    
    if (!driverDoc.exists) {
      throw new HttpsError('not-found', 'Driver not found');
    }
    
    const driverData = driverDoc.data()!;
    
    if (action === 'approve') {
      // ✅ BEST PRACTICE: Validar documentos antes de aprobar
      const documentsValid = await validateDriverDocuments(driverData.documents);
      
      if (!documentsValid.valid) {
        throw new HttpsError(
          'failed-precondition',
          `Documents validation failed: ${documentsValid.errors.join(', ')}`
        );
      }
      
      // ✅ BEST PRACTICE: Transacción para aprobación
      await admin.firestore().runTransaction(async (transaction) => {
        const driverRef = admin.firestore().collection('drivers').doc(driverId);
        const userRef = admin.firestore().collection('users').doc(driverId);
        
        // Actualizar estado del conductor
        transaction.update(driverRef, {
          status: 'approved',
          verificationStatus: 'verified',
          approvedAt: admin.firestore.FieldValue.serverTimestamp(),
          approvedBy: request.auth!.uid,
          approvalReason: reason,
        });
        
        // Actualizar usuario
        transaction.update(userRef, {
          userType: 'driver',
          'metadata.updatedAt': admin.firestore.FieldValue.serverTimestamp(),
        });
        
        // Crear log de auditoría
        const auditRef = admin.firestore().collection('audit_logs').doc();
        transaction.set(auditRef, {
          action: 'driver_approved',
          performedBy: request.auth!.uid,
          targetUser: driverId,
          reason,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      
      // ✅ BEST PRACTICE: Actualizar custom claims
      await admin.auth().setCustomUserClaims(driverId, {
        role: 'driver',
        verified: true,
        permissions: [
          'trips:accept',
          'trips:complete',
          'earnings:view',
          'documents:upload',
        ],
        lastUpdated: Date.now(),
      });
      
      // ✅ BEST PRACTICE: Notificación de aprobación
      await sendDriverVerificationResult(driverId, 'approved', reason);
      
    } else if (action === 'reject') {
      // ✅ BEST PRACTICE: Manejo de rechazo
      await admin.firestore().collection('drivers').doc(driverId).update({
        status: 'rejected',
        verificationStatus: 'rejected',
        rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
        rejectedBy: request.auth.uid,
        rejectionReason: reason,
        rejectionReasons: rejectionReasons || [],
      });
      
      // ✅ BEST PRACTICE: Notificación de rechazo
      await sendDriverVerificationResult(driverId, 'rejected', reason, rejectionReasons);
    }
    
    const duration = Date.now() - startTime;
    logger.info('Driver verification completed', {
      driverId,
      action,
      verifiedBy: request.auth.uid,
      duration: `${duration}ms`,
    });
    
    return {
      success: true,
      action,
      driverId,
      message: `Driver ${action}d successfully`,
    };
    
  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error('Driver verification failed', {
      error: error.message,
      driverId: request.data?.driverId,
      action: request.data?.action,
      verifiedBy: request.auth?.uid,
      duration: `${duration}ms`,
    });
    
    if (error instanceof HttpsError) {
      throw error;
    }
    
    throw new HttpsError('internal', 'Driver verification failed');
  }
});
```

---

## 🚖 TRIP MANAGEMENT FUNCTIONS

### Create Trip Function

```typescript
// src/trips/createTrip.ts
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { logger } from '../utils/logger';
import { validateTripRequest } from '../utils/validation';
import { calculateEstimatedFare } from '../utils/pricing';
import { findNearbyDrivers } from '../utils/location';
import { rateLimiter } from '../utils/security';

export const createTrip = onCall({
  region: 'us-central1',
  memory: '512MiB',
  timeoutSeconds: 30,
  enforceAppCheck: true,
}, async (request) => {
  const startTime = Date.now();
  
  try {
    // ✅ BEST PRACTICE: Validación de autenticación
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    const userId = request.auth.uid;
    const userRole = request.auth.token.role;
    
    // ✅ BEST PRACTICE: Verificar permisos
    if (userRole !== 'passenger') {
      throw new HttpsError(
        'permission-denied',
        'Only passengers can create trip requests'
      );
    }
    
    // ✅ BEST PRACTICE: Rate limiting
    const rateLimitResult = await rateLimiter.checkLimit(
      userId,
      'createTrip',
      { maxRequests: 10, timeWindow: 3600000 } // 10 requests per hour
    );
    
    if (!rateLimitResult.allowed) {
      throw new HttpsError(
        'resource-exhausted',
        `Rate limit exceeded. Try again in ${rateLimitResult.resetTime} seconds`
      );
    }
    
    // ✅ BEST PRACTICE: Validación de entrada
    const validationResult = validateTripRequest(request.data);
    if (!validationResult.valid) {
      throw new HttpsError('invalid-argument', validationResult.error);
    }
    
    const {
      pickup,
      destination,
      vehicleType,
      scheduledTime,
      notes,
      paymentMethod,
      maxWaitTime,
    } = request.data;
    
    // ✅ BEST PRACTICE: Verificar usuario activo
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();
    
    if (!userDoc.exists || userDoc.data()?.status !== 'active') {
      throw new HttpsError('failed-precondition', 'User account is not active');
    }
    
    // ✅ BEST PRACTICE: Verificar trips activos
    const activeTripsQuery = await admin.firestore()
      .collection('trips')
      .where('passengerId', '==', userId)
      .where('status', 'in', ['requested', 'accepted', 'started'])
      .limit(1)
      .get();
    
    if (!activeTripsQuery.empty) {
      throw new HttpsError(
        'failed-precondition',
        'You already have an active trip'
      );
    }
    
    // ✅ BEST PRACTICE: Calcular tarifa estimada
    const estimatedFare = await calculateEstimatedFare({
      pickup,
      destination,
      vehicleType,
      scheduledTime,
    });
    
    // ✅ BEST PRACTICE: Encontrar conductores cercanos
    const nearbyDrivers = await findNearbyDrivers({
      location: pickup,
      vehicleType,
      radiusKm: 10,
      maxDrivers: 20,
    });
    
    if (nearbyDrivers.length === 0) {
      throw new HttpsError(
        'unavailable',
        'No drivers available in your area right now'
      );
    }
    
    // ✅ BEST PRACTICE: Crear trip con ID único
    const tripId = admin.firestore().collection('trips').doc().id;
    const tripData = {
      id: tripId,
      passengerId: userId,
      driverId: null,
      status: 'requested',
      vehicleType,
      pickup: {
        latitude: pickup.latitude,
        longitude: pickup.longitude,
        address: pickup.address,
        placeId: pickup.placeId || null,
      },
      destination: {
        latitude: destination.latitude,
        longitude: destination.longitude,
        address: destination.address,
        placeId: destination.placeId || null,
      },
      pricing: {
        estimatedFare: estimatedFare.amount,
        baseFare: estimatedFare.baseFare,
        distanceFare: estimatedFare.distanceFare,
        timeFare: estimatedFare.timeFare,
        surgeFare: estimatedFare.surgeFare || 0,
        finalFare: null,
        currency: 'PEN',
      },
      timeline: {
        requestedAt: admin.firestore.FieldValue.serverTimestamp(),
        acceptedAt: null,
        startedAt: null,
        arrivedAt: null,
        completedAt: null,
        cancelledAt: null,
      },
      metadata: {
        estimatedDistance: estimatedFare.distance,
        estimatedDuration: estimatedFare.duration,
        scheduledTime: scheduledTime ? admin.firestore.Timestamp.fromDate(new Date(scheduledTime)) : null,
        notes: notes || '',
        paymentMethod: paymentMethod || 'cash',
        maxWaitTime: maxWaitTime || 300, // 5 minutes default
        nearbyDriversCount: nearbyDrivers.length,
        requestSource: 'mobile_app',
        appVersion: request.rawRequest.headers['x-app-version'] || 'unknown',
      },
      location: {
        currentLatitude: pickup.latitude,
        currentLongitude: pickup.longitude,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      },
    };
    
    // ✅ BEST PRACTICE: Transacción para consistencia
    await admin.firestore().runTransaction(async (transaction) => {
      const tripRef = admin.firestore().collection('trips').doc(tripId);
      transaction.set(tripRef, tripData);
      
      // Crear negotiation document
      const negotiationRef = admin.firestore()
        .collection('negotiations')
        .doc(tripId);
      
      transaction.set(negotiationRef, {
        tripId,
        passengerId: userId,
        status: 'waitingDriver',
        offers: [],
        finalPrice: null,
        acceptedBy: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + (maxWaitTime || 300) * 1000)
        ),
      });
      
      // Actualizar estadísticas del usuario
      const userStatsRef = admin.firestore()
        .collection('users')
        .doc(userId)
        .collection('statistics')
        .doc('summary');
      
      transaction.update(userStatsRef, {
        totalTripsRequested: admin.firestore.FieldValue.increment(1),
        lastTripRequestedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    
    // ✅ BEST PRACTICE: Notificar conductores cercanos (async)
    const notificationPromises = nearbyDrivers.map(driver =>
      admin.firestore()
        .collection('driver_notifications')
        .add({
          driverId: driver.id,
          tripId,
          type: 'trip_request',
          data: {
            pickup: pickup.address,
            destination: destination.address,
            estimatedFare: estimatedFare.amount,
            distance: driver.distance,
          },
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: admin.firestore.Timestamp.fromDate(
            new Date(Date.now() + (maxWaitTime || 300) * 1000)
          ),
        })
    );
    
    // No await - ejecutar en paralelo
    Promise.all(notificationPromises).catch(error => {
      logger.error('Failed to notify drivers', {
        tripId,
        error: error.message,
      });
    });
    
    // ✅ BEST PRACTICE: Analytics tracking
    await admin.firestore().collection('analytics').add({
      event: 'trip_requested',
      userId,
      tripId,
      data: {
        vehicleType,
        estimatedFare: estimatedFare.amount,
        distance: estimatedFare.distance,
        nearbyDrivers: nearbyDrivers.length,
        requestTime: new Date().toISOString(),
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    const duration = Date.now() - startTime;
    logger.info('Trip created successfully', {
      tripId,
      passengerId: userId,
      vehicleType,
      estimatedFare: estimatedFare.amount,
      nearbyDrivers: nearbyDrivers.length,
      duration: `${duration}ms`,
    });
    
    return {
      success: true,
      tripId,
      estimatedFare: estimatedFare.amount,
      estimatedDuration: estimatedFare.duration,
      nearbyDrivers: nearbyDrivers.length,
      expiresAt: new Date(Date.now() + (maxWaitTime || 300) * 1000).toISOString(),
    };
    
  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error('Trip creation failed', {
      error: error.message,
      userId: request.auth?.uid,
      requestData: JSON.stringify(request.data),
      duration: `${duration}ms`,
    });
    
    if (error instanceof HttpsError) {
      throw error;
    }
    
    throw new HttpsError('internal', 'Failed to create trip request');
  }
});
```

### Accept Trip Function

```typescript
// src/trips/acceptTrip.ts
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { logger } from '../utils/logger';
import { sendTripNotification } from '../notifications/sendPushNotification';
import { validateDriverAvailability } from '../utils/validation';

export const acceptTrip = onCall({
  region: 'us-central1',
  memory: '256MiB',
  timeoutSeconds: 30,
}, async (request) => {
  const startTime = Date.now();
  
  try {
    // ✅ BEST PRACTICE: Validación de conductor
    if (!request.auth || request.auth.token.role !== 'driver') {
      throw new HttpsError(
        'permission-denied',
        'Only verified drivers can accept trips'
      );
    }
    
    if (!request.auth.token.verified) {
      throw new HttpsError(
        'failed-precondition',
        'Driver must be verified to accept trips'
      );
    }
    
    const driverId = request.auth.uid;
    const { tripId, offerPrice } = request.data;
    
    if (!tripId) {
      throw new HttpsError('invalid-argument', 'Trip ID is required');
    }
    
    // ✅ BEST PRACTICE: Verificar disponibilidad del conductor
    const driverAvailable = await validateDriverAvailability(driverId);
    if (!driverAvailable.available) {
      throw new HttpsError(
        'failed-precondition',
        driverAvailable.reason || 'Driver is not available'
      );
    }
    
    // ✅ BEST PRACTICE: Transacción atómica para accept
    const result = await admin.firestore().runTransaction(async (transaction) => {
      const tripRef = admin.firestore().collection('trips').doc(tripId);
      const tripDoc = await transaction.get(tripRef);
      
      if (!tripDoc.exists) {
        throw new HttpsError('not-found', 'Trip not found');
      }
      
      const tripData = tripDoc.data()!;
      
      // Verificar estado del trip
      if (tripData.status !== 'requested') {
        throw new HttpsError(
          'failed-precondition',
          `Trip is no longer available (status: ${tripData.status})`
        );
      }
      
      // Verificar expiración
      const expiresAt = tripData.metadata?.expiresAt;
      if (expiresAt && expiresAt.toDate() < new Date()) {
        throw new HttpsError('deadline-exceeded', 'Trip request has expired');
      }
      
      // ✅ BEST PRACTICE: Obtener datos del conductor
      const driverRef = admin.firestore().collection('drivers').doc(driverId);
      const driverDoc = await transaction.get(driverRef);
      
      if (!driverDoc.exists) {
        throw new HttpsError('not-found', 'Driver profile not found');
      }
      
      const driverData = driverDoc.data()!;
      
      // ✅ BEST PRACTICE: Actualizar trip con conductor asignado
      const updateData: any = {
        driverId,
        status: 'accepted',
        'timeline.acceptedAt': admin.firestore.FieldValue.serverTimestamp(),
        'metadata.acceptedOfferPrice': offerPrice || tripData.pricing.estimatedFare,
        'metadata.driverInfo': {
          name: `${driverData.profile.firstName} ${driverData.profile.lastName}`,
          phone: driverData.phone,
          vehicleInfo: driverData.vehicle,
          rating: driverData.rating || 5.0,
        },
      };
      
      // Si hay oferta de precio diferente
      if (offerPrice && offerPrice !== tripData.pricing.estimatedFare) {
        updateData['pricing.negotiatedFare'] = offerPrice;
        updateData['pricing.finalFare'] = offerPrice;
      } else {
        updateData['pricing.finalFare'] = tripData.pricing.estimatedFare;
      }
      
      transaction.update(tripRef, updateData);
      
      // ✅ BEST PRACTICE: Actualizar estado del conductor
      transaction.update(driverRef, {
        status: 'busy',
        currentTripId: tripId,
        'metadata.lastTripAcceptedAt': admin.firestore.FieldValue.serverTimestamp(),
        'statistics.totalTripsAccepted': admin.firestore.FieldValue.increment(1),
      });
      
      // ✅ BEST PRACTICE: Actualizar negotiation
      const negotiationRef = admin.firestore().collection('negotiations').doc(tripId);
      transaction.update(negotiationRef, {
        status: 'accepted',
        acceptedBy: driverId,
        finalPrice: offerPrice || tripData.pricing.estimatedFare,
        acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      return {
        tripData,
        driverData,
        finalPrice: offerPrice || tripData.pricing.estimatedFare,
      };
    });
    
    // ✅ BEST PRACTICE: Notificar al pasajero (async)
    await sendTripNotification({
      userId: result.tripData.passengerId,
      type: 'trip_accepted',
      data: {
        tripId,
        driverName: result.driverData.profile.firstName,
        vehicleInfo: result.driverData.vehicle,
        estimatedArrival: 5, // minutes
      },
    });
    
    // ✅ BEST PRACTICE: Cancelar notificaciones a otros conductores
    const otherDriverNotifications = admin.firestore()
      .collection('driver_notifications')
      .where('tripId', '==', tripId)
      .where('driverId', '!=', driverId);
    
    const notificationsSnapshot = await otherDriverNotifications.get();
    const batch = admin.firestore().batch();
    
    notificationsSnapshot.docs.forEach(doc => {
      batch.update(doc.ref, { status: 'cancelled' });
    });
    
    await batch.commit();
    
    const duration = Date.now() - startTime;
    logger.info('Trip accepted successfully', {
      tripId,
      driverId,
      passengerId: result.tripData.passengerId,
      finalPrice: result.finalPrice,
      duration: `${duration}ms`,
    });
    
    return {
      success: true,
      tripId,
      driverInfo: result.driverData.profile,
      vehicleInfo: result.driverData.vehicle,
      finalPrice: result.finalPrice,
      estimatedArrival: 5,
    };
    
  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error('Trip acceptance failed', {
      error: error.message,
      tripId: request.data?.tripId,
      driverId: request.auth?.uid,
      duration: `${duration}ms`,
    });
    
    if (error instanceof HttpsError) {
      throw error;
    }
    
    throw new HttpsError('internal', 'Failed to accept trip');
  }
});
```

---

## 💳 PAYMENT FUNCTIONS

### Process Payment Function

```typescript
// src/payments/processPayment.ts
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { logger } from '../utils/logger';
import { MercadoPagoService } from '../utils/external-apis';
import { validatePaymentData } from '../utils/validation';
import { calculateCommissions } from '../utils/pricing';

export const processPayment = onCall({
  region: 'us-central1',
  memory: '512MiB',
  timeoutSeconds: 60,
}, async (request) => {
  const startTime = Date.now();
  
  try {
    // ✅ BEST PRACTICE: Validación de autenticación
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    const userId = request.auth.uid;
    const { tripId, paymentMethod, paymentData } = request.data;
    
    // ✅ BEST PRACTICE: Validación de entrada
    const validationResult = validatePaymentData({
      tripId,
      paymentMethod,
      paymentData,
    });
    
    if (!validationResult.valid) {
      throw new HttpsError('invalid-argument', validationResult.error);
    }
    
    // ✅ BEST PRACTICE: Obtener datos del trip
    const tripDoc = await admin.firestore()
      .collection('trips')
      .doc(tripId)
      .get();
    
    if (!tripDoc.exists) {
      throw new HttpsError('not-found', 'Trip not found');
    }
    
    const tripData = tripDoc.data()!;
    
    // Verificar autorización
    if (tripData.passengerId !== userId) {
      throw new HttpsError(
        'permission-denied',
        'You can only pay for your own trips'
      );
    }
    
    // Verificar estado del trip
    if (tripData.status !== 'completed') {
      throw new HttpsError(
        'failed-precondition',
        'Trip must be completed before payment'
      );
    }
    
    // Verificar si ya fue pagado
    if (tripData.payment?.status === 'paid') {
      throw new HttpsError(
        'already-exists',
        'Trip has already been paid'
      );
    }
    
    const amount = tripData.pricing.finalFare;
    const currency = tripData.pricing.currency || 'PEN';
    
    let paymentResult;
    
    if (paymentMethod === 'cash') {
      // ✅ BEST PRACTICE: Pago en efectivo
      paymentResult = {
        success: true,
        paymentId: `cash_${tripId}_${Date.now()}`,
        status: 'paid',
        method: 'cash',
        amount,
        currency,
        paidAt: new Date().toISOString(),
      };
      
    } else if (paymentMethod === 'card' || paymentMethod === 'digital_wallet') {
      // ✅ BEST PRACTICE: Procesamiento con MercadoPago
      const mercadoPago = new MercadoPagoService();
      
      paymentResult = await mercadoPago.processPayment({
        amount,
        currency,
        paymentMethodId: paymentData.paymentMethodId,
        token: paymentData.token,
        installments: paymentData.installments || 1,
        description: `Viaje OasisTaxi - ${tripData.pickup.address} a ${tripData.destination.address}`,
        externalReference: tripId,
        payer: {
          email: request.auth.token.email || paymentData.email,
          identification: paymentData.identification,
        },
        metadata: {
          tripId,
          passengerId: userId,
          driverId: tripData.driverId,
        },
      });
      
      if (!paymentResult.success) {
        throw new HttpsError(
          'payment-required',
          paymentResult.error || 'Payment processing failed'
        );
      }
      
    } else {
      throw new HttpsError('invalid-argument', `Unsupported payment method: ${paymentMethod}`);
    }
    
    // ✅ BEST PRACTICE: Calcular comisiones
    const commissions = calculateCommissions(amount);
    
    // ✅ BEST PRACTICE: Transacción para actualizar todos los documentos
    await admin.firestore().runTransaction(async (transaction) => {
      // Actualizar trip con información de pago
      const tripRef = admin.firestore().collection('trips').doc(tripId);
      transaction.update(tripRef, {
        'payment.status': 'paid',
        'payment.method': paymentMethod,
        'payment.paymentId': paymentResult.paymentId,
        'payment.amount': amount,
        'payment.currency': currency,
        'payment.paidAt': admin.firestore.FieldValue.serverTimestamp(),
        'payment.commissions': commissions,
        'metadata.updatedAt': admin.firestore.FieldValue.serverTimestamp(),
      });
      
      // Crear documento de pago
      const paymentRef = admin.firestore().collection('payments').doc();
      transaction.set(paymentRef, {
        id: paymentRef.id,
        tripId,
        passengerId: userId,
        driverId: tripData.driverId,
        amount,
        currency,
        method: paymentMethod,
        status: 'completed',
        externalPaymentId: paymentResult.paymentId,
        commissions,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        metadata: {
          processingDuration: Date.now() - startTime,
          ipAddress: request.rawRequest.ip,
          userAgent: request.rawRequest.headers['user-agent'],
        },
      });
      
      // Actualizar wallet del conductor
      const driverWalletRef = admin.firestore()
        .collection('wallets')
        .doc(tripData.driverId);
      
      transaction.update(driverWalletRef, {
        'balance': admin.firestore.FieldValue.increment(commissions.driverAmount),
        'totalEarnings': admin.firestore.FieldValue.increment(commissions.driverAmount),
        'lastUpdated': admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      
      // Crear transacción en wallet del conductor
      const driverTransactionRef = admin.firestore()
        .collection('wallets')
        .doc(tripData.driverId)
        .collection('transactions')
        .doc();
      
      transaction.set(driverTransactionRef, {
        id: driverTransactionRef.id,
        type: 'trip_earning',
        amount: commissions.driverAmount,
        currency,
        tripId,
        paymentId: paymentRef.id,
        status: 'completed',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      // Actualizar estadísticas del pasajero
      const passengerStatsRef = admin.firestore()
        .collection('users')
        .doc(userId)
        .collection('statistics')
        .doc('summary');
      
      transaction.update(passengerStatsRef, {
        'totalPaid': admin.firestore.FieldValue.increment(amount),
        'totalTrips': admin.firestore.FieldValue.increment(1),
        'lastPaymentAt': admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      
      // Actualizar estadísticas del conductor
      const driverStatsRef = admin.firestore()
        .collection('users')
        .doc(tripData.driverId)
        .collection('statistics')
        .doc('summary');
      
      transaction.update(driverStatsRef, {
        'totalEarnings': admin.firestore.FieldValue.increment(commissions.driverAmount),
        'totalTripsCompleted': admin.firestore.FieldValue.increment(1),
        'lastEarningAt': admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    });
    
    // ✅ BEST PRACTICE: Analytics de payment
    await admin.firestore().collection('analytics').add({
      event: 'payment_completed',
      userId,
      tripId,
      data: {
        amount,
        currency,
        method: paymentMethod,
        driverEarning: commissions.driverAmount,
        companyCommission: commissions.companyAmount,
        processingTime: Date.now() - startTime,
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    const duration = Date.now() - startTime;
    logger.info('Payment processed successfully', {
      tripId,
      paymentId: paymentResult.paymentId,
      amount,
      method: paymentMethod,
      passengerId: userId,
      driverId: tripData.driverId,
      duration: `${duration}ms`,
    });
    
    return {
      success: true,
      paymentId: paymentResult.paymentId,
      amount,
      currency,
      method: paymentMethod,
      driverEarning: commissions.driverAmount,
      receipt: {
        tripId,
        amount,
        currency,
        method: paymentMethod,
        paidAt: new Date().toISOString(),
        commissions,
      },
    };
    
  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error('Payment processing failed', {
      error: error.message,
      tripId: request.data?.tripId,
      userId: request.auth?.uid,
      paymentMethod: request.data?.paymentMethod,
      duration: `${duration}ms`,
    });
    
    // ✅ BEST PRACTICE: Registrar fallo de pago
    if (request.data?.tripId) {
      await admin.firestore()
        .collection('trips')
        .doc(request.data.tripId)
        .update({
          'payment.status': 'failed',
          'payment.error': error.message,
          'payment.failedAt': admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    
    if (error instanceof HttpsError) {
      throw error;
    }
    
    throw new HttpsError('internal', 'Payment processing failed');
  }
});
```

---

## 📱 NOTIFICATION FUNCTIONS

### Send Push Notification Function

```typescript
// src/notifications/sendPushNotification.ts
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { logger } from '../utils/logger';
import { validateNotificationData } from '../utils/validation';

interface NotificationData {
  userId: string;
  type: string;
  title: string;
  body: string;
  data?: Record<string, string>;
  priority?: 'high' | 'normal';
  sound?: string;
  badge?: number;
  imageUrl?: string;
}

export const sendPushNotification = onCall({
  region: 'us-central1',
  memory: '256MiB',
  timeoutSeconds: 30,
}, async (request) => {
  const startTime = Date.now();
  
  try {
    // ✅ BEST PRACTICE: Validación de admin o sistema
    if (!request.auth || !['admin', 'system'].includes(request.auth.token.role)) {
      throw new HttpsError(
        'permission-denied',
        'Only admin or system can send push notifications'
      );
    }
    
    const notificationData: NotificationData = request.data;
    
    // ✅ BEST PRACTICE: Validación de datos
    const validationResult = validateNotificationData(notificationData);
    if (!validationResult.valid) {
      throw new HttpsError('invalid-argument', validationResult.error);
    }
    
    const { userId, type, title, body, data, priority, sound, badge, imageUrl } = notificationData;
    
    // ✅ BEST PRACTICE: Obtener tokens FCM del usuario
    const tokensSnapshot = await admin.firestore()
      .collection('users')
      .doc(userId)
      .collection('fcm_tokens')
      .where('active', '==', true)
      .get();
    
    if (tokensSnapshot.empty) {
      logger.warn('No FCM tokens found for user', { userId });
      return { success: false, reason: 'No active FCM tokens found' };
    }
    
    const tokens = tokensSnapshot.docs.map(doc => doc.data().token);
    
    // ✅ BEST PRACTICE: Configurar mensaje multi-platform
    const message = {
      notification: {
        title,
        body,
        imageUrl,
      },
      data: {
        type,
        userId,
        timestamp: Date.now().toString(),
        ...data,
      },
      android: {
        priority: priority as 'high' | 'normal' || 'high',
        notification: {
          icon: 'ic_notification',
          color: '#FF6B35',
          sound: sound || 'default',
          channelId: getChannelId(type),
          priority: priority as 'high' | 'normal' || 'high',
          defaultSound: true,
          defaultVibrateTimings: true,
          defaultLightSettings: true,
        },
        data: {
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title,
              body,
            },
            badge: badge || 1,
            sound: sound || 'default',
            category: getCategoryId(type),
            'mutable-content': 1,
          },
        },
        fcmOptions: {
          imageUrl,
        },
      },
      webpush: {
        notification: {
          title,
          body,
          icon: '/icons/icon-192x192.png',
          badge: '/icons/badge-72x72.png',
          image: imageUrl,
          requireInteraction: priority === 'high',
          vibrate: [200, 100, 200],
        },
        fcmOptions: {
          link: getDeepLink(type, data),
        },
      },
      tokens,
    };
    
    // ✅ BEST PRACTICE: Enviar notificación
    const response = await admin.messaging().sendMulticast(message);
    
    // ✅ BEST PRACTICE: Procesar respuestas
    const successCount = response.successCount;
    const failureCount = response.failureCount;
    const invalidTokens: string[] = [];
    
    if (failureCount > 0) {
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const error = resp.error!;
          if (error.code === 'messaging/invalid-registration-token' ||
              error.code === 'messaging/registration-token-not-registered') {
            invalidTokens.push(tokens[idx]);
          }
        }
      });
      
      // ✅ BEST PRACTICE: Limpiar tokens inválidos
      if (invalidTokens.length > 0) {
        await cleanupInvalidTokens(userId, invalidTokens);
      }
    }
    
    // ✅ BEST PRACTICE: Guardar notificación en historial
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .collection('notifications')
      .add({
        type,
        title,
        body,
        data: data || {},
        read: false,
        sent: true,
        successCount,
        failureCount,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    
    const duration = Date.now() - startTime;
    logger.info('Push notification sent', {
      userId,
      type,
      successCount,
      failureCount,
      invalidTokens: invalidTokens.length,
      duration: `${duration}ms`,
    });
    
    return {
      success: successCount > 0,
      successCount,
      failureCount,
      invalidTokensCleaned: invalidTokens.length,
    };
    
  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error('Push notification failed', {
      error: error.message,
      userId: request.data?.userId,
      type: request.data?.type,
      duration: `${duration}ms`,
    });
    
    if (error instanceof HttpsError) {
      throw error;
    }
    
    throw new HttpsError('internal', 'Failed to send push notification');
  }
});

// ✅ BEST PRACTICE: Helper functions
function getChannelId(type: string): string {
  const channels = {
    trip_request: 'trip_notifications',
    trip_update: 'trip_notifications',
    payment: 'payment_notifications',
    promotion: 'marketing_notifications',
    system: 'system_notifications',
  };
  
  return channels[type as keyof typeof channels] || 'default';
}

function getCategoryId(type: string): string {
  const categories = {
    trip_request: 'TRIP_REQUEST',
    trip_update: 'TRIP_UPDATE',
    payment: 'PAYMENT',
    promotion: 'PROMOTION',
    system: 'SYSTEM',
  };
  
  return categories[type as keyof typeof categories] || 'DEFAULT';
}

function getDeepLink(type: string, data?: Record<string, string>): string {
  const baseUrl = 'https://oasistaxi.app';
  
  switch (type) {
    case 'trip_request':
    case 'trip_update':
      return `${baseUrl}/trip/${data?.tripId || ''}`;
    case 'payment':
      return `${baseUrl}/payment/${data?.paymentId || ''}`;
    case 'promotion':
      return `${baseUrl}/promotions`;
    default:
      return baseUrl;
  }
}

async function cleanupInvalidTokens(userId: string, invalidTokens: string[]): Promise<void> {
  const batch = admin.firestore().batch();
  
  for (const token of invalidTokens) {
    const tokenDoc = admin.firestore()
      .collection('users')
      .doc(userId)
      .collection('fcm_tokens')
      .doc(token);
    
    batch.delete(tokenDoc);
  }
  
  await batch.commit();
  
  logger.info('Invalid FCM tokens cleaned up', {
    userId,
    tokensRemoved: invalidTokens.length,
  });
}
```

---

## 📊 ANALYTICS FUNCTIONS

### Process Analytics Function

```typescript
// src/analytics/processAnalytics.ts
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import * as admin from 'firebase-admin';
import { logger } from '../utils/logger';

// ✅ BEST PRACTICE: Trigger para procesar analytics en tiempo real
export const processAnalytics = onDocumentWritten({
  document: 'trips/{tripId}',
  region: 'us-central1',
  memory: '256MiB',
}, async (event) => {
  const startTime = Date.now();
  
  try {
    const { data, params } = event;
    const tripId = params.tripId;
    
    // Skip if document was deleted
    if (!data?.after.exists) {
      return;
    }
    
    const tripData = data.after.data();
    const previousData = data.before?.data();
    
    // ✅ BEST PRACTICE: Procesar solo cambios relevantes
    if (previousData && tripData.status === previousData.status) {
      return; // No status change, skip processing
    }
    
    const analyticsData = {
      event: `trip_${tripData.status}`,
      tripId,
      userId: tripData.passengerId,
      driverId: tripData.driverId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      data: {
        vehicleType: tripData.vehicleType,
        pickupLocation: tripData.pickup.address,
        destinationLocation: tripData.destination.address,
        estimatedFare: tripData.pricing.estimatedFare,
        finalFare: tripData.pricing.finalFare,
        paymentMethod: tripData.metadata.paymentMethod,
        duration: calculateTripDuration(tripData),
        distance: tripData.metadata.estimatedDistance,
      },
    };
    
    // ✅ BEST PRACTICE: Batch para múltiples operaciones
    const batch = admin.firestore().batch();
    
    // Agregar a analytics general
    const analyticsRef = admin.firestore().collection('analytics').doc();
    batch.set(analyticsRef, analyticsData);
    
    // ✅ BEST PRACTICE: Procesar métricas por estado
    switch (tripData.status) {
      case 'completed':
        await processCompletedTripAnalytics(batch, tripData);
        break;
      case 'cancelled':
        await processCancelledTripAnalytics(batch, tripData);
        break;
      case 'accepted':
        await processAcceptedTripAnalytics(batch, tripData);
        break;
    }
    
    await batch.commit();
    
    const duration = Date.now() - startTime;
    logger.info('Analytics processed', {
      tripId,
      status: tripData.status,
      event: analyticsData.event,
      duration: `${duration}ms`,
    });
    
  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error('Analytics processing failed', {
      error: error.message,
      tripId: event.params.tripId,
      duration: `${duration}ms`,
    });
  }
});

// ✅ BEST PRACTICE: Funciones específicas por tipo de analytics
async function processCompletedTripAnalytics(
  batch: FirebaseFirestore.WriteBatch,
  tripData: any
): Promise<void> {
  const today = new Date().toISOString().split('T')[0];
  
  // Métricas diarias
  const dailyMetricsRef = admin.firestore()
    .collection('analytics')
    .doc('daily_metrics')
    .collection('dates')
    .doc(today);
  
  batch.set(dailyMetricsRef, {
    date: today,
    tripsCompleted: admin.firestore.FieldValue.increment(1),
    totalRevenue: admin.firestore.FieldValue.increment(tripData.pricing.finalFare || 0),
    totalDistance: admin.firestore.FieldValue.increment(tripData.metadata.estimatedDistance || 0),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  
  // Métricas del conductor
  if (tripData.driverId) {
    const driverMetricsRef = admin.firestore()
      .collection('drivers')
      .doc(tripData.driverId)
      .collection('analytics')
      .doc('summary');
    
    batch.set(driverMetricsRef, {
      totalTripsCompleted: admin.firestore.FieldValue.increment(1),
      totalEarnings: admin.firestore.FieldValue.increment(
        calculateDriverEarning(tripData.pricing.finalFare || 0)
      ),
      averageTripDuration: calculateAverageDuration(tripData),
      lastTripCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }
  
  // Métricas del pasajero
  const passengerMetricsRef = admin.firestore()
    .collection('users')
    .doc(tripData.passengerId)
    .collection('analytics')
    .doc('summary');
  
  batch.set(passengerMetricsRef, {
    totalTripsCompleted: admin.firestore.FieldValue.increment(1),
    totalSpent: admin.firestore.FieldValue.increment(tripData.pricing.finalFare || 0),
    favoriteLocations: admin.firestore.FieldValue.arrayUnion(tripData.destination.address),
    lastTripCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}

async function processCancelledTripAnalytics(
  batch: FirebaseFirestore.WriteBatch,
  tripData: any
): Promise<void> {
  const today = new Date().toISOString().split('T')[0];
  
  // Métricas de cancelación
  const cancellationMetricsRef = admin.firestore()
    .collection('analytics')
    .doc('cancellation_metrics')
    .collection('dates')
    .doc(today);
  
  batch.set(cancellationMetricsRef, {
    date: today,
    totalCancellations: admin.firestore.FieldValue.increment(1),
    cancellationsByReason: {
      [tripData.cancellation?.reason || 'unknown']: admin.firestore.FieldValue.increment(1),
    },
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}

async function processAcceptedTripAnalytics(
  batch: FirebaseFirestore.WriteBatch,
  tripData: any
): Promise<void> {
  // Calcular tiempo de aceptación
  const requestedAt = tripData.timeline.requestedAt.toDate();
  const acceptedAt = tripData.timeline.acceptedAt.toDate();
  const acceptanceTime = acceptedAt.getTime() - requestedAt.getTime();
  
  const today = new Date().toISOString().split('T')[0];
  
  // Métricas de aceptación
  const acceptanceMetricsRef = admin.firestore()
    .collection('analytics')
    .doc('acceptance_metrics')
    .collection('dates')
    .doc(today);
  
  batch.set(acceptanceMetricsRef, {
    date: today,
    totalAcceptances: admin.firestore.FieldValue.increment(1),
    totalAcceptanceTime: admin.firestore.FieldValue.increment(acceptanceTime),
    averageAcceptanceTime: admin.firestore.FieldValue.increment(acceptanceTime / 1000), // seconds
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}

// ✅ BEST PRACTICE: Helper functions
function calculateTripDuration(tripData: any): number {
  if (!tripData.timeline.completedAt || !tripData.timeline.startedAt) {
    return 0;
  }
  
  const startedAt = tripData.timeline.startedAt.toDate();
  const completedAt = tripData.timeline.completedAt.toDate();
  
  return Math.round((completedAt.getTime() - startedAt.getTime()) / 1000); // seconds
}

function calculateDriverEarning(totalFare: number): number {
  const commissionRate = 0.20; // 20% company commission
  return totalFare * (1 - commissionRate);
}

function calculateAverageDuration(tripData: any): number {
  // This would need to be calculated based on historical data
  // For now, return current trip duration
  return calculateTripDuration(tripData);
}
```

---

## 🚀 DEPLOYMENT Y CI/CD

### Deployment Configuration

```typescript
// firebase.json - ✅ BEST PRACTICE: Configuración completa
{
  "functions": [
    {
      "source": "firebase/functions",
      "codebase": "default",
      "runtime": "nodejs18",
      "ignore": [
        "node_modules",
        ".git",
        "firebase-debug.log",
        "firebase-debug.*.log",
        "*.local"
      ],
      "predeploy": [
        "npm --prefix firebase/functions run build"
      ]
    }
  ]
}
```

### GitHub Actions CI/CD

```yaml
# .github/workflows/deploy-functions.yml
name: Deploy Cloud Functions

on:
  push:
    branches: [main]
    paths: ['firebase/functions/**']
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
          cache-dependency-path: firebase/functions/package-lock.json
      
      - name: Install dependencies
        working-directory: firebase/functions
        run: npm ci
      
      - name: Run tests
        working-directory: firebase/functions
        run: npm test
      
      - name: Build functions
        working-directory: firebase/functions
        run: npm run build
      
      - name: Setup Firebase CLI
        run: npm install -g firebase-tools
      
      - name: Authenticate to Firebase
        run: echo "${{ secrets.FIREBASE_SERVICE_ACCOUNT }}" | base64 -d > firebase-key.json
        env:
          GOOGLE_APPLICATION_CREDENTIALS: firebase-key.json
      
      - name: Deploy to Firebase
        run: firebase deploy --only functions --project oasis-taxi-peru
        env:
          GOOGLE_APPLICATION_CREDENTIALS: firebase-key.json
```

---

## 📋 CONCLUSIONES

### Beneficios de la Arquitectura Cloud Functions

#### Ventajas Técnicas
- **Escalabilidad automática**: De 0 a millones de requests sin configuración
- **Latencia optimizada**: Ejecución en edge locations globales
- **Integración nativa**: Acceso directo a todos los servicios Firebase
- **Gestión de estado**: Stateless design para máxima eficiencia

#### Ventajas de Negocio
- **Costo eficiente**: Pago solo por ejecuciones reales
- **Time to market**: Desarrollo acelerado sin gestión de infraestructura
- **Mantenimiento mínimo**: Google maneja toda la infraestructura subyacente
- **Seguridad enterprise**: Protección automática contra ataques DDoS y vulnerabilidades

### Próximos Pasos de Implementación

1. **Setup inicial**: Configurar proyecto Firebase Functions con TypeScript
2. **Functions core**: Implementar authentication y trip management functions
3. **Payment integration**: Configurar MercadoPago y procesamiento de pagos
4. **Notifications**: Implementar sistema completo de notificaciones
5. **Analytics**: Setup de tracking y reportes automatizados
6. **Testing**: Implementar unit tests y integration tests
7. **CI/CD**: Configurar deployment automático
8. **Monitoring**: Setup de observabilidad completa

---

**⚡ CLOUD FUNCTIONS GUIDE v1.0**  
**📅 ÚLTIMA ACTUALIZACIÓN: ENERO 2025**  
**🔄 PRÓXIMA REVISIÓN: MARZO 2025**

*Esta guía proporciona una implementación production-ready de Cloud Functions para OasisTaxi, optimizada para escalabilidad, seguridad y performance.*