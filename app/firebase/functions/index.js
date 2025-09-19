// Firebase Cloud Functions para OasisTaxi Perú
// Lógica de backend serverless para la aplicación de transporte

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cors = require('cors')({ origin: true });
const crypto = require('crypto');
const mercadopago = require('mercadopago');

// Configure MercadoPago
mercadopago.configure({
  access_token: functions.config().mercadopago?.access_token || 'TEST-ACCESS-TOKEN',
  sandbox: functions.config().mercadopago?.sandbox === 'true'
});

// Inicializar Firebase Admin
admin.initializeApp();

// Referencias a servicios
const db = admin.firestore();
const auth = admin.auth();
const messaging = admin.messaging();
const storage = admin.storage();

// Configuración regional
const runtimeOpts = {
  timeoutSeconds: 540,
  memory: '2GB'
};

// ============================================================================
// API HTTP ENDPOINT
// ============================================================================

const express = require('express');
const app = express();

// Middleware
app.use(cors);
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', service: 'OasisTaxi API', timestamp: new Date().toISOString() });
});

// API version endpoint
app.get('/version', (req, res) => {
  res.status(200).json({ version: '1.0.0', environment: process.env.NODE_ENV || 'production' });
});

// TODO: Add more API routes as needed
// app.get('/trips', ...);
// app.post('/trips', ...);
// app.get('/drivers', ...);
// etc.

// Export the Express app as a Cloud Function
exports.api = functions.https.onRequest(app);

// ============================================================================
// FUNCIONES DE AUTENTICACIÓN
// ============================================================================

/**
 * Crear perfil de usuario personalizado después del registro
 */
exports.createUserProfile = functions.auth.user().onCreate(async (user) => {
  try {
    const userProfile = {
      uid: user.uid,
      email: user.email || null,
      phone: user.phoneNumber || null,
      displayName: user.displayName || null,
      photoURL: user.photoURL || null,
      userType: 'passenger', // Por defecto
      isActive: true,
      isVerified: false,
      rating: 0,
      totalTrips: 0,
      totalRatings: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
      preferences: {
        language: 'es',
        notifications: true,
        biometricAuth: false,
        autoAcceptPrice: false,
        maxWaitTime: 15
      },
      deviceTokens: [],
      emergencyContacts: []
    };

    await db.collection('users').doc(user.uid).set(userProfile);
    
    console.log(`Perfil creado para usuario: ${user.uid}`);
    
    // Enviar notificación de bienvenida
    await sendWelcomeNotification(user.uid, userProfile.userType);
    
  } catch (error) {
    console.error('Error creando perfil de usuario:', error);
    throw new functions.https.HttpsError('internal', 'Error creando perfil');
  }
});

/**
 * Actualizar última actividad al hacer login
 */
exports.updateLastLogin = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  try {
    await db.collection('users').doc(context.auth.uid).update({
      lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
      deviceTokens: admin.firestore.FieldValue.arrayUnion(data.deviceToken)
    });

    return { success: true };
  } catch (error) {
    console.error('Error actualizando último login:', error);
    throw new functions.https.HttpsError('internal', 'Error actualizando actividad');
  }
});

// ============================================================================
// FUNCIONES DE GESTIÓN DE VIAJES
// ============================================================================

/**
 * Crear nueva solicitud de viaje
 */
exports.createTripRequest = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  try {
    const {
      pickupLocation,
      destinationLocation,
      vehicleType,
      proposedPrice,
      paymentMethod,
      notes
    } = data;

    // Validar datos
    if (!pickupLocation || !destinationLocation || !vehicleType || !proposedPrice) {
      throw new functions.https.HttpsError('invalid-argument', 'Datos de viaje incompletos');
    }

    // Verificar que el usuario no tenga viajes activos
    const activeTripsQuery = await db.collection('trips')
      .where('passengerId', '==', context.auth.uid)
      .where('status', 'in', ['requested', 'accepted', 'in_progress'])
      .get();

    if (!activeTripsQuery.empty) {
      throw new functions.https.HttpsError('failed-precondition', 'Ya tienes un viaje activo');
    }

    // Calcular distancia y tiempo estimado
    const estimatedData = await calculateTripEstimates(pickupLocation, destinationLocation);
    
    // Crear documento de viaje
    const tripData = {
      passengerId: context.auth.uid,
      driverId: null,
      status: 'requested',
      pickupLocation,
      destinationLocation,
      vehicleType,
      proposedPrice,
      finalPrice: null,
      paymentMethod,
      notes: notes || '',
      estimatedDistance: estimatedData.distance,
      estimatedDuration: estimatedData.duration,
      actualDistance: null,
      actualDuration: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      acceptedAt: null,
      startedAt: null,
      completedAt: null,
      cancelledAt: null,
      cancelReason: null,
      verificationCode: generateVerificationCode(),
      rating: {
        passengerRating: null,
        driverRating: null,
        passengerComment: '',
        driverComment: ''
      }
    };

    const tripRef = await db.collection('trips').add(tripData);
    
    // Buscar conductores cercanos y notificar
    await notifyNearbyDrivers(tripRef.id, tripData);
    
    // Programar expiración de solicitud
    await scheduleRequestExpiration(tripRef.id);

    return {
      success: true,
      tripId: tripRef.id,
      estimatedDistance: estimatedData.distance,
      estimatedDuration: estimatedData.duration
    };

  } catch (error) {
    console.error('Error creando solicitud de viaje:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Aceptar viaje por conductor
 */
exports.acceptTrip = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  try {
    const { tripId, acceptedPrice } = data;

    // Verificar que el usuario es conductor
    const driverDoc = await db.collection('users').doc(context.auth.uid).get();
    if (!driverDoc.exists || driverDoc.data().userType !== 'driver') {
      throw new functions.https.HttpsError('permission-denied', 'Solo conductores pueden aceptar viajes');
    }

    // Verificar que el conductor esté disponible
    if (!driverDoc.data().isAvailable) {
      throw new functions.https.HttpsError('failed-precondition', 'Conductor no disponible');
    }

    // Usar transacción para evitar race conditions
    await db.runTransaction(async (transaction) => {
      const tripRef = db.collection('trips').doc(tripId);
      const tripDoc = await transaction.get(tripRef);

      if (!tripDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Viaje no encontrado');
      }

      const tripData = tripDoc.data();

      if (tripData.status !== 'requested') {
        throw new functions.https.HttpsError('failed-precondition', 'Viaje ya no está disponible');
      }

      // Actualizar viaje
      transaction.update(tripRef, {
        driverId: context.auth.uid,
        status: 'accepted',
        finalPrice: acceptedPrice || tripData.proposedPrice,
        acceptedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Actualizar disponibilidad del conductor
      transaction.update(db.collection('users').doc(context.auth.uid), {
        isAvailable: false,
        currentTripId: tripId
      });
    });

    // Notificar al pasajero
    await notifyPassengerTripAccepted(tripId);
    
    // Cancelar notificaciones a otros conductores
    await cancelDriverNotifications(tripId, context.auth.uid);

    return { success: true };

  } catch (error) {
    console.error('Error aceptando viaje:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Iniciar viaje (cuando el conductor recoge al pasajero)
 */
exports.startTrip = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  try {
    const { tripId, verificationCode } = data;

    const tripRef = db.collection('trips').doc(tripId);
    const tripDoc = await tripRef.get();

    if (!tripDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Viaje no encontrado');
    }

    const tripData = tripDoc.data();

    // Verificar autorización
    if (tripData.driverId !== context.auth.uid) {
      throw new functions.https.HttpsError('permission-denied', 'No autorizado para este viaje');
    }

    // Verificar código de verificación
    if (tripData.verificationCode !== verificationCode) {
      throw new functions.https.HttpsError('invalid-argument', 'Código de verificación incorrecto');
    }

    // Actualizar estado del viaje
    await tripRef.update({
      status: 'in_progress',
      startedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Notificar al pasajero
    await notifyPassengerTripStarted(tripId);

    return { success: true };

  } catch (error) {
    console.error('Error iniciando viaje:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Completar viaje
 */
exports.completeTrip = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  try {
    const { tripId, actualDistance, actualDuration } = data;

    const tripRef = db.collection('trips').doc(tripId);
    const tripDoc = await tripRef.get();

    if (!tripDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Viaje no encontrado');
    }

    const tripData = tripDoc.data();

    // Verificar autorización
    if (tripData.driverId !== context.auth.uid) {
      throw new functions.https.HttpsError('permission-denied', 'No autorizado para este viaje');
    }

    if (tripData.status !== 'in_progress') {
      throw new functions.https.HttpsError('failed-precondition', 'Viaje no está en progreso');
    }

    // Actualizar viaje
    await tripRef.update({
      status: 'completed',
      actualDistance: actualDistance || tripData.estimatedDistance,
      actualDuration: actualDuration || tripData.estimatedDuration,
      completedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Liberar conductor
    await db.collection('users').doc(context.auth.uid).update({
      isAvailable: true,
      currentTripId: null,
      totalTrips: admin.firestore.FieldValue.increment(1)
    });

    // Procesar pago si es con tarjeta
    if (tripData.paymentMethod !== 'cash') {
      await processPayment(tripId);
    }

    // Notificar finalización
    await notifyTripCompleted(tripId);

    return { success: true };

  } catch (error) {
    console.error('Error completando viaje:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================================================
// FUNCIONES DE NEGOCIACIÓN DE PRECIOS
// ============================================================================

/**
 * Crear nueva negociación de precio
 */
exports.createPriceNegotiation = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  try {
    const { tripId, initialPrice, maxPrice } = data;

    const negotiationData = {
      tripId,
      passengerId: context.auth.uid,
      driverId: null,
      status: 'waitingDriver',
      initialPrice,
      maxPrice: maxPrice || initialPrice * 1.5,
      currentPrice: initialPrice,
      finalPrice: null,
      rounds: [],
      maxRounds: 3,
      currentRound: 0,
      expiresAt: new Date(Date.now() + 15 * 60 * 1000), // 15 minutos
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };

    const negotiationRef = await db.collection('priceNegotiations').add(negotiationData);

    return {
      success: true,
      negotiationId: negotiationRef.id
    };

  } catch (error) {
    console.error('Error creando negociación:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Hacer contraoferta de precio
 */
exports.makeCounterOffer = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  try {
    const { negotiationId, proposedPrice, notes } = data;

    const negotiationRef = db.collection('priceNegotiations').doc(negotiationId);
    const negotiationDoc = await negotiationRef.get();

    if (!negotiationDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Negociación no encontrada');
    }

    const negotiationData = negotiationDoc.data();

    // Verificar que la negociación esté activa
    if (negotiationData.status === 'expired' || negotiationData.status === 'accepted') {
      throw new functions.https.HttpsError('failed-precondition', 'Negociación no está activa');
    }

    // Verificar límite de rondas
    if (negotiationData.currentRound >= negotiationData.maxRounds) {
      throw new functions.https.HttpsError('failed-precondition', 'Máximo de rondas alcanzado');
    }

    // Crear nueva ronda
    const newRound = {
      round: negotiationData.currentRound + 1,
      proposedBy: negotiationData.passengerId === context.auth.uid ? 'passenger' : 'driver',
      amount: proposedPrice,
      notes: notes || '',
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    };

    // Actualizar negociación
    await negotiationRef.update({
      driverId: negotiationData.passengerId === context.auth.uid ? negotiationData.driverId : context.auth.uid,
      status: 'driverOffered',
      currentPrice: proposedPrice,
      currentRound: admin.firestore.FieldValue.increment(1),
      rounds: admin.firestore.FieldValue.arrayUnion(newRound),
      expiresAt: new Date(Date.now() + 5 * 60 * 1000) // 5 minutos para responder
    });

    // Notificar a la otra parte
    await notifyCounterOffer(negotiationId, newRound);

    return { success: true };

  } catch (error) {
    console.error('Error haciendo contraoferta:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================================================
// FUNCIONES DE PAGO
// ============================================================================

/**
 * Procesar pago con MercadoPago
 */
exports.processPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  try {
    const { tripId, paymentMethodId, amount, description } = data;
    const userId = context.auth.uid;

    // Verification Comment 13: Add rate limiting
    // Check rate limit (max 5 payment attempts per user per hour)
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    const recentPaymentsSnapshot = await db.collection('payments')
      .where('userId', '==', userId)
      .where('createdAt', '>=', oneHourAgo)
      .get();

    if (recentPaymentsSnapshot.size >= 5) {
      throw new functions.https.HttpsError('resource-exhausted',
        'Demasiados intentos de pago. Por favor espere una hora.');
    }

    // Verification Comment 13: Add idempotency check
    // Check if payment already exists for this trip
    const existingPaymentDoc = await db.collection('payments').doc(tripId).get();
    if (existingPaymentDoc.exists) {
      const existingPayment = existingPaymentDoc.data();
      if (existingPayment.status === 'approved' || existingPayment.status === 'pending') {
        // Return existing payment instead of creating new one
        return {
          success: true,
          payment: {
            preferenceId: existingPayment.preferenceId,
            init_point: existingPayment.init_point,
            sandbox_init_point: existingPayment.sandbox_init_point,
            status: existingPayment.status,
            external_reference: existingPayment.external_reference || tripId
          }
        };
      }
    }

    // Verificar viaje
    const tripDoc = await db.collection('trips').doc(tripId).get();
    if (!tripDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Viaje no encontrado');
    }

    const tripData = tripDoc.data();
    if (tripData.passengerId !== userId) {
      throw new functions.https.HttpsError('permission-denied', 'No autorizado');
    }

    // Crear preferencia en MercadoPago
    const preference = {
      items: [{
        title: description || `Viaje OasisTaxi - ${tripId}`,
        unit_price: amount,
        quantity: 1,
        currency_id: 'PEN'
      }],
      payer: {
        email: context.auth.token.email || 'user@oasistaxi.com'
      },
      external_reference: tripId,
      notification_url: functions.config().app?.webhook_url || `https://us-central1-${process.env.GCLOUD_PROJECT}.cloudfunctions.net/mercadopagoWebhook`,
      auto_return: 'approved',
      payment_methods: {
        excluded_payment_types: [],
        installments: 12
      }
    };

    const response = await mercadopago.preferences.create(preference);
    const { body } = response;
    const payment = {
      preferenceId: body.id,
      external_reference: tripId,
      status: 'pending',
      status_detail: 'pending_payment',
      transaction_amount: amount,
      init_point: body.init_point,
      sandbox_init_point: body.sandbox_init_point
    };

    // Guardar información del pago
    await db.collection('payments').doc(tripId).set({
      tripId,
      userId: userId,
      preferenceId: payment.preferenceId,
      external_reference: payment.external_reference,
      amount,
      status: payment.status,
      paymentMethodId,
      transactionId: payment.preferenceId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      metadata: {
        external_reference: tripId,
        description
      }
    });

    return {
      success: true,
      payment: {
        preferenceId: payment.preferenceId,
        init_point: payment.init_point,
        sandbox_init_point: payment.sandbox_init_point,
        status: payment.status,
        external_reference: payment.external_reference
      }
    };

  } catch (error) {
    console.error('Error procesando pago:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Webhook de MercadoPago
 */
exports.mercadopagoWebhook = functions.https.onRequest(async (req, res) => {
  cors(req, res, async () => {
    try {
      const { data, type } = req.body;

      if (type === 'payment') {
        const paymentId = data.id;

        // Get real payment from MercadoPago
        const paymentResponse = await mercadopago.payment.get(paymentId);
        const payment = paymentResponse.body;

        // Validate webhook signature
        const signature = req.headers['x-signature'];
        const requestId = req.headers['x-request-id'];
        const webhookSecret = functions.config().mercadopago?.webhook_secret || '';

        if (!validateWebhookSignature(req.body, signature, requestId, webhookSecret)) {
          console.error('Invalid webhook signature');
          return res.status(401).send('Unauthorized');
        }

        if (payment.status === 'approved') {
          // Verification Comment 2: Get commission rate before transaction
          const commissionRate = await getCommissionRate();

          // Use Firestore transaction for atomic updates
          await db.runTransaction(async (transaction) => {
            // Update payment status using external_reference (tripId)
            const tripId = payment.external_reference;
            const paymentDocRef = db.collection('payments').doc(tripId);
            const paymentDoc = await transaction.get(paymentDocRef);

            // Check for duplicate processing (idempotency)
            if (paymentDoc.exists && paymentDoc.data().status === 'approved') {
              console.log('Payment already processed, skipping:', paymentId);
              return;
            }

            if (paymentDoc.exists) {
              const paymentData = paymentDoc.data();

              transaction.update(paymentDocRef, {
                status: 'approved',
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
                mercadopagoData: {
                  transactionAmount: payment.transaction_amount,
                  paymentMethodId: payment.payment_method_id,
                  statusDetail: payment.status_detail
                }
              });

              // Update trip payment status
              const tripRef = db.collection('trips').doc(tripId);
              transaction.update(tripRef, {
                paymentStatus: 'paid',
                paidAt: admin.firestore.FieldValue.serverTimestamp()
              });

              // Verification Comment 9: Use transaction.get for consistency
              // Update driver wallet
              const tripDoc = await transaction.get(tripRef);
              if (tripDoc.exists) {
                const tripData = tripDoc.data();
                const driverId = tripData.driverId;
                const amount = payment.transaction_amount;
                // Verification Comment 2: Use pre-fetched commission rate
                const commission = amount * commissionRate;
                const driverEarning = amount - commission;

                // Update driver wallet
                const walletRef = db.collection('wallets').doc(driverId);
                transaction.update(walletRef, {
                  balance: admin.firestore.FieldValue.increment(driverEarning),
                  totalEarnings: admin.firestore.FieldValue.increment(driverEarning),
                  lastActivityDate: admin.firestore.FieldValue.serverTimestamp()
                });

                // Create wallet transaction
                const walletTransactionRef = db.collection('walletTransactions').doc();
                transaction.set(walletTransactionRef, {
                  walletId: driverId,
                  type: 'earning',
                  amount: driverEarning,
                  status: 'completed',
                  tripId: tripId,
                  description: `Ganancia por viaje ${tripId}`,
                  metadata: {
                    grossAmount: amount,
                    commission: commission,
                    paymentId: paymentId
                  },
                  createdAt: admin.firestore.FieldValue.serverTimestamp(),
                  processedAt: admin.firestore.FieldValue.serverTimestamp()
                });
              }
            }
          });

          // Notify driver about payment
          await notifyDriverPaymentReceived(payment.external_reference);
        }
      }

      res.status(200).send('OK');

    } catch (error) {
      console.error('Error en webhook MercadoPago:', error);
      res.status(500).send('Error');
    }
  });
});

// ============================================================================
// FUNCIONES DE NOTIFICACIONES
// ============================================================================

/**
 * Enviar notificación push
 */
async function sendPushNotification(userId, title, body, data = {}) {
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) return;

    const userData = userDoc.data();
    const deviceTokens = userData.deviceTokens || [];

    if (deviceTokens.length === 0) return;

    const message = {
      notification: {
        title,
        body
      },
      data: {
        ...data,
        timestamp: Date.now().toString()
      },
      tokens: deviceTokens
    };

    const response = await messaging.sendMulticast(message);
    
    // Limpiar tokens inválidos
    if (response.failureCount > 0) {
      const failedTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          failedTokens.push(deviceTokens[idx]);
        }
      });

      await db.collection('users').doc(userId).update({
        deviceTokens: admin.firestore.FieldValue.arrayRemove(...failedTokens)
      });
    }

    console.log(`Notificación enviada a ${userId}: ${title}`);

  } catch (error) {
    console.error('Error enviando notificación:', error);
  }
}

/**
 * Notificar conductores cercanos sobre nueva solicitud
 */
async function notifyNearbyDrivers(tripId, tripData) {
  try {
    // Buscar conductores disponibles en un radio de 10km
    const driversQuery = await db.collection('users')
      .where('userType', '==', 'driver')
      .where('isActive', '==', true)
      .where('isAvailable', '==', true)
      .get();

    const notifications = [];
    
    driversQuery.forEach(driverDoc => {
      const driverData = driverDoc.data();
      
      // Verificar si el conductor tiene el tipo de vehículo solicitado
      if (driverData.vehicleType === tripData.vehicleType) {
        notifications.push(
          sendPushNotification(
            driverDoc.id,
            'Nueva solicitud de viaje',
            `Viaje desde ${tripData.pickupLocation.address} - S/ ${tripData.proposedPrice}`,
            {
              type: 'new_trip_request',
              tripId: tripId,
              proposedPrice: tripData.proposedPrice.toString()
            }
          )
        );
      }
    });

    await Promise.all(notifications);

  } catch (error) {
    console.error('Error notificando conductores:', error);
  }
}

/**
 * Enviar notificación de bienvenida
 */
async function sendWelcomeNotification(userId, userType) {
  const title = '¡Bienvenido a OasisTaxi!';
  const body = userType === 'driver' ?
    'Tu cuenta está siendo verificada. Te notificaremos cuando esté lista.' :
    '¡Comienza a viajar de manera segura y cómoda!';

  await sendPushNotification(userId, title, body, {
    type: 'welcome',
    userType
  });
}

/**
 * Validate MercadoPago webhook signature
 */
function validateWebhookSignature(payload, signature, requestId, secret) {
  // Parse MercadoPago signature header
  // Format: "ts=timestamp,v1=signature"
  if (!signature || !secret) return false;

  const parts = signature.split(',');
  let ts = '';
  let v1 = '';

  for (const part of parts) {
    const [key, value] = part.split('=');
    if (key === 'ts') ts = value;
    if (key === 'v1') v1 = value;
  }

  if (!ts || !v1) return false;

  // Build canonical string per MercadoPago docs
  // Format: "id:<notification_id>;request-id:<request_id>;ts:<timestamp>"
  const dataId = payload.data?.id || '';
  const canonicalString = `id:${dataId};request-id:${requestId || ''};ts:${ts}`;

  // Compute HMAC-SHA256
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(canonicalString)
    .digest('hex');

  // Equal-length guard before comparison
  if (v1.length !== expectedSignature.length) {
    return false;
  }

  // Constant-time comparison
  return crypto.timingSafeEqual(
    Buffer.from(v1, 'hex'),
    Buffer.from(expectedSignature, 'hex')
  );
}

/**
 * Process withdrawal request
 */
exports.processWithdrawal = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  try {
    const { amount, bankAccount, notes, driverId } = data;

    // Verification Comment 8: Validate driverId matches auth.uid if provided
    if (driverId && driverId !== context.auth.uid) {
      throw new functions.https.HttpsError('permission-denied', 'No autorizado para esta operación');
    }

    // Always use auth.uid as the actual driverId
    const actualDriverId = context.auth.uid;

    // Validate withdrawal amount
    const walletDoc = await db.collection('wallets').doc(actualDriverId).get();
    if (!walletDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Billetera no encontrada');
    }

    const walletData = walletDoc.data();
    const availableBalance = walletData.balance - (walletData.pendingBalance || 0);

    if (amount > availableBalance) {
      throw new functions.https.HttpsError('failed-precondition', 'Saldo insuficiente');
    }

    if (amount < 10) {
      throw new functions.https.HttpsError('invalid-argument', 'Monto mínimo S/ 10');
    }

    // Create withdrawal request
    const withdrawalRef = db.collection('withdrawalRequests').doc();
    await db.runTransaction(async (transaction) => {
      transaction.set(withdrawalRef, {
        walletId: actualDriverId,
        amount: amount,
        status: 'pending',
        bankAccount: bankAccount,
        notes: notes,
        requestedAt: admin.firestore.FieldValue.serverTimestamp(),
        metadata: {
          balanceAtRequest: walletData.balance,
          currency: 'PEN'
        }
      });

      // Update pending balance
      transaction.update(walletDoc.ref, {
        pendingBalance: admin.firestore.FieldValue.increment(amount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Create pending transaction
      const transactionRef = db.collection('walletTransactions').doc();
      transaction.set(transactionRef, {
        walletId: actualDriverId,
        type: 'withdrawal',
        amount: amount,
        status: 'pending',
        description: 'Solicitud de retiro',
        metadata: {
          withdrawalRequestId: withdrawalRef.id,
          bankAccount: bankAccount
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    });

    return {
      success: true,
      withdrawalId: withdrawalRef.id,
      status: 'pending',
      estimatedProcessingTime: '1-3 días hábiles'
    };

  } catch (error) {
    console.error('Error processing withdrawal:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Transfer money between drivers
 */
exports.transferBetweenDrivers = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  try {
    const { toDriverId, amount, concept } = data;
    const fromDriverId = context.auth.uid;

    if (fromDriverId === toDriverId) {
      throw new functions.https.HttpsError('invalid-argument', 'No puede transferir a sí mismo');
    }

    if (amount <= 0) {
      throw new functions.https.HttpsError('invalid-argument', 'Monto inválido');
    }

    // Get both wallets
    const fromWalletDoc = await db.collection('wallets').doc(fromDriverId).get();
    const toWalletDoc = await db.collection('wallets').doc(toDriverId).get();

    if (!fromWalletDoc.exists || !toWalletDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Billetera no encontrada');
    }

    const fromWalletData = fromWalletDoc.data();
    const availableBalance = fromWalletData.balance - (fromWalletData.pendingBalance || 0);

    if (amount > availableBalance) {
      throw new functions.https.HttpsError('failed-precondition', 'Saldo insuficiente');
    }

    // Execute transfer in transaction
    const transferId = db.collection('transfers').doc().id;

    await db.runTransaction(async (transaction) => {
      // Debit from sender
      transaction.update(fromWalletDoc.ref, {
        balance: admin.firestore.FieldValue.increment(-amount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Credit to receiver
      transaction.update(toWalletDoc.ref, {
        balance: admin.firestore.FieldValue.increment(amount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Record debit transaction
      const debitTxRef = db.collection('walletTransactions').doc();
      transaction.set(debitTxRef, {
        walletId: fromDriverId,
        type: 'transfer_out',
        amount: -amount,
        status: 'completed',
        transferId: transferId,
        toDriverId: toDriverId,
        description: concept || 'Transferencia',
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Record credit transaction
      const creditTxRef = db.collection('walletTransactions').doc();
      transaction.set(creditTxRef, {
        walletId: toDriverId,
        type: 'transfer_in',
        amount: amount,
        status: 'completed',
        transferId: transferId,
        fromDriverId: fromDriverId,
        description: concept || 'Transferencia recibida',
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Record transfer
      const transferRef = db.collection('transfers').doc(transferId);
      transaction.set(transferRef, {
        fromDriverId: fromDriverId,
        toDriverId: toDriverId,
        amount: amount,
        concept: concept,
        status: 'completed',
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    });

    return {
      success: true,
      transferId: transferId,
      status: 'completed'
    };

  } catch (error) {
    console.error('Error processing transfer:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Process Yape payment
 */
exports.processYape = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  try {
    const { tripId, amount, phoneNumber, transactionCode } = data;

    // TODO: Integrate with Yape API when available
    // For now, create a pending payment record

    const paymentRef = db.collection('payments').doc(tripId);
    await paymentRef.set({
      tripId,
      userId: context.auth.uid,
      amount,
      paymentMethod: 'yape',
      status: 'pending',
      phoneNumber,
      transactionCode,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return {
      success: true,
      paymentId: paymentRef.id,
      qrUrl: `yape://payment?amount=${amount}&phone=${phoneNumber}`,
      instructions: 'Complete el pago en la app Yape'
    };

  } catch (error) {
    console.error('Error processing Yape payment:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Process Plin payment
 */
exports.processPlin = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  try {
    const { tripId, amount, phoneNumber, transactionCode } = data;

    // TODO: Integrate with Plin API when available
    // For now, create a pending payment record

    const paymentRef = db.collection('payments').doc(tripId);
    await paymentRef.set({
      tripId,
      userId: context.auth.uid,
      amount,
      paymentMethod: 'plin',
      status: 'pending',
      phoneNumber,
      transactionCode,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return {
      success: true,
      paymentId: paymentRef.id,
      qrUrl: `plin://payment?amount=${amount}&phone=${phoneNumber}`,
      instructions: 'Complete el pago en la app Plin'
    };

  } catch (error) {
    console.error('Error processing Plin payment:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Get payment status
 */
exports.getPaymentStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  try {
    const { paymentId } = data;

    const paymentDoc = await db.collection('payments').doc(paymentId).get();

    if (!paymentDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Pago no encontrado');
    }

    const paymentData = paymentDoc.data();

    // Verify the user has access to this payment
    if (paymentData.userId !== context.auth.uid && paymentData.driverId !== context.auth.uid) {
      throw new functions.https.HttpsError('permission-denied', 'No autorizado');
    }

    return {
      success: true,
      status: paymentData.status,
      amount: paymentData.amount,
      paymentMethod: paymentData.paymentMethod,
      createdAt: paymentData.createdAt,
      completedAt: paymentData.completedAt,
      metadata: paymentData.metadata
    };

  } catch (error) {
    console.error('Error getting payment status:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * List user payments
 */
exports.listUserPayments = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  try {
    const { role = 'passenger', limit = 20, startAfter } = data;
    const userId = context.auth.uid;

    let query = db.collection('payments');

    if (role === 'driver') {
      // Get driver payments from wallet transactions
      query = db.collection('walletTransactions')
        .where('walletId', '==', userId)
        .where('type', 'in', ['earning', 'withdrawal', 'bonus'])
        .orderBy('createdAt', 'desc');
    } else {
      // Get passenger payments
      query = query
        .where('userId', '==', userId)
        .orderBy('createdAt', 'desc');
    }

    query = query.limit(limit);

    if (startAfter) {
      const lastDoc = await db.collection(role === 'driver' ? 'walletTransactions' : 'payments')
        .doc(startAfter)
        .get();
      if (lastDoc.exists) {
        query = query.startAfter(lastDoc);
      }
    }

    const snapshot = await query.get();

    const payments = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt?.toDate?.() || null
    }));

    return {
      success: true,
      payments,
      hasMore: snapshot.docs.length === limit,
      lastId: snapshot.docs.length > 0 ? snapshot.docs[snapshot.docs.length - 1].id : null
    };

  } catch (error) {
    console.error('Error listing payments:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Process payment refund
 */
exports.refundPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  try {
    const { paymentId, reason } = data;

    const paymentDoc = await db.collection('payments').doc(paymentId).get();

    if (!paymentDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Pago no encontrado');
    }

    const paymentData = paymentDoc.data();

    // Verify authorization (only admin or the passenger)
    if (paymentData.userId !== context.auth.uid && !context.auth.token.admin) {
      throw new functions.https.HttpsError('permission-denied', 'No autorizado');
    }

    if (paymentData.status !== 'approved') {
      throw new functions.https.HttpsError('failed-precondition', 'Pago no está aprobado');
    }

    // For MercadoPago payments, call MercadoPago refund API
    if (paymentData.paymentMethod === 'mercadopago' && paymentData.mercadopagoData?.paymentId) {
      // TODO: Implement MercadoPago refund API call
      // const refund = await mercadopago.refund.create({
      //   payment_id: paymentData.mercadopagoData.paymentId
      // });
    }

    // Process refund in Firestore
    await db.runTransaction(async (transaction) => {
      // Update payment status
      transaction.update(paymentDoc.ref, {
        status: 'refunded',
        refundedAt: admin.firestore.FieldValue.serverTimestamp(),
        refundReason: reason
      });

      // If trip exists, update it
      if (paymentData.tripId) {
        const tripRef = db.collection('trips').doc(paymentData.tripId);
        transaction.update(tripRef, {
          paymentStatus: 'refunded',
          refundedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }

      // Create refund transaction for driver (debit their wallet)
      if (paymentData.driverId) {
        const walletRef = db.collection('wallets').doc(paymentData.driverId);
        const walletDoc = await transaction.get(walletRef);

        if (walletDoc.exists) {
          const commissionRate = await getCommissionRate();
          const driverAmount = paymentData.amount * (1 - commissionRate);

          transaction.update(walletRef, {
            balance: admin.firestore.FieldValue.increment(-driverAmount),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });

          // Create refund transaction record
          const refundTxRef = db.collection('walletTransactions').doc();
          transaction.set(refundTxRef, {
            walletId: paymentData.driverId,
            type: 'refund',
            amount: -driverAmount,
            status: 'completed',
            paymentId: paymentId,
            description: `Reembolso por viaje ${paymentData.tripId}`,
            reason: reason,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
          });
        }
      }
    });

    return {
      success: true,
      refundId: `REF-${paymentId}`,
      status: 'completed',
      message: 'Reembolso procesado exitosamente'
    };

  } catch (error) {
    console.error('Error processing refund:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================================================
// FUNCIONES DE UTILIDAD
// ============================================================================

/**
 * Get commission rate from config
 */
async function getCommissionRate() {
  try {
    const configDoc = await db.collection('app_settings').doc('commission').get();
    if (configDoc.exists) {
      return configDoc.data().rate || 0.20;
    }
    return 0.20; // Default 20% commission
  } catch (error) {
    console.error('Error getting commission rate:', error);
    return 0.20;
  }
}

/**
 * Calcular distancia y tiempo estimado entre dos puntos
 */
async function calculateTripEstimates(pickupLocation, destinationLocation) {
  // Aquí iría la integración real con Google Maps Distance Matrix API
  // Por ahora retornamos valores estimados
  
  const lat1 = pickupLocation.latitude;
  const lon1 = pickupLocation.longitude;
  const lat2 = destinationLocation.latitude;
  const lon2 = destinationLocation.longitude;

  // Fórmula de Haversine para calcular distancia aproximada
  const R = 6371; // Radio de la Tierra en km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  const distance = R * c;

  // Estimar tiempo basado en velocidad promedio en Lima (20 km/h)
  const duration = (distance / 20) * 60; // minutos

  return {
    distance: Math.round(distance * 100) / 100, // Redondear a 2 decimales
    duration: Math.ceil(duration)
  };
}

/**
 * Generar código de verificación de 4 dígitos
 */
function generateVerificationCode() {
  return Math.floor(1000 + Math.random() * 9000).toString();
}

/**
 * Generar ID único para pagos
 */
function generatePaymentId() {
  return 'pay_' + crypto.randomBytes(16).toString('hex');
}

/**
 * Programar expiración de solicitud de viaje
 */
async function scheduleRequestExpiration(tripId) {
  // Programar Cloud Task para expirar la solicitud en 15 minutos
  // Por ahora usamos setTimeout (no recomendado para producción)
  setTimeout(async () => {
    try {
      const tripRef = db.collection('trips').doc(tripId);
      const tripDoc = await tripRef.get();
      
      if (tripDoc.exists && tripDoc.data().status === 'requested') {
        await tripRef.update({
          status: 'expired',
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
          cancelReason: 'expired'
        });
      }
    } catch (error) {
      console.error('Error expirando solicitud:', error);
    }
  }, 15 * 60 * 1000); // 15 minutos
}

// Funciones adicionales de notificación
async function notifyPassengerTripAccepted(tripId) {
  const tripDoc = await db.collection('trips').doc(tripId).get();
  if (tripDoc.exists) {
    const tripData = tripDoc.data();
    await sendPushNotification(
      tripData.passengerId,
      'Viaje aceptado',
      'Un conductor aceptó tu viaje. Te estará contactando pronto.',
      { type: 'trip_accepted', tripId }
    );
  }
}

async function notifyPassengerTripStarted(tripId) {
  const tripDoc = await db.collection('trips').doc(tripId).get();
  if (tripDoc.exists) {
    const tripData = tripDoc.data();
    await sendPushNotification(
      tripData.passengerId,
      'Viaje iniciado',
      'Tu viaje ha comenzado. ¡Disfruta el trayecto!',
      { type: 'trip_started', tripId }
    );
  }
}

async function notifyTripCompleted(tripId) {
  const tripDoc = await db.collection('trips').doc(tripId).get();
  if (tripDoc.exists) {
    const tripData = tripDoc.data();
    await Promise.all([
      sendPushNotification(
        tripData.passengerId,
        'Viaje completado',
        '¡Viaje finalizado! Por favor califica tu experiencia.',
        { type: 'trip_completed', tripId }
      ),
      sendPushNotification(
        tripData.driverId,
        'Viaje completado',
        'Viaje finalizado exitosamente. ¡Gracias por tu servicio!',
        { type: 'trip_completed', tripId }
      )
    ]);
  }
}

async function notifyCounterOffer(negotiationId, round) {
  // Implementar notificación de contraoferta
  console.log(`Contraoferta en negociación ${negotiationId}:`, round);
}

async function notifyDriverPaymentReceived(tripId) {
  const tripDoc = await db.collection('trips').doc(tripId).get();
  if (tripDoc.exists) {
    const tripData = tripDoc.data();
    await sendPushNotification(
      tripData.driverId,
      'Pago recibido',
      'El pago del viaje ha sido procesado exitosamente.',
      { type: 'payment_received', tripId }
    );
  }
}

async function cancelDriverNotifications(tripId, acceptedDriverId) {
  // Implementar cancelación de notificaciones a otros conductores
  console.log(`Cancelando notificaciones para viaje ${tripId}, conductor aceptado: ${acceptedDriverId}`);
}

// ============================================================================
// FUNCIONES DE ADMINISTRACIÓN
// ============================================================================

/**
 * Verificar documento de conductor
 */
exports.verifyDriverDocument = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  // Verificar que es administrador
  const adminDoc = await db.collection('users').doc(context.auth.uid).get();
  if (!adminDoc.exists || adminDoc.data().userType !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Solo administradores pueden verificar documentos');
  }

  try {
    const { documentId, status, notes } = data;

    await db.collection('documents').doc(documentId).update({
      status, // 'approved' o 'rejected'
      verificationNotes: notes || '',
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      verifiedBy: context.auth.uid
    });

    // Notificar al conductor sobre la decisión
    const docData = (await db.collection('documents').doc(documentId).get()).data();
    await sendPushNotification(
      docData.userId,
      status === 'approved' ? 'Documento aprobado' : 'Documento rechazado',
      status === 'approved' ? 
        'Tu documento ha sido verificado exitosamente.' : 
        `Tu documento fue rechazado: ${notes}`,
      {
        type: 'document_verification',
        status,
        documentType: docData.documentType
      }
    );

    return { success: true };

  } catch (error) {
    console.error('Error verificando documento:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Obtener estadísticas del dashboard administrativo
 */
exports.getDashboardStats = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  // Verificar que es administrador
  const adminDoc = await db.collection('users').doc(context.auth.uid).get();
  if (!adminDoc.exists || adminDoc.data().userType !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Solo administradores pueden ver estadísticas');
  }

  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // Consultas paralelas para optimizar rendimiento
    const [
      totalUsersSnapshot,
      activeDriversSnapshot,
      todayTripsSnapshot,
      todayRevenueSnapshot
    ] = await Promise.all([
      db.collection('users').where('isActive', '==', true).get(),
      db.collection('users')
        .where('userType', '==', 'driver')
        .where('isActive', '==', true)
        .where('isAvailable', '==', true)
        .get(),
      db.collection('trips')
        .where('createdAt', '>=', today)
        .get(),
      db.collection('payments')
        .where('createdAt', '>=', today)
        .where('status', '==', 'approved')
        .get()
    ]);

    // Calcular estadísticas
    const totalUsers = totalUsersSnapshot.size;
    const activeDrivers = activeDriversSnapshot.size;
    const tripsToday = todayTripsSnapshot.size;
    
    let revenueToday = 0;
    todayRevenueSnapshot.forEach(doc => {
      revenueToday += doc.data().amount || 0;
    });

    // Calcular promedio de calificaciones
    let totalRating = 0;
    let ratingCount = 0;
    totalUsersSnapshot.forEach(doc => {
      const userData = doc.data();
      if (userData.rating && userData.totalRatings) {
        totalRating += userData.rating * userData.totalRatings;
        ratingCount += userData.totalRatings;
      }
    });

    const averageRating = ratingCount > 0 ? totalRating / ratingCount : 0;

    return {
      totalUsers,
      activeDrivers,
      tripsToday,
      revenueToday: Math.round(revenueToday * 100) / 100,
      averageRating: Math.round(averageRating * 10) / 10,
      completionRate: 0.94, // Calcular dinámicamente en producción
      responseTime: 3.2, // Calcular dinámicamente en producción
      peakHours: ['08:00', '18:00', '22:00'] // Calcular dinámicamente
    };

  } catch (error) {
    console.error('Error obteniendo estadísticas:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Obtener análisis de ganancias para conductores
 */
exports.getEarningsAnalysis = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated',
      'Usuario no autenticado');
  }

  const { driverId, period = 'week' } = data;

  try {
    const now = new Date();
    let startDate = new Date();

    // Determinar período
    switch (period) {
      case 'day':
        startDate.setHours(0, 0, 0, 0);
        break;
      case 'week':
        startDate.setDate(now.getDate() - 7);
        break;
      case 'month':
        startDate.setMonth(now.getMonth() - 1);
        break;
      case 'year':
        startDate.setFullYear(now.getFullYear() - 1);
        break;
    }

    // Obtener transacciones del período
    const transactionsSnapshot = await db.collection('walletTransactions')
      .where('walletId', '==', driverId)
      .where('type', '==', 'earning')
      .where('status', '==', 'completed')
      .where('createdAt', '>=', startDate)
      .orderBy('createdAt', 'desc')
      .get();

    // Verification Comment 12: Get commission rate once before processing
    const commissionRate = await getCommissionRate();

    // Agrupar por día
    const dailyEarnings = {};
    const hourlyEarnings = new Array(24).fill(0);
    let totalEarnings = 0;
    let totalTrips = 0;
    let totalCommission = 0;

    transactionsSnapshot.forEach(doc => {
      const transaction = doc.data();
      const date = transaction.createdAt.toDate();
      const day = date.toISOString().split('T')[0];
      const hour = date.getHours();

      // All earnings in walletTransactions are already net of commission
      if (!dailyEarnings[day]) {
        dailyEarnings[day] = { earnings: 0, trips: 0, commission: 0 };
      }

      const netAmount = transaction.amount || 0;
      // Commission was already deducted - stored in metadata if available
      // If not in metadata, estimate based on configured rate
      const estimatedGross = netAmount / (1 - commissionRate); // Reverse calculation
      const commission = transaction.metadata?.commission || (estimatedGross * commissionRate);

      dailyEarnings[day].earnings += netAmount;
      dailyEarnings[day].trips += 1;
      dailyEarnings[day].commission += commission;

      hourlyEarnings[hour] += netAmount;
      totalEarnings += netAmount;
      totalTrips += 1;
      totalCommission += commission;
    });

    // Calcular promedio diario
    const daysWithEarnings = Object.keys(dailyEarnings).length || 1;
    const dailyAverage = totalEarnings / daysWithEarnings;

    // Encontrar mejor día y hora
    let bestDay = { date: '', earnings: 0 };
    let bestHour = { hour: 0, earnings: 0 };

    Object.entries(dailyEarnings).forEach(([date, data]) => {
      if (data.earnings > bestDay.earnings) {
        bestDay = { date, earnings: data.earnings };
      }
    });

    hourlyEarnings.forEach((earnings, hour) => {
      if (earnings > bestHour.earnings) {
        bestHour = { hour, earnings };
      }
    });

    // Calcular meta y progreso
    const monthlyGoal = 5000; // Meta mensual en soles
    const dailyGoal = monthlyGoal / 30;
    const weeklyGoal = monthlyGoal / 4;

    let currentPeriodEarnings = 0;
    let periodGoal = 0;

    switch (period) {
      case 'day':
        currentPeriodEarnings = dailyEarnings[now.toISOString().split('T')[0]]?.earnings || 0;
        periodGoal = dailyGoal;
        break;
      case 'week':
        currentPeriodEarnings = totalEarnings;
        periodGoal = weeklyGoal;
        break;
      case 'month':
        currentPeriodEarnings = totalEarnings;
        periodGoal = monthlyGoal;
        break;
    }

    const goalProgress = (currentPeriodEarnings / periodGoal) * 100;

    return {
      summary: {
        totalEarnings: Math.round(totalEarnings * 100) / 100,
        totalTrips,
        totalCommission: Math.round(totalCommission * 100) / 100,
        dailyAverage: Math.round(dailyAverage * 100) / 100,
        goalProgress: Math.min(100, Math.round(goalProgress))
      },
      dailyBreakdown: Object.entries(dailyEarnings).map(([date, data]) => ({
        date,
        ...data,
        earnings: Math.round(data.earnings * 100) / 100,
        commission: Math.round(data.commission * 100) / 100
      })),
      hourlyDistribution: hourlyEarnings.map(e => Math.round(e * 100) / 100),
      insights: {
        bestDay,
        bestHour: `${bestHour.hour}:00 - ${bestHour.hour + 1}:00`,
        averageTripEarnings: totalTrips > 0 ?
          Math.round((totalEarnings / totalTrips) * 100) / 100 : 0,
        projectedMonthly: Math.round(dailyAverage * 30 * 100) / 100
      },
      goals: {
        daily: dailyGoal,
        weekly: weeklyGoal,
        monthly: monthlyGoal,
        currentProgress: Math.round(currentPeriodEarnings * 100) / 100,
        percentComplete: Math.min(100, Math.round(goalProgress))
      }
    };

  } catch (error) {
    console.error('Error analizando ganancias:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================================================
// FUNCIONES PROGRAMADAS
// ============================================================================

/**
 * Limpiar datos antiguos (ejecutar diariamente)
 */
exports.cleanupOldData = functions.pubsub.schedule('0 2 * * *')
  .timeZone('America/Lima')
  .onRun(async (context) => {
    try {
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      // Limpiar negociaciones expiradas
      const expiredNegotiations = await db.collection('priceNegotiations')
        .where('expiresAt', '<', thirtyDaysAgo)
        .get();

      const batch = db.batch();
      expiredNegotiations.forEach(doc => {
        batch.delete(doc.ref);
      });

      await batch.commit();

      console.log(`Limpieza completada: ${expiredNegotiations.size} negociaciones eliminadas`);

    } catch (error) {
      console.error('Error en limpieza de datos:', error);
    }
  });

/**
 * Generar reportes diarios
 */
exports.generateDailyReports = functions.pubsub.schedule('0 23 * * *')
  .timeZone('America/Lima')
  .onRun(async (context) => {
    try {
      const today = new Date();
      const yesterday = new Date(today.getTime() - 24 * 60 * 60 * 1000);
      
      // Generar reporte diario de métricas
      const report = {
        date: yesterday.toISOString().split('T')[0],
        totalTrips: 0,
        totalRevenue: 0,
        averageRating: 0,
        generatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      // Calcular métricas del día anterior
      const tripsSnapshot = await db.collection('trips')
        .where('createdAt', '>=', yesterday)
        .where('createdAt', '<', today)
        .get();

      report.totalTrips = tripsSnapshot.size;

      // Guardar reporte
      await db.collection('daily_reports').add(report);

      console.log(`Reporte diario generado para ${report.date}`);

    } catch (error) {
      console.error('Error generando reporte diario:', error);
    }
  });

// ============================================================================
// FUNCIONES DE EMERGENCIA
// ============================================================================

/**
 * Manejar emergencia SOS
 */
exports.handleEmergency = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  try {
    const { tripId, location, emergencyType, notes } = data;

    // Crear registro de emergencia
    const emergencyData = {
      userId: context.auth.uid,
      tripId: tripId || null,
      location,
      emergencyType,
      notes: notes || '',
      status: 'active',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      respondedAt: null,
      responseTeam: null
    };

    const emergencyRef = await db.collection('emergencies').add(emergencyData);

    // Notificar a servicios de emergencia (simulado)
    console.log(`EMERGENCIA ACTIVADA: ${emergencyRef.id} por usuario ${context.auth.uid}`);

    // Notificar a contactos de emergencia del usuario
    const userDoc = await db.collection('users').doc(context.auth.uid).get();
    if (userDoc.exists) {
      const userData = userDoc.data();
      const emergencyContacts = userData.emergencyContacts || [];

      for (const contact of emergencyContacts) {
        // Enviar SMS o notificación a contactos de emergencia
        console.log(`Notificando emergencia a: ${contact.phone}`);
      }
    }

    return {
      success: true,
      emergencyId: emergencyRef.id,
      responseTime: '5-10 minutos',
      contactNumber: '+51-1-105',
      referenceCode: `SOS-${emergencyRef.id.substring(0, 6).toUpperCase()}`
    };

  } catch (error) {
    console.error('Error manejando emergencia:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================================================
// FUNCIONES FCM PARA NOTIFICACIONES (Comment 1 fix)
// ============================================================================

/**
 * Send ride notification to single driver
 */
exports.sendRideNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  const { token, tripId, pickupAddress, destinationAddress, estimatedFare, estimatedDistance, passengerName } = data;

  if (!token || !tripId) {
    throw new functions.https.HttpsError('invalid-argument', 'Parámetros requeridos faltantes');
  }

  try {
    const message = {
      token: token,
      notification: {
        title: '🚕 Nueva solicitud de viaje',
        body: `De: ${pickupAddress}\nA: ${destinationAddress}\nTarifa: S/ ${estimatedFare.toFixed(2)}`,
      },
      data: {
        type: 'ride_request',
        tripId: tripId,
        pickupAddress: pickupAddress || '',
        destinationAddress: destinationAddress || '',
        estimatedFare: String(estimatedFare || 0),
        estimatedDistance: String(estimatedDistance || 0),
        passengerName: passengerName || 'Pasajero',
        timestamp: String(Date.now()),
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
    };

    await messaging.send(message);
    return { success: true };
  } catch (error) {
    console.error('Error enviando notificación de viaje:', error);
    throw new functions.https.HttpsError('internal', 'Error al enviar notificación');
  }
});

/**
 * Send bulk ride notifications to multiple drivers
 */
exports.sendBulkRideNotifications = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  const { tokens, tripId, pickupAddress, destinationAddress, estimatedFare, estimatedDistance, passengerName } = data;

  if (!tokens || !Array.isArray(tokens) || tokens.length === 0 || !tripId) {
    throw new functions.https.HttpsError('invalid-argument', 'Parámetros requeridos faltantes');
  }

  if (tokens.length > 500) {
    throw new functions.https.HttpsError('invalid-argument', 'Máximo 500 tokens por lote');
  }

  try {
    const message = {
      tokens: tokens,
      notification: {
        title: '🚕 Nueva solicitud de viaje',
        body: `De: ${pickupAddress}\nA: ${destinationAddress}\nTarifa: S/ ${estimatedFare.toFixed(2)}`,
      },
      data: {
        type: 'ride_request',
        tripId: tripId,
        pickupAddress: pickupAddress || '',
        destinationAddress: destinationAddress || '',
        estimatedFare: String(estimatedFare || 0),
        estimatedDistance: String(estimatedDistance || 0),
        passengerName: passengerName || 'Pasajero',
        timestamp: String(Date.now()),
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
    };

    const response = await messaging.sendMulticast(message);
    const successfulTokens = [];
    response.responses.forEach((resp, idx) => {
      if (resp.success) {
        successfulTokens.push(tokens[idx]);
      }
    });

    return {
      success: true,
      successfulTokens: successfulTokens,
      successCount: response.successCount,
      failureCount: response.failureCount
    };
  } catch (error) {
    console.error('Error enviando notificaciones masivas:', error);
    throw new functions.https.HttpsError('internal', 'Error al enviar notificaciones');
  }
});

/**
 * Send trip status notification
 */
exports.sendTripStatusNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  const { token, tripId, status, driverName, vehicleInfo, customData } = data;

  if (!token || !tripId || !status) {
    throw new functions.https.HttpsError('invalid-argument', 'Parámetros requeridos faltantes');
  }

  try {
    let title = '🚕 Actualización de viaje';
    let body = '';

    switch (status) {
      case 'accepted':
        title = '✅ Viaje aceptado';
        body = `Conductor: ${driverName || 'Conductor'}\n${vehicleInfo || ''}`;
        break;
      case 'arrived':
        title = '📍 Conductor ha llegado';
        body = 'Tu conductor está esperándote';
        break;
      case 'started':
        title = '🚗 Viaje iniciado';
        body = 'En camino a tu destino';
        break;
      case 'completed':
        title = '✅ Viaje completado';
        body = 'Gracias por viajar con nosotros';
        break;
      case 'cancelled':
        title = '❌ Viaje cancelado';
        body = 'El viaje ha sido cancelado';
        break;
      default:
        body = `Estado: ${status}`;
    }

    const message = {
      token: token,
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: 'trip_status_update',
        tripId: tripId,
        status: status,
        driverName: driverName || '',
        vehicleInfo: vehicleInfo || '',
        ...customData,
        timestamp: String(Date.now()),
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
    };

    await messaging.send(message);
    return { success: true };
  } catch (error) {
    console.error('Error enviando actualización de estado:', error);
    throw new functions.https.HttpsError('internal', 'Error al enviar notificación');
  }
});

/**
 * Send custom notification
 */
exports.sendCustomNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  const { token, title, body, data: notificationData, imageUrl } = data;

  if (!token || !title || !body) {
    throw new functions.https.HttpsError('invalid-argument', 'Parámetros requeridos faltantes');
  }

  try {
    const message = {
      token: token,
      notification: {
        title: title,
        body: body,
        imageUrl: imageUrl,
      },
      data: {
        ...notificationData,
        timestamp: String(Date.now()),
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
    };

    await messaging.send(message);
    return { success: true };
  } catch (error) {
    console.error('Error enviando notificación personalizada:', error);
    throw new functions.https.HttpsError('internal', 'Error al enviar notificación');
  }
});

// ============================================================================
// VISION API CALLABLE (Comment 2 fix)
// ============================================================================

// Importar Google Cloud Vision
const vision = require('@google-cloud/vision');

/**
 * Annotate image using Cloud Vision API (server-side)
 */
exports.annotateImage = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  const { imageContent, storagePath } = data;

  if (!imageContent && !storagePath) {
    throw new functions.https.HttpsError('invalid-argument', 'Debe proporcionar imageContent o storagePath');
  }

  try {
    // Crear cliente de Vision API
    const client = new vision.ImageAnnotatorClient();

    // Preparar la imagen para análisis
    let image = {};
    if (imageContent) {
      // Usar contenido base64
      image = {
        content: imageContent
      };
    } else if (storagePath) {
      // Usar archivo de Cloud Storage
      const bucket = storage.bucket();
      const file = bucket.file(storagePath);
      const [exists] = await file.exists();

      if (!exists) {
        throw new functions.https.HttpsError('not-found', 'Archivo no encontrado en Storage');
      }

      image = {
        source: {
          gcsImageUri: `gs://${bucket.name}/${storagePath}`
        }
      };
    }

    // Configurar las características a detectar
    const features = [
      { type: 'TEXT_DETECTION', maxResults: 50 },
      { type: 'DOCUMENT_TEXT_DETECTION' },
      { type: 'FACE_DETECTION', maxResults: 10 },
      { type: 'SAFE_SEARCH_DETECTION' },
      { type: 'IMAGE_PROPERTIES' },
      { type: 'OBJECT_LOCALIZATION', maxResults: 20 }
    ];

    // Configurar contexto de imagen (idiomas)
    const imageContext = {
      languageHints: ['es', 'en']
    };

    // Construir la solicitud
    const request = {
      image: image,
      features: features,
      imageContext: imageContext
    };

    // Llamar a Vision API
    const [result] = await client.annotateImage(request);

    // Log para debugging
    console.log('Vision API procesada exitosamente');

    // Formatear y retornar la respuesta
    return {
      success: true,
      textAnnotations: result.textAnnotations || [],
      fullTextAnnotation: result.fullTextAnnotation || null,
      documentTextAnnotation: result.fullTextAnnotation || null, // Compatibilidad
      faceAnnotations: result.faceAnnotations || [],
      safeSearchAnnotation: result.safeSearchAnnotation || {
        adult: 'UNKNOWN',
        spoof: 'UNKNOWN',
        medical: 'UNKNOWN',
        violence: 'UNKNOWN',
        racy: 'UNKNOWN'
      },
      imagePropertiesAnnotation: result.imagePropertiesAnnotation || null,
      objectAnnotations: result.localizedObjectAnnotations || [],
      error: result.error || null
    };
  } catch (error) {
    console.error('Error procesando imagen con Vision API:', error);

    // Manejar errores específicos
    if (error.code === 7) {
      throw new functions.https.HttpsError('permission-denied', 'Sin permisos para Vision API');
    } else if (error.code === 3) {
      throw new functions.https.HttpsError('invalid-argument', 'Imagen inválida o corrupta');
    }

    throw new functions.https.HttpsError('internal', `Error al procesar imagen: ${error.message}`);
  }
});

// ============================================================================
// FUNCIONES PARA RECORDATORIOS DE VEHÍCULOS
// ============================================================================

/**
 * Cloud Function programada para verificar documentos próximos a vencer
 * Se ejecuta diariamente a las 9:00 AM hora de Perú (UTC-5)
 */
exports.checkDocumentExpiry = functions.pubsub
  .schedule('0 9 * * *')
  .timeZone('America/Lima')
  .onRun(async (context) => {
    console.log('Ejecutando verificación de documentos próximos a vencer');

    try {
      const now = new Date();
      const thirtyDaysFromNow = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
      const sevenDaysFromNow = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

      // Obtener todos los documentos de vehículos
      const documentsSnapshot = await db.collectionGroup('documents').get();

      const notifications = [];

      for (const doc of documentsSnapshot.docs) {
        const documentData = doc.data();
        const expiryDate = documentData.expiryDate?.toDate();

        if (!expiryDate) continue;

        // Calcular días hasta vencimiento
        const daysUntilExpiry = Math.floor((expiryDate - now) / (1000 * 60 * 60 * 24));

        // Obtener información del conductor
        const driverId = doc.ref.parent.parent?.id;
        if (!driverId) continue;

        const driverDoc = await db.collection('users').doc(driverId).get();
        if (!driverDoc.exists) continue;

        const driverData = driverDoc.data();
        const fcmToken = driverData.fcmToken;

        if (!fcmToken) continue;

        // Determinar el tipo de notificación según los días restantes
        let notificationTitle = '';
        let notificationBody = '';
        let priority = 'normal';

        if (daysUntilExpiry <= 0) {
          // Documento vencido
          notificationTitle = '⚠️ Documento Vencido';
          notificationBody = `Tu ${documentData.type} ha vencido. Actualízalo inmediatamente para continuar operando.`;
          priority = 'high';

          // Marcar conductor como inactivo si es documento crítico
          if (['SOAT', 'Licencia de Conducir', 'Tarjeta de Propiedad'].includes(documentData.type)) {
            await db.collection('users').doc(driverId).update({
              isActive: false,
              inactiveReason: `Documento vencido: ${documentData.type}`
            });
          }
        } else if (daysUntilExpiry <= 7) {
          // Urgente: menos de 7 días
          notificationTitle = '🚨 Documento por Vencer - URGENTE';
          notificationBody = `Tu ${documentData.type} vence en ${daysUntilExpiry} días. ¡Actualízalo ahora!`;
          priority = 'high';
        } else if (daysUntilExpiry <= 30) {
          // Recordatorio: menos de 30 días
          notificationTitle = '📋 Recordatorio de Documento';
          notificationBody = `Tu ${documentData.type} vence en ${daysUntilExpiry} días. No olvides renovarlo.`;
          priority = 'normal';
        } else {
          continue; // No enviar notificación si faltan más de 30 días
        }

        // Preparar notificación
        const notification = {
          token: fcmToken,
          notification: {
            title: notificationTitle,
            body: notificationBody
          },
          data: {
            type: 'document_expiry',
            documentType: documentData.type,
            documentId: doc.id,
            daysRemaining: daysUntilExpiry.toString(),
            expiryDate: expiryDate.toISOString(),
            screen: 'documents'
          },
          android: {
            priority: priority,
            notification: {
              channelId: 'document_reminders',
              priority: priority === 'high' ? 'max' : 'default',
              vibrateTimingsMillis: priority === 'high' ? [0, 250, 250, 250] : [0, 250]
            }
          },
          apns: {
            headers: {
              'apns-priority': priority === 'high' ? '10' : '5'
            },
            payload: {
              aps: {
                sound: priority === 'high' ? 'urgent.caf' : 'default',
                badge: 1
              }
            }
          }
        };

        notifications.push(notification);

        // Guardar registro de notificación en Firestore
        await db.collection('notifications').add({
          userId: driverId,
          type: 'document_expiry',
          title: notificationTitle,
          body: notificationBody,
          documentType: documentData.type,
          documentId: doc.id,
          daysUntilExpiry: daysUntilExpiry,
          priority: priority,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          read: false
        });
      }

      // Enviar todas las notificaciones en batch
      if (notifications.length > 0) {
        const results = await admin.messaging().sendEach(notifications);
        console.log(`Enviadas ${results.successCount} notificaciones de documentos, ${results.failureCount} fallidas`);
      }

      console.log('Verificación de documentos completada');
      return null;
    } catch (error) {
      console.error('Error verificando documentos:', error);
      throw error;
    }
  });

/**
 * Cloud Function programada para recordatorios de mantenimiento
 * Se ejecuta diariamente a las 8:00 AM hora de Perú (UTC-5)
 */
exports.checkMaintenanceReminders = functions.pubsub
  .schedule('0 8 * * *')
  .timeZone('America/Lima')
  .onRun(async (context) => {
    console.log('Ejecutando verificación de mantenimientos programados');

    try {
      const now = new Date();

      // Obtener todos los registros de mantenimiento
      const vehiclesSnapshot = await db.collection('vehicles').get();

      const notifications = [];

      for (const vehicleDoc of vehiclesSnapshot.docs) {
        const vehicleData = vehicleDoc.data();
        const driverId = vehicleData.driverId;

        if (!driverId) continue;

        // Obtener información del conductor
        const driverDoc = await db.collection('users').doc(driverId).get();
        if (!driverDoc.exists) continue;

        const driverData = driverDoc.data();
        const fcmToken = driverData.fcmToken;

        if (!fcmToken) continue;

        // Obtener registros de mantenimiento del vehículo
        const maintenanceSnapshot = await vehicleDoc.ref
          .collection('maintenanceRecords')
          .orderBy('date', 'desc')
          .limit(5)
          .get();

        // Verificar mantenimientos programados
        const currentMileage = vehicleData.mileage || 0;

        // Cambio de aceite cada 5000 km
        const lastOilChange = maintenanceSnapshot.docs.find(doc =>
          doc.data().type === 'Cambio de Aceite'
        );

        if (lastOilChange) {
          const lastOilChangeMileage = lastOilChange.data().mileage || 0;
          const kmSinceOilChange = currentMileage - lastOilChangeMileage;

          if (kmSinceOilChange >= 4500) {
            const kmRemaining = 5000 - kmSinceOilChange;
            const isUrgent = kmRemaining <= 200;

            const notification = {
              token: fcmToken,
              notification: {
                title: isUrgent ? '🚨 Cambio de Aceite URGENTE' : '🔧 Recordatorio de Mantenimiento',
                body: isUrgent
                  ? `¡Solo te quedan ${kmRemaining} km para el cambio de aceite!`
                  : `Te quedan ${kmRemaining} km para el próximo cambio de aceite`
              },
              data: {
                type: 'maintenance_reminder',
                maintenanceType: 'Cambio de Aceite',
                vehicleId: vehicleDoc.id,
                currentMileage: currentMileage.toString(),
                kmRemaining: kmRemaining.toString(),
                screen: 'vehicle_management'
              },
              android: {
                priority: isUrgent ? 'high' : 'normal',
                notification: {
                  channelId: 'maintenance_reminders',
                  priority: isUrgent ? 'max' : 'default'
                }
              }
            };

            notifications.push(notification);

            // Guardar registro de notificación
            await db.collection('notifications').add({
              userId: driverId,
              type: 'maintenance_reminder',
              title: notification.notification.title,
              body: notification.notification.body,
              maintenanceType: 'Cambio de Aceite',
              vehicleId: vehicleDoc.id,
              currentMileage: currentMileage,
              kmRemaining: kmRemaining,
              priority: isUrgent ? 'high' : 'normal',
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              read: false
            });
          }
        }

        // Verificar otros mantenimientos periódicos
        // Revisión técnica anual
        const lastInspection = maintenanceSnapshot.docs.find(doc =>
          doc.data().type === 'Revisión Técnica'
        );

        if (lastInspection) {
          const lastInspectionDate = lastInspection.data().date?.toDate();
          if (lastInspectionDate) {
            const monthsSinceInspection = Math.floor((now - lastInspectionDate) / (1000 * 60 * 60 * 24 * 30));

            if (monthsSinceInspection >= 11) {
              const notification = {
                token: fcmToken,
                notification: {
                  title: '📋 Revisión Técnica Próxima',
                  body: 'Tu revisión técnica anual está próxima a vencer'
                },
                data: {
                  type: 'maintenance_reminder',
                  maintenanceType: 'Revisión Técnica',
                  vehicleId: vehicleDoc.id,
                  lastDate: lastInspectionDate.toISOString(),
                  screen: 'vehicle_management'
                }
              };

              notifications.push(notification);
            }
          }
        }

        // Verificar recordatorios personalizados
        const remindersSnapshot = await vehicleDoc.ref
          .collection('reminders')
          .where('completed', '==', false)
          .where('date', '<=', admin.firestore.Timestamp.fromDate(now))
          .get();

        for (const reminderDoc of remindersSnapshot.docs) {
          const reminderData = reminderDoc.data();

          const notification = {
            token: fcmToken,
            notification: {
              title: '🔔 ' + reminderData.title,
              body: reminderData.description
            },
            data: {
              type: 'custom_reminder',
              reminderId: reminderDoc.id,
              vehicleId: vehicleDoc.id,
              reminderType: reminderData.type || 'other',
              screen: 'vehicle_management'
            }
          };

          notifications.push(notification);

          // Marcar recordatorio como enviado
          await reminderDoc.ref.update({
            notificationSent: true,
            notificationSentAt: admin.firestore.FieldValue.serverTimestamp()
          });
        }
      }

      // Enviar todas las notificaciones en batch
      if (notifications.length > 0) {
        const results = await admin.messaging().sendEach(notifications);
        console.log(`Enviadas ${results.successCount} notificaciones de mantenimiento, ${results.failureCount} fallidas`);
      }

      console.log('Verificación de mantenimientos completada');
      return null;
    } catch (error) {
      console.error('Error verificando mantenimientos:', error);
      throw error;
    }
  });

/**
 * Cloud Function para actualizar kilometraje del vehículo después de cada viaje
 */
exports.updateVehicleMileage = functions.firestore
  .document('trips/{tripId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Solo actualizar si el viaje pasó a estado completado
    if (before.status !== 'completed' && after.status === 'completed') {
      const driverId = after.driverId;
      const distance = after.distance || 0; // Distancia en km

      if (driverId && distance > 0) {
        try {
          // Obtener el vehículo del conductor
          const vehicleSnapshot = await db.collection('vehicles')
            .where('driverId', '==', driverId)
            .where('isActive', '==', true)
            .limit(1)
            .get();

          if (!vehicleSnapshot.empty) {
            const vehicleDoc = vehicleSnapshot.docs[0];
            const currentMileage = vehicleDoc.data().mileage || 0;
            const newMileage = currentMileage + Math.round(distance);

            // Actualizar kilometraje
            await vehicleDoc.ref.update({
              mileage: newMileage,
              lastMileageUpdate: admin.firestore.FieldValue.serverTimestamp()
            });

            console.log(`Kilometraje actualizado para vehículo ${vehicleDoc.id}: ${currentMileage} -> ${newMileage}`);
          }
        } catch (error) {
          console.error('Error actualizando kilometraje del vehículo:', error);
        }
      }
    }
  });

console.log('Firebase Cloud Functions cargadas exitosamente para OasisTaxi Perú');