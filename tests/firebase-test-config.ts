// Firebase Test Configuration
import * as admin from 'firebase-admin';
import * as firebaseConfig from '../firebase-admin-config.json';

// Initialize Firebase Admin SDK for testing
export const initializeTestFirebase = () => {
  // Use Firebase emulator or real configuration
  if (!admin.apps.length) {
    try {
      // Try to use environment variable first for CI/CD
      if (process.env.FIREBASE_SERVICE_ACCOUNT) {
        const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
          databaseURL: firebaseConfig.databaseURL,
          projectId: firebaseConfig.projectId,
          storageBucket: firebaseConfig.storageBucket
        });
      } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
        // Use application default credentials if available
        admin.initializeApp({
          credential: admin.credential.applicationDefault(),
          databaseURL: firebaseConfig.databaseURL,
          projectId: firebaseConfig.projectId,
          storageBucket: firebaseConfig.storageBucket
        });
      } else {
        // Use project configuration for local testing with emulator
        admin.initializeApp({
          projectId: firebaseConfig.projectId,
          databaseURL: firebaseConfig.databaseURL,
          storageBucket: firebaseConfig.storageBucket
        });
      }
    } catch (error) {
      console.warn('Firebase initialization warning:', error);
      // Fallback to basic configuration for unit tests
      admin.initializeApp({
        projectId: firebaseConfig.projectId || 'oasis-taxi-peru'
      });
    }
  }
  
  return admin;
};

// Mock Firestore for testing
export const getMockFirestore = () => {
  const mockDb = {
    collection: jest.fn().mockReturnThis(),
    doc: jest.fn().mockReturnThis(),
    set: jest.fn().mockResolvedValue({}),
    get: jest.fn().mockResolvedValue({
      exists: true,
      data: () => ({}),
      id: 'mockId'
    }),
    update: jest.fn().mockResolvedValue({}),
    delete: jest.fn().mockResolvedValue({}),
    where: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    onSnapshot: jest.fn()
  };
  
  return mockDb;
};

// Mock Auth for testing
export const getMockAuth = () => {
  return {
    createUser: jest.fn().mockResolvedValue({
      uid: 'test-uid',
      email: 'test@example.com'
    }),
    getUserByEmail: jest.fn().mockRejectedValue({
      code: 'auth/user-not-found'
    }),
    deleteUser: jest.fn().mockResolvedValue({}),
    updateUser: jest.fn().mockResolvedValue({}),
    setCustomUserClaims: jest.fn().mockResolvedValue({}),
    verifyIdToken: jest.fn().mockResolvedValue({
      uid: 'test-uid'
    })
  };
};

// Mock Storage for testing
export const getMockStorage = () => {
  return {
    bucket: jest.fn().mockReturnThis(),
    file: jest.fn().mockReturnThis(),
    save: jest.fn().mockResolvedValue({}),
    delete: jest.fn().mockResolvedValue({}),
    getSignedUrl: jest.fn().mockResolvedValue(['https://mock-url.com'])
  };
};

export default initializeTestFirebase;