# 🗄️ FIRESTORE DATA MODEL - OASISTAXI
## Documentación Completa del Modelo de Datos
### Versión: Production-Ready 1.0 - Enero 2025

---

## 📋 TABLA DE CONTENIDOS

1. [Introducción](#introducción)
2. [Filosofía de Diseño](#filosofía-de-diseño)
3. [Estructura General](#estructura-general)
4. [Colecciones Principales](#colecciones-principales)
5. [Subcolecciones](#subcolecciones)
6. [Esquemas de Documentos](#esquemas-de-documentos)
7. [Índices y Queries](#índices-y-queries)
8. [Relaciones entre Datos](#relaciones-entre-datos)
9. [Patrones de Acceso](#patrones-de-acceso)
10. [Optimización y Performance](#optimización-y-performance)
11. [Seguridad y Validación](#seguridad-y-validación)
12. [Migraciones y Versionado](#migraciones-y-versionado)

---

## 🎯 INTRODUCCIÓN

### Filosofía del Modelo de Datos

El modelo de datos de Firestore para OasisTaxi está diseñado siguiendo los principios NoSQL y las mejores prácticas de Google Cloud, optimizado para:

- 🚀 **Performance**: Queries rápidas con desnormalización estratégica
- 📈 **Escalabilidad**: Soporte para millones de usuarios y viajes simultáneos
- 🔒 **Seguridad**: Aislamiento de datos y acceso granular
- 💰 **Costo-eficiencia**: Minimización de lecturas/escrituras
- 🔄 **Real-time**: Actualizaciones en tiempo real para UX superior
- 🌍 **Multi-región**: Distribución global de datos

### Características Clave

```yaml
Diseño NoSQL Optimizado:
  - Documentos planos para máxima performance
  - Desnormalización controlada para reducir queries
  - Subcolecciones para organización jerárquica
  - Índices estratégicos para queries complejas
  - Triggers automáticos para consistencia

Capacidades Real-time:
  - Listeners de Firestore para updates instantáneos
  - Offline persistence para funcionalidad sin conexión
  - Conflict resolution automática
  - Sincronización bidireccional
```

---

## 🏗️ FILOSOFÍA DE DISEÑO

### Principios Fundamentales

#### 1. **Query-First Design**
```yaml
Principio: Diseñar collections basándose en queries necesarias
Implementación:
  - Analizar todos los patrones de acceso primero
  - Estructurar documents para minimizar queries
  - Usar composite indexes para filtros complejos
  - Desnormalizar datos frecuentemente accedidos
```

#### 2. **Flat Document Structure**
```yaml
Principio: Evitar objetos anidados profundos
Implementación:
  - Máximo 2 niveles de anidación
  - Usar referencias entre documents
  - Subcolecciones para datos relacionados
  - Arrays solo para listas pequeñas (<100 elementos)
```

#### 3. **Write-Heavy Optimization**
```yaml
Principio: Optimizar para escrituras frecuentes
Implementación:
  - Batch writes para operaciones múltiples
  - Atomic updates con transactions
  - Minimal document updates
  - Strategic denormalization
```

#### 4. **Real-time Friendly**
```yaml
Principio: Soporte nativo para real-time updates
Implementación:
  - Documents diseñados para listeners eficientes
  - Granular updates para minimizar data transfer
  - Status fields para state management
  - Timestamp fields para ordenamiento
```

---

## 🗂️ ESTRUCTURA GENERAL

### Jerarquía de Collections

```
firestore/
├── users/                          # Usuarios del sistema
│   ├── {userId}/
│   │   ├── statistics/             # Estadísticas del usuario
│   │   ├── notifications/          # Notificaciones personales
│   │   ├── fcm_tokens/            # Tokens FCM para push notifications
│   │   ├── payment_methods/        # Métodos de pago guardados
│   │   └── trip_history/          # Historial comprimido de viajes
│
├── drivers/                        # Conductores verificados
│   ├── {driverId}/
│   │   ├── documents/             # Documentos de verificación
│   │   ├── vehicle_history/       # Historial de vehículos
│   │   ├── earnings/              # Registro de ganancias
│   │   └── analytics/             # Métricas del conductor
│
├── trips/                          # Viajes (activos e históricos)
│   ├── {tripId}/
│   │   ├── location_updates/      # Updates de ubicación en tiempo real
│   │   ├── negotiations/          # Negociaciones de precio
│   │   ├── messages/              # Chat entre conductor y pasajero
│   │   └── events/                # Log de eventos del viaje
│
├── vehicles/                       # Registro de vehículos
├── payments/                       # Transacciones de pago
├── negotiations/                   # Negociaciones de precio activas
├── wallets/                        # Billeteras digitales
├── promotions/                     # Promociones y descuentos
├── admin_logs/                     # Logs de acciones administrativas
├── analytics/                      # Datos de analytics
├── configurations/                 # Configuraciones del sistema
└── emergency_contacts/             # Contactos de emergencia
```

### Convenciones de Nomenclatura

```yaml
Collections: snake_case (plural)
  ✅ users, trip_requests, payment_methods
  ❌ Users, TripRequest, paymentMethod

Documents: 
  - Auto-generated IDs para la mayoría
  - Meaningful IDs para configuraciones
  ✅ auto-generated: k8mN2pQ9rX3vB7
  ✅ meaningful: "default_pricing", "peru_config"

Fields: camelCase
  ✅ firstName, lastLoginAt, vehicleType
  ❌ first_name, last_login_at, vehicle_type

Timestamps: Usar FieldValue.serverTimestamp()
  ✅ createdAt: FieldValue.serverTimestamp()
  ❌ createdAt: new Date().toISOString()
```

---

## 👥 COLECCIONES PRINCIPALES

### 1. Users Collection

```typescript
// users/{userId}
interface UserDocument {
  // Identificación básica
  uid: string;
  email: string | null;
  phone: string | null;
  userType: 'passenger' | 'driver' | 'admin';
  status: 'active' | 'inactive' | 'suspended' | 'pending_verification';
  
  // Perfil personal
  profile: {
    firstName: string;
    lastName: string;
    avatar: string | null;
    dateOfBirth: Timestamp | null;
    gender: 'male' | 'female' | 'other' | 'prefer_not_say' | null;
    language: 'es' | 'en';
    emergencyContact: {
      name: string;
      phone: string;
      relationship: string;
    } | null;
  };
  
  // Ubicación actual
  location: {
    latitude: number | null;
    longitude: number | null;
    address: string;
    city: string;
    region: string;
    country: string;
    postalCode: string | null;
    lastUpdated: Timestamp | null;
  };
  
  // Preferencias del usuario
  preferences: {
    notifications: {
      push: boolean;
      email: boolean;
      sms: boolean;
    };
    theme: 'light' | 'dark' | 'system';
    currency: 'PEN' | 'USD';
    language: 'es' | 'en';
    defaultPaymentMethod: string | null;
    accessibility: {
      screenReader: boolean;
      highContrast: boolean;
      fontSize: 'small' | 'medium' | 'large';
    };
  };
  
  // Verificación y seguridad
  verification: {
    email: boolean;
    phone: boolean;
    identity: boolean;
    backgroundCheck: boolean | null;
  };
  
  // Ratings y reputación
  rating: {
    average: number;
    count: number;
    lastRatedAt: Timestamp | null;
  };
  
  // Metadata del sistema
  metadata: {
    createdAt: Timestamp;
    updatedAt: Timestamp;
    lastLoginAt: Timestamp | null;
    loginCount: number;
    platform: 'android' | 'ios' | 'web' | 'unknown';
    appVersion: string;
    deviceInfo: {
      model: string | null;
      osVersion: string | null;
      appVersion: string;
    };
    referralCode: string | null;
    referredBy: string | null;
  };
}
```

### 2. Drivers Collection

```typescript
// drivers/{driverId}
interface DriverDocument {
  // Información básica (referencia a users)
  userId: string;
  status: 'pending' | 'approved' | 'rejected' | 'suspended' | 'available' | 'busy' | 'offline';
  verificationStatus: 'pending' | 'under_review' | 'verified' | 'rejected';
  
  // Información personal adicional
  driverInfo: {
    licenseNumber: string;
    licenseExpiry: Timestamp;
    licenseClass: string;
    yearsExperience: number;
    previousEmployment: Array<{
      company: string;
      position: string;
      from: Timestamp;
      to: Timestamp;
    }>;
  };
  
  // Vehículo principal
  vehicle: {
    id: string; // Referencia a vehicles collection
    make: string;
    model: string;
    year: number;
    color: string;
    licensePlate: string;
    type: 'economy' | 'premium' | 'van' | 'motorcycle';
    capacity: number;
    amenities: string[];
    photos: string[];
  };
  
  // Documentos requeridos
  documents: {
    driverLicense: {
      url: string;
      status: 'pending' | 'approved' | 'rejected';
      uploadedAt: Timestamp;
      reviewedAt: Timestamp | null;
      reviewedBy: string | null;
      notes: string | null;
    };
    vehicleRegistration: {
      url: string;
      status: 'pending' | 'approved' | 'rejected';
      uploadedAt: Timestamp;
      expiryDate: Timestamp;
    };
    insurance: {
      url: string;
      status: 'pending' | 'approved' | 'rejected';
      uploadedAt: Timestamp;
      expiryDate: Timestamp;
      policyNumber: string;
    };
    criminalBackground: {
      url: string | null;
      status: 'pending' | 'approved' | 'rejected' | 'not_required';
      uploadedAt: Timestamp | null;
    };
    medicalCertificate: {
      url: string | null;
      status: 'pending' | 'approved' | 'rejected' | 'not_required';
      uploadedAt: Timestamp | null;
      expiryDate: Timestamp | null;
    };
  };
  
  // Información bancaria
  bankInfo: {
    accountNumber: string; // Encriptado
    bankName: string;
    accountType: 'savings' | 'checking';
    accountHolderName: string;
    verified: boolean;
  };
  
  // Disponibilidad y trabajo
  availability: {
    isOnline: boolean;
    workingDays: Array<'monday' | 'tuesday' | 'wednesday' | 'thursday' | 'friday' | 'saturday' | 'sunday'>;
    workingHours: {
      start: string; // HH:mm format
      end: string;   // HH:mm format
    };
    currentTripId: string | null;
    lastActiveAt: Timestamp;
  };
  
  // Ubicación actual
  location: {
    latitude: number;
    longitude: number;
    bearing: number | null; // Dirección del vehículo
    speed: number | null;   // km/h
    accuracy: number | null; // metros
    lastUpdated: Timestamp;
    geohash: string; // Para queries geográficas eficientes
  };
  
  // Estadísticas y performance
  statistics: {
    totalTrips: number;
    totalEarnings: number;
    totalDistance: number; // km
    totalOnlineTime: number; // minutos
    averageRating: number;
    totalRatings: number;
    acceptanceRate: number; // %
    cancellationRate: number; // %
    completionRate: number; // %
    averageResponseTime: number; // segundos
  };
  
  // Configuración de precios
  pricing: {
    customRates: boolean;
    baseRate: number | null;
    perKmRate: number | null;
    perMinuteRate: number | null;
    minimumFare: number | null;
  };
  
  // Metadata
  metadata: {
    approvedAt: Timestamp | null;
    approvedBy: string | null;
    rejectedAt: Timestamp | null;
    rejectedBy: string | null;
    rejectionReason: string | null;
    lastDocumentUpdate: Timestamp | null;
    createdAt: Timestamp;
    updatedAt: Timestamp;
  };
}
```

### 3. Trips Collection

```typescript
// trips/{tripId}
interface TripDocument {
  // Identificadores
  id: string;
  passengerId: string;
  driverId: string | null;
  vehicleId: string | null;
  
  // Estado del viaje
  status: 'requested' | 'accepted' | 'driver_arrived' | 'started' | 'completed' | 'cancelled';
  substatus: string | null; // Estados específicos adicionales
  
  // Información de origen y destino
  pickup: {
    latitude: number;
    longitude: number;
    address: string;
    placeId: string | null;
    landmark: string | null;
    instructions: string | null;
  };
  
  destination: {
    latitude: number;
    longitude: number;
    address: string;
    placeId: string | null;
    landmark: string | null;
    instructions: string | null;
  };
  
  // Información del vehículo solicitado
  vehicleType: 'economy' | 'premium' | 'van' | 'motorcycle';
  vehicleRequirements: {
    capacity: number | null;
    amenities: string[] | null;
    accessibility: boolean;
  };
  
  // Información de precios
  pricing: {
    estimatedFare: number;
    baseFare: number;
    distanceFare: number;
    timeFare: number;
    surgeFare: number;
    discounts: Array<{
      type: string;
      amount: number;
      code: string | null;
    }>;
    finalFare: number | null;
    currency: 'PEN';
    breakdown: {
      subtotal: number;
      taxes: number;
      fees: number;
      tips: number;
      total: number;
    } | null;
  };
  
  // Timeline del viaje
  timeline: {
    requestedAt: Timestamp;
    acceptedAt: Timestamp | null;
    driverArrivedAt: Timestamp | null;
    startedAt: Timestamp | null;
    completedAt: Timestamp | null;
    cancelledAt: Timestamp | null;
  };
  
  // Ruta y tracking
  route: {
    estimatedDistance: number; // km
    estimatedDuration: number; // minutos
    actualDistance: number | null;
    actualDuration: number | null;
    waypoints: Array<{
      latitude: number;
      longitude: number;
      timestamp: Timestamp;
    }> | null;
    polyline: string | null; // Encoded polyline
  };
  
  // Información del conductor (desnormalizada)
  driverInfo: {
    name: string;
    phone: string;
    rating: number;
    vehicleInfo: {
      make: string;
      model: string;
      color: string;
      licensePlate: string;
    };
  } | null;
  
  // Información del pasajero (desnormalizada)
  passengerInfo: {
    name: string;
    phone: string;
    rating: number;
  };
  
  // Pago
  payment: {
    method: 'cash' | 'card' | 'digital_wallet' | 'credit';
    status: 'pending' | 'processing' | 'paid' | 'failed' | 'refunded';
    paymentId: string | null;
    paidAt: Timestamp | null;
    refundedAt: Timestamp | null;
    tip: number | null;
  };
  
  // Calificaciones
  ratings: {
    passengerToDriver: {
      rating: number | null;
      comment: string | null;
      ratedAt: Timestamp | null;
    };
    driverToPassenger: {
      rating: number | null;
      comment: string | null;
      ratedAt: Timestamp | null;
    };
  };
  
  // Cancelación
  cancellation: {
    cancelledBy: 'passenger' | 'driver' | 'system' | 'admin' | null;
    reason: string | null;
    feeCharged: number | null;
    refundAmount: number | null;
  } | null;
  
  // Información adicional
  metadata: {
    scheduledTime: Timestamp | null;
    specialInstructions: string | null;
    accessibilityNeeds: string[] | null;
    promoCode: string | null;
    source: 'mobile_app' | 'web' | 'call_center' | 'api';
    platform: 'android' | 'ios' | 'web';
    appVersion: string;
    estimatedWaitTime: number | null;
    actualWaitTime: number | null;
    weatherConditions: string | null;
    trafficConditions: string | null;
    surgeMultiplier: number | null;
    createdAt: Timestamp;
    updatedAt: Timestamp;
  };
}
```

### 4. Vehicles Collection

```typescript
// vehicles/{vehicleId}
interface VehicleDocument {
  // Identificación del vehículo
  id: string;
  ownerId: string; // driverId
  status: 'active' | 'inactive' | 'maintenance' | 'retired';
  
  // Información básica
  make: string;
  model: string;
  year: number;
  color: string;
  licensePlate: string;
  vin: string | null;
  
  // Clasificación
  type: 'economy' | 'premium' | 'van' | 'motorcycle' | 'luxury';
  category: 'sedan' | 'suv' | 'hatchback' | 'truck' | 'motorcycle' | 'van';
  capacity: {
    passengers: number;
    luggage: number; // piezas estándar
  };
  
  // Características y amenidades
  features: {
    airConditioning: boolean;
    wifi: boolean;
    phoneCharger: boolean;
    bluetooth: boolean;
    gps: boolean;
    dashCam: boolean;
    childSeat: boolean;
    wheelchairAccessible: boolean;
    petFriendly: boolean;
    smokingAllowed: boolean;
  };
  
  // Documentación
  documentation: {
    registration: {
      number: string;
      expiryDate: Timestamp;
      issuedBy: string;
      documentUrl: string;
    };
    insurance: {
      policyNumber: string;
      provider: string;
      expiryDate: Timestamp;
      coverage: string[];
      documentUrl: string;
    };
    inspection: {
      lastInspectionDate: Timestamp;
      nextInspectionDate: Timestamp;
      certified: boolean;
      certificateUrl: string | null;
    };
    emissions: {
      lastTestDate: Timestamp | null;
      nextTestDate: Timestamp | null;
      passed: boolean;
      certificateUrl: string | null;
    };
  };
  
  // Mantenimiento
  maintenance: {
    lastServiceDate: Timestamp | null;
    nextServiceDate: Timestamp | null;
    mileage: number;
    serviceHistory: Array<{
      date: Timestamp;
      type: string;
      description: string;
      cost: number;
      mileage: number;
    }>;
  };
  
  // Multimedia
  media: {
    photos: Array<{
      url: string;
      type: 'exterior' | 'interior' | 'documents';
      uploadedAt: Timestamp;
    }>;
    videos: Array<{
      url: string;
      type: 'tour' | 'features';
      uploadedAt: Timestamp;
    }>;
  };
  
  // Estadísticas
  statistics: {
    totalTrips: number;
    totalDistance: number; // km
    totalRevenue: number;
    averageRating: number;
    totalRatings: number;
    fuelEfficiency: number | null; // km/galón
    maintenanceCost: number;
  };
  
  // Metadata
  metadata: {
    approvedAt: Timestamp | null;
    approvedBy: string | null;
    createdAt: Timestamp;
    updatedAt: Timestamp;
    retiredAt: Timestamp | null;
    retiredReason: string | null;
  };
}
```

### 5. Payments Collection

```typescript
// payments/{paymentId}
interface PaymentDocument {
  // Identificadores
  id: string;
  tripId: string;
  passengerId: string;
  driverId: string;
  
  // Información básica del pago
  amount: number;
  currency: 'PEN';
  method: 'cash' | 'credit_card' | 'debit_card' | 'digital_wallet' | 'bank_transfer';
  status: 'pending' | 'processing' | 'completed' | 'failed' | 'cancelled' | 'refunded';
  
  // Detalles de la transacción
  transaction: {
    externalId: string | null; // ID del proveedor de pagos
    provider: 'mercadopago' | 'visa' | 'mastercard' | 'cash' | 'internal_wallet';
    reference: string | null;
    authorizationCode: string | null;
    processingFee: number | null;
  };
  
  // Desglose del pago
  breakdown: {
    fareAmount: number;
    tip: number;
    taxes: number;
    fees: number;
    discounts: number;
    surcharge: number;
    total: number;
  };
  
  // Comisiones y distribución
  commissions: {
    driverAmount: number;
    companyAmount: number;
    processingFee: number;
    taxAmount: number;
    netDriverAmount: number;
  };
  
  // Información del método de pago
  paymentMethodInfo: {
    type: 'cash' | 'card' | 'wallet';
    last4Digits: string | null;
    brand: string | null; // visa, mastercard, etc.
    expiryMonth: number | null;
    expiryYear: number | null;
    holderName: string | null;
  };
  
  // Reembolsos
  refund: {
    amount: number | null;
    reason: string | null;
    status: 'pending' | 'processing' | 'completed' | 'failed' | null;
    requestedBy: string | null;
    requestedAt: Timestamp | null;
    processedAt: Timestamp | null;
    externalRefundId: string | null;
  } | null;
  
  // Disputas
  dispute: {
    status: 'open' | 'under_review' | 'resolved' | 'closed' | null;
    reason: string | null;
    disputedBy: 'passenger' | 'driver' | 'bank' | null;
    amount: number | null;
    createdAt: Timestamp | null;
    resolvedAt: Timestamp | null;
    resolution: string | null;
  } | null;
  
  // Metadata
  metadata: {
    ipAddress: string | null;
    userAgent: string | null;
    deviceFingerprint: string | null;
    processingTime: number | null; // milliseconds
    retryCount: number;
    createdAt: Timestamp;
    updatedAt: Timestamp;
    processedAt: Timestamp | null;
    failedAt: Timestamp | null;
    failureReason: string | null;
  };
}
```

### 6. Wallets Collection

```typescript
// wallets/{userId}
interface WalletDocument {
  // Identificación
  userId: string;
  userType: 'passenger' | 'driver';
  status: 'active' | 'frozen' | 'closed';
  
  // Balance
  balance: {
    current: number;
    available: number; // balance - pending withdrawals
    pending: number;   // pending transactions
    currency: 'PEN';
  };
  
  // Límites
  limits: {
    daily: {
      withdraw: number;
      deposit: number;
    };
    monthly: {
      withdraw: number;
      deposit: number;
    };
    perTransaction: {
      withdraw: number;
      deposit: number;
    };
  };
  
  // Configuración
  settings: {
    autoWithdraw: boolean;
    autoWithdrawThreshold: number;
    preferredWithdrawMethod: string;
    notifications: {
      lowBalance: boolean;
      threshold: number;
      transactions: boolean;
    };
  };
  
  // Estadísticas
  statistics: {
    totalDeposits: number;
    totalWithdrawals: number;
    totalTransactions: number;
    averageBalance: number;
    lastTransactionAt: Timestamp | null;
  };
  
  // Metadata
  metadata: {
    createdAt: Timestamp;
    updatedAt: Timestamp;
    lastActivityAt: Timestamp | null;
    verificationLevel: 'basic' | 'verified' | 'premium';
    kycStatus: 'pending' | 'approved' | 'rejected';
  };
}
```

---

## 📁 SUBCOLECCIONES

### Users Subcollections

#### users/{userId}/statistics
```typescript
interface UserStatistics {
  // Para pasajeros
  passenger?: {
    totalTrips: number;
    totalSpent: number;
    averageRating: number;
    totalRatings: number;
    favoriteDestinations: Array<{
      address: string;
      count: number;
    }>;
    averageTripDistance: number;
    averageTripDuration: number;
    preferredVehicleTypes: Record<string, number>;
  };
  
  // Para conductores
  driver?: {
    totalTrips: number;
    totalEarnings: number;
    averageRating: number;
    totalRatings: number;
    totalOnlineHours: number;
    averageAcceptanceRate: number;
    averageCancellationRate: number;
    topPickupLocations: Array<{
      address: string;
      count: number;
    }>;
  };
  
  // Estadísticas temporales
  monthly: Record<string, {
    trips: number;
    earnings?: number;
    spending?: number;
    onlineHours?: number;
  }>;
  
  weekly: Record<string, {
    trips: number;
    earnings?: number;
    spending?: number;
    onlineHours?: number;
  }>;
  
  metadata: {
    lastCalculatedAt: Timestamp;
    calculationVersion: string;
  };
}
```

#### users/{userId}/notifications
```typescript
interface NotificationDocument {
  id: string;
  type: 'trip_update' | 'payment' | 'promotion' | 'system' | 'driver_verification';
  title: string;
  body: string;
  data: Record<string, any>;
  
  // Estado
  read: boolean;
  readAt: Timestamp | null;
  dismissed: boolean;
  dismissedAt: Timestamp | null;
  
  // Delivery
  channels: Array<'push' | 'email' | 'sms' | 'in_app'>;
  delivered: boolean;
  deliveredAt: Timestamp | null;
  failureReason: string | null;
  
  // Prioridad y programación
  priority: 'low' | 'normal' | 'high' | 'urgent';
  scheduledFor: Timestamp | null;
  expiresAt: Timestamp | null;
  
  // Metadata
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

#### users/{userId}/fcm_tokens
```typescript
interface FCMTokenDocument {
  token: string;
  platform: 'android' | 'ios' | 'web';
  deviceInfo: {
    model: string | null;
    osVersion: string | null;
    appVersion: string;
    deviceId: string | null;
  };
  
  active: boolean;
  lastUsed: Timestamp;
  createdAt: Timestamp;
  
  // Para cleanup automático
  expiresAt: Timestamp | null;
}
```

### Trips Subcollections

#### trips/{tripId}/location_updates
```typescript
interface LocationUpdate {
  driverId: string;
  latitude: number;
  longitude: number;
  bearing: number | null;
  speed: number | null;
  accuracy: number;
  timestamp: Timestamp;
  
  // Información adicional
  batteryLevel: number | null;
  isCharging: boolean | null;
  networkType: string | null;
}
```

#### trips/{tripId}/messages
```typescript
interface TripMessage {
  id: string;
  senderId: string;
  senderType: 'passenger' | 'driver' | 'system';
  type: 'text' | 'quick_reply' | 'location' | 'system_update';
  content: string;
  
  // Estado del mensaje
  delivered: boolean;
  deliveredAt: Timestamp | null;
  read: boolean;
  readAt: Timestamp | null;
  
  // Metadata
  timestamp: Timestamp;
  editedAt: Timestamp | null;
  deletedAt: Timestamp | null;
}
```

#### trips/{tripId}/events
```typescript
interface TripEvent {
  id: string;
  type: 'status_change' | 'location_update' | 'payment_update' | 'rating_added' | 'message_sent';
  actor: 'passenger' | 'driver' | 'system' | 'admin';
  actorId: string;
  
  // Datos del evento
  data: Record<string, any>;
  previousState: Record<string, any> | null;
  newState: Record<string, any> | null;
  
  // Contexto
  metadata: {
    ipAddress: string | null;
    userAgent: string | null;
    timestamp: Timestamp;
    correlationId: string | null;
  };
}
```

### Wallets Subcollections

#### wallets/{userId}/transactions
```typescript
interface WalletTransaction {
  id: string;
  type: 'deposit' | 'withdrawal' | 'payment' | 'refund' | 'fee' | 'bonus' | 'adjustment';
  amount: number;
  currency: 'PEN';
  
  // Estado
  status: 'pending' | 'processing' | 'completed' | 'failed' | 'cancelled';
  
  // Referencias
  relatedTripId: string | null;
  relatedPaymentId: string | null;
  externalTransactionId: string | null;
  
  // Balances
  balanceBefore: number;
  balanceAfter: number;
  
  // Descripción
  description: string;
  category: string;
  tags: string[];
  
  // Método (para deposits/withdrawals)
  method: {
    type: 'bank_transfer' | 'card' | 'cash' | 'internal_transfer';
    details: Record<string, any>;
  } | null;
  
  // Fees
  fee: {
    amount: number;
    type: string;
    description: string;
  } | null;
  
  // Metadata
  metadata: {
    initiatedBy: string | null; // userId o 'system'
    ipAddress: string | null;
    userAgent: string | null;
    processingTime: number | null;
    retryCount: number;
    failureReason: string | null;
    createdAt: Timestamp;
    updatedAt: Timestamp;
    processedAt: Timestamp | null;
  };
}
```

---

## 🔍 ÍNDICES Y QUERIES

### Índices Estratégicos

#### Trips Collection Indexes
```json
{
  "collectionGroup": "trips",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "status", "order": "ASCENDING"},
    {"fieldPath": "passengerId", "order": "ASCENDING"},
    {"fieldPath": "timeline.requestedAt", "order": "DESCENDING"}
  ]
},
{
  "collectionGroup": "trips",
  "queryScope": "COLLECTION", 
  "fields": [
    {"fieldPath": "status", "order": "ASCENDING"},
    {"fieldPath": "driverId", "order": "ASCENDING"},
    {"fieldPath": "timeline.acceptedAt", "order": "DESCENDING"}
  ]
},
{
  "collectionGroup": "trips",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "vehicleType", "order": "ASCENDING"},
    {"fieldPath": "status", "order": "ASCENDING"},
    {"fieldPath": "pickup.latitude", "order": "ASCENDING"},
    {"fieldPath": "pickup.longitude", "order": "ASCENDING"}
  ]
}
```

#### Drivers Collection Indexes
```json
{
  "collectionGroup": "drivers",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "status", "order": "ASCENDING"},
    {"fieldPath": "vehicle.type", "order": "ASCENDING"},
    {"fieldPath": "location.geohash", "order": "ASCENDING"},
    {"fieldPath": "availability.lastActiveAt", "order": "DESCENDING"}
  ]
},
{
  "collectionGroup": "drivers",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "verificationStatus", "order": "ASCENDING"},
    {"fieldPath": "metadata.createdAt", "order": "DESCENDING"}
  ]
}
```

#### Analytics Collection Indexes
```json
{
  "collectionGroup": "analytics",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "event", "order": "ASCENDING"},
    {"fieldPath": "timestamp", "order": "DESCENDING"}
  ]
},
{
  "collectionGroup": "analytics",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "userId", "order": "ASCENDING"},
    {"fieldPath": "event", "order": "ASCENDING"},
    {"fieldPath": "timestamp", "order": "DESCENDING"}
  ]
}
```

### Query Patterns Comunes

#### 1. Buscar Conductores Disponibles
```typescript
// Query optimizada para encontrar conductores cercanos
const findNearbyDrivers = async (
  latitude: number,
  longitude: number,
  vehicleType: string,
  radiusKm: number = 5
) => {
  // Calcular geohash bounds
  const bounds = geohashQueryBounds([latitude, longitude], radiusKm * 1000);
  
  const promises = bounds.map(bound => 
    db.collection('drivers')
      .where('status', '==', 'available')
      .where('vehicle.type', '==', vehicleType)
      .where('location.geohash', '>=', bound[0])
      .where('location.geohash', '<=', bound[1])
      .orderBy('location.geohash')
      .orderBy('availability.lastActiveAt', 'desc')
      .limit(20)
      .get()
  );
  
  const snapshots = await Promise.all(promises);
  // Filtrar por distancia exacta y retornar ordenado por proximidad
};
```

#### 2. Historial de Viajes de Usuario
```typescript
// Query paginada para historial de trips
const getUserTripHistory = async (
  userId: string,
  limit: number = 20,
  lastDoc?: DocumentSnapshot
) => {
  let query = db.collection('trips')
    .where('passengerId', '==', userId)
    .where('status', 'in', ['completed', 'cancelled'])
    .orderBy('timeline.requestedAt', 'desc')
    .limit(limit);
  
  if (lastDoc) {
    query = query.startAfter(lastDoc);
  }
  
  return await query.get();
};
```

#### 3. Analytics por Período
```typescript
// Query para analytics con filtros temporales
const getAnalyticsByPeriod = async (
  startDate: Date,
  endDate: Date,
  eventType?: string
) => {
  let query = db.collection('analytics')
    .where('timestamp', '>=', Timestamp.fromDate(startDate))
    .where('timestamp', '<=', Timestamp.fromDate(endDate));
  
  if (eventType) {
    query = query.where('event', '==', eventType);
  }
  
  return await query
    .orderBy('timestamp', 'desc')
    .limit(1000)
    .get();
};
```

#### 4. Transacciones de Wallet
```typescript
// Query para transacciones con filtros
const getWalletTransactions = async (
  userId: string,
  type?: string,
  status?: string,
  limit: number = 50
) => {
  let query = db.collection('wallets')
    .doc(userId)
    .collection('transactions')
    .orderBy('metadata.createdAt', 'desc');
  
  if (type) {
    query = query.where('type', '==', type);
  }
  
  if (status) {
    query = query.where('status', '==', status);
  }
  
  return await query.limit(limit).get();
};
```

---

## 🔗 RELACIONES ENTRE DATOS

### Patrón de Referencias

#### 1. Referencias Directas
```typescript
// Trip -> User (One-to-Many)
{
  tripId: "trip123",
  passengerId: "user456",  // Referencia directa
  driverId: "driver789"    // Referencia directa
}

// Vehicle -> Driver (One-to-One)
{
  vehicleId: "vehicle123",
  ownerId: "driver789"     // Referencia directa
}
```

#### 2. Desnormalización Estratégica
```typescript
// Trip document incluye datos frecuentemente accedidos
{
  tripId: "trip123",
  passengerId: "user456",
  
  // Datos desnormalizados del conductor
  driverInfo: {
    name: "Juan Pérez",
    phone: "+51987654321",
    rating: 4.8,
    vehicleInfo: {
      make: "Toyota",
      model: "Corolla",
      color: "Blanco",
      licensePlate: "ABC-123"
    }
  },
  
  // Datos desnormalizados del pasajero
  passengerInfo: {
    name: "María García",
    phone: "+51123456789",
    rating: 4.9
  }
}
```

#### 3. Subcolecciones para Datos Relacionados
```typescript
// Estructura jerárquica para datos relacionados
users/{userId}/
├── statistics/        // Datos agregados del usuario
├── notifications/     // Notificaciones personales
├── payment_methods/   // Métodos de pago guardados
└── trip_history/     // Historial comprimido

trips/{tripId}/
├── location_updates/ // Updates de ubicación en tiempo real
├── messages/         // Chat del viaje
└── events/          // Log de eventos
```

### Patrones de Consistencia

#### 1. Transacciones Atómicas
```typescript
// Ejemplo: Completar un viaje
const completeTrip = async (tripId: string, finalFare: number) => {
  return await db.runTransaction(async (transaction) => {
    // 1. Actualizar trip
    const tripRef = db.collection('trips').doc(tripId);
    transaction.update(tripRef, {
      status: 'completed',
      'pricing.finalFare': finalFare,
      'timeline.completedAt': FieldValue.serverTimestamp()
    });
    
    // 2. Actualizar estadísticas del conductor
    const driverStatsRef = db.collection('drivers')
      .doc(driverId)
      .collection('statistics')
      .doc('summary');
    
    transaction.update(driverStatsRef, {
      totalTrips: FieldValue.increment(1),
      totalEarnings: FieldValue.increment(finalFare * 0.8)
    });
    
    // 3. Actualizar estadísticas del pasajero
    const passengerStatsRef = db.collection('users')
      .doc(passengerId)
      .collection('statistics')
      .doc('summary');
    
    transaction.update(passengerStatsRef, {
      totalTrips: FieldValue.increment(1),
      totalSpent: FieldValue.increment(finalFare)
    });
  });
};
```

#### 2. Updates Eventuales
```typescript
// Cloud Function trigger para sincronización eventual
export const onTripStatusChange = functions.firestore
  .document('trips/{tripId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    // Solo procesar cambios de estado
    if (before.status === after.status) return;
    
    // Actualizar métricas agregadas asíncronamente
    await updateAggregatedMetrics(after);
    
    // Enviar notificaciones
    await sendStatusChangeNotifications(after);
    
    // Actualizar analytics
    await recordAnalyticsEvent(after);
  });
```

---

## ⚡ OPTIMIZACIÓN Y PERFORMANCE

### Estrategias de Optimización

#### 1. Denormalización Inteligente
```yaml
Principio: Duplicar datos frecuentemente accedidos
Casos de Uso:
  - Información del conductor en trips (evita joins)
  - Ratings promedio en perfiles (evita agregaciones)
  - Estadísticas totales en dashboards
  
Implementación:
  - Cloud Functions para mantener sincronización
  - Triggers automáticos en cambios críticos
  - Validación de consistencia periódica
```

#### 2. Particionamiento Temporal
```typescript
// Estructura para datos históricos
analytics/
├── daily/{date}/        # Métricas diarias
├── monthly/{month}/     # Agregaciones mensuales
└── yearly/{year}/       # Resúmenes anuales

// Query optimizada por período
const getDailyMetrics = (date: string) => {
  return db.collection('analytics')
    .doc('daily')
    .collection(date)
    .get();
};
```

#### 3. Caching con TTL
```typescript
// Estructura para cache con expiración
cache/{type}/{key} = {
  data: any,
  cachedAt: Timestamp,
  expiresAt: Timestamp,
  version: string
}

// Función helper para cache
const getCachedData = async (type: string, key: string) => {
  const cacheDoc = await db.collection('cache')
    .doc(type)
    .collection('entries')
    .doc(key)
    .get();
  
  if (!cacheDoc.exists) return null;
  
  const data = cacheDoc.data();
  if (data.expiresAt.toDate() < new Date()) {
    // Cache expirado
    await cacheDoc.ref.delete();
    return null;
  }
  
  return data.data;
};
```

#### 4. Batch Operations
```typescript
// Ejemplo de batch write optimizado
const updateMultipleDocuments = async (updates: Array<{
  collection: string;
  doc: string;
  data: any;
}>) => {
  const batchSize = 500; // Firestore limit
  const batches = [];
  
  for (let i = 0; i < updates.length; i += batchSize) {
    const batch = db.batch();
    const batchUpdates = updates.slice(i, i + batchSize);
    
    batchUpdates.forEach(update => {
      const ref = db.collection(update.collection).doc(update.doc);
      batch.update(ref, update.data);
    });
    
    batches.push(batch.commit());
  }
  
  return Promise.all(batches);
};
```

### Métricas de Performance

#### 1. Query Performance
```yaml
Objetivos:
  - <100ms para queries simples
  - <500ms para queries complejas
  - <1s para agregaciones

Monitoreo:
  - Cloud Monitoring para latencia
  - Logging personalizado para queries lentas
  - Alerts para degradación de performance
```

#### 2. Write Performance
```yaml
Estrategias:
  - Batch writes para operaciones múltiples
  - Transacciones solo cuando necesario
  - Async updates para datos no-críticos
  
Límites:
  - 500 ops por batch
  - 500 docs por transaction
  - 10MB por document
```

---

## 🔒 SEGURIDAD Y VALIDACIÓN

### Firestore Security Rules

#### Rules Principales
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function hasRole(role) {
      return isAuthenticated() && request.auth.token.role == role;
    }
    
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    function isVerified() {
      return isAuthenticated() && request.auth.token.verified == true;
    }
    
    function isValidUserData() {
      return request.resource.data.keys().hasAll(['email', 'profile', 'userType']) &&
             request.resource.data.userType in ['passenger', 'driver', 'admin'];
    }
    
    // Users collection
    match /users/{userId} {
      allow read: if isOwner(userId) || hasRole('admin');
      allow write: if isOwner(userId) && isValidUserData();
      
      // User subcollections
      match /{subcollection=**} {
        allow read, write: if isOwner(userId) || hasRole('admin');
      }
    }
    
    // Drivers collection
    match /drivers/{driverId} {
      allow read: if isAuthenticated();
      allow write: if (isOwner(driverId) && isVerified()) || hasRole('admin');
    }
    
    // Trips collection
    match /trips/{tripId} {
      allow read: if isAuthenticated() && (
        isOwner(resource.data.passengerId) ||
        isOwner(resource.data.driverId) ||
        hasRole('admin')
      );
      
      allow create: if isAuthenticated() && hasRole('passenger') &&
                       isOwner(request.resource.data.passengerId);
      
      allow update: if isAuthenticated() && (
        (hasRole('passenger') && isOwner(resource.data.passengerId)) ||
        (hasRole('driver') && isOwner(resource.data.driverId)) ||
        hasRole('admin')
      );
      
      // Trip subcollections
      match /{subcollection=**} {
        allow read, write: if isAuthenticated() && (
          isOwner(get(/databases/$(database)/documents/trips/$(tripId)).data.passengerId) ||
          isOwner(get(/databases/$(database)/documents/trips/$(tripId)).data.driverId) ||
          hasRole('admin')
        );
      }
    }
    
    // Vehicles collection
    match /vehicles/{vehicleId} {
      allow read: if isAuthenticated();
      allow write: if isOwner(resource.data.ownerId) || hasRole('admin');
    }
    
    // Payments collection
    match /payments/{paymentId} {
      allow read: if isAuthenticated() && (
        isOwner(resource.data.passengerId) ||
        isOwner(resource.data.driverId) ||
        hasRole('admin')
      );
      
      allow write: if hasRole('admin') || 
                      (isAuthenticated() && isOwner(resource.data.passengerId));
    }
    
    // Wallets collection
    match /wallets/{userId} {
      allow read, write: if isOwner(userId) || hasRole('admin');
      
      // Wallet transactions
      match /transactions/{transactionId} {
        allow read: if isOwner(userId) || hasRole('admin');
        allow write: if hasRole('admin'); // Solo admin puede crear transacciones
      }
    }
    
    // Analytics collection (read-only for users)
    match /analytics/{document=**} {
      allow read: if hasRole('admin');
      allow write: if false; // Solo Cloud Functions
    }
    
    // Admin logs (admin only)
    match /admin_logs/{document=**} {
      allow read, write: if hasRole('admin');
    }
  }
}
```

### Validación de Datos

#### Client-side Validation
```typescript
// Schemas de validación con Joi
const userProfileSchema = Joi.object({
  firstName: Joi.string().min(2).max(50).required(),
  lastName: Joi.string().min(2).max(50).required(),
  email: Joi.string().email().required(),
  phone: Joi.string().pattern(/^\+51[0-9]{9}$/).required(),
  dateOfBirth: Joi.date().max('now').optional(),
  emergencyContact: Joi.object({
    name: Joi.string().min(2).max(100).required(),
    phone: Joi.string().pattern(/^\+51[0-9]{9}$/).required(),
    relationship: Joi.string().max(50).required()
  }).optional()
});

const tripRequestSchema = Joi.object({
  pickup: Joi.object({
    latitude: Joi.number().min(-90).max(90).required(),
    longitude: Joi.number().min(-180).max(180).required(),
    address: Joi.string().min(5).max(200).required()
  }).required(),
  
  destination: Joi.object({
    latitude: Joi.number().min(-90).max(90).required(),
    longitude: Joi.number().min(-180).max(180).required(),
    address: Joi.string().min(5).max(200).required()
  }).required(),
  
  vehicleType: Joi.string().valid('economy', 'premium', 'van', 'motorcycle').required(),
  scheduledTime: Joi.date().min('now').optional(),
  notes: Joi.string().max(500).optional()
});
```

#### Server-side Validation
```typescript
// Cloud Functions validation
export const validateTripRequest = (data: any): ValidationResult => {
  const { error, value } = tripRequestSchema.validate(data);
  
  if (error) {
    return {
      valid: false,
      error: error.details[0].message,
      code: 'VALIDATION_ERROR'
    };
  }
  
  // Validaciones de negocio adicionales
  const pickup = value.pickup;
  const destination = value.destination;
  
  // Verificar que pickup y destination no sean el mismo lugar
  const distance = calculateDistance(
    pickup.latitude, pickup.longitude,
    destination.latitude, destination.longitude
  );
  
  if (distance < 0.1) { // 100 metros
    return {
      valid: false,
      error: 'Pickup and destination must be at least 100 meters apart',
      code: 'INVALID_DISTANCE'
    };
  }
  
  // Verificar que la distancia no sea excesiva
  if (distance > 200) { // 200 km
    return {
      valid: false,
      error: 'Trip distance cannot exceed 200 kilometers',
      code: 'DISTANCE_TOO_LONG'
    };
  }
  
  return {
    valid: true,
    data: value
  };
};
```

---

## 🔄 MIGRACIONES Y VERSIONADO

### Estrategia de Migraciones

#### 1. Versionado de Schema
```typescript
// Estructura para control de versiones
interface DocumentVersion {
  schemaVersion: string;
  migratedAt?: Timestamp;
  migrationLog?: Array<{
    from: string;
    to: string;
    migratedAt: Timestamp;
    changes: string[];
  }>;
}

// Ejemplo de documento versionado
interface VersionedUserDocument extends UserDocument {
  _metadata: {
    schemaVersion: "2.1.0";
    migratedAt?: Timestamp;
    migrationLog?: MigrationLogEntry[];
  };
}
```

#### 2. Migration Scripts
```typescript
// Script de migración para actualizar schema de usuarios
export const migrateUsersToV2 = async () => {
  const batchSize = 500;
  let lastDoc: DocumentSnapshot | null = null;
  
  do {
    let query = db.collection('users')
      .where('_metadata.schemaVersion', '<', '2.0.0')
      .limit(batchSize);
    
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }
    
    const snapshot = await query.get();
    
    if (snapshot.empty) break;
    
    const batch = db.batch();
    
    snapshot.docs.forEach(doc => {
      const data = doc.data();
      const migratedData = migrateUserDocumentToV2(data);
      
      batch.update(doc.ref, {
        ...migratedData,
        '_metadata.schemaVersion': '2.0.0',
        '_metadata.migratedAt': FieldValue.serverTimestamp(),
        '_metadata.migrationLog': FieldValue.arrayUnion({
          from: data._metadata?.schemaVersion || '1.0.0',
          to: '2.0.0',
          migratedAt: FieldValue.serverTimestamp(),
          changes: ['Added emergency contact field', 'Updated preferences structure']
        })
      });
    });
    
    await batch.commit();
    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    
    console.log(`Migrated ${snapshot.docs.length} user documents`);
    
  } while (true);
};

// Función de transformación específica
const migrateUserDocumentToV2 = (oldData: any): any => {
  return {
    ...oldData,
    profile: {
      ...oldData.profile,
      emergencyContact: oldData.emergencyContact || null // Mover campo
    },
    preferences: {
      ...oldData.preferences,
      accessibility: { // Nuevo campo
        screenReader: false,
        highContrast: false,
        fontSize: 'medium'
      }
    }
  };
};
```

#### 3. Backward Compatibility
```typescript
// Helper para leer documentos con backward compatibility
export const readUserWithCompatibility = async (userId: string) => {
  const doc = await db.collection('users').doc(userId).get();
  
  if (!doc.exists) return null;
  
  const data = doc.data()!;
  const version = data._metadata?.schemaVersion || '1.0.0';
  
  // Auto-migrar en lectura si es necesario
  if (semverLt(version, '2.0.0')) {
    const migratedData = migrateUserDocumentToV2(data);
    
    // Update async (no await para no bloquear lectura)
    doc.ref.update({
      ...migratedData,
      '_metadata.schemaVersion': '2.0.0',
      '_metadata.migratedAt': FieldValue.serverTimestamp()
    }).catch(error => {
      console.error('Auto-migration failed:', error);
    });
    
    return migratedData;
  }
  
  return data;
};
```

### Deployment Strategies

#### 1. Blue-Green Deployment
```yaml
Estrategia:
  1. Deploy nueva versión en paralelo
  2. Ejecutar migraciones de datos necesarias
  3. Validar funcionamiento con subset de usuarios
  4. Switch completo de tráfico
  5. Cleanup de versión anterior

Rollback:
  - Switch inmediato a versión anterior
  - Reverse migrations si es necesario
  - Validación de integridad de datos
```

#### 2. Feature Flags
```typescript
// Remote Config para feature flags
export const isFeatureEnabled = async (featureName: string, userId?: string): Promise<boolean> => {
  const remoteConfig = getRemoteConfig(app);
  
  await fetchAndActivate(remoteConfig);
  
  const featureFlag = getValue(remoteConfig, featureName);
  
  if (featureFlag.getSource() === 'default') {
    return false; // Feature disabled by default
  }
  
  const config = JSON.parse(featureFlag.asString());
  
  // Rollout gradual por porcentaje
  if (config.rolloutPercentage) {
    const hash = simpleHash(userId || 'anonymous');
    return (hash % 100) < config.rolloutPercentage;
  }
  
  // Rollout para usuarios específicos
  if (config.enabledUsers && userId) {
    return config.enabledUsers.includes(userId);
  }
  
  return config.enabled === true;
};
```

---

## 📊 CONCLUSIONES Y MEJORES PRÁCTICAS

### Beneficios del Modelo de Datos

#### Ventajas Técnicas
- **Performance optimizada**: Queries sub-100ms para operaciones críticas
- **Escalabilidad horizontal**: Soporte para millones de documentos
- **Real-time capabilities**: Updates instantáneos en toda la aplicación
- **Offline support**: Funcionalidad completa sin conexión

#### Ventajas de Negocio
- **Costo optimizado**: Estructura eficiente minimiza reads/writes
- **Development velocity**: Schema flexible acelera iteraciones
- **Global availability**: Multi-región automática
- **Zero maintenance**: Google maneja toda la infraestructura

### Recomendaciones de Implementación

#### 1. Fase de Setup
```yaml
Prioridades:
  1. Implementar collections principales (users, drivers, trips)
  2. Configurar security rules básicas
  3. Setup de índices críticos
  4. Implementar validación client-side
```

#### 2. Fase de Optimización
```yaml
Mejoras:
  1. Análisis de query patterns reales
  2. Optimización de índices basada en uso
  3. Implementación de caching estratégico
  4. Setup de monitoring y alertas
```

#### 3. Fase de Escalabilidad
```yaml
Evolución:
  1. Particionamiento por regiones geográficas
  2. Implementación de data archiving
  3. Advanced analytics y machine learning
  4. Integration con BigQuery para data warehouse
```

### Monitoreo y Mantenimiento

#### 1. Métricas Clave
```yaml
Performance:
  - Query latency (p50, p95, p99)
  - Write throughput
  - Error rates por collection
  - Cache hit rates

Costos:
  - Reads per day/month
  - Writes per day/month
  - Storage usage
  - Bandwidth consumption

Negocio:
  - Active users por collection
  - Data growth rate
  - Feature adoption rates
```

#### 2. Alertas Críticas
```yaml
Sistema:
  - Query latency > 1 segundo
  - Error rate > 1%
  - Writes failed > 0.1%
  
Negocio:
  - Spike en trip cancellations
  - Drop en driver acceptance rate
  - Payment failure rate > 2%
```

### Roadmap de Evolución

#### Corto Plazo (0-3 meses)
- [ ] Implementación completa del modelo base
- [ ] Security rules production-ready
- [ ] Monitoring básico configurado
- [ ] Performance baseline establecido

#### Medio Plazo (3-6 meses)
- [ ] Analytics avanzado con BigQuery
- [ ] ML para demand prediction
- [ ] Multi-región deployment
- [ ] Advanced caching strategies

#### Largo Plazo (6-12 meses)
- [ ] Predictive analytics para pricing
- [ ] Real-time fraud detection
- [ ] Advanced personalization
- [ ] Integration con IoT vehicles

---

**🗄️ FIRESTORE DATA MODEL v1.0**  
**📅 ÚLTIMA ACTUALIZACIÓN: ENERO 2025**  
**🔄 PRÓXIMA REVISIÓN: MARZO 2025**

*Este modelo de datos ha sido diseñado para soportar el crecimiento exponencial de OasisTaxi, manteniendo siempre la performance, seguridad y escalabilidad como prioridades absolutas.*