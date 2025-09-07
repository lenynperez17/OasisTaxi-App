// Firebase initialization for testing
import * as admin from 'firebase-admin';

// Inicializar Firebase Admin SDK con las credenciales por defecto
// Esto funcionará si:
// 1. Estás ejecutando en Google Cloud
// 2. Tienes la variable de entorno GOOGLE_APPLICATION_CREDENTIALS configurada
// 3. Estás autenticado con gcloud CLI
// 4. Estás usando Firebase CLI con una sesión activa

export function initializeFirebaseForTests() {
  if (admin.apps.length === 0) {
    try {
      // Intentar inicializar con credenciales por defecto
      admin.initializeApp({
        projectId: 'oasis-taxi-peru',
        databaseURL: 'https://oasis-taxi-peru-default-rtdb.firebaseio.com',
        storageBucket: 'oasis-taxi-peru.firebasestorage.app',
        // No especificamos credential para usar Application Default Credentials
      });
      console.log('✅ Firebase Admin inicializado con credenciales por defecto');
    } catch (error) {
      console.error('❌ Error inicializando Firebase Admin:', error);
      
      // Fallback: inicializar sin credenciales (solo para pruebas locales)
      console.log('⚠️ Inicializando Firebase Admin sin credenciales (modo prueba)');
      admin.initializeApp({
        projectId: 'oasis-taxi-peru',
      });
    }
  }
  
  return admin;
}

// Exportar las instancias para usar en los tests
export const getTestFirestore = () => admin.firestore();
export const getTestAuth = () => admin.auth();
export const getTestDatabase = () => admin.database();