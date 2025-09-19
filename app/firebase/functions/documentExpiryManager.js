/**
 * Cloud Function para gestión automática de vencimientos de documentos
 * Monitoreo, alertas y deshabilitación automática para documentos críticos
 * 
 * @author OasisTaxi Development Team
 * @version 1.0.0
 * @date 2025-01-11
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
const axios = require('axios');

// Inicializar Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();

// Configuración de notificaciones
const emailTransporter = nodemailer.createTransporter({
  service: 'gmail',
  auth: {
    user: functions.config().email?.user || 'notifications@oasistaxiperu.com',
    pass: functions.config().email?.password || process.env.EMAIL_PASSWORD
  }
});

/**
 * Cloud Scheduler: Verificación diaria de documentos próximos a vencer
 */
exports.dailyExpiryCheck = functions
  .runWith({
    timeoutSeconds: 540,
    memory: '1GB'
  })
  .pubsub
  .schedule('0 8 * * *') // 8:00 AM Lima diariamente
  .timeZone('America/Lima')
  .onRun(async (context) => {
    try {
      console.log('Iniciando verificación diaria de vencimientos de documentos');

      const results = {
        total_checked: 0,
        expiring_soon: 0,
        expired: 0,
        notifications_sent: 0,
        auto_disabled: 0,
        errors: []
      };

      // Tipos de documentos críticos a verificar
      const criticalDocuments = ['soat', 'license_a', 'license_b', 'technical_review'];
      
      for (const docType of criticalDocuments) {
        try {
          console.log(`Verificando documentos tipo: ${docType}`);
          
          const typeResult = await checkDocumentTypeExpiry(docType);
          
          results.total_checked += typeResult.checked;
          results.expiring_soon += typeResult.expiring_soon;
          results.expired += typeResult.expired;
          results.notifications_sent += typeResult.notifications_sent;
          results.auto_disabled += typeResult.auto_disabled;

        } catch (error) {
          console.error(`Error verificando ${docType}:`, error);
          results.errors.push(`${docType}: ${error.message}`);
        }
      }

      // Generar reporte diario
      await generateDailyExpiryReport(results);

      // Enviar alertas a administradores si hay documentos críticos
      if (results.expired > 0 || results.expiring_soon > 10) {
        await sendCriticalExpiryAlert(results);
      }

      console.log('Verificación diaria completada:', results);
      
      // Guardar estadísticas
      await db.collection('system_stats').doc('daily_expiry_check').set({
        date: admin.firestore.FieldValue.serverTimestamp(),
        results,
        execution_time: context.timestamp
      }, { merge: true });

      return results;

    } catch (error) {
      console.error('Error en verificación diaria:', error);
      
      // Alertar sobre el error del sistema
      await sendSystemErrorAlert('dailyExpiryCheck', error);
      
      throw error;
    }
  });

/**
 * Verificar documentos de un tipo específico
 */
async function checkDocumentTypeExpiry(documentType) {
  const result = {
    checked: 0,
    expiring_soon: 0,
    expired: 0,
    notifications_sent: 0,
    auto_disabled: 0
  };

  try {
    // Configuración por tipo de documento
    const documentConfig = {
      soat: {
        collection: 'drivers',
        field: 'documents.soat',
        advance_days: [45, 30, 15, 7, 3, 1],
        auto_disable_vehicle: true,
        critical: true
      },
      license_a: {
        collection: 'drivers',
        field: 'documents.license',
        advance_days: [30, 15, 7, 3, 1],
        auto_disable_driver: true,
        critical: true
      },
      license_b: {
        collection: 'drivers',
        field: 'documents.license',
        advance_days: [30, 15, 7, 3, 1],
        auto_disable_driver: true,
        critical: true
      },
      technical_review: {
        collection: 'drivers',
        field: 'documents.technical_review',
        advance_days: [30, 15, 7, 3, 1],
        auto_disable_vehicle: true,
        critical: true
      }
    };

    const config = documentConfig[documentType];
    if (!config) {
      throw new Error(`Tipo de documento no soportado: ${documentType}`);
    }

    // Consultar todos los documentos del tipo
    const snapshot = await db.collection(config.collection)
      .where(`${config.field}.status`, '==', 'approved')
      .where(`${config.field}.expiry_date`, '!=', null)
      .get();

    result.checked = snapshot.docs.length;

    for (const doc of snapshot.docs) {
      const driverData = doc.data();
      const documentData = getNestedProperty(driverData, config.field);
      
      if (!documentData || !documentData.expiry_date) {
        continue;
      }

      const expiryDate = documentData.expiry_date.toDate();
      const now = new Date();
      const daysUntilExpiry = Math.ceil((expiryDate - now) / (1000 * 60 * 60 * 24));

      // Verificar si el documento ya venció
      if (daysUntilExpiry < 0) {
        console.log(`Documento vencido: ${documentType} del conductor ${doc.id}`);
        result.expired++;
        
        // Deshabilitar automáticamente si es crítico
        if (config.auto_disable_driver || config.auto_disable_vehicle) {
          await autoDisableForExpiredDocument(doc.id, documentType, config);
          result.auto_disabled++;
        }

        // Enviar notificación de emergencia
        await sendEmergencyExpiryNotification(doc.id, documentType, daysUntilExpiry);
        result.notifications_sent++;
        
        continue;
      }

      // Verificar si está próximo a vencer
      if (config.advance_days.includes(daysUntilExpiry)) {
        console.log(`Documento próximo a vencer: ${documentType} del conductor ${doc.id} (${daysUntilExpiry} días)`);
        result.expiring_soon++;
        
        // Enviar notificación de advertencia
        await sendExpiryWarningNotification(doc.id, documentType, daysUntilExpiry);
        result.notifications_sent++;

        // Registrar advertencia en historial
        await logExpiryWarning(doc.id, documentType, daysUntilExpiry);
      }
    }

    return result;

  } catch (error) {
    console.error(`Error verificando ${documentType}:`, error);
    throw error;
  }
}

/**
 * Obtener propiedad anidada de un objeto
 */
function getNestedProperty(obj, path) {
  return path.split('.').reduce((current, key) => current && current[key], obj);
}

/**
 * Deshabilitar automáticamente conductor/vehículo por documento vencido
 */
async function autoDisableForExpiredDocument(driverId, documentType, config) {
  try {
    const batch = db.batch();
    
    // Actualizar estado del conductor
    const driverRef = db.collection('drivers').doc(driverId);
    
    if (config.auto_disable_driver) {
      batch.update(driverRef, {
        'status.active': false,
        'status.disabled_reason': `${documentType}_expired`,
        'status.disabled_at': admin.firestore.FieldValue.serverTimestamp(),
        'status.disabled_by': 'system_auto',
        'status.can_reactivate': false
      });
    }

    // Deshabilitar vehículo asociado si es necesario
    if (config.auto_disable_vehicle) {
      const driverDoc = await driverRef.get();
      const vehicleId = driverDoc.data()?.vehicle_id;
      
      if (vehicleId) {
        const vehicleRef = db.collection('vehicles').doc(vehicleId);
        batch.update(vehicleRef, {
          'status.active': false,
          'status.disabled_reason': `${documentType}_expired`,
          'status.disabled_at': admin.firestore.FieldValue.serverTimestamp(),
          'status.disabled_by': 'system_auto'
        });
      }
    }

    // Registrar acción en log de auditoría
    batch.create(db.collection('audit_logs').doc(), {
      action: 'auto_disable',
      entity_type: 'driver',
      entity_id: driverId,
      reason: `${documentType}_expired`,
      automated: true,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      details: {
        document_type: documentType,
        config: config
      }
    });

    await batch.commit();
    
    console.log(`Auto-deshabilitado conductor ${driverId} por ${documentType} vencido`);

    // Notificar al conductor sobre la deshabilitación
    await sendAutoDisableNotification(driverId, documentType);

  } catch (error) {
    console.error(`Error auto-deshabilitando conductor ${driverId}:`, error);
    throw error;
  }
}

/**
 * Enviar notificación de emergencia por documento vencido
 */
async function sendEmergencyExpiryNotification(driverId, documentType, daysExpired) {
  try {
    const driverDoc = await db.collection('drivers').doc(driverId).get();
    if (!driverDoc.exists) return;

    const driverData = driverDoc.data();
    const fcmToken = driverData.fcm_token;
    const email = driverData.email;
    const phone = driverData.phone;

    const documentNames = {
      soat: 'SOAT',
      license_a: 'Licencia de Conducir Clase A',
      license_b: 'Licencia de Conducir Clase B',
      technical_review: 'Revisión Técnica'
    };

    const title = '🚨 DOCUMENTO VENCIDO - ACCIÓN INMEDIATA REQUERIDA';
    const body = `Su ${documentNames[documentType]} venció hace ${Math.abs(daysExpired)} días. Su cuenta ha sido deshabilitada automáticamente.`;

    // Notificación push con alta prioridad
    if (fcmToken) {
      const message = {
        token: fcmToken,
        notification: {
          title,
          body,
        },
        data: {
          type: 'document_expired',
          document_type: documentType,
          days_expired: daysExpired.toString(),
          priority: 'emergency',
          action_required: 'renew_document'
        },
        android: {
          priority: 'high',
          notification: {
            priority: 'high',
            defaultSound: true,
            defaultVibrateTimings: true
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
              sound: 'default',
              badge: 1
            }
          }
        }
      };

      await messaging.send(message);
    }

    // Email de emergencia
    if (email) {
      const emailOptions = {
        from: 'noreply@oasistaxiperu.com',
        to: email,
        subject: `🚨 URGENTE: ${documentNames[documentType]} Vencido - Cuenta Deshabilitada`,
        html: generateEmergencyEmailTemplate(driverData, documentType, daysExpired)
      };

      await emailTransporter.sendMail(emailOptions);
    }

    // SMS de emergencia si está disponible
    if (phone && functions.config().sms?.enabled) {
      await sendEmergencySMS(phone, documentType, daysExpired);
    }

    // Registrar notificación enviada
    await db.collection('notifications').add({
      recipient_id: driverId,
      type: 'emergency_expiry',
      document_type: documentType,
      days_expired: daysExpired,
      channels: ['push', 'email', phone ? 'sms' : null].filter(Boolean),
      sent_at: admin.firestore.FieldValue.serverTimestamp(),
      priority: 'emergency'
    });

  } catch (error) {
    console.error(`Error enviando notificación de emergencia a ${driverId}:`, error);
  }
}

/**
 * Enviar notificación de advertencia por documento próximo a vencer
 */
async function sendExpiryWarningNotification(driverId, documentType, daysUntilExpiry) {
  try {
    const driverDoc = await db.collection('drivers').doc(driverId).get();
    if (!driverDoc.exists) return;

    const driverData = driverDoc.data();
    const fcmToken = driverData.fcm_token;
    const email = driverData.email;

    const documentNames = {
      soat: 'SOAT',
      license_a: 'Licencia de Conducir Clase A',
      license_b: 'Licencia de Conducir Clase B',
      technical_review: 'Revisión Técnica'
    };

    const urgencyLevel = daysUntilExpiry <= 3 ? 'URGENTE' : 'IMPORTANTE';
    const title = `${urgencyLevel}: ${documentNames[documentType]} vence en ${daysUntilExpiry} días`;
    const body = `Renueve su ${documentNames[documentType]} antes del vencimiento para evitar la deshabilitación de su cuenta.`;

    // Notificación push
    if (fcmToken) {
      const message = {
        token: fcmToken,
        notification: {
          title,
          body,
        },
        data: {
          type: 'document_expiring',
          document_type: documentType,
          days_until_expiry: daysUntilExpiry.toString(),
          urgency: urgencyLevel.toLowerCase(),
          action_required: 'renew_document'
        },
        android: {
          priority: daysUntilExpiry <= 3 ? 'high' : 'normal'
        }
      };

      await messaging.send(message);
    }

    // Email informativo
    if (email) {
      const emailOptions = {
        from: 'noreply@oasistaxiperu.com',
        to: email,
        subject: `${urgencyLevel}: Renovación de ${documentNames[documentType]} Requerida`,
        html: generateWarningEmailTemplate(driverData, documentType, daysUntilExpiry)
      };

      await emailTransporter.sendMail(emailOptions);
    }

    // Registrar notificación enviada
    await db.collection('notifications').add({
      recipient_id: driverId,
      type: 'expiry_warning',
      document_type: documentType,
      days_until_expiry: daysUntilExpiry,
      urgency: urgencyLevel.toLowerCase(),
      channels: ['push', 'email'],
      sent_at: admin.firestore.FieldValue.serverTimestamp()
    });

  } catch (error) {
    console.error(`Error enviando advertencia a ${driverId}:`, error);
  }
}

/**
 * Registrar advertencia de vencimiento en historial
 */
async function logExpiryWarning(driverId, documentType, daysUntilExpiry) {
  try {
    await db.collection('expiry_warnings').add({
      driver_id: driverId,
      document_type: documentType,
      days_until_expiry: daysUntilExpiry,
      warning_date: admin.firestore.FieldValue.serverTimestamp(),
      status: 'sent',
      automated: true
    });
  } catch (error) {
    console.error(`Error registrando advertencia para ${driverId}:`, error);
  }
}

/**
 * Generar reporte diario de vencimientos
 */
async function generateDailyExpiryReport(results) {
  try {
    const reportDate = new Date().toLocaleDateString('es-PE', {
      timeZone: 'America/Lima',
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });

    const report = {
      date: reportDate,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      summary: results,
      details: await getDailyExpiryDetails(),
      recommendations: generateRecommendations(results)
    };

    // Guardar reporte
    await db.collection('daily_reports').doc(`expiry_${Date.now()}`).set(report);

    // Enviar por email a administradores si hay elementos críticos
    if (results.expired > 0 || results.expiring_soon > 15) {
      await sendDailyReportEmail(report);
    }

  } catch (error) {
    console.error('Error generando reporte diario:', error);
  }
}

/**
 * Obtener detalles del reporte diario
 */
async function getDailyExpiryDetails() {
  try {
    const details = {
      expired_by_type: {},
      expiring_by_type: {},
      disabled_drivers: [],
      disabled_vehicles: []
    };

    // Consultar documentos vencidos por tipo
    const documentTypes = ['soat', 'license_a', 'license_b', 'technical_review'];
    
    for (const docType of documentTypes) {
      // Contar documentos vencidos
      const expiredQuery = await db.collection('drivers')
        .where(`documents.${docType}.expiry_date`, '<', new Date())
        .where(`documents.${docType}.status`, '==', 'approved')
        .get();
      
      details.expired_by_type[docType] = expiredQuery.docs.length;

      // Contar documentos próximos a vencer (7 días)
      const sevenDaysFromNow = new Date();
      sevenDaysFromNow.setDate(sevenDaysFromNow.getDate() + 7);
      
      const expiringQuery = await db.collection('drivers')
        .where(`documents.${docType}.expiry_date`, '<=', sevenDaysFromNow)
        .where(`documents.${docType}.expiry_date`, '>=', new Date())
        .where(`documents.${docType}.status`, '==', 'approved')
        .get();
      
      details.expiring_by_type[docType] = expiringQuery.docs.length;
    }

    // Consultar conductores deshabilitados hoy
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    
    const disabledDriversQuery = await db.collection('drivers')
      .where('status.disabled_at', '>=', todayStart)
      .where('status.disabled_by', '==', 'system_auto')
      .get();
    
    details.disabled_drivers = disabledDriversQuery.docs.map(doc => ({
      id: doc.id,
      name: doc.data().full_name,
      reason: doc.data().status?.disabled_reason,
      disabled_at: doc.data().status?.disabled_at
    }));

    return details;

  } catch (error) {
    console.error('Error obteniendo detalles del reporte:', error);
    return {};
  }
}

/**
 * Generar recomendaciones basadas en los resultados
 */
function generateRecommendations(results) {
  const recommendations = [];

  if (results.expired > 0) {
    recommendations.push({
      type: 'urgent',
      title: 'Documentos Vencidos',
      description: `${results.expired} documentos han vencido y requieren renovación inmediata.`,
      action: 'Contactar conductores afectados y proporcionar asistencia para renovación.'
    });
  }

  if (results.expiring_soon > 20) {
    recommendations.push({
      type: 'warning',
      title: 'Alto Volumen de Vencimientos',
      description: `${results.expiring_soon} documentos vencen próximamente.`,
      action: 'Implementar campaña proactiva de renovación de documentos.'
    });
  }

  if (results.auto_disabled > 5) {
    recommendations.push({
      type: 'operational',
      title: 'Impacto en Flota',
      description: `${results.auto_disabled} vehículos/conductores deshabilitados automáticamente.`,
      action: 'Revisar proceso de renovación y considerar extensiones temporales.'
    });
  }

  if (results.errors.length > 0) {
    recommendations.push({
      type: 'technical',
      title: 'Errores del Sistema',
      description: `${results.errors.length} errores detectados durante la verificación.`,
      action: 'Revisar logs del sistema y corregir problemas técnicos.'
    });
  }

  return recommendations;
}

/**
 * Enviar alerta crítica a administradores
 */
async function sendCriticalExpiryAlert(results) {
  try {
    const adminEmails = [
      'admin@oasistaxiperu.com',
      'operations@oasistaxiperu.com',
      'fleet@oasistaxiperu.com'
    ];

    const subject = `🚨 ALERTA CRÍTICA: ${results.expired} documentos vencidos, ${results.expiring_soon} próximos a vencer`;
    
    const emailOptions = {
      from: 'alerts@oasistaxiperu.com',
      to: adminEmails.join(','),
      subject,
      html: generateCriticalAlertEmailTemplate(results),
      priority: 'high'
    };

    await emailTransporter.sendMail(emailOptions);

    console.log('Alerta crítica enviada a administradores');

  } catch (error) {
    console.error('Error enviando alerta crítica:', error);
  }
}

/**
 * Enviar alerta de error del sistema
 */
async function sendSystemErrorAlert(functionName, error) {
  try {
    const adminEmails = ['tech@oasistaxiperu.com', 'admin@oasistaxiperu.com'];

    const emailOptions = {
      from: 'system@oasistaxiperu.com',
      to: adminEmails.join(','),
      subject: `🔴 ERROR DEL SISTEMA: ${functionName}`,
      html: `
        <h2>Error en Cloud Function</h2>
        <p><strong>Función:</strong> ${functionName}</p>
        <p><strong>Timestamp:</strong> ${new Date().toLocaleString('es-PE', { timeZone: 'America/Lima' })}</p>
        <p><strong>Error:</strong> ${error.message}</p>
        <pre><code>${error.stack}</code></pre>
        
        <p>Revisar logs de Cloud Functions inmediatamente.</p>
      `,
      priority: 'high'
    };

    await emailTransporter.sendMail(emailOptions);

  } catch (emailError) {
    console.error('Error enviando alerta de error del sistema:', emailError);
  }
}

/**
 * Plantilla de email de emergencia
 */
function generateEmergencyEmailTemplate(driverData, documentType, daysExpired) {
  const documentNames = {
    soat: 'SOAT',
    license_a: 'Licencia de Conducir Clase A',
    license_b: 'Licencia de Conducir Clase B',
    technical_review: 'Revisión Técnica'
  };

  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        .container { max-width: 600px; margin: 0 auto; font-family: Arial, sans-serif; }
        .header { background-color: #dc3545; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; }
        .alert { background-color: #f8d7da; border: 1px solid #f5c6cb; padding: 15px; margin: 15px 0; border-radius: 5px; }
        .btn { background-color: #28a745; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 10px 0; }
        .footer { background-color: #f8f9fa; padding: 15px; text-align: center; font-size: 12px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>🚨 DOCUMENTO VENCIDO</h1>
          <p>ACCIÓN INMEDIATA REQUERIDA</p>
        </div>
        
        <div class="content">
          <p>Estimado/a <strong>${driverData.full_name}</strong>,</p>
          
          <div class="alert">
            <h3>⚠️ Su ${documentNames[documentType]} ha vencido</h3>
            <p>Venció hace <strong>${Math.abs(daysExpired)} días</strong></p>
            <p>Su cuenta ha sido <strong>deshabilitada automáticamente</strong> hasta que renueve este documento.</p>
          </div>
          
          <h3>¿Qué significa esto?</h3>
          <ul>
            <li>No puede recibir viajes hasta renovar su documento</li>
            <li>Su vehículo no puede operar en la plataforma</li>
            <li>Debe renovar el documento inmediatamente</li>
          </ul>
          
          <h3>¿Qué debe hacer?</h3>
          <ol>
            <li>Renovar su ${documentNames[documentType]} inmediatamente</li>
            <li>Subir el nuevo documento a la aplicación</li>
            <li>Esperar la verificación (24-48 horas)</li>
            <li>Su cuenta será reactivada automáticamente</li>
          </ol>
          
          <a href="https://app.oasistaxiperu.com/documents/upload" class="btn">Renovar Documento Ahora</a>
          
          <p><strong>¿Necesita ayuda?</strong></p>
          <p>Contacte nuestro soporte: <a href="tel:+51987654321">+51 987 654 321</a></p>
        </div>
        
        <div class="footer">
          <p>OasisTaxi Perú - Sistema Automático de Notificaciones</p>
          <p>Este mensaje fue enviado automáticamente</p>
        </div>
      </div>
    </body>
    </html>
  `;
}

/**
 * Plantilla de email de advertencia
 */
function generateWarningEmailTemplate(driverData, documentType, daysUntilExpiry) {
  const documentNames = {
    soat: 'SOAT',
    license_a: 'Licencia de Conducir Clase A',
    license_b: 'Licencia de Conducir Clase B',
    technical_review: 'Revisión Técnica'
  };

  const urgencyColor = daysUntilExpiry <= 3 ? '#dc3545' : '#ffc107';
  const urgencyText = daysUntilExpiry <= 3 ? 'URGENTE' : 'IMPORTANTE';

  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        .container { max-width: 600px; margin: 0 auto; font-family: Arial, sans-serif; }
        .header { background-color: ${urgencyColor}; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; }
        .warning { background-color: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; margin: 15px 0; border-radius: 5px; }
        .btn { background-color: #007bff; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 10px 0; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>${urgencyText}</h1>
          <p>${documentNames[documentType]} vence en ${daysUntilExpiry} días</p>
        </div>
        
        <div class="content">
          <p>Estimado/a <strong>${driverData.full_name}</strong>,</p>
          
          <div class="warning">
            <h3>⚠️ Renovación de Documento Requerida</h3>
            <p>Su ${documentNames[documentType]} vence en <strong>${daysUntilExpiry} días</strong></p>
          </div>
          
          <h3>Para evitar la deshabilitación:</h3>
          <ol>
            <li>Renueve su ${documentNames[documentType]} antes del vencimiento</li>
            <li>Suba el nuevo documento a la aplicación</li>
            <li>Nuestro equipo lo verificará en 24-48 horas</li>
          </ol>
          
          <a href="https://app.oasistaxiperu.com/documents/upload" class="btn">Renovar Ahora</a>
          
          <p><em>Recuerde: Si no renueva a tiempo, su cuenta será deshabilitada automáticamente.</em></p>
        </div>
      </div>
    </body>
    </html>
  `;
}

/**
 * Plantilla de email de alerta crítica para administradores
 */
function generateCriticalAlertEmailTemplate(results) {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        .container { max-width: 800px; margin: 0 auto; font-family: Arial, sans-serif; }
        .header { background-color: #dc3545; color: white; padding: 20px; text-align: center; }
        .stats { display: flex; justify-content: space-around; padding: 20px; }
        .stat { text-align: center; }
        .stat-number { font-size: 2em; font-weight: bold; color: #dc3545; }
        .errors { background-color: #f8d7da; padding: 15px; margin: 15px 0; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>🚨 ALERTA CRÍTICA DEL SISTEMA</h1>
          <p>Verificación Diaria de Documentos - ${new Date().toLocaleDateString('es-PE')}</p>
        </div>
        
        <div class="stats">
          <div class="stat">
            <div class="stat-number">${results.expired}</div>
            <div>Documentos Vencidos</div>
          </div>
          <div class="stat">
            <div class="stat-number">${results.expiring_soon}</div>
            <div>Próximos a Vencer</div>
          </div>
          <div class="stat">
            <div class="stat-number">${results.auto_disabled}</div>
            <div>Auto-Deshabilitados</div>
          </div>
        </div>
        
        <div class="content">
          <h2>Resumen de Verificación</h2>
          <ul>
            <li><strong>Total Verificados:</strong> ${results.total_checked}</li>
            <li><strong>Notificaciones Enviadas:</strong> ${results.notifications_sent}</li>
            <li><strong>Conductores/Vehículos Deshabilitados:</strong> ${results.auto_disabled}</li>
          </ul>
          
          ${results.errors.length > 0 ? `
            <div class="errors">
              <h3>❌ Errores Detectados</h3>
              <ul>
                ${results.errors.map(error => `<li>${error}</li>`).join('')}
              </ul>
            </div>
          ` : ''}
          
          <h2>Acción Requerida</h2>
          <p>Revisar el dashboard de administración y contactar conductores afectados.</p>
          <p><a href="https://admin.oasistaxiperu.com/documents/expiry">Ver Dashboard Completo</a></p>
        </div>
      </div>
    </body>
    </html>
  `;
}

/**
 * Enviar notificación de deshabilitación automática
 */
async function sendAutoDisableNotification(driverId, documentType) {
  try {
    const driverDoc = await db.collection('drivers').doc(driverId).get();
    if (!driverDoc.exists) return;

    const driverData = driverDoc.data();
    const fcmToken = driverData.fcm_token;

    if (fcmToken) {
      const message = {
        token: fcmToken,
        notification: {
          title: '🚫 Cuenta Deshabilitada',
          body: 'Su cuenta ha sido deshabilitada automáticamente por documento vencido. Renueve inmediatamente.',
        },
        data: {
          type: 'account_disabled',
          reason: `${documentType}_expired`,
          action_required: 'renew_document_urgent'
        },
        android: {
          priority: 'high'
        }
      };

      await messaging.send(message);
    }

  } catch (error) {
    console.error(`Error enviando notificación de deshabilitación a ${driverId}:`, error);
  }
}

/**
 * Enviar SMS de emergencia
 */
async function sendEmergencySMS(phone, documentType, daysExpired) {
  try {
    // Integración con proveedor SMS (ejemplo: Twilio)
    const smsBody = `ALERTA OASIS TAXI: Su ${documentType} venció hace ${Math.abs(daysExpired)} días. Cuenta deshabilitada. Renueve INMEDIATAMENTE. +51987654321`;
    
    // Aquí iría la integración con el proveedor SMS
    console.log(`SMS enviado a ${phone}: ${smsBody}`);
    
  } catch (error) {
    console.error(`Error enviando SMS a ${phone}:`, error);
  }
}

/**
 * Cloud Function HTTP para verificación manual
 */
exports.manualExpiryCheck = functions.https.onCall(async (data, context) => {
  try {
    // Verificar autenticación y permisos de admin
    if (!context.auth || !context.auth.token.admin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Solo administradores pueden ejecutar verificación manual'
      );
    }

    const { documentType, driverId } = data;

    if (driverId) {
      // Verificar conductor específico
      const result = await checkSpecificDriverDocuments(driverId);
      return { success: true, result };
    } else if (documentType) {
      // Verificar tipo de documento específico
      const result = await checkDocumentTypeExpiry(documentType);
      return { success: true, result };
    } else {
      // Verificación completa
      const results = await Promise.all([
        checkDocumentTypeExpiry('soat'),
        checkDocumentTypeExpiry('license_a'),
        checkDocumentTypeExpiry('license_b'),
        checkDocumentTypeExpiry('technical_review')
      ]);

      return { success: true, results };
    }

  } catch (error) {
    console.error('Error en verificación manual:', error);
    throw new functions.https.HttpsError(
      'internal',
      `Error en verificación manual: ${error.message}`
    );
  }
});

/**
 * Verificar documentos de un conductor específico
 */
async function checkSpecificDriverDocuments(driverId) {
  try {
    const driverDoc = await db.collection('drivers').doc(driverId).get();
    
    if (!driverDoc.exists) {
      throw new Error(`Conductor ${driverId} no encontrado`);
    }

    const driverData = driverDoc.data();
    const documents = driverData.documents || {};
    
    const results = {
      driver_id: driverId,
      driver_name: driverData.full_name,
      checked_documents: [],
      expired: [],
      expiring_soon: [],
      notifications_sent: 0
    };

    // Verificar cada tipo de documento
    const documentTypes = ['soat', 'license', 'technical_review', 'criminal_record'];
    
    for (const docType of documentTypes) {
      const docData = documents[docType];
      
      if (!docData || !docData.expiry_date) {
        results.checked_documents.push({
          type: docType,
          status: 'missing',
          message: 'Documento no encontrado o sin fecha de vencimiento'
        });
        continue;
      }

      const expiryDate = docData.expiry_date.toDate();
      const now = new Date();
      const daysUntilExpiry = Math.ceil((expiryDate - now) / (1000 * 60 * 60 * 24));

      results.checked_documents.push({
        type: docType,
        expiry_date: expiryDate.toLocaleDateString('es-PE'),
        days_until_expiry: daysUntilExpiry,
        status: daysUntilExpiry < 0 ? 'expired' : daysUntilExpiry <= 7 ? 'expiring_soon' : 'valid'
      });

      if (daysUntilExpiry < 0) {
        results.expired.push(docType);
      } else if (daysUntilExpiry <= 7) {
        results.expiring_soon.push(docType);
        
        // Enviar notificación
        await sendExpiryWarningNotification(driverId, docType, daysUntilExpiry);
        results.notifications_sent++;
      }
    }

    return results;

  } catch (error) {
    console.error(`Error verificando conductor ${driverId}:`, error);
    throw error;
  }
}

/**
 * Cloud Function para obtener estadísticas de vencimientos
 */
exports.getExpiryStats = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Usuario debe estar autenticado'
      );
    }

    const { period = '30d', admin_view = false } = data;

    // Verificar permisos para vista de admin
    if (admin_view && !context.auth.token.admin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Solo administradores pueden ver estadísticas completas'
      );
    }

    const stats = {
      period,
      generated_at: admin.firestore.FieldValue.serverTimestamp(),
      document_types: {},
      summary: {
        total_active_drivers: 0,
        documents_expiring_30d: 0,
        documents_expiring_7d: 0,
        documents_expired: 0,
        auto_disabled_count: 0
      }
    };

    // Calcular fechas
    const now = new Date();
    const thirtyDaysFromNow = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
    const sevenDaysFromNow = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

    // Obtener estadísticas por tipo de documento
    const documentTypes = ['soat', 'license', 'technical_review'];
    
    for (const docType of documentTypes) {
      const typeStats = {
        total: 0,
        expired: 0,
        expiring_7d: 0,
        expiring_30d: 0,
        valid: 0
      };

      // Consultar documentos
      const snapshot = await db.collection('drivers')
        .where(`documents.${docType}.status`, '==', 'approved')
        .get();

      for (const doc of snapshot.docs) {
        const driverData = doc.data();
        const docData = getNestedProperty(driverData, `documents.${docType}`);
        
        if (!docData || !docData.expiry_date) continue;

        typeStats.total++;
        const expiryDate = docData.expiry_date.toDate();

        if (expiryDate < now) {
          typeStats.expired++;
        } else if (expiryDate <= sevenDaysFromNow) {
          typeStats.expiring_7d++;
        } else if (expiryDate <= thirtyDaysFromNow) {
          typeStats.expiring_30d++;
        } else {
          typeStats.valid++;
        }
      }

      stats.document_types[docType] = typeStats;
      
      // Agregar a resumen
      stats.summary.documents_expired += typeStats.expired;
      stats.summary.documents_expiring_7d += typeStats.expiring_7d;
      stats.summary.documents_expiring_30d += typeStats.expiring_30d;
    }

    // Contar conductores activos
    const activeDriversSnapshot = await db.collection('drivers')
      .where('status.active', '==', true)
      .get();
    
    stats.summary.total_active_drivers = activeDriversSnapshot.docs.length;

    // Contar deshabilitados automáticamente (último mes)
    const lastMonth = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    
    const autoDisabledSnapshot = await db.collection('drivers')
      .where('status.disabled_by', '==', 'system_auto')
      .where('status.disabled_at', '>=', lastMonth)
      .get();
    
    stats.summary.auto_disabled_count = autoDisabledSnapshot.docs.length;

    return stats;

  } catch (error) {
    console.error('Error obteniendo estadísticas:', error);
    throw new functions.https.HttpsError(
      'internal',
      `Error obteniendo estadísticas: ${error.message}`
    );
  }
});

module.exports = {
  dailyExpiryCheck: exports.dailyExpiryCheck,
  manualExpiryCheck: exports.manualExpiryCheck,
  getExpiryStats: exports.getExpiryStats
};