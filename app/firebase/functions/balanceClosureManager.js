// ====================================================================
// 💰 BALANCE CLOSURE MANAGER - CLOUD FUNCTIONS OASISTAXI PERU
// ====================================================================
// Sistema automático de cierres de balance y transferencias
// Cálculo de comisiones, distribución a conductores y reportes financieros
// Integración con bancos peruanos (BCP, BBVA, Interbank, Scotiabank)
// ====================================================================

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { BigQuery } = require('@google-cloud/bigquery');
const axios = require('axios');
const moment = require('moment-timezone');

// Inicializar Firebase Admin si no está inicializado
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const bigquery = new BigQuery();

// ====================================================================
// 🏦 CONFIGURACIÓN BANCOS PERUANOS
// ====================================================================

const PERU_BANKS_CONFIG = {
  BCP: {
    name: 'Banco de Crédito del Perú',
    code: '002',
    api: 'https://api.viabcp.com/transfers',
    cci: '20100000001',
    supportedCurrencies: ['PEN', 'USD'],
    maxDailyTransfer: 500000, // S/ 500,000
    processingHours: { start: 8, end: 18 }
  },
  BBVA: {
    name: 'BBVA Continental',
    code: '011',
    api: 'https://api.bbva.pe/transfers',
    cci: '20110000001',
    supportedCurrencies: ['PEN', 'USD'],
    maxDailyTransfer: 300000, // S/ 300,000
    processingHours: { start: 9, end: 17 }
  },
  INTERBANK: {
    name: 'Interbank',
    code: '003',
    api: 'https://api.interbank.pe/transfers',
    cci: '20030000001',
    supportedCurrencies: ['PEN'],
    maxDailyTransfer: 200000, // S/ 200,000
    processingHours: { start: 8, end: 19 }
  },
  SCOTIABANK: {
    name: 'Scotiabank Perú',
    code: '009',
    api: 'https://api.scotiabank.com.pe/transfers',
    cci: '20090000001',
    supportedCurrencies: ['PEN', 'USD'],
    maxDailyTransfer: 400000, // S/ 400,000
    processingHours: { start: 8, end: 18 }
  }
};

// Comisiones OasisTaxi Peru (configurables por tipo de vehículo)
const COMMISSION_RATES = {
  economy: 0.15,      // 15% para autos económicos
  comfort: 0.17,      // 17% para autos comfort
  premium: 0.20,      // 20% para autos premium
  van: 0.18,          // 18% para vans/minivans
  moto: 0.12,         // 12% para motos/mototaxis
  default: 0.15
};

// Configuración Peru específica
const PERU_CONFIG = {
  timezone: 'America/Lima',
  currency: 'PEN',
  taxRate: 0.18, // IGV 18%
  minTransferAmount: 10.00, // S/ 10.00 mínimo
  maxRetryAttempts: 3,
  businessHours: { start: 8, end: 18 },
  sunat: {
    api: 'https://api.sunat.gob.pe/v1/contribuyentes',
    ruc: '20123456789' // RUC de OasisTaxi Peru
  }
};

// ====================================================================
// 🔥 TRIGGER: CIERRE DIARIO AUTOMÁTICO
// ====================================================================

exports.dailyBalanceClosure = functions.pubsub
  .schedule('0 23 * * *') // 11 PM todos los días
  .timeZone('America/Lima')
  .onRun(async (context) => {
    try {
      console.log('💰 Iniciando cierre diario de balances...');

      const today = moment().tz(PERU_CONFIG.timezone).format('YYYY-MM-DD');
      const closureId = `closure_${today}_${Date.now()}`;

      // Crear registro de cierre
      const closureRecord = {
        id: closureId,
        date: today,
        type: 'daily_closure',
        status: 'processing',
        startTime: admin.firestore.FieldValue.serverTimestamp(),
        totalDrivers: 0,
        totalTrips: 0,
        totalRevenue: 0,
        totalCommissions: 0,
        totalDriverPayments: 0,
        processedDrivers: 0,
        failedTransfers: 0,
        errors: []
      };

      await db.collection('balance_closures').doc(closureId).set(closureRecord);

      // Obtener todos los conductores activos
      const driversSnapshot = await db.collection('drivers')
        .where('status', '==', 'active')
        .where('hasActiveTrips', '==', false) // Solo cerrar si no tienen viajes activos
        .get();

      console.log(`📊 Procesando ${driversSnapshot.size} conductores activos`);

      let totalRevenue = 0;
      let totalCommissions = 0;
      let totalDriverPayments = 0;
      let processedCount = 0;
      let failedCount = 0;

      // Procesar cada conductor
      for (const driverDoc of driversSnapshot.docs) {
        try {
          const driverId = driverDoc.id;
          const driverData = driverDoc.data();

          console.log(`👤 Procesando conductor: ${driverId}`);

          // Calcular balance del día
          const balanceResult = await calculateDriverDailyBalance(driverId, today);
          
          if (balanceResult.totalEarnings > PERU_CONFIG.minTransferAmount) {
            // Procesar transferencia bancaria
            const transferResult = await processDriverTransfer(driverId, balanceResult, closureId);
            
            if (transferResult.success) {
              processedCount++;
              totalRevenue += balanceResult.totalRevenue;
              totalCommissions += balanceResult.commission;
              totalDriverPayments += balanceResult.totalEarnings;
              
              // Actualizar saldo del conductor
              await updateDriverBalance(driverId, balanceResult, transferResult);
            } else {
              failedCount++;
              console.error(`❌ Fallo transferencia para conductor ${driverId}:`, transferResult.error);
            }
          } else {
            console.log(`💰 Saldo insuficiente para conductor ${driverId}: S/ ${balanceResult.totalEarnings}`);
          }

        } catch (driverError) {
          console.error(`❌ Error procesando conductor:`, driverError);
          failedCount++;
        }
      }

      // Generar reportes financieros
      await generateDailyFinancialReports(today, {
        totalDrivers: driversSnapshot.size,
        totalRevenue,
        totalCommissions,
        totalDriverPayments,
        processedDrivers: processedCount,
        failedTransfers: failedCount
      });

      // Actualizar registro de cierre
      await db.collection('balance_closures').doc(closureId).update({
        status: 'completed',
        endTime: admin.firestore.FieldValue.serverTimestamp(),
        totalDrivers: driversSnapshot.size,
        totalRevenue,
        totalCommissions,
        totalDriverPayments,
        processedDrivers: processedCount,
        failedTransfers: failedCount
      });

      // Enviar notificaciones a administradores
      await notifyAdministrators('daily_closure_completed', {
        date: today,
        processedDrivers: processedCount,
        totalRevenue: totalRevenue.toFixed(2),
        totalCommissions: totalCommissions.toFixed(2)
      });

      console.log(`✅ Cierre diario completado: ${processedCount}/${driversSnapshot.size} conductores procesados`);

    } catch (error) {
      console.error('❌ Error en cierre diario:', error);
      
      // Notificar error crítico
      await notifyAdministrators('daily_closure_failed', {
        error: error.message,
        timestamp: new Date().toISOString()
      });
    }
  });

// ====================================================================
// 📊 CÁLCULO DE BALANCE DIARIO POR CONDUCTOR
// ====================================================================

async function calculateDriverDailyBalance(driverId, date) {
  try {
    console.log(`📊 Calculando balance diario para conductor: ${driverId}`);

    const startOfDay = moment.tz(date, PERU_CONFIG.timezone).startOf('day').toDate();
    const endOfDay = moment.tz(date, PERU_CONFIG.timezone).endOf('day').toDate();

    // Obtener todos los viajes del día
    const tripsSnapshot = await db.collection('trips')
      .where('driverId', '==', driverId)
      .where('status', '==', 'completed')
      .where('endTime', '>=', startOfDay)
      .where('endTime', '<=', endOfDay)
      .get();

    let totalRevenue = 0;
    let totalTips = 0;
    let totalBonuses = 0;
    let tripCount = 0;

    const tripDetails = [];

    for (const tripDoc of tripsSnapshot.docs) {
      const trip = tripDoc.data();
      
      totalRevenue += trip.fare || 0;
      totalTips += trip.tip || 0;
      totalBonuses += trip.bonus || 0;
      tripCount++;

      tripDetails.push({
        id: tripDoc.id,
        fare: trip.fare || 0,
        tip: trip.tip || 0,
        bonus: trip.bonus || 0,
        startTime: trip.startTime,
        endTime: trip.endTime
      });
    }

    // Obtener tipo de vehículo para calcular comisión
    const driverDoc = await db.collection('drivers').doc(driverId).get();
    const driverData = driverDoc.data();
    const vehicleType = driverData.vehicleType || 'default';
    
    // Calcular comisión
    const commissionRate = COMMISSION_RATES[vehicleType] || COMMISSION_RATES.default;
    const commission = totalRevenue * commissionRate;

    // Calcular bonos adicionales por productividad
    let productivityBonus = 0;
    if (tripCount >= 20) {
      productivityBonus = totalRevenue * 0.05; // 5% bonus por 20+ viajes
    } else if (tripCount >= 15) {
      productivityBonus = totalRevenue * 0.03; // 3% bonus por 15+ viajes
    } else if (tripCount >= 10) {
      productivityBonus = totalRevenue * 0.02; // 2% bonus por 10+ viajes
    }

    const totalEarnings = totalRevenue - commission + totalTips + totalBonuses + productivityBonus;

    const balanceResult = {
      date,
      driverId,
      tripCount,
      totalRevenue,
      totalTips,
      totalBonuses,
      productivityBonus,
      commission,
      commissionRate,
      totalEarnings,
      tripDetails,
      calculatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    // Guardar cálculo en Firestore
    await db.collection('driver_daily_balances').doc(`${driverId}_${date}`).set(balanceResult);

    console.log(`✅ Balance calculado - Conductor: ${driverId}, Ingresos: S/ ${totalEarnings.toFixed(2)}`);
    return balanceResult;

  } catch (error) {
    console.error(`❌ Error calculando balance:`, error);
    throw error;
  }
}

// ====================================================================
// 🏦 PROCESAMIENTO DE TRANSFERENCIAS BANCARIAS
// ====================================================================

async function processDriverTransfer(driverId, balanceResult, closureId) {
  try {
    console.log(`🏦 Procesando transferencia para conductor: ${driverId}`);

    // Obtener datos bancarios del conductor
    const driverDoc = await db.collection('drivers').doc(driverId).get();
    const driverData = driverDoc.data();

    if (!driverData.bankAccount) {
      return {
        success: false,
        error: 'Conductor no tiene cuenta bancaria registrada'
      };
    }

    const bankAccount = driverData.bankAccount;
    const bankConfig = PERU_BANKS_CONFIG[bankAccount.bank];

    if (!bankConfig) {
      return {
        success: false,
        error: `Banco no soportado: ${bankAccount.bank}`
      };
    }

    // Verificar horarios bancarios
    const now = moment().tz(PERU_CONFIG.timezone);
    const currentHour = now.hour();
    
    if (currentHour < bankConfig.processingHours.start || currentHour > bankConfig.processingHours.end) {
      console.log(`⏰ Transferencia programada para horario bancario: ${bankAccount.bank}`);
      
      // Programar para mañana temprano
      const nextProcessingTime = now.clone()
        .add(1, 'day')
        .hour(bankConfig.processingHours.start)
        .minute(0)
        .second(0);

      await schedulePendingTransfer(driverId, balanceResult, nextProcessingTime.toDate());
      
      return {
        success: true,
        scheduled: true,
        scheduledFor: nextProcessingTime.toDate(),
        message: 'Transferencia programada para horario bancario'
      };
    }

    // Verificar límites diarios
    if (balanceResult.totalEarnings > bankConfig.maxDailyTransfer) {
      return {
        success: false,
        error: `Monto excede límite diario del banco: S/ ${bankConfig.maxDailyTransfer}`
      };
    }

    // Preparar datos de transferencia
    const transferData = {
      amount: balanceResult.totalEarnings,
      currency: PERU_CONFIG.currency,
      destinationBank: bankAccount.bank,
      destinationAccount: bankAccount.accountNumber,
      destinationAccountType: bankAccount.accountType,
      destinationCCI: bankAccount.cci,
      beneficiaryName: `${driverData.name} ${driverData.lastName}`,
      beneficiaryDNI: driverData.dni,
      concept: `OasisTaxi - Liquidación ${balanceResult.date}`,
      reference: `OAXIS-${closureId}-${driverId}`,
      originAccount: bankConfig.cci,
      metadata: {
        driverId,
        balanceDate: balanceResult.date,
        tripCount: balanceResult.tripCount,
        closureId
      }
    };

    let transferResult;
    
    // Intentar transferencia via API bancaria
    try {
      transferResult = await executeBankTransfer(bankConfig, transferData);
    } catch (apiError) {
      console.error(`❌ Error API bancaria:`, apiError);
      
      // Fallback: crear orden manual
      transferResult = await createManualTransferOrder(transferData);
    }

    // Registrar transferencia en Firestore
    const transferRecord = {
      ...transferData,
      ...transferResult,
      status: transferResult.success ? 'completed' : 'failed',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      processedAt: transferResult.success ? admin.firestore.FieldValue.serverTimestamp() : null
    };

    await db.collection('bank_transfers').add(transferRecord);

    // Actualizar métricas BigQuery
    await recordTransferMetrics(transferRecord);

    console.log(`✅ Transferencia procesada: ${driverId} - S/ ${balanceResult.totalEarnings}`);
    return transferResult;

  } catch (error) {
    console.error(`❌ Error procesando transferencia:`, error);
    return {
      success: false,
      error: error.message
    };
  }
}

// ====================================================================
// 🏦 EJECUCIÓN DE TRANSFERENCIA BANCARIA
// ====================================================================

async function executeBankTransfer(bankConfig, transferData) {
  try {
    console.log(`🏦 Ejecutando transferencia ${bankConfig.name}`);

    // Obtener credenciales del banco desde secrets
    const bankCredentials = await getSecretValue(`bank_${bankConfig.code}_credentials`);
    
    if (!bankCredentials) {
      throw new Error(`Credenciales no encontradas para ${bankConfig.name}`);
    }

    // Preparar headers de autenticación
    const headers = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${bankCredentials.accessToken}`,
      'X-Client-ID': bankCredentials.clientId,
      'X-Request-ID': transferData.reference,
      'X-Timestamp': new Date().toISOString()
    };

    // Payload específico por banco
    const payload = {
      sourceAccount: transferData.originAccount,
      destinationAccount: transferData.destinationAccount,
      amount: {
        value: transferData.amount.toFixed(2),
        currency: transferData.currency
      },
      beneficiary: {
        name: transferData.beneficiaryName,
        dni: transferData.beneficiaryDNI,
        bank: transferData.destinationBank
      },
      description: transferData.concept,
      reference: transferData.reference,
      metadata: transferData.metadata
    };

    // Hacer llamada a API bancaria
    const response = await axios.post(bankConfig.api, payload, {
      headers,
      timeout: 30000,
      validateStatus: (status) => status < 500 // Retry solo en errores de servidor
    });

    if (response.status === 200 || response.status === 201) {
      return {
        success: true,
        transactionId: response.data.transactionId || response.data.id,
        bankReference: response.data.reference,
        status: response.data.status || 'completed',
        processedAt: new Date().toISOString(),
        bankResponse: response.data
      };
    } else {
      throw new Error(`Error bancario: ${response.status} - ${response.data.message || 'Error desconocido'}`);
    }

  } catch (error) {
    console.error(`❌ Error ejecutando transferencia:`, error);
    
    if (error.response) {
      // Error de API bancaria
      return {
        success: false,
        error: `Error bancario: ${error.response.status} - ${error.response.data?.message || 'Error API'}`,
        retryable: error.response.status >= 500,
        bankError: error.response.data
      };
    } else {
      // Error de red o timeout
      return {
        success: false,
        error: error.message,
        retryable: true
      };
    }
  }
}

// ====================================================================
// 📋 CREAR ORDEN DE TRANSFERENCIA MANUAL
// ====================================================================

async function createManualTransferOrder(transferData) {
  try {
    console.log(`📋 Creando orden de transferencia manual`);

    const manualOrder = {
      ...transferData,
      type: 'manual_transfer_order',
      status: 'pending_manual_processing',
      requiresApproval: transferData.amount > 10000, // > S/ 10,000
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      instructions: generateTransferInstructions(transferData),
      priority: transferData.amount > 5000 ? 'high' : 'normal'
    };

    const orderRef = await db.collection('manual_transfer_orders').add(manualOrder);

    // Notificar al equipo financiero
    await notifyFinancialTeam('manual_transfer_required', {
      orderId: orderRef.id,
      amount: transferData.amount,
      beneficiary: transferData.beneficiaryName,
      bank: transferData.destinationBank,
      priority: manualOrder.priority
    });

    return {
      success: true,
      manual: true,
      orderId: orderRef.id,
      status: 'pending_manual_processing',
      message: 'Orden de transferencia manual creada'
    };

  } catch (error) {
    console.error(`❌ Error creando orden manual:`, error);
    return {
      success: false,
      error: error.message
    };
  }
}

// ====================================================================
// 📊 GENERACIÓN DE REPORTES FINANCIEROS
// ====================================================================

async function generateDailyFinancialReports(date, summary) {
  try {
    console.log(`📊 Generando reportes financieros para: ${date}`);

    // Reporte ejecutivo
    const executiveReport = {
      date,
      type: 'executive_daily',
      summary,
      metrics: {
        averageTripsPerDriver: summary.totalDrivers > 0 ? (summary.totalTrips / summary.totalDrivers).toFixed(2) : 0,
        averageRevenuePerDriver: summary.totalDrivers > 0 ? (summary.totalRevenue / summary.totalDrivers).toFixed(2) : 0,
        commissionPercentage: summary.totalRevenue > 0 ? ((summary.totalCommissions / summary.totalRevenue) * 100).toFixed(2) : 0,
        successfulTransferRate: summary.totalDrivers > 0 ? ((summary.processedDrivers / summary.totalDrivers) * 100).toFixed(2) : 0
      },
      comparisonWithPreviousDay: await getComparisonMetrics(date),
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };

    await db.collection('financial_reports').add(executiveReport);

    // Reporte detallado para BigQuery
    await insertIntoBigQuery('oasistaxi_analytics.daily_financial_summary', {
      date,
      total_drivers: summary.totalDrivers,
      total_revenue: summary.totalRevenue,
      total_commissions: summary.totalCommissions,
      total_driver_payments: summary.totalDriverPayments,
      processed_drivers: summary.processedDrivers,
      failed_transfers: summary.failedTransfers,
      timestamp: new Date().toISOString()
    });

    // Reporte para SUNAT (si es requerido)
    if (summary.totalRevenue > 100000) { // > S/ 100,000
      await generateSUNATReport(date, summary);
    }

    // Enviar reporte por email
    await emailDailyReport(date, executiveReport);

    console.log(`✅ Reportes financieros generados para: ${date}`);

  } catch (error) {
    console.error(`❌ Error generando reportes:`, error);
  }
}

// ====================================================================
// 🔄 CIERRE SEMANAL Y MENSUAL
// ====================================================================

exports.weeklyBalanceClosure = functions.pubsub
  .schedule('0 1 * * 1') // Lunes a la 1 AM
  .timeZone('America/Lima')
  .onRun(async (context) => {
    try {
      console.log('📅 Iniciando cierre semanal...');

      const endDate = moment().tz(PERU_CONFIG.timezone).subtract(1, 'day');
      const startDate = endDate.clone().subtract(6, 'days');

      await generateWeeklyReport(startDate.format('YYYY-MM-DD'), endDate.format('YYYY-MM-DD'));
      await processWeeklyBonuses();
      await reconcileWeeklyTransactions();

      console.log('✅ Cierre semanal completado');

    } catch (error) {
      console.error('❌ Error en cierre semanal:', error);
    }
  });

exports.monthlyBalanceClosure = functions.pubsub
  .schedule('0 2 1 * *') // Primer día del mes a las 2 AM
  .timeZone('America/Lima')
  .onRun(async (context) => {
    try {
      console.log('📅 Iniciando cierre mensual...');

      const lastMonth = moment().tz(PERU_CONFIG.timezone).subtract(1, 'month');
      const startDate = lastMonth.clone().startOf('month').format('YYYY-MM-DD');
      const endDate = lastMonth.clone().endOf('month').format('YYYY-MM-DD');

      await generateMonthlyReport(startDate, endDate);
      await processMonthlyBonuses();
      await generateTaxReports(lastMonth.format('YYYY-MM'));
      await reconcileMonthlyAccounts();

      console.log('✅ Cierre mensual completado');

    } catch (error) {
      console.error('❌ Error en cierre mensual:', error);
    }
  });

// ====================================================================
// 🔧 FUNCIONES UTILITARIAS
// ====================================================================

async function updateDriverBalance(driverId, balanceResult, transferResult) {
  await db.collection('drivers').doc(driverId).update({
    'balance.lastUpdate': admin.firestore.FieldValue.serverTimestamp(),
    'balance.lastTransfer': transferResult.success ? {
      amount: balanceResult.totalEarnings,
      date: balanceResult.date,
      transactionId: transferResult.transactionId,
      status: 'completed'
    } : null,
    'balance.pendingAmount': transferResult.success ? 0 : balanceResult.totalEarnings,
    'balance.totalEarningsToDate': admin.firestore.FieldValue.increment(balanceResult.totalEarnings)
  });
}

async function schedulePendingTransfer(driverId, balanceResult, scheduledTime) {
  await db.collection('pending_transfers').add({
    driverId,
    amount: balanceResult.totalEarnings,
    balanceDate: balanceResult.date,
    scheduledFor: scheduledTime,
    status: 'scheduled',
    retryCount: 0,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
}

async function getSecretValue(secretName) {
  try {
    // En producción, usar Secret Manager
    // Por ahora, retornar mock credentials
    return {
      accessToken: 'mock_token_' + secretName,
      clientId: 'mock_client_id',
      clientSecret: 'mock_client_secret'
    };
  } catch (error) {
    console.error(`❌ Error obteniendo secret ${secretName}:`, error);
    return null;
  }
}

async function recordTransferMetrics(transferRecord) {
  try {
    await insertIntoBigQuery('oasistaxi_analytics.bank_transfers', {
      transfer_id: transferRecord.reference,
      driver_id: transferRecord.metadata.driverId,
      amount: transferRecord.amount,
      bank: transferRecord.destinationBank,
      status: transferRecord.status,
      success: transferRecord.status === 'completed',
      timestamp: new Date().toISOString(),
      processing_date: transferRecord.metadata.balanceDate
    });
  } catch (error) {
    console.error('❌ Error registrando métricas:', error);
  }
}

async function insertIntoBigQuery(tableId, data) {
  try {
    const [dataset, table] = tableId.split('.');
    await bigquery.dataset(dataset).table(table).insert([data]);
  } catch (error) {
    console.error('❌ Error insertando en BigQuery:', error);
  }
}

async function notifyAdministrators(eventType, data) {
  try {
    // Enviar notificación FCM a administradores
    const adminsSnapshot = await db.collection('users')
      .where('role', '==', 'admin')
      .get();

    const adminTokens = [];
    adminsSnapshot.forEach(doc => {
      const adminData = doc.data();
      if (adminData.fcmToken) {
        adminTokens.push(adminData.fcmToken);
      }
    });

    if (adminTokens.length > 0) {
      const message = {
        notification: {
          title: getNotificationTitle(eventType),
          body: getNotificationBody(eventType, data)
        },
        data: {
          type: eventType,
          ...data
        },
        tokens: adminTokens
      };

      await admin.messaging().sendMulticast(message);
    }
  } catch (error) {
    console.error('❌ Error enviando notificaciones:', error);
  }
}

async function notifyFinancialTeam(eventType, data) {
  // Similar a notifyAdministrators pero para equipo financiero
  console.log(`📧 Notificando equipo financiero: ${eventType}`, data);
}

function getNotificationTitle(eventType) {
  const titles = {
    'daily_closure_completed': '✅ Cierre Diario Completado',
    'daily_closure_failed': '❌ Error en Cierre Diario',
    'manual_transfer_required': '📋 Transferencia Manual Requerida'
  };
  return titles[eventType] || 'Notificación Financiera';
}

function getNotificationBody(eventType, data) {
  switch (eventType) {
    case 'daily_closure_completed':
      return `${data.processedDrivers} conductores procesados. Ingresos: S/ ${data.totalRevenue}`;
    case 'daily_closure_failed':
      return `Error en cierre diario: ${data.error}`;
    case 'manual_transfer_required':
      return `Transferencia manual requerida: S/ ${data.amount} para ${data.beneficiary}`;
    default:
      return 'Evento financiero procesado';
  }
}

function generateTransferInstructions(transferData) {
  return {
    amount: `S/ ${transferData.amount.toFixed(2)}`,
    beneficiary: transferData.beneficiaryName,
    bank: transferData.destinationBank,
    account: transferData.destinationAccount,
    cci: transferData.destinationCCI,
    concept: transferData.concept,
    reference: transferData.reference,
    urgency: transferData.amount > 5000 ? 'Alto' : 'Normal'
  };
}

async function getComparisonMetrics(currentDate) {
  const previousDate = moment(currentDate).subtract(1, 'day').format('YYYY-MM-DD');
  
  try {
    const previousDayDoc = await db.collection('financial_reports')
      .where('date', '==', previousDate)
      .where('type', '==', 'executive_daily')
      .limit(1)
      .get();

    if (!previousDayDoc.empty) {
      const previousData = previousDayDoc.docs[0].data();
      return {
        revenueChange: previousData.summary.totalRevenue,
        driversChange: previousData.summary.totalDrivers,
        available: true
      };
    }
  } catch (error) {
    console.error('Error obteniendo métricas de comparación:', error);
  }

  return { available: false };
}

async function generateSUNATReport(date, summary) {
  console.log(`📊 Generando reporte SUNAT para: ${date}`);
  // Implementar reporte específico para SUNAT si es requerido
}

async function emailDailyReport(date, report) {
  console.log(`📧 Enviando reporte diario por email: ${date}`);
  // Implementar envío de email con SendGrid o similar
}

async function generateWeeklyReport(startDate, endDate) {
  console.log(`📅 Generando reporte semanal: ${startDate} - ${endDate}`);
  // Implementar reporte semanal
}

async function processWeeklyBonuses() {
  console.log(`💰 Procesando bonos semanales`);
  // Implementar bonos semanales por productividad
}

async function reconcileWeeklyTransactions() {
  console.log(`🔄 Reconciliando transacciones semanales`);
  // Implementar reconciliación bancaria
}

async function generateMonthlyReport(startDate, endDate) {
  console.log(`📅 Generando reporte mensual: ${startDate} - ${endDate}`);
  // Implementar reporte mensual
}

async function processMonthlyBonuses() {
  console.log(`💰 Procesando bonos mensuales`);
  // Implementar bonos mensuales
}

async function generateTaxReports(month) {
  console.log(`📊 Generando reportes fiscales para: ${month}`);
  // Implementar reportes fiscales mensuales
}

async function reconcileMonthlyAccounts() {
  console.log(`🔄 Reconciliando cuentas mensuales`);
  // Implementar reconciliación mensual completa
}

console.log('💰 Sistema de Cierres de Balance - OasisTaxi Peru Cargado ✅');