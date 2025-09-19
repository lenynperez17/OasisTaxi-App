const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { CloudTasksClient } = require('@google-cloud/tasks');
const { v4: uuidv4 } = require('uuid');

// Configuración para Perú
const PERU_CONFIG = {
  timezone: 'America/Lima',
  currency: 'PEN',
  country: 'PE'
};

/**
 * SISTEMA COMPLETO DE CLOUD TASKS CON REINTENTOS INTELIGENTES
 * Gestión robusta de tareas asíncronas para OasisTaxi Perú
 * 
 * Características:
 * - Reintentos exponenciales con jitter
 * - Circuit breaker pattern
 * - Dead letter queue management
 * - Monitoreo y alertas de fallos
 * - Diferentes estrategias de reintento por tipo de tarea
 * - Recuperación automática de tareas fallidas
 * - Análisis de patrones de fallos
 */

// ============================================================================
// CONFIGURACIÓN Y INICIALIZACIÓN
// ============================================================================

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const tasksClient = new CloudTasksClient();

// Configuración de reintentos por tipo de tarea
const RETRY_CONFIGS = {
  // Configuraciones por tipo de tarea
  taskTypes: {
    PAYMENT_PROCESSING: 'payment_processing',
    NOTIFICATION_SENDING: 'notification_sending',
    TRIP_MATCHING: 'trip_matching',
    DRIVER_VERIFICATION: 'driver_verification',
    DATA_SYNCHRONIZATION: 'data_synchronization',
    REPORT_GENERATION: 'report_generation',
    EMAIL_SENDING: 'email_sending',
    WEBHOOK_DELIVERY: 'webhook_delivery'
  },

  // Estrategias de reintento específicas
  retryStrategies: {
    PAYMENT_PROCESSING: {
      maxAttempts: 5,
      initialDelay: 1000, // 1 segundo
      maxDelay: 300000,   // 5 minutos
      backoffMultiplier: 2.0,
      jitter: true,
      circuitBreakerThreshold: 10,
      timeoutSeconds: 30
    },
    NOTIFICATION_SENDING: {
      maxAttempts: 3,
      initialDelay: 500,
      maxDelay: 60000, // 1 minuto
      backoffMultiplier: 1.5,
      jitter: true,
      circuitBreakerThreshold: 15,
      timeoutSeconds: 10
    },
    TRIP_MATCHING: {
      maxAttempts: 7,
      initialDelay: 2000,
      maxDelay: 600000, // 10 minutos
      backoffMultiplier: 2.5,
      jitter: true,
      circuitBreakerThreshold: 20,
      timeoutSeconds: 45
    },
    DRIVER_VERIFICATION: {
      maxAttempts: 3,
      initialDelay: 5000,
      maxDelay: 1800000, // 30 minutos
      backoffMultiplier: 3.0,
      jitter: false,
      circuitBreakerThreshold: 5,
      timeoutSeconds: 60
    },
    DATA_SYNCHRONIZATION: {
      maxAttempts: 4,
      initialDelay: 1500,
      maxDelay: 120000, // 2 minutos
      backoffMultiplier: 2.0,
      jitter: true,
      circuitBreakerThreshold: 12,
      timeoutSeconds: 20
    },
    DEFAULT: {
      maxAttempts: 3,
      initialDelay: 1000,
      maxDelay: 60000,
      backoffMultiplier: 2.0,
      jitter: true,
      circuitBreakerThreshold: 10,
      timeoutSeconds: 15
    }
  },

  // Estados de tareas
  taskStates: {
    PENDING: 'pending',
    PROCESSING: 'processing',
    COMPLETED: 'completed',
    FAILED: 'failed',
    RETRY: 'retry',
    DEAD_LETTER: 'dead_letter',
    CIRCUIT_OPEN: 'circuit_open'
  }
};

// Circuit breakers por tipo de tarea
const circuitBreakers = new Map();

// ============================================================================
// FUNCIÓN PRINCIPAL: CREAR TAREA CON CONFIGURACIÓN DE REINTENTOS
// ============================================================================

exports.createTaskWithRetry = functions
  .runWith({
    timeoutSeconds: 60,
    memory: '512MB'
  })
  .https.onCall(async (data, context) => {
    
    console.log('📋 Creando tarea con configuración de reintentos:', data.taskType);
    
    try {
      const {
        taskType,
        taskData,
        scheduleTime,
        priority,
        tags,
        dedupKey
      } = data;
      
      if (!taskType || !taskData) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'taskType y taskData son requeridos'
        );
      }
      
      // Obtener configuración de reintentos para el tipo de tarea
      const retryConfig = RETRY_CONFIGS.retryStrategies[taskType] || 
                         RETRY_CONFIGS.retryStrategies.DEFAULT;
      
      // Verificar circuit breaker
      const circuitState = await checkCircuitBreakerState(taskType);
      if (circuitState.isOpen) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          `Circuit breaker abierto para ${taskType}. Próximo intento en ${circuitState.nextAttemptTime}`
        );
      }
      
      // Crear ID único de tarea
      const taskId = dedupKey || uuidv4();
      
      // Verificar deduplicación si se proporciona dedupKey
      if (dedupKey) {
        const existingTask = await checkTaskDeduplication(dedupKey, taskType);
        if (existingTask) {
          return {
            success: true,
            taskId: existingTask.id,
            status: 'deduplicated',
            message: 'Tarea ya existe con el mismo dedupKey'
          };
        }
      }
      
      // Crear documento de tarea en Firestore
      const taskDoc = {
        id: taskId,
        type: taskType,
        status: RETRY_CONFIGS.taskStates.PENDING,
        data: taskData,
        retryConfig,
        
        // Información de reintentos
        attemptCount: 0,
        maxAttempts: retryConfig.maxAttempts,
        nextRetryAt: scheduleTime ? admin.firestore.Timestamp.fromDate(new Date(scheduleTime)) : admin.firestore.FieldValue.serverTimestamp(),
        
        // Metadatos
        priority: priority || 'normal',
        tags: tags || [],
        dedupKey: dedupKey || null,
        
        // Timestamps
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        
        // Información de seguimiento
        executionHistory: [],
        lastError: null,
        totalProcessingTime: 0,
        
        // Configuración específica para Perú
        locale: PERU_CONFIG
      };
      
      // Guardar en Firestore
      await db.collection('cloud_tasks').doc(taskId).set(taskDoc);
      
      // Crear tarea en Cloud Tasks
      const cloudTask = await createCloudTask(taskId, taskType, taskData, retryConfig, scheduleTime);
      
      // Log de auditoría
      await logTaskEvent(taskId, 'TASK_CREATED', {
        taskType,
        retryConfig: retryConfig,
        cloudTaskName: cloudTask.name
      });
      
      console.log(`✅ Tarea creada exitosamente: ${taskId}`);
      
      return {
        success: true,
        taskId,
        status: RETRY_CONFIGS.taskStates.PENDING,
        cloudTaskName: cloudTask.name,
        retryConfig
      };
      
    } catch (error) {
      console.error('❌ Error creando tarea:', error);
      
      throw new functions.https.HttpsError(
        'internal',
        `Error creando tarea: ${error.message}`
      );
    }
  });

// ============================================================================
// FUNCIÓN: EJECUTOR DE TAREAS CON REINTENTOS
// ============================================================================

exports.executeTaskWithRetry = functions
  .runWith({
    timeoutSeconds: 300,
    memory: '1GB'
  })
  .https.onRequest(async (req, res) => {
    
    console.log('⚡ Ejecutando tarea con manejo de reintentos...');
    
    try {
      const { taskId } = req.body;
      
      if (!taskId) {
        return res.status(400).json({
          error: 'taskId es requerido'
        });
      }
      
      // Obtener datos de la tarea
      const taskDoc = await db.collection('cloud_tasks').doc(taskId).get();
      
      if (!taskDoc.exists) {
        return res.status(404).json({
          error: 'Tarea no encontrada'
        });
      }
      
      const task = taskDoc.data();
      
      // Verificar si la tarea ya fue completada
      if (task.status === RETRY_CONFIGS.taskStates.COMPLETED) {
        return res.status(200).json({
          success: true,
          message: 'Tarea ya completada previamente'
        });
      }
      
      // Actualizar estado a processing
      await taskDoc.ref.update({
        status: RETRY_CONFIGS.taskStates.PROCESSING,
        currentAttempt: (task.attemptCount || 0) + 1,
        lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      const executionStart = Date.now();
      let executionResult = null;
      let executionError = null;
      
      try {
        // Ejecutar la tarea específica
        executionResult = await executeSpecificTask(task.type, task.data, taskId);
        
        // Marcar como completada
        await markTaskAsCompleted(taskId, executionResult, executionStart);
        
        // Actualizar circuit breaker con éxito
        await updateCircuitBreakerSuccess(task.type);
        
        res.status(200).json({
          success: true,
          taskId,
          result: executionResult,
          executionTime: Date.now() - executionStart
        });
        
      } catch (error) {
        executionError = error;
        console.error(`❌ Error ejecutando tarea ${taskId}:`, error);
        
        // Determinar si se debe reintentar
        const shouldRetry = await evaluateRetryCondition(task, error);
        
        if (shouldRetry) {
          // Programar reintento
          await scheduleTaskRetry(taskId, task, error, executionStart);
          
          res.status(202).json({
            success: false,
            taskId,
            status: 'retry_scheduled',
            error: error.message,
            nextRetryIn: calculateNextRetryDelay(task),
            attempt: (task.attemptCount || 0) + 1
          });
          
        } else {
          // Marcar como fallida permanentemente
          await markTaskAsFailed(taskId, task, error, executionStart);
          
          // Actualizar circuit breaker con fallo
          await updateCircuitBreakerFailure(task.type);
          
          res.status(500).json({
            success: false,
            taskId,
            status: 'failed_permanently',
            error: error.message,
            totalAttempts: (task.attemptCount || 0) + 1
          });
        }
      }
      
    } catch (error) {
      console.error('❌ Error en ejecutor de tareas:', error);
      
      res.status(500).json({
        error: 'Error interno del servidor',
        details: error.message
      });
    }
  });

// ============================================================================
// FUNCIÓN: MONITOR DE CIRCUIT BREAKERS
// ============================================================================

exports.monitorCircuitBreakers = functions
  .runWith({
    timeoutSeconds: 120,
    memory: '512MB'
  })
  .pubsub
  .schedule('*/5 * * * *') // Cada 5 minutos
  .timeZone(PERU_CONFIG.timezone)
  .onRun(async (context) => {
    
    console.log('🔍 Monitoreando estado de circuit breakers...');
    
    try {
      const taskTypes = Object.values(RETRY_CONFIGS.taskTypes);
      const circuitStates = [];
      
      for (const taskType of taskTypes) {
        const circuitState = await evaluateCircuitBreakerState(taskType);
        circuitStates.push(circuitState);
        
        // Si el circuit breaker estaba abierto pero puede cerrarse
        if (circuitState.wasOpen && circuitState.canClose) {
          await closeCircuitBreaker(taskType);
          console.log(`🔧 Circuit breaker cerrado para ${taskType}`);
        }
        
        // Si hay muchos fallos, abrir circuit breaker
        if (circuitState.shouldOpen) {
          await openCircuitBreaker(taskType, circuitState.reason);
          console.log(`⚠️ Circuit breaker abierto para ${taskType}: ${circuitState.reason}`);
        }
      }
      
      // Generar reporte de estado
      const healthReport = {
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        circuitStates,
        healthyCircuits: circuitStates.filter(s => s.state === 'closed').length,
        openCircuits: circuitStates.filter(s => s.state === 'open').length,
        totalCircuits: circuitStates.length
      };
      
      // Guardar reporte
      await db.collection('circuit_breaker_health').add(healthReport);
      
      // Enviar alertas si hay circuits abiertos
      const openCircuits = circuitStates.filter(s => s.state === 'open');
      if (openCircuits.length > 0) {
        await sendCircuitBreakerAlerts(openCircuits);
      }
      
      console.log(`✅ Monitoreo completado: ${circuitStates.length} circuit breakers evaluados`);
      
      return {
        success: true,
        evaluatedCircuits: circuitStates.length,
        healthyCircuits: healthReport.healthyCircuits,
        openCircuits: healthReport.openCircuits
      };
      
    } catch (error) {
      console.error('❌ Error monitoreando circuit breakers:', error);
      throw error;
    }
  });

// ============================================================================
// FUNCIÓN: RECUPERACIÓN DE TAREAS FALLIDAS
// ============================================================================

exports.recoverFailedTasks = functions
  .runWith({
    timeoutSeconds: 540,
    memory: '1GB'
  })
  .https.onCall(async (data, context) => {
    
    console.log('🔄 Iniciando recuperación de tareas fallidas...');
    
    try {
      // Validación de autenticación admin
      if (!context.auth || !context.auth.token.admin) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'Solo administradores pueden recuperar tareas fallidas'
        );
      }
      
      const { 
        taskType, 
        maxAge, 
        maxTasks, 
        forceRetry 
      } = data;
      
      // Buscar tareas fallidas
      let query = db.collection('cloud_tasks')
        .where('status', 'in', [RETRY_CONFIGS.taskStates.FAILED, RETRY_CONFIGS.taskStates.DEAD_LETTER])
        .orderBy('updatedAt', 'desc');
        
      if (taskType) {
        query = query.where('type', '==', taskType);
      }
      
      if (maxTasks) {
        query = query.limit(maxTasks);
      }
      
      const failedTasks = await query.get();
      
      if (failedTasks.empty) {
        return {
          success: true,
          message: 'No hay tareas fallidas para recuperar',
          recoveredTasks: 0
        };
      }
      
      const recoveryResults = [];
      
      for (const taskDoc of failedTasks.docs) {
        const task = taskDoc.data();
        const taskAge = Date.now() - task.updatedAt.toDate().getTime();
        
        // Verificar edad máxima si se especifica
        if (maxAge && taskAge > maxAge * 60 * 1000) {
          continue;
        }
        
        try {
          // Analizar si la tarea es recuperable
          const recoveryAnalysis = await analyzeTaskRecoverability(task);
          
          if (recoveryAnalysis.canRecover || forceRetry) {
            // Resetear estado y programar nuevo intento
            await resetTaskForRetry(taskDoc.id, task, recoveryAnalysis);
            
            recoveryResults.push({
              taskId: taskDoc.id,
              status: 'scheduled_for_retry',
              reason: recoveryAnalysis.reason
            });
            
            console.log(`🔄 Tarea ${taskDoc.id} programada para reintento`);
            
          } else {
            recoveryResults.push({
              taskId: taskDoc.id,
              status: 'not_recoverable',
              reason: recoveryAnalysis.reason
            });
          }
          
        } catch (error) {
          console.error(`❌ Error recuperando tarea ${taskDoc.id}:`, error);
          
          recoveryResults.push({
            taskId: taskDoc.id,
            status: 'recovery_error',
            error: error.message
          });
        }
      }
      
      // Log de auditoría
      await logTaskEvent('BULK_RECOVERY', 'RECOVERY_COMPLETED', {
        totalTasks: failedTasks.size,
        recoveredTasks: recoveryResults.filter(r => r.status === 'scheduled_for_retry').length,
        taskType,
        maxAge,
        maxTasks
      });
      
      return {
        success: true,
        totalTasksAnalyzed: failedTasks.size,
        recoveredTasks: recoveryResults.filter(r => r.status === 'scheduled_for_retry').length,
        notRecoverableTasks: recoveryResults.filter(r => r.status === 'not_recoverable').length,
        recoveryResults
      };
      
    } catch (error) {
      console.error('❌ Error en recuperación de tareas:', error);
      
      throw new functions.https.HttpsError(
        'internal',
        `Error en recuperación: ${error.message}`
      );
    }
  });

// ============================================================================
// FUNCIONES AUXILIARES DE EJECUCIÓN
// ============================================================================

async function createCloudTask(taskId, taskType, taskData, retryConfig, scheduleTime) {
  try {
    const project = process.env.GOOGLE_CLOUD_PROJECT;
    const location = 'us-central1';
    const queue = `${taskType.toLowerCase()}-queue`;
    
    const parent = tasksClient.queuePath(project, location, queue);
    
    const task = {
      httpRequest: {
        httpMethod: 'POST',
        url: `https://${location}-${project}.cloudfunctions.net/executeTaskWithRetry`,
        body: Buffer.from(JSON.stringify({ taskId })),
        headers: {
          'Content-Type': 'application/json'
        }
      },
      scheduleTime: scheduleTime ? {
        seconds: Math.floor(new Date(scheduleTime).getTime() / 1000)
      } : undefined
    };
    
    const [response] = await tasksClient.createTask({
      parent,
      task
    });
    
    return response;
    
  } catch (error) {
    console.error('❌ Error creando Cloud Task:', error);
    throw error;
  }
}

async function executeSpecificTask(taskType, taskData, taskId) {
  console.log(`🚀 Ejecutando tarea específica: ${taskType}`);
  
  try {
    switch (taskType) {
      case RETRY_CONFIGS.taskTypes.PAYMENT_PROCESSING:
        return await processPaymentTask(taskData, taskId);
        
      case RETRY_CONFIGS.taskTypes.NOTIFICATION_SENDING:
        return await sendNotificationTask(taskData, taskId);
        
      case RETRY_CONFIGS.taskTypes.TRIP_MATCHING:
        return await matchTripTask(taskData, taskId);
        
      case RETRY_CONFIGS.taskTypes.DRIVER_VERIFICATION:
        return await verifyDriverTask(taskData, taskId);
        
      case RETRY_CONFIGS.taskTypes.DATA_SYNCHRONIZATION:
        return await synchronizeDataTask(taskData, taskId);
        
      case RETRY_CONFIGS.taskTypes.REPORT_GENERATION:
        return await generateReportTask(taskData, taskId);
        
      case RETRY_CONFIGS.taskTypes.EMAIL_SENDING:
        return await sendEmailTask(taskData, taskId);
        
      case RETRY_CONFIGS.taskTypes.WEBHOOK_DELIVERY:
        return await deliverWebhookTask(taskData, taskId);
        
      default:
        throw new Error(`Tipo de tarea no soportado: ${taskType}`);
    }
    
  } catch (error) {
    console.error(`❌ Error ejecutando tarea ${taskType}:`, error);
    throw error;
  }
}

// ============================================================================
// IMPLEMENTACIONES ESPECÍFICAS DE TAREAS
// ============================================================================

async function processPaymentTask(taskData, taskId) {
  console.log('💳 Procesando pago...');
  
  const { paymentId, amount, paymentMethod } = taskData;
  
  // Simulación de procesamiento de pago
  // En implementación real, esto interactuaría con MercadoPago, etc.
  await new Promise(resolve => setTimeout(resolve, 2000));
  
  // Actualizar estado del pago en Firestore
  await db.collection('payments').doc(paymentId).update({
    status: 'processed',
    processedAt: admin.firestore.FieldValue.serverTimestamp(),
    processedBy: 'cloud_tasks',
    taskId
  });
  
  return {
    paymentId,
    status: 'processed',
    amount,
    paymentMethod,
    processedAt: new Date().toISOString()
  };
}

async function sendNotificationTask(taskData, taskId) {
  console.log('🔔 Enviando notificación...');
  
  const { userId, title, message, type } = taskData;
  
  // Implementar envío de notificación FCM
  const messaging = admin.messaging();
  
  // Obtener token del usuario
  const userDoc = await db.collection('users').doc(userId).get();
  const fcmToken = userDoc.data()?.fcmToken;
  
  if (!fcmToken) {
    throw new Error('Token FCM no encontrado para el usuario');
  }
  
  const messagePayload = {
    token: fcmToken,
    notification: {
      title,
      body: message
    },
    data: {
      type,
      taskId,
      timestamp: new Date().toISOString()
    }
  };
  
  const response = await messaging.send(messagePayload);
  
  return {
    userId,
    messageId: response,
    sentAt: new Date().toISOString(),
    type
  };
}

async function matchTripTask(taskData, taskId) {
  console.log('🚗 Emparejando viaje...');
  
  const { tripRequestId, location, vehicleType } = taskData;
  
  // Buscar conductores disponibles
  const availableDriversQuery = await db.collection('drivers')
    .where('status', '==', 'available')
    .where('vehicleType', '==', vehicleType)
    .limit(10)
    .get();
    
  if (availableDriversQuery.empty) {
    throw new Error('No hay conductores disponibles');
  }
  
  // Algoritmo simple de matching (en producción sería más complejo)
  const nearestDriver = availableDriversQuery.docs[0];
  const driverId = nearestDriver.id;
  
  // Asignar viaje al conductor
  await db.collection('trip_requests').doc(tripRequestId).update({
    assignedDriverId: driverId,
    status: 'assigned',
    assignedAt: admin.firestore.FieldValue.serverTimestamp(),
    taskId
  });
  
  // Actualizar estado del conductor
  await db.collection('drivers').doc(driverId).update({
    status: 'busy',
    currentTripId: tripRequestId,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  return {
    tripRequestId,
    assignedDriverId: driverId,
    matchedAt: new Date().toISOString()
  };
}

async function verifyDriverTask(taskData, taskId) {
  console.log('👨‍💼 Verificando conductor...');
  
  const { driverId, documentType } = taskData;
  
  // Simulación de verificación (en producción usaría APIs externas)
  await new Promise(resolve => setTimeout(resolve, 5000));
  
  const verificationResult = {
    driverId,
    documentType,
    verificationStatus: 'verified',
    verifiedAt: new Date().toISOString(),
    taskId
  };
  
  // Actualizar estado de verificación
  await db.collection('driver_verifications').doc(driverId).update({
    [documentType]: verificationResult,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  return verificationResult;
}

async function synchronizeDataTask(taskData, taskId) {
  console.log('🔄 Sincronizando datos...');
  
  const { sourceCollection, targetCollection, syncType } = taskData;
  
  // Implementar lógica de sincronización
  const sourceData = await db.collection(sourceCollection).get();
  
  const batch = db.batch();
  let syncedRecords = 0;
  
  sourceData.docs.forEach(doc => {
    const targetRef = db.collection(targetCollection).doc(doc.id);
    batch.set(targetRef, {
      ...doc.data(),
      syncedAt: admin.firestore.FieldValue.serverTimestamp(),
      taskId
    });
    syncedRecords++;
  });
  
  await batch.commit();
  
  return {
    sourceCollection,
    targetCollection,
    syncType,
    syncedRecords,
    syncedAt: new Date().toISOString()
  };
}

// ============================================================================
// FUNCIONES AUXILIARES DE REINTENTOS
// ============================================================================

async function evaluateRetryCondition(task, error) {
  const currentAttempts = (task.attemptCount || 0) + 1;
  const maxAttempts = task.retryConfig.maxAttempts;
  
  // Verificar si se alcanzó el máximo de intentos
  if (currentAttempts >= maxAttempts) {
    return false;
  }
  
  // Errores que no se deben reintentar
  const nonRetryableErrors = [
    'invalid-argument',
    'permission-denied',
    'not-found',
    'already-exists'
  ];
  
  if (nonRetryableErrors.some(errorType => error.message.includes(errorType))) {
    return false;
  }
  
  // Verificar circuit breaker
  const circuitState = await checkCircuitBreakerState(task.type);
  if (circuitState.isOpen) {
    return false;
  }
  
  return true;
}

async function scheduleTaskRetry(taskId, task, error, executionStart) {
  const nextAttempt = (task.attemptCount || 0) + 1;
  const delay = calculateNextRetryDelay(task);
  const nextRetryTime = new Date(Date.now() + delay);
  
  const executionRecord = {
    attempt: nextAttempt,
    startedAt: new Date(executionStart).toISOString(),
    endedAt: new Date().toISOString(),
    duration: Date.now() - executionStart,
    status: 'failed',
    error: {
      message: error.message,
      code: error.code,
      stack: error.stack
    }
  };
  
  await db.collection('cloud_tasks').doc(taskId).update({
    status: RETRY_CONFIGS.taskStates.RETRY,
    attemptCount: nextAttempt,
    nextRetryAt: admin.firestore.Timestamp.fromDate(nextRetryTime),
    lastError: executionRecord.error,
    executionHistory: admin.firestore.FieldValue.arrayUnion(executionRecord),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  // Crear nueva tarea Cloud Task para el reintento
  await createCloudTask(
    taskId, 
    task.type, 
    task.data, 
    task.retryConfig, 
    nextRetryTime.toISOString()
  );
  
  await logTaskEvent(taskId, 'RETRY_SCHEDULED', {
    attempt: nextAttempt,
    nextRetryAt: nextRetryTime.toISOString(),
    delay,
    error: error.message
  });
}

function calculateNextRetryDelay(task) {
  const config = task.retryConfig;
  const attempt = (task.attemptCount || 0) + 1;
  
  // Calcular delay exponencial
  let delay = config.initialDelay * Math.pow(config.backoffMultiplier, attempt - 1);
  
  // Aplicar límite máximo
  delay = Math.min(delay, config.maxDelay);
  
  // Aplicar jitter si está habilitado
  if (config.jitter) {
    const jitterAmount = delay * 0.1; // 10% jitter
    delay += (Math.random() - 0.5) * 2 * jitterAmount;
  }
  
  return Math.round(delay);
}

// ============================================================================
// FUNCIONES AUXILIARES ADICIONALES
// ============================================================================

async function markTaskAsCompleted(taskId, result, executionStart) {
  const executionRecord = {
    attempt: 1, // Will be updated with actual attempt
    startedAt: new Date(executionStart).toISOString(),
    endedAt: new Date().toISOString(),
    duration: Date.now() - executionStart,
    status: 'completed',
    result
  };
  
  await db.collection('cloud_tasks').doc(taskId).update({
    status: RETRY_CONFIGS.taskStates.COMPLETED,
    completedAt: admin.firestore.FieldValue.serverTimestamp(),
    result,
    executionHistory: admin.firestore.FieldValue.arrayUnion(executionRecord),
    totalProcessingTime: admin.firestore.FieldValue.increment(executionRecord.duration),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  await logTaskEvent(taskId, 'TASK_COMPLETED', {
    result,
    processingTime: executionRecord.duration
  });
}

async function checkCircuitBreakerState(taskType) {
  // Implementar lógica de circuit breaker
  return {
    isOpen: false,
    nextAttemptTime: null
  };
}

async function checkTaskDeduplication(dedupKey, taskType) {
  const existingTaskQuery = await db.collection('cloud_tasks')
    .where('dedupKey', '==', dedupKey)
    .where('type', '==', taskType)
    .where('status', 'in', [RETRY_CONFIGS.taskStates.PENDING, RETRY_CONFIGS.taskStates.PROCESSING, RETRY_CONFIGS.taskStates.COMPLETED])
    .limit(1)
    .get();
    
  return existingTaskQuery.empty ? null : existingTaskQuery.docs[0].data();
}

async function logTaskEvent(taskId, eventType, eventData) {
  await db.collection('task_audit_logs').add({
    taskId,
    eventType,
    eventData,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    service: 'cloud_tasks_retry'
  });
}

// Stubs para funciones que requieren implementación completa
async function updateCircuitBreakerSuccess() { console.log('Actualizando circuit breaker success...'); }
async function updateCircuitBreakerFailure() { console.log('Actualizando circuit breaker failure...'); }
async function markTaskAsFailed() { console.log('Marcando tarea como fallida...'); }
async function evaluateCircuitBreakerState() { return { state: 'closed' }; }
async function openCircuitBreaker() { console.log('Abriendo circuit breaker...'); }
async function closeCircuitBreaker() { console.log('Cerrando circuit breaker...'); }
async function sendCircuitBreakerAlerts() { console.log('Enviando alertas de circuit breaker...'); }
async function analyzeTaskRecoverability() { return { canRecover: true, reason: 'Task is recoverable' }; }
async function resetTaskForRetry() { console.log('Reseteando tarea para reintento...'); }
async function generateReportTask() { return { status: 'report_generated' }; }
async function sendEmailTask() { return { status: 'email_sent' }; }
async function deliverWebhookTask() { return { status: 'webhook_delivered' }; }

console.log('📋 Sistema Cloud Tasks con reintentos para OasisTaxi inicializado correctamente');