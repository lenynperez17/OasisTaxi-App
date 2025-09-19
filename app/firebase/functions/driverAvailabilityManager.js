const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Inicializar Firebase Admin SDK si no está ya inicializado
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Cloud Function para gestión automática de disponibilidad de conductores
 * Ejecutada por Cloud Scheduler para diferentes tipos de gestión de estado
 * 
 * Características:
 * - Auto-offline por inactividad
 * - Gestión por horarios nocturnos
 * - Reactivación inteligente
 * - Optimización por demanda
 * - Detección de app en background
 * - Gamificación y recompensas
 */
exports.manageDriverAvailability = functions
  .runWith({
    timeoutSeconds: 540, // 9 minutos
    memory: '2GB'
  })
  .pubsub
  .topic('driver-availability-management')
  .onPublish(async (message, context) => {
    const startTime = Date.now();
    
    try {
      // Decodificar mensaje de Cloud Scheduler
      const jobData = message.json;
      const jobType = jobData.jobType;
      
      console.log(`🚗 Procesando gestión de disponibilidad: ${jobType}`);
      
      // Procesar según tipo de job
      let result;
      switch (jobType) {
        case 'auto_offline_inactivity':
          result = await processAutoOfflineInactivity(jobData);
          break;
          
        case 'auto_offline_night_hours':
          result = await processAutoOfflineNightHours(jobData);
          break;
          
        case 'auto_reactivation_morning':
          result = await processAutoReactivationMorning(jobData);
          break;
          
        case 'availability_optimization':
          result = await processAvailabilityOptimization(jobData);
          break;
          
        case 'app_background_detection':
          result = await processAppBackgroundDetection(jobData);
          break;
          
        case 'status_cleanup':
          result = await processStatusCleanup(jobData);
          break;
          
        case 'availability_gamification':
          result = await processAvailabilityGamification(jobData);
          break;
          
        default:
          throw new Error(`Tipo de job no soportado: ${jobType}`);
      }
      
      // Registrar estadísticas de la operación
      const executionTime = Date.now() - startTime;
      const operationStats = {
        jobType,
        executionTime,
        result,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      };
      
      await db.collection('driver_availability_stats').add(operationStats);
      
      console.log(`✅ Gestión ${jobType} completada:`, result);
      
      return {
        success: true,
        jobType,
        stats: result
      };
      
    } catch (error) {
      console.error('❌ Error en gestión de disponibilidad:', error);
      
      // Registrar error
      await db.collection('driver_availability_errors').add({
        error: error.message,
        stack: error.stack,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        executionTime: Date.now() - startTime
      });
      
      throw error;
    }
  });

/**
 * Auto-offline por inactividad
 */
async function processAutoOfflineInactivity(jobData) {
  try {
    console.log('😴 Procesando auto-offline por inactividad...');
    
    const criteria = jobData.criteria;
    const inactivityThreshold = new Date(Date.now() - criteria.inactivityThresholdMinutes * 60 * 1000);
    const locationThreshold = new Date(Date.now() - criteria.lastLocationUpdateMinutes * 60 * 1000);
    
    // Obtener conductores online potencialmente inactivos
    const driversQuery = await db.collection('driver_availability')
      .where('isOnline', '==', true)
      .where('status', '!=', 'on_trip') // Ignorar conductores en viaje
      .where('lastActivity', '<=', admin.firestore.Timestamp.fromDate(inactivityThreshold))
      .get();
    
    console.log(`🔍 ${driversQuery.docs.length} conductores potencialmente inactivos encontrados`);
    
    const processedDrivers = [];
    const notifications = [];
    
    for (const driverDoc of driversQuery.docs) {
      const driverData = driverDoc.data();
      const driverId = driverDoc.id;
      
      // Verificaciones adicionales
      const isReallyInactive = await verifyDriverInactivity(driverId, driverData, {
        inactivityThreshold,
        locationThreshold
      });
      
      if (!isReallyInactive) {
        console.log(`⏭️ Conductor ${driverId} no cumple criterios de inactividad`);
        continue;
      }
      
      // Actualizar estado a offline
      await db.collection('driver_availability').doc(driverId).update({
        isOnline: false,
        status: 'offline',
        autoOfflineReason: 'inactivity',
        autoOfflineAt: admin.firestore.FieldValue.serverTimestamp(),
        lastStatusChange: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Preparar notificación
      const userData = await db.collection('users').doc(driverId).get();
      const userTokens = userData.data()?.fcmTokens;
      
      if (userTokens && userTokens.length > 0) {
        for (const token of userTokens) {
          notifications.push({
            token: token,
            notification: {
              title: jobData.notifications.title,
              body: jobData.notifications.body
            },
            data: {
              type: 'auto_offline',
              reason: 'inactivity',
              actionUrl: jobData.notifications.actionUrl,
              driverId: driverId,
              canReactivate: 'true'
            },
            android: {
              notification: {
                channelId: 'driver_status',
                priority: 'high',
                defaultSound: true
              }
            }
          });
        }
      }
      
      // Registrar evento de auditoría
      await db.collection('driver_activity_logs').add({
        driverId: driverId,
        event: 'auto_offline',
        reason: 'inactivity',
        previousStatus: driverData.status,
        inactivityDuration: Date.now() - driverData.lastActivity.toDate().getTime(),
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
      
      processedDrivers.push({
        driverId,
        previousStatus: driverData.status,
        inactivityMinutes: Math.floor((Date.now() - driverData.lastActivity.toDate().getTime()) / 60000)
      });
    }
    
    // Enviar notificaciones en lotes
    let sentNotifications = 0;
    if (notifications.length > 0) {
      const batchSize = 500;
      for (let i = 0; i < notifications.length; i += batchSize) {
        const batch = notifications.slice(i, i + batchSize);
        
        try {
          const response = await messaging.sendAll(batch);
          sentNotifications += response.successCount;
        } catch (error) {
          console.error(`Error enviando notificaciones lote ${i}:`, error);
        }
      }
    }
    
    return {
      driversProcessed: processedDrivers.length,
      driversSetOffline: processedDrivers.length,
      notificationsSent: sentNotifications,
      processedDrivers: processedDrivers
    };
    
  } catch (error) {
    console.error('Error en auto-offline por inactividad:', error);
    throw error;
  }
}

/**
 * Auto-offline durante horario nocturno
 */
async function processAutoOfflineNightHours(jobData) {
  try {
    console.log('🌙 Procesando auto-offline nocturno...');
    
    const timeWindow = jobData.timeWindow;
    const now = new Date();
    const currentHour = now.getHours();
    
    // Verificar si estamos en ventana nocturna
    const startHour = parseInt(timeWindow.startHour.split(':')[0]);
    const endHour = parseInt(timeWindow.endHour.split(':')[0]);
    
    if (currentHour < startHour || currentHour >= endHour) {
      console.log('⏭️ No estamos en horario nocturno, saltando...');
      return { driversProcessed: 0, message: 'Outside night window' };
    }
    
    // Obtener conductores online elegibles para auto-offline nocturno
    const driversQuery = await db.collection('driver_availability')
      .where('isOnline', '==', true)
      .where('status', '!=', 'on_trip')
      .get();
    
    console.log(`🌃 ${driversQuery.docs.length} conductores online durante horario nocturno`);
    
    const processedDrivers = [];
    const notifications = [];
    const reactivationSchedules = [];
    
    for (const driverDoc of driversQuery.docs) {
      const driverData = driverDoc.data();
      const driverId = driverDoc.id;
      
      // Verificar si el conductor está exento del auto-offline nocturno
      const isExempt = await checkNightShiftExemption(driverId, jobData.criteria);
      if (isExempt) {
        console.log(`⏭️ Conductor ${driverId} exento del auto-offline nocturno`);
        continue;
      }
      
      // Actualizar estado a offline con razón nocturna
      await db.collection('driver_availability').doc(driverId).update({
        isOnline: false,
        status: 'offline',
        autoOfflineReason: 'night_hours',
        autoOfflineAt: admin.firestore.FieldValue.serverTimestamp(),
        lastStatusChange: admin.firestore.FieldValue.serverTimestamp(),
        scheduledReactivation: calculateReactivationTime(timeWindow.endHour)
      });
      
      // Preparar notificación suave
      const userData = await db.collection('users').doc(driverId).get();
      const userTokens = userData.data()?.fcmTokens;
      
      if (userTokens && userTokens.length > 0) {
        for (const token of userTokens) {
          notifications.push({
            token: token,
            notification: {
              title: jobData.notifications.title,
              body: jobData.notifications.body
            },
            data: {
              type: 'auto_offline',
              reason: 'night_hours',
              actionUrl: jobData.notifications.actionUrl,
              reactivationTime: timeWindow.endHour,
              driverId: driverId
            },
            android: {
              notification: {
                channelId: 'driver_status',
                priority: 'default', // Menos intrusiva durante la noche
                defaultSound: false
              }
            }
          });
        }
      }
      
      // Programar reactivación automática
      if (jobData.reactivation && jobData.reactivation.scheduleReactivation) {
        reactivationSchedules.push({
          driverId: driverId,
          reactivationTime: calculateReactivationTime(jobData.reactivation.hour),
          reason: 'night_hours_end'
        });
      }
      
      processedDrivers.push({
        driverId,
        reason: 'night_hours',
        reactivationScheduled: jobData.reactivation?.scheduleReactivation || false
      });
    }
    
    // Guardar horarios de reactivación
    if (reactivationSchedules.length > 0) {
      const batch = db.batch();
      for (const schedule of reactivationSchedules) {
        const scheduleRef = db.collection('driver_reactivation_schedule').doc();
        batch.set(scheduleRef, {
          ...schedule,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          status: 'scheduled'
        });
      }
      await batch.commit();
    }
    
    // Enviar notificaciones
    let sentNotifications = 0;
    if (notifications.length > 0) {
      const batchSize = 500;
      for (let i = 0; i < notifications.length; i += batchSize) {
        const batch = notifications.slice(i, i + batchSize);
        
        try {
          const response = await messaging.sendAll(batch);
          sentNotifications += response.successCount;
        } catch (error) {
          console.error(`Error enviando notificaciones nocturnas ${i}:`, error);
        }
      }
    }
    
    return {
      driversProcessed: processedDrivers.length,
      driversSetOffline: processedDrivers.length,
      reactivationsScheduled: reactivationSchedules.length,
      notificationsSent: sentNotifications
    };
    
  } catch (error) {
    console.error('Error en auto-offline nocturno:', error);
    throw error;
  }
}

/**
 * Reactivación automática matutina
 */
async function processAutoReactivationMorning(jobData) {
  try {
    console.log('🌅 Procesando reactivación matutina...');
    
    const timeWindow = jobData.timeWindow;
    const now = new Date();
    
    // Obtener conductores programados para reactivación
    const reactivationQuery = await db.collection('driver_reactivation_schedule')
      .where('reactivationTime', '<=', now)
      .where('status', '==', 'scheduled')
      .get();
    
    console.log(`⏰ ${reactivationQuery.docs.length} reactivaciones programadas encontradas`);
    
    const reactivatedDrivers = [];
    const notifications = [];
    
    for (const scheduleDoc of reactivationQuery.docs) {
      const scheduleData = scheduleDoc.data();
      const driverId = scheduleData.driverId;
      
      // Verificar criterios de reactivación
      const canReactivate = await verifyReactivationCriteria(driverId, jobData.criteria);
      if (!canReactivate) {
        console.log(`⏭️ Conductor ${driverId} no cumple criterios de reactivación`);
        continue;
      }
      
      // Actualizar estado a online
      await db.collection('driver_availability').doc(driverId).update({
        isOnline: true,
        status: 'available',
        reactivatedBy: 'auto_scheduler',
        reactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastStatusChange: admin.firestore.FieldValue.serverTimestamp(),
        scheduledReactivation: admin.firestore.FieldValue.delete()
      });
      
      // Marcar programación como completada
      await db.collection('driver_reactivation_schedule').doc(scheduleDoc.id).update({
        status: 'completed',
        completedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Preparar notificación de buenos días
      const userData = await db.collection('users').doc(driverId).get();
      const userTokens = userData.data()?.fcmTokens;
      
      if (userTokens && userTokens.length > 0) {
        // Personalizar mensaje con datos del conductor
        const personalizedMessage = await personalizeGoodMorningMessage(driverId);
        
        for (const token of userTokens) {
          notifications.push({
            token: token,
            notification: {
              title: jobData.notifications.title,
              body: personalizedMessage
            },
            data: {
              type: 'auto_reactivation',
              reason: 'morning_hours',
              actionUrl: jobData.notifications.actionUrl,
              hasEarlyBirdBonus: jobData.incentives?.earlyBirdBonus?.enabled ? 'true' : 'false',
              bonusPercentage: jobData.incentives?.earlyBirdBonus?.bonusPercentage?.toString() || '0',
              driverId: driverId
            },
            android: {
              notification: {
                channelId: 'driver_status',
                priority: 'high',
                defaultSound: true,
                defaultVibrateTimings: true
              }
            }
          });
        }
      }
      
      // Registrar evento de auditoría
      await db.collection('driver_activity_logs').add({
        driverId: driverId,
        event: 'auto_reactivation',
        reason: 'morning_hours',
        scheduledReactivationId: scheduleDoc.id,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
      
      reactivatedDrivers.push({
        driverId,
        reason: scheduleData.reason,
        scheduledTime: scheduleData.reactivationTime
      });
    }
    
    // Enviar notificaciones de buenos días
    let sentNotifications = 0;
    if (notifications.length > 0) {
      const batchSize = 500;
      for (let i = 0; i < notifications.length; i += batchSize) {
        const batch = notifications.slice(i, i + batchSize);
        
        try {
          const response = await messaging.sendAll(batch);
          sentNotifications += response.successCount;
        } catch (error) {
          console.error(`Error enviando notificaciones matutinas ${i}:`, error);
        }
      }
    }
    
    return {
      scheduledReactivations: reactivationQuery.docs.length,
      driversReactivated: reactivatedDrivers.length,
      notificationsSent: sentNotifications,
      reactivatedDrivers: reactivatedDrivers
    };
    
  } catch (error) {
    console.error('Error en reactivación matutina:', error);
    throw error;
  }
}

/**
 * Optimización por demanda
 */
async function processAvailabilityOptimization(jobData) {
  try {
    console.log('🎯 Procesando optimización por demanda...');
    
    const analysis = jobData.analysis;
    const zones = jobData.zones;
    const thresholds = jobData.thresholds;
    
    const optimizationResults = [];
    
    for (const zone of zones) {
      console.log(`📊 Analizando zona: ${zone.name}`);
      
      // Analizar demanda actual y futura para la zona
      const demandAnalysis = await analyzeDemandForZone(zone, analysis);
      
      // Contar conductores disponibles en la zona
      const availableDrivers = await countAvailableDriversInZone(zone);
      
      // Calcular si necesitamos más conductores
      const supplyGap = calculateSupplyGap(demandAnalysis, availableDrivers, thresholds);
      
      let actionsTaken = [];
      
      if (supplyGap.needMoreDrivers) {
        // Buscar conductores offline cercanos para sugerir reactivación
        const nearbyOfflineDrivers = await findNearbyOfflineDrivers(zone, supplyGap.driversNeeded);
        
        const reactivationSuggestions = [];
        for (const driver of nearbyOfflineDrivers) {
          // Enviar sugerencia de reactivación
          const userData = await db.collection('users').doc(driver.driverId).get();
          const userTokens = userData.data()?.fcmTokens;
          
          if (userTokens && userTokens.length > 0) {
            const incentive = calculateReactivationIncentive(supplyGap.urgency);
            
            for (const token of userTokens) {
              reactivationSuggestions.push({
                token: token,
                notification: {
                  title: `Alta demanda en ${zone.name} 🎯`,
                  body: `Gana hasta S/ ${incentive.bonus} extra. ¡Conecta ahora!`
                },
                data: {
                  type: 'reactivation_suggestion',
                  zone: zone.name,
                  incentive: incentive.bonus.toString(),
                  urgency: supplyGap.urgency,
                  actionUrl: "oasistaxi://driver/reactivate",
                  driverId: driver.driverId
                }
              });
            }
          }
        }
        
        // Enviar sugerencias
        if (reactivationSuggestions.length > 0) {
          const batchSize = 500;
          let suggestionsSent = 0;
          
          for (let i = 0; i < reactivationSuggestions.length; i += batchSize) {
            const batch = reactivationSuggestions.slice(i, i + batchSize);
            
            try {
              const response = await messaging.sendAll(batch);
              suggestionsSent += response.successCount;
            } catch (error) {
              console.error(`Error enviando sugerencias zona ${zone.name}:`, error);
            }
          }
          
          actionsTaken.push({
            action: 'reactivation_suggestions_sent',
            count: suggestionsSent
          });
        }
      }
      
      optimizationResults.push({
        zone: zone.name,
        demandLevel: demandAnalysis.level,
        availableDrivers: availableDrivers,
        recommendedDrivers: demandAnalysis.optimalDriverCount,
        supplyGap: supplyGap,
        actionsTaken: actionsTaken
      });
    }
    
    // Registrar resultados de optimización
    await db.collection('availability_optimization_results').add({
      results: optimizationResults,
      executedAt: admin.firestore.FieldValue.serverTimestamp(),
      analysisConfig: analysis
    });
    
    return {
      zonesAnalyzed: zones.length,
      optimizationResults: optimizationResults,
      totalActionsTaken: optimizationResults.reduce((sum, result) => 
        sum + result.actionsTaken.length, 0)
    };
    
  } catch (error) {
    console.error('Error en optimización por demanda:', error);
    throw error;
  }
}

/**
 * Detección de app en background
 */
async function processAppBackgroundDetection(jobData) {
  try {
    console.log('📱 Procesando detección de app en background...');
    
    const detection = jobData.detection;
    const gracePeriod = jobData.gracePeriod;
    
    const heartbeatThreshold = new Date(Date.now() - detection.lastHeartbeatThresholdMinutes * 60 * 1000);
    
    // Obtener conductores online con heartbeat antiguo
    const driversQuery = await db.collection('driver_availability')
      .where('isOnline', '==', true)
      .where('lastHeartbeat', '<=', admin.firestore.Timestamp.fromDate(heartbeatThreshold))
      .get();
    
    console.log(`📱 ${driversQuery.docs.length} conductores con app potencialmente en background`);
    
    const backgroundAlerts = [];
    const pausedDrivers = [];
    
    for (const driverDoc of driversQuery.docs) {
      const driverData = driverDoc.data();
      const driverId = driverDoc.id;
      
      // Verificar si el conductor ya ha sido advertido
      const warningCount = driverData.backgroundWarnings || 0;
      
      if (warningCount >= gracePeriod.maxBackgroundWarnings) {
        // Auto-offline después de máximas advertencias
        await db.collection('driver_availability').doc(driverId).update({
          isOnline: false,
          status: 'offline',
          autoOfflineReason: 'app_background_limit_exceeded',
          autoOfflineAt: admin.firestore.FieldValue.serverTimestamp(),
          backgroundWarnings: 0 // Reset contador
        });
        
        pausedDrivers.push({
          driverId,
          reason: 'background_limit_exceeded',
          warningCount: warningCount
        });
        
      } else {
        // Enviar alerta de app en background
        const userData = await db.collection('users').doc(driverId).get();
        const userTokens = userData.data()?.fcmTokens;
        
        if (userTokens && userTokens.length > 0) {
          for (const token of userTokens) {
            backgroundAlerts.push({
              token: token,
              notification: {
                title: jobData.alerts.backgroundAlert.title,
                body: jobData.alerts.backgroundAlert.body
              },
              data: {
                type: 'background_alert',
                actionUrl: jobData.alerts.backgroundAlert.actionUrl,
                warningNumber: (warningCount + 1).toString(),
                maxWarnings: gracePeriod.maxBackgroundWarnings.toString(),
                driverId: driverId
              },
              android: {
                notification: {
                  channelId: 'driver_alerts',
                  priority: 'max',
                  defaultSound: true,
                  defaultVibrateTimings: true,
                  sticky: true
                }
              }
            });
          }
        }
        
        // Incrementar contador de advertencias
        await db.collection('driver_availability').doc(driverId).update({
          backgroundWarnings: admin.firestore.FieldValue.increment(1),
          lastBackgroundWarning: admin.firestore.FieldValue.serverTimestamp()
        });
      }
    }
    
    // Enviar alertas de background
    let alertsSent = 0;
    if (backgroundAlerts.length > 0) {
      const batchSize = 500;
      for (let i = 0; i < backgroundAlerts.length; i += batchSize) {
        const batch = backgroundAlerts.slice(i, i + batchSize);
        
        try {
          const response = await messaging.sendAll(batch);
          alertsSent += response.successCount;
        } catch (error) {
          console.error(`Error enviando alertas background ${i}:`, error);
        }
      }
    }
    
    return {
      driversDetectedBackground: driversQuery.docs.length,
      alertsSent: alertsSent,
      driversPaused: pausedDrivers.length,
      pausedDrivers: pausedDrivers
    };
    
  } catch (error) {
    console.error('Error en detección app background:', error);
    throw error;
  }
}

/**
 * Limpieza de estados huérfanos
 */
async function processStatusCleanup(jobData) {
  try {
    console.log('🧹 Procesando limpieza de estados...');
    
    const cleanup = jobData.cleanup;
    const criteria = jobData.criteria;
    
    let cleanupResults = {
      orphanedSessions: 0,
      staleLocations: 0,
      inconsistentStates: 0,
      expiredTokens: 0
    };
    
    // Limpiar sesiones huérfanas
    if (cleanup.orphanedSessions) {
      const sessionAge = new Date(Date.now() - criteria.sessionAgeHours * 60 * 60 * 1000);
      
      const orphanedSessionsQuery = await db.collection('driver_availability')
        .where('lastActivity', '<=', admin.firestore.Timestamp.fromDate(sessionAge))
        .where('isOnline', '==', true)
        .get();
      
      const batch = db.batch();
      orphanedSessionsQuery.docs.forEach(doc => {
        batch.update(doc.ref, {
          isOnline: false,
          status: 'offline',
          cleanupReason: 'orphaned_session',
          cleanedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      });
      
      if (orphanedSessionsQuery.docs.length > 0) {
        await batch.commit();
      }
      
      cleanupResults.orphanedSessions = orphanedSessionsQuery.docs.length;
    }
    
    // Limpiar ubicaciones obsoletas
    if (cleanup.staleLocations) {
      const locationAge = new Date(Date.now() - criteria.locationAgeHours * 60 * 60 * 1000);
      
      const staleLocationsQuery = await db.collection('driver_locations')
        .where('lastUpdate', '<=', admin.firestore.Timestamp.fromDate(locationAge))
        .get();
      
      const locationBatch = db.batch();
      staleLocationsQuery.docs.forEach(doc => {
        locationBatch.delete(doc.ref);
      });
      
      if (staleLocationsQuery.docs.length > 0) {
        await locationBatch.commit();
      }
      
      cleanupResults.staleLocations = staleLocationsQuery.docs.length;
    }
    
    // Detectar estados inconsistentes
    if (cleanup.inconsistentStates) {
      const inconsistentCount = await detectAndFixInconsistentStates(criteria.inconsistencyThresholdMinutes);
      cleanupResults.inconsistentStates = inconsistentCount;
    }
    
    // Limpiar tokens expirados
    if (cleanup.expiredTokens) {
      const tokenAge = new Date(Date.now() - criteria.tokenAgeHours * 60 * 60 * 1000);
      const expiredTokensCount = await cleanupExpiredTokens(tokenAge);
      cleanupResults.expiredTokens = expiredTokensCount;
    }
    
    // Registrar resultado de limpieza
    await db.collection('cleanup_results').add({
      results: cleanupResults,
      criteria: criteria,
      executedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    return cleanupResults;
    
  } catch (error) {
    console.error('Error en limpieza de estados:', error);
    throw error;
  }
}

/**
 * Sistema de gamificación de disponibilidad
 */
async function processAvailabilityGamification(jobData) {
  try {
    console.log('🏆 Procesando gamificación de disponibilidad...');
    
    const dailyRewards = jobData.dailyRewards;
    const achievements = jobData.achievements;
    
    const today = new Date();
    const startOfDay = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    const endOfDay = new Date(startOfDay);
    endOfDay.setDate(endOfDay.getDate() + 1);
    
    // Obtener todos los conductores activos
    const driversQuery = await db.collection('users')
      .where('userType', '==', 'driver')
      .where('isActive', '==', true)
      .get();
    
    console.log(`🎮 Procesando gamificación para ${driversQuery.docs.length} conductores`);
    
    const gamificationResults = [];
    const achievementNotifications = [];
    
    for (const driverDoc of driversQuery.docs) {
      const driverData = driverDoc.data();
      const driverId = driverDoc.id;
      
      // Calcular métricas del día
      const dailyMetrics = await calculateDailyMetrics(driverId, startOfDay, endOfDay);
      
      // Verificar logros
      const newAchievements = await checkAchievements(driverId, achievements, dailyMetrics);
      
      // Calcular puntos y recompensas
      const pointsEarned = calculateDailyPoints(dailyMetrics);
      const bonusEarned = calculateDailyBonus(dailyMetrics);
      
      // Actualizar estadísticas del conductor
      await db.collection('driver_gamification').doc(driverId).set({
        dailyMetrics: dailyMetrics,
        pointsEarnedToday: pointsEarned,
        bonusEarnedToday: bonusEarned,
        newAchievements: newAchievements,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
      
      // Preparar notificaciones de logros
      if (newAchievements.length > 0) {
        const userData = await db.collection('users').doc(driverId).get();
        const userTokens = userData.data()?.fcmTokens;
        
        if (userTokens && userTokens.length > 0) {
          for (const achievement of newAchievements) {
            for (const token of userTokens) {
              achievementNotifications.push({
                token: token,
                notification: {
                  title: jobData.notifications.achievement.title,
                  body: jobData.notifications.achievement.body
                    .replace('{achievement_name}', achievement.name)
                    .replace('{reward_amount}', achievement.reward.bonus)
                },
                data: {
                  type: 'achievement_unlocked',
                  achievementId: achievement.id,
                  achievementName: achievement.name,
                  rewardPoints: achievement.reward.points.toString(),
                  rewardBonus: achievement.reward.bonus,
                  actionUrl: jobData.notifications.achievement.actionUrl,
                  driverId: driverId
                }
              });
            }
          }
        }
      }
      
      gamificationResults.push({
        driverId: driverId,
        dailyMetrics: dailyMetrics,
        pointsEarned: pointsEarned,
        bonusEarned: bonusEarned,
        achievementsUnlocked: newAchievements.length
      });
    }
    
    // Enviar notificaciones de logros
    let achievementNotificationsSent = 0;
    if (achievementNotifications.length > 0) {
      const batchSize = 500;
      for (let i = 0; i < achievementNotifications.length; i += batchSize) {
        const batch = achievementNotifications.slice(i, i + batchSize);
        
        try {
          const response = await messaging.sendAll(batch);
          achievementNotificationsSent += response.successCount;
        } catch (error) {
          console.error(`Error enviando notificaciones logros ${i}:`, error);
        }
      }
    }
    
    // Calcular y actualizar leaderboards
    const leaderboards = await updateLeaderboards(gamificationResults, jobData.leaderboards);
    
    return {
      driversProcessed: gamificationResults.length,
      totalPointsAwarded: gamificationResults.reduce((sum, result) => sum + result.pointsEarned, 0),
      totalBonusAwarded: gamificationResults.reduce((sum, result) => sum + result.bonusEarned, 0),
      achievementsUnlocked: gamificationResults.reduce((sum, result) => sum + result.achievementsUnlocked, 0),
      achievementNotificationsSent: achievementNotificationsSent,
      leaderboards: leaderboards
    };
    
  } catch (error) {
    console.error('Error en gamificación de disponibilidad:', error);
    throw error;
  }
}

// ═══════════════════════════════════════════════════════════════════
// FUNCIONES AUXILIARES
// ═══════════════════════════════════════════════════════════════════

/**
 * Verificar inactividad real del conductor
 */
async function verifyDriverInactivity(driverId, driverData, thresholds) {
  try {
    // Verificar última ubicación
    const locationDoc = await db.collection('driver_locations').doc(driverId).get();
    if (locationDoc.exists) {
      const locationData = locationDoc.data();
      if (locationData.lastUpdate.toDate() > thresholds.locationThreshold) {
        return false; // Ubicación reciente, no está inactivo
      }
    }
    
    // Verificar interacciones recientes con la app
    const interactionQuery = await db.collection('driver_app_interactions')
      .where('driverId', '==', driverId)
      .where('timestamp', '>', admin.firestore.Timestamp.fromDate(thresholds.inactivityThreshold))
      .limit(1)
      .get();
    
    if (!interactionQuery.empty) {
      return false; // Interacción reciente, no está inactivo
    }
    
    // Verificar si está en viaje
    if (driverData.status === 'on_trip' || driverData.status === 'busy') {
      return false; // Está ocupado, no desconectar
    }
    
    return true; // Verdaderamente inactivo
  } catch (error) {
    console.error(`Error verificando inactividad conductor ${driverId}:`, error);
    return false; // En caso de error, no desconectar
  }
}

/**
 * Verificar exención de auto-offline nocturno
 */
async function checkNightShiftExemption(driverId, criteria) {
  try {
    const driverDoc = await db.collection('users').doc(driverId).get();
    const driverData = driverDoc.data();
    
    // Verificar si es conductor nocturno
    if (criteria.excludeNightShiftDrivers && driverData.workShift === 'night') {
      return true;
    }
    
    // Verificar si es conductor del aeropuerto
    if (criteria.excludeAirportDrivers && driverData.specialtyZones?.includes('airport')) {
      return true;
    }
    
    // Verificar si ha optado por no recibir auto-offline
    if (criteria.allowOptOut && driverData.preferences?.autoOfflineOptOut === true) {
      return true;
    }
    
    return false;
  } catch (error) {
    console.error(`Error verificando exención nocturna ${driverId}:`, error);
    return false;
  }
}

/**
 * Calcular tiempo de reactivación
 */
function calculateReactivationTime(hourString) {
  const [hour, minute] = hourString.split(':').map(Number);
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  tomorrow.setHours(hour, minute || 0, 0, 0);
  return admin.firestore.Timestamp.fromDate(tomorrow);
}

/**
 * Verificar criterios de reactivación
 */
async function verifyReactivationCriteria(driverId, criteria) {
  try {
    // Verificar si fue puesto offline automáticamente
    const availabilityDoc = await db.collection('driver_availability').doc(driverId).get();
    const availabilityData = availabilityDoc.data();
    
    if (criteria.wasAutoOfflined && !availabilityData.autoOfflineReason) {
      return false;
    }
    
    // Verificar si estuvo activo ayer
    if (criteria.lastActiveYesterday) {
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      
      if (!availabilityData.lastActivity || 
          availabilityData.lastActivity.toDate() < yesterday) {
        return false;
      }
    }
    
    // Verificar cuenta en buen estado
    if (criteria.accountInGoodStanding) {
      const driverDoc = await db.collection('users').doc(driverId).get();
      const driverData = driverDoc.data();
      
      if (!driverData.isActive || driverData.isSuspended) {
        return false;
      }
    }
    
    return true;
  } catch (error) {
    console.error(`Error verificando criterios reactivación ${driverId}:`, error);
    return false;
  }
}

/**
 * Personalizar mensaje de buenos días
 */
async function personalizeGoodMorningMessage(driverId) {
  try {
    // Obtener datos del conductor
    const driverDoc = await db.collection('users').doc(driverId).get();
    const driverData = driverDoc.data();
    
    let message = "¡Buenos días! Hora pico iniciando. ¿Listo para ganar?";
    
    // Agregar nombre si está disponible
    if (driverData.displayName) {
      const firstName = driverData.displayName.split(' ')[0];
      message = `¡Buenos días, ${firstName}! Hora pico iniciando. ¿Listo para ganar?`;
    }
    
    // Agregar meta de ganancias si está disponible
    if (driverData.dailyEarningsGoal) {
      message += ` Tu meta de S/ ${driverData.dailyEarningsGoal} te está esperando.`;
    }
    
    return message;
  } catch (error) {
    return "¡Buenos días! Hora pico iniciando. ¿Listo para ganar?";
  }
}

/**
 * Otros métodos auxiliares simplificados para mantener el ejemplo conciso
 */
async function analyzeDemandForZone(zone, analysis) {
  // Simulación de análisis de demanda
  return {
    level: 'medium',
    optimalDriverCount: 15,
    currentDemand: 12,
    predictedDemand: 18
  };
}

async function countAvailableDriversInZone(zone) {
  // Simulación de conteo de conductores
  return Math.floor(Math.random() * 20) + 5;
}

function calculateSupplyGap(demandAnalysis, availableDrivers, thresholds) {
  const gap = demandAnalysis.optimalDriverCount - availableDrivers;
  return {
    needMoreDrivers: gap > 0,
    driversNeeded: Math.max(0, gap),
    urgency: gap > 5 ? 'high' : gap > 2 ? 'medium' : 'low'
  };
}

async function findNearbyOfflineDrivers(zone, needed) {
  // Simulación de búsqueda de conductores cercanos
  return Array.from({ length: Math.min(needed, 10) }, (_, i) => ({
    driverId: `driver_${i}`,
    distance: Math.random() * 5000
  }));
}

function calculateReactivationIncentive(urgency) {
  const incentives = {
    high: { bonus: 25 },
    medium: { bonus: 15 },
    low: { bonus: 10 }
  };
  return incentives[urgency] || incentives.low;
}

async function detectAndFixInconsistentStates(thresholdMinutes) {
  // Simulación de detección de estados inconsistentes
  return Math.floor(Math.random() * 5);
}

async function cleanupExpiredTokens(tokenAge) {
  // Simulación de limpieza de tokens expirados
  return Math.floor(Math.random() * 10);
}

async function calculateDailyMetrics(driverId, startOfDay, endOfDay) {
  // Simulación de cálculo de métricas diarias
  return {
    onlineHours: Math.random() * 10 + 2,
    tripsCompleted: Math.floor(Math.random() * 15) + 1,
    responseRate: 0.8 + Math.random() * 0.2,
    earnings: Math.random() * 200 + 50
  };
}

async function checkAchievements(driverId, achievements, dailyMetrics) {
  // Simulación de verificación de logros
  const newAchievements = [];
  
  if (dailyMetrics.onlineHours > 8) {
    newAchievements.push(achievements.find(a => a.id === 'consistency_king') || {
      id: 'daily_hero',
      name: 'Héroe del Día',
      reward: { points: 100, bonus: 'S/ 10' }
    });
  }
  
  return newAchievements;
}

function calculateDailyPoints(dailyMetrics) {
  return Math.floor(dailyMetrics.onlineHours * 10 + dailyMetrics.tripsCompleted * 5);
}

function calculateDailyBonus(dailyMetrics) {
  return Math.floor(dailyMetrics.onlineHours * 2);
}

async function updateLeaderboards(gamificationResults, leaderboardConfig) {
  // Simulación de actualización de leaderboards
  return {
    updated: true,
    weeklyTopDrivers: 10,
    monthlyTopDrivers: 20
  };
}

module.exports = {
  manageDriverAvailability: exports.manageDriverAvailability
};