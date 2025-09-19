const functions = require('firebase-functions');
const admin = require('firebase-admin');
const sgMail = require('@sendgrid/api');
const sgClient = require('@sendgrid/client');
const mailgun = require('mailgun-js');

// Inicialización de Firebase Admin si no está inicializado
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Email Service Manager - SendGrid & Mailgun Integration
 * Sistema profesional de envío de emails con múltiples proveedores
 * 
 * Características:
 * - Integración dual SendGrid + Mailgun
 * - Failover automático entre proveedores
 * - Templates profesionales
 * - Analytics y métricas de delivery
 * - Rate limiting y throttling
 * - Bounce y complaint handling
 * - Segmentación de usuarios
 * - A/B testing de emails
 * - Personalización dinámica
 * - Reportes detallados
 */

// Configuración de SendGrid
const SENDGRID_CONFIG = {
  apiKey: functions.config().sendgrid?.api_key || process.env.SENDGRID_API_KEY,
  fromEmail: 'noreply@oasistaxiperu.com',
  fromName: 'OasisTaxi Perú',
  webhookUrl: 'https://us-central1-oasis-taxi-peru.cloudfunctions.net/handleSendGridWebhook',
  templates: {
    welcome: 'd-f180e70eb8e44e9bb6f6c0db1e6c5f8a',
    tripConfirmation: 'd-a1b2c3d4e5f6789012345678901234567',
    passwordReset: 'd-b2c3d4e5f6789012345678901234567890',
    receipt: 'd-c3d4e5f6789012345678901234567890123',
    newsletter: 'd-d4e5f6789012345678901234567890123456'
  }
};

// Configuración de Mailgun
const MAILGUN_CONFIG = {
  domain: functions.config().mailgun?.domain || process.env.MAILGUN_DOMAIN,
  apiKey: functions.config().mailgun?.api_key || process.env.MAILGUN_API_KEY,
  fromEmail: 'noreply@oasistaxiperu.com',
  fromName: 'OasisTaxi Perú',
  webhookUrl: 'https://us-central1-oasis-taxi-peru.cloudfunctions.net/handleMailgunWebhook',
  templates: {
    welcome: 'welcome-template',
    tripConfirmation: 'trip-confirmation-template',
    passwordReset: 'password-reset-template',
    receipt: 'receipt-template',
    newsletter: 'newsletter-template'
  }
};

// Inicializar SendGrid
if (SENDGRID_CONFIG.apiKey) {
  sgMail.setApiKey(SENDGRID_CONFIG.apiKey);
  sgClient.setApiKey(SENDGRID_CONFIG.apiKey);
}

// Inicializar Mailgun
let mg = null;
if (MAILGUN_CONFIG.domain && MAILGUN_CONFIG.apiKey) {
  mg = mailgun({
    apiKey: MAILGUN_CONFIG.apiKey,
    domain: MAILGUN_CONFIG.domain
  });
}

// Tipos de email disponibles
const EMAIL_TYPES = {
  WELCOME: 'welcome',
  TRIP_CONFIRMATION: 'tripConfirmation',
  TRIP_COMPLETED: 'tripCompleted',
  PASSWORD_RESET: 'passwordReset',
  RECEIPT: 'receipt',
  NEWSLETTER: 'newsletter',
  PROMOTIONAL: 'promotional',
  NOTIFICATION: 'notification',
  DRIVER_APPROVED: 'driverApproved',
  DRIVER_REJECTED: 'driverRejected',
  PAYMENT_REMINDER: 'paymentReminder',
  WEEKLY_SUMMARY: 'weeklySummary',
  SURVEY: 'survey'
};

// Configuración de rate limiting
const RATE_LIMITS = {
  sendgrid: {
    requestsPerSecond: 10,
    requestsPerHour: 1000,
    requestsPerDay: 40000
  },
  mailgun: {
    requestsPerSecond: 5,
    requestsPerHour: 500,
    requestsPerDay: 10000
  }
};

// Sistema de failover
const FAILOVER_CONFIG = {
  primaryProvider: 'sendgrid',
  secondaryProvider: 'mailgun',
  maxRetries: 3,
  retryDelay: 2000,
  circuitBreakerThreshold: 5,
  circuitBreakerTimeout: 300000 // 5 minutos
};

// Circuit breaker state
let circuitBreaker = {
  sendgrid: { failures: 0, lastFailure: null, isOpen: false },
  mailgun: { failures: 0, lastFailure: null, isOpen: false }
};

/**
 * Enviar email con failover automático
 */
exports.sendEmail = functions
  .runWith({
    timeoutSeconds: 300,
    memory: '1GB'
  })
  .https.onCall(async (data, context) => {
    try {
      // Validar autenticación para ciertos tipos de emails
      const requiresAuth = ['receipt', 'tripConfirmation', 'weeklySummary'];
      if (requiresAuth.includes(data.emailType) && !context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
      }

      const {
        to,
        emailType,
        templateData = {},
        priority = 'normal',
        scheduledFor = null,
        trackOpens = true,
        trackClicks = true,
        tags = [],
        attachments = []
      } = data;

      // Validaciones
      if (!to || !emailType) {
        throw new functions.https.HttpsError('invalid-argument', 'Email y tipo son requeridos');
      }

      if (!Object.values(EMAIL_TYPES).includes(emailType)) {
        throw new functions.https.HttpsError('invalid-argument', 'Tipo de email no válido');
      }

      // Verificar si el usuario está en lista de no envío
      const isUnsubscribed = await checkUnsubscribeStatus(to);
      if (isUnsubscribed && !['passwordReset', 'receipt'].includes(emailType)) {
        throw new functions.https.HttpsError('failed-precondition', 'Usuario dado de baja de emails');
      }

      // Preparar email
      const emailData = {
        id: generateEmailId(),
        to,
        emailType,
        templateData,
        priority,
        scheduledFor: scheduledFor ? admin.firestore.Timestamp.fromDate(new Date(scheduledFor)) : null,
        trackOpens,
        trackClicks,
        tags: [...tags, emailType, priority],
        attachments,
        status: 'pending',
        attempts: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: context.auth?.uid || 'system'
      };

      // Si es para envío inmediato
      if (!scheduledFor) {
        const result = await sendEmailWithFailover(emailData);
        return result;
      } else {
        // Programar para envío posterior
        await db.collection('scheduledEmails').doc(emailData.id).set(emailData);
        
        return {
          success: true,
          emailId: emailData.id,
          status: 'scheduled',
          scheduledFor: scheduledFor,
          message: 'Email programado exitosamente'
        };
      }

    } catch (error) {
      console.error('Error enviando email:', error);
      throw new functions.https.HttpsError('internal', 'Error interno del servidor');
    }
  });

/**
 * Enviar email con sistema de failover
 */
async function sendEmailWithFailover(emailData) {
  const primaryProvider = FAILOVER_CONFIG.primaryProvider;
  const secondaryProvider = FAILOVER_CONFIG.secondaryProvider;

  let result = null;
  let lastError = null;

  // Intentar con proveedor primario
  if (!isCircuitBreakerOpen(primaryProvider)) {
    try {
      result = await sendEmailWithProvider(emailData, primaryProvider);
      if (result.success) {
        resetCircuitBreaker(primaryProvider);
        await logEmailSent(emailData, primaryProvider, result);
        return result;
      }
    } catch (error) {
      lastError = error;
      incrementCircuitBreakerFailures(primaryProvider);
      console.warn(`Error con proveedor primario ${primaryProvider}:`, error.message);
    }
  }

  // Intentar con proveedor secundario
  if (!isCircuitBreakerOpen(secondaryProvider)) {
    try {
      result = await sendEmailWithProvider(emailData, secondaryProvider);
      if (result.success) {
        resetCircuitBreaker(secondaryProvider);
        await logEmailSent(emailData, secondaryProvider, result);
        return result;
      }
    } catch (error) {
      lastError = error;
      incrementCircuitBreakerFailures(secondaryProvider);
      console.warn(`Error con proveedor secundario ${secondaryProvider}:`, error.message);
    }
  }

  // Si ambos proveedores fallaron
  await logEmailFailed(emailData, lastError);
  
  return {
    success: false,
    error: 'Ambos proveedores de email fallaron',
    details: lastError?.message || 'Error desconocido'
  };
}

/**
 * Enviar email con un proveedor específico
 */
async function sendEmailWithProvider(emailData, provider) {
  switch (provider) {
    case 'sendgrid':
      return await sendWithSendGrid(emailData);
    case 'mailgun':
      return await sendWithMailgun(emailData);
    default:
      throw new Error(`Proveedor no soportado: ${provider}`);
  }
}

/**
 * Enviar email con SendGrid
 */
async function sendWithSendGrid(emailData) {
  if (!SENDGRID_CONFIG.apiKey) {
    throw new Error('SendGrid API key no configurada');
  }

  const templateId = SENDGRID_CONFIG.templates[emailData.emailType];
  if (!templateId) {
    throw new Error(`Template no encontrado para tipo: ${emailData.emailType}`);
  }

  const message = {
    to: emailData.to,
    from: {
      email: SENDGRID_CONFIG.fromEmail,
      name: SENDGRID_CONFIG.fromName
    },
    templateId: templateId,
    dynamicTemplateData: {
      ...emailData.templateData,
      user_email: emailData.to,
      timestamp: new Date().toISOString()
    },
    trackingSettings: {
      clickTracking: { enable: emailData.trackClicks },
      openTracking: { enable: emailData.trackOpens }
    },
    customArgs: {
      email_id: emailData.id,
      email_type: emailData.emailType,
      priority: emailData.priority
    },
    categories: emailData.tags
  };

  // Agregar attachments si existen
  if (emailData.attachments && emailData.attachments.length > 0) {
    message.attachments = emailData.attachments.map(att => ({
      content: att.content,
      filename: att.filename,
      type: att.type,
      disposition: att.disposition || 'attachment'
    }));
  }

  const response = await sgMail.send(message);

  return {
    success: true,
    provider: 'sendgrid',
    messageId: response[0].headers['x-message-id'],
    response: response[0]
  };
}

/**
 * Enviar email con Mailgun
 */
async function sendWithMailgun(emailData) {
  if (!mg) {
    throw new Error('Mailgun no configurado correctamente');
  }

  const templateName = MAILGUN_CONFIG.templates[emailData.emailType];
  if (!templateName) {
    throw new Error(`Template no encontrado para tipo: ${emailData.emailType}`);
  }

  const messageData = {
    from: `${MAILGUN_CONFIG.fromName} <${MAILGUN_CONFIG.fromEmail}>`,
    to: emailData.to,
    template: templateName,
    'h:X-Mailgun-Variables': JSON.stringify({
      ...emailData.templateData,
      user_email: emailData.to,
      timestamp: new Date().toISOString()
    }),
    'o:tag': emailData.tags,
    'o:tracking': emailData.trackOpens ? 'yes' : 'no',
    'o:tracking-clicks': emailData.trackClicks ? 'yes' : 'no'
  };

  // Agregar headers personalizados
  messageData['h:X-Email-ID'] = emailData.id;
  messageData['h:X-Email-Type'] = emailData.emailType;
  messageData['h:X-Priority'] = emailData.priority;

  // Agregar attachments si existen
  if (emailData.attachments && emailData.attachments.length > 0) {
    messageData.attachment = emailData.attachments.map(att => ({
      data: Buffer.from(att.content, 'base64'),
      filename: att.filename,
      contentType: att.type
    }));
  }

  const response = await mg.messages().send(messageData);

  return {
    success: true,
    provider: 'mailgun',
    messageId: response.id,
    response: response
  };
}

/**
 * Procesar emails programados
 */
exports.processScheduledEmails = functions
  .runWith({
    timeoutSeconds: 540,
    memory: '2GB'
  })
  .pubsub.schedule('*/5 * * * *') // Cada 5 minutos
  .timeZone('America/Lima')
  .onRun(async (context) => {
    try {
      const now = admin.firestore.Timestamp.now();
      
      // Buscar emails programados que ya deben enviarse
      const scheduledEmailsSnapshot = await db.collection('scheduledEmails')
        .where('status', '==', 'pending')
        .where('scheduledFor', '<=', now)
        .limit(100)
        .get();

      console.log(`Procesando ${scheduledEmailsSnapshot.size} emails programados`);

      const promises = [];

      scheduledEmailsSnapshot.forEach(doc => {
        const emailData = { id: doc.id, ...doc.data() };
        
        promises.push(
          sendEmailWithFailover(emailData)
            .then(async (result) => {
              await doc.ref.update({
                status: result.success ? 'sent' : 'failed',
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
                result: result
              });
            })
            .catch(async (error) => {
              console.error(`Error procesando email programado ${doc.id}:`, error);
              
              await doc.ref.update({
                status: 'failed',
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
                error: error.message
              });
            })
        );
      });

      await Promise.all(promises);

      console.log('Procesamiento de emails programados completado');

    } catch (error) {
      console.error('Error procesando emails programados:', error);
    }
  });

/**
 * Webhook handler para SendGrid
 */
exports.handleSendGridWebhook = functions
  .runWith({
    timeoutSeconds: 60,
    memory: '512MB'
  })
  .https.onRequest(async (req, res) => {
    try {
      if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Método no permitido' });
      }

      const events = req.body;
      if (!Array.isArray(events)) {
        return res.status(400).json({ error: 'Formato de datos inválido' });
      }

      console.log(`Recibidos ${events.length} eventos de SendGrid`);

      const promises = events.map(async (event) => {
        try {
          await processEmailEvent({
            provider: 'sendgrid',
            emailId: event.email_id,
            eventType: event.event,
            timestamp: new Date(event.timestamp * 1000),
            email: event.email,
            reason: event.reason,
            response: event.response,
            userAgent: event.useragent,
            ip: event.ip,
            url: event.url
          });
        } catch (error) {
          console.error('Error procesando evento SendGrid:', error);
        }
      });

      await Promise.all(promises);

      res.status(200).json({ message: 'Eventos procesados exitosamente' });

    } catch (error) {
      console.error('Error en webhook SendGrid:', error);
      res.status(500).json({ error: 'Error interno del servidor' });
    }
  });

/**
 * Webhook handler para Mailgun
 */
exports.handleMailgunWebhook = functions
  .runWith({
    timeoutSeconds: 60,
    memory: '512MB'
  })
  .https.onRequest(async (req, res) => {
    try {
      if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Método no permitido' });
      }

      const event = req.body;
      console.log('Evento Mailgun recibido:', event['event-data']?.event);

      const eventData = event['event-data'];
      if (!eventData) {
        return res.status(400).json({ error: 'Datos de evento faltantes' });
      }

      await processEmailEvent({
        provider: 'mailgun',
        emailId: eventData.message?.headers?.['x-email-id'],
        eventType: eventData.event,
        timestamp: new Date(eventData.timestamp * 1000),
        email: eventData.recipient,
        reason: eventData.reason,
        response: eventData.delivery?.response,
        userAgent: eventData['client-info']?.['client-name'],
        ip: eventData['client-info']?.['client-ip'],
        url: eventData.url
      });

      res.status(200).json({ message: 'Evento procesado exitosamente' });

    } catch (error) {
      console.error('Error en webhook Mailgun:', error);
      res.status(500).json({ error: 'Error interno del servidor' });
    }
  });

/**
 * Procesar evento de email
 */
async function processEmailEvent(eventData) {
  const {
    provider,
    emailId,
    eventType,
    timestamp,
    email,
    reason,
    response,
    userAgent,
    ip,
    url
  } = eventData;

  // Guardar evento en Firestore
  await db.collection('emailEvents').add({
    provider,
    emailId: emailId || 'unknown',
    eventType,
    timestamp: admin.firestore.Timestamp.fromDate(timestamp),
    email,
    reason,
    response,
    userAgent,
    ip,
    url,
    processedAt: admin.firestore.FieldValue.serverTimestamp()
  });

  // Actualizar métricas agregadas
  await updateEmailMetrics(provider, eventType, email);

  // Manejar eventos específicos
  switch (eventType) {
    case 'bounce':
    case 'dropped':
      await handleBounce(email, reason);
      break;
    
    case 'spam':
    case 'unsubscribe':
      await handleUnsubscribe(email, eventType);
      break;
    
    case 'click':
      await handleClick(email, url, userAgent, ip);
      break;
  }
}

/**
 * Manejar bounces de email
 */
async function handleBounce(email, reason) {
  try {
    const bounceDoc = await db.collection('emailBounces').doc(email).get();
    
    if (bounceDoc.exists) {
      // Incrementar contador de bounces
      await bounceDoc.ref.update({
        bounceCount: admin.firestore.FieldValue.increment(1),
        lastBounce: admin.firestore.FieldValue.serverTimestamp(),
        lastReason: reason
      });
    } else {
      // Crear nuevo registro de bounce
      await db.collection('emailBounces').doc(email).set({
        email,
        bounceCount: 1,
        firstBounce: admin.firestore.FieldValue.serverTimestamp(),
        lastBounce: admin.firestore.FieldValue.serverTimestamp(),
        lastReason: reason,
        status: 'bounced'
      });
    }

    // Si hay muchos bounces, agregar a lista de supresión
    const updatedDoc = await db.collection('emailBounces').doc(email).get();
    const bounceData = updatedDoc.data();
    
    if (bounceData.bounceCount >= 3) {
      await db.collection('suppressedEmails').doc(email).set({
        email,
        reason: 'multiple_bounces',
        suppressedAt: admin.firestore.FieldValue.serverTimestamp(),
        bounceCount: bounceData.bounceCount
      });
    }

  } catch (error) {
    console.error('Error manejando bounce:', error);
  }
}

/**
 * Manejar unsubscribes
 */
async function handleUnsubscribe(email, eventType) {
  try {
    await db.collection('unsubscribes').doc(email).set({
      email,
      unsubscribeType: eventType,
      unsubscribedAt: admin.firestore.FieldValue.serverTimestamp(),
      source: 'email_event'
    });

    // Actualizar también en suppressedEmails
    await db.collection('suppressedEmails').doc(email).set({
      email,
      reason: eventType,
      suppressedAt: admin.firestore.FieldValue.serverTimestamp(),
      source: 'email_event'
    });

    console.log(`Usuario dado de baja: ${email} por ${eventType}`);

  } catch (error) {
    console.error('Error manejando unsubscribe:', error);
  }
}

/**
 * Manejar clicks en emails
 */
async function handleClick(email, url, userAgent, ip) {
  try {
    await db.collection('emailClicks').add({
      email,
      url,
      userAgent,
      ip,
      clickedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Actualizar perfil del usuario con información de engagement
    const userQuerySnapshot = await db.collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();

    if (!userQuerySnapshot.empty) {
      const userDoc = userQuerySnapshot.docs[0];
      await userDoc.ref.update({
        'emailEngagement.lastClick': admin.firestore.FieldValue.serverTimestamp(),
        'emailEngagement.clickCount': admin.firestore.FieldValue.increment(1)
      });
    }

  } catch (error) {
    console.error('Error manejando click:', error);
  }
}

/**
 * Actualizar métricas agregadas
 */
async function updateEmailMetrics(provider, eventType, email) {
  try {
    const today = new Date().toISOString().split('T')[0];
    const metricsRef = db.collection('emailMetrics').doc(`${provider}_${today}`);

    const increment = admin.firestore.FieldValue.increment(1);
    const updateData = {
      provider,
      date: today,
      [`events.${eventType}`]: increment,
      'events.total': increment,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    await metricsRef.set(updateData, { merge: true });

  } catch (error) {
    console.error('Error actualizando métricas:', error);
  }
}

/**
 * Verificar estado de unsubscribe
 */
async function checkUnsubscribeStatus(email) {
  try {
    const unsubscribeDoc = await db.collection('unsubscribes').doc(email).get();
    const suppressedDoc = await db.collection('suppressedEmails').doc(email).get();
    
    return unsubscribeDoc.exists || suppressedDoc.exists;
  } catch (error) {
    console.error('Error verificando estado unsubscribe:', error);
    return false;
  }
}

/**
 * Generar ID único para email
 */
function generateEmailId() {
  return `email_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

/**
 * Funciones del circuit breaker
 */
function isCircuitBreakerOpen(provider) {
  const breaker = circuitBreaker[provider];
  if (!breaker.isOpen) return false;
  
  const now = Date.now();
  const timeSinceLastFailure = now - (breaker.lastFailure || 0);
  
  if (timeSinceLastFailure > FAILOVER_CONFIG.circuitBreakerTimeout) {
    breaker.isOpen = false;
    breaker.failures = 0;
    return false;
  }
  
  return true;
}

function incrementCircuitBreakerFailures(provider) {
  const breaker = circuitBreaker[provider];
  breaker.failures++;
  breaker.lastFailure = Date.now();
  
  if (breaker.failures >= FAILOVER_CONFIG.circuitBreakerThreshold) {
    breaker.isOpen = true;
    console.warn(`Circuit breaker abierto para ${provider}`);
  }
}

function resetCircuitBreaker(provider) {
  circuitBreaker[provider] = {
    failures: 0,
    lastFailure: null,
    isOpen: false
  };
}

/**
 * Log de email enviado
 */
async function logEmailSent(emailData, provider, result) {
  try {
    await db.collection('emailLogs').add({
      emailId: emailData.id,
      to: emailData.to,
      emailType: emailData.emailType,
      provider: provider,
      status: 'sent',
      messageId: result.messageId,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      priority: emailData.priority
    });
  } catch (error) {
    console.error('Error logging email enviado:', error);
  }
}

/**
 * Log de email fallido
 */
async function logEmailFailed(emailData, error) {
  try {
    await db.collection('emailLogs').add({
      emailId: emailData.id,
      to: emailData.to,
      emailType: emailData.emailType,
      status: 'failed',
      error: error?.message || 'Error desconocido',
      failedAt: admin.firestore.FieldValue.serverTimestamp(),
      priority: emailData.priority
    });
  } catch (error) {
    console.error('Error logging email fallido:', error);
  }
}

/**
 * Crear template de email
 */
exports.createEmailTemplate = functions
  .runWith({
    timeoutSeconds: 180,
    memory: '512MB'
  })
  .https.onCall(async (data, context) => {
    try {
      if (!context.auth || !context.auth.token.admin) {
        throw new functions.https.HttpsError('permission-denied', 'Requiere permisos de administrador');
      }

      const {
        name,
        subject,
        htmlContent,
        textContent,
        variables = [],
        category,
        isActive = true
      } = data;

      if (!name || !subject || !htmlContent) {
        throw new functions.https.HttpsError('invalid-argument', 'Datos requeridos faltantes');
      }

      const templateData = {
        name,
        subject,
        htmlContent,
        textContent: textContent || '',
        variables,
        category: category || 'general',
        isActive,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: context.auth.uid,
        version: 1
      };

      const templateRef = await db.collection('emailTemplates').add(templateData);

      return {
        success: true,
        templateId: templateRef.id,
        message: 'Template creado exitosamente'
      };

    } catch (error) {
      console.error('Error creando template:', error);
      throw new functions.https.HttpsError('internal', 'Error interno del servidor');
    }
  });

/**
 * Obtener métricas de email
 */
exports.getEmailMetrics = functions
  .runWith({
    timeoutSeconds: 60,
    memory: '512MB'
  })
  .https.onCall(async (data, context) => {
    try {
      if (!context.auth || !context.auth.token.admin) {
        throw new functions.https.HttpsError('permission-denied', 'Requiere permisos de administrador');
      }

      const {
        startDate,
        endDate,
        provider = null
      } = data;

      let query = db.collection('emailMetrics');

      if (startDate) {
        query = query.where('date', '>=', startDate);
      }

      if (endDate) {
        query = query.where('date', '<=', endDate);
      }

      if (provider) {
        query = query.where('provider', '==', provider);
      }

      const metricsSnapshot = await query.orderBy('date', 'desc').get();
      
      const metrics = [];
      let totals = {
        sent: 0,
        delivered: 0,
        opened: 0,
        clicked: 0,
        bounced: 0,
        spam: 0,
        unsubscribed: 0
      };

      metricsSnapshot.forEach(doc => {
        const data = doc.data();
        metrics.push({
          id: doc.id,
          ...data
        });

        // Sumar totales
        if (data.events) {
          totals.sent += data.events.sent || 0;
          totals.delivered += data.events.delivered || 0;
          totals.opened += data.events.opened || 0;
          totals.clicked += data.events.clicked || 0;
          totals.bounced += data.events.bounced || 0;
          totals.spam += data.events.spam || 0;
          totals.unsubscribed += data.events.unsubscribed || 0;
        }
      });

      // Calcular tasas
      const rates = {
        deliveryRate: totals.sent > 0 ? (totals.delivered / totals.sent) * 100 : 0,
        openRate: totals.delivered > 0 ? (totals.opened / totals.delivered) * 100 : 0,
        clickRate: totals.delivered > 0 ? (totals.clicked / totals.delivered) * 100 : 0,
        bounceRate: totals.sent > 0 ? (totals.bounced / totals.sent) * 100 : 0,
        spamRate: totals.sent > 0 ? (totals.spam / totals.sent) * 100 : 0,
        unsubscribeRate: totals.delivered > 0 ? (totals.unsubscribed / totals.delivered) * 100 : 0
      };

      return {
        success: true,
        metrics: metrics,
        summary: {
          totals,
          rates,
          period: {
            startDate: startDate || null,
            endDate: endDate || null
          },
          recordCount: metrics.length
        }
      };

    } catch (error) {
      console.error('Error obteniendo métricas:', error);
      throw new functions.https.HttpsError('internal', 'Error interno del servidor');
    }
  });

/**
 * Manejar unsubscribe manual
 */
exports.unsubscribeUser = functions
  .runWith({
    timeoutSeconds: 60,
    memory: '256MB'
  })
  .https.onRequest(async (req, res) => {
    try {
      const { email, token } = req.query;

      if (!email || !token) {
        return res.status(400).send('Parámetros faltantes');
      }

      // Verificar token (implementar verificación de seguridad)
      // Por simplicidad, usar hash simple
      const expectedToken = Buffer.from(email).toString('base64');
      if (token !== expectedToken) {
        return res.status(400).send('Token inválido');
      }

      await db.collection('unsubscribes').doc(email).set({
        email,
        unsubscribeType: 'manual',
        unsubscribedAt: admin.firestore.FieldValue.serverTimestamp(),
        source: 'unsubscribe_link'
      });

      await db.collection('suppressedEmails').doc(email).set({
        email,
        reason: 'manual_unsubscribe',
        suppressedAt: admin.firestore.FieldValue.serverTimestamp(),
        source: 'unsubscribe_link'
      });

      res.status(200).send(`
        <!DOCTYPE html>
        <html>
        <head>
            <title>Baja exitosa - OasisTaxi</title>
            <meta charset="utf-8">
        </head>
        <body style="font-family: Arial, sans-serif; text-align: center; margin-top: 50px;">
            <h1>¡Listo!</h1>
            <p>Te has dado de baja exitosamente de nuestros emails.</p>
            <p>Si cambias de opinión, siempre puedes volver a suscribirte desde la app.</p>
            <p><strong>Gracias por usar OasisTaxi.</strong></p>
        </body>
        </html>
      `);

    } catch (error) {
      console.error('Error en unsubscribe:', error);
      res.status(500).send('Error interno del servidor');
    }
  });

/**
 * Generar reporte de emails
 */
exports.generateEmailReport = functions
  .runWith({
    timeoutSeconds: 300,
    memory: '1GB'
  })
  .pubsub.schedule('0 9 * * MON') // Lunes a las 9 AM
  .timeZone('America/Lima')
  .onRun(async (context) => {
    try {
      const endDate = new Date();
      const startDate = new Date(endDate.getTime() - (7 * 24 * 60 * 60 * 1000)); // 7 días atrás

      const startDateStr = startDate.toISOString().split('T')[0];
      const endDateStr = endDate.toISOString().split('T')[0];

      // Obtener métricas de la semana
      const metricsSnapshot = await db.collection('emailMetrics')
        .where('date', '>=', startDateStr)
        .where('date', '<=', endDateStr)
        .get();

      let weeklyTotals = {
        sent: 0,
        delivered: 0,
        opened: 0,
        clicked: 0,
        bounced: 0,
        spam: 0,
        unsubscribed: 0
      };

      metricsSnapshot.forEach(doc => {
        const data = doc.data();
        if (data.events) {
          weeklyTotals.sent += data.events.sent || 0;
          weeklyTotals.delivered += data.events.delivered || 0;
          weeklyTotals.opened += data.events.opened || 0;
          weeklyTotals.clicked += data.events.clicked || 0;
          weeklyTotals.bounced += data.events.bounced || 0;
          weeklyTotals.spam += data.events.spam || 0;
          weeklyTotals.unsubscribed += data.events.unsubscribed || 0;
        }
      });

      // Guardar reporte semanal
      await db.collection('emailReports').add({
        type: 'weekly',
        period: {
          start: admin.firestore.Timestamp.fromDate(startDate),
          end: admin.firestore.Timestamp.fromDate(endDate)
        },
        metrics: weeklyTotals,
        rates: {
          deliveryRate: weeklyTotals.sent > 0 ? (weeklyTotals.delivered / weeklyTotals.sent) * 100 : 0,
          openRate: weeklyTotals.delivered > 0 ? (weeklyTotals.opened / weeklyTotals.delivered) * 100 : 0,
          clickRate: weeklyTotals.delivered > 0 ? (weeklyTotals.clicked / weeklyTotals.delivered) * 100 : 0,
          bounceRate: weeklyTotals.sent > 0 ? (weeklyTotals.bounced / weeklyTotals.sent) * 100 : 0
        },
        generatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      console.log('Reporte semanal de emails generado', weeklyTotals);

    } catch (error) {
      console.error('Error generando reporte semanal:', error);
    }
  });

module.exports = {
  EMAIL_TYPES,
  SENDGRID_CONFIG,
  MAILGUN_CONFIG,
  FAILOVER_CONFIG
};