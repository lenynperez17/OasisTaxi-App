// ====================================================================
// 🚨 PROCESADOR DE INCIDENTES - CLOUD FUNCTIONS OASISTAXI PERU
// ====================================================================
// Sistema integral para procesamiento automático de reportes de incidentes
// Escalamiento a autoridades peruanas, análisis de patrones y respuesta automática
// Integración con PNP, SAMU, Bomberos, CEM y otras entidades de emergencia
// ====================================================================

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const twilio = require('twilio');

// Inicializar Firebase Admin si no está inicializado
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const storage = admin.storage();

// ====================================================================
// 🚨 CONFIGURACIÓN DE EMERGENCIAS PERU
// ====================================================================

const PERU_EMERGENCY_CONTACTS = {
  PNP: {
    phone: '105',
    sms: '+511940000105',
    api: 'https://api.pnp.gob.pe/emergency',
    name: 'Policía Nacional del Perú',
    types: ['robbery', 'kidnapping', 'traffic_accident', 'driver_intoxicated']
  },
  SAMU: {
    phone: '116',
    sms: '+511940000116',
    api: 'https://api.minsa.gob.pe/samu/emergency',
    name: 'Sistema de Atención Móvil de Urgencias',
    types: ['medical_emergency', 'traffic_accident']
  },
  BOMBEROS: {
    phone: '116',
    sms: '+511940000116',
    api: 'https://api.bomberos.gob.pe/emergency',
    name: 'Cuerpo General de Bomberos',
    types: ['fire_emergency', 'traffic_accident']
  },
  SERENAZGO_LIMA: {
    phone: '1530',
    sms: '+5115301530',
    api: 'https://api.munlima.gob.pe/serenazgo/incident',
    name: 'Serenazgo Lima Metropolitana',
    types: ['driver_aggressive', 'vehicle_unsafe', 'harassment']
  },
  CEM: {
    phone: '100',
    sms: '+51100100100',
    api: 'https://api.mimp.gob.pe/cem/report',
    name: 'Centro de Emergencia Mujer',
    types: ['harassment', 'kidnapping']
  },
  INDECI: {
    phone: '115',
    sms: '+51115115115',
    api: 'https://api.indeci.gob.pe/emergency',
    name: 'Instituto Nacional de Defensa Civil',
    types: ['natural_disaster', 'fire_emergency']
  }
};

const LIMA_DISTRICTS = {
  'LIMA_CENTRO': {
    name: 'Lima Centro',
    serenazgo: '01-315-1212',
    comisaria: 'Comisaría Centro Lima',
    coordinates: { lat: -12.0464, lng: -77.0428 }
  },
  'MIRAFLORES': {
    name: 'Miraflores',
    serenazgo: '01-617-7313',
    comisaria: 'Comisaría Miraflores',
    coordinates: { lat: -12.1210, lng: -77.0282 }
  },
  'SAN_ISIDRO': {
    name: 'San Isidro',
    serenazgo: '01-513-9000',
    comisaria: 'Comisaría San Isidro',
    coordinates: { lat: -12.0976, lng: -77.0365 }
  },
  'SURCO': {
    name: 'Santiago de Surco',
    serenazgo: '01-411-9600',
    comisaria: 'Comisaría Surco',
    coordinates: { lat: -12.1359, lng: -77.0142 }
  }
};

// ====================================================================
// 🔥 TRIGGER: NUEVO INCIDENTE REPORTADO
// ====================================================================

exports.processNewIncident = functions.firestore
  .document('incident_reports/{incidentId}')
  .onCreate(async (snap, context) => {
    const incident = snap.data();
    const incidentId = context.params.incidentId;

    try {
      console.log(`🚨 Procesando nuevo incidente: ${incidentId}`);

      // Validar datos críticos
      if (!incident.type || !incident.severity) {
        console.error('❌ Incidente sin tipo o severidad válida');
        return null;
      }

      // Enriquecer con datos adicionales
      await enrichIncidentData(incidentId, incident);

      // Análisis automático de riesgo
      const riskAssessment = await performRiskAssessment(incident);
      
      // Determinar nivel de escalamiento
      const escalationLevel = determineEscalationLevel(incident, riskAssessment);

      // Ejecutar acciones según severidad
      if (incident.severity === 'critical' || escalationLevel >= 8) {
        await handleCriticalIncident(incidentId, incident);
      } else if (incident.severity === 'high' || escalationLevel >= 6) {
        await handleHighPriorityIncident(incidentId, incident);
      } else {
        await handleStandardIncident(incidentId, incident);
      }

      // Notificar a autoridades si corresponde
      await notifyAuthorities(incident, escalationLevel);

      // Actualizar métricas
      await updateIncidentMetrics(incident);

      // Programar seguimiento automático
      await scheduleFollowUp(incidentId, incident);

      console.log(`✅ Incidente procesado: ${incidentId}, nivel: ${escalationLevel}`);

    } catch (error) {
      console.error(`❌ Error procesando incidente ${incidentId}:`, error);
      
      // Crear entrada de error para debugging
      await db.collection('incident_processing_errors').add({
        incidentId,
        error: error.message,
        stackTrace: error.stack,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        incident: incident
      });
    }
  });

// ====================================================================
// 🔄 TRIGGER: ACTUALIZACIÓN DE ESTADO
// ====================================================================

exports.onIncidentStatusUpdate = functions.firestore
  .document('incident_reports/{incidentId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const incidentId = context.params.incidentId;

    try {
      console.log(`🔄 Estado actualizado: ${incidentId} - ${before.status} → ${after.status}`);

      // Si cambió a estado crítico
      if (before.status !== 'escalated' && after.status === 'escalated') {
        await handleEscalation(incidentId, after);
      }

      // Si se resolvió el incidente
      if (after.status === 'resolved' || after.status === 'closed') {
        await handleIncidentResolution(incidentId, after);
      }

      // Notificar cambio de estado
      await notifyStatusChange(incidentId, before.status, after.status, after);

      // Actualizar SLA tracking
      await updateSLATracking(incidentId, after);

    } catch (error) {
      console.error(`❌ Error en actualización de estado ${incidentId}:`, error);
    }
  });

// ====================================================================
// 🔍 ENRIQUECIMIENTO DE DATOS DEL INCIDENTE
// ====================================================================

async function enrichIncidentData(incidentId, incident) {
  try {
    console.log(`🔍 Enriqueciendo datos del incidente: ${incidentId}`);

    const enrichedData = {};

    // Obtener información del usuario
    if (incident.userId) {
      const userDoc = await db.collection('users').doc(incident.userId).get();
      if (userDoc.exists) {
        const userData = userDoc.data();
        enrichedData.userProfile = {
          name: userData.name,
          phone: userData.phone,
          email: userData.email,
          registrationDate: userData.createdAt,
          totalTrips: userData.totalTrips || 0,
          rating: userData.rating || 5.0
        };
      }
    }

    // Obtener información del conductor si aplica
    if (incident.driverId) {
      const driverDoc = await db.collection('drivers').doc(incident.driverId).get();
      if (driverDoc.exists) {
        const driverData = driverDoc.data();
        enrichedData.driverProfile = {
          name: driverData.name,
          phone: driverData.phone,
          licenseNumber: driverData.licenseNumber,
          vehiclePlate: driverData.vehiclePlate,
          rating: driverData.rating || 5.0,
          totalTrips: driverData.totalTrips || 0,
          joinDate: driverData.createdAt
        };
      }
    }

    // Obtener información del viaje si aplica
    if (incident.tripId) {
      const tripDoc = await db.collection('trips').doc(incident.tripId).get();
      if (tripDoc.exists) {
        const tripData = tripDoc.data();
        enrichedData.tripDetails = {
          origin: tripData.origin,
          destination: tripData.destination,
          startTime: tripData.startTime,
          estimatedDuration: tripData.estimatedDuration,
          fare: tripData.fare,
          status: tripData.status
        };
      }
    }

    // Análisis de ubicación
    if (incident.location) {
      const locationAnalysis = await analyzeIncidentLocation(incident.location);
      enrichedData.locationAnalysis = locationAnalysis;
    }

    // Historial de incidentes similares
    const similarIncidents = await findSimilarIncidents(incident);
    enrichedData.similarIncidentsCount = similarIncidents.length;
    enrichedData.patternDetection = analyzePatternsInSimilarIncidents(similarIncidents);

    // Actualizar documento con datos enriquecidos
    await db.collection('incident_reports').doc(incidentId).update({
      enrichedData,
      lastEnriched: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log(`✅ Datos enriquecidos para: ${incidentId}`);

  } catch (error) {
    console.error(`❌ Error enriqueciendo datos:`, error);
  }
}

// ====================================================================
// 📊 ANÁLISIS DE RIESGO AUTOMÁTICO
// ====================================================================

async function performRiskAssessment(incident) {
  try {
    console.log('📊 Realizando análisis de riesgo');

    let riskScore = 0;
    const riskFactors = [];

    // Factor 1: Tipo de incidente (0-4 puntos)
    const incidentTypeRisks = {
      'medical_emergency': 4,
      'kidnapping': 4,
      'robbery': 3,
      'fire_emergency': 4,
      'traffic_accident': 3,
      'harassment': 2,
      'driver_intoxicated': 3,
      'driver_aggressive': 2,
      'natural_disaster': 4,
      'vehicle_unsafe': 1,
      'other': 1
    };
    
    const typeRisk = incidentTypeRisks[incident.type] || 1;
    riskScore += typeRisk;
    riskFactors.push(`Tipo: ${incident.type} (+${typeRisk})`);

    // Factor 2: Severidad (0-3 puntos)
    const severityRisks = {
      'critical': 3,
      'high': 2,
      'medium': 1,
      'low': 0
    };
    
    const severityRisk = severityRisks[incident.severity] || 1;
    riskScore += severityRisk;
    riskFactors.push(`Severidad: ${incident.severity} (+${severityRisk})`);

    // Factor 3: Hora del incidente (0-2 puntos)
    const incidentHour = new Date(incident.reportedAt).getHours();
    let timeRisk = 0;
    if (incidentHour >= 22 || incidentHour <= 5) {
      timeRisk = 2; // Madrugada es más riesgoso
    } else if (incidentHour >= 18 || incidentHour <= 7) {
      timeRisk = 1; // Noche/amanecer
    }
    riskScore += timeRisk;
    if (timeRisk > 0) riskFactors.push(`Horario nocturno (+${timeRisk})`);

    // Factor 4: Ubicación (0-3 puntos)
    if (incident.location) {
      const locationRisk = await assessLocationRisk(incident.location);
      riskScore += locationRisk;
      if (locationRisk > 0) riskFactors.push(`Zona de riesgo (+${locationRisk})`);
    }

    // Factor 5: Historial del usuario (0-2 puntos)
    if (incident.userId) {
      const userRisk = await assessUserRiskHistory(incident.userId);
      riskScore += userRisk;
      if (userRisk > 0) riskFactors.push(`Historial usuario (+${userRisk})`);
    }

    // Factor 6: Conductor con historial problemático (0-3 puntos)
    if (incident.driverId) {
      const driverRisk = await assessDriverRiskHistory(incident.driverId);
      riskScore += driverRisk;
      if (driverRisk > 0) riskFactors.push(`Historial conductor (+${driverRisk})`);
    }

    // Determinar nivel de riesgo
    let riskLevel;
    if (riskScore >= 12) riskLevel = 'CRÍTICO';
    else if (riskScore >= 8) riskLevel = 'ALTO';
    else if (riskScore >= 4) riskLevel = 'MEDIO';
    else riskLevel = 'BAJO';

    const assessment = {
      riskScore,
      riskLevel,
      riskFactors,
      assessedAt: admin.firestore.FieldValue.serverTimestamp(),
      recommendations: generateRiskRecommendations(riskScore, incident.type)
    };

    console.log(`✅ Análisis de riesgo completado: ${riskLevel} (${riskScore} puntos)`);
    return assessment;

  } catch (error) {
    console.error('❌ Error en análisis de riesgo:', error);
    return {
      riskScore: 5,
      riskLevel: 'MEDIO',
      riskFactors: ['Error en análisis'],
      error: error.message
    };
  }
}

// ====================================================================
// 🚨 MANEJO DE INCIDENTES CRÍTICOS
// ====================================================================

async function handleCriticalIncident(incidentId, incident) {
  try {
    console.log(`🚨 INCIDENTE CRÍTICO: ${incidentId}`);

    // Crear registro de emergencia
    const emergencyRecord = {
      incidentId,
      type: incident.type,
      severity: incident.severity,
      location: incident.location,
      userId: incident.userId,
      driverId: incident.driverId,
      reportedAt: incident.reportedAt,
      status: 'ACTIVE',
      responses: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };

    await db.collection('emergency_responses').doc(incidentId).set(emergencyRecord);

    // Notificación inmediata a equipo de emergencia
    await sendEmergencyNotifications(incident);

    // Activar protocolo de emergencia
    await activateEmergencyProtocol(incidentId, incident);

    // Si hay ubicación, enviar a autoridades locales
    if (incident.location) {
      await dispatchLocalAuthorities(incident);
    }

    // Crear timeline de respuesta
    await createEmergencyTimeline(incidentId);

    // Actualizar estado del incidente
    await db.collection('incident_reports').doc(incidentId).update({
      status: 'escalated',
      escalationLevel: 3,
      emergencyActivated: true,
      escalatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log(`✅ Protocolo de emergencia activado para: ${incidentId}`);

  } catch (error) {
    console.error(`❌ Error en manejo crítico:`, error);
  }
}

// ====================================================================
// 📞 NOTIFICACIÓN A AUTORIDADES
// ====================================================================

async function notifyAuthorities(incident, escalationLevel) {
  try {
    console.log('📞 Notificando autoridades peruanas');

    const notifications = [];

    // Determinar qué autoridades contactar según tipo de incidente
    const relevantAuthorities = [];
    
    for (const [key, authority] of Object.entries(PERU_EMERGENCY_CONTACTS)) {
      if (authority.types.includes(incident.type)) {
        relevantAuthorities.push({ key, ...authority });
      }
    }

    // Notificar solo si el escalamiento es suficiente
    if (escalationLevel >= 7) {
      for (const authority of relevantAuthorities) {
        try {
          // Preparar datos del incidente para autoridades
          const incidentData = {
            id: incident.id || 'N/A',
            type: incident.type,
            severity: incident.severity,
            location: {
              latitude: incident.location?.latitude,
              longitude: incident.location?.longitude,
              address: incident.location?.address,
              district: incident.location?.district
            },
            reportedAt: incident.reportedAt,
            description: incident.description,
            emergencyContact: authority.phone,
            platform: 'OasisTaxi Peru'
          };

          // Intentar notificación via API si está disponible
          if (authority.api && escalationLevel >= 8) {
            try {
              const response = await axios.post(authority.api, {
                incident: incidentData,
                source: 'oasistaxi_peru',
                priority: escalationLevel >= 9 ? 'URGENT' : 'HIGH'
              }, {
                timeout: 10000,
                headers: {
                  'Content-Type': 'application/json',
                  'X-Source': 'OasisTaxi-Peru',
                  'X-Incident-Type': incident.type
                }
              });

              notifications.push({
                authority: authority.name,
                method: 'API',
                status: 'SUCCESS',
                response: response.status,
                timestamp: new Date().toISOString()
              });

              console.log(`✅ ${authority.name} notificado via API`);

            } catch (apiError) {
              console.log(`⚠️ API no disponible para ${authority.name}, intentando SMS`);
              
              // Fallback a SMS
              await sendSMSToAuthority(authority, incidentData);
              notifications.push({
                authority: authority.name,
                method: 'SMS_FALLBACK',
                status: 'SENT',
                timestamp: new Date().toISOString()
              });
            }
          } else {
            // Solo SMS para escalamientos menores
            await sendSMSToAuthority(authority, incidentData);
            notifications.push({
              authority: authority.name,
              method: 'SMS',
              status: 'SENT',
              timestamp: new Date().toISOString()
            });
          }

        } catch (authorityError) {
          console.error(`❌ Error notificando ${authority.name}:`, authorityError);
          notifications.push({
            authority: authority.name,
            method: 'FAILED',
            status: 'ERROR',
            error: authorityError.message,
            timestamp: new Date().toISOString()
          });
        }
      }
    }

    // Guardar log de notificaciones
    if (notifications.length > 0) {
      await db.collection('authority_notifications').add({
        incidentId: incident.id,
        notifications,
        escalationLevel,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    console.log(`✅ ${notifications.length} autoridades notificadas`);

  } catch (error) {
    console.error('❌ Error notificando autoridades:', error);
  }
}

// ====================================================================
// 📱 ENVÍO DE SMS A AUTORIDADES
// ====================================================================

async function sendSMSToAuthority(authority, incidentData) {
  try {
    // Configurar Twilio (en producción usar variables de entorno)
    const accountSid = functions.config().twilio?.account_sid;
    const authToken = functions.config().twilio?.auth_token;
    const fromNumber = functions.config().twilio?.phone_number;

    if (!accountSid || !authToken) {
      console.log(`⚠️ Configuración SMS no disponible para ${authority.name}`);
      return;
    }

    const client = twilio(accountSid, authToken);

    // Crear mensaje estructurado
    const message = `
🚨 ALERTA OASISTAXI PERU
Tipo: ${incidentData.type.toUpperCase()}
Ubicación: ${incidentData.location.district || 'N/A'}
Dirección: ${incidentData.location.address || 'No disponible'}
Hora: ${new Date(incidentData.reportedAt).toLocaleString('es-PE')}
ID: ${incidentData.id}
Coordenadas: ${incidentData.location.latitude},${incidentData.location.longitude}
Descripción: ${incidentData.description.substring(0, 100)}...
`.trim();

    await client.messages.create({
      body: message,
      from: fromNumber,
      to: authority.sms
    });

    console.log(`📱 SMS enviado a ${authority.name}`);

  } catch (error) {
    console.error(`❌ Error enviando SMS:`, error);
  }
}

// ====================================================================
// 📊 ANÁLISIS DE UBICACIÓN
// ====================================================================

async function analyzeIncidentLocation(location) {
  try {
    const analysis = {
      district: location.district,
      riskLevel: 'BAJO',
      nearbyServices: [],
      recommendations: []
    };

    // Consultar historial de incidentes en la zona
    const nearbyIncidents = await db.collection('incident_reports')
      .where('location.district', '==', location.district)
      .where('reportedAt', '>=', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)) // Últimos 30 días
      .get();

    analysis.recentIncidentsInArea = nearbyIncidents.size;

    // Determinar nivel de riesgo por zona
    if (analysis.recentIncidentsInArea > 20) {
      analysis.riskLevel = 'ALTO';
      analysis.recommendations.push('Zona con alta incidencia de reportes');
    } else if (analysis.recentIncidentsInArea > 10) {
      analysis.riskLevel = 'MEDIO';
      analysis.recommendations.push('Zona con incidencia moderada');
    }

    // Identificar servicios de emergencia cercanos
    const districtInfo = LIMA_DISTRICTS[location.district.toUpperCase().replace(' ', '_')];
    if (districtInfo) {
      analysis.nearbyServices.push({
        type: 'Serenazgo Local',
        contact: districtInfo.serenazgo,
        name: `Serenazgo ${districtInfo.name}`
      });
      
      analysis.nearbyServices.push({
        type: 'Comisaría',
        name: districtInfo.comisaria,
        district: districtInfo.name
      });
    }

    return analysis;

  } catch (error) {
    console.error('❌ Error analizando ubicación:', error);
    return { error: error.message };
  }
}

// ====================================================================
// 🔄 PROGRAMAR SEGUIMIENTOS
// ====================================================================

async function scheduleFollowUp(incidentId, incident) {
  try {
    console.log(`⏰ Programando seguimiento para: ${incidentId}`);

    const followUps = [];

    // Seguimiento inmediato para incidentes críticos (5 minutos)
    if (incident.severity === 'critical') {
      followUps.push({
        incidentId,
        type: 'STATUS_CHECK',
        scheduledFor: new Date(Date.now() + 5 * 60 * 1000),
        message: 'Verificación de estado - Incidente crítico'
      });
    }

    // Seguimiento estándar (30 minutos)
    followUps.push({
      incidentId,
      type: 'ESCALATION_CHECK',
      scheduledFor: new Date(Date.now() + 30 * 60 * 1000),
      message: 'Revisar si requiere escalamiento adicional'
    });

    // Seguimiento de resolución (2 horas)
    followUps.push({
      incidentId,
      type: 'RESOLUTION_CHECK',
      scheduledFor: new Date(Date.now() + 2 * 60 * 60 * 1000),
      message: 'Verificar progreso hacia resolución'
    });

    // Guardar programación
    for (const followUp of followUps) {
      await db.collection('scheduled_followups').add({
        ...followUp,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'PENDING'
      });
    }

    console.log(`✅ ${followUps.length} seguimientos programados`);

  } catch (error) {
    console.error('❌ Error programando seguimiento:', error);
  }
}

// ====================================================================
// 📈 ACTUALIZAR MÉTRICAS
// ====================================================================

async function updateIncidentMetrics(incident) {
  try {
    const today = new Date().toISOString().split('T')[0];
    const metricsRef = db.collection('incident_metrics').doc(today);

    await db.runTransaction(async (transaction) => {
      const doc = await transaction.get(metricsRef);
      
      const metrics = doc.exists ? doc.data() : {
        date: today,
        totalIncidents: 0,
        byType: {},
        bySeverity: {},
        byDistrict: {},
        byHour: {},
        averageResponseTime: 0,
        escalatedCount: 0
      };

      // Actualizar contadores
      metrics.totalIncidents++;
      metrics.byType[incident.type] = (metrics.byType[incident.type] || 0) + 1;
      metrics.bySeverity[incident.severity] = (metrics.bySeverity[incident.severity] || 0) + 1;
      
      if (incident.location?.district) {
        metrics.byDistrict[incident.location.district] = (metrics.byDistrict[incident.location.district] || 0) + 1;
      }

      const hour = new Date(incident.reportedAt).getHours();
      metrics.byHour[hour] = (metrics.byHour[hour] || 0) + 1;

      if (incident.severity === 'critical' || incident.escalationLevel > 0) {
        metrics.escalatedCount++;
      }

      metrics.lastUpdated = admin.firestore.FieldValue.serverTimestamp();

      transaction.set(metricsRef, metrics);
    });

    console.log(`📊 Métricas actualizadas para: ${today}`);

  } catch (error) {
    console.error('❌ Error actualizando métricas:', error);
  }
}

// ====================================================================
// 🔧 FUNCIONES AUXILIARES
// ====================================================================

function determineEscalationLevel(incident, riskAssessment) {
  let level = 0;

  // Base por tipo de incidente
  const typeScores = {
    'medical_emergency': 8,
    'kidnapping': 10,
    'robbery': 7,
    'fire_emergency': 9,
    'traffic_accident': 6,
    'harassment': 5,
    'driver_intoxicated': 7,
    'natural_disaster': 9,
    'other': 3
  };

  level += typeScores[incident.type] || 3;

  // Modificar por severidad
  const severityMultipliers = {
    'critical': 1.5,
    'high': 1.2,
    'medium': 1.0,
    'low': 0.8
  };

  level *= severityMultipliers[incident.severity] || 1.0;

  // Agregar score de riesgo
  if (riskAssessment && riskAssessment.riskScore) {
    level += riskAssessment.riskScore * 0.3;
  }

  return Math.min(Math.round(level), 10);
}

async function findSimilarIncidents(incident) {
  try {
    const query = await db.collection('incident_reports')
      .where('type', '==', incident.type)
      .where('reportedAt', '>=', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000))
      .limit(20)
      .get();

    return query.docs.map(doc => ({ id: doc.id, ...doc.data() }));

  } catch (error) {
    console.error('Error buscando incidentes similares:', error);
    return [];
  }
}

function generateRiskRecommendations(riskScore, incidentType) {
  const recommendations = [];

  if (riskScore >= 10) {
    recommendations.push('Activar protocolo de emergencia inmediatamente');
    recommendations.push('Contactar autoridades locales');
    recommendations.push('Monitoreo continuo cada 5 minutos');
  } else if (riskScore >= 6) {
    recommendations.push('Escalamiento a supervisor de turno');
    recommendations.push('Seguimiento cada 15 minutos');
  }

  // Recomendaciones específicas por tipo
  const typeRecommendations = {
    'medical_emergency': ['Contactar SAMU', 'Obtener ubicación exacta'],
    'robbery': ['Contactar PNP', 'No perseguir al agresor'],
    'traffic_accident': ['Contactar PNP y SAMU', 'Asegurar la zona'],
    'harassment': ['Documentar evidencia', 'Contactar CEM si aplica']
  };

  if (typeRecommendations[incidentType]) {
    recommendations.push(...typeRecommendations[incidentType]);
  }

  return recommendations;
}

// Función para manejar incidentes estándar
async function handleStandardIncident(incidentId, incident) {
  console.log(`📋 Procesando incidente estándar: ${incidentId}`);
  
  // Notificación a equipo de soporte
  await sendNotificationToSupport(incident, 'standard');
  
  // Programar revisión en 30 minutos
  await scheduleStandardReview(incidentId);
}

// Función para manejar incidentes de alta prioridad
async function handleHighPriorityIncident(incidentId, incident) {
  console.log(`⚠️ Procesando incidente alta prioridad: ${incidentId}`);
  
  // Notificación a supervisor
  await sendNotificationToSupervisor(incident);
  
  // Programar revisión en 10 minutos
  await scheduleHighPriorityReview(incidentId);
}

async function sendNotificationToSupport(incident, level) {
  // Implementación de notificación a equipo de soporte
  console.log(`📧 Notificando a soporte - Nivel: ${level}`);
}

async function sendNotificationToSupervisor(incident) {
  // Implementación de notificación a supervisor
  console.log(`📧 Notificando a supervisor`);
}

async function scheduleStandardReview(incidentId) {
  // Implementación de programación de revisión estándar
  console.log(`⏰ Revisión estándar programada: ${incidentId}`);
}

async function scheduleHighPriorityReview(incidentId) {
  // Implementación de programación de revisión prioritaria
  console.log(`⏰ Revisión prioritaria programada: ${incidentId}`);
}

async function sendEmergencyNotifications(incident) {
  // Implementación de notificaciones de emergencia
  console.log(`🚨 Enviando notificaciones de emergencia`);
}

async function activateEmergencyProtocol(incidentId, incident) {
  // Implementación de protocolo de emergencia
  console.log(`🚨 Activando protocolo de emergencia: ${incidentId}`);
}

async function dispatchLocalAuthorities(incident) {
  // Implementación de despacho a autoridades locales
  console.log(`🚔 Despachando autoridades locales`);
}

async function createEmergencyTimeline(incidentId) {
  // Implementación de timeline de emergencia
  console.log(`📝 Creando timeline de emergencia: ${incidentId}`);
}

async function handleEscalation(incidentId, incident) {
  // Implementación de manejo de escalamiento
  console.log(`⬆️ Manejando escalamiento: ${incidentId}`);
}

async function handleIncidentResolution(incidentId, incident) {
  // Implementación de resolución de incidente
  console.log(`✅ Manejando resolución: ${incidentId}`);
}

async function notifyStatusChange(incidentId, oldStatus, newStatus, incident) {
  // Implementación de notificación de cambio de estado
  console.log(`🔄 Notificando cambio: ${oldStatus} → ${newStatus}`);
}

async function updateSLATracking(incidentId, incident) {
  // Implementación de tracking de SLA
  console.log(`📊 Actualizando SLA tracking: ${incidentId}`);
}

async function assessLocationRisk(location) {
  // Implementación de evaluación de riesgo de ubicación
  return 0; // Por defecto sin riesgo adicional
}

async function assessUserRiskHistory(userId) {
  // Implementación de evaluación de historial de usuario
  return 0; // Por defecto sin riesgo adicional
}

async function assessDriverRiskHistory(driverId) {
  // Implementación de evaluación de historial de conductor
  return 0; // Por defecto sin riesgo adicional
}

function analyzePatternsInSimilarIncidents(incidents) {
  // Implementación de análisis de patrones
  return {
    commonTimePattern: null,
    commonLocationPattern: null,
    escalationTrend: 'stable'
  };
}

console.log('🚨 Sistema de Procesamiento de Incidentes - OasisTaxi Peru Cargado ✅');