const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Inicializar Firebase Admin SDK si no está ya inicializado
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Cloud Function para manejar campañas de notificaciones
 * Ejecutada por Cloud Scheduler para diferentes tipos de campañas
 * 
 * Características:
 * - Segmentación avanzada de usuarios
 * - Personalización de contenido
 * - A/B Testing integrado
 * - Análisis de engagement
 * - Respeto por preferencias de usuario
 * - Gamificación y recompensas
 */
exports.processCampaign = functions
  .runWith({
    timeoutSeconds: 540, // 9 minutos
    memory: '2GB'
  })
  .pubsub
  .topic('notification-campaigns')
  .onPublish(async (message, context) => {
    const startTime = Date.now();
    
    try {
      // Decodificar mensaje de Cloud Scheduler
      const campaignData = message.json;
      const campaignType = campaignData.campaignType;
      
      console.log(`🚀 Procesando campaña: ${campaignType}`);
      
      // Procesar según tipo de campaña
      let result;
      switch (campaignType) {
        case 'weekly_promo':
          result = await processWeeklyPromoCampaign(campaignData);
          break;
          
        case 'user_reactivation':
          result = await processUserReactivationCampaign(campaignData);
          break;
          
        case 'driver_maintenance':
          result = await processDriverMaintenanceCampaign(campaignData);
          break;
          
        case 'special_events':
          result = await processSpecialEventsCampaign(campaignData);
          break;
          
        case 'rating_feedback':
          result = await processRatingFeedbackCampaign(campaignData);
          break;
          
        case 'personalized_segments':
          result = await processPersonalizedSegmentsCampaign(campaignData);
          break;
          
        case 'emergency_alerts':
          result = await processEmergencyAlertsCampaign(campaignData);
          break;
          
        default:
          throw new Error(`Tipo de campaña no soportado: ${campaignType}`);
      }
      
      // Registrar estadísticas de campaña
      const executionTime = Date.now() - startTime;
      const campaignStats = {
        campaignType,
        executionTime,
        result,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      };
      
      await db.collection('campaign_stats').add(campaignStats);
      
      console.log(`✅ Campaña ${campaignType} completada:`, result);
      
      return {
        success: true,
        campaignType,
        stats: result
      };
      
    } catch (error) {
      console.error('❌ Error procesando campaña:', error);
      
      // Registrar error
      await db.collection('campaign_errors').add({
        error: error.message,
        stack: error.stack,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        executionTime: Date.now() - startTime
      });
      
      throw error;
    }
  });

/**
 * Campaña promocional semanal
 */
async function processWeeklyPromoCampaign(campaignData) {
  try {
    console.log('📢 Procesando campaña promocional semanal...');
    
    // Obtener usuarios activos elegibles
    const usersQuery = await db.collection('users')
      .where('userType', '==', 'passenger')
      .where('isActive', '==', true)
      .where('lastTripDate', '>', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)) // últimos 30 días
      .get();
    
    console.log(`👥 ${usersQuery.docs.length} usuarios elegibles encontrados`);
    
    // Filtrar usuarios que no han optado out
    const eligibleUsers = [];
    for (const userDoc of usersQuery.docs) {
      const userData = userDoc.data();
      const preferences = userData.notificationPreferences || {};
      
      if (preferences.promoNotifications !== false) {
        eligibleUsers.push({
          uid: userDoc.id,
          ...userData
        });
      }
    }
    
    console.log(`✅ ${eligibleUsers.length} usuarios después de filtrar preferencias`);
    
    // A/B Testing para título de notificación
    const titleVariants = [
      "¡Ofertas especiales esta semana! 🚖✨",
      "¡Descuentos increíbles te esperan! 💰",
      "¡No te pierdas estas promociones! 🎉"
    ];
    
    // Personalizar y enviar notificaciones
    const notifications = [];
    const batchSize = 500; // FCM limit
    
    for (let i = 0; i < eligibleUsers.length; i += batchSize) {
      const batch = eligibleUsers.slice(i, i + batchSize);
      
      for (const user of batch) {
        // Seleccionar variante A/B
        const variantIndex = i % titleVariants.length;
        const title = titleVariants[variantIndex];
        
        // Personalizar contenido
        const personalizedContent = personalizePromoContent(user, campaignData.content);
        
        // Crear token de FCM
        if (user.fcmTokens && user.fcmTokens.length > 0) {
          for (const token of user.fcmTokens) {
            notifications.push({
              token: token,
              notification: {
                title: title,
                body: personalizedContent.body,
                imageUrl: campaignData.content.imageUrl
              },
              data: {
                type: 'promo_campaign',
                actionUrl: campaignData.content.actionUrl,
                promoCode: campaignData.content.promoCode,
                userId: user.uid,
                campaignId: `weekly_promo_${Date.now()}`,
                abVariant: `variant_${variantIndex + 1}`
              },
              android: {
                notification: {
                  channelId: 'promotions',
                  priority: 'high',
                  defaultSound: true,
                  defaultVibrateTimings: true
                }
              },
              apns: {
                payload: {
                  aps: {
                    category: 'PROMO_CATEGORY',
                    sound: 'default'
                  }
                }
              }
            });
          }
        }
      }
    }
    
    // Enviar notificaciones en lotes
    let sentCount = 0;
    let failedCount = 0;
    
    for (let i = 0; i < notifications.length; i += batchSize) {
      const batch = notifications.slice(i, i + batchSize);
      
      try {
        const response = await messaging.sendAll(batch);
        sentCount += response.successCount;
        failedCount += response.failureCount;
        
        // Log errores específicos
        response.responses.forEach((resp, index) => {
          if (!resp.success) {
            console.warn(`Error enviando notificación ${i + index}:`, resp.error);
          }
        });
        
      } catch (batchError) {
        console.error(`Error enviando lote ${i}:`, batchError);
        failedCount += batch.length;
      }
    }
    
    // Registrar métricas de campaña
    await db.collection('campaign_metrics').add({
      campaignType: 'weekly_promo',
      targetUsers: eligibleUsers.length,
      notificationsSent: sentCount,
      notificationsFailed: failedCount,
      successRate: sentCount / (sentCount + failedCount),
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
    
    return {
      targetUsers: eligibleUsers.length,
      notificationsSent: sentCount,
      notificationsFailed: failedCount,
      successRate: (sentCount / (sentCount + failedCount) * 100).toFixed(2) + '%'
    };
    
  } catch (error) {
    console.error('Error en campaña promocional semanal:', error);
    throw error;
  }
}

/**
 * Campaña de reactivación de usuarios inactivos
 */
async function processUserReactivationCampaign(campaignData) {
  try {
    console.log('💤 Procesando campaña de reactivación...');
    
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const ninetyDaysAgo = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);
    
    // Usuarios inactivos pero no perdidos
    const inactiveUsersQuery = await db.collection('users')
      .where('userType', '==', 'passenger')
      .where('lastTripDate', '<=', thirtyDaysAgo)
      .where('lastTripDate', '>', ninetyDaysAgo)
      .where('totalTrips', '>=', 3) // Han usado el servicio antes
      .get();
    
    console.log(`😴 ${inactiveUsersQuery.docs.length} usuarios inactivos encontrados`);
    
    const reactivationNotifications = [];
    
    for (const userDoc of inactiveUsersQuery.docs) {
      const userData = userDoc.data();
      const preferences = userData.notificationPreferences || {};
      
      // Respetar preferencias de usuario
      if (preferences.reactivationNotifications === false) continue;
      
      // Personalizar mensaje de reactivación
      const personalizedMessage = personalizeReactivationMessage(userData);
      
      if (userData.fcmTokens && userData.fcmTokens.length > 0) {
        for (const token of userData.fcmTokens) {
          reactivationNotifications.push({
            token: token,
            notification: {
              title: "Te extrañamos en OasisTaxi 😢",
              body: personalizedMessage,
              imageUrl: campaignData.content.imageUrl
            },
            data: {
              type: 'reactivation_campaign',
              actionUrl: campaignData.content.actionUrl,
              promoCode: campaignData.content.promoCode,
              userId: userData.uid || userDoc.id,
              campaignId: `reactivation_${Date.now()}`
            }
          });
        }
      }
    }
    
    // Enviar notificaciones de reactivación
    let sentCount = 0;
    const batchSize = 500;
    
    for (let i = 0; i < reactivationNotifications.length; i += batchSize) {
      const batch = reactivationNotifications.slice(i, i + batchSize);
      
      try {
        const response = await messaging.sendAll(batch);
        sentCount += response.successCount;
      } catch (error) {
        console.error(`Error enviando lote reactivación ${i}:`, error);
      }
    }
    
    return {
      inactiveUsersFound: inactiveUsersQuery.docs.length,
      reactivationMessagesSent: sentCount
    };
    
  } catch (error) {
    console.error('Error en campaña de reactivación:', error);
    throw error;
  }
}

/**
 * Campaña de recordatorios de mantenimiento para conductores
 */
async function processDriverMaintenanceCampaign(campaignData) {
  try {
    console.log('🔧 Procesando recordatorios de mantenimiento...');
    
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    
    // Conductores activos
    const driversQuery = await db.collection('users')
      .where('userType', '==', 'driver')
      .where('isActive', '==', true)
      .where('lastTripDate', '>', sevenDaysAgo)
      .get();
    
    const maintenanceReminders = [];
    let urgentCount = 0;
    
    for (const driverDoc of driversQuery.docs) {
      const driverData = driverDoc.data();
      const documents = driverData.documents || {};
      
      // Verificar documentos próximos a vencer
      const urgentDocuments = checkDocumentExpiry(documents);
      const isUrgent = urgentDocuments.length > 0;
      
      if (isUrgent) urgentCount++;
      
      // Personalizar mensaje según urgencia
      const message = isUrgent 
        ? `⚠️ URGENTE: ${urgentDocuments.join(', ')} vence(n) pronto`
        : "Recordatorio mensual: Revisa que tus documentos estén vigentes";
      
      if (driverData.fcmTokens && driverData.fcmTokens.length > 0) {
        for (const token of driverData.fcmTokens) {
          maintenanceReminders.push({
            token: token,
            notification: {
              title: isUrgent ? "Documentos por vencer ⚠️" : "Recordatorio de mantenimiento 🔧",
              body: message,
              imageUrl: campaignData.content.imageUrl
            },
            data: {
              type: 'maintenance_reminder',
              actionUrl: campaignData.content.actionUrl,
              urgentDocuments: JSON.stringify(urgentDocuments),
              driverId: driverData.uid || driverDoc.id,
              isUrgent: isUrgent.toString()
            },
            android: {
              notification: {
                priority: isUrgent ? 'max' : 'high',
                channelId: isUrgent ? 'urgent_alerts' : 'maintenance'
              }
            }
          });
        }
      }
    }
    
    // Enviar recordatorios
    let sentCount = 0;
    const batchSize = 500;
    
    for (let i = 0; i < maintenanceReminders.length; i += batchSize) {
      const batch = maintenanceReminders.slice(i, i + batchSize);
      
      try {
        const response = await messaging.sendAll(batch);
        sentCount += response.successCount;
      } catch (error) {
        console.error(`Error enviando recordatorios ${i}:`, error);
      }
    }
    
    return {
      driversContacted: driversQuery.docs.length,
      urgentCases: urgentCount,
      remindersSent: sentCount
    };
    
  } catch (error) {
    console.error('Error en campaña de mantenimiento:', error);
    throw error;
  }
}

/**
 * Campaña de eventos especiales
 */
async function processSpecialEventsCampaign(campaignData) {
  try {
    console.log('🎉 Procesando campaña de eventos especiales...');
    
    const today = new Date();
    const todayString = today.toISOString().split('T')[0];
    
    // Verificar eventos para hoy
    let eventToday = null;
    let eventType = null;
    
    // Revisar eventos nacionales
    for (const event of campaignData.eventTypes[0].events) {
      if (event.date === todayString) {
        eventToday = event;
        eventType = 'holiday';
        break;
      }
    }
    
    // Si no hay evento nacional, revisar eventos locales
    if (!eventToday) {
      for (const event of campaignData.eventTypes[1].events) {
        if (event.date === todayString) {
          eventToday = event;
          eventType = 'local_event';
          break;
        }
      }
    }
    
    // Si no hay eventos programados, verificar alertas climáticas
    if (!eventToday) {
      const weatherAlert = await checkWeatherConditions();
      if (weatherAlert) {
        eventToday = weatherAlert;
        eventType = 'weather';
      }
    }
    
    if (!eventToday) {
      console.log('ℹ️ No hay eventos especiales para hoy');
      return { eventsToday: 0, notificationsSent: 0 };
    }
    
    console.log(`🎯 Evento detectado: ${eventToday.name || eventToday.condition}`);
    
    // Obtener usuarios activos
    const usersQuery = await db.collection('users')
      .where('isActive', '==', true)
      .get();
    
    const eventNotifications = [];
    
    for (const userDoc of usersQuery.docs) {
      const userData = userDoc.data();
      
      // Filtrar por área si es evento local
      if (eventType === 'local_event' && eventToday.areas) {
        const userArea = userData.preferredArea || userData.lastKnownArea;
        if (!eventToday.areas.includes(userArea)) continue;
      }
      
      const content = campaignData.content[eventType];
      let message = content.body;
      
      // Personalizar mensaje
      if (eventType === 'holiday') {
        message = content.body.replace('{holiday_name}', eventToday.name);
      } else if (eventType === 'weather') {
        message = `${content.body}. Condición: ${eventToday.condition}`;
      }
      
      if (userData.fcmTokens && userData.fcmTokens.length > 0) {
        for (const token of userData.fcmTokens) {
          eventNotifications.push({
            token: token,
            notification: {
              title: content.title.replace('{holiday_name}', eventToday.name || ''),
              body: message
            },
            data: {
              type: 'special_event',
              eventType: eventType,
              actionUrl: content.actionUrl,
              eventName: eventToday.name || eventToday.condition,
              surge: eventToday.surge ? eventToday.surge.toString() : '1.0'
            }
          });
        }
      }
    }
    
    // Enviar notificaciones de evento
    let sentCount = 0;
    const batchSize = 500;
    
    for (let i = 0; i < eventNotifications.length; i += batchSize) {
      const batch = eventNotifications.slice(i, i + batchSize);
      
      try {
        const response = await messaging.sendAll(batch);
        sentCount += response.successCount;
      } catch (error) {
        console.error(`Error enviando notificaciones evento ${i}:`, error);
      }
    }
    
    return {
      eventName: eventToday.name || eventToday.condition,
      eventType: eventType,
      targetUsers: usersQuery.docs.length,
      notificationsSent: sentCount
    };
    
  } catch (error) {
    console.error('Error en campaña de eventos especiales:', error);
    throw error;
  }
}

/**
 * Campaña de rating y feedback
 */
async function processRatingFeedbackCampaign(campaignData) {
  try {
    console.log('⭐ Procesando campaña de rating y feedback...');
    
    const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const today = new Date();
    
    // Obtener viajes completados sin rating en las últimas 24 horas
    const unratedTripsQuery = await db.collection('trips')
      .where('status', '==', 'completed')
      .where('completedAt', '>=', admin.firestore.Timestamp.fromDate(yesterday))
      .where('completedAt', '<=', admin.firestore.Timestamp.fromDate(today))
      .where('hasRating', '==', false)
      .get();
    
    console.log(`📊 ${unratedTripsQuery.docs.length} viajes sin rating encontrados`);
    
    const ratingReminders = [];
    const processedUsers = new Set(); // Evitar spam al mismo usuario
    
    for (const tripDoc of unratedTripsQuery.docs) {
      const tripData = tripDoc.data();
      const passengerId = tripData.passengerId;
      
      // Evitar múltiples notificaciones al mismo usuario
      if (processedUsers.has(passengerId)) continue;
      processedUsers.add(passengerId);
      
      // Obtener datos del usuario
      const userDoc = await db.collection('users').doc(passengerId).get();
      const userData = userDoc.data();
      
      if (!userData || !userData.fcmTokens) continue;
      
      // Verificar si ya se notificó sobre rating hoy
      const lastRatingNotification = userData.lastRatingNotification;
      if (lastRatingNotification && lastRatingNotification.toDate() > yesterday) continue;
      
      const content = campaignData.content.rating_reminder;
      
      for (const token of userData.fcmTokens) {
        ratingReminders.push({
          token: token,
          notification: {
            title: content.title,
            body: content.body
          },
          data: {
            type: 'rating_reminder',
            actionUrl: content.actionUrl.replace('{trip_id}', tripDoc.id),
            tripId: tripDoc.id,
            driverId: tripData.driverId,
            incentivePoints: campaignData.incentives.ratingReward.points.toString(),
            incentiveDiscount: campaignData.incentives.ratingReward.discount
          }
        });
      }
      
      // Actualizar última notificación de rating
      await db.collection('users').doc(passengerId).update({
        lastRatingNotification: admin.firestore.FieldValue.serverTimestamp()
      });
    }
    
    // Enviar recordatorios de rating
    let sentCount = 0;
    const batchSize = 500;
    
    for (let i = 0; i < ratingReminders.length; i += batchSize) {
      const batch = ratingReminders.slice(i, i + batchSize);
      
      try {
        const response = await messaging.sendAll(batch);
        sentCount += response.successCount;
      } catch (error) {
        console.error(`Error enviando recordatorios rating ${i}:`, error);
      }
    }
    
    return {
      unratedTrips: unratedTripsQuery.docs.length,
      uniqueUsers: processedUsers.size,
      ratingRemindersSent: sentCount
    };
    
  } catch (error) {
    console.error('Error en campaña de rating:', error);
    throw error;
  }
}

/**
 * Campaña personalizada por segmentos
 */
async function processPersonalizedSegmentsCampaign(campaignData) {
  try {
    console.log('🎯 Procesando campañas personalizadas por segmentos...');
    
    const results = {};
    
    for (const segment of campaignData.segments) {
      console.log(`📊 Procesando segmento: ${segment.name}`);
      
      // Obtener usuarios que cumplen criterios del segmento
      const segmentUsers = await getUsersBySegmentCriteria(segment.criteria);
      console.log(`👥 ${segmentUsers.length} usuarios en segmento ${segment.name}`);
      
      const segmentNotifications = [];
      
      for (const user of segmentUsers) {
        if (!user.fcmTokens || user.fcmTokens.length === 0) continue;
        
        for (const token of user.fcmTokens) {
          segmentNotifications.push({
            token: token,
            notification: {
              title: segment.content.title,
              body: segment.content.body
            },
            data: {
              type: 'personalized_segment',
              segmentName: segment.name,
              promoCode: segment.content.promoCode,
              actionUrl: segment.content.actionUrl,
              userId: user.uid
            }
          });
        }
      }
      
      // Enviar notificaciones del segmento
      let sentCount = 0;
      const batchSize = 500;
      
      for (let i = 0; i < segmentNotifications.length; i += batchSize) {
        const batch = segmentNotifications.slice(i, i + batchSize);
        
        try {
          const response = await messaging.sendAll(batch);
          sentCount += response.successCount;
        } catch (error) {
          console.error(`Error enviando segmento ${segment.name} lote ${i}:`, error);
        }
      }
      
      results[segment.name] = {
        targetUsers: segmentUsers.length,
        notificationsSent: sentCount
      };
    }
    
    return results;
    
  } catch (error) {
    console.error('Error en campañas personalizadas:', error);
    throw error;
  }
}

/**
 * Campaña de alertas de emergencia
 */
async function processEmergencyAlertsCampaign(campaignData) {
  try {
    console.log('🚨 Verificando alertas de emergencia...');
    
    const alerts = [];
    
    // Verificar diferentes tipos de alertas
    for (const alertType of campaignData.alertTypes) {
      const activeAlerts = await checkAlertConditions(alertType);
      
      if (activeAlerts.length > 0) {
        alerts.push(...activeAlerts.map(alert => ({
          ...alert,
          type: alertType.type,
          content: alertType.content
        })));
      }
    }
    
    if (alerts.length === 0) {
      console.log('✅ No hay alertas de emergencia activas');
      return { alertsActive: 0, notificationsSent: 0 };
    }
    
    console.log(`⚠️ ${alerts.length} alertas activas encontradas`);
    
    let totalSent = 0;
    
    for (const alert of alerts) {
      const targetUsers = await getTargetUsersForAlert(alert);
      const emergencyNotifications = [];
      
      for (const user of targetUsers) {
        if (!user.fcmTokens) continue;
        
        for (const token of user.fcmTokens) {
          emergencyNotifications.push({
            token: token,
            notification: {
              title: alert.content.title,
              body: alert.content.body.replace('{area_name}', alert.area || 'área afectada')
            },
            data: {
              type: 'emergency_alert',
              alertType: alert.type,
              actionUrl: alert.content.actionUrl,
              priority: alert.content.priority,
              alertId: alert.id
            },
            android: {
              notification: {
                priority: 'max',
                channelId: 'emergency_alerts',
                defaultSound: true,
                defaultVibrateTimings: true
              }
            }
          });
        }
      }
      
      // Enviar alertas con máxima prioridad
      const batchSize = 500;
      
      for (let i = 0; i < emergencyNotifications.length; i += batchSize) {
        const batch = emergencyNotifications.slice(i, i + batchSize);
        
        try {
          const response = await messaging.sendAll(batch);
          totalSent += response.successCount;
        } catch (error) {
          console.error(`Error enviando alertas emergencia ${i}:`, error);
        }
      }
    }
    
    return {
      alertsActive: alerts.length,
      alertTypes: alerts.map(a => a.type),
      notificationsSent: totalSent
    };
    
  } catch (error) {
    console.error('Error en alertas de emergencia:', error);
    throw error;
  }
}

// ═══════════════════════════════════════════════════════════════════
// FUNCIONES AUXILIARES
// ═══════════════════════════════════════════════════════════════════

/**
 * Personalizar contenido promocional
 */
function personalizePromoContent(user, baseContent) {
  let body = baseContent.body;
  
  // Personalización básica
  if (user.displayName) {
    body = `Hola ${user.displayName.split(' ')[0]}, ${body}`;
  }
  
  // Personalización por historial
  if (user.totalTrips > 50) {
    body += " Como usuario frecuente, tienes descuentos adicionales disponibles.";
  }
  
  return { body };
}

/**
 * Personalizar mensaje de reactivación
 */
function personalizeReactivationMessage(userData) {
  let message = "¡Vuelve y recibe S/ 10 de descuento en tu próximo viaje!";
  
  if (userData.favoriteRoute) {
    message += ` Tu ruta favorita ${userData.favoriteRoute} te está esperando.`;
  }
  
  if (userData.lastTripDate) {
    const daysSince = Math.floor((Date.now() - userData.lastTripDate.toDate()) / (24 * 60 * 60 * 1000));
    message = `Han pasado ${daysSince} días desde tu último viaje. ${message}`;
  }
  
  return message;
}

/**
 * Verificar vencimiento de documentos
 */
function checkDocumentExpiry(documents) {
  const urgentDocuments = [];
  const thirtyDaysFromNow = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
  
  if (documents.soat && documents.soat.expiryDate) {
    if (new Date(documents.soat.expiryDate) <= thirtyDaysFromNow) {
      urgentDocuments.push('SOAT');
    }
  }
  
  if (documents.license && documents.license.expiryDate) {
    if (new Date(documents.license.expiryDate) <= thirtyDaysFromNow) {
      urgentDocuments.push('Licencia');
    }
  }
  
  if (documents.technicalReview && documents.technicalReview.expiryDate) {
    if (new Date(documents.technicalReview.expiryDate) <= thirtyDaysFromNow) {
      urgentDocuments.push('Revisión Técnica');
    }
  }
  
  return urgentDocuments;
}

/**
 * Verificar condiciones climáticas
 */
async function checkWeatherConditions() {
  // En producción, integrar con API climática real
  // Por ahora, simulamos verificación
  
  try {
    // Simular consulta a API climática para Lima
    const simulatedWeatherAlert = Math.random() < 0.1; // 10% probabilidad
    
    if (simulatedWeatherAlert) {
      return {
        condition: 'lluvia_intensa',
        severity: 'medium',
        area: 'Lima Metropolitana'
      };
    }
    
    return null;
  } catch (error) {
    console.error('Error verificando clima:', error);
    return null;
  }
}

/**
 * Obtener usuarios por criterios de segmento
 */
async function getUsersBySegmentCriteria(criteria) {
  try {
    let query = db.collection('users').where('userType', '==', 'passenger');
    
    // Aplicar filtros según criterios
    if (criteria.tripsPerMonth) {
      query = query.where('monthlyTrips', '>=', criteria.tripsPerMonth);
    }
    
    const snapshot = await query.get();
    
    // Filtrado adicional en memoria para criterios complejos
    const users = [];
    for (const doc of snapshot.docs) {
      const userData = doc.data();
      
      // Verificar criterios adicionales
      if (meetsCriteria(userData, criteria)) {
        users.push({
          uid: doc.id,
          ...userData
        });
      }
    }
    
    return users;
  } catch (error) {
    console.error('Error obteniendo usuarios por segmento:', error);
    return [];
  }
}

/**
 * Verificar si usuario cumple criterios de segmento
 */
function meetsCriteria(userData, criteria) {
  // Implementar lógica de verificación de criterios
  if (criteria.averageDistance && userData.averageTripDistance < criteria.averageDistance) {
    return false;
  }
  
  if (criteria.preferredHours && userData.preferredTripHours) {
    const hasPreferredHour = criteria.preferredHours.some(hour => 
      userData.preferredTripHours.includes(hour)
    );
    if (!hasPreferredHour) return false;
  }
  
  return true;
}

/**
 * Verificar condiciones de alerta
 */
async function checkAlertConditions(alertType) {
  const alerts = [];
  
  try {
    switch (alertType.type) {
      case 'service_disruption':
        // Verificar estado del sistema
        const systemStatus = await checkSystemStatus();
        if (systemStatus.hasIssues) {
          alerts.push({
            id: `system_${Date.now()}`,
            issue: systemStatus.issue,
            severity: 'high'
          });
        }
        break;
        
      case 'security_alert':
        // Verificar alertas de seguridad
        const securityAlerts = await checkSecurityAlerts();
        alerts.push(...securityAlerts);
        break;
        
      case 'driver_sos':
        // Verificar botones SOS activos
        const sosAlerts = await checkSOSAlerts();
        alerts.push(...sosAlerts);
        break;
    }
  } catch (error) {
    console.error(`Error verificando alertas ${alertType.type}:`, error);
  }
  
  return alerts;
}

/**
 * Obtener usuarios objetivo para alerta
 */
async function getTargetUsersForAlert(alert) {
  try {
    let query = db.collection('users').where('isActive', '==', true);
    
    // Filtrar por área si es necesario
    if (alert.area) {
      query = query.where('currentArea', '==', alert.area);
    }
    
    const snapshot = await query.get();
    return snapshot.docs.map(doc => ({
      uid: doc.id,
      ...doc.data()
    }));
  } catch (error) {
    console.error('Error obteniendo usuarios para alerta:', error);
    return [];
  }
}

/**
 * Verificar estado del sistema
 */
async function checkSystemStatus() {
  // Implementar verificación real del sistema
  return { hasIssues: false, issue: null };
}

/**
 * Verificar alertas de seguridad
 */
async function checkSecurityAlerts() {
  // Implementar verificación de seguridad
  return [];
}

/**
 * Verificar alertas SOS
 */
async function checkSOSAlerts() {
  try {
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
    
    const sosQuery = await db.collection('emergency_alerts')
      .where('type', '==', 'sos')
      .where('createdAt', '>', admin.firestore.Timestamp.fromDate(fiveMinutesAgo))
      .where('status', '==', 'active')
      .get();
    
    return sosQuery.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
  } catch (error) {
    console.error('Error verificando SOS:', error);
    return [];
  }
}

module.exports = {
  processCampaign: exports.processCampaign
};