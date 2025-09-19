const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { google } = require('googleapis');
const archiver = require('archiver');
const fs = require('fs');
const path = require('path');
const { Storage } = require('@google-cloud/storage');

// Inicialización de Firebase Admin si no está inicializado
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const storage = new Storage();

/**
 * Firebase App Distribution Manager
 * Sistema profesional de distribución de aplicaciones para testing
 * 
 * Características:
 * - Distribución automática de builds de testing
 * - Gestión de grupos de testers
 * - Release notes automáticos
 * - Integración con CI/CD
 * - Notificaciones a testers
 * - Analytics de testing
 * - Feedback collection
 * - Version management
 * - Device compatibility checking
 * - Crash reporting integration
 */

// Configuración de App Distribution
const APP_DISTRIBUTION_CONFIG = {
  projectId: 'oasis-taxi-peru',
  androidAppId: '1:123456789:android:abcd1234efgh5678',
  iosAppId: '1:123456789:ios:abcd1234efgh5678',
  bucketName: 'oasis-taxi-peru.appspot.com',
  testBuildsBucket: 'oasis-taxi-test-builds',
  groups: {
    internal: 'internal-testers',
    beta: 'beta-testers',
    drivers: 'driver-testers',
    admin: 'admin-testers',
    qa: 'qa-team'
  },
  credentials: {
    type: 'service_account',
    project_id: 'oasis-taxi-peru',
    private_key_id: functions.config().app_distribution?.key_id || process.env.APP_DIST_KEY_ID,
    private_key: (functions.config().app_distribution?.private_key || process.env.APP_DIST_PRIVATE_KEY)?.replace(/\\n/g, '\n'),
    client_email: functions.config().app_distribution?.client_email || process.env.APP_DIST_CLIENT_EMAIL,
    client_id: functions.config().app_distribution?.client_id || process.env.APP_DIST_CLIENT_ID,
    auth_uri: 'https://accounts.google.com/o/oauth2/auth',
    token_uri: 'https://oauth2.googleapis.com/token',
  }
};

// Estados de distribución
const DISTRIBUTION_STATUS = {
  PENDING: 'pending',
  UPLOADING: 'uploading',
  PROCESSING: 'processing',
  DISTRIBUTING: 'distributing',
  COMPLETED: 'completed',
  FAILED: 'failed'
};

// Tipos de builds
const BUILD_TYPES = {
  DEBUG: 'debug',
  RELEASE: 'release',
  PROFILE: 'profile'
};

// Grupos de testers predefinidos
const TESTER_GROUPS = {
  internal: {
    name: 'Internal Testers',
    description: 'Equipo interno de desarrollo',
    emails: [
      'dev1@oasistaxiperu.com',
      'dev2@oasistaxiperu.com',
      'manager@oasistaxiperu.com'
    ]
  },
  beta: {
    name: 'Beta Testers',
    description: 'Usuarios beta externos',
    emails: [
      'beta1@gmail.com',
      'beta2@gmail.com',
      'beta3@gmail.com'
    ]
  },
  drivers: {
    name: 'Driver Testers',
    description: 'Conductores para testing',
    emails: [
      'driver1@gmail.com',
      'driver2@gmail.com'
    ]
  },
  qa: {
    name: 'QA Team',
    description: 'Equipo de control de calidad',
    emails: [
      'qa1@oasistaxiperu.com',
      'qa2@oasistaxiperu.com'
    ]
  }
};

/**
 * Crear nueva distribución de app
 */
exports.createAppDistribution = functions
  .runWith({
    timeoutSeconds: 540,
    memory: '2GB'
  })
  .https.onCall(async (data, context) => {
    try {
      // Verificar autenticación de admin o CI
      if (!context.auth || (!context.auth.token.admin && !context.auth.token.ci)) {
        throw new functions.https.HttpsError('permission-denied', 'Requiere permisos de administrador o CI');
      }

      const {
        platform, // 'android' o 'ios'
        buildType, // 'debug', 'release', 'profile'
        version,
        buildNumber,
        releaseNotes,
        testerGroups = ['internal'],
        notifyTesters = true,
        apkUrl, // URL del APK/IPA en Storage
        metadata = {}
      } = data;

      // Validaciones
      if (!platform || !['android', 'ios'].includes(platform)) {
        throw new functions.https.HttpsError('invalid-argument', 'Plataforma debe ser android o ios');
      }

      if (!buildType || !Object.values(BUILD_TYPES).includes(buildType)) {
        throw new functions.https.HttpsError('invalid-argument', 'Tipo de build inválido');
      }

      if (!version || !buildNumber) {
        throw new functions.https.HttpsError('invalid-argument', 'Version y buildNumber son requeridos');
      }

      if (!apkUrl) {
        throw new functions.https.HttpsError('invalid-argument', 'URL del archivo es requerida');
      }

      // Crear documento de distribución
      const distributionRef = db.collection('appDistributions').doc();
      const distributionData = {
        id: distributionRef.id,
        platform,
        buildType,
        version,
        buildNumber,
        releaseNotes: releaseNotes || '',
        testerGroups: testerGroups,
        notifyTesters,
        apkUrl,
        metadata,
        status: DISTRIBUTION_STATUS.PENDING,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: context.auth.uid,
        stats: {
          totalTesters: 0,
          downloads: 0,
          installs: 0,
          crashes: 0,
          feedbackCount: 0
        }
      };

      await distributionRef.set(distributionData);

      // Iniciar proceso de distribución
      const result = await processAppDistribution(distributionRef.id, distributionData);

      return {
        success: true,
        distributionId: distributionRef.id,
        status: result.status,
        message: 'Distribución creada e iniciada exitosamente'
      };

    } catch (error) {
      console.error('Error creando distribución:', error);
      throw new functions.https.HttpsError('internal', 'Error interno del servidor');
    }
  });

/**
 * Procesar distribución de aplicación
 */
async function processAppDistribution(distributionId, distributionData) {
  try {
    const distributionRef = db.collection('appDistributions').doc(distributionId);

    // Actualizar status a uploading
    await distributionRef.update({
      status: DISTRIBUTION_STATUS.UPLOADING,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Obtener archivo del Storage
    const fileInfo = await downloadBuildFile(distributionData.apkUrl);
    
    if (!fileInfo.success) {
      throw new Error(`Error descargando archivo: ${fileInfo.error}`);
    }

    // Actualizar status a processing
    await distributionRef.update({
      status: DISTRIBUTION_STATUS.PROCESSING,
      fileSize: fileInfo.size,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Crear cliente de App Distribution
    const appDistributionClient = await createAppDistributionClient();

    // Subir aplicación a App Distribution
    const uploadResult = await uploadToAppDistribution(
      appDistributionClient,
      distributionData,
      fileInfo.filePath
    );

    if (!uploadResult.success) {
      throw new Error(`Error subiendo a App Distribution: ${uploadResult.error}`);
    }

    // Actualizar status a distributing
    await distributionRef.update({
      status: DISTRIBUTION_STATUS.DISTRIBUTING,
      releaseId: uploadResult.releaseId,
      downloadUrl: uploadResult.downloadUrl,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Distribuir a grupos de testers
    const distributionResult = await distributeToTesterGroups(
      appDistributionClient,
      uploadResult.releaseId,
      distributionData.testerGroups,
      distributionData.notifyTesters
    );

    // Limpiar archivo temporal
    fs.unlinkSync(fileInfo.filePath);

    // Actualizar status final
    const finalStatus = distributionResult.success ? 
      DISTRIBUTION_STATUS.COMPLETED : DISTRIBUTION_STATUS.FAILED;

    await distributionRef.update({
      status: finalStatus,
      'stats.totalTesters': distributionResult.totalTesters || 0,
      distributionResult: distributionResult,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log(`Distribución ${distributionId} completada con status: ${finalStatus}`);

    return {
      success: distributionResult.success,
      status: finalStatus,
      releaseId: uploadResult.releaseId,
      totalTesters: distributionResult.totalTesters
    };

  } catch (error) {
    console.error(`Error procesando distribución ${distributionId}:`, error);
    
    // Actualizar status a failed
    await db.collection('appDistributions').doc(distributionId).update({
      status: DISTRIBUTION_STATUS.FAILED,
      error: error.message,
      failedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return {
      success: false,
      status: DISTRIBUTION_STATUS.FAILED,
      error: error.message
    };
  }
}

/**
 * Descargar archivo de build desde Storage
 */
async function downloadBuildFile(fileUrl) {
  try {
    const bucket = storage.bucket(APP_DISTRIBUTION_CONFIG.bucketName);
    
    // Extraer path del archivo desde la URL
    const urlParts = fileUrl.split('/');
    const fileName = urlParts[urlParts.length - 1];
    const filePath = `/tmp/${fileName}`;
    
    // Descargar archivo
    const file = bucket.file(fileName);
    await file.download({ destination: filePath });
    
    // Obtener información del archivo
    const stats = fs.statSync(filePath);
    
    return {
      success: true,
      filePath: filePath,
      size: stats.size,
      fileName: fileName
    };

  } catch (error) {
    console.error('Error descargando build file:', error);
    return {
      success: false,
      error: error.message
    };
  }
}

/**
 * Crear cliente de App Distribution API
 */
async function createAppDistributionClient() {
  const auth = new google.auth.GoogleAuth({
    credentials: APP_DISTRIBUTION_CONFIG.credentials,
    scopes: ['https://www.googleapis.com/auth/cloud-platform']
  });

  const authClient = await auth.getClient();
  
  return google.firebaseappdistribution({
    version: 'v1',
    auth: authClient
  });
}

/**
 * Subir aplicación a App Distribution
 */
async function uploadToAppDistribution(client, distributionData, filePath) {
  try {
    const appId = distributionData.platform === 'android' ? 
      APP_DISTRIBUTION_CONFIG.androidAppId : 
      APP_DISTRIBUTION_CONFIG.iosAppId;

    // Crear release
    const releaseResponse = await client.projects.apps.releases.create({
      parent: `projects/${APP_DISTRIBUTION_CONFIG.projectId}/apps/${appId}`,
      requestBody: {
        releaseNotes: {
          text: distributionData.releaseNotes || `Version ${distributionData.version} (${distributionData.buildNumber})`
        }
      },
      media: {
        mimeType: distributionData.platform === 'android' ? 'application/vnd.android.package-archive' : 'application/octet-stream',
        body: fs.createReadStream(filePath)
      }
    });

    const releaseId = releaseResponse.data.name;
    const downloadUrl = releaseResponse.data.downloadUrl;

    console.log(`App subida a App Distribution - Release ID: ${releaseId}`);

    return {
      success: true,
      releaseId: releaseId,
      downloadUrl: downloadUrl
    };

  } catch (error) {
    console.error('Error subiendo a App Distribution:', error);
    return {
      success: false,
      error: error.message
    };
  }
}

/**
 * Distribuir a grupos de testers
 */
async function distributeToTesterGroups(client, releaseId, testerGroups, notifyTesters) {
  try {
    let totalTesters = 0;
    const results = [];

    for (const groupName of testerGroups) {
      try {
        // Obtener emails del grupo
        const groupEmails = TESTER_GROUPS[groupName]?.emails || [];
        
        if (groupEmails.length === 0) {
          console.warn(`Grupo ${groupName} no tiene testers configurados`);
          continue;
        }

        // Distribuir a grupo
        const distributionResponse = await client.projects.apps.releases.distribute({
          name: releaseId,
          requestBody: {
            testerEmails: groupEmails,
            notify: notifyTesters
          }
        });

        totalTesters += groupEmails.length;
        results.push({
          group: groupName,
          success: true,
          testerCount: groupEmails.length,
          response: distributionResponse.data
        });

        console.log(`Distribuido a grupo ${groupName}: ${groupEmails.length} testers`);

      } catch (error) {
        console.error(`Error distribuyendo a grupo ${groupName}:`, error);
        results.push({
          group: groupName,
          success: false,
          error: error.message
        });
      }
    }

    return {
      success: results.some(r => r.success),
      totalTesters: totalTesters,
      groupResults: results
    };

  } catch (error) {
    console.error('Error distribuyendo a testers:', error);
    return {
      success: false,
      error: error.message
    };
  }
}

/**
 * Gestionar grupos de testers
 */
exports.manageTesterGroups = functions
  .runWith({
    timeoutSeconds: 300,
    memory: '512MB'
  })
  .https.onCall(async (data, context) => {
    try {
      if (!context.auth || !context.auth.token.admin) {
        throw new functions.https.HttpsError('permission-denied', 'Requiere permisos de administrador');
      }

      const {
        action, // 'create', 'update', 'delete', 'list', 'addTesters', 'removeTesters'
        groupName,
        groupData,
        testerEmails
      } = data;

      let result = {};

      switch (action) {
        case 'create':
          result = await createTesterGroup(groupName, groupData);
          break;
        
        case 'update':
          result = await updateTesterGroup(groupName, groupData);
          break;
        
        case 'delete':
          result = await deleteTesterGroup(groupName);
          break;
        
        case 'list':
          result = await listTesterGroups();
          break;
        
        case 'addTesters':
          result = await addTestersToGroup(groupName, testerEmails);
          break;
        
        case 'removeTesters':
          result = await removeTestersFromGroup(groupName, testerEmails);
          break;
        
        default:
          throw new functions.https.HttpsError('invalid-argument', 'Acción no válida');
      }

      return {
        success: true,
        action: action,
        result: result
      };

    } catch (error) {
      console.error('Error gestionando grupos de testers:', error);
      throw new functions.https.HttpsError('internal', 'Error interno del servidor');
    }
  });

/**
 * Crear grupo de testers
 */
async function createTesterGroup(groupName, groupData) {
  const groupRef = db.collection('testerGroups').doc(groupName);
  
  const data = {
    name: groupData.name || groupName,
    description: groupData.description || '',
    emails: groupData.emails || [],
    isActive: groupData.isActive !== false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  await groupRef.set(data);
  
  return {
    groupName: groupName,
    testerCount: data.emails.length
  };
}

/**
 * Obtener estadísticas de distribución
 */
exports.getDistributionStats = functions
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
        startDate,
        endDate,
        platform = null,
        buildType = null
      } = data;

      let query = db.collection('appDistributions');

      if (startDate) {
        query = query.where('createdAt', '>=', admin.firestore.Timestamp.fromDate(new Date(startDate)));
      }

      if (endDate) {
        query = query.where('createdAt', '<=', admin.firestore.Timestamp.fromDate(new Date(endDate)));
      }

      if (platform) {
        query = query.where('platform', '==', platform);
      }

      if (buildType) {
        query = query.where('buildType', '==', buildType);
      }

      const distributionsSnapshot = await query.orderBy('createdAt', 'desc').get();

      const stats = {
        totalDistributions: distributionsSnapshot.size,
        statusBreakdown: {},
        platformBreakdown: {},
        buildTypeBreakdown: {},
        totalDownloads: 0,
        totalInstalls: 0,
        totalCrashes: 0,
        totalFeedback: 0,
        recentDistributions: []
      };

      distributionsSnapshot.forEach(doc => {
        const data = doc.data();
        
        // Status breakdown
        stats.statusBreakdown[data.status] = (stats.statusBreakdown[data.status] || 0) + 1;
        
        // Platform breakdown
        stats.platformBreakdown[data.platform] = (stats.platformBreakdown[data.platform] || 0) + 1;
        
        // Build type breakdown
        stats.buildTypeBreakdown[data.buildType] = (stats.buildTypeBreakdown[data.buildType] || 0) + 1;
        
        // Totales
        if (data.stats) {
          stats.totalDownloads += data.stats.downloads || 0;
          stats.totalInstalls += data.stats.installs || 0;
          stats.totalCrashes += data.stats.crashes || 0;
          stats.totalFeedback += data.stats.feedbackCount || 0;
        }

        // Distribuciones recientes
        if (stats.recentDistributions.length < 10) {
          stats.recentDistributions.push({
            id: doc.id,
            version: data.version,
            buildNumber: data.buildNumber,
            platform: data.platform,
            status: data.status,
            createdAt: data.createdAt?.toDate().toISOString()
          });
        }
      });

      return {
        success: true,
        stats: stats,
        period: {
          startDate: startDate,
          endDate: endDate
        }
      };

    } catch (error) {
      console.error('Error obteniendo estadísticas:', error);
      throw new functions.https.HttpsError('internal', 'Error interno del servidor');
    }
  });

/**
 * Webhook para eventos de App Distribution
 */
exports.handleAppDistributionWebhook = functions
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
      console.log('App Distribution webhook recibido:', event.eventType);

      // Verificar signature si está configurada
      // TODO: Implementar verificación de signature

      await processAppDistributionEvent(event);

      res.status(200).json({ message: 'Evento procesado exitosamente' });

    } catch (error) {
      console.error('Error en webhook App Distribution:', error);
      res.status(500).json({ error: 'Error interno del servidor' });
    }
  });

/**
 * Procesar evento de App Distribution
 */
async function processAppDistributionEvent(event) {
  try {
    const { eventType, releaseId, appId, testerEmail, timestamp } = event;

    // Buscar distribución correspondiente
    const distributionsSnapshot = await db.collection('appDistributions')
      .where('releaseId', '==', releaseId)
      .limit(1)
      .get();

    if (distributionsSnapshot.empty) {
      console.warn(`Distribución no encontrada para release: ${releaseId}`);
      return;
    }

    const distributionDoc = distributionsSnapshot.docs[0];
    const distributionRef = distributionDoc.ref;

    // Procesar según tipo de evento
    switch (eventType) {
      case 'downloaded':
        await distributionRef.update({
          'stats.downloads': admin.firestore.FieldValue.increment(1),
          lastDownloadAt: admin.firestore.FieldValue.serverTimestamp()
        });
        break;
      
      case 'installed':
        await distributionRef.update({
          'stats.installs': admin.firestore.FieldValue.increment(1),
          lastInstallAt: admin.firestore.FieldValue.serverTimestamp()
        });
        break;
      
      case 'feedback_submitted':
        await distributionRef.update({
          'stats.feedbackCount': admin.firestore.FieldValue.increment(1),
          lastFeedbackAt: admin.firestore.FieldValue.serverTimestamp()
        });
        break;
    }

    // Registrar evento individual
    await db.collection('appDistributionEvents').add({
      distributionId: distributionDoc.id,
      releaseId: releaseId,
      eventType: eventType,
      testerEmail: testerEmail,
      timestamp: admin.firestore.Timestamp.fromDate(new Date(timestamp)),
      processedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log(`Evento App Distribution procesado: ${eventType} para release ${releaseId}`);

  } catch (error) {
    console.error('Error procesando evento App Distribution:', error);
  }
}

/**
 * Generar reporte de testing
 */
exports.generateTestingReport = functions
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
        distributionId,
        includeEvents = true,
        includeFeedback = true,
        includeCrashData = true
      } = data;

      // Obtener distribución
      const distributionDoc = await db.collection('appDistributions').doc(distributionId).get();
      
      if (!distributionDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Distribución no encontrada');
      }

      const distribution = distributionDoc.data();
      const report = {
        distribution: {
          id: distributionDoc.id,
          ...distribution,
          createdAt: distribution.createdAt?.toDate().toISOString(),
          completedAt: distribution.completedAt?.toDate().toISOString()
        },
        events: [],
        feedback: [],
        crashData: {},
        summary: {}
      };

      // Obtener eventos si solicitado
      if (includeEvents) {
        const eventsSnapshot = await db.collection('appDistributionEvents')
          .where('distributionId', '==', distributionId)
          .orderBy('timestamp', 'desc')
          .get();

        report.events = eventsSnapshot.docs.map(doc => ({
          id: doc.id,
          ...doc.data(),
          timestamp: doc.data().timestamp?.toDate().toISOString()
        }));
      }

      // Obtener feedback si solicitado
      if (includeFeedback) {
        const feedbackSnapshot = await db.collection('testingFeedback')
          .where('distributionId', '==', distributionId)
          .orderBy('createdAt', 'desc')
          .get();

        report.feedback = feedbackSnapshot.docs.map(doc => ({
          id: doc.id,
          ...doc.data(),
          createdAt: doc.data().createdAt?.toDate().toISOString()
        }));
      }

      // Obtener datos de crashes si solicitado
      if (includeCrashData) {
        // Integrar con Crashlytics data
        // TODO: Implementar integración con Crashlytics API
        report.crashData = {
          totalCrashes: distribution.stats?.crashes || 0,
          note: 'Integración con Crashlytics pendiente'
        };
      }

      // Generar resumen
      report.summary = {
        totalTesters: distribution.stats?.totalTesters || 0,
        downloads: distribution.stats?.downloads || 0,
        installs: distribution.stats?.installs || 0,
        crashes: distribution.stats?.crashes || 0,
        feedbackCount: distribution.stats?.feedbackCount || 0,
        downloadRate: distribution.stats?.totalTesters > 0 ? 
          ((distribution.stats?.downloads || 0) / distribution.stats.totalTesters * 100).toFixed(2) + '%' : '0%',
        installRate: distribution.stats?.downloads > 0 ? 
          ((distribution.stats?.installs || 0) / distribution.stats.downloads * 100).toFixed(2) + '%' : '0%',
        eventCount: report.events.length,
        feedbackScore: report.feedback.length > 0 ? 
          (report.feedback.reduce((sum, f) => sum + (f.rating || 0), 0) / report.feedback.length).toFixed(1) : 'N/A'
      };

      // Guardar reporte
      await db.collection('testingReports').add({
        distributionId: distributionId,
        reportData: report,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        generatedBy: context.auth.uid
      });

      return {
        success: true,
        report: report
      };

    } catch (error) {
      console.error('Error generando reporte de testing:', error);
      throw new functions.https.HttpsError('internal', 'Error interno del servidor');
    }
  });

/**
 * Limpiar distribuciones antiguas
 */
exports.cleanupOldDistributions = functions
  .runWith({
    timeoutSeconds: 300,
    memory: '512MB'
  })
  .pubsub.schedule('0 2 * * 0') // Domingos a las 2 AM
  .timeZone('America/Lima')
  .onRun(async (context) => {
    try {
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - 30); // 30 días atrás

      const oldDistributionsSnapshot = await db.collection('appDistributions')
        .where('createdAt', '<', admin.firestore.Timestamp.fromDate(cutoffDate))
        .where('status', '==', DISTRIBUTION_STATUS.COMPLETED)
        .get();

      console.log(`Encontradas ${oldDistributionsSnapshot.size} distribuciones antiguas para limpiar`);

      const cleanupPromises = [];

      oldDistributionsSnapshot.forEach(doc => {
        // Marcar como archivada en lugar de eliminar
        cleanupPromises.push(
          doc.ref.update({
            archived: true,
            archivedAt: admin.firestore.FieldValue.serverTimestamp()
          })
        );
      });

      await Promise.all(cleanupPromises);

      console.log('Limpieza de distribuciones antiguas completada');

    } catch (error) {
      console.error('Error en limpieza automática:', error);
    }
  });

module.exports = {
  APP_DISTRIBUTION_CONFIG,
  DISTRIBUTION_STATUS,
  BUILD_TYPES,
  TESTER_GROUPS
};