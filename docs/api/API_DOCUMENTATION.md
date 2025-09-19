# 🚀 API DOCUMENTATION - OASISTAXI PERÚ

## 📋 OVERVIEW

Esta documentación cubre todas las APIs disponibles en el ecosistema OasisTaxi, incluyendo Firebase APIs, Cloud Functions, y integraciones de terceros.

### Base URLs
```yaml
Firebase Functions: https://us-central1-oasis-taxi-peru.cloudfunctions.net
Firestore Database: https://firestore.googleapis.com/v1/projects/oasis-taxi-peru
Firebase Storage: https://firebasestorage.googleapis.com/v0/b/oasis-taxi-peru.appspot.com
```

### Autenticación
```javascript
// Todas las APIs requieren Firebase ID Token
headers: {
  'Authorization': 'Bearer <firebase_id_token>',
  'Content-Type': 'application/json'
}

// Obtener ID Token en Flutter
final user = FirebaseAuth.instance.currentUser;
final idToken = await user?.getIdToken();
```

---

## 🔐 AUTHENTICATION API

### POST /auth/verifyPhone
Verificar número de teléfono y enviar código OTP.

**Request:**
```json
{
  "phoneNumber": "+51987654321",
  "recaptchaToken": "03AGdBq26..."
}
```

**Response:**
```json
{
  "success": true,
  "verificationId": "AM35F6Gq...",
  "message": "Código enviado exitosamente"
}
```

**Error Responses:**
```json
{
  "error": "INVALID_PHONE_NUMBER",
  "message": "Formato de teléfono inválido",
  "code": 400
}

{
  "error": "SMS_QUOTA_EXCEEDED", 
  "message": "Límite de SMS excedido",
  "code": 429
}
```

### POST /auth/confirmPhone
Confirmar código OTP recibido por SMS.

**Request:**
```json
{
  "verificationId": "AM35F6Gq...",
  "smsCode": "123456"
}
```

**Response:**
```json
{
  "success": true,
  "user": {
    "uid": "user123",
    "phoneNumber": "+51987654321",
    "isNewUser": true
  },
  "idToken": "eyJhbGciOiJSUzI1NiIs...",
  "refreshToken": "AEu4IL3-..."
}
```

### POST /auth/googleSignIn
Autenticación con Google OAuth.

**Request:**
```json
{
  "idToken": "eyJhbGciOiJSUzI1NiIs...",
  "accessToken": "ya29.a0ARrd..."
}
```

**Response:**
```json
{
  "success": true,
  "user": {
    "uid": "user123",
    "email": "usuario@gmail.com",
    "displayName": "Juan Pérez",
    "photoURL": "https://lh3.googleusercontent.com/...",
    "isNewUser": false
  },
  "idToken": "eyJhbGciOiJSUzI1NiIs...",
  "refreshToken": "AEu4IL3-..."
}
```

---

## 👤 USER MANAGEMENT API

### GET /users/profile
Obtener perfil del usuario autenticado.

**Response:**
```json
{
  "success": true,
  "user": {
    "uid": "user123",
    "email": "usuario@email.com",
    "phone": "+51987654321",
    "firstName": "Juan",
    "lastName": "Pérez",
    "userType": "passenger",
    "profileImage": "https://storage.googleapis.com/...",
    "isActive": true,
    "isVerified": true,
    "rating": 4.8,
    "totalTrips": 45,
    "createdAt": "2024-01-15T10:30:00Z",
    "lastLoginAt": "2024-01-20T08:15:00Z",
    "preferences": {
      "language": "es",
      "notifications": true,
      "biometricAuth": false
    }
  }
}
```

### PUT /users/profile
Actualizar perfil del usuario.

**Request:**
```json
{
  "firstName": "Juan Carlos",
  "lastName": "Pérez Silva",
  "email": "nuevo@email.com",
  "preferences": {
    "language": "es",
    "notifications": true,
    "biometricAuth": true
  }
}
```

**Response:**
```json
{
  "success": true,
  "message": "Perfil actualizado exitosamente",
  "user": {
    // ... datos actualizados
  }
}
```

### POST /users/uploadProfileImage
Subir imagen de perfil.

**Request (Multipart):**
```
Content-Type: multipart/form-data
image: [binary_data]
```

**Response:**
```json
{
  "success": true,
  "imageUrl": "https://storage.googleapis.com/oasis-taxi-peru.appspot.com/profiles/user123.jpg",
  "thumbnailUrl": "https://storage.googleapis.com/oasis-taxi-peru.appspot.com/profiles/thumbs/user123_200x200.jpg"
}
```

---

## 🚗 TRIP MANAGEMENT API

### POST /trips/request
Solicitar un nuevo viaje.

**Request:**
```json
{
  "pickupLocation": {
    "latitude": -12.0464,
    "longitude": -77.0428,
    "address": "Av. Javier Prado Este 1066, San Isidro, Lima"
  },
  "destinationLocation": {
    "latitude": -12.0931,
    "longitude": -77.0465,
    "address": "Plaza de Armas, Cercado de Lima, Lima"
  },
  "vehicleType": "economic",
  "paymentMethod": "cash",
  "notes": "Edificio con portón azul",
  "proposedPrice": 12.50
}
```

**Response:**
```json
{
  "success": true,
  "trip": {
    "tripId": "trip_123456",
    "status": "requested",
    "estimatedDistance": 5.2,
    "estimatedDuration": 18,
    "estimatedPrice": 12.50,
    "createdAt": "2024-01-20T15:30:00Z",
    "expiresAt": "2024-01-20T15:45:00Z"
  },
  "message": "Solicitud enviada a conductores cercanos"
}
```

### GET /trips/{tripId}
Obtener detalles de un viaje específico.

**Response:**
```json
{
  "success": true,
  "trip": {
    "tripId": "trip_123456",
    "passengerId": "user123",
    "driverId": "driver456",
    "status": "in_progress",
    "pickupLocation": {
      "latitude": -12.0464,
      "longitude": -77.0428,
      "address": "Av. Javier Prado Este 1066, San Isidro"
    },
    "destinationLocation": {
      "latitude": -12.0931,
      "longitude": -77.0465,
      "address": "Plaza de Armas, Cercado de Lima"
    },
    "vehicleType": "economic",
    "vehicle": {
      "make": "Toyota",
      "model": "Yaris",
      "color": "Blanco",
      "licensePlate": "ABC-123"
    },
    "driver": {
      "name": "Carlos Mendoza",
      "rating": 4.9,
      "phone": "+51987654322",
      "profileImage": "https://storage.googleapis.com/..."
    },
    "estimatedDistance": 5.2,
    "estimatedDuration": 18,
    "actualDistance": 5.1,
    "actualDuration": 16,
    "finalPrice": 14.00,
    "paymentMethod": "cash",
    "createdAt": "2024-01-20T15:30:00Z",
    "acceptedAt": "2024-01-20T15:32:00Z",
    "startedAt": "2024-01-20T15:35:00Z",
    "completedAt": null,
    "currentLocation": {
      "latitude": -12.0650,
      "longitude": -77.0447,
      "heading": 45,
      "speed": 25
    }
  }
}
```

### POST /trips/{tripId}/cancel
Cancelar un viaje.

**Request:**
```json
{
  "reason": "change_of_plans",
  "notes": "Ya no necesito el viaje"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Viaje cancelado exitosamente",
  "cancellationFee": 0.00
}
```

### POST /trips/{tripId}/rate
Calificar un viaje completado.

**Request:**
```json
{
  "rating": 5,
  "comment": "Excelente conductor, muy puntual",
  "tags": ["puntual", "amable", "vehiculo_limpio"]
}
```

**Response:**
```json
{
  "success": true,
  "message": "Calificación registrada exitosamente"
}
```

---

## 💰 PRICE NEGOTIATION API

### POST /negotiations/create
Iniciar negociación de precio.

**Request:**
```json
{
  "tripId": "trip_123456",
  "initialPrice": 12.00,
  "maxPrice": 16.00
}
```

**Response:**
```json
{
  "success": true,
  "negotiation": {
    "negotiationId": "nego_789",
    "tripId": "trip_123456",
    "status": "waitingDriver",
    "initialPrice": 12.00,
    "currentPrice": 12.00,
    "rounds": 0,
    "maxRounds": 3,
    "expiresAt": "2024-01-20T15:45:00Z"
  }
}
```

### POST /negotiations/{negotiationId}/counteroffer
Hacer contraoferta en negociación.

**Request:**
```json
{
  "proposedPrice": 15.00,
  "notes": "Precio justo por la distancia"
}
```

**Response:**
```json
{
  "success": true,
  "negotiation": {
    "negotiationId": "nego_789",
    "status": "driverOffered",
    "currentPrice": 15.00,
    "rounds": 1,
    "lastOffer": {
      "proposedBy": "driver",
      "amount": 15.00,
      "timestamp": "2024-01-20T15:33:00Z"
    }
  }
}
```

### POST /negotiations/{negotiationId}/accept
Aceptar precio negociado.

**Response:**
```json
{
  "success": true,
  "negotiation": {
    "negotiationId": "nego_789",
    "status": "accepted",
    "finalPrice": 15.00,
    "totalRounds": 1
  },
  "trip": {
    "tripId": "trip_123456",
    "status": "accepted",
    "finalPrice": 15.00
  }
}
```

---

## 💳 PAYMENT API

### GET /payments/methods
Obtener métodos de pago disponibles.

**Response:**
```json
{
  "success": true,
  "methods": [
    {
      "id": "cash",
      "name": "Efectivo",
      "type": "cash",
      "isDefault": true,
      "available": true
    },
    {
      "id": "mp_card_123",
      "name": "Visa ****1234",
      "type": "credit_card",
      "provider": "mercadopago",
      "isDefault": false,
      "available": true,
      "expirationDate": "12/25"
    },
    {
      "id": "wallet",
      "name": "Billetera OasisTaxi",
      "type": "wallet",
      "available": true,
      "balance": 45.50
    }
  ]
}
```

### POST /payments/methods/add
Agregar nuevo método de pago.

**Request:**
```json
{
  "type": "credit_card",
  "cardToken": "mp_card_token_123",
  "cardholderName": "Juan Pérez",
  "isDefault": true
}
```

**Response:**
```json
{
  "success": true,
  "method": {
    "id": "mp_card_456",
    "name": "Mastercard ****5678",
    "type": "credit_card",
    "provider": "mercadopago",
    "isDefault": true,
    "available": true
  }
}
```

### POST /payments/process
Procesar pago de viaje.

**Request:**
```json
{
  "tripId": "trip_123456",
  "paymentMethodId": "mp_card_123",
  "amount": 15.00,
  "tip": 2.00,
  "description": "Viaje OasisTaxi - Plaza de Armas"
}
```

**Response:**
```json
{
  "success": true,
  "payment": {
    "paymentId": "pay_789",
    "status": "approved",
    "amount": 15.00,
    "tip": 2.00,
    "total": 17.00,
    "method": "credit_card",
    "transactionId": "mp_123456789",
    "processedAt": "2024-01-20T16:00:00Z"
  }
}
```

---

## 🚚 DRIVER API

### GET /drivers/nearby
Buscar conductores cercanos (Solo para pasajeros).

**Query Parameters:**
- `lat`: Latitud
- `lng`: Longitud  
- `radius`: Radio en km (default: 5)
- `vehicleType`: Tipo de vehículo

**Response:**
```json
{
  "success": true,
  "drivers": [
    {
      "driverId": "driver123",
      "name": "Carlos Mendoza",
      "rating": 4.9,
      "totalTrips": 1250,
      "vehicle": {
        "make": "Toyota",
        "model": "Yaris",
        "color": "Blanco",
        "licensePlate": "ABC-123",
        "vehicleType": "economic"
      },
      "location": {
        "latitude": -12.0450,
        "longitude": -77.0420
      },
      "distance": 0.8,
      "eta": 3,
      "isOnline": true,
      "isAvailable": true
    }
  ]
}
```

### POST /drivers/location/update
Actualizar ubicación del conductor (Solo para conductores).

**Request:**
```json
{
  "latitude": -12.0464,
  "longitude": -77.0428,
  "heading": 90,
  "speed": 30,
  "accuracy": 5
}
```

**Response:**
```json
{
  "success": true,
  "message": "Ubicación actualizada"
}
```

### POST /drivers/status
Cambiar estado de disponibilidad.

**Request:**
```json
{
  "isOnline": true,
  "isAvailable": true
}
```

**Response:**
```json
{
  "success": true,
  "status": {
    "isOnline": true,
    "isAvailable": true,
    "lastUpdate": "2024-01-20T15:30:00Z"
  }
}
```

### GET /drivers/earnings
Obtener reporte de ganancias.

**Query Parameters:**
- `startDate`: Fecha inicio (YYYY-MM-DD)
- `endDate`: Fecha fin (YYYY-MM-DD)
- `period`: daily|weekly|monthly

**Response:**
```json
{
  "success": true,
  "earnings": {
    "period": "weekly",
    "startDate": "2024-01-14",
    "endDate": "2024-01-20",
    "totalEarnings": 450.00,
    "totalTrips": 32,
    "averagePerTrip": 14.06,
    "commission": 90.00,
    "netEarnings": 360.00,
    "dailyBreakdown": [
      {
        "date": "2024-01-14",
        "trips": 5,
        "earnings": 70.00,
        "hours": 6.5
      }
    ]
  }
}
```

---

## 💬 CHAT API

### GET /chats/{tripId}/messages
Obtener mensajes del chat de un viaje.

**Response:**
```json
{
  "success": true,
  "messages": [
    {
      "messageId": "msg_123",
      "senderId": "user123",
      "senderType": "passenger",
      "content": "Estoy esperando en la puerta principal",
      "type": "text",
      "timestamp": "2024-01-20T15:35:00Z",
      "isRead": true
    },
    {
      "messageId": "msg_124",
      "senderId": "driver456",
      "senderType": "driver",
      "content": "Perfecto, ya llegué",
      "type": "text",
      "timestamp": "2024-01-20T15:36:00Z",
      "isRead": false
    }
  ]
}
```

### POST /chats/{tripId}/messages
Enviar mensaje en el chat.

**Request:**
```json
{
  "content": "Ya salgo del edificio",
  "type": "text"
}
```

**Response:**
```json
{
  "success": true,
  "message": {
    "messageId": "msg_125",
    "senderId": "user123",
    "content": "Ya salgo del edificio",
    "type": "text",
    "timestamp": "2024-01-20T15:37:00Z"
  }
}
```

### POST /chats/{tripId}/messages/location
Compartir ubicación en el chat.

**Request:**
```json
{
  "latitude": -12.0464,
  "longitude": -77.0428,
  "address": "Av. Javier Prado Este 1066"
}
```

**Response:**
```json
{
  "success": true,
  "message": {
    "messageId": "msg_126",
    "senderId": "user123",
    "type": "location",
    "location": {
      "latitude": -12.0464,
      "longitude": -77.0428,
      "address": "Av. Javier Prado Este 1066"
    },
    "timestamp": "2024-01-20T15:38:00Z"
  }
}
```

---

## 🚨 EMERGENCY API

### POST /emergency/sos
Activar botón de pánico/SOS.

**Request:**
```json
{
  "tripId": "trip_123456",
  "location": {
    "latitude": -12.0464,
    "longitude": -77.0428
  },
  "emergencyType": "panic_button",
  "notes": "Situación sospechosa"
}
```

**Response:**
```json
{
  "success": true,
  "emergency": {
    "emergencyId": "emer_789",
    "status": "active",
    "responseTime": "5-10 minutos",
    "contactNumber": "+51-1-105",
    "referenceCode": "SOS-789"
  },
  "message": "Emergencia reportada. Ayuda en camino."
}
```

### GET /emergency/{emergencyId}/status
Obtener estado de emergencia.

**Response:**
```json
{
  "success": true,
  "emergency": {
    "emergencyId": "emer_789",
    "status": "responded",
    "createdAt": "2024-01-20T15:40:00Z",
    "respondedAt": "2024-01-20T15:43:00Z",
    "responseTeam": "Serenazgo San Isidro",
    "notes": "Situación bajo control"
  }
}
```

---

## 📊 ANALYTICS API

### GET /analytics/dashboard
Obtener métricas del dashboard (Solo administradores).

**Response:**
```json
{
  "success": true,
  "metrics": {
    "totalUsers": 15420,
    "activeDrivers": 1240,
    "tripsToday": 340,
    "revenueToday": 5100.00,
    "averageRating": 4.7,
    "completionRate": 0.94,
    "responseTime": 3.2,
    "peakHours": ["08:00", "18:00", "22:00"]
  }
}
```

### GET /analytics/trips
Obtener estadísticas de viajes.

**Query Parameters:**
- `startDate`: Fecha inicio
- `endDate`: Fecha fin
- `groupBy`: hour|day|week|month

**Response:**
```json
{
  "success": true,
  "stats": {
    "totalTrips": 1240,
    "completedTrips": 1165,
    "cancelledTrips": 75,
    "averageDistance": 4.8,
    "averagePrice": 13.50,
    "peakDemandHours": [
      {"hour": 8, "trips": 120},
      {"hour": 18, "trips": 145},
      {"hour": 22, "trips": 98}
    ]
  }
}
```

---

## 🔧 ADMIN API

### GET /admin/users
Obtener lista de usuarios (Solo administradores).

**Query Parameters:**
- `page`: Página (default: 1)
- `limit`: Límite por página (default: 20)
- `userType`: passenger|driver|admin
- `status`: active|inactive|banned
- `search`: Término de búsqueda

**Response:**
```json
{
  "success": true,
  "users": [
    {
      "uid": "user123",
      "email": "usuario@email.com",
      "phone": "+51987654321",
      "firstName": "Juan",
      "lastName": "Pérez",
      "userType": "passenger",
      "status": "active",
      "rating": 4.8,
      "totalTrips": 45,
      "createdAt": "2024-01-15T10:30:00Z",
      "lastLoginAt": "2024-01-20T08:15:00Z"
    }
  ],
  "pagination": {
    "currentPage": 1,
    "totalPages": 25,
    "totalUsers": 500,
    "hasNext": true,
    "hasPrev": false
  }
}
```

### POST /admin/users/{userId}/ban
Banear un usuario.

**Request:**
```json
{
  "reason": "violacion_terminos",
  "notes": "Comportamiento inapropiado reportado múltiples veces",
  "duration": "30_days"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Usuario baneado exitosamente",
  "banDetails": {
    "userId": "user123",
    "bannedAt": "2024-01-20T16:00:00Z",
    "expiresAt": "2024-02-19T16:00:00Z",
    "reason": "violacion_terminos"
  }
}
```

### GET /admin/documents/pending
Obtener documentos pendientes de verificación.

**Response:**
```json
{
  "success": true,
  "documents": [
    {
      "documentId": "doc_456",
      "userId": "driver789",
      "userInfo": {
        "name": "Carlos Mendoza",
        "email": "carlos@email.com"
      },
      "documentType": "license",
      "fileName": "licencia_conducir.pdf",
      "fileUrl": "https://storage.googleapis.com/...",
      "uploadedAt": "2024-01-20T14:00:00Z",
      "status": "pending"
    }
  ]
}
```

### POST /admin/documents/{documentId}/verify
Verificar o rechazar documento.

**Request:**
```json
{
  "status": "approved",
  "notes": "Documento válido y legible"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Documento verificado exitosamente",
  "document": {
    "documentId": "doc_456",
    "status": "approved",
    "verifiedAt": "2024-01-20T16:15:00Z",
    "verifiedBy": "admin_user_id"
  }
}
```

---

## 📡 REALTIME API (WebSocket)

### Connection
```javascript
// Conectar a WebSocket
const socket = io('wss://oasis-taxi-peru.firebaseapp.com', {
  auth: {
    token: '<firebase_id_token>'
  }
});
```

### Trip Updates
```javascript
// Suscribirse a actualizaciones de viaje
socket.emit('subscribe_trip', { tripId: 'trip_123456' });

// Recibir actualizaciones
socket.on('trip_update', (data) => {
  console.log('Trip update:', data);
  /*
  {
    tripId: 'trip_123456',
    status: 'in_progress',
    driverLocation: {
      latitude: -12.0464,
      longitude: -77.0428,
      heading: 90
    },
    eta: 8
  }
  */
});
```

### Driver Location Updates
```javascript
// Enviar ubicación (solo conductores)
socket.emit('update_location', {
  latitude: -12.0464,
  longitude: -77.0428,
  heading: 90,
  speed: 25
});

// Recibir ubicación de conductor (solo pasajeros)
socket.on('driver_location', (data) => {
  console.log('Driver location:', data);
});
```

---

## 🔄 WEBHOOK API

### MercadoPago Webhook
Endpoint para recibir notificaciones de pagos.

**URL:** `https://us-central1-oasis-taxi-peru.cloudfunctions.net/mercadopagoWebhook`

**Request:**
```json
{
  "id": 12345678901,
  "live_mode": true,
  "type": "payment",
  "date_created": "2024-01-20T16:00:00.000-04:00",
  "application_id": 123456789,
  "user_id": 987654321,
  "version": 1,
  "api_version": "v1",
  "action": "payment.created",
  "data": {
    "id": "98765432"
  }
}
```

**Response:**
```json
{
  "status": "OK",
  "message": "Webhook processed successfully"
}
```

---

## 📱 PUSH NOTIFICATIONS API

### Send Notification
```javascript
// Cloud Function para enviar notificación
exports.sendPushNotification = functions.https.onCall(async (data, context) => {
  const { userId, title, body, data: notificationData } = data;
  
  const message = {
    notification: {
      title: title,
      body: body
    },
    data: notificationData,
    token: userDeviceToken
  };
  
  const response = await admin.messaging().send(message);
  return { success: true, messageId: response };
});
```

### Notification Types
```yaml
Trip Notifications:
  - new_trip_request: Nueva solicitud de viaje
  - trip_accepted: Viaje aceptado
  - driver_arrived: Conductor ha llegado
  - trip_started: Viaje iniciado
  - trip_completed: Viaje completado
  - trip_cancelled: Viaje cancelado

Payment Notifications:
  - payment_successful: Pago exitoso
  - payment_failed: Pago fallido
  - refund_processed: Reembolso procesado

System Notifications:
  - document_approved: Documento aprobado
  - document_rejected: Documento rechazado
  - account_suspended: Cuenta suspendida
  - maintenance_mode: Modo mantenimiento
```

---

## ❌ ERROR CODES

### HTTP Status Codes
```yaml
200: OK - Solicitud exitosa
201: Created - Recurso creado exitosamente
400: Bad Request - Datos inválidos en la solicitud
401: Unauthorized - Token de autenticación inválido
403: Forbidden - Sin permisos para esta acción
404: Not Found - Recurso no encontrado
409: Conflict - Conflicto con el estado actual
429: Too Many Requests - Límite de velocidad excedido
500: Internal Server Error - Error interno del servidor
503: Service Unavailable - Servicio temporalmente no disponible
```

### Custom Error Codes
```yaml
AUTH_ERRORS:
  - INVALID_PHONE_NUMBER: Formato de teléfono inválido
  - INVALID_OTP_CODE: Código OTP incorrecto
  - OTP_EXPIRED: Código OTP expirado
  - SMS_QUOTA_EXCEEDED: Límite de SMS diario excedido
  - ACCOUNT_DISABLED: Cuenta deshabilitada

TRIP_ERRORS:
  - DRIVER_NOT_AVAILABLE: Conductor no disponible
  - TRIP_NOT_FOUND: Viaje no encontrado
  - INVALID_LOCATION: Ubicación inválida
  - TRIP_ALREADY_CANCELLED: Viaje ya cancelado
  - TRIP_ALREADY_COMPLETED: Viaje ya completado

PAYMENT_ERRORS:
  - PAYMENT_METHOD_INVALID: Método de pago inválido
  - INSUFFICIENT_FUNDS: Fondos insuficientes
  - PAYMENT_PROCESSING_ERROR: Error procesando pago
  - CARD_EXPIRED: Tarjeta expirada
  - CARD_DECLINED: Tarjeta rechazada

VALIDATION_ERRORS:
  - MISSING_REQUIRED_FIELDS: Campos requeridos faltantes
  - INVALID_DATA_FORMAT: Formato de datos inválido
  - VALUE_OUT_OF_RANGE: Valor fuera de rango permitido
```

---

## 🔧 SDK & LIBRARIES

### Flutter SDK
```yaml
dependencies:
  http: ^1.1.0
  dio: ^5.3.2
  firebase_auth: ^4.15.3
  cloud_firestore: ^4.13.6
  firebase_messaging: ^14.7.10
```

### API Client Example
```dart
// lib/services/api_client.dart
class OasisTaxiApiClient {
  static const String baseUrl = 'https://us-central1-oasis-taxi-peru.cloudfunctions.net';
  
  static Future<Map<String, dynamic>> request({
    required String endpoint,
    required String method,
    Map<String, dynamic>? data,
    Map<String, String>? headers,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();
    
    final defaultHeaders = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    };
    
    final response = await http.request(
      method,
      Uri.parse('$baseUrl$endpoint'),
      headers: {...defaultHeaders, ...?headers},
      body: data != null ? jsonEncode(data) : null,
    );
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: jsonDecode(response.body)['message'] ?? 'Unknown error',
      );
    }
  }
}
```

---

## 📞 SUPPORT & CONTACT

### Technical Support
```yaml
Email: api-support@oasistaxiperu.com
Slack: #api-support
Documentation: https://docs.oasistaxiperu.com/api
Status Page: https://status.oasistaxiperu.com
```

### Rate Limits
```yaml
Authentication Endpoints: 10 requests/minute
Trip Management: 60 requests/minute
Payment Processing: 30 requests/minute
Chat Messages: 100 requests/minute
Location Updates: 300 requests/minute
```

---

**API Version:** v1.0.0  
**Last Updated:** Enero 2025  
**Maintained by:** OasisTaxi Development Team