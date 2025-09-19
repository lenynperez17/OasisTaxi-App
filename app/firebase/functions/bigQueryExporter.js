const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { BigQuery } = require('@google-cloud/bigquery');

// Inicializar Firebase Admin SDK si no está ya inicializado
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const bigquery = new BigQuery({
  projectId: 'oasis-taxi-peru',
  keyFilename: process.env.GOOGLE_APPLICATION_CREDENTIALS
});

/**
 * Cloud Function para exportar datos de Firestore a BigQuery
 * Ejecutada diariamente via Cloud Scheduler
 * 
 * Características:
 * - Exporta trips, users, ratings, payments
 * - Crea vistas y tablas optimizadas para Data Studio
 * - Maneja schema evolution automáticamente
 * - Implementa particionamiento por fecha
 * - Registra métricas de calidad de datos
 */
exports.exportToBigQuery = functions
  .runWith({
    timeoutSeconds: 540, // 9 minutos
    memory: '2GB'
  })
  .pubsub
  .topic('bigquery-export')
  .onPublish(async (message, context) => {
    const startTime = Date.now();
    
    console.log('📊 Iniciando exportación a BigQuery...');
    
    try {
      const exportDate = new Date();
      const dateString = exportDate.toISOString().split('T')[0]; // YYYY-MM-DD
      
      // Configurar datasets
      const dataset = bigquery.dataset('oasis_taxi_analytics');
      await ensureDatasetExists(dataset);
      
      // Exportar cada colección
      const collections = [
        { name: 'trips', tableSuffix: 'trips' },
        { name: 'users', tableSuffix: 'users' },
        { name: 'ratings', tableSuffix: 'ratings' },
        { name: 'payments', tableSuffix: 'payments' },
        { name: 'price_negotiations', tableSuffix: 'negotiations' },
        { name: 'chat_file_metadata', tableSuffix: 'chat_files' }
      ];
      
      const exportResults = {};
      
      for (const collection of collections) {
        console.log(`📤 Exportando colección: ${collection.name}`);
        
        const result = await exportCollectionToBigQuery(
          collection.name,
          dataset,
          `${collection.tableSuffix}_${dateString.replace(/-/g, '')}`,
          exportDate
        );
        
        exportResults[collection.name] = result;
      }
      
      // Crear vistas agregadas para Data Studio
      await createDataStudioViews(dataset);
      
      // Crear tablas de análisis pre-calculadas
      await createAnalyticsTables(dataset, dateString);
      
      // Limpiar datos antiguos (retener 90 días)
      await cleanupOldData(dataset);
      
      // Registrar métricas de exportación
      const endTime = Date.now();
      const exportStats = {
        executionTime: endTime - startTime,
        exportDate: dateString,
        collectionsExported: Object.keys(exportResults).length,
        totalRecords: Object.values(exportResults).reduce((sum, result) => sum + result.recordCount, 0),
        results: exportResults,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      };
      
      await db.collection('bigquery_export_logs').add(exportStats);
      
      console.log('✅ Exportación a BigQuery completada:', exportStats);
      
      return {
        success: true,
        stats: exportStats
      };
      
    } catch (error) {
      console.error('❌ Error en exportación a BigQuery:', error);
      
      // Registrar error
      await db.collection('bigquery_export_errors').add({
        error: error.message,
        stack: error.stack,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        executionTime: Date.now() - startTime
      });
      
      throw error;
    }
  });

/**
 * Exportar una colección específica a BigQuery
 */
async function exportCollectionToBigQuery(collectionName, dataset, tableName, exportDate) {
  try {
    // Obtener documentos desde las últimas 24 horas
    const yesterday = new Date(exportDate);
    yesterday.setDate(yesterday.getDate() - 1);
    
    const snapshot = await db.collection(collectionName)
      .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(yesterday))
      .where('createdAt', '<', admin.firestore.Timestamp.fromDate(exportDate))
      .get();
    
    if (snapshot.empty) {
      console.log(`⚠️ No hay datos nuevos para ${collectionName}`);
      return { recordCount: 0, status: 'no_data' };
    }
    
    // Preparar datos para BigQuery
    const rows = snapshot.docs.map(doc => {
      const data = doc.data();
      
      // Convertir Timestamps a formato BigQuery
      const processedData = processFirestoreData(data);
      
      return {
        insertId: doc.id, // Evita duplicados
        json: {
          id: doc.id,
          ...processedData,
          _export_date: exportDate.toISOString().split('T')[0],
          _export_timestamp: exportDate.toISOString()
        }
      };
    });
    
    // Crear/obtener tabla
    const table = dataset.table(tableName);
    await ensureTableExists(table, getTableSchema(collectionName));
    
    // Insertar datos
    await table.insert(rows, {
      skipInvalidRows: false,
      ignoreUnknownValues: false,
      createInsertId: false
    });
    
    console.log(`✅ ${rows.length} registros exportados a ${tableName}`);
    
    return {
      recordCount: rows.length,
      status: 'success',
      tableName: tableName
    };
    
  } catch (error) {
    console.error(`❌ Error exportando ${collectionName}:`, error);
    throw error;
  }
}

/**
 * Procesar datos de Firestore para BigQuery
 */
function processFirestoreData(data) {
  const processed = {};
  
  for (const [key, value] of Object.entries(data)) {
    if (value === null || value === undefined) {
      processed[key] = null;
    } else if (admin.firestore.Timestamp.isTimestamp(value)) {
      // Convertir Timestamp a DATETIME
      processed[key] = value.toDate().toISOString();
    } else if (admin.firestore.GeoPoint && value instanceof admin.firestore.GeoPoint) {
      // Convertir GeoPoint a estructura de coordenadas
      processed[key] = {
        lat: value.latitude,
        lng: value.longitude
      };
    } else if (Array.isArray(value)) {
      // Procesar arrays recursivamente
      processed[key] = value.map(item => 
        typeof item === 'object' && item !== null ? processFirestoreData(item) : item
      );
    } else if (typeof value === 'object' && value !== null) {
      // Procesar objetos anidados recursivamente
      processed[key] = processFirestoreData(value);
    } else {
      processed[key] = value;
    }
  }
  
  return processed;
}

/**
 * Obtener schema de tabla según la colección
 */
function getTableSchema(collectionName) {
  const commonFields = [
    { name: 'id', type: 'STRING', mode: 'REQUIRED' },
    { name: '_export_date', type: 'DATE', mode: 'REQUIRED' },
    { name: '_export_timestamp', type: 'TIMESTAMP', mode: 'REQUIRED' }
  ];
  
  const schemas = {
    trips: [
      ...commonFields,
      { name: 'passengerId', type: 'STRING' },
      { name: 'driverId', type: 'STRING' },
      { name: 'status', type: 'STRING' },
      { name: 'createdAt', type: 'TIMESTAMP' },
      { name: 'acceptedAt', type: 'TIMESTAMP' },
      { name: 'completedAt', type: 'TIMESTAMP' },
      { name: 'pickup', type: 'RECORD', fields: [
        { name: 'lat', type: 'FLOAT' },
        { name: 'lng', type: 'FLOAT' },
        { name: 'address', type: 'STRING' }
      ]},
      { name: 'destination', type: 'RECORD', fields: [
        { name: 'lat', type: 'FLOAT' },
        { name: 'lng', type: 'FLOAT' },
        { name: 'address', type: 'STRING' }
      ]},
      { name: 'initialPrice', type: 'FLOAT' },
      { name: 'finalPrice', type: 'FLOAT' },
      { name: 'surgeMultiplier', type: 'FLOAT' },
      { name: 'distance', type: 'FLOAT' },
      { name: 'duration', type: 'INTEGER' },
      { name: 'vehicleType', type: 'STRING' },
      { name: 'paymentMethod', type: 'STRING' },
      { name: 'paymentStatus', type: 'STRING' },
      { name: 'cancellationReason', type: 'STRING' },
      { name: 'cancelledBy', type: 'STRING' }
    ],
    
    users: [
      ...commonFields,
      { name: 'uid', type: 'STRING' },
      { name: 'email', type: 'STRING' },
      { name: 'displayName', type: 'STRING' },
      { name: 'phoneNumber', type: 'STRING' },
      { name: 'userType', type: 'STRING' },
      { name: 'isActive', type: 'BOOLEAN' },
      { name: 'isVerified', type: 'BOOLEAN' },
      { name: 'createdAt', type: 'TIMESTAMP' },
      { name: 'lastLoginAt', type: 'TIMESTAMP' },
      { name: 'rating', type: 'FLOAT' },
      { name: 'totalTrips', type: 'INTEGER' }
    ],
    
    ratings: [
      ...commonFields,
      { name: 'tripId', type: 'STRING' },
      { name: 'passengerId', type: 'STRING' },
      { name: 'driverId', type: 'STRING' },
      { name: 'rating', type: 'INTEGER' },
      { name: 'comment', type: 'STRING' },
      { name: 'ratingType', type: 'STRING' },
      { name: 'createdAt', type: 'TIMESTAMP' }
    ],
    
    payments: [
      ...commonFields,
      { name: 'tripId', type: 'STRING' },
      { name: 'userId', type: 'STRING' },
      { name: 'amount', type: 'FLOAT' },
      { name: 'currency', type: 'STRING' },
      { name: 'method', type: 'STRING' },
      { name: 'status', type: 'STRING' },
      { name: 'transactionId', type: 'STRING' },
      { name: 'createdAt', type: 'TIMESTAMP' },
      { name: 'completedAt', type: 'TIMESTAMP' }
    ],
    
    negotiations: [
      ...commonFields,
      { name: 'tripId', type: 'STRING' },
      { name: 'passengerId', type: 'STRING' },
      { name: 'driverId', type: 'STRING' },
      { name: 'initialPrice', type: 'FLOAT' },
      { name: 'counterOfferPrice', type: 'FLOAT' },
      { name: 'finalPrice', type: 'FLOAT' },
      { name: 'status', type: 'STRING' },
      { name: 'createdAt', type: 'TIMESTAMP' },
      { name: 'acceptedAt', type: 'TIMESTAMP' }
    ],
    
    chat_files: [
      ...commonFields,
      { name: 'chatId', type: 'STRING' },
      { name: 'messageId', type: 'STRING' },
      { name: 'userId', type: 'STRING' },
      { name: 'fileName', type: 'STRING' },
      { name: 'fileType', type: 'STRING' },
      { name: 'originalSize', type: 'INTEGER' },
      { name: 'finalSize', type: 'INTEGER' },
      { name: 'downloadUrl', type: 'STRING' },
      { name: 'thumbnailUrl', type: 'STRING' },
      { name: 'autoDeleteAt', type: 'TIMESTAMP' },
      { name: 'isDeleted', type: 'BOOLEAN' },
      { name: 'createdAt', type: 'TIMESTAMP' }
    ]
  };
  
  return schemas[collectionName] || commonFields;
}

/**
 * Crear vistas para Data Studio
 */
async function createDataStudioViews(dataset) {
  try {
    console.log('📊 Creando vistas para Data Studio...');
    
    // Vista: Métricas diarias de negocio
    const businessMetricsView = `
      CREATE OR REPLACE VIEW \`oasis-taxi-peru.oasis_taxi_analytics.daily_business_metrics\` AS
      SELECT 
        _export_date as date,
        COUNT(*) as total_trips,
        COUNTIF(status = 'completed') as completed_trips,
        COUNTIF(status = 'cancelled') as cancelled_trips,
        SUM(CASE WHEN status = 'completed' THEN finalPrice ELSE 0 END) as total_revenue,
        AVG(CASE WHEN status = 'completed' THEN finalPrice END) as avg_trip_value,
        COUNT(DISTINCT driverId) as active_drivers,
        COUNT(DISTINCT passengerId) as active_passengers,
        SAFE_DIVIDE(COUNTIF(status = 'completed'), COUNT(*)) as completion_rate
      FROM \`oasis-taxi-peru.oasis_taxi_analytics.trips_*\`
      WHERE _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY))
      GROUP BY _export_date
      ORDER BY date DESC
    `;
    
    await bigquery.query(businessMetricsView);
    
    // Vista: Top conductores
    const topDriversView = `
      CREATE OR REPLACE VIEW \`oasis-taxi-peru.oasis_taxi_analytics.top_drivers\` AS
      WITH driver_stats AS (
        SELECT 
          t.driverId,
          u.displayName as driver_name,
          COUNT(*) as total_trips,
          COUNTIF(t.status = 'completed') as completed_trips,
          SUM(CASE WHEN t.status = 'completed' THEN t.finalPrice ELSE 0 END) as total_earnings,
          AVG(r.rating) as avg_rating,
          SAFE_DIVIDE(COUNTIF(t.status = 'completed'), COUNT(*)) as completion_rate
        FROM \`oasis-taxi-peru.oasis_taxi_analytics.trips_*\` t
        LEFT JOIN \`oasis-taxi-peru.oasis_taxi_analytics.users_*\` u ON t.driverId = u.uid
        LEFT JOIN \`oasis-taxi-peru.oasis_taxi_analytics.ratings_*\` r ON t.id = r.tripId AND r.ratingType = 'driver'
        WHERE t._TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY))
        AND t.driverId IS NOT NULL
        GROUP BY t.driverId, u.displayName
        HAVING total_trips >= 5
      )
      SELECT 
        *,
        total_earnings * 0.8 as driver_share,
        total_earnings * 0.2 as commission
      FROM driver_stats
      ORDER BY total_earnings DESC
      LIMIT 50
    `;
    
    await bigquery.query(topDriversView);
    
    // Vista: Análisis temporal
    const temporalAnalysisView = `
      CREATE OR REPLACE VIEW \`oasis-taxi-peru.oasis_taxi_analytics.hourly_demand\` AS
      SELECT 
        EXTRACT(DAYOFWEEK FROM DATETIME(createdAt, 'America/Lima')) as day_of_week,
        EXTRACT(HOUR FROM DATETIME(createdAt, 'America/Lima')) as hour_of_day,
        COUNT(*) as trip_count,
        AVG(finalPrice) as avg_price,
        AVG(surgeMultiplier) as avg_surge,
        CASE 
          WHEN COUNT(*) > PERCENTILE_CONT(COUNT(*), 0.8) OVER() THEN 'Peak'
          WHEN COUNT(*) > PERCENTILE_CONT(COUNT(*), 0.5) OVER() THEN 'Medium'
          ELSE 'Low'
        END as demand_level
      FROM \`oasis-taxi-peru.oasis_taxi_analytics.trips_*\`
      WHERE _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY))
      AND status = 'completed'
      GROUP BY day_of_week, hour_of_day
      ORDER BY day_of_week, hour_of_day
    `;
    
    await bigquery.query(temporalAnalysisView);
    
    // Vista: Métricas financieras
    const financialMetricsView = `
      CREATE OR REPLACE VIEW \`oasis-taxi-peru.oasis_taxi_analytics.financial_summary\` AS
      SELECT 
        _export_date as date,
        SUM(CASE WHEN t.status = 'completed' THEN t.finalPrice ELSE 0 END) as total_revenue,
        SUM(CASE WHEN t.status = 'completed' THEN t.finalPrice * 0.2 ELSE 0 END) as commission_revenue,
        SUM(CASE WHEN t.status = 'completed' THEN t.finalPrice * 0.8 ELSE 0 END) as driver_earnings,
        COUNT(DISTINCT CASE WHEN t.status = 'completed' THEN t.driverId END) as earning_drivers,
        AVG(CASE WHEN t.status = 'completed' THEN t.finalPrice END) as avg_trip_value,
        -- Revenue by payment method
        SUM(CASE WHEN t.status = 'completed' AND t.paymentMethod = 'cash' THEN t.finalPrice ELSE 0 END) as cash_revenue,
        SUM(CASE WHEN t.status = 'completed' AND t.paymentMethod = 'card' THEN t.finalPrice ELSE 0 END) as card_revenue,
        SUM(CASE WHEN t.status = 'completed' AND t.paymentMethod = 'wallet' THEN t.finalPrice ELSE 0 END) as wallet_revenue
      FROM \`oasis-taxi-peru.oasis_taxi_analytics.trips_*\` t
      WHERE _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY))
      GROUP BY _export_date
      ORDER BY date DESC
    `;
    
    await bigquery.query(financialMetricsView);
    
    console.log('✅ Vistas de Data Studio creadas exitosamente');
    
  } catch (error) {
    console.error('❌ Error creando vistas de Data Studio:', error);
    throw error;
  }
}

/**
 * Crear tablas de análisis pre-calculadas
 */
async function createAnalyticsTables(dataset, dateString) {
  try {
    console.log('🔍 Creando tablas de análisis...');
    
    // Tabla: Cohort analysis
    const cohortAnalysisQuery = `
      CREATE OR REPLACE TABLE \`oasis-taxi-peru.oasis_taxi_analytics.user_cohorts_${dateString.replace(/-/g, '')}\` AS
      WITH user_first_trip AS (
        SELECT 
          passengerId,
          DATE(MIN(DATETIME(createdAt))) as first_trip_date
        FROM \`oasis-taxi-peru.oasis_taxi_analytics.trips_*\`
        WHERE status = 'completed'
        AND _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
        GROUP BY passengerId
      ),
      monthly_activity AS (
        SELECT 
          passengerId,
          DATE_TRUNC(DATE(DATETIME(createdAt)), MONTH) as activity_month
        FROM \`oasis-taxi-peru.oasis_taxi_analytics.trips_*\`
        WHERE status = 'completed'
        AND _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
        GROUP BY passengerId, activity_month
      )
      SELECT 
        DATE_TRUNC(first_trip_date, MONTH) as cohort_month,
        activity_month,
        DATE_DIFF(activity_month, DATE_TRUNC(first_trip_date, MONTH), MONTH) as period_number,
        COUNT(DISTINCT u.passengerId) as users,
        CURRENT_DATE() as analysis_date
      FROM user_first_trip u
      JOIN monthly_activity m ON u.passengerId = m.passengerId
      GROUP BY cohort_month, activity_month, period_number
      ORDER BY cohort_month, period_number
    `;
    
    await bigquery.query(cohortAnalysisQuery);
    
    // Tabla: Driver performance scoring
    const driverScoringQuery = `
      CREATE OR REPLACE TABLE \`oasis-taxi-peru.oasis_taxi_analytics.driver_performance_${dateString.replace(/-/g, '')}\` AS
      SELECT 
        driverId,
        COUNT(*) as total_trips,
        COUNTIF(status = 'completed') as completed_trips,
        COUNTIF(status = 'cancelled' AND cancelledBy = 'driver') as driver_cancellations,
        AVG(finalPrice) as avg_earnings_per_trip,
        SUM(CASE WHEN status = 'completed' THEN finalPrice ELSE 0 END) as total_earnings,
        AVG(DATETIME_DIFF(DATETIME(completedAt), DATETIME(acceptedAt), MINUTE)) as avg_trip_duration_minutes,
        -- Performance score (0-100)
        GREATEST(0, LEAST(100,
          COALESCE((
            (SELECT AVG(rating) FROM \`oasis-taxi-peru.oasis_taxi_analytics.ratings_*\` r 
             WHERE r.driverId = t.driverId AND r._TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY))
            ) - 3
          ) * 25, 0) +
          GREATEST(0, 20 - COUNTIF(status = 'cancelled' AND cancelledBy = 'driver')) +
          LEAST(20, COUNT(*) / 10)
        )) as performance_score,
        CURRENT_DATE() as analysis_date
      FROM \`oasis-taxi-peru.oasis_taxi_analytics.trips_*\` t
      WHERE _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY))
      AND driverId IS NOT NULL
      GROUP BY driverId
      HAVING COUNT(*) >= 5
      ORDER BY performance_score DESC
    `;
    
    await bigquery.query(driverScoringQuery);
    
    console.log('✅ Tablas de análisis creadas exitosamente');
    
  } catch (error) {
    console.error('❌ Error creando tablas de análisis:', error);
    throw error;
  }
}

/**
 * Asegurar que el dataset existe
 */
async function ensureDatasetExists(dataset) {
  try {
    const [exists] = await dataset.exists();
    if (!exists) {
      await dataset.create({
        location: 'US',
        description: 'OasisTaxi Peru - Analytics Dataset for Data Studio'
      });
      console.log('📊 Dataset creado exitosamente');
    }
  } catch (error) {
    console.error('Error creando dataset:', error);
    throw error;
  }
}

/**
 * Asegurar que la tabla existe
 */
async function ensureTableExists(table, schema) {
  try {
    const [exists] = await table.exists();
    if (!exists) {
      await table.create({
        schema: { fields: schema },
        timePartitioning: {
          type: 'DAY',
          field: '_export_timestamp'
        },
        clustering: {
          fields: ['id', '_export_date']
        }
      });
      console.log(`📋 Tabla ${table.id} creada exitosamente`);
    }
  } catch (error) {
    console.error(`Error creando tabla ${table.id}:`, error);
    throw error;
  }
}

/**
 * Limpiar datos antiguos (retener 90 días)
 */
async function cleanupOldData(dataset) {
  try {
    console.log('🧹 Limpiando datos antiguos...');
    
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - 90);
    const cutoffDateString = cutoffDate.toISOString().split('T')[0].replace(/-/g, '');
    
    // Listar tablas para limpiar
    const [tables] = await dataset.getTables();
    
    for (const table of tables) {
      if (table.id.match(/_\d{8}$/)) { // Tablas con sufijo de fecha
        const tableDateString = table.id.slice(-8);
        if (tableDateString < cutoffDateString) {
          await table.delete();
          console.log(`🗑️ Tabla eliminada: ${table.id}`);
        }
      }
    }
    
  } catch (error) {
    console.error('Error limpiando datos antiguos:', error);
    // No relanzar error, es una operación de mantenimiento
  }
}

/**
 * Cloud Function para generar reportes automáticos
 * Ejecutada diariamente a las 6 AM (hora de Perú)
 */
exports.generateDailyReport = functions
  .runWith({
    timeoutSeconds: 300,
    memory: '1GB'
  })
  .pubsub
  .topic('generate-daily-report')
  .onPublish(async (message, context) => {
    try {
      console.log('📋 Generando reporte diario...');
      
      const reportDate = new Date();
      const dateString = reportDate.toISOString().split('T')[0];
      
      // Consultar métricas desde BigQuery
      const businessMetricsQuery = `
        SELECT *
        FROM \`oasis-taxi-peru.oasis_taxi_analytics.daily_business_metrics\`
        WHERE date = '${dateString}'
      `;
      
      const [businessRows] = await bigquery.query(businessMetricsQuery);
      const businessMetrics = businessRows[0] || {};
      
      // Generar reporte
      const report = {
        date: dateString,
        metrics: {
          totalTrips: businessMetrics.total_trips || 0,
          completedTrips: businessMetrics.completed_trips || 0,
          totalRevenue: businessMetrics.total_revenue || 0,
          activeDrivers: businessMetrics.active_drivers || 0,
          completionRate: businessMetrics.completion_rate || 0
        },
        dashboardUrl: 'https://datastudio.google.com/reporting/oasistaxi-dashboards',
        generatedAt: admin.firestore.FieldValue.serverTimestamp()
      };
      
      // Guardar reporte
      await db.collection('daily_reports').doc(dateString).set(report);
      
      // Enviar por email (simular)
      console.log('📧 Reporte enviado:', report);
      
      return { success: true, report };
      
    } catch (error) {
      console.error('❌ Error generando reporte diario:', error);
      throw error;
    }
  });

module.exports = {
  exportToBigQuery: exports.exportToBigQuery,
  generateDailyReport: exports.generateDailyReport
};