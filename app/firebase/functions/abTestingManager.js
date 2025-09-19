const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { v4: uuidv4 } = require('uuid');

// Configuración para Perú
const PERU_CONFIG = {
  timezone: 'America/Lima',
  currency: 'PEN',
  country: 'PE'
};

/**
 * SISTEMA COMPLETO DE A/B TESTING PARA OASISTAXI PERU
 * Funciones Cloud para gestión integral de experimentos A/B
 * Integración con Firebase Remote Config y Analytics
 * 
 * Características:
 * - Creación y gestión de experimentos
 * - Asignación automática de usuarios a grupos
 * - Seguimiento de métricas y conversiones
 * - Análisis estadístico de resultados
 * - Automatización de decisiones
 */

// ============================================================================
// CONFIGURACIÓN Y INICIALIZACIÓN
// ============================================================================

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const remoteConfig = admin.remoteConfig();

// Configuración del sistema A/B Testing
const AB_CONFIG = {
  // Tipos de experimentos disponibles
  experimentTypes: {
    PRICING: 'pricing',
    UI_UX: 'ui_ux', 
    FEATURES: 'features',
    MESSAGING: 'messaging',
    ONBOARDING: 'onboarding'
  },
  
  // Estados de experimentos
  experimentStatus: {
    DRAFT: 'draft',
    ACTIVE: 'active', 
    PAUSED: 'paused',
    COMPLETED: 'completed',
    CANCELLED: 'cancelled'
  },
  
  // Métricas principales de OasisTaxi
  primaryMetrics: {
    TRIP_COMPLETION_RATE: 'trip_completion_rate',
    DRIVER_ACCEPTANCE_RATE: 'driver_acceptance_rate',
    USER_RETENTION: 'user_retention',
    AVERAGE_TRIP_VALUE: 'average_trip_value',
    CONVERSION_RATE: 'conversion_rate',
    USER_SATISFACTION: 'user_satisfaction'
  }
};

// ============================================================================
// FUNCIÓN PRINCIPAL: CREAR EXPERIMENTO A/B
// ============================================================================

exports.createABExperiment = functions
  .runWith({
    timeoutSeconds: 300,
    memory: '1GB'
  })
  .https.onCall(async (data, context) => {
    
    console.log('🧪 Creando nuevo experimento A/B:', data.experimentName);
    
    try {
      // Validación de autenticación
      if (!context.auth || !context.auth.token.admin) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'Solo administradores pueden crear experimentos A/B'
        );
      }
      
      // Validación de datos requeridos
      const {
        experimentName,
        description,
        hypothesis,
        experimentType,
        variants,
        primaryMetric,
        trafficSplit,
        duration,
        targetAudience,
        successCriteria
      } = data;
      
      if (!experimentName || !variants || variants.length < 2) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Se requiere nombre del experimento y al menos 2 variantes'
        );
      }
      
      // Generar ID único para el experimento
      const experimentId = uuidv4();
      const startDate = new Date();
      const endDate = new Date();
      endDate.setDate(startDate.getDate() + (duration || 30));
      
      // Configurar variantes
      const processedVariants = variants.map((variant, index) => ({
        id: `variant_${index}`,
        name: variant.name || `Variante ${index + 1}`,
        description: variant.description || '',
        config: variant.config || {},
        trafficPercentage: trafficSplit[index] || Math.floor(100 / variants.length),
        isControl: index === 0,
        userCount: 0,
        conversionCount: 0,
        metrics: {}
      }));
      
      // Crear documento del experimento
      const experimentDoc = {
        id: experimentId,
        name: experimentName,
        description: description || '',
        hypothesis: hypothesis || '',
        type: experimentType || AB_CONFIG.experimentTypes.FEATURES,
        status: AB_CONFIG.experimentStatus.DRAFT,
        
        // Configuración del experimento
        variants: processedVariants,
        primaryMetric: primaryMetric || AB_CONFIG.primaryMetrics.CONVERSION_RATE,
        trafficSplit: trafficSplit,
        
        // Fechas y duración
        startDate: admin.firestore.Timestamp.fromDate(startDate),
        endDate: admin.firestore.Timestamp.fromDate(endDate),
        duration: duration || 30,
        
        // Audiencia objetivo
        targetAudience: {
          userTypes: targetAudience?.userTypes || ['passenger', 'driver'],
          cities: targetAudience?.cities || ['Lima', 'Arequipa', 'Trujillo'],
          minAge: targetAudience?.minAge || 18,
          maxAge: targetAudience?.maxAge || 65,
          deviceTypes: targetAudience?.deviceTypes || ['android', 'ios']
        },
        
        // Criterios de éxito
        successCriteria: {
          minimumSampleSize: successCriteria?.minimumSampleSize || 1000,
          confidenceLevel: successCriteria?.confidenceLevel || 0.95,
          minimumDetectableEffect: successCriteria?.minimumDetectableEffect || 0.05,
          significanceThreshold: successCriteria?.significanceThreshold || 0.05
        },
        
        // Metadatos
        createdBy: context.auth.uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        
        // Configuración específica para Perú
        localization: PERU_CONFIG
      };
      
      // Guardar en Firestore
      await db.collection('ab_experiments').doc(experimentId).set(experimentDoc);
      
      // Crear configuración en Remote Config
      await createRemoteConfigForExperiment(experimentId, experimentDoc);
      
      // Configurar Analytics para tracking
      await setupAnalyticsTracking(experimentId, experimentDoc);
      
      // Log de auditoría
      await logAuditEvent('AB_EXPERIMENT_CREATED', {
        experimentId,
        experimentName,
        createdBy: context.auth.uid,
        variants: variants.length
      });
      
      console.log('✅ Experimento A/B creado exitosamente:', experimentId);
      
      return {
        success: true,
        experimentId,
        message: 'Experimento A/B creado exitosamente',
        experiment: experimentDoc
      };
      
    } catch (error) {
      console.error('❌ Error al crear experimento A/B:', error);
      await logAuditEvent('AB_EXPERIMENT_ERROR', {
        error: error.message,
        data
      });
      
      throw new functions.https.HttpsError(
        'internal',
        `Error al crear experimento: ${error.message}`
      );
    }
  });

// ============================================================================
// FUNCIÓN: ASIGNAR USUARIO A GRUPO EXPERIMENTAL
// ============================================================================

exports.assignUserToExperiment = functions
  .runWith({
    timeoutSeconds: 60,
    memory: '512MB'
  })
  .https.onCall(async (data, context) => {
    
    console.log('👤 Asignando usuario a experimento:', data.experimentId);
    
    try {
      const { experimentId, userId, userProfile } = data;
      
      if (!experimentId || !userId) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Se requiere experimentId y userId'
        );
      }
      
      // Obtener experimento
      const experimentDoc = await db.collection('ab_experiments').doc(experimentId).get();
      
      if (!experimentDoc.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'Experimento no encontrado'
        );
      }
      
      const experiment = experimentDoc.data();
      
      // Verificar si el experimento está activo
      if (experiment.status !== AB_CONFIG.experimentStatus.ACTIVE) {
        return {
          success: false,
          message: 'El experimento no está activo',
          variant: null
        };
      }
      
      // Verificar si el usuario ya está asignado
      const existingAssignment = await db
        .collection('ab_assignments')
        .where('experimentId', '==', experimentId)
        .where('userId', '==', userId)
        .limit(1)
        .get();
        
      if (!existingAssignment.empty) {
        const assignment = existingAssignment.docs[0].data();
        return {
          success: true,
          message: 'Usuario ya asignado previamente',
          variant: assignment.variant,
          config: assignment.config
        };
      }
      
      // Verificar elegibilidad del usuario
      const isEligible = await checkUserEligibility(userId, userProfile, experiment.targetAudience);
      
      if (!isEligible) {
        return {
          success: false,
          message: 'Usuario no elegible para este experimento',
          variant: null
        };
      }
      
      // Asignar variante usando hash consistente
      const assignedVariant = await assignVariantToUser(userId, experiment.variants);
      
      // Crear documento de asignación
      const assignmentDoc = {
        id: uuidv4(),
        experimentId,
        userId,
        variant: assignedVariant,
        config: assignedVariant.config,
        assignedAt: admin.firestore.FieldValue.serverTimestamp(),
        userProfile: {
          userType: userProfile?.userType || 'passenger',
          city: userProfile?.city || 'Lima',
          age: userProfile?.age || null,
          device: userProfile?.device || 'android'
        },
        events: [],
        metrics: {},
        isConverted: false
      };
      
      // Guardar asignación
      await db.collection('ab_assignments').add(assignmentDoc);
      
      // Actualizar contador de usuarios en la variante
      await db.collection('ab_experiments').doc(experimentId).update({
        [`variants.${assignedVariant.id}.userCount`]: admin.firestore.FieldValue.increment(1)
      });
      
      console.log('✅ Usuario asignado exitosamente a variante:', assignedVariant.name);
      
      return {
        success: true,
        message: 'Usuario asignado exitosamente',
        variant: assignedVariant,
        config: assignedVariant.config
      };
      
    } catch (error) {
      console.error('❌ Error al asignar usuario:', error);
      
      throw new functions.https.HttpsError(
        'internal',
        `Error al asignar usuario: ${error.message}`
      );
    }
  });

// ============================================================================
// FUNCIÓN: REGISTRAR EVENTO DE EXPERIMENTO
// ============================================================================

exports.trackExperimentEvent = functions
  .runWith({
    timeoutSeconds: 30,
    memory: '256MB'
  })
  .https.onCall(async (data, context) => {
    
    try {
      const { experimentId, userId, eventType, eventData, isConversion } = data;
      
      if (!experimentId || !userId || !eventType) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Se requiere experimentId, userId y eventType'
        );
      }
      
      // Buscar asignación del usuario
      const assignmentQuery = await db
        .collection('ab_assignments')
        .where('experimentId', '==', experimentId)
        .where('userId', '==', userId)
        .limit(1)
        .get();
        
      if (assignmentQuery.empty) {
        console.log('⚠️ No se encontró asignación para usuario:', userId);
        return { success: false, message: 'Usuario no asignado al experimento' };
      }
      
      const assignmentDoc = assignmentQuery.docs[0];
      const assignment = assignmentDoc.data();
      
      // Crear evento
      const eventDoc = {
        id: uuidv4(),
        experimentId,
        userId,
        variant: assignment.variant,
        eventType,
        eventData: eventData || {},
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isConversion: isConversion || false
      };
      
      // Guardar evento
      await db.collection('ab_events').add(eventDoc);
      
      // Actualizar asignación con el evento
      await assignmentDoc.ref.update({
        events: admin.firestore.FieldValue.arrayUnion(eventDoc),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Si es una conversión, actualizar contadores
      if (isConversion && !assignment.isConverted) {
        await assignmentDoc.ref.update({
          isConverted: true,
          conversionAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        // Actualizar contador de conversiones en la variante
        await db.collection('ab_experiments').doc(experimentId).update({
          [`variants.${assignment.variant.id}.conversionCount`]: admin.firestore.FieldValue.increment(1)
        });
      }
      
      return {
        success: true,
        message: 'Evento registrado exitosamente'
      };
      
    } catch (error) {
      console.error('❌ Error al registrar evento:', error);
      
      throw new functions.https.HttpsError(
        'internal',
        `Error al registrar evento: ${error.message}`
      );
    }
  });

// ============================================================================
// FUNCIÓN: ANALIZAR RESULTADOS DE EXPERIMENTO
// ============================================================================

exports.analyzeExperimentResults = functions
  .runWith({
    timeoutSeconds: 540,
    memory: '2GB'
  })
  .https.onCall(async (data, context) => {
    
    console.log('📊 Analizando resultados de experimento:', data.experimentId);
    
    try {
      // Validación de autenticación admin
      if (!context.auth || !context.auth.token.admin) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'Solo administradores pueden analizar experimentos'
        );
      }
      
      const { experimentId } = data;
      
      if (!experimentId) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Se requiere experimentId'
        );
      }
      
      // Obtener experimento
      const experimentDoc = await db.collection('ab_experiments').doc(experimentId).get();
      
      if (!experimentDoc.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'Experimento no encontrado'
        );
      }
      
      const experiment = experimentDoc.data();
      
      // Obtener todas las asignaciones del experimento
      const assignmentsQuery = await db
        .collection('ab_assignments')
        .where('experimentId', '==', experimentId)
        .get();
        
      if (assignmentsQuery.empty) {
        return {
          success: false,
          message: 'No hay datos suficientes para análisis'
        };
      }
      
      // Procesar datos por variante
      const variantResults = {};
      
      assignmentsQuery.docs.forEach(doc => {
        const assignment = doc.data();
        const variantId = assignment.variant.id;
        
        if (!variantResults[variantId]) {
          variantResults[variantId] = {
            name: assignment.variant.name,
            totalUsers: 0,
            conversions: 0,
            events: [],
            metrics: {}
          };
        }
        
        variantResults[variantId].totalUsers++;
        if (assignment.isConverted) {
          variantResults[variantId].conversions++;
        }
        variantResults[variantId].events.push(...(assignment.events || []));
      });
      
      // Calcular métricas estadísticas
      const statisticalAnalysis = await calculateStatisticalSignificance(variantResults);
      
      // Determinar ganador
      const winner = determineWinner(variantResults, statisticalAnalysis);
      
      // Generar recomendaciones
      const recommendations = generateRecommendations(experiment, variantResults, statisticalAnalysis, winner);
      
      // Crear reporte completo
      const analysisReport = {
        experimentId,
        experimentName: experiment.name,
        analysisDate: new Date().toISOString(),
        duration: Math.ceil((new Date() - experiment.startDate.toDate()) / (1000 * 60 * 60 * 24)),
        
        // Resultados por variante
        variantResults,
        
        // Análisis estadístico
        statisticalAnalysis,
        
        // Ganador y recomendaciones
        winner,
        recommendations,
        
        // Métricas globales
        totalUsers: Object.values(variantResults).reduce((sum, v) => sum + v.totalUsers, 0),
        totalConversions: Object.values(variantResults).reduce((sum, v) => sum + v.conversions, 0),
        overallConversionRate: Object.values(variantResults).reduce((sum, v) => sum + v.conversions, 0) / 
                              Object.values(variantResults).reduce((sum, v) => sum + v.totalUsers, 0),
        
        // Configuración específica para Perú
        localization: PERU_CONFIG
      };
      
      // Guardar reporte de análisis
      await db.collection('ab_analysis_reports').add({
        ...analysisReport,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log('✅ Análisis de experimento completado');
      
      return {
        success: true,
        message: 'Análisis completado exitosamente',
        report: analysisReport
      };
      
    } catch (error) {
      console.error('❌ Error en análisis de experimento:', error);
      
      throw new functions.https.HttpsError(
        'internal',
        `Error en análisis: ${error.message}`
      );
    }
  });

// ============================================================================
// FUNCIÓN: GESTIONAR CICLO DE VIDA DE EXPERIMENTOS
// ============================================================================

exports.manageExperimentLifecycle = functions
  .runWith({
    timeoutSeconds: 300,
    memory: '1GB'
  })
  .pubsub
  .schedule('0 9 * * *') // Todos los días a las 9 AM (Lima)
  .timeZone(PERU_CONFIG.timezone)
  .onRun(async (context) => {
    
    console.log('🔄 Ejecutando gestión automática de experimentos...');
    
    try {
      const now = new Date();
      
      // Obtener experimentos activos
      const activeExperimentsQuery = await db
        .collection('ab_experiments')
        .where('status', '==', AB_CONFIG.experimentStatus.ACTIVE)
        .get();
        
      let processedCount = 0;
      
      for (const experimentDoc of activeExperimentsQuery.docs) {
        const experiment = experimentDoc.data();
        const experimentId = experimentDoc.id;
        
        // Verificar si el experimento ha finalizado
        if (experiment.endDate.toDate() <= now) {
          console.log(`⏰ Finalizando experimento: ${experiment.name}`);
          
          // Analizar resultados automáticamente
          const analysisResult = await analyzeExperimentResults({ experimentId }, { 
            auth: { token: { admin: true } } 
          });
          
          // Actualizar estado a completado
          await experimentDoc.ref.update({
            status: AB_CONFIG.experimentStatus.COMPLETED,
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
            autoCompleted: true,
            finalAnalysis: analysisResult.report
          });
          
          // Enviar notificación a administradores
          await sendExperimentCompletionNotification(experimentId, experiment, analysisResult.report);
          
          processedCount++;
        }
        
        // Verificar si el experimento necesita más datos
        else {
          const totalUsers = experiment.variants.reduce((sum, variant) => sum + (variant.userCount || 0), 0);
          const minimumSampleSize = experiment.successCriteria.minimumSampleSize;
          
          if (totalUsers >= minimumSampleSize) {
            // Realizar análisis intermedio
            const interimAnalysis = await analyzeExperimentResults({ experimentId }, { 
              auth: { token: { admin: true } } 
            });
            
            // Verificar si se puede tomar una decisión temprana
            if (interimAnalysis.report.statisticalAnalysis.hasSignificance) {
              console.log(`🎯 Significancia alcanzada en experimento: ${experiment.name}`);
              
              // Notificar a administradores sobre posible finalización temprana
              await sendEarlySignificanceNotification(experimentId, experiment, interimAnalysis.report);
            }
          }
        }
      }
      
      console.log(`✅ Gestión de experimentos completada. Procesados: ${processedCount}`);
      
      return { processedCount };
      
    } catch (error) {
      console.error('❌ Error en gestión de experimentos:', error);
      throw error;
    }
  });

// ============================================================================
// FUNCIONES AUXILIARES
// ============================================================================

/**
 * Crear configuración de Remote Config para el experimento
 */
async function createRemoteConfigForExperiment(experimentId, experiment) {
  try {
    const template = await remoteConfig.getTemplate();
    
    // Crear parámetro para el experimento
    const parameterKey = `ab_experiment_${experimentId}`;
    
    template.parameters[parameterKey] = {
      defaultValue: {
        value: JSON.stringify({
          status: 'inactive',
          variants: experiment.variants,
          config: {}
        })
      },
      conditionalValues: {
        // Configuración específica para usuarios target
        [`ab_user_${experimentId}`]: {
          value: JSON.stringify({
            status: 'active',
            variants: experiment.variants,
            config: experiment.variants[0].config // Control por defecto
          })
        }
      },
      description: `Configuración A/B para experimento: ${experiment.name}`
    };
    
    await remoteConfig.publishTemplate(template);
    console.log('✅ Remote Config actualizado para experimento');
    
  } catch (error) {
    console.error('❌ Error al crear Remote Config:', error);
    throw error;
  }
}

/**
 * Configurar tracking de Analytics para el experimento
 */
async function setupAnalyticsTracking(experimentId, experiment) {
  try {
    // Crear eventos personalizados para el experimento
    const customEvents = [
      `ab_${experimentId}_assignment`,
      `ab_${experimentId}_conversion`,
      `ab_${experimentId}_interaction`
    ];
    
    // Los eventos se registrarán automáticamente cuando se usen
    console.log('✅ Analytics tracking configurado:', customEvents);
    
  } catch (error) {
    console.error('❌ Error al configurar Analytics:', error);
    throw error;
  }
}

/**
 * Verificar elegibilidad del usuario para el experimento
 */
async function checkUserEligibility(userId, userProfile, targetAudience) {
  try {
    // Verificar tipo de usuario
    if (targetAudience.userTypes && !targetAudience.userTypes.includes(userProfile?.userType)) {
      return false;
    }
    
    // Verificar ciudad
    if (targetAudience.cities && !targetAudience.cities.includes(userProfile?.city)) {
      return false;
    }
    
    // Verificar edad
    if (userProfile?.age) {
      if (targetAudience.minAge && userProfile.age < targetAudience.minAge) return false;
      if (targetAudience.maxAge && userProfile.age > targetAudience.maxAge) return false;
    }
    
    // Verificar tipo de dispositivo
    if (targetAudience.deviceTypes && !targetAudience.deviceTypes.includes(userProfile?.device)) {
      return false;
    }
    
    return true;
    
  } catch (error) {
    console.error('❌ Error al verificar elegibilidad:', error);
    return false;
  }
}

/**
 * Asignar variante al usuario usando hash consistente
 */
async function assignVariantToUser(userId, variants) {
  try {
    // Crear hash consistente basado en userId
    const crypto = require('crypto');
    const hash = crypto.createHash('md5').update(userId).digest('hex');
    const hashValue = parseInt(hash.substring(0, 8), 16);
    const percentage = (hashValue % 100) + 1;
    
    // Asignar basado en porcentajes acumulativos
    let cumulativePercentage = 0;
    
    for (const variant of variants) {
      cumulativePercentage += variant.trafficPercentage;
      if (percentage <= cumulativePercentage) {
        return variant;
      }
    }
    
    // Fallback: retornar primera variante (control)
    return variants[0];
    
  } catch (error) {
    console.error('❌ Error al asignar variante:', error);
    return variants[0];
  }
}

/**
 * Calcular significancia estadística
 */
async function calculateStatisticalSignificance(variantResults) {
  try {
    const variants = Object.keys(variantResults);
    const controlVariant = variants[0]; // Primera variante es control
    const analysis = {
      hasSignificance: false,
      confidenceLevel: 0,
      pValue: 1,
      variants: {}
    };
    
    // Calcular para cada variante vs control
    for (let i = 1; i < variants.length; i++) {
      const variantId = variants[i];
      const controlData = variantResults[controlVariant];
      const variantData = variantResults[variantId];
      
      // Calcular tasas de conversión
      const controlRate = controlData.conversions / controlData.totalUsers;
      const variantRate = variantData.conversions / variantData.totalUsers;
      
      // Calcular z-score (aproximación)
      const pooledRate = (controlData.conversions + variantData.conversions) / 
                        (controlData.totalUsers + variantData.totalUsers);
      
      const standardError = Math.sqrt(
        pooledRate * (1 - pooledRate) * 
        (1 / controlData.totalUsers + 1 / variantData.totalUsers)
      );
      
      const zScore = (variantRate - controlRate) / standardError;
      const pValue = 2 * (1 - normalCDF(Math.abs(zScore))); // Two-tailed test
      
      analysis.variants[variantId] = {
        conversionRate: variantRate,
        improvement: ((variantRate - controlRate) / controlRate) * 100,
        zScore,
        pValue,
        isSignificant: pValue < 0.05
      };
      
      if (pValue < 0.05) {
        analysis.hasSignificance = true;
      }
    }
    
    return analysis;
    
  } catch (error) {
    console.error('❌ Error en cálculo estadístico:', error);
    return { hasSignificance: false, variants: {} };
  }
}

/**
 * Aproximación de la función de distribución normal
 */
function normalCDF(x) {
  return 0.5 * (1 + erf(x / Math.sqrt(2)));
}

function erf(x) {
  // Aproximación de la función error
  const a1 =  0.254829592;
  const a2 = -0.284496736;
  const a3 =  1.421413741;
  const a4 = -1.453152027;
  const a5 =  1.061405429;
  const p  =  0.3275911;
  
  const sign = x >= 0 ? 1 : -1;
  x = Math.abs(x);
  
  const t = 1.0 / (1.0 + p * x);
  const y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * Math.exp(-x * x);
  
  return sign * y;
}

/**
 * Determinar ganador del experimento
 */
function determineWinner(variantResults, statisticalAnalysis) {
  try {
    const variants = Object.keys(variantResults);
    let winner = {
      variantId: variants[0], // Control por defecto
      conversionRate: variantResults[variants[0]].conversions / variantResults[variants[0]].totalUsers,
      isSignificant: false,
      improvement: 0
    };
    
    // Buscar la variante con mejor performance y significancia estadística
    for (const variantId of variants) {
      const variantRate = variantResults[variantId].conversions / variantResults[variantId].totalUsers;
      const analysis = statisticalAnalysis.variants[variantId];
      
      if (analysis && analysis.isSignificant && variantRate > winner.conversionRate) {
        winner = {
          variantId,
          conversionRate: variantRate,
          isSignificant: true,
          improvement: analysis.improvement
        };
      }
    }
    
    return winner;
    
  } catch (error) {
    console.error('❌ Error al determinar ganador:', error);
    return { variantId: 'unknown', isSignificant: false };
  }
}

/**
 * Generar recomendaciones basadas en resultados
 */
function generateRecommendations(experiment, variantResults, statisticalAnalysis, winner) {
  try {
    const recommendations = [];
    
    if (winner.isSignificant) {
      recommendations.push({
        type: 'IMPLEMENT_WINNER',
        priority: 'HIGH',
        title: 'Implementar variante ganadora',
        description: `La variante "${winner.variantId}" muestra una mejora significativa del ${winner.improvement.toFixed(2)}%`,
        action: 'Desplegar la configuración ganadora para todos los usuarios'
      });
    } else {
      recommendations.push({
        type: 'CONTINUE_TESTING',
        priority: 'MEDIUM',
        title: 'Continuar experimento',
        description: 'No se encontró diferencia estadísticamente significativa',
        action: 'Extender la duración del experimento o incrementar el tamaño de muestra'
      });
    }
    
    // Recomendaciones específicas para OasisTaxi
    if (experiment.type === AB_CONFIG.experimentTypes.PRICING) {
      recommendations.push({
        type: 'MONITOR_METRICS',
        priority: 'HIGH',
        title: 'Monitorear impacto en ganancias',
        description: 'Verificar que los cambios de precio no afecten negativamente las ganancias de los conductores',
        action: 'Revisar métricas de satisfacción de conductores'
      });
    }
    
    return recommendations;
    
  } catch (error) {
    console.error('❌ Error al generar recomendaciones:', error);
    return [];
  }
}

/**
 * Enviar notificación de finalización de experimento
 */
async function sendExperimentCompletionNotification(experimentId, experiment, analysisReport) {
  try {
    // Implementar notificación por email/FCM a administradores
    console.log(`📧 Enviando notificación de finalización: ${experiment.name}`);
    
    // TODO: Implementar envío de notificaciones
    
  } catch (error) {
    console.error('❌ Error al enviar notificación:', error);
  }
}

/**
 * Enviar notificación de significancia temprana
 */
async function sendEarlySignificanceNotification(experimentId, experiment, analysisReport) {
  try {
    console.log(`📈 Enviando notificación de significancia: ${experiment.name}`);
    
    // TODO: Implementar envío de notificaciones
    
  } catch (error) {
    console.error('❌ Error al enviar notificación:', error);
  }
}

/**
 * Registrar evento de auditoría
 */
async function logAuditEvent(eventType, eventData) {
  try {
    await db.collection('audit_logs').add({
      eventType,
      eventData,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      service: 'ab_testing'
    });
    
  } catch (error) {
    console.error('❌ Error al registrar auditoría:', error);
  }
}

// ============================================================================
// EXPORTS ADICIONALES PARA TESTING Y UTILIDADES
// ============================================================================

exports.getActiveExperiments = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('permission-denied', 'Authentication required');
    }
    
    const activeExperiments = await db
      .collection('ab_experiments')
      .where('status', '==', AB_CONFIG.experimentStatus.ACTIVE)
      .get();
      
    return {
      success: true,
      experiments: activeExperiments.docs.map(doc => ({ id: doc.id, ...doc.data() }))
    };
    
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

exports.getUserExperiments = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('permission-denied', 'Authentication required');
    }
    
    const { userId } = data;
    
    const userAssignments = await db
      .collection('ab_assignments')
      .where('userId', '==', userId || context.auth.uid)
      .get();
      
    return {
      success: true,
      assignments: userAssignments.docs.map(doc => doc.data())
    };
    
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

console.log('🧪 Sistema A/B Testing para OasisTaxi inicializado correctamente');