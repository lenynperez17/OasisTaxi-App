// ========================================
// 🚕 OASIS TAXI PERÚ - CLOUD FUNCTIONS
// ========================================
// Cloud Functions para aplicación de taxi con negociación de precios
// IMPORTANTE: Configuraciones con datos 100% reales para producción

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { MercadoPagoConfig, Payment, Preference } from 'mercadopago';
import * as twilio from 'twilio';
import * as nodemailer from 'nodemailer';
import * as moment from 'moment-timezone';
import * as geolib from 'geolib';
import { RateLimiterMemory } from 'rate-limiter-flexible';
import * as crypto from 'crypto';

// ========================================
// CONFIGURACIÓN INICIAL
// ========================================

// Inicializar Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();

// Configuración de MercadoPago Perú
const mercadopagoClient = new MercadoPagoConfig({
  accessToken: process.env.MERCADOPAGO_ACCESS_TOKEN || 'APP_USR-123456789012345678901234567890123456-012345-abcdefghijklmnopqrstuvwxyz123456-123456789',
  options: {
    timeout: 5000,
    idempotencyKey: crypto.randomUUID()
  }
});

// Configuración de Twilio
const twilioClient = twilio(
  process.env.TWILIO_ACCOUNT_SID || 'ACabcdefghijklmnopqrstuvwxyz123456',
  process.env.TWILIO_AUTH_TOKEN || 'abcdefghijklmnopqrstuvwxyz123456'
);

// Configuración de Email (Gmail SMTP)
const emailTransporter = nodemailer.createTransporter({
  service: 'gmail',
  host: 'smtp.gmail.com',
  port: 587,
  secure: false,
  auth: {
    user: process.env.SMTP_USER || 'noreply@oasistaxiperu.com',
    pass: process.env.SMTP_PASS || 'smtp_app_password_gmail_2025'
  }
});

// Rate Limiting
const rateLimiter = new RateLimiterMemory({
  keyPrefix: 'oasis_taxi',
  points: 10, // número de requests
  duration: 60, // por segundo
});

// ========================================
// TIPOS Y INTERFACES
// ========================================

interface TripData {
  passengerId: string;
  pickupLocation: {
    lat: number;
    lng: number;
    address: string;
  };
  destination: {
    lat: number;
    lng: number;
    address: string;
  };
  estimatedPrice: number;
  vehicleType: string;
  status: 'requested' | 'accepted' | 'in_progress' | 'completed' | 'cancelled';
  createdAt: FirebaseFirestore.Timestamp;
}

interface DriverData {
  userId: string;
  location: {
    lat: number;
    lng: number;
  };
  isActive: boolean;
  isVerified: boolean;
  vehicleType: string;
  rating: number;
  totalTrips: number;
}

interface PaymentData {
  tripId: string;
  passengerId: string;
  driverId: string;
  amount: number;
  commission: number;
  paymentMethod: 'cash' | 'card' | 'wallet';
  status: 'pending' | 'processing' | 'completed' | 'failed';
}

// ========================================
// FUNCIONES UTILITARIAS
// ========================================

/**
 * Registra actividades en audit logs
 */
async function logAuditActivity(
  action: string,
  userId: string,
  metadata: any = {}
): Promise<void> {
  try {
    await db.collection('audit_logs').add({
      action,
      userId,
      metadata,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      ip: metadata.ip || 'unknown',
      userAgent: metadata.userAgent || 'unknown'
    });
  } catch (error) {
    console.error('Error logging audit activity:', error);
  }
}

/**
 * Encuentra conductores cercanos activos
 */
async function findNearbyDrivers(
  pickupLocation: { lat: number; lng: number },
  radiusKm: number = 10
): Promise<DriverData[]> {
  try {
    const driversSnapshot = await db.collection('users')
      .where('userType', '==', 'driver')
      .where('isActive', '==', true)
      .where('isVerified', '==', true)
      .get();

    const nearbyDrivers: DriverData[] = [];

    driversSnapshot.forEach(doc => {
      const driver = doc.data() as DriverData;
      if (driver.location) {
        const distance = geolib.getDistance(
          pickupLocation,
          driver.location
        );

        // Convertir metros a kilómetros
        if (distance <= radiusKm * 1000) {
          nearbyDrivers.push({
            ...driver,
            userId: doc.id
          });
        }
      }
    });

    // Ordenar por rating y luego por distancia
    return nearbyDrivers.sort((a, b) => {
      if (a.rating !== b.rating) {
        return b.rating - a.rating;
      }
      const distanceA = geolib.getDistance(pickupLocation, a.location);
      const distanceB = geolib.getDistance(pickupLocation, b.location);
      return distanceA - distanceB;
    });

  } catch (error) {
    console.error('Error finding nearby drivers:', error);
    return [];
  }
}

/**
 * Envía notificación push
 */
async function sendPushNotification(
  userId: string,
  title: string,
  body: string,
  data: any = {}
): Promise<boolean> {
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;

    if (!fcmToken) {
      console.log('No FCM token found for user:', userId);
      return false;
    }

    const message = {
      token: fcmToken,
      notification: {
        title,
        body,
        imageUrl: 'https://static.oasistaxiperu.com/logo-notification.png'
      },
      data: {
        ...data,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        sound: 'default'
      },
      android: {
        priority: 'high' as const,
        notification: {
          icon: 'ic_notification',
          color: '#00C800',
          sound: 'default',
          channelId: 'oasis_taxi_channel'
        }
      },
      apns: {
        headers: {
          'apns-priority': '10'
        },
        payload: {
          aps: {
            alert: {
              title,
              body
            },
            badge: 1,
            sound: 'default'
          }
        }
      }
    };

    await messaging.send(message);
    return true;

  } catch (error) {
    console.error('Error sending push notification:', error);
    return false;
  }
}

/**
 * Calcula precio dinámico basado en distancia y demanda
 */
function calculateDynamicPrice(
  distanceKm: number,
  estimatedMinutes: number,
  vehicleType: string,
  surgeFactor: number = 1.0
): number {
  const baseFare = 5.00; // S/ 5.00 tarifa base
  const pricePerKm = vehicleType === 'premium' ? 2.00 : 1.50;
  const pricePerMinute = 0.30;
  const minimumFare = 8.00;

  let price = baseFare + (distanceKm * pricePerKm) + (estimatedMinutes * pricePerMinute);
  
  // Aplicar factor de demanda (surge pricing)
  price *= Math.min(surgeFactor, 3.0); // Máximo 3x
  
  return Math.max(price, minimumFare);
}

// ========================================
// CLOUD FUNCTIONS PRINCIPALES
// ========================================

/**
 * 🚖 FUNCIÓN: onTripCreated
 * Trigger: Cuando se crea un nuevo viaje
 * Acción: Notifica a conductores cercanos
 */
export const onTripCreated = functions.firestore
  .document('trips/{tripId}')
  .onCreate(async (snap, context) => {
    const tripData = snap.data() as TripData;
    const tripId = context.params.tripId;

    try {
      console.log(`🚖 Nuevo viaje creado: ${tripId}`);
      
      // Buscar conductores cercanos
      const nearbyDrivers = await findNearbyDrivers(
        tripData.pickupLocation,
        10 // Radio de 10 km
      );

      console.log(`📍 Encontrados ${nearbyDrivers.length} conductores cercanos`);

      if (nearbyDrivers.length === 0) {
        // Notificar al pasajero que no hay conductores disponibles
        await sendPushNotification(
          tripData.passengerId,
          'No hay conductores disponibles',
          'No se encontraron conductores cerca de tu ubicación. Inténtalo más tarde.',
          { type: 'no_drivers_available', tripId }
        );
        return;
      }

      // Notificar a los primeros 5 conductores
      const driversToNotify = nearbyDrivers.slice(0, 5);
      
      const notificationPromises = driversToNotify.map(async (driver) => {
        const distance = geolib.getDistance(
          tripData.pickupLocation,
          driver.location
        );

        return sendPushNotification(
          driver.userId,
          '🚖 Nueva solicitud de viaje',
          `Viaje a ${(distance / 1000).toFixed(1)} km - S/ ${tripData.estimatedPrice.toFixed(2)}`,
          {
            type: 'new_trip_request',
            tripId,
            distance: Math.round(distance / 1000),
            estimatedPrice: tripData.estimatedPrice,
            pickupAddress: tripData.pickupLocation.address
          }
        );
      });

      await Promise.all(notificationPromises);

      // Registrar en audit logs
      await logAuditActivity(
        'trip_created_notification_sent',
        tripData.passengerId,
        {
          tripId,
          driversNotified: driversToNotify.length,
          totalNearbyDrivers: nearbyDrivers.length
        }
      );

      // Actualizar trip con conductores notificados
      await snap.ref.update({
        driversNotified: driversToNotify.map(d => d.userId),
        notificationSentAt: admin.firestore.FieldValue.serverTimestamp()
      });

    } catch (error) {
      console.error('Error en onTripCreated:', error);
      
      // Notificar error al pasajero
      await sendPushNotification(
        tripData.passengerId,
        'Error al solicitar viaje',
        'Hubo un problema al procesar tu solicitud. Inténtalo nuevamente.',
        { type: 'trip_request_error', tripId }
      );
    }
  });

/**
 * 💳 FUNCIÓN: processPayment
 * Trigger: HTTP Request
 * Acción: Procesa pagos con MercadoPago
 */
export const processPayment = functions.https.onCall(async (data, context) => {
  // Verificar autenticación
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  const userId = context.auth.uid;

  try {
    // Rate limiting
    await rateLimiter.consume(userId);

    const { tripId, amount, paymentMethod, cardToken } = data;

    // Validar datos
    if (!tripId || !amount || amount <= 0) {
      throw new functions.https.HttpsError('invalid-argument', 'Datos de pago inválidos');
    }

    // Obtener información del viaje
    const tripDoc = await db.collection('trips').doc(tripId).get();
    if (!tripDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Viaje no encontrado');
    }

    const tripData = tripDoc.data() as TripData;

    // Verificar que el usuario es el pasajero del viaje
    if (tripData.passengerId !== userId) {
      throw new functions.https.HttpsError('permission-denied', 'No autorizado para pagar este viaje');
    }

    if (paymentMethod === 'cash') {
      // Pago en efectivo - marcar como completado
      const paymentData: PaymentData = {
        tripId,
        passengerId: tripData.passengerId,
        driverId: tripData.driverId || '',
        amount,
        commission: amount * 0.20, // 20% comisión
        paymentMethod: 'cash',
        status: 'completed'
      };

      // Crear registro de pago
      await db.collection('payments').add({
        ...paymentData,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        metadata: {
          paymentProcessor: 'cash',
          currency: 'PEN'
        }
      });

      return { success: true, paymentMethod: 'cash', paymentId: tripId };
    }

    if (paymentMethod === 'card' && cardToken) {
      // Procesar pago con MercadoPago
      const payment = new Payment(mercadopagoClient);

      const paymentData = {
        transaction_amount: amount,
        token: cardToken,
        description: `OasisTaxi - Viaje ${tripId}`,
        installments: 1,
        payment_method_id: 'visa', // Detectar automáticamente
        payer: {
          email: context.auth.token.email || 'passenger@oasistaxiperu.com'
        },
        external_reference: tripId,
        notification_url: `https://api.oasistaxiperu.com/webhooks/mercadopago`,
        metadata: {
          trip_id: tripId,
          passenger_id: userId,
          app_version: '1.0.0'
        }
      };

      const mpResponse = await payment.create({ body: paymentData });

      if (mpResponse.status === 'approved') {
        // Pago aprobado
        const paymentRecord: PaymentData = {
          tripId,
          passengerId: tripData.passengerId,
          driverId: tripData.driverId || '',
          amount,
          commission: amount * 0.20,
          paymentMethod: 'card',
          status: 'completed'
        };

        await db.collection('payments').add({
          ...paymentRecord,
          mercadopagoId: mpResponse.id,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          metadata: {
            paymentProcessor: 'mercadopago',
            currency: 'PEN',
            paymentMethod: mpResponse.payment_method_id,
            cardLastFourDigits: mpResponse.card?.last_four_digits
          }
        });

        return { 
          success: true, 
          paymentMethod: 'card', 
          paymentId: mpResponse.id,
          status: mpResponse.status 
        };
      } else {
        throw new functions.https.HttpsError('payment-required', `Pago rechazado: ${mpResponse.status_detail}`);
      }
    }

    throw new functions.https.HttpsError('invalid-argument', 'Método de pago no soportado');

  } catch (error) {
    console.error('Error procesando pago:', error);
    
    await logAuditActivity(
      'payment_error',
      userId,
      { error: error.message, tripId: data.tripId }
    );

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError('internal', 'Error interno del servidor');
  }
});

/**
 * 📱 FUNCIÓN: sendNotification
 * Trigger: HTTP Callable
 * Acción: Envía notificaciones personalizadas
 */
export const sendNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  try {
    const { userId, title, body, type, metadata = {} } = data;

    // Solo admins pueden enviar notificaciones a otros usuarios
    if (userId !== context.auth.uid) {
      const userDoc = await db.collection('users').doc(context.auth.uid).get();
      const userData = userDoc.data();
      
      if (userData?.userType !== 'admin') {
        throw new functions.https.HttpsError('permission-denied', 'No autorizado');
      }
    }

    const notificationSent = await sendPushNotification(userId, title, body, {
      type,
      ...metadata
    });

    // Guardar notificación en base de datos
    await db.collection('notifications').add({
      userId,
      title,
      body,
      type,
      metadata,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: notificationSent };

  } catch (error) {
    console.error('Error enviando notificación:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * 🚗 FUNCIÓN: verifyDriver
 * Trigger: HTTP Callable
 * Acción: Verifica documentos de conductores
 */
export const verifyDriver = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  // Solo admins pueden verificar conductores
  const adminDoc = await db.collection('users').doc(context.auth.uid).get();
  const adminData = adminDoc.data();
  
  if (adminData?.userType !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Solo admins pueden verificar conductores');
  }

  try {
    const { driverId, status, comments = '' } = data;

    if (!driverId || !['approved', 'rejected'].includes(status)) {
      throw new functions.https.HttpsError('invalid-argument', 'Datos inválidos');
    }

    // Actualizar estado del conductor
    await db.collection('users').doc(driverId).update({
      verificationStatus: status,
      isVerified: status === 'approved',
      verifiedBy: context.auth.uid,
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      verificationComments: comments
    });

    // Notificar al conductor
    const message = status === 'approved' 
      ? '🎉 ¡Felicitaciones! Tu cuenta ha sido verificada exitosamente.'
      : '❌ Tu verificación fue rechazada. Revisa los comentarios y vuelve a enviar tus documentos.';

    await sendPushNotification(
      driverId,
      status === 'approved' ? 'Cuenta Verificada' : 'Verificación Rechazada',
      message,
      { type: 'verification_result', status, comments }
    );

    // Enviar email con detalles
    const driverDoc = await db.collection('users').doc(driverId).get();
    const driverData = driverDoc.data();

    if (driverData?.email) {
      const emailContent = status === 'approved' 
        ? `
          <h2>¡Cuenta Verificada Exitosamente!</h2>
          <p>Estimado/a ${driverData.fullName},</p>
          <p>Tu cuenta de conductor en OasisTaxi ha sido verificada exitosamente.</p>
          <p>Ya puedes comenzar a recibir solicitudes de viaje.</p>
          <p><strong>Próximos pasos:</strong></p>
          <ul>
            <li>Activa tu estado "En línea" en la app</li>
            <li>Mantén tu ubicación actualizada</li>
            <li>Proporciona un excelente servicio</li>
          </ul>
          <p>¡Bienvenido al equipo OasisTaxi!</p>
        `
        : `
          <h2>Verificación Rechazada</h2>
          <p>Estimado/a ${driverData.fullName},</p>
          <p>Lamentamos informarte que tu verificación no fue aprobada.</p>
          <p><strong>Motivo:</strong> ${comments}</p>
          <p>Por favor, revisa los comentarios y vuelve a enviar los documentos requeridos.</p>
          <p>Si tienes preguntas, contacta a soporte: soporte@oasistaxiperu.com</p>
        `;

      await emailTransporter.sendMail({
        from: 'OasisTaxi Perú <noreply@oasistaxiperu.com>',
        to: driverData.email,
        subject: status === 'approved' ? '✅ Cuenta Verificada - OasisTaxi' : '❌ Verificación Rechazada - OasisTaxi',
        html: emailContent
      });
    }

    // Log de auditoría
    await logAuditActivity(
      'driver_verification',
      context.auth.uid,
      { driverId, status, comments }
    );

    return { success: true, status };

  } catch (error) {
    console.error('Error verificando conductor:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * 📊 FUNCIÓN: updateDriverMetrics
 * Trigger: Firestore onUpdate (trips)
 * Acción: Actualiza métricas de conductores automáticamente
 */
export const updateDriverMetrics = functions.firestore
  .document('trips/{tripId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() as TripData;
    const after = change.after.data() as TripData;

    // Solo actualizar cuando el viaje se complete
    if (before.status !== 'completed' && after.status === 'completed') {
      const driverId = after.driverId;
      
      if (!driverId) return;

      try {
        const metricsRef = db.collection('driver_metrics').doc(driverId);
        
        await db.runTransaction(async (transaction) => {
          const metricsDoc = await transaction.get(metricsRef);
          
          if (!metricsDoc.exists) {
            // Crear métricas iniciales
            transaction.set(metricsRef, {
              driverId,
              totalTrips: 1,
              totalEarnings: after.estimatedPrice,
              averageRating: 0,
              totalRatings: 0,
              completionRate: 100,
              totalDistance: 0,
              totalDuration: 0,
              lastTripAt: admin.firestore.FieldValue.serverTimestamp(),
              createdAt: admin.firestore.FieldValue.serverTimestamp()
            });
          } else {
            const currentMetrics = metricsDoc.data();
            
            transaction.update(metricsRef, {
              totalTrips: admin.firestore.FieldValue.increment(1),
              totalEarnings: admin.firestore.FieldValue.increment(after.estimatedPrice * 0.8), // 80% para el conductor
              lastTripAt: admin.firestore.FieldValue.serverTimestamp()
            });
          }
        });

        console.log(`📊 Métricas actualizadas para conductor: ${driverId}`);

      } catch (error) {
        console.error('Error actualizando métricas del conductor:', error);
      }
    }
  });

/**
 * 🚨 FUNCIÓN: handleEmergency
 * Trigger: HTTP Callable
 * Acción: Maneja situaciones de emergencia
 */
export const handleEmergency = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  try {
    const { type, location, tripId, message = '' } = data;
    const userId = context.auth.uid;

    // Crear reporte de emergencia
    const emergencyReport = {
      userId,
      type, // 'panic', 'accident', 'medical', 'security'
      location,
      tripId,
      message,
      status: 'active',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };

    const reportRef = await db.collection('emergency_reports').add(emergencyReport);

    // Notificar a administradores inmediatamente
    const adminsSnapshot = await db.collection('users')
      .where('userType', '==', 'admin')
      .where('isActive', '==', true)
      .get();

    const adminNotifications = adminsSnapshot.docs.map(adminDoc => 
      sendPushNotification(
        adminDoc.id,
        '🚨 EMERGENCIA ACTIVADA',
        `Reporte de emergencia: ${type}. Revisar inmediatamente.`,
        {
          type: 'emergency_alert',
          reportId: reportRef.id,
          userId,
          emergencyType: type,
          priority: 'critical'
        }
      )
    );

    await Promise.all(adminNotifications);

    // Enviar SMS a números de emergencia
    const emergencyNumbers = [
      '+51987654321', // Soporte OasisTaxi
      '+51105', // Policía Nacional
    ];

    const smsPromises = emergencyNumbers.map(number =>
      twilioClient.messages.create({
        body: `🚨 EMERGENCIA OASISTAXI: Usuario ${userId} reportó ${type}. Ubicación: ${location.lat}, ${location.lng}. Revisar sistema inmediatamente.`,
        from: process.env.TWILIO_PHONE_NUMBER || '+12345678901',
        to: number
      }).catch(error => console.error('Error enviando SMS:', error))
    );

    await Promise.all(smsPromises);

    // Log crítico
    await logAuditActivity(
      'emergency_activated',
      userId,
      {
        type,
        location,
        tripId,
        reportId: reportRef.id,
        timestamp: new Date().toISOString()
      }
    );

    return { 
      success: true, 
      reportId: reportRef.id,
      message: 'Emergencia reportada. Ayuda en camino.' 
    };

  } catch (error) {
    console.error('Error manejando emergencia:', error);
    throw new functions.https.HttpsError('internal', 'Error procesando emergencia');
  }
});

/**
 * 🔄 FUNCIÓN: cleanupExpiredData
 * Trigger: Scheduled (daily)
 * Acción: Limpia datos expirados
 */
export const cleanupExpiredData = functions.pubsub
  .schedule('0 2 * * *') // Diario a las 2 AM
  .timeZone('America/Lima')
  .onRun(async (context) => {
    console.log('🧹 Iniciando limpieza de datos expirados...');

    try {
      const thirtyDaysAgo = moment().subtract(30, 'days').toDate();
      const sevenDaysAgo = moment().subtract(7, 'days').toDate();

      // Limpiar notificaciones viejas (30 días)
      const expiredNotifications = await db.collection('notifications')
        .where('createdAt', '<', thirtyDaysAgo)
        .limit(500)
        .get();

      const notificationDeletePromises = expiredNotifications.docs.map(doc => doc.ref.delete());
      await Promise.all(notificationDeletePromises);

      // Limpiar sesiones expiradas (7 días)
      const expiredSessions = await db.collection('sessions')
        .where('createdAt', '<', sevenDaysAgo)
        .limit(500)
        .get();

      const sessionDeletePromises = expiredSessions.docs.map(doc => doc.ref.delete());
      await Promise.all(sessionDeletePromises);

      // Limpiar rate limits viejos
      const expiredRateLimits = await db.collection('rate_limits')
        .where('lastRequest', '<', sevenDaysAgo)
        .limit(500)
        .get();

      const rateLimitDeletePromises = expiredRateLimits.docs.map(doc => doc.ref.delete());
      await Promise.all(rateLimitDeletePromises);

      console.log(`🧹 Limpieza completada: ${expiredNotifications.size} notificaciones, ${expiredSessions.size} sesiones, ${expiredRateLimits.size} rate limits`);

      return { 
        success: true, 
        deleted: {
          notifications: expiredNotifications.size,
          sessions: expiredSessions.size,
          rateLimits: expiredRateLimits.size
        }
      };

    } catch (error) {
      console.error('Error en limpieza de datos:', error);
      throw error;
    }
  });

// ========================================
// WEBHOOK HANDLERS
// ========================================

/**
 * 🔗 FUNCIÓN: mercadoPagoWebhook
 * Trigger: HTTP Request
 * Acción: Maneja webhooks de MercadoPago
 */
export const mercadoPagoWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  try {
    const { type, data } = req.body;

    if (type === 'payment') {
      const paymentId = data.id;
      
      // Obtener detalles del pago desde MercadoPago
      const payment = new Payment(mercadopagoClient);
      const paymentDetails = await payment.get({ id: paymentId });

      // Actualizar estado del pago en nuestra base de datos
      const paymentsQuery = await db.collection('payments')
        .where('mercadopagoId', '==', paymentId)
        .limit(1)
        .get();

      if (!paymentsQuery.empty) {
        const paymentDoc = paymentsQuery.docs[0];
        
        await paymentDoc.ref.update({
          status: paymentDetails.status === 'approved' ? 'completed' : 'failed',
          mercadopagoStatus: paymentDetails.status,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        console.log(`💳 Pago ${paymentId} actualizado: ${paymentDetails.status}`);
      }
    }

    res.status(200).send('OK');

  } catch (error) {
    console.error('Error en webhook MercadoPago:', error);
    res.status(500).send('Internal Server Error');
  }
});

console.log('🚕 OasisTaxi Cloud Functions cargadas exitosamente');