const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

// Inicialización de Firebase Admin si no está inicializado
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * A/B Testing Manager para Mensajes
 * Sistema profesional para testing de diferentes variantes de mensajes
 * 
 * Características:
 * - A/B Testing para notificaciones push
 * - A/B Testing para emails  
 * - A/B Testing para mensajes in-app
 * - A/B Testing para SMS
 * - Análisis estadístico automático
 * - Segmentación de usuarios
 * - Reportes de performance
 */

// Configuración de transporter para emails de testing
const createEmailTransporter = () => {
  return nodemailer.createTransporter({
    service: 'gmail',
    auth: {
      user: functions.config().email?.user || process.env.EMAIL_USER,
      pass: functions.config().email?.password || process.env.EMAIL_PASSWORD
    }
  });
};

// Configuraciones de experimentos de mensajes
const MESSAGE_EXPERIMENT_CONFIGS = {
  types: {
    PUSH_NOTIFICATION: 'push_notification',
    EMAIL: 'email',
    IN_APP_MESSAGE: 'in_app_message',
    SMS: 'sms',
    WHATSAPP: 'whatsapp'
  },
  metrics: {
    OPEN_RATE: 'open_rate',
    CLICK_RATE: 'click_rate', 
    CONVERSION_RATE: 'conversion_rate',
    UNSUBSCRIBE_RATE: 'unsubscribe_rate',
    RESPONSE_TIME: 'response_time'
  },
  segments: {
    NEW_USERS: 'new_users',
    RETURNING_USERS: 'returning_users',
    DRIVERS: 'drivers',
    PASSENGERS: 'passengers',
    VIP_USERS: 'vip_users',
    INACTIVE_USERS: 'inactive_users'
  }
};

// Plantillas predefinidas para diferentes tipos de mensajes
const MESSAGE_TEMPLATES = {
  push_notification: {
    ride_request: {
      variants: [
        {
          title: "¡Nueva solicitud de viaje!",
          body: "Un pasajero te necesita. ¡Acepta ahora!",
          data: { priority: 'high', sound: 'default' }
        },
        {
          title: "¡Oportunidad de viaje!",
          body: "Hay un viaje disponible cerca tuyo",
          data: { priority: 'high', sound: 'chime' }
        },
        {
          title: "🚖 Nuevo viaje",
          body: "Gana dinero ahora - viaje disponible",
          data: { priority: 'high', sound: 'ding' }
        }
      ]
    },
    price_negotiation: {
      variants: [
        {
          title: "Negociación de precio",
          body: "El conductor propuso S/{price}. ¿Aceptas?",
          data: { type: 'negotiation', priority: 'high' }
        },
        {
          title: "💰 Contraoferta recibida",
          body: "Nuevo precio: S/{price}",
          data: { type: 'negotiation', priority: 'high' }
        },
        {
          title: "¡Precio actualizado!",
          body: "El conductor ofrece S/{price} por tu viaje",
          data: { type: 'negotiation', priority: 'high' }
        }
      ]
    },
    trip_completion: {
      variants: [
        {
          title: "¡Viaje completado!",
          body: "Califica tu experiencia y ayuda a otros usuarios",
          data: { type: 'rating', priority: 'normal' }
        },
        {
          title: "¡Llegaste a destino! ⭐",
          body: "¿Cómo estuvo tu viaje? Califícanos",
          data: { type: 'rating', priority: 'normal' }
        },
        {
          title: "Viaje finalizado",
          body: "Tu opinión es importante - deja tu calificación",
          data: { type: 'rating', priority: 'normal' }
        }
      ]
    }
  },
  email: {
    welcome: {
      variants: [
        {
          subject: "¡Bienvenido a OasisTaxi Perú! 🚖",
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
              <h1 style="color: #2196F3;">¡Bienvenido a OasisTaxi!</h1>
              <p>Gracias por unirte a la mejor plataforma de transporte del Perú.</p>
              <a href="{app_link}" style="background: #2196F3; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">Comenzar ahora</a>
            </div>
          `
        },
        {
          subject: "¡Tu aventura con OasisTaxi comienza aquí! 🌟",
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
              <h1 style="color: #FF9800;">¡Hola y bienvenido!</h1>
              <p>Estás a un paso de vivir la mejor experiencia de transporte.</p>
              <a href="{app_link}" style="background: #FF9800; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">Empezar mi primer viaje</a>
            </div>
          `
        },
        {
          subject: "¡OasisTaxi te da la bienvenida! 🎉",
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
              <h1 style="color: #4CAF50;">¡Excelente elección!</h1>
              <p>Te has registrado en la app de transporte más confiable del Perú.</p>
              <a href="{app_link}" style="background: #4CAF50; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">Explorar la app</a>
            </div>
          `
        }
      ]
    },
    payment_reminder: {
      variants: [
        {
          subject: "Recordatorio: Viaje pendiente de pago",
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
              <h2>Recordatorio de pago</h2>
              <p>Tienes un viaje pendiente de pago por S/{amount}.</p>
              <a href="{payment_link}">Pagar ahora</a>
            </div>
          `
        },
        {
          subject: "💳 Completa tu pago - OasisTaxi",
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
              <h2>¡Casi listo! 💰</h2>
              <p>Solo falta completar el pago de S/{amount} por tu último viaje.</p>
              <a href="{payment_link}">Finalizar pago</a>
            </div>
          `
        },
        {
          subject: "Pago pendiente - Acción requerida",
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
              <h2>Atención requerida</h2>
              <p>Para seguir usando OasisTaxi, completa el pago de S/{amount}.</p>
              <a href="{payment_link}">Procesar pago</a>
            </div>
          `
        }
      ]
    }
  },
  in_app_message: {
    promotion: {
      variants: [
        {
          title: "🎉 ¡Oferta especial!",
          content: "Descuento del 20% en tu próximo viaje",
          cta: "Usar descuento",
          style: { backgroundColor: '#E3F2FD', textColor: '#1976D2' }
        },
        {
          title: "💥 ¡Super descuento!",
          content: "20% OFF - Solo por tiempo limitado",
          cta: "¡Quiero mi descuento!",
          style: { backgroundColor: '#FFF3E0', textColor: '#F57C00' }
        },
        {
          title: "✨ Promoción exclusiva",
          content: "Tu descuento del 20% te está esperando",
          cta: "Activar promoción",
          style: { backgroundColor: '#E8F5E8', textColor: '#388E3C' }
        }
      ]
    },
    driver_bonus: {
      variants: [
        {
          title: "🏆 ¡Bono disponible!",
          content: "Completa 5 viajes y gana S/25 extra",
          cta: "Ver detalles",
          style: { backgroundColor: '#F3E5F5', textColor: '#7B1FA2' }
        },
        {
          title: "💰 Oportunidad de ganar más",
          content: "Bono de S/25 por 5 viajes completados",
          cta: "¡Lo quiero!",
          style: { backgroundColor: '#E0F2F1', textColor: '#00796B' }
        },
        {
          title: "🚀 Incentivo especial",
          content: "5 viajes = S/25 de bono garantizado",
          cta: "Comenzar ahora",
          style: { backgroundColor: '#FFF8E1', textColor: '#F9A825' }
        }
      ]
    }
  },
  sms: {
    verification: {
      variants: [
        "Tu código OasisTaxi es: {code}. Válido por 5 minutos.",
        "OasisTaxi: {code} es tu código de verificación",
        "Código de seguridad OasisTaxi: {code} (válido 5 min)"
      ]
    },
    trip_update: {
      variants: [
        "Tu conductor {driver_name} llegará en {eta} minutos. Placa: {plate}",
        "🚖 {driver_name} está en camino. ETA: {eta} min. Vehículo: {plate}",
        "Actualización: Tu conductor {driver_name} llegará en {eta}. Placa {plate}"
      ]
    }
  }
};

/**
 * Crear experimento de mensaje A/B
 */
exports.createMessageABTest = functions
  .runWith({ 
    timeoutSeconds: 300, 
    memory: '1GB' 
  })
  .https.onCall(async (data, context) => {
    try {
      // Verificar autenticación de admin
      if (!context.auth || !context.auth.token.admin) {
        throw new functions.https.HttpsError('permission-denied', 'Requiere permisos de administrador');
      }

      const {
        name,
        description,
        messageType, // push_notification, email, in_app_message, sms
        variants,
        targetSegment,
        trafficSplit,
        duration,
        metrics,
        startDate,
        endDate
      } = data;

      // Validaciones
      if (!name || !messageType || !variants || variants.length < 2) {
        throw new functions.https.HttpsError('invalid-argument', 'Datos requeridos faltantes');
      }

      if (!Object.values(MESSAGE_EXPERIMENT_CONFIGS.types).includes(messageType)) {
        throw new functions.https.HttpsError('invalid-argument', 'Tipo de mensaje no válido');
      }

      // Crear documento del experimento
      const experimentRef = db.collection('messageABTests').doc();
      const experimentData = {
        id: experimentRef.id,
        name,
        description: description || '',
        messageType,
        variants: variants.map((variant, index) => ({
          id: `variant_${index}`,
          ...variant,
          assignedUsers: 0,
          metrics: {}
        })),
        targetSegment: targetSegment || 'all_users',
        trafficSplit: trafficSplit || variants.map(() => 100 / variants.length),
        duration: duration || 7, // días
        metrics: metrics || ['open_rate', 'click_rate'],
        status: 'draft',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: context.auth.uid,
        startDate: startDate ? admin.firestore.Timestamp.fromDate(new Date(startDate)) : null,
        endDate: endDate ? admin.firestore.Timestamp.fromDate(new Date(endDate)) : null,
        totalUsers: 0,
        results: {
          statistical_significance: false,
          confidence_level: 0,
          winner: null,
          analysis: {}
        }
      };

      await experimentRef.set(experimentData);

      // Crear colección de eventos para tracking
      await experimentRef.collection('events').doc('_init').set({
        initialized: true,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });

      console.log(`Experimento de mensaje A/B creado: ${experimentRef.id}`);

      return {
        success: true,
        experimentId: experimentRef.id,
        message: 'Experimento de mensaje A/B creado exitosamente'
      };

    } catch (error) {
      console.error('Error creando experimento de mensaje A/B:', error);
      throw new functions.https.HttpsError('internal', 'Error interno del servidor');
    }
  });

/**
 * Activar experimento de mensaje A/B
 */
exports.activateMessageABTest = functions
  .runWith({ 
    timeoutSeconds: 180,
    memory: '512MB'
  })
  .https.onCall(async (data, context) => {
    try {
      if (!context.auth || !context.auth.token.admin) {
        throw new functions.https.HttpsError('permission-denied', 'Requiere permisos de administrador');
      }

      const { experimentId } = data;
      
      const experimentRef = db.collection('messageABTests').doc(experimentId);
      const experimentDoc = await experimentRef.get();
      
      if (!experimentDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Experimento no encontrado');
      }

      const experimentData = experimentDoc.data();
      
      if (experimentData.status === 'active') {
        throw new functions.https.HttpsError('failed-precondition', 'Experimento ya está activo');
      }

      // Calcular fechas si no están definidas
      const now = new Date();
      const startDate = experimentData.startDate?.toDate() || now;
      const endDate = experimentData.endDate?.toDate() || new Date(now.getTime() + (experimentData.duration * 24 * 60 * 60 * 1000));

      await experimentRef.update({
        status: 'active',
        activatedAt: admin.firestore.FieldValue.serverTimestamp(),
        startDate: admin.firestore.Timestamp.fromDate(startDate),
        endDate: admin.firestore.Timestamp.fromDate(endDate)
      });

      console.log(`Experimento de mensaje activado: ${experimentId}`);

      return {
        success: true,
        message: 'Experimento activado exitosamente',
        startDate: startDate.toISOString(),
        endDate: endDate.toISOString()
      };

    } catch (error) {
      console.error('Error activando experimento:', error);
      throw new functions.https.HttpsError('internal', 'Error interno del servidor');
    }
  });

/**
 * Asignar usuario a variante de experimento
 */
exports.assignUserToMessageVariant = functions
  .runWith({ 
    timeoutSeconds: 60,
    memory: '256MB'
  })
  .https.onCall(async (data, context) => {
    try {
      if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
      }

      const { experimentId, userId, userSegment } = data;
      const targetUserId = userId || context.auth.uid;

      const experimentRef = db.collection('messageABTests').doc(experimentId);
      const experimentDoc = await experimentRef.get();

      if (!experimentDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Experimento no encontrado');
      }

      const experimentData = experimentDoc.data();

      if (experimentData.status !== 'active') {
        throw new functions.https.HttpsError('failed-precondition', 'Experimento no está activo');
      }

      // Verificar si el usuario ya está asignado
      const assignmentRef = db.collection('messageABTests')
        .doc(experimentId)
        .collection('userAssignments')
        .doc(targetUserId);
      
      const assignmentDoc = await assignmentRef.get();
      
      if (assignmentDoc.exists) {
        return {
          success: true,
          variantId: assignmentDoc.data().variantId,
          variant: experimentData.variants.find(v => v.id === assignmentDoc.data().variantId),
          alreadyAssigned: true
        };
      }

      // Verificar si el usuario pertenece al segmento objetivo
      if (experimentData.targetSegment !== 'all_users' && userSegment !== experimentData.targetSegment) {
        throw new functions.https.HttpsError('failed-precondition', 'Usuario no pertenece al segmento objetivo');
      }

      // Asignar variante basada en distribución de tráfico
      const randomValue = Math.random() * 100;
      let cumulativePercentage = 0;
      let selectedVariant = null;

      for (let i = 0; i < experimentData.variants.length; i++) {
        cumulativePercentage += experimentData.trafficSplit[i];
        if (randomValue < cumulativePercentage) {
          selectedVariant = experimentData.variants[i];
          break;
        }
      }

      if (!selectedVariant) {
        selectedVariant = experimentData.variants[0]; // Fallback
      }

      // Guardar asignación
      await assignmentRef.set({
        userId: targetUserId,
        experimentId: experimentId,
        variantId: selectedVariant.id,
        assignedAt: admin.firestore.FieldValue.serverTimestamp(),
        userSegment: userSegment || 'unknown'
      });

      // Actualizar contadores
      await experimentRef.update({
        totalUsers: admin.firestore.FieldValue.increment(1),
        [`variants.${experimentData.variants.indexOf(selectedVariant)}.assignedUsers`]: admin.firestore.FieldValue.increment(1)
      });

      return {
        success: true,
        variantId: selectedVariant.id,
        variant: selectedVariant,
        alreadyAssigned: false
      };

    } catch (error) {
      console.error('Error asignando usuario a variante:', error);
      throw new functions.https.HttpsError('internal', 'Error interno del servidor');
    }
  });

/**
 * Enviar mensaje de experimento A/B
 */
exports.sendABTestMessage = functions
  .runWith({
    timeoutSeconds: 300,
    memory: '1GB'
  })
  .https.onCall(async (data, context) => {
    try {
      if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
      }

      const { 
        experimentId, 
        userId, 
        messageData, 
        testMode = false 
      } = data;

      const targetUserId = userId || context.auth.uid;

      // Obtener asignación del usuario
      const assignmentDoc = await db.collection('messageABTests')
        .doc(experimentId)
        .collection('userAssignments')
        .doc(targetUserId)
        .get();

      if (!assignmentDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Usuario no asignado a experimento');
      }

      const assignment = assignmentDoc.data();
      
      // Obtener experimento
      const experimentDoc = await db.collection('messageABTests').doc(experimentId).get();
      if (!experimentDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Experimento no encontrado');
      }

      const experiment = experimentDoc.data();
      const variant = experiment.variants.find(v => v.id === assignment.variantId);

      if (!variant) {
        throw new functions.https.HttpsError('not-found', 'Variante no encontrada');
      }

      // Obtener datos del usuario
      const userDoc = await db.collection('users').doc(targetUserId).get();
      if (!userDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Usuario no encontrado');
      }

      const userData = userDoc.data();
      let result = {};

      // Enviar mensaje según el tipo
      switch (experiment.messageType) {
        case 'push_notification':
          result = await sendPushNotification(userData, variant, messageData, testMode);
          break;
        
        case 'email':
          result = await sendEmail(userData, variant, messageData, testMode);
          break;
        
        case 'in_app_message':
          result = await sendInAppMessage(targetUserId, variant, messageData, testMode);
          break;
        
        case 'sms':
          result = await sendSMS(userData, variant, messageData, testMode);
          break;
        
        default:
          throw new functions.https.HttpsError('invalid-argument', 'Tipo de mensaje no soportado');
      }

      // Registrar evento de envío
      await db.collection('messageABTests')
        .doc(experimentId)
        .collection('events')
        .add({
          type: 'message_sent',
          userId: targetUserId,
          variantId: assignment.variantId,
          messageType: experiment.messageType,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          messageData: messageData,
          result: result,
          testMode: testMode
        });

      console.log(`Mensaje A/B enviado - Experimento: ${experimentId}, Usuario: ${targetUserId}, Variante: ${assignment.variantId}`);

      return {
        success: true,
        variantId: assignment.variantId,
        messageType: experiment.messageType,
        result: result,
        testMode: testMode
      };

    } catch (error) {
      console.error('Error enviando mensaje A/B:', error);
      throw new functions.https.HttpsError('internal', 'Error interno del servidor');
    }
  });

/**
 * Función auxiliar para enviar notificación push
 */
async function sendPushNotification(userData, variant, messageData, testMode) {
  try {
    if (!userData.fcmToken) {
      throw new Error('Usuario sin token FCM');
    }

    let message = {
      notification: {
        title: variant.title || '',
        body: variant.body || ''
      },
      data: {
        ...variant.data,
        ab_test: 'true',
        variant_id: variant.id,
        ...messageData
      },
      token: userData.fcmToken
    };

    // Reemplazar placeholders en el mensaje
    if (messageData) {
      message.notification.title = replacePlaceholders(message.notification.title, messageData);
      message.notification.body = replacePlaceholders(message.notification.body, messageData);
    }

    if (testMode) {
      console.log('MODO TEST - Notificación push:', message);
      return { sent: true, testMode: true, message };
    }

    const response = await messaging.send(message);
    
    return {
      sent: true,
      messageId: response,
      title: message.notification.title,
      body: message.notification.body
    };

  } catch (error) {
    console.error('Error enviando push notification:', error);
    return {
      sent: false,
      error: error.message
    };
  }
}

/**
 * Función auxiliar para enviar email
 */
async function sendEmail(userData, variant, messageData, testMode) {
  try {
    if (!userData.email) {
      throw new Error('Usuario sin email');
    }

    const transporter = createEmailTransporter();
    
    let subject = variant.subject || 'Mensaje de OasisTaxi';
    let html = variant.html || variant.content || '';

    // Reemplazar placeholders
    if (messageData) {
      subject = replacePlaceholders(subject, messageData);
      html = replacePlaceholders(html, messageData);
    }

    const mailOptions = {
      from: functions.config().email?.user || process.env.EMAIL_USER,
      to: userData.email,
      subject: subject,
      html: html
    };

    if (testMode) {
      console.log('MODO TEST - Email:', mailOptions);
      return { sent: true, testMode: true, mailOptions };
    }

    const result = await transporter.sendMail(mailOptions);
    
    return {
      sent: true,
      messageId: result.messageId,
      subject: subject,
      to: userData.email
    };

  } catch (error) {
    console.error('Error enviando email:', error);
    return {
      sent: false,
      error: error.message
    };
  }
}

/**
 * Función auxiliar para enviar mensaje in-app
 */
async function sendInAppMessage(userId, variant, messageData, testMode) {
  try {
    let message = {
      title: variant.title || '',
      content: variant.content || '',
      cta: variant.cta || '',
      style: variant.style || {},
      type: 'ab_test',
      variantId: variant.id,
      ...messageData
    };

    // Reemplazar placeholders
    if (messageData) {
      message.title = replacePlaceholders(message.title, messageData);
      message.content = replacePlaceholders(message.content, messageData);
      message.cta = replacePlaceholders(message.cta, messageData);
    }

    if (testMode) {
      console.log('MODO TEST - In-app message:', message);
      return { sent: true, testMode: true, message };
    }

    // Guardar mensaje in-app en Firestore
    await db.collection('users').doc(userId).collection('inAppMessages').add({
      ...message,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
      displayed: false
    });

    return {
      sent: true,
      title: message.title,
      content: message.content
    };

  } catch (error) {
    console.error('Error enviando in-app message:', error);
    return {
      sent: false,
      error: error.message
    };
  }
}

/**
 * Función auxiliar para enviar SMS
 */
async function sendSMS(userData, variant, messageData, testMode) {
  try {
    if (!userData.phoneNumber) {
      throw new Error('Usuario sin número de teléfono');
    }

    let message = variant.content || variant.text || '';

    // Reemplazar placeholders
    if (messageData) {
      message = replacePlaceholders(message, messageData);
    }

    if (testMode) {
      console.log('MODO TEST - SMS:', { to: userData.phoneNumber, message });
      return { sent: true, testMode: true, message, to: userData.phoneNumber };
    }

    // Aquí integrarías con tu proveedor de SMS (Twilio, AWS SNS, etc.)
    // Por ahora simular el envío
    console.log(`SMS enviado a ${userData.phoneNumber}: ${message}`);

    return {
      sent: true,
      message: message,
      to: userData.phoneNumber
    };

  } catch (error) {
    console.error('Error enviando SMS:', error);
    return {
      sent: false,
      error: error.message
    };
  }
}

/**
 * Registrar evento de interacción con mensaje
 */
exports.trackMessageInteraction = functions
  .runWith({
    timeoutSeconds: 60,
    memory: '256MB'
  })
  .https.onCall(async (data, context) => {
    try {
      if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
      }

      const {
        experimentId,
        userId,
        eventType, // opened, clicked, converted, unsubscribed
        eventData
      } = data;

      const targetUserId = userId || context.auth.uid;

      // Verificar asignación del usuario
      const assignmentDoc = await db.collection('messageABTests')
        .doc(experimentId)
        .collection('userAssignments')
        .doc(targetUserId)
        .get();

      if (!assignmentDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Usuario no asignado a experimento');
      }

      const assignment = assignmentDoc.data();

      // Registrar evento
      await db.collection('messageABTests')
        .doc(experimentId)
        .collection('events')
        .add({
          type: eventType,
          userId: targetUserId,
          variantId: assignment.variantId,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          eventData: eventData || {}
        });

      console.log(`Evento de mensaje registrado: ${eventType} - Usuario: ${targetUserId}, Variante: ${assignment.variantId}`);

      return {
        success: true,
        message: 'Evento registrado exitosamente'
      };

    } catch (error) {
      console.error('Error registrando evento de mensaje:', error);
      throw new functions.https.HttpsError('internal', 'Error interno del servidor');
    }
  });

/**
 * Analizar resultados de experimento de mensajes
 */
exports.analyzeMessageABTestResults = functions
  .runWith({
    timeoutSeconds: 300,
    memory: '1GB'
  })
  .https.onCall(async (data, context) => {
    try {
      if (!context.auth || !context.auth.token.admin) {
        throw new functions.https.HttpsError('permission-denied', 'Requiere permisos de administrador');
      }

      const { experimentId } = data;

      const experimentDoc = await db.collection('messageABTests').doc(experimentId).get();
      if (!experimentDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Experimento no encontrado');
      }

      const experiment = experimentDoc.data();

      // Obtener todos los eventos
      const eventsSnapshot = await db.collection('messageABTests')
        .doc(experimentId)
        .collection('events')
        .get();

      const events = [];
      eventsSnapshot.forEach(doc => {
        if (doc.id !== '_init') {
          events.push({ id: doc.id, ...doc.data() });
        }
      });

      // Calcular métricas por variante
      const variantMetrics = {};
      
      experiment.variants.forEach(variant => {
        variantMetrics[variant.id] = {
          variantId: variant.id,
          name: variant.title || variant.subject || `Variante ${variant.id}`,
          messagesSent: 0,
          opened: 0,
          clicked: 0,
          converted: 0,
          unsubscribed: 0,
          openRate: 0,
          clickRate: 0,
          conversionRate: 0,
          unsubscribeRate: 0
        };
      });

      // Procesar eventos
      events.forEach(event => {
        const variantId = event.variantId;
        if (!variantMetrics[variantId]) return;

        switch (event.type) {
          case 'message_sent':
            variantMetrics[variantId].messagesSent++;
            break;
          case 'opened':
            variantMetrics[variantId].opened++;
            break;
          case 'clicked':
            variantMetrics[variantId].clicked++;
            break;
          case 'converted':
            variantMetrics[variantId].converted++;
            break;
          case 'unsubscribed':
            variantMetrics[variantId].unsubscribed++;
            break;
        }
      });

      // Calcular tasas
      Object.values(variantMetrics).forEach(metrics => {
        if (metrics.messagesSent > 0) {
          metrics.openRate = (metrics.opened / metrics.messagesSent) * 100;
          metrics.clickRate = (metrics.clicked / metrics.messagesSent) * 100;
          metrics.conversionRate = (metrics.converted / metrics.messagesSent) * 100;
          metrics.unsubscribeRate = (metrics.unsubscribed / metrics.messagesSent) * 100;
        }
      });

      // Análisis estadístico
      const statisticalAnalysis = performStatisticalAnalysis(variantMetrics, experiment.metrics);

      // Actualizar resultados en el experimento
      await db.collection('messageABTests').doc(experimentId).update({
        'results.lastAnalysis': admin.firestore.FieldValue.serverTimestamp(),
        'results.variantMetrics': variantMetrics,
        'results.statistical_significance': statisticalAnalysis.isSignificant,
        'results.confidence_level': statisticalAnalysis.confidenceLevel,
        'results.winner': statisticalAnalysis.winner,
        'results.analysis': statisticalAnalysis
      });

      return {
        success: true,
        results: {
          variantMetrics: Object.values(variantMetrics),
          statisticalAnalysis: statisticalAnalysis,
          totalEvents: events.length,
          analysisDate: new Date().toISOString()
        }
      };

    } catch (error) {
      console.error('Error analizando resultados:', error);
      throw new functions.https.HttpsError('internal', 'Error interno del servidor');
    }
  });

/**
 * Función auxiliar para análisis estadístico
 */
function performStatisticalAnalysis(variantMetrics, metrics) {
  const variants = Object.values(variantMetrics);
  
  if (variants.length < 2) {
    return {
      isSignificant: false,
      confidenceLevel: 0,
      winner: null,
      pValue: null,
      message: 'Se necesitan al menos 2 variantes para análisis'
    };
  }

  // Usar la métrica principal (primera en la lista o conversion rate por defecto)
  const primaryMetric = metrics && metrics.length > 0 ? metrics[0] : 'conversion_rate';
  const metricKey = primaryMetric === 'open_rate' ? 'openRate' :
                   primaryMetric === 'click_rate' ? 'clickRate' :
                   primaryMetric === 'conversion_rate' ? 'conversionRate' :
                   'openRate';

  // Encontrar la variante con mejor performance
  let bestVariant = variants[0];
  variants.forEach(variant => {
    if (variant[metricKey] > bestVariant[metricKey]) {
      bestVariant = variant;
    }
  });

  // Test de significancia estadística simple (z-test)
  const controlVariant = variants[0];
  const testVariant = bestVariant.variantId === controlVariant.variantId ? variants[1] : bestVariant;

  if (controlVariant.messagesSent < 30 || testVariant.messagesSent < 30) {
    return {
      isSignificant: false,
      confidenceLevel: 0,
      winner: null,
      pValue: null,
      message: 'Muestra insuficiente para análisis estadístico (mínimo 30 por variante)'
    };
  }

  // Calcular z-score
  const p1 = controlVariant[metricKey] / 100;
  const p2 = testVariant[metricKey] / 100;
  const n1 = controlVariant.messagesSent;
  const n2 = testVariant.messagesSent;

  const pooledP = ((p1 * n1) + (p2 * n2)) / (n1 + n2);
  const standardError = Math.sqrt(pooledP * (1 - pooledP) * ((1/n1) + (1/n2)));
  
  const zScore = Math.abs(p2 - p1) / standardError;
  const pValue = 2 * (1 - normalCDF(Math.abs(zScore))); // Two-tailed test

  const isSignificant = pValue < 0.05;
  const confidenceLevel = (1 - pValue) * 100;

  return {
    isSignificant,
    confidenceLevel: Math.min(confidenceLevel, 99.9),
    winner: isSignificant ? bestVariant.variantId : null,
    pValue,
    zScore,
    metric: primaryMetric,
    controlRate: controlVariant[metricKey],
    testRate: testVariant[metricKey],
    improvement: testVariant[metricKey] - controlVariant[metricKey],
    improvementPercent: ((testVariant[metricKey] - controlVariant[metricKey]) / controlVariant[metricKey]) * 100,
    message: isSignificant ? 
      `Diferencia estadísticamente significativa detectada (p=${pValue.toFixed(4)})` :
      `No hay diferencia estadísticamente significativa (p=${pValue.toFixed(4)})`
  };
}

/**
 * Función auxiliar para calcular CDF normal
 */
function normalCDF(x) {
  const a1 =  0.254829592;
  const a2 = -0.284496736;
  const a3 =  1.421413741;
  const a4 = -1.453152027;
  const a5 =  1.061405429;
  const p  =  0.3275911;

  const sign = x < 0 ? -1 : 1;
  x = Math.abs(x) / Math.sqrt(2.0);

  const t = 1.0 / (1.0 + p * x);
  const y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * Math.exp(-x * x);

  return 0.5 * (1.0 + sign * y);
}

/**
 * Función auxiliar para reemplazar placeholders
 */
function replacePlaceholders(text, data) {
  if (!text || !data) return text;
  
  let result = text;
  Object.keys(data).forEach(key => {
    const regex = new RegExp(`{${key}}`, 'g');
    result = result.replace(regex, data[key]);
  });
  
  return result;
}

/**
 * Obtener plantillas de mensaje predefinidas
 */
exports.getMessageTemplates = functions
  .runWith({
    timeoutSeconds: 60,
    memory: '256MB'
  })
  .https.onCall(async (data, context) => {
    try {
      if (!context.auth || !context.auth.token.admin) {
        throw new functions.https.HttpsError('permission-denied', 'Requiere permisos de administrador');
      }

      const { messageType, templateCategory } = data;

      if (messageType && !Object.values(MESSAGE_EXPERIMENT_CONFIGS.types).includes(messageType)) {
        throw new functions.https.HttpsError('invalid-argument', 'Tipo de mensaje no válido');
      }

      let templates = MESSAGE_TEMPLATES;

      if (messageType) {
        templates = MESSAGE_TEMPLATES[messageType] || {};
      }

      if (templateCategory) {
        templates = templates[templateCategory] || {};
      }

      return {
        success: true,
        templates: templates,
        messageTypes: Object.values(MESSAGE_EXPERIMENT_CONFIGS.types),
        availableMetrics: Object.values(MESSAGE_EXPERIMENT_CONFIGS.metrics),
        availableSegments: Object.values(MESSAGE_EXPERIMENT_CONFIGS.segments)
      };

    } catch (error) {
      console.error('Error obteniendo plantillas:', error);
      throw new functions.https.HttpsError('internal', 'Error interno del servidor');
    }
  });

/**
 * Finalizar experimento automáticamente
 */
exports.finalizeExpiredMessageTests = functions
  .runWith({
    timeoutSeconds: 300,
    memory: '512MB'
  })
  .pubsub.schedule('0 */6 * * *') // Cada 6 horas
  .timeZone('America/Lima')
  .onRun(async (context) => {
    try {
      const now = admin.firestore.Timestamp.now();

      // Buscar experimentos activos que han expirado
      const expiredTestsSnapshot = await db.collection('messageABTests')
        .where('status', '==', 'active')
        .where('endDate', '<=', now)
        .get();

      console.log(`Encontrados ${expiredTestsSnapshot.size} experimentos expirados`);

      const promises = [];

      expiredTestsSnapshot.forEach(doc => {
        const experimentId = doc.id;
        
        promises.push(
          doc.ref.update({
            status: 'completed',
            completedAt: admin.firestore.FieldValue.serverTimestamp()
          }).then(() => {
            console.log(`Experimento finalizado: ${experimentId}`);
            
            // Realizar análisis final
            return analyzeMessageABTestResults({ experimentId }, { auth: { token: { admin: true } } });
          })
        );
      });

      await Promise.all(promises);

      console.log('Finalización automática de experimentos completada');

    } catch (error) {
      console.error('Error finalizando experimentos automáticamente:', error);
    }
  });

/**
 * Generar reporte de experimentos de mensajes
 */
exports.generateMessageABTestReport = functions
  .runWith({
    timeoutSeconds: 300,
    memory: '1GB'
  })
  .https.onCall(async (data, context) => {
    try {
      if (!context.auth || !context.auth.token.admin) {
        throw new functions.https.HttpsError('permission-denied', 'Requiere permisos de administrador');
      }

      const { 
        startDate, 
        endDate, 
        includeActive = true, 
        includeCompleted = true 
      } = data;

      let query = db.collection('messageABTests');

      // Filtros de estado
      const statuses = [];
      if (includeActive) statuses.push('active');
      if (includeCompleted) statuses.push('completed');

      if (statuses.length > 0) {
        query = query.where('status', 'in', statuses);
      }

      // Filtros de fecha
      if (startDate) {
        query = query.where('createdAt', '>=', admin.firestore.Timestamp.fromDate(new Date(startDate)));
      }

      if (endDate) {
        query = query.where('createdAt', '<=', admin.firestore.Timestamp.fromDate(new Date(endDate)));
      }

      const experimentsSnapshot = await query.get();
      
      const reportData = {
        summary: {
          totalExperiments: experimentsSnapshot.size,
          activeExperiments: 0,
          completedExperiments: 0,
          totalUsersInExperiments: 0,
          totalMessagesSent: 0
        },
        experiments: [],
        generatedAt: new Date().toISOString()
      };

      for (const doc of experimentsSnapshot.docs) {
        const experiment = doc.data();
        
        if (experiment.status === 'active') {
          reportData.summary.activeExperiments++;
        } else if (experiment.status === 'completed') {
          reportData.summary.completedExperiments++;
        }

        reportData.summary.totalUsersInExperiments += experiment.totalUsers || 0;

        // Obtener métricas detalladas si están disponibles
        let detailedMetrics = null;
        if (experiment.results && experiment.results.variantMetrics) {
          detailedMetrics = experiment.results.variantMetrics;
          
          Object.values(detailedMetrics).forEach(variant => {
            reportData.summary.totalMessagesSent += variant.messagesSent || 0;
          });
        }

        reportData.experiments.push({
          id: doc.id,
          name: experiment.name,
          messageType: experiment.messageType,
          status: experiment.status,
          createdAt: experiment.createdAt?.toDate().toISOString(),
          startDate: experiment.startDate?.toDate().toISOString(),
          endDate: experiment.endDate?.toDate().toISOString(),
          totalUsers: experiment.totalUsers || 0,
          variants: experiment.variants?.map(v => ({
            id: v.id,
            assignedUsers: v.assignedUsers || 0
          })) || [],
          metrics: detailedMetrics,
          winner: experiment.results?.winner,
          isSignificant: experiment.results?.statistical_significance || false,
          confidenceLevel: experiment.results?.confidence_level || 0
        });
      }

      return {
        success: true,
        report: reportData
      };

    } catch (error) {
      console.error('Error generando reporte:', error);
      throw new functions.https.HttpsError('internal', 'Error interno del servidor');
    }
  });

module.exports = {
  MESSAGE_EXPERIMENT_CONFIGS,
  MESSAGE_TEMPLATES
};