// Script para configurar datos iniciales en Firebase
// Ejecutar con: node setup_firebase_data.js

require('dotenv').config();
const admin = require('firebase-admin');

// Validar variables de entorno requeridas
const requiredEnvVars = [
  'FIREBASE_PROJECT_ID',
  'FIREBASE_PRIVATE_KEY_ID',
  'FIREBASE_PRIVATE_KEY',
  'FIREBASE_CLIENT_EMAIL',
  'FIREBASE_CLIENT_ID'
];

for (const envVar of requiredEnvVars) {
  if (!process.env[envVar]) {
    console.error(`Error: Variable de entorno faltante: ${envVar}`);
    process.exit(1);
  }
}

// Construir service account desde variables de entorno
const serviceAccount = {
  type: "service_account",
  project_id: process.env.FIREBASE_PROJECT_ID,
  private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,
  private_key: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
  client_email: process.env.FIREBASE_CLIENT_EMAIL,
  client_id: process.env.FIREBASE_CLIENT_ID,
  auth_uri: process.env.FIREBASE_AUTH_URI || "https://accounts.google.com/o/oauth2/auth",
  token_uri: process.env.FIREBASE_TOKEN_URI || "https://oauth2.googleapis.com/token",
  auth_provider_x509_cert_url: `https://www.googleapis.com/oauth2/v1/certs`,
  client_x509_cert_url: `https://www.googleapis.com/robot/v1/metadata/x509/${process.env.FIREBASE_CLIENT_EMAIL}`
};

// Inicializar Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: `https://${process.env.FIREBASE_PROJECT_ID}-default-rtdb.firebaseio.com`
});

const db = admin.firestore();

async function setupInitialData() {
  try {
    console.log('🔧 Configurando datos iniciales en Firebase...');
    
    // 1. Configuración general
    console.log('📝 Creando configuración general...');
    await db.collection('config').doc('general').set({
      commission_rate: 0.20, // 20% de comisión
      min_driver_rating: 3.5,
      max_negotiation_time: 300, // 5 minutos
      currency: 'PEN',
      currency_symbol: 'S/',
      support_phone: '+51999999999',
      support_email: 'soporte@oasistaxiperu.com',
      terms_url: 'https://oasistaxiperu.com/terminos',
      privacy_url: 'https://oasistaxiperu.com/privacidad',
      updated_at: admin.firestore.FieldValue.serverTimestamp()
    });

    // 2. Tarifas por tipo de vehículo
    console.log('💰 Configurando tarifas...');
    
    await db.collection('rates').doc('sedan').set({
      vehicle_type: 'sedan',
      display_name: 'Sedán',
      base_fare: 5.0,  // S/ 5.00 tarifa base
      per_km: 2.0,     // S/ 2.00 por km
      per_minute: 0.5, // S/ 0.50 por minuto
      minimum_fare: 8.0, // S/ 8.00 mínimo
      capacity: 4,
      active: true,
      surge_multiplier: 1.0,
      created_at: admin.firestore.FieldValue.serverTimestamp()
    });

    await db.collection('rates').doc('minivan').set({
      vehicle_type: 'minivan',
      display_name: 'Minivan',
      base_fare: 7.0,
      per_km: 2.5,
      per_minute: 0.6,
      minimum_fare: 10.0,
      capacity: 6,
      active: true,
      surge_multiplier: 1.0,
      created_at: admin.firestore.FieldValue.serverTimestamp()
    });

    await db.collection('rates').doc('pickup').set({
      vehicle_type: 'pickup',
      display_name: 'Pickup',
      base_fare: 8.0,
      per_km: 3.0,
      per_minute: 0.7,
      minimum_fare: 12.0,
      capacity: 2,
      cargo_capacity: true,
      active: true,
      surge_multiplier: 1.0,
      created_at: admin.firestore.FieldValue.serverTimestamp()
    });

    await db.collection('rates').doc('cargo').set({
      vehicle_type: 'cargo',
      display_name: 'Carga',
      base_fare: 10.0,
      per_km: 3.5,
      per_minute: 0.8,
      minimum_fare: 15.0,
      capacity: 2,
      cargo_only: true,
      active: true,
      surge_multiplier: 1.0,
      created_at: admin.firestore.FieldValue.serverTimestamp()
    });

    // 3. Tipos de vehículos disponibles
    console.log('🚗 Configurando tipos de vehículos...');
    
    await db.collection('vehicle_types').doc('sedan').set({
      id: 'sedan',
      name: 'Sedán',
      description: 'Vehículo estándar para 4 pasajeros',
      icon: 'car',
      max_passengers: 4,
      base_commission: 0.20,
      requirements: [
        'Año 2010 o más reciente',
        'Aire acondicionado funcional',
        'Cinturones de seguridad en buen estado'
      ],
      active: true,
      order: 1
    });

    await db.collection('vehicle_types').doc('minivan').set({
      id: 'minivan',
      name: 'Minivan',
      description: 'Vehículo amplio para 6 pasajeros',
      icon: 'minivan',
      max_passengers: 6,
      base_commission: 0.18,
      requirements: [
        'Año 2012 o más reciente',
        'Aire acondicionado funcional',
        'Espacio para equipaje'
      ],
      active: true,
      order: 2
    });

    await db.collection('vehicle_types').doc('pickup').set({
      id: 'pickup',
      name: 'Pickup',
      description: 'Camioneta para carga y pasajeros',
      icon: 'pickup',
      max_passengers: 2,
      has_cargo: true,
      base_commission: 0.18,
      requirements: [
        'Año 2010 o más reciente',
        'Platón en buen estado',
        'Capacidad de carga mínima 500kg'
      ],
      active: true,
      order: 3
    });

    await db.collection('vehicle_types').doc('cargo').set({
      id: 'cargo',
      name: 'Carga',
      description: 'Vehículo exclusivo para transporte de carga',
      icon: 'truck',
      max_passengers: 2,
      cargo_only: true,
      base_commission: 0.15,
      requirements: [
        'Año 2008 o más reciente',
        'Capacidad de carga mínima 1000kg',
        'Documentación de transporte de carga'
      ],
      active: true,
      order: 4
    });

    // 4. Zonas de servicio
    console.log('📍 Configurando zonas de servicio...');
    
    await db.collection('service_zones').doc('lima').set({
      name: 'Lima Metropolitana',
      center: {
        latitude: -12.0464,
        longitude: -77.0428
      },
      radius_km: 50,
      active: true,
      surge_zones: [],
      created_at: admin.firestore.FieldValue.serverTimestamp()
    });

    // 5. Promociones iniciales
    console.log('🎁 Creando promociones...');
    
    await db.collection('promotions').doc('welcome').set({
      code: 'BIENVENIDO',
      description: '20% de descuento en tu primer viaje',
      discount_type: 'percentage',
      discount_value: 20,
      max_discount: 15.0, // Máximo S/ 15
      min_trip_value: 10.0,
      valid_from: admin.firestore.Timestamp.now(),
      valid_until: admin.firestore.Timestamp.fromDate(new Date('2025-12-31')),
      usage_limit: 1,
      new_users_only: true,
      active: true,
      created_at: admin.firestore.FieldValue.serverTimestamp()
    });

    // 6. Métodos de pago aceptados
    console.log('💳 Configurando métodos de pago...');
    
    await db.collection('payment_methods').doc('config').set({
      accepted_methods: ['cash', 'card', 'wallet'],
      wallet_bonus_percentage: 5, // 5% extra al recargar billetera
      min_wallet_recharge: 20.0,
      max_wallet_recharge: 500.0,
      card_processing_fee: 0.03, // 3% de comisión por tarjeta
      updated_at: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log('✅ Datos iniciales configurados exitosamente!');
    console.log('');
    console.log('📊 Resumen de configuración:');
    console.log('   - Configuración general ✓');
    console.log('   - 4 tipos de tarifas ✓');
    console.log('   - 4 tipos de vehículos ✓');
    console.log('   - 1 zona de servicio (Lima) ✓');
    console.log('   - 1 promoción de bienvenida ✓');
    console.log('   - Métodos de pago configurados ✓');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error configurando datos:', error);
    process.exit(1);
  }
}

// Ejecutar setup
setupInitialData();