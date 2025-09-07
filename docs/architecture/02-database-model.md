# Modelo de Base de Datos - OASIS TAXI

## Estrategia de Datos Híbrida

### Firestore (NoSQL) - Datos en Tiempo Real

```
/users/{userId}
├── profile
│   ├── email: string
│   ├── phone: string
│   ├── name: string
│   ├── photoUrl: string
│   ├── role: "passenger" | "driver" | "admin"
│   ├── createdAt: timestamp
│   └── status: "active" | "suspended" | "deleted"
│
├── passenger_data (solo si role = "passenger")
│   ├── favoriteLocations: array
│   ├── paymentMethods: array
│   ├── rating: number
│   └── totalRides: number
│
├── driver_data (solo si role = "driver")
│   ├── vehicle: object
│   │   ├── brand: string
│   │   ├── model: string
│   │   ├── year: number
│   │   ├── plate: string
│   │   └── color: string
│   ├── documents: object
│   │   ├── license: {url, verified, expiryDate}
│   │   ├── insurance: {url, verified, expiryDate}
│   │   └── vehicle_permit: {url, verified, expiryDate}
│   ├── rating: number
│   ├── totalRides: number
│   ├── isOnline: boolean
│   ├── lastLocation: geopoint
│   └── earnings: object
│       ├── today: number
│       ├── week: number
│       └── month: number
│
└── admin_data (solo si role = "admin")
    ├── permissions: array
    ├── department: string
    └── lastAccess: timestamp

/active_rides/{rideId}
├── passengerId: string
├── driverId: string | null
├── status: "pending" | "accepted" | "arriving" | "in_progress" | "completed" | "cancelled"
├── pickup: object
│   ├── location: geopoint
│   ├── address: string
│   └── details: string
├── destination: object
│   ├── location: geopoint
│   ├── address: string
│   └── details: string
├── route: object
│   ├── distance: number (km)
│   ├── duration: number (minutos)
│   └── polyline: string
├── pricing: object
│   ├── baseFare: number
│   ├── distanceCharge: number
│   ├── timeCharge: number
│   ├── total: number
│   └── currency: string
├── payment: object
│   ├── method: "cash" | "card" | "mercadopago" | "yape"
│   └── status: "pending" | "completed" | "failed"
├── timestamps: object
│   ├── created: timestamp
│   ├── accepted: timestamp | null
│   ├── started: timestamp | null
│   └── completed: timestamp | null
└── driverLocation: geopoint (actualizado en tiempo real)

/driver_locations/{driverId}
├── location: geopoint
├── heading: number
├── speed: number
├── isOnline: boolean
├── isAvailable: boolean
└── lastUpdate: timestamp

/notifications/{userId}/messages/{messageId}
├── type: "ride_request" | "ride_update" | "payment" | "promotion" | "system"
├── title: string
├── body: string
├── data: object
├── read: boolean
├── createdAt: timestamp
└── expiresAt: timestamp
```

### Cloud SQL (PostgreSQL) - Datos Transaccionales y Reportes

```sql
-- Tabla de usuarios (replica de Firestore para joins)
CREATE TABLE users (
    id VARCHAR(128) PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('passenger', 'driver', 'admin')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Historial completo de viajes
CREATE TABLE rides (
    id VARCHAR(128) PRIMARY KEY,
    passenger_id VARCHAR(128) NOT NULL REFERENCES users(id),
    driver_id VARCHAR(128) REFERENCES users(id),
    status VARCHAR(20) NOT NULL,
    pickup_lat DECIMAL(10, 8) NOT NULL,
    pickup_lng DECIMAL(11, 8) NOT NULL,
    pickup_address TEXT NOT NULL,
    destination_lat DECIMAL(10, 8) NOT NULL,
    destination_lng DECIMAL(11, 8) NOT NULL,
    destination_address TEXT NOT NULL,
    distance_km DECIMAL(10, 2),
    duration_minutes INTEGER,
    base_fare DECIMAL(10, 2),
    distance_charge DECIMAL(10, 2),
    time_charge DECIMAL(10, 2),
    total_fare DECIMAL(10, 2) NOT NULL,
    payment_method VARCHAR(20),
    payment_status VARCHAR(20),
    passenger_rating INTEGER CHECK (passenger_rating BETWEEN 1 AND 5),
    driver_rating INTEGER CHECK (driver_rating BETWEEN 1 AND 5),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    accepted_at TIMESTAMP,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    cancelled_at TIMESTAMP,
    cancellation_reason TEXT
);

-- Índices para búsquedas frecuentes
CREATE INDEX idx_rides_passenger ON rides(passenger_id, created_at DESC);
CREATE INDEX idx_rides_driver ON rides(driver_id, created_at DESC);
CREATE INDEX idx_rides_status ON rides(status);
CREATE INDEX idx_rides_dates ON rides(created_at, completed_at);

-- Transacciones de pago
CREATE TABLE payment_transactions (
    id VARCHAR(128) PRIMARY KEY,
    ride_id VARCHAR(128) REFERENCES rides(id),
    user_id VARCHAR(128) REFERENCES users(id),
    type VARCHAR(20) NOT NULL CHECK (type IN ('ride_payment', 'driver_payout', 'refund')),
    amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'PEN',
    method VARCHAR(20) NOT NULL,
    external_reference VARCHAR(255), -- ID de Mercado Pago, etc.
    status VARCHAR(20) NOT NULL,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP
);

-- Documentos de conductores
CREATE TABLE driver_documents (
    id SERIAL PRIMARY KEY,
    driver_id VARCHAR(128) REFERENCES users(id),
    document_type VARCHAR(50) NOT NULL,
    document_url TEXT NOT NULL,
    verified BOOLEAN DEFAULT FALSE,
    verified_by VARCHAR(128) REFERENCES users(id),
    verified_at TIMESTAMP,
    expiry_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Vehículos
CREATE TABLE vehicles (
    id SERIAL PRIMARY KEY,
    driver_id VARCHAR(128) REFERENCES users(id),
    brand VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    year INTEGER NOT NULL,
    plate VARCHAR(20) UNIQUE NOT NULL,
    color VARCHAR(30),
    capacity INTEGER DEFAULT 4,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tarifas dinámicas
CREATE TABLE pricing_rules (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    base_fare DECIMAL(10, 2) NOT NULL,
    per_km_rate DECIMAL(10, 2) NOT NULL,
    per_minute_rate DECIMAL(10, 2) NOT NULL,
    minimum_fare DECIMAL(10, 2) NOT NULL,
    surge_multiplier DECIMAL(3, 2) DEFAULT 1.0,
    valid_from TIMESTAMP NOT NULL,
    valid_until TIMESTAMP,
    zone_id INTEGER,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Zonas geográficas
CREATE TABLE zones (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    polygon GEOMETRY(POLYGON, 4326) NOT NULL,
    surge_multiplier DECIMAL(3, 2) DEFAULT 1.0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Promociones
CREATE TABLE promotions (
    id SERIAL PRIMARY KEY,
    code VARCHAR(20) UNIQUE NOT NULL,
    description TEXT,
    discount_type VARCHAR(20) CHECK (discount_type IN ('percentage', 'fixed')),
    discount_value DECIMAL(10, 2) NOT NULL,
    max_discount DECIMAL(10, 2),
    min_ride_amount DECIMAL(10, 2),
    usage_limit INTEGER,
    usage_count INTEGER DEFAULT 0,
    valid_from TIMESTAMP NOT NULL,
    valid_until TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Uso de promociones
CREATE TABLE promotion_usage (
    id SERIAL PRIMARY KEY,
    promotion_id INTEGER REFERENCES promotions(id),
    user_id VARCHAR(128) REFERENCES users(id),
    ride_id VARCHAR(128) REFERENCES rides(id),
    discount_applied DECIMAL(10, 2) NOT NULL,
    used_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Logs de actividad para auditoría
CREATE TABLE activity_logs (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(128) REFERENCES users(id),
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50),
    entity_id VARCHAR(128),
    metadata JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Métricas agregadas (para dashboard)
CREATE TABLE daily_metrics (
    date DATE PRIMARY KEY,
    total_rides INTEGER DEFAULT 0,
    completed_rides INTEGER DEFAULT 0,
    cancelled_rides INTEGER DEFAULT 0,
    total_revenue DECIMAL(12, 2) DEFAULT 0,
    total_distance_km DECIMAL(12, 2) DEFAULT 0,
    average_ride_duration INTEGER DEFAULT 0,
    active_drivers INTEGER DEFAULT 0,
    active_passengers INTEGER DEFAULT 0,
    new_users INTEGER DEFAULT 0,
    average_rating DECIMAL(3, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Incidencias y soporte
CREATE TABLE support_tickets (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(128) REFERENCES users(id),
    ride_id VARCHAR(128) REFERENCES rides(id),
    category VARCHAR(50) NOT NULL,
    priority VARCHAR(20) DEFAULT 'normal',
    subject TEXT NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'open',
    assigned_to VARCHAR(128) REFERENCES users(id),
    resolved_at TIMESTAMP,
    resolution TEXT,
    satisfaction_rating INTEGER CHECK (satisfaction_rating BETWEEN 1 AND 5),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Mensajes de soporte
CREATE TABLE support_messages (
    id SERIAL PRIMARY KEY,
    ticket_id INTEGER REFERENCES support_tickets(id),
    sender_id VARCHAR(128) REFERENCES users(id),
    message TEXT NOT NULL,
    attachments JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Estrategia de Sincronización

### Firestore → PostgreSQL

```javascript
// Cloud Function para sincronizar rides completados
exports.syncCompletedRides = functions.firestore
    .document('active_rides/{rideId}')
    .onUpdate(async (change, context) => {
        const newData = change.after.data();
        const oldData = change.before.data();
        
        // Si el viaje se completó o canceló
        if (newData.status === 'completed' || newData.status === 'cancelled') {
            await syncToPostgreSQL(context.params.rideId, newData);
            
            // Eliminar de active_rides después de sincronizar
            await change.after.ref.delete();
        }
    });
```

### Caché Strategy (Redis)

```
// Estructura de caché en Redis

// Ubicaciones de conductores (TTL: 10 segundos)
driver_location:{driverId} → {lat, lng, heading, speed}

// Conductores por zona (TTL: 5 segundos)
drivers_in_zone:{zoneId} → Set de driverIds

// Tarifas activas (TTL: 5 minutos)
pricing_rules:active → JSON de reglas activas

// Sesiones de usuario (TTL: 24 horas)
session:{sessionId} → {userId, role, permissions}

// Rate limiting (TTL: 1 minuto)
rate_limit:{userId}:{endpoint} → contador

// Métricas en tiempo real (TTL: 30 segundos)
metrics:active_rides → contador
metrics:online_drivers → contador
metrics:revenue_today → suma
```

## Consideraciones de Rendimiento

### Índices Geoespaciales

```sql
-- Para búsquedas de conductores cercanos
CREATE INDEX idx_driver_locations ON driver_locations USING GIST (location);

-- Para búsquedas por zona
CREATE INDEX idx_zones_polygon ON zones USING GIST (polygon);
```

### Particionamiento

```sql
-- Particionar rides por mes para mejor rendimiento
CREATE TABLE rides_2025_01 PARTITION OF rides
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

CREATE TABLE rides_2025_02 PARTITION OF rides
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
```

### Consultas Optimizadas

```sql
-- Vista materializada para dashboard
CREATE MATERIALIZED VIEW dashboard_stats AS
SELECT 
    DATE_TRUNC('hour', created_at) as hour,
    COUNT(*) as total_rides,
    COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_rides,
    AVG(total_fare) as avg_fare,
    AVG(distance_km) as avg_distance
FROM rides
WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY DATE_TRUNC('hour', created_at);

-- Refrescar cada hora
CREATE INDEX idx_dashboard_stats_hour ON dashboard_stats(hour);
```

## Backup y Recuperación

### Estrategia de Backup

1. **Firestore**: Backup automático diario a Cloud Storage
2. **Cloud SQL**: 
   - Backup automático diario (retención 30 días)
   - Point-in-time recovery habilitado
   - Réplica de lectura para reportes

### Recuperación ante Desastres

```bash
# Script de recuperación
#!/bin/bash

# 1. Restaurar Firestore
gcloud firestore import gs://oasis-taxi-backups/firestore/2025-01-15

# 2. Restaurar Cloud SQL
gcloud sql backups restore BACKUP_ID --backup-instance=oasis-taxi-db

# 3. Verificar integridad
./scripts/verify-data-integrity.sh
```

---

Este modelo de datos híbrido aprovecha las fortalezas de Firestore para datos en tiempo real y PostgreSQL para análisis y reportes, asegurando escalabilidad y rendimiento óptimo.