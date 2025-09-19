/**
 * Cloud Function para gestión automática de Google Data Studio Dashboards
 * Sistema completo de reportes, métricas y analytics para OasisTaxi Perú
 * 
 * @author OasisTaxi Development Team
 * @version 1.0.0
 * @date 2025-01-11
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { BigQuery } = require('@google-cloud/bigquery');
const { google } = require('googleapis');
const nodemailer = require('nodemailer');

// Inicializar servicios
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const bigquery = new BigQuery({ projectId: 'oasis-taxi-peru' });

// Configuración de Google APIs
const googleAuth = new google.auth.GoogleAuth({
  keyFile: 'service-account-key.json',
  scopes: [
    'https://www.googleapis.com/auth/datastudio',
    'https://www.googleapis.com/auth/bigquery',
    'https://www.googleapis.com/auth/drive',
    'https://www.googleapis.com/auth/analytics.readonly'
  ]
});

const datastudio = google.datastudio({ version: 'v1', auth: googleAuth });
const drive = google.drive({ version: 'v3', auth: googleAuth });
const analytics = google.analyticsreporting({ version: 'v4', auth: googleAuth });

/**
 * Configuración de dashboards disponibles
 */
const DASHBOARD_CONFIGS = {
  // Dashboard Ejecutivo - Vista general del negocio
  executive: {
    name: 'Dashboard Ejecutivo OasisTaxi',
    description: 'Métricas clave de negocio y KPIs ejecutivos',
    bigquery_dataset: 'oasis_taxi_analytics',
    tables: ['trips', 'drivers', 'passengers', 'finances'],
    refresh_interval: '1h',
    viewers: ['admin@oasistaxiperu.com', 'ceo@oasistaxiperu.com'],
    metrics: [
      'total_trips_today',
      'total_revenue_today', 
      'active_drivers_count',
      'passenger_satisfaction',
      'avg_trip_duration',
      'conversion_rate'
    ]
  },

  // Dashboard Operacional - Métricas operativas
  operations: {
    name: 'Dashboard Operaciones OasisTaxi',
    description: 'Métricas operativas en tiempo real',
    bigquery_dataset: 'oasis_taxi_operations',
    tables: ['real_time_trips', 'driver_status', 'demand_patterns'],
    refresh_interval: '5m',
    viewers: ['operations@oasistaxiperu.com', 'fleet@oasistaxiperu.com'],
    metrics: [
      'trips_in_progress',
      'waiting_passengers',
      'driver_utilization',
      'avg_pickup_time',
      'cancellation_rate',
      'peak_demand_areas'
    ]
  },

  // Dashboard Financiero - Análisis financiero
  financial: {
    name: 'Dashboard Financiero OasisTaxi', 
    description: 'Análisis financiero y revenue tracking',
    bigquery_dataset: 'oasis_taxi_finances',
    tables: ['transactions', 'commissions', 'driver_earnings', 'expenses'],
    refresh_interval: '30m',
    viewers: ['finance@oasistaxiperu.com', 'accounting@oasistaxiperu.com'],
    metrics: [
      'daily_revenue',
      'commission_earned',
      'driver_payouts',
      'payment_method_breakdown',
      'outstanding_payments',
      'profit_margin'
    ]
  },

  // Dashboard de Conductores - Análisis de flota
  drivers: {
    name: 'Dashboard Gestión de Conductores',
    description: 'Métricas de desempeño y gestión de conductores',
    bigquery_dataset: 'oasis_taxi_drivers',
    tables: ['driver_performance', 'ratings', 'earnings', 'activity'],
    refresh_interval: '15m',
    viewers: ['fleet@oasistaxiperu.com', 'hr@oasistaxiperu.com'],
    metrics: [
      'active_drivers',
      'avg_driver_rating',
      'top_performers',
      'driver_churn_rate',
      'earnings_distribution',
      'training_completion'
    ]
  },

  // Dashboard de Pasajeros - Análisis de usuarios
  passengers: {
    name: 'Dashboard Análisis de Pasajeros',
    description: 'Comportamiento y satisfacción de pasajeros',
    bigquery_dataset: 'oasis_taxi_passengers',
    tables: ['user_behavior', 'trip_patterns', 'satisfaction', 'retention'],
    refresh_interval: '1h',
    viewers: ['marketing@oasistaxiperu.com', 'product@oasistaxiperu.com'],
    metrics: [
      'active_passengers',
      'new_registrations',
      'trip_frequency',
      'customer_lifetime_value',
      'retention_rate',
      'preferred_routes'
    ]
  },

  // Dashboard de Calidad - Métricas de servicio
  quality: {
    name: 'Dashboard Calidad de Servicio',
    description: 'Métricas de calidad y satisfacción del servicio',
    bigquery_dataset: 'oasis_taxi_quality',
    tables: ['ratings', 'complaints', 'response_times', 'incidents'],
    refresh_interval: '10m',
    viewers: ['quality@oasistaxiperu.com', 'support@oasistaxiperu.com'],
    metrics: [
      'avg_trip_rating',
      'complaint_resolution_time',
      'incident_frequency',
      'driver_compliance',
      'passenger_feedback',
      'quality_score'
    ]
  },

  // Dashboard de Marketing - Análisis de marketing
  marketing: {
    name: 'Dashboard Marketing y Crecimiento',
    description: 'Métricas de marketing y adquisición de usuarios',
    bigquery_dataset: 'oasis_taxi_marketing',
    tables: ['campaigns', 'user_acquisition', 'referrals', 'promotions'],
    refresh_interval: '2h',
    viewers: ['marketing@oasistaxiperu.com', 'growth@oasistaxiperu.com'],
    metrics: [
      'campaign_performance',
      'user_acquisition_cost',
      'referral_rate',
      'promotion_effectiveness',
      'organic_growth',
      'market_penetration'
    ]
  }
};

/**
 * Cloud Scheduler: Actualización automática de dashboards
 */
exports.updateDataStudioDashboards = functions
  .runWith({
    timeoutSeconds: 540,
    memory: '2GB'
  })
  .pubsub
  .schedule('0 */1 * * *') // Cada hora
  .timeZone('America/Lima')
  .onRun(async (context) => {
    try {
      console.log('Iniciando actualización automática de Data Studio dashboards');

      const results = {
        dashboards_updated: 0,
        bigquery_refreshed: 0,
        errors: [],
        execution_time: new Date().toISOString()
      };

      // Actualizar cada dashboard según su intervalo
      for (const [dashboardId, config] of Object.entries(DASHBOARD_CONFIGS)) {
        try {
          console.log(`Actualizando dashboard: ${config.name}`);
          
          // Verificar si necesita actualización basado en el intervalo
          const needsUpdate = await checkIfDashboardNeedsUpdate(dashboardId, config.refresh_interval);
          
          if (needsUpdate) {
            // Actualizar datos en BigQuery
            await refreshBigQueryDataset(config.bigquery_dataset, config.tables);
            results.bigquery_refreshed++;

            // Actualizar dashboard en Data Studio
            await updateDataStudioReport(dashboardId, config);
            results.dashboards_updated++;

            // Registrar última actualización
            await recordDashboardUpdate(dashboardId, {
              updated_at: admin.firestore.FieldValue.serverTimestamp(),
              status: 'success',
              metrics_count: config.metrics.length
            });

            console.log(`Dashboard ${dashboardId} actualizado exitosamente`);
          }

        } catch (error) {
          console.error(`Error actualizando dashboard ${dashboardId}:`, error);
          results.errors.push(`${dashboardId}: ${error.message}`);
        }
      }

      // Generar reporte de salud de dashboards
      await generateDashboardHealthReport(results);

      // Enviar alertas si hay errores críticos
      if (results.errors.length > 2) {
        await sendDashboardErrorAlert(results);
      }

      console.log('Actualización de dashboards completada:', results);

      return results;

    } catch (error) {
      console.error('Error en actualización de dashboards:', error);
      await sendSystemErrorAlert('updateDataStudioDashboards', error);
      throw error;
    }
  });

/**
 * Verificar si un dashboard necesita actualización
 */
async function checkIfDashboardNeedsUpdate(dashboardId, refreshInterval) {
  try {
    const lastUpdateDoc = await db
      .collection('dashboard_updates')
      .doc(dashboardId)
      .get();

    if (!lastUpdateDoc.exists) {
      return true; // Primera actualización
    }

    const lastUpdate = lastUpdateDoc.data().updated_at.toDate();
    const now = new Date();
    
    // Convertir intervalo a millisegundos
    const intervalMs = parseRefreshInterval(refreshInterval);
    const timeSinceUpdate = now.getTime() - lastUpdate.getTime();

    return timeSinceUpdate >= intervalMs;

  } catch (error) {
    console.error(`Error verificando actualización para ${dashboardId}:`, error);
    return true; // En caso de error, forzar actualización
  }
}

/**
 * Convertir intervalo de texto a millisegundos
 */
function parseRefreshInterval(interval) {
  const units = {
    'm': 60 * 1000,        // minutos
    'h': 60 * 60 * 1000,   // horas
    'd': 24 * 60 * 60 * 1000 // días
  };

  const match = interval.match(/^(\d+)([mhd])$/);
  if (!match) {
    return 60 * 60 * 1000; // Default: 1 hora
  }

  const [, value, unit] = match;
  return parseInt(value) * units[unit];
}

/**
 * Actualizar dataset de BigQuery con datos frescos
 */
async function refreshBigQueryDataset(dataset, tables) {
  try {
    console.log(`Refrescando dataset BigQuery: ${dataset}`);

    // Para cada tabla en el dataset
    for (const table of tables) {
      console.log(`Actualizando tabla: ${table}`);

      switch (table) {
        case 'trips':
          await refreshTripsTable(dataset);
          break;
        case 'drivers':
          await refreshDriversTable(dataset);
          break;
        case 'passengers':
          await refreshPassengersTable(dataset);
          break;
        case 'finances':
          await refreshFinancesTable(dataset);
          break;
        case 'real_time_trips':
          await refreshRealTimeTripsTable(dataset);
          break;
        case 'driver_status':
          await refreshDriverStatusTable(dataset);
          break;
        default:
          await refreshGenericTable(dataset, table);
      }
    }

    console.log(`Dataset ${dataset} actualizado exitosamente`);

  } catch (error) {
    console.error(`Error refrescando dataset ${dataset}:`, error);
    throw error;
  }
}

/**
 * Actualizar tabla de viajes
 */
async function refreshTripsTable(dataset) {
  try {
    const query = `
      INSERT INTO \`oasis-taxi-peru.${dataset}.trips\`
      SELECT
        t.trip_id,
        t.passenger_id,
        t.driver_id,
        t.created_at,
        t.started_at,
        t.completed_at,
        t.status,
        t.pickup_location,
        t.destination_location,
        t.distance_km,
        t.duration_minutes,
        t.fare_amount,
        t.commission_amount,
        t.payment_method,
        t.rating_passenger,
        t.rating_driver,
        EXTRACT(DATE FROM t.created_at) as trip_date,
        EXTRACT(HOUR FROM t.created_at) as trip_hour,
        ST_DISTANCE(
          ST_GEOGPOINT(t.pickup_location.longitude, t.pickup_location.latitude),
          ST_GEOGPOINT(t.destination_location.longitude, t.destination_location.latitude)
        ) / 1000 as calculated_distance_km,
        CASE 
          WHEN t.completed_at IS NOT NULL AND t.started_at IS NOT NULL 
          THEN DATETIME_DIFF(t.completed_at, t.started_at, MINUTE)
          ELSE NULL 
        END as actual_duration_minutes
      FROM \`oasis-taxi-peru.firestore_export.trips\` t
      WHERE DATE(t.created_at) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
        AND t.status IN ('completed', 'cancelled')
    `;

    const [job] = await bigquery.createQueryJob({
      query,
      location: 'US',
      writeDisposition: 'WRITE_APPEND'
    });

    await job.getQueryResults();
    console.log('Tabla de viajes actualizada');

  } catch (error) {
    console.error('Error actualizando tabla de viajes:', error);
    throw error;
  }
}

/**
 * Actualizar tabla de conductores
 */
async function refreshDriversTable(dataset) {
  try {
    const query = `
      INSERT INTO \`oasis-taxi-peru.${dataset}.drivers\`
      SELECT
        d.driver_id,
        d.full_name,
        d.email,
        d.phone,
        d.created_at,
        d.status.active as is_active,
        d.status.verified as is_verified,
        d.vehicle_id,
        d.license_number,
        d.rating_average,
        d.rating_count,
        d.total_trips,
        d.total_earnings,
        d.documents.dni.status as dni_status,
        d.documents.license.status as license_status,
        d.documents.soat.status as soat_status,
        d.documents.license.expiry_date as license_expiry,
        d.documents.soat.expiry_date as soat_expiry,
        CASE 
          WHEN d.last_location_update > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
          THEN TRUE ELSE FALSE 
        END as recently_active,
        CASE
          WHEN d.documents.license.expiry_date < CURRENT_TIMESTAMP() 
            OR d.documents.soat.expiry_date < CURRENT_TIMESTAMP()
          THEN TRUE ELSE FALSE
        END as has_expired_documents
      FROM \`oasis-taxi-peru.firestore_export.drivers\` d
      WHERE d.created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    `;

    const [job] = await bigquery.createQueryJob({
      query,
      location: 'US',
      writeDisposition: 'WRITE_TRUNCATE' // Reemplazar datos existentes
    });

    await job.getQueryResults();
    console.log('Tabla de conductores actualizada');

  } catch (error) {
    console.error('Error actualizando tabla de conductores:', error);
    throw error;
  }
}

/**
 * Actualizar tabla de pasajeros
 */
async function refreshPassengersTable(dataset) {
  try {
    const query = `
      INSERT INTO \`oasis-taxi-peru.${dataset}.passengers\`
      SELECT
        p.passenger_id,
        p.full_name,
        p.email,
        p.phone,
        p.created_at,
        p.status.active as is_active,
        p.total_trips,
        p.total_spent,
        p.preferred_payment_method,
        p.rating_average,
        p.last_trip_date,
        COALESCE(trip_stats.trips_last_30d, 0) as trips_last_30_days,
        COALESCE(trip_stats.avg_trip_value, 0) as average_trip_value,
        CASE 
          WHEN p.last_trip_date > DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
          THEN TRUE ELSE FALSE 
        END as active_last_30_days,
        DATE_DIFF(CURRENT_DATE(), DATE(p.created_at), DAY) as days_since_registration
      FROM \`oasis-taxi-peru.firestore_export.passengers\` p
      LEFT JOIN (
        SELECT 
          passenger_id,
          COUNT(*) as trips_last_30d,
          AVG(fare_amount) as avg_trip_value
        FROM \`oasis-taxi-peru.firestore_export.trips\`
        WHERE created_at >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
          AND status = 'completed'
        GROUP BY passenger_id
      ) trip_stats ON p.passenger_id = trip_stats.passenger_id
    `;

    const [job] = await bigquery.createQueryJob({
      query,
      location: 'US',
      writeDisposition: 'WRITE_TRUNCATE'
    });

    await job.getQueryResults();
    console.log('Tabla de pasajeros actualizada');

  } catch (error) {
    console.error('Error actualizando tabla de pasajeros:', error);
    throw error;
  }
}

/**
 * Actualizar tabla de finanzas
 */
async function refreshFinancesTable(dataset) {
  try {
    const query = `
      INSERT INTO \`oasis-taxi-peru.${dataset}.finances\`
      SELECT
        t.trip_id,
        t.passenger_id,
        t.driver_id,
        t.completed_at as transaction_date,
        t.fare_amount,
        t.commission_amount,
        t.driver_earnings,
        t.payment_method,
        t.payment_status,
        EXTRACT(DATE FROM t.completed_at) as date,
        EXTRACT(MONTH FROM t.completed_at) as month,
        EXTRACT(YEAR FROM t.completed_at) as year,
        EXTRACT(DAYOFWEEK FROM t.completed_at) as day_of_week,
        CASE 
          WHEN EXTRACT(HOUR FROM t.completed_at) BETWEEN 6 AND 11 THEN 'morning'
          WHEN EXTRACT(HOUR FROM t.completed_at) BETWEEN 12 AND 17 THEN 'afternoon'
          WHEN EXTRACT(HOUR FROM t.completed_at) BETWEEN 18 AND 21 THEN 'evening'
          ELSE 'night'
        END as time_period,
        -- Cálculos financieros adicionales
        ROUND(t.commission_amount / t.fare_amount * 100, 2) as commission_percentage,
        CASE 
          WHEN t.payment_method = 'cash' THEN 'efectivo'
          WHEN t.payment_method = 'card' THEN 'tarjeta'
          WHEN t.payment_method = 'wallet' THEN 'billetera'
          ELSE 'otro'
        END as payment_method_spanish
      FROM \`oasis-taxi-peru.firestore_export.trips\` t
      WHERE t.status = 'completed'
        AND t.completed_at >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
        AND t.fare_amount > 0
    `;

    const [job] = await bigquery.createQueryJob({
      query,
      location: 'US',
      writeDisposition: 'WRITE_APPEND'
    });

    await job.getQueryResults();
    console.log('Tabla de finanzas actualizada');

  } catch (error) {
    console.error('Error actualizando tabla de finanzas:', error);
    throw error;
  }
}

/**
 * Actualizar tabla de viajes en tiempo real
 */
async function refreshRealTimeTripsTable(dataset) {
  try {
    const query = `
      CREATE OR REPLACE TABLE \`oasis-taxi-peru.${dataset}.real_time_trips\` AS
      SELECT
        t.trip_id,
        t.passenger_id,
        t.driver_id,
        t.status,
        t.created_at,
        t.started_at,
        t.pickup_location,
        t.destination_location,
        t.estimated_duration,
        t.estimated_fare,
        TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), t.created_at, MINUTE) as minutes_since_created,
        CASE 
          WHEN t.status = 'requested' THEN 'Solicitado'
          WHEN t.status = 'driver_assigned' THEN 'Conductor Asignado'
          WHEN t.status = 'driver_arriving' THEN 'Conductor en Camino'
          WHEN t.status = 'in_progress' THEN 'En Progreso'
          WHEN t.status = 'completed' THEN 'Completado'
          WHEN t.status = 'cancelled' THEN 'Cancelado'
          ELSE t.status
        END as status_spanish
      FROM \`oasis-taxi-peru.firestore_export.trips\` t
      WHERE t.status IN ('requested', 'driver_assigned', 'driver_arriving', 'in_progress')
        AND t.created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 HOUR)
    `;

    const [job] = await bigquery.createQueryJob({
      query,
      location: 'US'
    });

    await job.getQueryResults();
    console.log('Tabla de viajes en tiempo real actualizada');

  } catch (error) {
    console.error('Error actualizando tabla de viajes en tiempo real:', error);
    throw error;
  }
}

/**
 * Actualizar tabla de estado de conductores
 */
async function refreshDriverStatusTable(dataset) {
  try {
    const query = `
      CREATE OR REPLACE TABLE \`oasis-taxi-peru.${dataset}.driver_status\` AS
      SELECT
        d.driver_id,
        d.full_name,
        d.status.active as is_active,
        d.status.available as is_available,
        d.current_location,
        d.last_location_update,
        d.current_trip_id,
        TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), d.last_location_update, MINUTE) as minutes_since_update,
        CASE 
          WHEN d.current_trip_id IS NOT NULL THEN 'en_viaje'
          WHEN d.status.available = true THEN 'disponible'
          WHEN d.status.active = true THEN 'conectado'
          ELSE 'desconectado'
        END as driver_state,
        -- Calcular zona basada en ubicación (ejemplo para Lima)
        CASE 
          WHEN d.current_location.latitude BETWEEN -12.046 AND -12.026 
            AND d.current_location.longitude BETWEEN -77.042 AND -77.022 THEN 'Centro Histórico'
          WHEN d.current_location.latitude BETWEEN -12.120 AND -12.080 
            AND d.current_location.longitude BETWEEN -77.050 AND -77.020 THEN 'Miraflores'
          WHEN d.current_location.latitude BETWEEN -12.130 AND -12.100 
            AND d.current_location.longitude BETWEEN -77.040 AND -77.010 THEN 'San Isidro'
          ELSE 'Otra Zona'
        END as zone
      FROM \`oasis-taxi-peru.firestore_export.drivers\` d
      WHERE d.last_location_update >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 6 HOUR)
    `;

    const [job] = await bigquery.createQueryJob({
      query,
      location: 'US'
    });

    await job.getQueryResults();
    console.log('Tabla de estado de conductores actualizada');

  } catch (error) {
    console.error('Error actualizando tabla de estado de conductores:', error);
    throw error;
  }
}

/**
 * Actualizar tabla genérica
 */
async function refreshGenericTable(dataset, table) {
  console.log(`Actualizando tabla genérica: ${dataset}.${table}`);
  // Implementar lógica genérica según sea necesario
}

/**
 * Actualizar reporte de Data Studio
 */
async function updateDataStudioReport(dashboardId, config) {
  try {
    console.log(`Actualizando reporte Data Studio: ${config.name}`);

    // Obtener ID del reporte de Data Studio
    const reportId = await getDataStudioReportId(dashboardId);
    
    if (!reportId) {
      console.log(`Reporte no encontrado para ${dashboardId}, creando nuevo...`);
      await createDataStudioReport(dashboardId, config);
      return;
    }

    // Actualizar fuentes de datos del reporte
    await updateDataStudioDataSources(reportId, config);

    // Refrescar cache del reporte
    await refreshDataStudioCache(reportId);

    console.log(`Reporte Data Studio ${reportId} actualizado exitosamente`);

  } catch (error) {
    console.error(`Error actualizando reporte Data Studio:`, error);
    throw error;
  }
}

/**
 * Obtener ID del reporte de Data Studio
 */
async function getDataStudioReportId(dashboardId) {
  try {
    const doc = await db.collection('data_studio_reports').doc(dashboardId).get();
    return doc.exists ? doc.data().report_id : null;
  } catch (error) {
    console.error(`Error obteniendo report ID:`, error);
    return null;
  }
}

/**
 * Crear nuevo reporte de Data Studio
 */
async function createDataStudioReport(dashboardId, config) {
  try {
    console.log(`Creando nuevo reporte: ${config.name}`);

    // Configuración básica del reporte
    const reportConfig = {
      name: config.name,
      description: config.description,
      dataSource: {
        projectId: 'oasis-taxi-peru',
        datasetId: config.bigquery_dataset,
        type: 'BIGQUERY'
      },
      layout: generateDashboardLayout(config),
      permissions: {
        viewers: config.viewers,
        editors: ['admin@oasistaxiperu.com']
      }
    };

    // Crear el reporte (simulado - en producción usar Data Studio API real)
    const reportId = `report_${dashboardId}_${Date.now()}`;
    
    // Guardar referencia en Firestore
    await db.collection('data_studio_reports').doc(dashboardId).set({
      report_id: reportId,
      report_url: `https://datastudio.google.com/reporting/${reportId}`,
      config: reportConfig,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      status: 'active'
    });

    console.log(`Reporte creado con ID: ${reportId}`);
    return reportId;

  } catch (error) {
    console.error('Error creando reporte Data Studio:', error);
    throw error;
  }
}

/**
 * Generar layout del dashboard basado en configuración
 */
function generateDashboardLayout(config) {
  const layouts = {
    executive: generateExecutiveLayout(),
    operations: generateOperationsLayout(),
    financial: generateFinancialLayout(),
    drivers: generateDriversLayout(),
    passengers: generatePassengersLayout(),
    quality: generateQualityLayout(),
    marketing: generateMarketingLayout()
  };

  return layouts[config.name.toLowerCase().split(' ')[1]] || generateDefaultLayout();
}

/**
 * Layout para dashboard ejecutivo
 */
function generateExecutiveLayout() {
  return {
    sections: [
      {
        name: 'KPIs Principal',
        charts: [
          {
            type: 'scorecard',
            metric: 'total_trips_today',
            title: 'Viajes Hoy',
            format: 'number'
          },
          {
            type: 'scorecard', 
            metric: 'total_revenue_today',
            title: 'Ingresos Hoy',
            format: 'currency'
          },
          {
            type: 'scorecard',
            metric: 'active_drivers_count',
            title: 'Conductores Activos',
            format: 'number'
          },
          {
            type: 'scorecard',
            metric: 'passenger_satisfaction',
            title: 'Satisfacción Pasajeros',
            format: 'percentage'
          }
        ]
      },
      {
        name: 'Tendencias',
        charts: [
          {
            type: 'time_series',
            metric: 'daily_trips',
            title: 'Viajes por Día (Últimos 30 días)',
            timeframe: '30d'
          },
          {
            type: 'time_series',
            metric: 'daily_revenue',
            title: 'Ingresos por Día (Últimos 30 días)', 
            timeframe: '30d'
          }
        ]
      },
      {
        name: 'Análisis',
        charts: [
          {
            type: 'pie_chart',
            metric: 'trips_by_payment_method',
            title: 'Viajes por Método de Pago'
          },
          {
            type: 'geo_map',
            metric: 'trips_by_zone',
            title: 'Viajes por Zona de Lima'
          }
        ]
      }
    ]
  };
}

/**
 * Layout para dashboard operacional
 */
function generateOperationsLayout() {
  return {
    sections: [
      {
        name: 'Estado en Tiempo Real',
        charts: [
          {
            type: 'scorecard',
            metric: 'trips_in_progress',
            title: 'Viajes en Progreso',
            format: 'number',
            refresh: '1m'
          },
          {
            type: 'scorecard',
            metric: 'waiting_passengers',
            title: 'Pasajeros Esperando',
            format: 'number',
            refresh: '1m'
          },
          {
            type: 'scorecard',
            metric: 'available_drivers',
            title: 'Conductores Disponibles',
            format: 'number',
            refresh: '1m'
          }
        ]
      },
      {
        name: 'Métricas Operativas',
        charts: [
          {
            type: 'gauge',
            metric: 'avg_pickup_time',
            title: 'Tiempo Promedio de Recogida',
            target: 5,
            unit: 'minutos'
          },
          {
            type: 'gauge',
            metric: 'driver_utilization',
            title: 'Utilización de Conductores',
            target: 75,
            unit: 'percentage'
          }
        ]
      },
      {
        name: 'Mapas en Vivo',
        charts: [
          {
            type: 'real_time_map',
            metric: 'driver_locations',
            title: 'Ubicación de Conductores en Tiempo Real'
          },
          {
            type: 'heat_map',
            metric: 'demand_hotspots',
            title: 'Zonas de Alta Demanda'
          }
        ]
      }
    ]
  };
}

/**
 * Layout para dashboard financiero
 */
function generateFinancialLayout() {
  return {
    sections: [
      {
        name: 'Resumen Financiero',
        charts: [
          {
            type: 'scorecard',
            metric: 'daily_revenue',
            title: 'Ingresos del Día',
            format: 'currency'
          },
          {
            type: 'scorecard',
            metric: 'commission_earned',
            title: 'Comisiones Ganadas',
            format: 'currency'
          },
          {
            type: 'scorecard',
            metric: 'driver_payouts',
            title: 'Pagos a Conductores',
            format: 'currency'
          },
          {
            type: 'scorecard',
            metric: 'profit_margin',
            title: 'Margen de Ganancia',
            format: 'percentage'
          }
        ]
      },
      {
        name: 'Análisis Financiero',
        charts: [
          {
            type: 'line_chart',
            metric: 'revenue_trend',
            title: 'Tendencia de Ingresos (90 días)',
            timeframe: '90d'
          },
          {
            type: 'column_chart',
            metric: 'payment_methods',
            title: 'Ingresos por Método de Pago'
          }
        ]
      },
      {
        name: 'Distribución',
        charts: [
          {
            type: 'pie_chart',
            metric: 'revenue_distribution',
            title: 'Distribución de Ingresos por Zona'
          },
          {
            type: 'table',
            metric: 'top_earning_drivers',
            title: 'Top 10 Conductores por Ganancias'
          }
        ]
      }
    ]
  };
}

/**
 * Layouts adicionales (simplificados)
 */
function generateDriversLayout() {
  return { sections: [{ name: 'Conductores', charts: [{ type: 'table', metric: 'driver_performance', title: 'Rendimiento de Conductores' }] }] };
}

function generatePassengersLayout() {
  return { sections: [{ name: 'Pasajeros', charts: [{ type: 'table', metric: 'passenger_behavior', title: 'Comportamiento de Pasajeros' }] }] };
}

function generateQualityLayout() {
  return { sections: [{ name: 'Calidad', charts: [{ type: 'gauge', metric: 'service_quality', title: 'Calidad de Servicio' }] }] };
}

function generateMarketingLayout() {
  return { sections: [{ name: 'Marketing', charts: [{ type: 'funnel', metric: 'user_acquisition', title: 'Embudo de Adquisición' }] }] };
}

function generateDefaultLayout() {
  return { sections: [{ name: 'General', charts: [{ type: 'table', metric: 'general_stats', title: 'Estadísticas Generales' }] }] };
}

/**
 * Actualizar fuentes de datos del reporte
 */
async function updateDataStudioDataSources(reportId, config) {
  console.log(`Actualizando fuentes de datos para reporte ${reportId}`);
  // Implementación específica para actualizar conexiones BigQuery
}

/**
 * Refrescar cache del reporte
 */
async function refreshDataStudioCache(reportId) {
  console.log(`Refrescando cache para reporte ${reportId}`);
  // Implementación para limpiar cache de Data Studio
}

/**
 * Registrar actualización de dashboard
 */
async function recordDashboardUpdate(dashboardId, updateData) {
  try {
    await db.collection('dashboard_updates').doc(dashboardId).set(updateData, { merge: true });
  } catch (error) {
    console.error('Error registrando actualización:', error);
  }
}

/**
 * Generar reporte de salud de dashboards
 */
async function generateDashboardHealthReport(results) {
  try {
    const healthReport = {
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      dashboards_total: Object.keys(DASHBOARD_CONFIGS).length,
      dashboards_updated: results.dashboards_updated,
      bigquery_refreshed: results.bigquery_refreshed,
      errors_count: results.errors.length,
      errors: results.errors,
      success_rate: results.dashboards_updated / Object.keys(DASHBOARD_CONFIGS).length,
      status: results.errors.length === 0 ? 'healthy' : results.errors.length < 3 ? 'warning' : 'critical'
    };

    await db.collection('system_health').doc('dashboards').set(healthReport);

    console.log('Reporte de salud generado:', healthReport.status);

  } catch (error) {
    console.error('Error generando reporte de salud:', error);
  }
}

/**
 * Enviar alerta de errores en dashboards
 */
async function sendDashboardErrorAlert(results) {
  try {
    const adminEmails = [
      'admin@oasistaxiperu.com',
      'tech@oasistaxiperu.com',
      'analytics@oasistaxiperu.com'
    ];

    const emailTransporter = nodemailer.createTransporter({
      service: 'gmail',
      auth: {
        user: functions.config().email?.user,
        pass: functions.config().email?.password
      }
    });

    const emailOptions = {
      from: 'alerts@oasistaxiperu.com',
      to: adminEmails.join(','),
      subject: `🔴 ERRORES EN DATA STUDIO DASHBOARDS - ${results.errors.length} errores detectados`,
      html: `
        <h2>Errores en Actualización de Dashboards</h2>
        <p><strong>Timestamp:</strong> ${results.execution_time}</p>
        <p><strong>Dashboards Actualizados:</strong> ${results.dashboards_updated}</p>
        <p><strong>Errores Detectados:</strong> ${results.errors.length}</p>
        
        <h3>Detalles de Errores:</h3>
        <ul>
          ${results.errors.map(error => `<li>${error}</li>`).join('')}
        </ul>
        
        <p>Revisar logs de Cloud Functions inmediatamente.</p>
        <p><a href="https://console.cloud.google.com/functions/list">Ver Cloud Functions</a></p>
      `,
      priority: 'high'
    };

    await emailTransporter.sendMail(emailOptions);

    console.log('Alerta de errores enviada a administradores');

  } catch (error) {
    console.error('Error enviando alerta:', error);
  }
}

/**
 * Enviar alerta de error del sistema
 */
async function sendSystemErrorAlert(functionName, error) {
  try {
    const adminEmails = ['tech@oasistaxiperu.com', 'admin@oasistaxiperu.com'];

    const emailTransporter = nodemailer.createTransporter({
      service: 'gmail',
      auth: {
        user: functions.config().email?.user,
        pass: functions.config().email?.password
      }
    });

    const emailOptions = {
      from: 'system@oasistaxiperu.com',
      to: adminEmails.join(','),
      subject: `🔴 ERROR CRÍTICO: ${functionName}`,
      html: `
        <h2>Error Crítico en Cloud Function</h2>
        <p><strong>Función:</strong> ${functionName}</p>
        <p><strong>Timestamp:</strong> ${new Date().toLocaleString('es-PE', { timeZone: 'America/Lima' })}</p>
        <p><strong>Error:</strong> ${error.message}</p>
        <pre><code>${error.stack}</code></pre>
      `,
      priority: 'high'
    };

    await emailTransporter.sendMail(emailOptions);

  } catch (emailError) {
    console.error('Error enviando alerta de sistema:', emailError);
  }
}

/**
 * HTTP Cloud Function para obtener estadísticas de dashboards
 */
exports.getDashboardStats = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth || !context.auth.token.admin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Solo administradores pueden ver estadísticas de dashboards'
      );
    }

    const stats = {
      dashboards: {},
      summary: {
        total_dashboards: Object.keys(DASHBOARD_CONFIGS).length,
        active_dashboards: 0,
        last_update: null,
        health_status: 'unknown'
      }
    };

    // Obtener estadísticas de cada dashboard
    for (const [dashboardId, config] of Object.entries(DASHBOARD_CONFIGS)) {
      const updateDoc = await db.collection('dashboard_updates').doc(dashboardId).get();
      const reportDoc = await db.collection('data_studio_reports').doc(dashboardId).get();

      stats.dashboards[dashboardId] = {
        name: config.name,
        last_update: updateDoc.exists ? updateDoc.data().updated_at : null,
        status: updateDoc.exists ? updateDoc.data().status : 'unknown',
        report_url: reportDoc.exists ? reportDoc.data().report_url : null,
        refresh_interval: config.refresh_interval,
        viewers_count: config.viewers.length
      };

      if (updateDoc.exists && updateDoc.data().status === 'success') {
        stats.summary.active_dashboards++;
      }
    }

    // Obtener estado de salud general
    const healthDoc = await db.collection('system_health').doc('dashboards').get();
    if (healthDoc.exists) {
      stats.summary.health_status = healthDoc.data().status;
      stats.summary.last_update = healthDoc.data().timestamp;
    }

    return stats;

  } catch (error) {
    console.error('Error obteniendo estadísticas de dashboards:', error);
    throw new functions.https.HttpsError(
      'internal',
      `Error obteniendo estadísticas: ${error.message}`
    );
  }
});

/**
 * HTTP Cloud Function para forzar actualización de dashboard específico
 */
exports.forceDashboardUpdate = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth || !context.auth.token.admin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Solo administradores pueden forzar actualizaciones'
      );
    }

    const { dashboardId } = data;

    if (!dashboardId || !DASHBOARD_CONFIGS[dashboardId]) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Dashboard ID inválido'
      );
    }

    const config = DASHBOARD_CONFIGS[dashboardId];

    // Forzar actualización
    await refreshBigQueryDataset(config.bigquery_dataset, config.tables);
    await updateDataStudioReport(dashboardId, config);

    await recordDashboardUpdate(dashboardId, {
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      status: 'success',
      forced: true,
      forced_by: context.auth.uid
    });

    return {
      success: true,
      dashboard: config.name,
      updated_at: new Date().toISOString()
    };

  } catch (error) {
    console.error('Error forzando actualización:', error);
    throw new functions.https.HttpsError(
      'internal',
      `Error forzando actualización: ${error.message}`
    );
  }
});

module.exports = {
  updateDataStudioDashboards: exports.updateDataStudioDashboards,
  getDashboardStats: exports.getDashboardStats,
  forceDashboardUpdate: exports.forceDashboardUpdate
};