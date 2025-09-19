-- 📊 BIGQUERY SCHEMAS PARA OASISTAXI
-- Configuración completa de Data Warehouse
-- Versión: Producción 1.0
-- Fecha: Enero 2025

-- ============================================
-- DATASET PRINCIPAL
-- ============================================
CREATE SCHEMA IF NOT EXISTS `oasis_taxi_analytics`
OPTIONS (
  description = "Dataset principal para analytics de OasisTaxi",
  location = "US"
);

-- ============================================
-- TABLA: USUARIOS
-- ============================================
CREATE OR REPLACE TABLE `oasis_taxi_analytics.users` (
  user_id STRING NOT NULL,
  email STRING,
  phone STRING,
  full_name STRING,
  user_type STRING, -- passenger, driver, admin
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  is_active BOOLEAN DEFAULT TRUE,
  is_verified BOOLEAN DEFAULT FALSE,
  last_login TIMESTAMP,
  profile_image_url STRING,
  birth_date DATE,
  gender STRING,
  registration_source STRING, -- app, web, referral
  referred_by STRING,
  city STRING,
  country STRING DEFAULT 'PE',
  preferred_language STRING DEFAULT 'es',
  notification_preferences STRUCT<
    push_enabled BOOLEAN,
    email_enabled BOOLEAN,
    sms_enabled BOOLEAN
  >,
  verification_documents ARRAY<STRUCT<
    document_type STRING,
    document_url STRING,
    verified_at TIMESTAMP,
    verified_by STRING
  >>,
  -- Campos calculados para analytics
  total_trips INT64 DEFAULT 0,
  total_spent NUMERIC(10,2) DEFAULT 0,
  average_rating FLOAT64,
  lifetime_value NUMERIC(10,2),
  -- Metadatos
  created_by STRING,
  updated_by STRING,
  version INT64 DEFAULT 1,
  -- Particionamiento
  partition_date DATE GENERATED ALWAYS AS (DATE(created_at)) STORED
)
PARTITION BY partition_date
CLUSTER BY user_type, city, is_active
OPTIONS (
  description = "Tabla principal de usuarios del sistema OasisTaxi",
  partition_expiration_days = 1095, -- 3 años
  require_partition_filter = FALSE
);

-- ============================================
-- TABLA: CONDUCTORES
-- ============================================
CREATE OR REPLACE TABLE `oasis_taxi_analytics.drivers` (
  driver_id STRING NOT NULL,
  user_id STRING NOT NULL,
  license_number STRING,
  license_expiry_date DATE,
  vehicle_info STRUCT<
    plate_number STRING,
    brand STRING,
    model STRING,
    year INT64,
    color STRING,
    vehicle_type STRING, -- sedan, suv, minivan
    capacity INT64,
    insurance_policy STRING,
    soat_expiry DATE
  >,
  status STRING, -- pending, verified, suspended, inactive
  verified_at TIMESTAMP,
  verified_by STRING,
  is_online BOOLEAN DEFAULT FALSE,
  current_location STRUCT<
    latitude FLOAT64,
    longitude FLOAT64,
    address STRING,
    updated_at TIMESTAMP
  >,
  -- Métricas de rendimiento
  total_trips INT64 DEFAULT 0,
  total_earnings NUMERIC(10,2) DEFAULT 0,
  average_rating FLOAT64,
  completion_rate FLOAT64,
  cancellation_rate FLOAT64,
  response_time_avg FLOAT64, -- promedio en segundos
  -- Documentos
  documents ARRAY<STRUCT<
    document_type STRING,
    document_url STRING,
    upload_date TIMESTAMP,
    verification_status STRING,
    verified_by STRING,
    verified_at TIMESTAMP
  >>,
  -- Banking info
  bank_account STRUCT<
    bank_name STRING,
    account_number STRING,
    account_type STRING,
    account_holder STRING
  >,
  -- Timestamps
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  last_active TIMESTAMP,
  -- Particionamiento
  partition_date DATE GENERATED ALWAYS AS (DATE(created_at)) STORED
)
PARTITION BY partition_date
CLUSTER BY status, vehicle_info.vehicle_type, is_online
OPTIONS (
  description = "Información detallada de conductores verificados",
  partition_expiration_days = 1095
);

-- ============================================
-- TABLA: VIAJES
-- ============================================
CREATE OR REPLACE TABLE `oasis_taxi_analytics.trips` (
  trip_id STRING NOT NULL,
  passenger_id STRING NOT NULL,
  driver_id STRING,
  vehicle_type STRING,
  
  -- Ubicaciones
  origin STRUCT<
    latitude FLOAT64,
    longitude FLOAT64,
    address STRING,
    landmark STRING,
    city STRING,
    district STRING
  >,
  destination STRUCT<
    latitude FLOAT64,
    longitude FLOAT64,
    address STRING,
    landmark STRING,
    city STRING,
    district STRING
  >,
  
  -- Estados del viaje
  status STRING, -- pending, accepted, in_progress, completed, cancelled
  status_history ARRAY<STRUCT<
    status STRING,
    timestamp TIMESTAMP,
    updated_by STRING,
    reason STRING
  >>,
  
  -- Tiempos
  created_at TIMESTAMP,
  accepted_at TIMESTAMP,
  started_at TIMESTAMP,
  completed_at TIMESTAMP,
  estimated_duration INT64, -- en minutos
  actual_duration INT64, -- en minutos
  
  -- Precios y pagos
  estimated_price NUMERIC(8,2),
  final_price NUMERIC(8,2),
  base_fare NUMERIC(8,2),
  distance_fare NUMERIC(8,2),
  time_fare NUMERIC(8,2),
  surge_multiplier FLOAT64 DEFAULT 1.0,
  commission_rate FLOAT64,
  commission_amount NUMERIC(8,2),
  payment_method STRING, -- cash, card, wallet
  payment_status STRING, -- pending, completed, failed
  
  -- Negociación de precios
  negotiation STRUCT<
    enabled BOOLEAN,
    rounds INT64,
    original_price NUMERIC(8,2),
    final_negotiated_price NUMERIC(8,2),
    negotiation_history ARRAY<STRUCT<
      round_number INT64,
      offered_by STRING, -- passenger, driver
      amount NUMERIC(8,2),
      timestamp TIMESTAMP,
      status STRING -- pending, accepted, rejected
    >>
  >,
  
  -- Métricas del viaje
  distance_km FLOAT64,
  route_polyline STRING,
  traffic_factor FLOAT64,
  weather_conditions STRING,
  
  -- Calificaciones
  passenger_rating STRUCT<
    rating INT64, -- 1-5
    comment STRING,
    rated_at TIMESTAMP
  >,
  driver_rating STRUCT<
    rating INT64, -- 1-5
    comment STRING,
    rated_at TIMESTAMP
  >,
  
  -- Información adicional
  special_requests STRING,
  cancellation_reason STRING,
  emergency_activated BOOLEAN DEFAULT FALSE,
  
  -- Timestamps
  updated_at TIMESTAMP,
  
  -- Particionamiento por fecha de creación
  partition_date DATE GENERATED ALWAYS AS (DATE(created_at)) STORED
)
PARTITION BY partition_date
CLUSTER BY status, passenger_id, driver_id
OPTIONS (
  description = "Registro completo de todos los viajes en OasisTaxi",
  partition_expiration_days = 2555 -- 7 años para compliance
);

-- ============================================
-- TABLA: PAGOS
-- ============================================
CREATE OR REPLACE TABLE `oasis_taxi_analytics.payments` (
  payment_id STRING NOT NULL,
  trip_id STRING,
  user_id STRING NOT NULL,
  payment_type STRING, -- trip_payment, wallet_topup, driver_payout
  
  -- Montos
  amount NUMERIC(10,2),
  currency STRING DEFAULT 'PEN',
  commission_amount NUMERIC(10,2),
  net_amount NUMERIC(10,2),
  
  -- Método de pago
  payment_method STRING, -- cash, mercadopago, wallet
  payment_provider STRING, -- mercadopago, manual, internal
  provider_transaction_id STRING,
  
  -- Estados
  status STRING, -- pending, processing, completed, failed, refunded
  status_history ARRAY<STRUCT<
    status STRING,
    timestamp TIMESTAMP,
    reason STRING,
    updated_by STRING
  >>,
  
  -- Detalles del pago
  payment_details STRUCT<
    card_last_four STRING,
    card_brand STRING,
    bank_name STRING,
    authorization_code STRING,
    receipt_url STRING
  >,
  
  -- Metadata de MercadoPago
  mercadopago_data STRUCT<
    payment_id STRING,
    payment_method_id STRING,
    payment_type_id STRING,
    issuer_id STRING,
    installments INT64,
    transaction_amount NUMERIC(10,2),
    processing_mode STRING,
    external_reference STRING
  >,
  
  -- Timestamps
  created_at TIMESTAMP,
  processed_at TIMESTAMP,
  updated_at TIMESTAMP,
  
  -- Particionamiento
  partition_date DATE GENERATED ALWAYS AS (DATE(created_at)) STORED
)
PARTITION BY partition_date
CLUSTER BY status, payment_method, user_id
OPTIONS (
  description = "Registro de todas las transacciones y pagos",
  partition_expiration_days = 2555
);

-- ============================================
-- TABLA: EVENTOS DE APLICACIÓN
-- ============================================
CREATE OR REPLACE TABLE `oasis_taxi_analytics.app_events` (
  event_id STRING NOT NULL,
  user_id STRING,
  session_id STRING,
  event_name STRING, -- app_open, trip_request, payment_completed, etc.
  event_category STRING, -- user_engagement, business_event, technical_event
  
  -- Contexto del evento
  platform STRING, -- android, ios, web
  app_version STRING,
  device_info STRUCT<
    device_model STRING,
    os_version STRING,
    screen_resolution STRING,
    network_type STRING -- wifi, cellular, unknown
  >,
  
  -- Ubicación del evento
  location STRUCT<
    latitude FLOAT64,
    longitude FLOAT64,
    city STRING,
    country STRING DEFAULT 'PE'
  >,
  
  -- Parámetros del evento
  event_parameters JSON,
  
  -- Métricas de rendimiento
  performance_metrics STRUCT<
    page_load_time INT64,
    api_response_time INT64,
    memory_usage INT64,
    cpu_usage FLOAT64
  >,
  
  -- Timestamps
  timestamp TIMESTAMP,
  
  -- Particionamiento
  partition_date DATE GENERATED ALWAYS AS (DATE(timestamp)) STORED
)
PARTITION BY partition_date
CLUSTER BY event_name, platform, user_id
OPTIONS (
  description = "Eventos de la aplicación para analytics y debugging",
  partition_expiration_days = 365 -- 1 año
);

-- ============================================
-- TABLA: MÉTRICAS DIARIAS
-- ============================================
CREATE OR REPLACE TABLE `oasis_taxi_analytics.daily_metrics` (
  date DATE NOT NULL,
  city STRING,
  metric_type STRING, -- business, technical, financial
  
  -- Métricas de usuarios
  new_users INT64 DEFAULT 0,
  active_users INT64 DEFAULT 0,
  returning_users INT64 DEFAULT 0,
  user_retention_rate FLOAT64,
  
  -- Métricas de viajes
  total_trips INT64 DEFAULT 0,
  completed_trips INT64 DEFAULT 0,
  cancelled_trips INT64 DEFAULT 0,
  average_trip_duration FLOAT64,
  average_trip_distance FLOAT64,
  trip_completion_rate FLOAT64,
  
  -- Métricas financieras
  gross_revenue NUMERIC(12,2) DEFAULT 0,
  net_revenue NUMERIC(12,2) DEFAULT 0,
  total_commission NUMERIC(12,2) DEFAULT 0,
  average_trip_value NUMERIC(8,2),
  
  -- Métricas de conductores
  active_drivers INT64 DEFAULT 0,
  new_driver_registrations INT64 DEFAULT 0,
  verified_drivers INT64 DEFAULT 0,
  driver_utilization_rate FLOAT64,
  average_driver_rating FLOAT64,
  
  -- Métricas de rendimiento
  app_crashes INT64 DEFAULT 0,
  api_error_rate FLOAT64,
  average_response_time FLOAT64,
  system_uptime FLOAT64,
  
  -- Métricas de satisfacción
  average_passenger_rating FLOAT64,
  nps_score FLOAT64,
  complaints_count INT64 DEFAULT 0,
  
  -- Timestamps
  created_at TIMESTAMP,
  updated_at TIMESTAMP
)
PARTITION BY date
CLUSTER BY city, metric_type
OPTIONS (
  description = "Métricas diarias agregadas para reporting ejecutivo",
  partition_expiration_days = 1095
);

-- ============================================
-- TABLA: ANÁLISIS GEOESPACIAL
-- ============================================
CREATE OR REPLACE TABLE `oasis_taxi_analytics.location_analytics` (
  id STRING NOT NULL,
  date DATE,
  geohash STRING, -- Para agrupación geoespacial
  
  -- Coordenadas
  latitude FLOAT64,
  longitude FLOAT64,
  city STRING,
  district STRING,
  
  -- Métricas de demanda
  trip_requests INT64 DEFAULT 0,
  completed_trips INT64 DEFAULT 0,
  average_wait_time FLOAT64,
  demand_intensity FLOAT64, -- trips per km²
  
  -- Métricas de oferta
  available_drivers INT64 DEFAULT 0,
  supply_intensity FLOAT64, -- drivers per km²
  supply_demand_ratio FLOAT64,
  
  -- Métricas de precios
  average_trip_price NUMERIC(8,2),
  surge_factor FLOAT64,
  price_variance FLOAT64,
  
  -- Condiciones externas
  weather_condition STRING,
  traffic_level STRING, -- low, medium, high
  special_events ARRAY<STRING>,
  
  -- Timestamps
  timestamp TIMESTAMP,
  
  -- Particionamiento
  partition_date DATE GENERATED ALWAYS AS (date) STORED
)
PARTITION BY partition_date
CLUSTER BY city, geohash
OPTIONS (
  description = "Análisis geoespacial de demanda y oferta",
  partition_expiration_days = 730
);

-- ============================================
-- TABLA: AUDITORÍA
-- ============================================
CREATE OR REPLACE TABLE `oasis_taxi_analytics.audit_log` (
  audit_id STRING NOT NULL,
  user_id STRING,
  entity_type STRING, -- user, trip, payment, driver
  entity_id STRING,
  action STRING, -- create, update, delete, view
  
  -- Detalles del cambio
  changes JSON, -- Before/after values
  reason STRING,
  ip_address STRING,
  user_agent STRING,
  
  -- Contexto
  platform STRING,
  app_version STRING,
  admin_action BOOLEAN DEFAULT FALSE,
  
  -- Timestamps
  timestamp TIMESTAMP,
  
  -- Particionamiento
  partition_date DATE GENERATED ALWAYS AS (DATE(timestamp)) STORED
)
PARTITION BY partition_date
CLUSTER BY entity_type, action, user_id
OPTIONS (
  description = "Log de auditoría para compliance y seguridad",
  partition_expiration_days = 2555 -- 7 años
);

-- ============================================
-- VISTAS ANALÍTICAS
-- ============================================

-- Vista de KPIs principales
CREATE OR REPLACE VIEW `oasis_taxi_analytics.v_main_kpis` AS
SELECT 
  DATE(DATETIME(TIMESTAMP_TRUNC(CURRENT_TIMESTAMP(), DAY), "America/Lima")) as date,
  COUNT(DISTINCT CASE WHEN t.created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR) THEN t.passenger_id END) as active_users_24h,
  COUNT(CASE WHEN t.created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR) AND t.status = 'completed' THEN 1 END) as completed_trips_24h,
  ROUND(AVG(CASE WHEN t.status = 'completed' AND t.final_price IS NOT NULL THEN t.final_price END), 2) as avg_trip_value,
  COUNT(DISTINCT CASE WHEN d.is_online = TRUE THEN d.driver_id END) as online_drivers,
  ROUND(AVG(CASE WHEN t.status = 'completed' AND t.passenger_rating.rating IS NOT NULL THEN t.passenger_rating.rating END), 2) as avg_passenger_rating
FROM `oasis_taxi_analytics.trips` t
LEFT JOIN `oasis_taxi_analytics.drivers` d ON d.status = 'verified'
WHERE t.created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
GROUP BY 1;

-- Vista de análisis de retención
CREATE OR REPLACE VIEW `oasis_taxi_analytics.v_user_retention` AS
WITH user_trips AS (
  SELECT 
    passenger_id,
    DATE(created_at) as trip_date,
    ROW_NUMBER() OVER (PARTITION BY passenger_id ORDER BY created_at) as trip_number
  FROM `oasis_taxi_analytics.trips`
  WHERE status = 'completed'
),
first_trips AS (
  SELECT passenger_id, trip_date as first_trip_date
  FROM user_trips 
  WHERE trip_number = 1
),
retention_cohorts AS (
  SELECT 
    ft.first_trip_date as cohort_date,
    DATE_DIFF(ut.trip_date, ft.first_trip_date, DAY) as days_since_first_trip,
    COUNT(DISTINCT ut.passenger_id) as users
  FROM first_trips ft
  JOIN user_trips ut ON ft.passenger_id = ut.passenger_id
  GROUP BY 1, 2
)
SELECT 
  cohort_date,
  days_since_first_trip,
  users,
  users / FIRST_VALUE(users) OVER (PARTITION BY cohort_date ORDER BY days_since_first_trip) as retention_rate
FROM retention_cohorts
ORDER BY cohort_date DESC, days_since_first_trip;

-- ============================================
-- FUNCIONES AUXILIARES
-- ============================================

-- Función para calcular distancia entre dos puntos
CREATE OR REPLACE FUNCTION `oasis_taxi_analytics.calculate_distance`(
  lat1 FLOAT64, 
  lon1 FLOAT64, 
  lat2 FLOAT64, 
  lon2 FLOAT64
) RETURNS FLOAT64
LANGUAGE js AS """
  var R = 6371; // Radio de la Tierra en km
  var dLat = (lat2 - lat1) * Math.PI / 180;
  var dLon = (lon2 - lon1) * Math.PI / 180;
  var a = Math.sin(dLat/2) * Math.sin(dLat/2) +
          Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
          Math.sin(dLon/2) * Math.sin(dLon/2);
  var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
""";

-- Función para obtener geohash
CREATE OR REPLACE FUNCTION `oasis_taxi_analytics.get_geohash`(
  latitude FLOAT64, 
  longitude FLOAT64, 
  precision INT64
) RETURNS STRING
LANGUAGE js AS """
  // Implementación simplificada de geohash
  var base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
  var lat_range = [-90.0, 90.0];
  var lon_range = [-180.0, 180.0];
  var geohash = '';
  var bits = 0;
  var bit = 0;
  var even = true;
  
  while (geohash.length < precision) {
    if (even) {
      var mid = (lon_range[0] + lon_range[1]) / 2;
      if (longitude >= mid) {
        bits |= (1 << (4 - bit));
        lon_range[0] = mid;
      } else {
        lon_range[1] = mid;
      }
    } else {
      var mid = (lat_range[0] + lat_range[1]) / 2;
      if (latitude >= mid) {
        bits |= (1 << (4 - bit));
        lat_range[0] = mid;
      } else {
        lat_range[1] = mid;
      }
    }
    
    even = !even;
    if (bit < 4) {
      bit++;
    } else {
      geohash += base32.charAt(bits);
      bits = 0;
      bit = 0;
    }
  }
  
  return geohash;
""";

-- ============================================
-- SCHEDULED QUERIES (Configuración)
-- ============================================

-- Query programada para métricas diarias
/*
CREATE OR REPLACE SCHEDULED QUERY `oasis_taxi_analytics.daily_metrics_update`
OPTIONS (
  description = "Actualización diaria de métricas agregadas",
  schedule = "0 2 * * *", -- Todos los días a las 2 AM
  destination_dataset = "oasis_taxi_analytics",
  destination_table = "daily_metrics",
  write_disposition = "WRITE_APPEND"
)
AS
INSERT INTO `oasis_taxi_analytics.daily_metrics` (
  date, city, metric_type, 
  new_users, active_users, total_trips, completed_trips,
  gross_revenue, active_drivers, created_at
)
SELECT 
  CURRENT_DATE("America/Lima") - 1 as date,
  'Lima' as city,
  'business' as metric_type,
  COUNT(DISTINCT u.user_id) as new_users,
  COUNT(DISTINCT t.passenger_id) as active_users,
  COUNT(t.trip_id) as total_trips,
  COUNT(CASE WHEN t.status = 'completed' THEN 1 END) as completed_trips,
  SUM(CASE WHEN t.status = 'completed' THEN t.final_price ELSE 0 END) as gross_revenue,
  COUNT(DISTINCT d.driver_id) as active_drivers,
  CURRENT_TIMESTAMP() as created_at
FROM `oasis_taxi_analytics.users` u
LEFT JOIN `oasis_taxi_analytics.trips` t ON DATE(t.created_at) = CURRENT_DATE("America/Lima") - 1
LEFT JOIN `oasis_taxi_analytics.drivers` d ON d.last_active >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
WHERE DATE(u.created_at) = CURRENT_DATE("America/Lima") - 1;
*/

-- ============================================
-- ÍNDICES Y OPTIMIZACIONES
-- ============================================

-- Comentarios sobre optimización:
-- 1. Particionamiento por fecha para mejorar performance
-- 2. Clustering por campos frecuentemente filtrados
-- 3. Expiración automática de particiones para control de costos
-- 4. Vistas materializadas para consultas frecuentes
-- 5. Scheduled queries para actualización automática

-- ============================================
-- PERMISOS Y SEGURIDAD
-- ============================================

-- Roles sugeridos:
-- - oasis_taxi_admin: Acceso completo a todos los datasets
-- - oasis_taxi_analyst: Solo lectura para análisis
-- - oasis_taxi_developer: Lectura y escritura limitada
-- - oasis_taxi_viewer: Solo lectura a vistas y métricas

-- ============================================
-- CONFIGURACIÓN DE EXPORTACIÓN
-- ============================================

-- Para conectar con Data Studio, Looker, etc:
-- 1. Configurar service account con permisos BigQuery Data Viewer
-- 2. Compartir dataset con la cuenta de servicio
-- 3. Usar las vistas analíticas como fuente de datos

-- Fin del archivo de schemas BigQuery