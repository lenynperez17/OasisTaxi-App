import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Inicializar admin si no está inicializado
if (!admin.apps.length) {
  admin.initializeApp();
}

const messaging = admin.messaging();
const firestore = admin.firestore();

/**
 * Cloud Function para enviar notificaciones FCM
 * Callable function que puede ser invocada desde la app
 */
export const sendNotification = functions.https.onCall(async (data, context) => {
  // Verificar autenticación
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Usuario no autenticado'
    );
  }

  const { userId, title, body, data: notificationData, topic } = data;

  try {
    let message: admin.messaging.Message;

    if (topic) {
      // Enviar a un topic
      message = {
        topic,
        notification: {
          title,
          body,
        },
        data: notificationData || {},
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        appleConfig: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };
    } else if (userId) {
      // Obtener token FCM del usuario
      const userDoc = await firestore.collection('users').doc(userId).get();
      const fcmToken = userDoc.data()?.fcmToken;

      if (!fcmToken) {
        throw new functions.https.HttpsError(
          'not-found',
          'Token FCM no encontrado para el usuario'
        );
      }

      message = {
        token: fcmToken,
        notification: {
          title,
          body,
        },
        data: notificationData || {},
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        appleConfig: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };
    } else {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Debe especificar userId o topic'
      );
    }

    // Enviar notificación
    const response = await messaging.send(message);

    // Registrar en Firestore
    await firestore.collection('notification_logs').add({
      userId: userId || null,
      topic: topic || null,
      title,
      body,
      data: notificationData || {},
      messageId: response,
      status: 'sent',
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      sentBy: context.auth.uid,
    });

    return { success: true, messageId: response };
  } catch (error) {
    console.error('Error enviando notificación FCM:', error);

    // Registrar error
    await firestore.collection('notification_logs').add({
      userId: userId || null,
      topic: topic || null,
      title,
      body,
      data: notificationData || {},
      error: error.message,
      status: 'failed',
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      sentBy: context.auth.uid,
    });

    throw new functions.https.HttpsError(
      'internal',
      'Error al enviar notificación',
      error
    );
  }
});

/**
 * Enviar notificación a múltiples usuarios
 */
export const sendBatchNotifications = functions.https.onCall(async (data, context) => {
  // Verificar autenticación
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Usuario no autenticado'
    );
  }

  const { userIds, title, body, data: notificationData } = data;

  if (!userIds || !Array.isArray(userIds) || userIds.length === 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Lista de usuarios inválida'
    );
  }

  // Máximo 500 usuarios por batch (límite FCM)
  if (userIds.length > 500) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Máximo 500 usuarios por batch'
    );
  }

  try {
    // Obtener tokens FCM de todos los usuarios
    const userDocs = await firestore
      .collection('users')
      .where(admin.firestore.FieldPath.documentId(), 'in', userIds)
      .get();

    const tokens: string[] = [];
    const invalidUsers: string[] = [];

    userDocs.forEach((doc) => {
      const fcmToken = doc.data().fcmToken;
      if (fcmToken) {
        tokens.push(fcmToken);
      } else {
        invalidUsers.push(doc.id);
      }
    });

    if (tokens.length === 0) {
      throw new functions.https.HttpsError(
        'not-found',
        'No se encontraron tokens FCM válidos'
      );
    }

    // Crear mensaje multicast
    const message: admin.messaging.MulticastMessage = {
      tokens,
      notification: {
        title,
        body,
      },
      data: notificationData || {},
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      appleConfig: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    // Enviar notificaciones
    const response = await messaging.sendMulticast(message);

    // Registrar resultado
    await firestore.collection('notification_logs').add({
      type: 'batch',
      userIds,
      invalidUsers,
      title,
      body,
      data: notificationData || {},
      successCount: response.successCount,
      failureCount: response.failureCount,
      status: response.failureCount === 0 ? 'sent' : 'partial',
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      sentBy: context.auth.uid,
    });

    return {
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
      invalidUsers,
    };
  } catch (error) {
    console.error('Error enviando notificaciones batch:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Error al enviar notificaciones',
      error
    );
  }
});

/**
 * Suscribir usuario a un topic
 */
export const subscribeToTopic = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Usuario no autenticado'
    );
  }

  const { topic } = data;
  const userId = context.auth.uid;

  try {
    // Obtener token FCM del usuario
    const userDoc = await firestore.collection('users').doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;

    if (!fcmToken) {
      throw new functions.https.HttpsError(
        'not-found',
        'Token FCM no encontrado'
      );
    }

    // Suscribir al topic
    await messaging.subscribeToTopic([fcmToken], topic);

    // Actualizar suscripciones del usuario
    await firestore.collection('users').doc(userId).update({
      fcmTopics: admin.firestore.FieldValue.arrayUnion(topic),
      lastTopicUpdate: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, topic };
  } catch (error) {
    console.error('Error suscribiendo a topic:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Error al suscribir a topic',
      error
    );
  }
});

/**
 * Desuscribir usuario de un topic
 */
export const unsubscribeFromTopic = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Usuario no autenticado'
    );
  }

  const { topic } = data;
  const userId = context.auth.uid;

  try {
    // Obtener token FCM del usuario
    const userDoc = await firestore.collection('users').doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;

    if (!fcmToken) {
      throw new functions.https.HttpsError(
        'not-found',
        'Token FCM no encontrado'
      );
    }

    // Desuscribir del topic
    await messaging.unsubscribeFromTopic([fcmToken], topic);

    // Actualizar suscripciones del usuario
    await firestore.collection('users').doc(userId).update({
      fcmTopics: admin.firestore.FieldValue.arrayRemove(topic),
      lastTopicUpdate: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, topic };
  } catch (error) {
    console.error('Error desuscribiendo de topic:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Error al desuscribir de topic',
      error
    );
  }
});