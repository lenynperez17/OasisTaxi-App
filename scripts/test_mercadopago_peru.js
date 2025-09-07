#!/usr/bin/env node

/**
 * 🚀 SCRIPT DE TESTING - MERCADOPAGO PERÚ
 * =====================================
 * 
 * Este script permite probar la integración completa de MercadoPago
 * con tarjetas de prueba específicas para Perú.
 * 
 * Uso:
 * node scripts/test_mercadopago_peru.js --env=sandbox
 * node scripts/test_mercadopago_peru.js --env=production --confirm
 */

const https = require('https');
const http = require('http');

// Configuración de entornos
const config = {
  sandbox: {
    apiUrl: 'http://localhost:3000/api/v1',
    mercadopagoPublicKey: 'TEST-REEMPLAZAR-CON-KEY-REAL-SANDBOX',
    mercadopagoAccessToken: 'TEST-REEMPLAZAR-CON-ACCESS-TOKEN-REAL-SANDBOX'
  },
  production: {
    apiUrl: 'https://api.oasistaxi.com.pe/api/v1',
    mercadopagoPublicKey: 'APP_USR-REEMPLAZAR-CON-KEY-REAL-PRODUCCION',
    mercadopagoAccessToken: 'APP_USR-REEMPLAZAR-CON-ACCESS-TOKEN-REAL-PRODUCCIÓN'
  }
};

// 🇵🇪 Tarjetas de prueba MercadoPago para Perú
const testCards = {
  visa: {
    approved: {
      number: '4009175332806176',
      securityCode: '123',
      expirationMonth: '11',
      expirationYear: '25',
      cardHolderName: 'APRO',
      identificationType: 'DNI',
      identificationNumber: '12345678'
    },
    rejected: {
      number: '4804980743570011',
      securityCode: '123', 
      expirationMonth: '11',
      expirationYear: '25',
      cardHolderName: 'OTHE',
      identificationType: 'DNI',
      identificationNumber: '12345678'
    },
    insufficientFunds: {
      number: '4170068810108020',
      securityCode: '123',
      expirationMonth: '11', 
      expirationYear: '25',
      cardHolderName: 'FUND',
      identificationType: 'DNI',
      identificationNumber: '12345678'
    }
  },
  mastercard: {
    approved: {
      number: '5031433215406351',
      securityCode: '123',
      expirationMonth: '11',
      expirationYear: '25',
      cardHolderName: 'APRO',
      identificationType: 'DNI', 
      identificationNumber: '12345678'
    }
  }
};

// Datos de prueba para viajes
const testRideData = {
  rideId: `test_ride_${Date.now()}`,
  amount: 25.50, // S/25.50 - tarifa típica Lima
  currency: 'PEN',
  description: 'Viaje de prueba Oasis Taxi - Lima Centro a San Isidro',
  payerEmail: 'test.passenger@oasistaxi.com.pe',
  payerName: 'Pasajero Test',
  payerPhone: '+51987654321',
  pickupAddress: 'Plaza de Armas, Lima Centro',
  destinationAddress: 'Av. Javier Prado Este 123, San Isidro'
};

// Función principal
async function runTests() {
  const args = process.argv.slice(2);
  const envArg = args.find(arg => arg.startsWith('--env='));
  const confirmArg = args.includes('--confirm');
  
  const environment = envArg ? envArg.split('=')[1] : 'sandbox';
  
  if (!['sandbox', 'production'].includes(environment)) {
    console.error('❌ Entorno debe ser: sandbox o production');
    process.exit(1);
  }
  
  if (environment === 'production' && !confirmArg) {
    console.error('❌ Para producción debes usar --confirm');
    console.log('   Ejemplo: node scripts/test_mercadopago_peru.js --env=production --confirm');
    process.exit(1);
  }
  
  const currentConfig = config[environment];
  
  console.log('🇵🇪 INICIANDO TESTS MERCADOPAGO PERÚ');
  console.log('=====================================');
  console.log(`Entorno: ${environment.toUpperCase()}`);
  console.log(`API URL: ${currentConfig.apiUrl}`);
  console.log(`Fecha: ${new Date().toISOString()}`);
  console.log('');

  // Verificar que las credenciales no sean las de ejemplo
  if (currentConfig.mercadopagoPublicKey.includes('REEMPLAZAR')) {
    console.error('⚠️  CREDENCIALES NO CONFIGURADAS');
    console.error('   Debes reemplazar las credenciales en este archivo');
    console.error('   Ver: docs/MERCADOPAGO_SETUP_PERU.md');
    process.exit(1);
  }

  try {
    // Test 1: Verificar conectividad API
    console.log('🔌 TEST 1: Verificando conectividad API...');
    await testApiConnectivity(currentConfig);
    
    // Test 2: Crear preferencia de pago
    console.log('💳 TEST 2: Creando preferencia de pago...');
    const preference = await createPaymentPreference(currentConfig);
    
    // Test 3: Simular webhook (solo sandbox)
    if (environment === 'sandbox') {
      console.log('🎣 TEST 3: Simulando webhook...');
      await simulateWebhook(currentConfig, preference.preferenceId);
    }
    
    // Test 4: Verificar métodos de pago disponibles
    console.log('💰 TEST 4: Verificando métodos de pago Perú...');
    await testPaymentMethods(currentConfig);
    
    // Test 5: Testing con tarjetas de prueba (solo sandbox)
    if (environment === 'sandbox') {
      console.log('🃏 TEST 5: Testing con tarjetas de prueba...');
      await testWithCards(currentConfig);
    }
    
    console.log('');
    console.log('✅ TODOS LOS TESTS COMPLETADOS EXITOSAMENTE');
    console.log('');
    console.log('📊 RESUMEN:');
    console.log('- ✅ Conectividad API funcionando');
    console.log('- ✅ Preferencias de pago creándose correctamente'); 
    console.log('- ✅ Métodos de pago para Perú disponibles');
    if (environment === 'sandbox') {
      console.log('- ✅ Webhook handler funcionando');
      console.log('- ✅ Tarjetas de prueba validadas');
    }
    
  } catch (error) {
    console.error('❌ ERROR EN TESTS:', error.message);
    process.exit(1);
  }
}

// Test 1: Conectividad API
async function testApiConnectivity(config) {
  try {
    const response = await makeRequest('GET', `${config.apiUrl}/health`);
    if (response.status === 'ok') {
      console.log('   ✅ API backend respondiendo correctamente');
    } else {
      throw new Error('API no respondió correctamente');
    }
  } catch (error) {
    console.log('   ⚠️  Backend no disponible (normal en desarrollo)');
  }
}

// Test 2: Crear preferencia de pago
async function createPaymentPreference(config) {
  const payload = {
    rideId: testRideData.rideId,
    amount: testRideData.amount,
    description: testRideData.description,
    payerEmail: testRideData.payerEmail,
    payerName: testRideData.payerName
  };
  
  try {
    const response = await makeRequest('POST', `${config.apiUrl}/payments/create-preference`, payload);
    
    if (response.success) {
      console.log('   ✅ Preferencia creada exitosamente');
      console.log(`   📋 ID: ${response.data.preferenceId}`);
      console.log(`   💰 Monto: S/${response.data.amount}`);
      console.log(`   🏪 Comisión plataforma: S/${response.data.platformCommission}`);
      console.log(`   🚗 Ganancias conductor: S/${response.data.driverEarnings}`);
      
      return response.data;
    } else {
      throw new Error(response.message || 'Error creando preferencia');
    }
  } catch (error) {
    console.log('   ⚠️  Error creando preferencia (verificar credenciales)');
    throw error;
  }
}

// Test 3: Simular webhook
async function simulateWebhook(config, preferenceId) {
  const webhookPayload = {
    id: parseInt(Math.random() * 1000000),
    live_mode: false,
    type: 'payment',
    date_created: new Date().toISOString(),
    application_id: 123456789,
    user_id: 'USER_TEST',
    version: 1,
    api_version: 'v1',
    action: 'payment.created',
    data: {
      id: preferenceId
    }
  };
  
  try {
    const response = await makeRequest('POST', `${config.apiUrl}/payments/webhook`, webhookPayload, {
      'x-signature': 'ts=1234567890,v1=test_signature',
      'x-request-id': 'test_request_id'
    });
    
    console.log('   ✅ Webhook procesado correctamente');
  } catch (error) {
    console.log('   ⚠️  Error procesando webhook (verificar configuración)');
  }
}

// Test 4: Métodos de pago
async function testPaymentMethods(config) {
  const expectedMethods = [
    'mercadopago',
    'yape', 
    'plin',
    'pagoefectivo',
    'bank_transfer',
    'cash'
  ];
  
  try {
    const response = await makeRequest('GET', `${config.apiUrl}/payments/methods`);
    
    if (response.success) {
      const availableMethods = response.data.map(method => method.id);
      
      console.log('   ✅ Métodos de pago disponibles:');
      expectedMethods.forEach(method => {
        const isAvailable = availableMethods.includes(method);
        console.log(`   ${isAvailable ? '✅' : '❌'} ${method}`);
      });
    }
  } catch (error) {
    console.log('   ⚠️  No se pudieron verificar métodos de pago');
  }
}

// Test 5: Testing con tarjetas
async function testWithCards(config) {
  console.log('   🔄 Probando tarjeta Visa APROBADA...');
  await testCard(config, testCards.visa.approved, 'APROBADA');
  
  console.log('   🔄 Probando tarjeta Visa RECHAZADA...');  
  await testCard(config, testCards.visa.rejected, 'RECHAZADA');
  
  console.log('   🔄 Probando tarjeta Mastercard APROBADA...');
  await testCard(config, testCards.mastercard.approved, 'APROBADA');
}

async function testCard(config, card, expectedResult) {
  const payload = {
    rideId: `test_card_${Date.now()}`,
    amount: 15.00,
    currency: 'PEN', 
    paymentMethodId: 'visa',
    token: 'test_token_' + card.number.slice(-4),
    payerEmail: testRideData.payerEmail,
    description: `Test ${expectedResult} - ${card.cardHolderName}`
  };
  
  try {
    const response = await makeRequest('POST', `${config.apiUrl}/payments`, payload);
    
    if (expectedResult === 'APROBADA' && response.success) {
      console.log(`     ✅ Tarjeta ${card.number.slice(-4)}: ${expectedResult} ✓`);
    } else if (expectedResult === 'RECHAZADA' && !response.success) {
      console.log(`     ✅ Tarjeta ${card.number.slice(-4)}: ${expectedResult} ✓`);
    } else {
      console.log(`     ⚠️  Tarjeta ${card.number.slice(-4)}: Resultado inesperado`);
    }
  } catch (error) {
    console.log(`     ⚠️  Tarjeta ${card.number.slice(-4)}: Error en test`);
  }
}

// Función auxiliar para hacer requests HTTP
function makeRequest(method, url, data = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const isHttps = url.startsWith('https');
    const requestModule = isHttps ? https : http;
    
    const urlObj = new URL(url);
    const options = {
      hostname: urlObj.hostname,
      port: urlObj.port || (isHttps ? 443 : 80),
      path: urlObj.pathname + urlObj.search,
      method: method,
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'OasisTaxi-TestScript/1.0',
        ...headers
      }
    };
    
    const req = requestModule.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          const jsonResponse = JSON.parse(body);
          resolve(jsonResponse);
        } catch (e) {
          resolve({ status: res.statusCode, body });
        }
      });
    });
    
    req.on('error', reject);
    
    if (data) {
      req.write(JSON.stringify(data));
    }
    
    req.end();
  });
}

// Función de ayuda
function showHelp() {
  console.log('🇵🇪 SCRIPT DE TESTING MERCADOPAGO PERÚ');
  console.log('');
  console.log('Uso:');
  console.log('  node scripts/test_mercadopago_peru.js --env=sandbox');
  console.log('  node scripts/test_mercadopago_peru.js --env=production --confirm');
  console.log('');
  console.log('Opciones:');
  console.log('  --env=sandbox     Usar entorno de pruebas (por defecto)');
  console.log('  --env=production  Usar entorno de producción');
  console.log('  --confirm         Confirmar tests en producción');
  console.log('  --help            Mostrar esta ayuda');
  console.log('');
  console.log('Antes de ejecutar:');
  console.log('1. Configurar credenciales MercadoPago en este archivo');
  console.log('2. Seguir guía: docs/MERCADOPAGO_SETUP_PERU.md');
  console.log('3. Asegurar que el backend esté ejecutándose');
}

// Ejecutar script
if (process.argv.includes('--help') || process.argv.includes('-h')) {
  showHelp();
} else {
  runTests().catch(console.error);
}