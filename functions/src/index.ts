import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { v4 as uuidv4 } from 'uuid';
import { NotificationService } from './services/NotificationService';
import { TripNotificationHandler } from './handlers/TripNotificationHandler';
import { PaymentNotificationHandler } from './handlers/PaymentNotificationHandler';
import { EmergencyNotificationHandler } from './handlers/EmergencyNotificationHandler';

// Inicializar Firebase Admin SDK
admin.initializeApp();

const db = admin.firestore();
const notificationService = new NotificationService();

// Configurar región
const runtimeOpts: functions.RuntimeOptions = {
  timeoutSeconds: 60,
  memory: '512MB',
};

/**
 * 🚗 TRIGGER: Nuevo viaje creado
 * Auto-envía notificaciones a conductores disponibles
 */
export const onTripCreated = functions
  .region('us-central1')
  .runWith(runtimeOpts)
  .firestore
  .document('trips/{tripId}')
  .onCreate(async (snapshot, context) => {
    const tripId = context.params.tripId;
    const tripData = snapshot.data();

    console.log(`🚗 Nuevo viaje creado: ${tripId}`);

    try {
      const handler = new TripNotificationHandler(notificationService, db);
      await handler.handleNewTrip(tripId, tripData);
      
      console.log(`✅ Notificaciones de nuevo viaje enviadas: ${tripId}`);
    } catch (error) {
      console.error(`❌ Error procesando nuevo viaje ${tripId}:`, error);
      
      // Log del error en Firestore para debugging
      await db.collection('error_logs').add({
        type: 'trip_created_notification_failed',
        tripId,
        error: error instanceof Error ? error.message : String(error),
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

/**
 * 🚗 TRIGGER: Estado del viaje actualizado
 * Auto-envía notificaciones según el nuevo estado
 */
export const onTripStatusUpdate = functions
  .region('us-central1')
  .runWith(runtimeOpts)
  .firestore
  .document('trips/{tripId}')
  .onUpdate(async (change, context) => {
    const tripId = context.params.tripId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Solo procesar si el status cambió
    if (beforeData.status === afterData.status) {
      return;
    }

    console.log(`🔄 Estado del viaje ${tripId} cambió: ${beforeData.status} → ${afterData.status}`);

    try {
      const handler = new TripNotificationHandler(notificationService, db);
      await handler.handleTripStatusChange(tripId, beforeData.status, afterData.status, afterData);
      
      console.log(`✅ Notificaciones de cambio de estado enviadas: ${tripId}`);
    } catch (error) {
      console.error(`❌ Error procesando cambio de estado ${tripId}:`, error);
      
      await db.collection('error_logs').add({
        type: 'trip_status_notification_failed',
        tripId,
        oldStatus: beforeData.status,
        newStatus: afterData.status,
        error: error instanceof Error ? error.message : String(error),
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

/**
 * 💰 TRIGGER: Pago procesado
 * Auto-envía notificaciones de confirmación de pago
 */
export const onPaymentProcessed = functions
  .region('us-central1')
  .runWith(runtimeOpts)
  .firestore
  .document('payments/{paymentId}')
  .onCreate(async (snapshot, context) => {
    const paymentId = context.params.paymentId;
    const paymentData = snapshot.data();

    console.log(`💰 Nuevo pago procesado: ${paymentId}`);

    try {
      const handler = new PaymentNotificationHandler(notificationService, db);
      await handler.handlePaymentProcessed(paymentId, paymentData);
      
      console.log(`✅ Notificaciones de pago enviadas: ${paymentId}`);
    } catch (error) {
      console.error(`❌ Error procesando pago ${paymentId}:`, error);
      
      await db.collection('error_logs').add({
        type: 'payment_notification_failed',
        paymentId,
        error: error instanceof Error ? error.message : String(error),
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

/**
 * 🚨 TRIGGER: Botón SOS activado
 * Auto-envía alertas de emergencia inmediatas
 */
export const onEmergencyActivated = functions
  .region('us-central1')
  .runWith(runtimeOpts)
  .firestore
  .document('emergencies/{emergencyId}')
  .onCreate(async (snapshot, context) => {
    const emergencyId = context.params.emergencyId;
    const emergencyData = snapshot.data();

    console.log(`🚨 EMERGENCIA ACTIVADA: ${emergencyId}`);

    try {
      const handler = new EmergencyNotificationHandler(notificationService, db);
      await handler.handleEmergency(emergencyId, emergencyData);
      
      console.log(`✅ Alertas de emergencia enviadas: ${emergencyId}`);
    } catch (error) {
      console.error(`❌ ERROR CRÍTICO procesando emergencia ${emergencyId}:`, error);
      
      // Para emergencias, también enviamos log crítico
      await db.collection('critical_errors').add({
        type: 'emergency_notification_failed',
        emergencyId,
        error: error instanceof Error ? error.message : String(error),
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        severity: 'CRITICAL',
      });
    }
  });

/**
 * 📤 HTTP ENDPOINT: Envío manual de notificaciones
 * Para testing y envío directo desde la app
 */
export const sendNotification = functions
  .region('us-central1')
  .runWith(runtimeOpts)
  .https
  .onRequest(async (req, res) => {
    // Verificar método HTTP
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Método no permitido. Usar POST.' });
      return;
    }

    // CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (req.method === 'OPTIONS') {
      res.status(200).end();
      return;
    }

    try {
      const { tokens, topic, notification, data } = req.body;

      if (!notification || !notification.title || !notification.body) {
        res.status(400).json({ 
          error: 'Notification requerida con title y body' 
        });
        return;
      }

      console.log(`📤 Enviando notificación manual: ${notification.title}`);

      let result;
      
      if (tokens && Array.isArray(tokens)) {
        // Envío a tokens específicos
        result = await notificationService.sendToTokens(tokens, notification, data);
      } else if (topic) {
        // Envío a topic
        result = await notificationService.sendToTopic(topic, notification, data);
      } else {
        res.status(400).json({ 
          error: 'Debe especificar tokens o topic' 
        });
        return;
      }

      // Registrar envío exitoso
      await db.collection('notification_logs').add({
        type: 'manual_send',
        notification,
        result,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        source: 'http_endpoint',
      });

      res.status(200).json({
        success: true,
        result,
        message: 'Notificación enviada exitosamente',
      });

    } catch (error) {
      console.error('❌ Error en sendNotification endpoint:', error);
      
      res.status(500).json({
        success: false,
        error: error instanceof Error ? error.message : 'Error interno',
      });
    }
  });

/**
 * 🧹 SCHEDULED: Limpieza de tokens inválidos
 * Ejecuta diariamente a las 2:00 AM
 */
export const cleanupInvalidTokens = functions
  .region('us-central1')
  .runWith(runtimeOpts)
  .pubsub
  .schedule('0 2 * * *') // Cron: 2:00 AM todos los días
  .timeZone('America/Lima') // Hora de Perú
  .onRun(async (context) => {
    console.log('🧹 Iniciando limpieza de tokens inválidos...');

    try {
      const usersRef = db.collection('users');
      const snapshot = await usersRef
        .where('fcmToken', '!=', null)
        .get();

      const batch = db.batch();
      let cleanedCount = 0;

      snapshot.forEach((doc) => {
        const userData = doc.data();
        const token = userData.fcmToken;

        // Validar formato del token
        if (!token || 
            typeof token !== 'string' || 
            token.length < 100 || 
            (!token.includes(':') && !token.includes('-'))) {
          batch.update(doc.ref, { fcmToken: admin.firestore.FieldValue.delete() });
          cleanedCount++;
        }
      });

      if (cleanedCount > 0) {
        await batch.commit();
        console.log(`🧹 Limpiados ${cleanedCount} tokens inválidos`);
      } else {
        console.log('🧹 No se encontraron tokens inválidos para limpiar');
      }

      // Registrar métricas
      await db.collection('cleanup_logs').add({
        type: 'token_cleanup',
        totalProcessed: snapshot.size,
        tokensRemoved: cleanedCount,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

    } catch (error) {
      console.error('❌ Error en limpieza de tokens:', error);
    }
  });

/**
 * 📊 SCHEDULED: Métricas de notificaciones
 * Ejecuta cada hora para generar estadísticas
 */
export const generateNotificationMetrics = functions
  .region('us-central1')
  .runWith(runtimeOpts)
  .pubsub
  .schedule('0 * * * *') // Cada hora
  .timeZone('America/Lima')
  .onRun(async (context) => {
    console.log('📊 Generando métricas de notificaciones...');

    try {
      const now = new Date();
      const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);

      // Obtener logs de la última hora
      const logsRef = db.collection('notification_logs');
      const snapshot = await logsRef
        .where('timestamp', '>=', oneHourAgo)
        .get();

      const metrics = {
        totalSent: 0,
        byType: {} as Record<string, number>,
        byChannel: {} as Record<string, number>,
        successRate: 0,
        failureCount: 0,
      };

      snapshot.forEach((doc) => {
        const logData = doc.data();
        metrics.totalSent++;
        
        if (logData.type) {
          metrics.byType[logData.type] = (metrics.byType[logData.type] || 0) + 1;
        }
        
        if (logData.channel) {
          metrics.byChannel[logData.channel] = (metrics.byChannel[logData.channel] || 0) + 1;
        }
        
        if (logData.success === false) {
          metrics.failureCount++;
        }
      });

      metrics.successRate = metrics.totalSent > 0 
        ? ((metrics.totalSent - metrics.failureCount) / metrics.totalSent) * 100 
        : 100;

      // Guardar métricas
      await db.collection('notification_metrics').add({
        ...metrics,
        periodStart: oneHourAgo,
        periodEnd: now,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`📊 Métricas generadas: ${metrics.totalSent} notificaciones, ${metrics.successRate.toFixed(2)}% éxito`);

    } catch (error) {
      console.error('❌ Error generando métricas:', error);
    }
  });

/**
 * ⚙️ HTTP ENDPOINT: Health check del sistema
 */
export const healthCheck = functions
  .region('us-central1')
  .https
  .onRequest(async (req, res) => {
    res.set('Access-Control-Allow-Origin', '*');
    
    try {
      const health = {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        services: {
          firestore: false,
          fcm: false,
        },
      };

      // Test Firestore
      try {
        await db.collection('health_check').limit(1).get();
        health.services.firestore = true;
      } catch (error) {
        console.error('Firestore health check failed:', error);
      }

      // Test FCM
      try {
        const testResult = await notificationService.testConnection();
        health.services.fcm = testResult;
      } catch (error) {
        console.error('FCM health check failed:', error);
      }

      const allHealthy = Object.values(health.services).every(Boolean);
      
      res.status(allHealthy ? 200 : 503).json({
        ...health,
        status: allHealthy ? 'healthy' : 'degraded',
      });

    } catch (error) {
      res.status(500).json({
        status: 'unhealthy',
        error: error instanceof Error ? error.message : 'Error desconocido',
        timestamp: new Date().toISOString(),
      });
    }
  });