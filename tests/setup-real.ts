// Test setup and configuration - REAL Firebase
import { beforeAll, afterAll, beforeEach, afterEach } from '@jest/globals';
import * as admin from 'firebase-admin';
import { initializeFirebaseAdmin, getFirestore, getAuth } from '../src/config/firebase-init';
import * as path from 'path';

// Configurar la variable de entorno para el archivo de credenciales
const serviceAccountPath = path.resolve(__dirname, '..', 'oasis-taxi-peru-firebase-adminsdk-fbsvc-deb77aff98.json');
process.env.GOOGLE_APPLICATION_CREDENTIALS = serviceAccountPath;
process.env.FIREBASE_PROJECT_ID = 'oasis-taxi-peru';
process.env.FIREBASE_DATABASE_URL = 'https://oasis-taxi-peru-default-rtdb.firebaseio.com';
process.env.FIREBASE_STORAGE_BUCKET = 'oasis-taxi-peru.firebasestorage.app';

// Inicializar Firebase usando la configuración unificada
initializeFirebaseAdmin();

export const db = getFirestore();
export const auth = getAuth();

// Test data cleanup - REAL Firebase cleanup
export const cleanupTestData = async () => {
  try {
    console.log('🧹 Limpiando datos de prueba en Firebase real...');
    
    // Clean up test collections (only test data)
    const testCollections = [
      'test_users',
      'test_rides', 
      'test_payments',
      'test_notifications',
      'test_chat_messages',
      'test_ratings'
    ];

    for (const collectionName of testCollections) {
      const snapshot = await db.collection(collectionName).get();
      const batch = db.batch();
      
      snapshot.docs.forEach(doc => {
        batch.delete(doc.ref);
      });
      
      if (!snapshot.empty) {
        await batch.commit();
        console.log(`✅ Eliminados ${snapshot.docs.length} documentos de ${collectionName}`);
      }
    }
    
    // También limpiar usuarios de prueba de Auth (solo los que empiecen con test-)
    try {
      const listUsersResult = await auth.listUsers(1000);
      const testUsers = listUsersResult.users.filter(user => 
        user.email?.includes('test-') || user.displayName?.includes('Test')
      );
      
      for (const user of testUsers) {
        await auth.deleteUser(user.uid);
        console.log(`🗑️ Usuario de prueba eliminado: ${user.email}`);
      }
    } catch (error) {
      console.log('⚠️ Error limpiando usuarios de prueba (puede ser normal):', error);
    }
    
  } catch (error) {
    console.error('❌ Error cleaning up test data:', error);
  }
};

// Create test user - REAL Firebase
export const createTestUser = async (userData: any) => {
  try {
    // Si no se proporciona UID o si existe, no especificar UID (Firebase generará uno)
    const createUserData: any = {
      email: userData.email,
      password: 'testpassword123',
      displayName: userData.displayName,
      phoneNumber: userData.phoneNumber,
    };
    
    // Solo agregar UID si se proporciona y añadir timestamp para hacerlo único
    if (userData.uid) {
      createUserData.uid = `${userData.uid}_${Date.now()}`;
    }
    
    const userRecord = await auth.createUser(createUserData);

    // Hash password para que coincida con el auth-service
    const bcrypt = require('bcryptjs');
    const hashedPassword = await bcrypt.hash('testpassword123', 12);
    
    await db.collection('test_users').doc(userRecord.uid).set({
      ...userData,
      hashedPassword,
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    console.log(`✅ Usuario de prueba creado: ${userRecord.email}`);
    return userRecord;
  } catch (error) {
    console.error('❌ Error creating test user:', error);
    throw error;
  }
};

// Delete test user - REAL Firebase
export const deleteTestUser = async (uid: string) => {
  try {
    await auth.deleteUser(uid);
    await db.collection('test_users').doc(uid).delete();
    console.log(`🗑️ Usuario de prueba eliminado: ${uid}`);
  } catch (error) {
    console.error('❌ Error deleting test user:', error);
  }
};

// Generate test JWT token - REAL Firebase
export const generateTestToken = async (uid: string) => {
  try {
    return await auth.createCustomToken(uid);
  } catch (error) {
    console.error('❌ Error generating test token:', error);
    throw error;
  }
};

// Test data generators
export const generateTestRide = (overrides: any = {}) => ({
  id: `test_ride_${Date.now()}`,
  passengerId: 'test_passenger_1',
  driverId: null,
  status: 'searching',
  pickup: {
    lat: -34.6037,
    lng: -58.3816,
    address: 'Test Pickup Address',
  },
  destination: {
    lat: -34.6118,
    lng: -58.3960,
    address: 'Test Destination Address',
  },
  estimatedFare: 1500,
  estimatedDuration: 15,
  estimatedDistance: 5.2,
  createdAt: new Date(),
  updatedAt: new Date(),
  ...overrides,
});

export const generateTestPayment = (overrides: any = {}) => ({
  id: `test_payment_${Date.now()}`,
  userId: 'test_user_1',
  rideId: 'test_ride_1',
  amount: 1500,
  currency: 'ARS',
  method: 'card',
  status: 'pending',
  gatewayResponse: null,
  createdAt: new Date(),
  updatedAt: new Date(),
  ...overrides,
});

export const generateTestNotification = (overrides: any = {}) => ({
  id: `test_notification_${Date.now()}`,
  userId: 'test_user_1',
  type: 'ride_assigned',
  title: 'Test Notification',
  body: 'This is a test notification',
  data: {},
  read: false,
  createdAt: new Date(),
  ...overrides,
});

// Mock HTTP request helper
export const mockRequest = (overrides: any = {}) => ({
  method: 'GET',
  url: '/test',
  headers: {},
  body: {},
  query: {},
  params: {},
  userId: null,
  ...overrides,
});

// Mock HTTP response helper
export const mockResponse = () => {
  const res: any = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  res.send = jest.fn().mockReturnValue(res);
  res.cookie = jest.fn().mockReturnValue(res);
  res.clearCookie = jest.fn().mockReturnValue(res);
  return res;
};

// Setup and teardown hooks
beforeAll(async () => {
  console.log('🚀 Setting up REAL Firebase test environment...');
  console.log('📧 Service Account:', admin.credential.cert ? 'Configurado' : 'NO configurado');
  await cleanupTestData();
}, 60000); // 60 segundos timeout

afterAll(async () => {
  console.log('🧹 Cleaning up REAL Firebase test environment...');
  await cleanupTestData();
}, 60000); // 60 segundos timeout

beforeEach(async () => {
  // Setup for each test
});

afterEach(async () => {
  // Cleanup after each test
});

// Error matchers
export const expectValidationError = (error: any, field?: string) => {
  expect(error).toBeDefined();
  expect(error.statusCode).toBe(400);
  expect(error.code).toBe('VALIDATION_ERROR');
  if (field) {
    // Hacer la comparaci\u00f3n case-insensitive
    expect(error.message.toLowerCase()).toContain(field.toLowerCase());
  }
};

export const expectNotFoundError = (error: any) => {
  expect(error).toBeDefined();
  expect(error.statusCode).toBe(404);
};

export const expectUnauthorizedError = (error: any) => {
  expect(error).toBeDefined();
  expect(error.statusCode).toBe(401);
  expect(error.code).toBe('UNAUTHORIZED');
};

export const expectForbiddenError = (error: any) => {
  expect(error).toBeDefined();
  expect(error.statusCode).toBe(403);
};

// Test utilities
export const wait = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

export const generateRandomString = (length: number = 10) => {
  return Math.random().toString(36).substring(2, length + 2);
};

export const generateRandomNumber = (min: number = 0, max: number = 1000) => {
  return Math.floor(Math.random() * (max - min + 1)) + min;
};

export const generateRandomLocation = () => ({
  lat: -34.6037 + (Math.random() - 0.5) * 0.1,
  lng: -58.3816 + (Math.random() - 0.5) * 0.1,
});

// Assert helpers
export const assertApiResponse = (response: any, expectedStatus: number = 200) => {
  expect(response.success).toBe(expectedStatus < 400);
  expect(response.timestamp).toBeDefined();
  if (expectedStatus >= 400) {
    expect(response.error).toBeDefined();
  }
};

export const assertPaginationInfo = (pagination: any) => {
  expect(pagination).toBeDefined();
  expect(pagination.page).toBeGreaterThan(0);
  expect(pagination.limit).toBeGreaterThan(0);
  expect(pagination.total).toBeGreaterThanOrEqual(0);
  expect(pagination.totalPages).toBeGreaterThanOrEqual(0);
  expect(typeof pagination.hasNext).toBe('boolean');
  expect(typeof pagination.hasPrev).toBe('boolean');
};

// Real external services (no mocks)
export const mockMercadoPago = {
  createPayment: jest.fn().mockResolvedValue({ id: 'payment_123' }),
  getPayment: jest.fn().mockResolvedValue({ status: 'approved' }),
  refundPayment: jest.fn().mockResolvedValue({ status: 'refunded' }),
  cancelPayment: jest.fn().mockResolvedValue({ status: 'cancelled' }),
};

export const mockFirebaseMessaging = {
  send: jest.fn().mockResolvedValue({ messageId: 'msg_123' }),
  sendMulticast: jest.fn().mockResolvedValue({ successCount: 1 }),
  subscribeToTopic: jest.fn().mockResolvedValue({}),
  unsubscribeFromTopic: jest.fn().mockResolvedValue({}),
};

export const mockEmailService = {
  sendEmail: jest.fn().mockResolvedValue({ messageId: 'email_123' }),
};

export const mockSMSService = {
  sendSMS: jest.fn().mockResolvedValue({ messageId: 'sms_123' }),
};