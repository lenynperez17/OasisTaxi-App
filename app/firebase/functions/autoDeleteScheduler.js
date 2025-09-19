const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Inicializar Firebase Admin SDK si no está ya inicializado
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const bucket = admin.storage().bucket();

/**
 * Cloud Function para eliminación automática de archivos de chat
 * Ejecutada por Cloud Scheduler cada hora
 * 
 * Características:
 * - Elimina archivos que han excedido su fecha de auto-eliminación
 * - Actualiza estadísticas de uso de almacenamiento
 * - Registra eventos de auditoría
 * - Maneja errores graciosamente
 * - Optimizada para grandes volúmenes
 */
exports.autoDeleteChatFiles = functions
  .runWith({
    timeoutSeconds: 540, // 9 minutos máximo
    memory: '1GB'
  })
  .pubsub
  .topic('auto-delete-chat-files')
  .onPublish(async (message, context) => {
    const startTime = Date.now();
    
    console.log('🗑️ Iniciando eliminación automática de archivos de chat...');
    
    try {
      const now = admin.firestore.Timestamp.now();
      const batchSize = 100; // Procesar en lotes de 100
      let totalProcessed = 0;
      let totalDeleted = 0;
      let totalErrors = 0;
      
      // Obtener archivos programados para eliminación
      const scheduledQuery = db.collection('scheduled_deletions')
        .where('deleteAt', '<=', now)
        .where('status', '==', 'pending')
        .where('type', '==', 'chat_file')
        .limit(batchSize);
      
      let hasMore = true;
      let lastDoc = null;
      
      while (hasMore) {
        let query = scheduledQuery;
        if (lastDoc) {
          query = query.startAfter(lastDoc);
        }
        
        const snapshot = await query.get();
        
        if (snapshot.empty) {
          hasMore = false;
          break;
        }
        
        // Procesar lote actual
        const batch = db.batch();
        const deletionPromises = [];
        
        for (const doc of snapshot.docs) {
          const deletion = doc.data();
          const fileId = deletion.fileId;
          
          totalProcessed++;
          
          try {
            // Obtener metadatos del archivo
            const fileMetadataDoc = await db
              .collection('chat_file_metadata')
              .doc(fileId)
              .get();
            
            if (!fileMetadataDoc.exists) {
              console.warn(`⚠️ Archivo ${fileId} ya no existe en metadatos`);
              // Marcar eliminación como completada
              batch.update(doc.ref, {
                status: 'completed',
                completedAt: admin.firestore.FieldValue.serverTimestamp(),
                error: 'File metadata not found'
              });
              continue;
            }
            
            const fileMetadata = fileMetadataDoc.data();
            
            // Eliminar archivo de Cloud Storage
            const storagePath = `chat-files/${fileMetadata.chatId}/${fileId}`;
            deletionPromises.push(
              deleteFileFromStorage(storagePath, fileId)
            );
            
            // Eliminar thumbnail si existe
            if (fileMetadata.thumbnailUrl) {
              const thumbnailPath = `chat-files/thumbnails/${fileId}.jpg`;
              deletionPromises.push(
                deleteFileFromStorage(thumbnailPath, `${fileId}_thumbnail`)
              );
            }
            
            // Actualizar metadatos del archivo (soft delete)
            batch.update(fileMetadataDoc.ref, {
              isDeleted: true,
              deletedAt: admin.firestore.FieldValue.serverTimestamp(),
              deletedBy: 'auto-scheduler',
              autoDeleteReason: 'Expired retention period'
            });
            
            // Actualizar uso de almacenamiento del usuario
            const userUsageRef = db.collection('user_storage_usage')
              .doc(fileMetadata.userId);
            
            batch.update(userUsageRef, {
              totalBytes: admin.firestore.FieldValue.increment(-fileMetadata.finalSize),
              totalFiles: admin.firestore.FieldValue.increment(-1),
              lastUpdated: admin.firestore.FieldValue.serverTimestamp()
            });
            
            // Marcar eliminación como completada
            batch.update(doc.ref, {
              status: 'completed',
              completedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            
            // Registrar evento de auditoría
            const auditRef = db.collection('audit_logs').doc();
            batch.set(auditRef, {
              event: 'chat_file_auto_delete',
              fileId: fileId,
              fileName: fileMetadata.fileName,
              fileSize: fileMetadata.finalSize,
              userId: fileMetadata.userId,
              chatId: fileMetadata.chatId,
              reason: 'auto_expiry',
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
              scheduledDeletionId: doc.id
            });
            
            totalDeleted++;
            
          } catch (error) {
            console.error(`❌ Error procesando archivo ${fileId}:`, error);
            totalErrors++;
            
            // Marcar eliminación como fallida
            batch.update(doc.ref, {
              status: 'failed',
              error: error.message,
              failedAt: admin.firestore.FieldValue.serverTimestamp(),
              retryCount: admin.firestore.FieldValue.increment(1)
            });
          }
        }
        
        // Ejecutar operaciones de Firestore
        await batch.commit();
        
        // Ejecutar eliminaciones de Storage
        await Promise.allSettled(deletionPromises);
        
        // Configurar para siguiente lote
        lastDoc = snapshot.docs[snapshot.docs.length - 1];
        
        console.log(`📊 Lote procesado: ${snapshot.size} elementos`);
      }
      
      // Limpiar eliminaciones fallidas antiguas (más de 7 días)
      await cleanupFailedDeletions();
      
      // Generar estadísticas finales
      const endTime = Date.now();
      const executionTime = endTime - startTime;
      
      const stats = {
        executionTime: executionTime,
        totalProcessed: totalProcessed,
        totalDeleted: totalDeleted,
        totalErrors: totalErrors,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      };
      
      // Guardar estadísticas de ejecución
      await db.collection('auto_delete_stats').add(stats);
      
      console.log('✅ Eliminación automática completada:', stats);
      
      return {
        success: true,
        stats: stats
      };
      
    } catch (error) {
      console.error('❌ Error en eliminación automática:', error);
      
      // Registrar error global
      await db.collection('auto_delete_errors').add({
        error: error.message,
        stack: error.stack,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        executionTime: Date.now() - startTime
      });
      
      throw error;
    }
  });

/**
 * Función auxiliar para eliminar archivo de Storage
 */
async function deleteFileFromStorage(filePath, fileId) {
  try {
    const file = bucket.file(filePath);
    const [exists] = await file.exists();
    
    if (exists) {
      await file.delete();
      console.log(`🗑️ Archivo eliminado de Storage: ${filePath}`);
    } else {
      console.warn(`⚠️ Archivo no encontrado en Storage: ${filePath}`);
    }
  } catch (error) {
    console.error(`❌ Error eliminando ${filePath} de Storage:`, error);
    throw error;
  }
}

/**
 * Limpiar eliminaciones fallidas antiguas
 */
async function cleanupFailedDeletions() {
  try {
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    
    const oldFailedQuery = db.collection('scheduled_deletions')
      .where('status', '==', 'failed')
      .where('failedAt', '<', admin.firestore.Timestamp.fromDate(sevenDaysAgo))
      .limit(50);
    
    const oldFailedDocs = await oldFailedQuery.get();
    
    if (!oldFailedDocs.empty) {
      const batch = db.batch();
      
      oldFailedDocs.forEach(doc => {
        batch.delete(doc.ref);
      });
      
      await batch.commit();
      
      console.log(`🧹 Eliminadas ${oldFailedDocs.size} eliminaciones fallidas antiguas`);
    }
    
  } catch (error) {
    console.error('❌ Error limpiando eliminaciones fallidas:', error);
  }
}

/**
 * Cloud Function para programar eliminaciones automáticas
 * Ejecutada cuando se crea un nuevo archivo
 */
exports.scheduleChatFileAutoDelete = functions.firestore
  .document('chat_file_metadata/{fileId}')
  .onCreate(async (snap, context) => {
    const fileId = context.params.fileId;
    const fileData = snap.data();
    
    // Solo programar si tiene fecha de auto-eliminación
    if (!fileData.autoDeleteAt) {
      console.log(`📄 Archivo ${fileId} sin auto-eliminación programada`);
      return null;
    }
    
    try {
      // Crear entrada en eliminaciones programadas
      await db.collection('scheduled_deletions').add({
        fileId: fileId,
        deleteAt: fileData.autoDeleteAt,
        type: 'chat_file',
        scheduledAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'pending',
        chatId: fileData.chatId,
        userId: fileData.userId,
        fileName: fileData.fileName,
        fileSize: fileData.finalSize
      });
      
      console.log(`⏰ Auto-eliminación programada para archivo ${fileId} en ${fileData.autoDeleteAt.toDate()}`);
      
    } catch (error) {
      console.error(`❌ Error programando auto-eliminación para ${fileId}:`, error);
    }
  });

/**
 * Cloud Function para manejar eliminaciones manuales
 */
exports.handleManualFileDelete = functions.firestore
  .document('chat_file_metadata/{fileId}')
  .onUpdate(async (change, context) => {
    const fileId = context.params.fileId;
    const before = change.before.data();
    const after = change.after.data();
    
    // Detectar eliminación manual
    if (!before.isDeleted && after.isDeleted && after.deletedBy !== 'auto-scheduler') {
      try {
        // Cancelar eliminación automática programada
        const scheduledQuery = db.collection('scheduled_deletions')
          .where('fileId', '==', fileId)
          .where('status', '==', 'pending');
        
        const scheduledDocs = await scheduledQuery.get();
        
        if (!scheduledDocs.empty) {
          const batch = db.batch();
          
          scheduledDocs.forEach(doc => {
            batch.update(doc.ref, {
              status: 'cancelled',
              cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
              cancelReason: 'manual_delete'
            });
          });
          
          await batch.commit();
          
          console.log(`❌ Cancelada auto-eliminación para archivo eliminado manualmente: ${fileId}`);
        }
        
      } catch (error) {
        console.error(`❌ Error cancelando auto-eliminación para ${fileId}:`, error);
      }
    }
  });

/**
 * Cloud Function para obtener estadísticas de eliminación
 * Ejecutada via HTTPS
 */
exports.getAutoDeleteStats = functions.https.onCall(async (data, context) => {
  // Verificar autenticación
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }
  
  // Verificar permisos de admin
  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  const userData = userDoc.data();
  
  if (!userData || !userData.isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Acceso denegado');
  }
  
  try {
    const days = data.days || 7;
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);
    
    // Obtener estadísticas recientes
    const statsQuery = db.collection('auto_delete_stats')
      .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(startDate))
      .orderBy('timestamp', 'desc')
      .limit(100);
    
    const statsSnapshot = await statsQuery.get();
    const stats = statsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      timestamp: doc.data().timestamp?.toDate()
    }));
    
    // Obtener eliminaciones pendientes
    const pendingQuery = db.collection('scheduled_deletions')
      .where('status', '==', 'pending')
      .count();
    
    const pendingCount = await pendingQuery.get();
    
    // Obtener eliminaciones fallidas
    const failedQuery = db.collection('scheduled_deletions')
      .where('status', '==', 'failed')
      .count();
    
    const failedCount = await failedQuery.get();
    
    return {
      recentStats: stats,
      pendingDeletions: pendingCount.data().count,
      failedDeletions: failedCount.data().count,
      generatedAt: new Date().toISOString()
    };
    
  } catch (error) {
    console.error('❌ Error obteniendo estadísticas de auto-delete:', error);
    throw new functions.https.HttpsError('internal', 'Error interno del servidor');
  }
});

/**
 * Cloud Function para limpieza manual de archivos expirados
 * Ejecutada via HTTPS por administradores
 */
exports.triggerManualCleanup = functions.https.onCall(async (data, context) => {
  // Verificar autenticación y permisos
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }
  
  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  const userData = userDoc.data();
  
  if (!userData || !userData.isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Acceso denegado');
  }
  
  try {
    console.log(`🛠️ Limpieza manual iniciada por admin: ${context.auth.uid}`);
    
    // Publicar mensaje al topic para activar la limpieza
    const message = {
      triggeredBy: context.auth.uid,
      triggeredAt: new Date().toISOString(),
      manual: true
    };
    
    await admin.messaging().send({
      topic: 'auto-delete-chat-files',
      data: message
    });
    
    // Registrar evento de auditoría
    await db.collection('audit_logs').add({
      event: 'manual_cleanup_triggered',
      adminId: context.auth.uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log('✅ Limpieza manual activada correctamente');
    
    return {
      success: true,
      message: 'Limpieza manual activada correctamente',
      triggeredAt: new Date().toISOString()
    };
    
  } catch (error) {
    console.error('❌ Error activando limpieza manual:', error);
    throw new functions.https.HttpsError('internal', 'Error interno del servidor');
  }
});

module.exports = {
  autoDeleteChatFiles: exports.autoDeleteChatFiles,
  scheduleChatFileAutoDelete: exports.scheduleChatFileAutoDelete,
  handleManualFileDelete: exports.handleManualFileDelete,
  getAutoDeleteStats: exports.getAutoDeleteStats,
  triggerManualCleanup: exports.triggerManualCleanup
};