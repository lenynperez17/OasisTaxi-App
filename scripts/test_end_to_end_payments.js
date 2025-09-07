#!/usr/bin/env node

/**
 * 🚀 TESTING END-TO-END PAGOS OASIS TAXI PERÚ
 * ===========================================
 * 
 * Script completo de testing para validar todo el flujo de pagos
 * desde la creación de la preferencia hasta el webhook final.
 * 
 * Uso:
 * node scripts/test_end_to_end_payments.js --env=sandbox
 * node scripts/test_end_to_end_payments.js --env=sandbox --verbose
 * node scripts/test_end_to_end_payments.js --env=production --confirm
 */

const https = require('https');
const http = require('http');
const crypto = require('crypto');

// Configuración de testing
const config = {
  sandbox: {
    apiUrl: 'http://localhost:3000/api/v1',
    frontendUrl: 'http://localhost:5020',
    mercadopagoPublicKey: 'TEST-REEMPLAZAR-CON-KEY-REAL-SANDBOX',
    mercadopagoAccessToken: 'TEST-REEMPLAZAR-CON-ACCESS-TOKEN-REAL-SANDBOX',
    webhookSecret: 'test_webhook_secret'
  },
  production: {
    apiUrl: 'https://api.oasistaxi.com.pe/api/v1',
    frontendUrl: 'https://app.oasistaxi.com.pe',
    mercadopagoPublicKey: 'APP_USR-REEMPLAZAR-CON-KEY-REAL-PRODUCCION',
    mercadopagoAccessToken: 'APP_USR-REEMPLAZAR-CON-ACCESS-TOKEN-REAL-PRODUCCIÓN',
    webhookSecret: 'production_webhook_secret'
  }
};

// Datos de testing realistas para Lima, Perú
const testData = {
  passenger: {
    id: 'test_passenger_001',
    name: 'María González',
    email: 'maria.gonzalez@test.oasistaxi.com.pe',
    phone: '+51987654321',
    dni: '12345678'
  },
  driver: {
    id: 'test_driver_001', 
    name: 'Carlos Mendoza',
    email: 'carlos.mendoza@test.oasistaxi.com.pe',
    phone: '+51912345678',
    dni: '87654321',
    licensePlate: 'ABC-123'
  },
  ride: {
    pickup: {
      address: 'Plaza de Armas, Lima Centro, Lima',
      lat: -12.046373,
      lng: -77.042755
    },
    destination: {
      address: 'Av. Javier Prado Este 123, San Isidro, Lima',
      lat: -12.094635,
      lng: -76.971515
    },
    distance: 8.5, // km
    duration: 25,   // minutos
    vehicleType: 'standard'
  }
};

// Variables globales para tracking
let testResults = {
  totalTests: 0,
  passedTests: 0,
  failedTests: 0,
  errors: [],
  startTime: null,
  endTime: null
};

let currentConfig = null;
let verbose = false;

/**
 * Función principal de testing
 */
async function runEndToEndTests() {
  testResults.startTime = new Date();
  
  console.log('🇵🇪 INICIANDO TESTS END-TO-END PAGOS PERÚ');
  console.log('==========================================');
  console.log(`Entorno: ${process.env.NODE_ENV || 'sandbox'}`);
  console.log(`Fecha: ${new Date().toISOString()}`);
  console.log('');

  try {
    // Configuración inicial
    await setupTestEnvironment();
    
    // Batería de tests
    await runTestSuite();
    
    // Reporte final
    generateFinalReport();
    
  } catch (error) {
    console.error('❌ ERROR CRÍTICO EN TESTS:', error.message);
    process.exit(1);
  }
}

/**
 * Configurar entorno de testing
 */
async function setupTestEnvironment() {
  const args = process.argv.slice(2);
  const envArg = args.find(arg => arg.startsWith('--env='));
  const environment = envArg ? envArg.split('=')[1] : 'sandbox';
  verbose = args.includes('--verbose');
  
  currentConfig = config[environment];
  
  if (!currentConfig) {
    throw new Error('Entorno inválido. Usar: sandbox o production');
  }

  console.log('🔧 CONFIGURANDO ENTORNO');
  console.log(`   API URL: ${currentConfig.apiUrl}`);
  console.log(`   Frontend: ${currentConfig.frontendUrl}`);
  console.log('');

  // Verificar credenciales
  if (currentConfig.mercadopagoPublicKey.includes('REEMPLAZAR')) {
    console.warn('⚠️  CREDENCIALES NO CONFIGURADAS');
    console.warn('   Ver: docs/MERCADOPAGO_SETUP_PERU.md');
    console.log('');
  }
}

/**
 * Ejecutar suite completa de tests
 */
async function runTestSuite() {
  console.log('🧪 EJECUTANDO BATERÍA DE TESTS');
  console.log('==============================');
  console.log('');

  // TEST 1: Conectividad básica
  await runTest('Conectividad API', testApiConnectivity);
  
  // TEST 2: Cálculo de tarifas
  await runTest('Cálculo tarifas Perú', testFareCalculation);
  
  // TEST 3: Crear preferencia MercadoPago
  const preference = await runTest('Crear preferencia MercadoPago', testCreatePreference);
  
  // TEST 4: Simular webhook de pago
  if (preference) {
    await runTest('Procesar webhook pago', () => testProcessWebhook(preference));
  }
  
  // TEST 5: Verificar comisiones
  await runTest('Calcular comisiones conductor', testDriverCommissions);
  
  // TEST 6: Sistema de bonificaciones
  await runTest('Sistema bonificaciones', testPerformanceBonuses);
  
  // TEST 7: Solicitud de pago conductor
  await runTest('Solicitud pago conductor', testDriverPayout);
  
  // TEST 8: Validación de métodos de pago
  await runTest('Métodos pago Perú', testPaymentMethods);
  
  // TEST 9: Manejo de errores
  await runTest('Manejo errores', testErrorHandling);
  
  // TEST 10: Performance y stress
  await runTest('Performance básico', testBasicPerformance);
}

/**
 * Ejecutar test individual
 */
async function runTest(testName, testFunction) {
  testResults.totalTests++;
  
  try {
    console.log(`🔄 ${testName}...`);
    
    const startTime = Date.now();
    const result = await testFunction();
    const duration = Date.now() - startTime;
    
    testResults.passedTests++;
    console.log(`   ✅ PASÓ (${duration}ms)`);
    
    if (verbose && result) {
      console.log(`   📊 Resultado:`, JSON.stringify(result, null, 2));
    }
    
    return result;
    
  } catch (error) {
    testResults.failedTests++;
    testResults.errors.push({ testName, error: error.message });
    
    console.log(`   ❌ FALLÓ: ${error.message}`);
    
    if (verbose) {
      console.log(`   🔍 Stack:`, error.stack);
    }
    
    return null;
  }
}

/**
 * TEST 1: Conectividad API
 */
async function testApiConnectivity() {
  const response = await makeRequest('GET', `${currentConfig.apiUrl}/health`);
  
  if (response.status !== 'ok' && !response.message) {
    throw new Error('API no respondió correctamente');
  }
  
  return { status: 'connected', response };
}

/**
 * TEST 2: Cálculo de tarifas específicas para Perú
 */
async function testFareCalculation() {
  const fareData = {
    distance: testData.ride.distance,
    duration: testData.ride.duration,
    vehicleType: testData.ride.vehicleType,
    applyDynamicPricing: false
  };
  
  const response = await makeRequest('POST', `${currentConfig.apiUrl}/rides/calculate-fare`, fareData);
  
  if (!response.success || !response.data.fare) {
    throw new Error('Error calculando tarifa');
  }
  
  const fare = response.data.fare;
  
  // Validar tarifa mínima para Perú (S/4.50)
  if (fare < 4.5) {
    throw new Error(`Tarifa menor a mínimo: S/${fare}`);
  }
  
  // Validar comisiones
  const expectedDriverEarnings = fare * 0.8;
  const expectedPlatformCommission = fare * 0.2;
  
  if (Math.abs(response.data.driverEarnings - expectedDriverEarnings) > 0.01) {
    throw new Error('Cálculo ganancias conductor incorrecto');
  }
  
  return {
    fare,
    driverEarnings: response.data.driverEarnings,
    platformCommission: response.data.platformCommission,
    currency: 'PEN'
  };
}

/**
 * TEST 3: Crear preferencia MercadoPago
 */
async function testCreatePreference() {
  const rideId = `test_ride_${Date.now()}`;
  const amount = 25.50; // Tarifa típica Lima
  
  const preferenceData = {
    rideId,
    amount,
    description: `Viaje prueba Lima - ${testData.ride.pickup.address} a ${testData.ride.destination.address}`,
    payerEmail: testData.passenger.email,
    payerName: testData.passenger.name
  };
  
  const response = await makeRequest('POST', `${currentConfig.apiUrl}/payments/create-preference`, preferenceData);
  
  if (!response.success || !response.data.preferenceId) {
    throw new Error('Error creando preferencia MercadoPago');
  }
  
  const data = response.data;
  
  // Validar respuesta
  if (!data.initPoint || !data.publicKey) {
    throw new Error('Respuesta de preferencia incompleta');
  }
  
  // Validar comisiones
  if (Math.abs(data.platformCommission - amount * 0.2) > 0.01) {
    throw new Error('Comisión plataforma incorrecta');
  }
  
  if (Math.abs(data.driverEarnings - amount * 0.8) > 0.01) {
    throw new Error('Ganancias conductor incorrectas');
  }
  
  return {
    rideId,
    preferenceId: data.preferenceId,
    initPoint: data.initPoint,
    amount: data.amount,
    platformCommission: data.platformCommission,
    driverEarnings: data.driverEarnings
  };
}

/**
 * TEST 4: Procesar webhook de pago
 */
async function testProcessWebhook(preference) {
  const webhookData = {
    id: Math.floor(Math.random() * 1000000),
    live_mode: false,
    type: 'payment',
    date_created: new Date().toISOString(),
    application_id: 123456789,
    user_id: 'USER_TEST',
    version: 1,
    api_version: 'v1',
    action: 'payment.updated',
    data: {
      id: preference.preferenceId
    }
  };
  
  // Generar firma válida
  const signature = generateWebhookSignature(
    webhookData.data.id,
    'test_request_id',
    Math.floor(Date.now() / 1000).toString()
  );
  
  const headers = {
    'x-signature': signature,
    'x-request-id': 'test_request_id',
    'content-type': 'application/json'
  };
  
  const response = await makeRequest('POST', `${currentConfig.apiUrl}/payments/webhook`, webhookData, headers);
  
  if (!response.received) {
    throw new Error('Webhook no fue recibido');
  }
  
  return {
    received: response.received,
    processed: response.processed,
    processingTime: response.processing_time
  };
}

/**
 * TEST 5: Calcular comisiones del conductor
 */
async function testDriverCommissions() {
  const rideAmount = 30.00;
  const driverId = testData.driver.id;
  
  const commissionData = {
    rideId: `commission_test_${Date.now()}`,
    paymentAmount: rideAmount,
    driverId,
    bonusMultiplier: 1.0
  };
  
  const response = await makeRequest('POST', `${currentConfig.apiUrl}/drivers/process-commission`, commissionData);
  
  if (!response.success) {
    throw new Error('Error procesando comisión');
  }
  
  const data = response.data;
  const expectedDriverEarnings = rideAmount * 0.8;
  const expectedPlatformCommission = rideAmount * 0.2;
  
  if (Math.abs(data.driverEarnings - expectedDriverEarnings) > 0.01) {
    throw new Error('Ganancias conductor incorrectas');
  }
  
  if (Math.abs(data.platformCommission - expectedPlatformCommission) > 0.01) {
    throw new Error('Comisión plataforma incorrecta');
  }
  
  return {
    driverEarnings: data.driverEarnings,
    platformCommission: data.platformCommission,
    totalProcessed: data.totalProcessed
  };
}

/**
 * TEST 6: Sistema de bonificaciones
 */
async function testPerformanceBonuses() {
  const driverId = testData.driver.id;
  
  const response = await makeRequest('GET', `${currentConfig.apiUrl}/drivers/${driverId}/performance-bonus?period=weekly`);
  
  if (!response.success) {
    throw new Error('Error calculando bonificación');
  }
  
  const data = response.data;
  
  if (typeof data.multiplier !== 'number' || data.multiplier < 1.0) {
    throw new Error('Multiplicador de bonificación inválido');
  }
  
  if (!Array.isArray(data.criteria)) {
    throw new Error('Criterios de bonificación inválidos');
  }
  
  return {
    bonusEarned: data.bonusEarned,
    multiplier: data.multiplier,
    criteria: data.criteria
  };
}

/**
 * TEST 7: Solicitud de pago del conductor
 */
async function testDriverPayout() {
  const payoutData = {
    driverId: testData.driver.id,
    amount: 150.00, // S/150
    bankAccount: {
      bankName: 'BCP',
      accountType: 'savings',
      accountNumber: '12345678901234',
      cci: '00212345678901234567',
      accountHolderName: testData.driver.name,
      accountHolderDni: testData.driver.dni
    }
  };
  
  const response = await makeRequest('POST', `${currentConfig.apiUrl}/drivers/request-payout`, payoutData);
  
  if (!response.success) {
    throw new Error('Error solicitando pago');
  }
  
  const data = response.data;
  
  if (!data.payoutId || !data.scheduledFor) {
    throw new Error('Respuesta de pago incompleta');
  }
  
  // Validar deducciones
  const expectedTaxRetained = payoutData.amount * 0.08;
  const expectedNetAmount = payoutData.amount - expectedTaxRetained - 2.50; // fee
  
  if (Math.abs(data.netAmount - expectedNetAmount) > 0.01) {
    throw new Error('Monto neto incorrecto');
  }
  
  return {
    payoutId: data.payoutId,
    netAmount: data.netAmount,
    taxRetained: data.taxRetained,
    scheduledFor: data.scheduledFor
  };
}

/**
 * TEST 8: Métodos de pago disponibles para Perú
 */
async function testPaymentMethods() {
  const response = await makeRequest('GET', `${currentConfig.apiUrl}/payments/methods/peru`);
  
  if (!response.success || !Array.isArray(response.data)) {
    throw new Error('Error obteniendo métodos de pago');
  }
  
  const methods = response.data;
  const requiredMethods = ['mercadopago', 'yape', 'plin', 'pagoefectivo', 'bank_transfer', 'cash'];
  
  for (const required of requiredMethods) {
    const found = methods.find(m => m.id === required);
    if (!found || !found.isEnabled) {
      throw new Error(`Método de pago requerido no disponible: ${required}`);
    }
  }
  
  return {
    totalMethods: methods.length,
    availableMethods: methods.map(m => m.id),
    requiredMethods
  };
}

/**
 * TEST 9: Manejo de errores
 */
async function testErrorHandling() {
  const tests = [
    // Monto inválido
    { 
      endpoint: '/payments/create-preference',
      data: { amount: -10, rideId: 'test' },
      expectedError: 'INVALID_AMOUNT'
    },
    // Pago no encontrado
    {
      endpoint: '/payments/status/invalid_id',
      method: 'GET',
      expectedError: 'PAYMENT_NOT_FOUND'
    },
    // Banco no soportado
    {
      endpoint: '/drivers/request-payout',
      data: { 
        amount: 100,
        bankAccount: { bankName: 'BANCO_INEXISTENTE' }
      },
      expectedError: 'UNSUPPORTED_BANK'
    }
  ];
  
  const results = [];
  
  for (const test of tests) {
    try {
      const response = await makeRequest(
        test.method || 'POST',
        `${currentConfig.apiUrl}${test.endpoint}`,
        test.data
      );
      
      // Si llega aquí, debería haber fallado
      results.push({ test: test.endpoint, result: 'UNEXPECTED_SUCCESS' });
      
    } catch (error) {
      // Verificar que el error sea el esperado
      if (error.message.includes(test.expectedError)) {
        results.push({ test: test.endpoint, result: 'EXPECTED_ERROR' });
      } else {
        results.push({ test: test.endpoint, result: 'UNEXPECTED_ERROR', error: error.message });
      }
    }
  }
  
  return { errorTests: results };
}

/**
 * TEST 10: Performance básico
 */
async function testBasicPerformance() {
  const iterations = 10;
  const endpoint = `${currentConfig.apiUrl}/payments/methods/peru`;
  const times = [];
  
  for (let i = 0; i < iterations; i++) {
    const startTime = Date.now();
    await makeRequest('GET', endpoint);
    const duration = Date.now() - startTime;
    times.push(duration);
  }
  
  const avgTime = times.reduce((sum, time) => sum + time, 0) / times.length;
  const maxTime = Math.max(...times);
  const minTime = Math.min(...times);
  
  if (avgTime > 1000) {
    throw new Error(`Tiempo promedio muy alto: ${avgTime}ms`);
  }
  
  if (maxTime > 2000) {
    throw new Error(`Tiempo máximo muy alto: ${maxTime}ms`);
  }
  
  return {
    iterations,
    averageTime: avgTime,
    maxTime,
    minTime,
    totalTime: times.reduce((sum, time) => sum + time, 0)
  };
}

/**
 * Generar firma de webhook
 */
function generateWebhookSignature(dataId, requestId, timestamp) {
  const secret = currentConfig.webhookSecret;
  const manifest = `id:${dataId};request-id:${requestId};ts:${timestamp};`;
  const signature = crypto.createHmac('sha256', secret).update(manifest).digest('hex');
  return `ts=${timestamp},v1=${signature}`;
}

/**
 * Hacer request HTTP
 */
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
        'User-Agent': 'OasisTaxi-EndToEndTest/1.0',
        ...headers
      },
      timeout: 10000 // 10 segundos
    };
    
    const req = requestModule.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          const jsonResponse = JSON.parse(body);
          if (res.statusCode >= 400) {
            reject(new Error(jsonResponse.error || `HTTP ${res.statusCode}`));
          } else {
            resolve(jsonResponse);
          }
        } catch (e) {
          if (res.statusCode >= 400) {
            reject(new Error(`HTTP ${res.statusCode}: ${body}`));
          } else {
            resolve({ status: res.statusCode, body });
          }
        }
      });
    });
    
    req.on('error', reject);
    req.on('timeout', () => reject(new Error('Request timeout')));
    
    if (data) {
      req.write(JSON.stringify(data));
    }
    
    req.end();
  });
}

/**
 * Generar reporte final
 */
function generateFinalReport() {
  testResults.endTime = new Date();
  const duration = testResults.endTime - testResults.startTime;
  
  console.log('');
  console.log('📊 REPORTE FINAL DE TESTS');
  console.log('=========================');
  console.log(`⏱️  Duración total: ${(duration / 1000).toFixed(2)}s`);
  console.log(`📈 Tests ejecutados: ${testResults.totalTests}`);
  console.log(`✅ Tests exitosos: ${testResults.passedTests}`);
  console.log(`❌ Tests fallidos: ${testResults.failedTests}`);
  console.log(`🎯 Tasa de éxito: ${((testResults.passedTests / testResults.totalTests) * 100).toFixed(1)}%`);
  
  if (testResults.errors.length > 0) {
    console.log('');
    console.log('❌ ERRORES ENCONTRADOS:');
    testResults.errors.forEach((error, index) => {
      console.log(`   ${index + 1}. ${error.testName}: ${error.error}`);
    });
  }
  
  console.log('');
  if (testResults.failedTests === 0) {
    console.log('🎉 TODOS LOS TESTS PASARON EXITOSAMENTE');
    console.log('   Sistema de pagos listo para producción');
  } else {
    console.log('⚠️  ALGUNOS TESTS FALLARON');
    console.log('   Revisar errores antes de desplegar');
  }
  
  console.log('');
  console.log('🔗 PRÓXIMOS PASOS:');
  console.log('1. Configurar credenciales reales de MercadoPago');
  console.log('2. Configurar webhook URL en panel MercadoPago');
  console.log('3. Probar con tarjetas de prueba en sandbox');
  console.log('4. Implementar monitoreo en producción');
  console.log('');
  
  // Exit code según resultado
  process.exit(testResults.failedTests === 0 ? 0 : 1);
}

// Ejecutar si es llamado directamente
if (require.main === module) {
  runEndToEndTests().catch(console.error);
}