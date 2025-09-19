const admin = require('firebase-admin');
const serviceAccount = require('./app/assets/oasis-taxi-peru-firebase-adminsdk-fbsvc-deb77aff98.json');

// Inicializar Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'oasis-taxi-peru'
});

const db = admin.firestore();
const auth = admin.auth();
const storage = admin.storage();

// Datos del usuario específico
const userData = {
  fullName: 'Lenyn Mauricio Perez Araujo',
  email: 'Lepereza@ucvvirtual.edu.pe',
  phone: '962321336', // Sin +51 para Firestore
  gender: 'male',
  profilePhotoUrl: '',
  isActive: true,
  isVerified: true,
  emailVerified: true,
  phoneVerified: true,
  rating: 5.0,
  totalTrips: 0,
  balance: 0.0,
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  securitySettings: {
    loginAttempts: 0,
    lastPasswordChange: admin.firestore.FieldValue.serverTimestamp(),
    passwordHistory: []
  },
  deviceInfo: {
    lastDeviceId: null,
    trustedDevices: []
  }
};

// Contraseña segura para todos los usuarios
const PASSWORD = 'OasisTaxi2024$ecure!';

// Función para limpiar toda la base de datos
async function cleanDatabase() {
  console.log('🧹 Limpiando base de datos existente...');
  
  try {
    // Eliminar todos los usuarios de Firebase Auth
    console.log('Eliminando usuarios de Auth...');
    const listUsersResult = await auth.listUsers(1000);
    const deletePromises = listUsersResult.users.map(user => 
      auth.deleteUser(user.uid).catch(err => 
        console.log(`Error eliminando usuario ${user.email}: ${err.message}`)
      )
    );
    await Promise.all(deletePromises);
    console.log(`✅ ${listUsersResult.users.length} usuarios eliminados de Auth`);
    
    // Eliminar colecciones principales
    const collections = ['users', 'drivers', 'trips', 'notifications', 
                          'price_negotiations', 'payments', 'security_logs',
                          'admin_notifications'];
    
    for (const collectionName of collections) {
      console.log(`Limpiando colección ${collectionName}...`);
      const snapshot = await db.collection(collectionName).get();
      const batch = db.batch();
      let count = 0;
      
      snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
        count++;
      });
      
      if (count > 0) {
        await batch.commit();
        console.log(`✅ ${count} documentos eliminados de ${collectionName}`);
      }
    }
    
    console.log('✅ Base de datos limpiada completamente');
  } catch (error) {
    console.error('❌ Error limpiando base de datos:', error);
    throw error;
  }
}

// Función principal para crear los 3 usuarios específicos
async function createThreeUsers() {
  try {
    console.log('🚀 Iniciando creación de 3 usuarios específicos...');
    console.log('----------------------------------------');
    
    // 1. CREAR USUARIO PASAJERO
    console.log('📱 [1/3] Creando usuario PASAJERO...');
    const passengerUser = await auth.createUser({
      email: userData.email,
      password: PASSWORD,
      displayName: userData.fullName,
      emailVerified: true,
      phoneNumber: '+51962321336'
    });

    await db.collection('users').doc(passengerUser.uid).set({
      ...userData,
      userType: 'passenger',
      uid: passengerUser.uid
    });

    console.log(`✅ Usuario PASAJERO creado:`);
    console.log(`   - UID: ${passengerUser.uid}`);
    console.log(`   - Email: ${userData.email}`);
    console.log(`   - Password: ${PASSWORD}`);
    console.log('----------------------------------------');

    // 2. CREAR USUARIO CONDUCTOR
    console.log('🚗 [2/3] Creando usuario CONDUCTOR...');
    const driverEmail = 'Lepereza+driver@ucvvirtual.edu.pe';
    const driverUser = await auth.createUser({
      email: driverEmail,
      password: PASSWORD,
      displayName: userData.fullName,
      emailVerified: true
    });

    // Crear en colección users
    await db.collection('users').doc(driverUser.uid).set({
      ...userData,
      email: driverEmail,
      userType: 'driver',
      uid: driverUser.uid,
      isAvailable: false,
      vehicleInfo: {
        brand: 'Toyota',
        model: 'Corolla',
        year: 2020,
        plate: 'ABC-123',
        color: 'Blanco',
        type: 'sedan'
      }
    });

    // Crear perfil de conductor en colección drivers
    await db.collection('drivers').doc(driverUser.uid).set({
      userId: driverUser.uid,
      name: userData.fullName,
      email: driverEmail,
      phone: userData.phone,
      isVerified: true, // Pre-verificado
      verificationStatus: 'approved',
      verificationDate: admin.firestore.FieldValue.serverTimestamp(),
      rating: 5.0,
      totalTrips: 0,
      memberSince: admin.firestore.FieldValue.serverTimestamp(),
      vehicle: {
        brand: 'Toyota',
        model: 'Corolla',
        year: 2020,
        plate: 'ABC-123',
        color: 'Blanco',
        type: 'sedan'
      }
    });

    // Crear documentos PRE-APROBADOS para el conductor
    const documentTypes = [
      { type: 'license', displayName: 'Licencia de Conducir' },
      { type: 'dni', displayName: 'DNI' },
      { type: 'criminal_record', displayName: 'Antecedentes Penales' },
      { type: 'vehicle_card', displayName: 'Tarjeta de Propiedad' },
      { type: 'soat', displayName: 'SOAT' },
      { type: 'technical_review', displayName: 'Revisión Técnica' },
      { type: 'vehicle_photo_front', displayName: 'Foto Frontal del Vehículo' },
      { type: 'vehicle_photo_back', displayName: 'Foto Posterior del Vehículo' },
      { type: 'vehicle_photo_plate', displayName: 'Foto de la Placa' },
      { type: 'vehicle_photo_interior', displayName: 'Foto Interior del Vehículo' },
      { type: 'bank_account', displayName: 'Cuenta Bancaria' }
    ];

    const batch = db.batch();
    for (const doc of documentTypes) {
      const docRef = db.collection('drivers').doc(driverUser.uid).collection('documents').doc(doc.type);
      batch.set(docRef, {
        type: doc.type,
        displayName: doc.displayName,
        status: 'approved', // Pre-aprobados
        url: `https://example.com/docs/${doc.type}.jpg`, // URL de ejemplo
        fileName: `${doc.type}.jpg`,
        uploadedAt: admin.firestore.FieldValue.serverTimestamp(),
        reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        reviewedBy: 'system',
        verificationComments: 'Documento pre-verificado para pruebas',
        expiryDate: doc.type === 'soat' || doc.type === 'technical_review' 
          ? admin.firestore.Timestamp.fromDate(new Date('2025-12-31'))
          : null,
        rejectionReason: null,
        metadata: {
          verified: true,
          preApproved: true
        }
      });
    }
    await batch.commit();

    console.log(`✅ Usuario CONDUCTOR creado:`);
    console.log(`   - UID: ${driverUser.uid}`);
    console.log(`   - Email: ${driverEmail}`);
    console.log(`   - Password: ${PASSWORD}`);
    console.log(`   - Documentos: PRE-APROBADOS`);
    console.log('----------------------------------------');

    // 3. CREAR USUARIO ADMINISTRADOR
    console.log('👨‍💼 [3/3] Creando usuario ADMINISTRADOR...');
    const adminEmail = 'Lepereza+admin@ucvvirtual.edu.pe';
    const adminUser = await auth.createUser({
      email: adminEmail,
      password: PASSWORD,
      displayName: userData.fullName,
      emailVerified: true
    });

    await db.collection('users').doc(adminUser.uid).set({
      ...userData,
      email: adminEmail,
      userType: 'admin',
      uid: adminUser.uid,
      twoFactorEnabled: true, // 2FA habilitado
      adminPermissions: {
        manageDrivers: true,
        manageRides: true,
        manageUsers: true,
        viewAnalytics: true,
        systemSettings: true,
        all: true
      },
      lastLoginAt: null
    });

    console.log(`✅ Usuario ADMINISTRADOR creado:`);
    console.log(`   - UID: ${adminUser.uid}`);
    console.log(`   - Email: ${adminEmail}`);
    console.log(`   - Password: ${PASSWORD}`);
    console.log(`   - 2FA: HABILITADO`);
    console.log('----------------------------------------');

    console.log('\n🎉 ¡TODOS LOS USUARIOS CREADOS EXITOSAMENTE!');
    console.log('\n📝 RESUMEN DE CREDENCIALES:');
    console.log('═'.repeat(60));
    console.log('\n👤 USUARIO PASAJERO:');
    console.log(`   Email: ${userData.email}`);
    console.log(`   Password: ${PASSWORD}`);
    console.log(`   Teléfono: +51${userData.phone}`);
    console.log(`   UID: ${passengerUser.uid}`);
    console.log();
    console.log('🚗 USUARIO CONDUCTOR:');
    console.log(`   Email: ${driverEmail}`);
    console.log(`   Password: ${PASSWORD}`);
    console.log(`   Teléfono: +51${userData.phone}`);
    console.log(`   UID: ${driverUser.uid}`);
    console.log(`   Estado: VERIFICADO con documentos pre-aprobados`);
    console.log(`   Vehículo: Toyota Corolla 2020 - ABC-123`);
    console.log();
    console.log('👨‍💼 USUARIO ADMINISTRADOR:');
    console.log(`   Email: ${adminEmail}`);
    console.log(`   Password: ${PASSWORD}`);
    console.log(`   Teléfono: +51${userData.phone}`);
    console.log(`   UID: ${adminUser.uid}`);
    console.log(`   2FA: HABILITADO (usar teléfono para verificación)`);
    console.log('═'.repeat(60));
    console.log('\n✨ Sistema 100% funcional con usuarios reales.');
    console.log('🔒 Guarda estas credenciales de forma segura.');

  } catch (error) {
    console.error('❌ Error creando usuarios:', error);
    if (error.code === 'auth/email-already-exists') {
      console.log('ℹ️  Algunos usuarios ya existen. Ejecuta primero el modo limpiar.');
    }
    throw error;
  }
}

// Función principal con opciones
async function main() {
  const args = process.argv.slice(2);
  const command = args[0];
  
  console.log('\n🌊 OASIS TAXI - GESTIÓN DE USUARIOS');
  console.log('========================================\n');
  
  try {
    if (command === 'clean') {
      await cleanDatabase();
    } else if (command === 'create') {
      await createThreeUsers();
    } else if (command === 'reset') {
      console.log('🔄 Reiniciando todo el sistema...');
      await cleanDatabase();
      console.log('\n⏳ Esperando 3 segundos...\n');
      await new Promise(resolve => setTimeout(resolve, 3000));
      await createThreeUsers();
    } else {
      console.log('📖 USO:');
      console.log('  node create_users.js clean   - Limpiar toda la base de datos');
      console.log('  node create_users.js create  - Crear los 3 usuarios específicos');
      console.log('  node create_users.js reset   - Limpiar y crear (recomendado)');
      console.log('\n💡 Recomendación: usa "reset" para empezar con una base limpia');
    }
  } catch (error) {
    console.error('\n💥 Error fatal:', error);
    process.exit(1);
  }
  
  console.log('\n🔚 Proceso completado.');
  process.exit(0);
}

// Ejecutar
main();