import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// Comment 9: Implement proper cloud functions for notifications

/**
 * Check document expiry and send notifications
 * Runs daily at 9:00 AM Peru time (UTC-5)
 */
export const checkDocumentExpiry = functions.pubsub
  .schedule('0 9 * * *')
  .timeZone('America/Lima')
  .onRun(async (context) => {
    console.log('Checking document expiry...');

    const now = new Date();
    const thirtyDaysFromNow = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

    try {
      // Get all vehicle documents
      const documentsSnapshot = await db.collectionGroup('documents').get();
      const notifications: admin.messaging.Message[] = [];

      for (const doc of documentsSnapshot.docs) {
        const data = doc.data();
        const expiryDate = data.expiryDate?.toDate();

        if (!expiryDate) continue;

        const daysUntilExpiry = Math.floor((expiryDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));

        // Get driver info
        const driverId = doc.ref.parent.parent?.id;
        if (!driverId) continue;

        const driverDoc = await db.collection('users').doc(driverId).get();
        if (!driverDoc.exists) continue;

        const driverData = driverDoc.data();
        const fcmToken = driverData?.fcmToken;

        if (!fcmToken) continue;

        let title = '';
        let body = '';
        let priority: 'high' | 'normal' = 'normal';

        if (daysUntilExpiry <= 0) {
          title = '⚠️ Documento Vencido';
          body = `Tu ${data.type} ha vencido. Actualízalo inmediatamente.`;
          priority = 'high';
        } else if (daysUntilExpiry <= 7) {
          title = '🚨 Documento por Vencer - URGENTE';
          body = `Tu ${data.type} vence en ${daysUntilExpiry} días.`;
          priority = 'high';
        } else if (daysUntilExpiry <= 30) {
          title = '📋 Recordatorio de Documento';
          body = `Tu ${data.type} vence en ${daysUntilExpiry} días.`;
          priority = 'normal';
        } else {
          continue;
        }

        notifications.push({
          token: fcmToken,
          notification: {
            title,
            body
          },
          data: {
            type: 'document_expiry',
            documentType: data.type,
            documentId: doc.id,
            daysRemaining: daysUntilExpiry.toString(),
            screen: 'documents'
          },
          android: {
            priority
          }
        });
      }

      // Send notifications in batch
      if (notifications.length > 0) {
        const response = await messaging.sendEach(notifications);
        console.log(`Sent ${response.successCount} notifications, ${response.failureCount} failed`);
      }

      return null;
    } catch (error) {
      console.error('Error checking document expiry:', error);
      throw error;
    }
  });

/**
 * Send maintenance reminders
 * Runs daily at 8:00 AM Peru time (UTC-5)
 */
export const sendMaintenanceReminders = functions.pubsub
  .schedule('0 8 * * *')
  .timeZone('America/Lima')
  .onRun(async (context) => {
    console.log('Sending maintenance reminders...');

    try {
      const vehiclesSnapshot = await db.collection('vehicles').get();
      const notifications: admin.messaging.Message[] = [];

      for (const vehicleDoc of vehiclesSnapshot.docs) {
        const vehicleData = vehicleDoc.data();
        const driverId = vehicleData.driverId;

        if (!driverId) continue;

        const driverDoc = await db.collection('users').doc(driverId).get();
        if (!driverDoc.exists) continue;

        const driverData = driverDoc.data();
        const fcmToken = driverData?.fcmToken;

        if (!fcmToken) continue;

        // Get maintenance records
        const maintenanceSnapshot = await vehicleDoc.ref
          .collection('maintenanceRecords')
          .orderBy('date', 'desc')
          .limit(5)
          .get();

        const currentMileage = vehicleData.mileage || 0;

        // Check oil change (every 5000 km)
        const lastOilChange = maintenanceSnapshot.docs.find(doc =>
          doc.data().type === 'Cambio de Aceite'
        );

        if (lastOilChange) {
          const lastOilChangeMileage = lastOilChange.data().mileage || 0;
          const kmSinceOilChange = currentMileage - lastOilChangeMileage;

          if (kmSinceOilChange >= 4500) {
            const kmRemaining = 5000 - kmSinceOilChange;
            const isUrgent = kmRemaining <= 200;

            notifications.push({
              token: fcmToken,
              notification: {
                title: isUrgent ? '🚨 Cambio de Aceite URGENTE' : '🔧 Recordatorio de Mantenimiento',
                body: isUrgent
                  ? `¡Solo te quedan ${kmRemaining} km para el cambio de aceite!`
                  : `Te quedan ${kmRemaining} km para el próximo cambio de aceite`
              },
              data: {
                type: 'maintenance_reminder',
                maintenanceType: 'Cambio de Aceite',
                vehicleId: vehicleDoc.id,
                currentMileage: currentMileage.toString(),
                kmRemaining: kmRemaining.toString(),
                screen: 'vehicle_management'
              }
            });
          }
        }

        // Check custom reminders
        const remindersSnapshot = await vehicleDoc.ref
          .collection('reminders')
          .where('completed', '==', false)
          .where('date', '<=', admin.firestore.Timestamp.now())
          .get();

        for (const reminderDoc of remindersSnapshot.docs) {
          const reminderData = reminderDoc.data();

          notifications.push({
            token: fcmToken,
            notification: {
              title: '🔔 ' + reminderData.title,
              body: reminderData.description
            },
            data: {
              type: 'custom_reminder',
              reminderId: reminderDoc.id,
              vehicleId: vehicleDoc.id,
              screen: 'vehicle_management'
            }
          });

          // Mark as sent
          await reminderDoc.ref.update({
            notificationSent: true,
            notificationSentAt: admin.firestore.FieldValue.serverTimestamp()
          });
        }
      }

      // Send notifications in batch
      if (notifications.length > 0) {
        const response = await messaging.sendEach(notifications);
        console.log(`Sent ${response.successCount} maintenance reminders, ${response.failureCount} failed`);
      }

      return null;
    } catch (error) {
      console.error('Error sending maintenance reminders:', error);
      throw error;
    }
  });

/**
 * Notify wallet transaction
 * Triggered when a new transaction is created
 */
export const notifyWalletTransaction = functions.firestore
  .document('wallets/{driverId}/transactions/{transactionId}')
  .onCreate(async (snapshot, context) => {
    const transactionData = snapshot.data();
    const driverId = context.params.driverId;

    try {
      // Get driver data
      const driverDoc = await db.collection('users').doc(driverId).get();
      if (!driverDoc.exists) return;

      const driverData = driverDoc.data();
      const fcmToken = driverData?.fcmToken;

      if (!fcmToken) return;

      let title = '';
      let body = '';

      switch (transactionData.type) {
        case 'earning':
          title = '💰 Nuevo Ingreso';
          body = `Has recibido S/ ${transactionData.amount} por tu último viaje`;
          break;
        case 'withdrawal':
          title = '💸 Retiro Procesado';
          body = `Se ha procesado tu retiro de S/ ${transactionData.amount}`;
          break;
        case 'commission':
          title = '📊 Comisión Cobrada';
          body = `Se ha descontado S/ ${transactionData.amount} de comisión`;
          break;
        default:
          title = '💳 Nueva Transacción';
          body = `Transacción de S/ ${transactionData.amount} procesada`;
      }

      const message: admin.messaging.Message = {
        token: fcmToken,
        notification: {
          title,
          body
        },
        data: {
          type: 'wallet_transaction',
          transactionId: snapshot.id,
          transactionType: transactionData.type,
          amount: transactionData.amount.toString(),
          screen: 'wallet'
        }
      };

      await messaging.send(message);
      console.log('Wallet transaction notification sent to', driverId);
    } catch (error) {
      console.error('Error sending wallet notification:', error);
    }
  });

/**
 * Notify withdrawal request status
 * Triggered when a withdrawal request is updated
 */
export const notifyWithdrawalRequest = functions.firestore
  .document('withdrawalRequests/{requestId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only notify on status change
    if (before.status === after.status) return;

    const driverId = after.driverId;

    try {
      // Get driver data
      const driverDoc = await db.collection('users').doc(driverId).get();
      if (!driverDoc.exists) return;

      const driverData = driverDoc.data();
      const fcmToken = driverData?.fcmToken;

      if (!fcmToken) return;

      let title = '';
      let body = '';

      switch (after.status) {
        case 'approved':
          title = '✅ Retiro Aprobado';
          body = `Tu solicitud de retiro de S/ ${after.amount} ha sido aprobada`;
          break;
        case 'rejected':
          title = '❌ Retiro Rechazado';
          body = `Tu solicitud de retiro de S/ ${after.amount} ha sido rechazada. Motivo: ${after.rejectionReason || 'No especificado'}`;
          break;
        case 'completed':
          title = '💵 Retiro Completado';
          body = `Tu retiro de S/ ${after.amount} ha sido depositado en tu cuenta`;
          break;
        default:
          return;
      }

      const message: admin.messaging.Message = {
        token: fcmToken,
        notification: {
          title,
          body
        },
        data: {
          type: 'withdrawal_status',
          requestId: context.params.requestId,
          status: after.status,
          amount: after.amount.toString(),
          screen: 'wallet'
        }
      };

      await messaging.send(message);
      console.log('Withdrawal status notification sent to', driverId);
    } catch (error) {
      console.error('Error sending withdrawal notification:', error);
    }
  });

/**
 * Update vehicle mileage after trip completion
 */
export const updateVehicleMileage = functions.firestore
  .document('trips/{tripId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only update when trip is completed
    if (before.status !== 'completed' && after.status === 'completed') {
      const driverId = after.driverId;
      const distance = after.distance || 0;

      if (driverId && distance > 0) {
        try {
          // Get driver's vehicle
          const vehicleSnapshot = await db.collection('vehicles')
            .where('driverId', '==', driverId)
            .where('isActive', '==', true)
            .limit(1)
            .get();

          if (!vehicleSnapshot.empty) {
            const vehicleDoc = vehicleSnapshot.docs[0];
            const currentMileage = vehicleDoc.data().mileage || 0;
            const newMileage = currentMileage + Math.round(distance);

            // Update mileage
            await vehicleDoc.ref.update({
              mileage: newMileage,
              lastMileageUpdate: admin.firestore.FieldValue.serverTimestamp()
            });

            console.log(`Updated mileage for vehicle ${vehicleDoc.id}: ${currentMileage} -> ${newMileage}`);
          }
        } catch (error) {
          console.error('Error updating vehicle mileage:', error);
        }
      }
    }
  });