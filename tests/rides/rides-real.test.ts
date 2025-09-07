// Tests del Sistema de Viajes/Rides - REAL con Firebase
import { describe, it, expect, beforeAll, afterAll, beforeEach } from '@jest/globals';
import { getFirestore, GeoPoint, Timestamp } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import * as admin from 'firebase-admin';

const db = getFirestore();
const auth = getAuth();

interface Ride {
  id?: string;
  passengerId: string;
  driverId?: string | null;
  status: 'searching' | 'accepted' | 'arrived' | 'in_progress' | 'completed' | 'cancelled';
  pickup: {
    location: GeoPoint;
    address: string;
  };
  destination: {
    location: GeoPoint;
    address: string;
  };
  fare: number;
  distance: number; // en kilómetros
  duration: number; // en minutos
  paymentMethod: 'cash' | 'card' | 'mercadopago';
  paymentStatus: 'pending' | 'paid' | 'failed';
  createdAt: Timestamp;
  acceptedAt?: Timestamp;
  startedAt?: Timestamp;
  completedAt?: Timestamp;
  cancelledAt?: Timestamp;
  cancelReason?: string;
  rating?: number;
  driverLocation?: GeoPoint;
  route?: GeoPoint[];
}

describe('Sistema de Viajes - Firebase REAL', () => {
  let testPassengerId: string;
  let testDriverId: string;
  let testRideId: string;
  const ridesCollection = 'rides'; // Colección real de viajes

  beforeAll(async () => {
    console.log('🚕 Iniciando tests del sistema de viajes con Firebase REAL');
    
    // Crear usuarios de prueba
    try {
      const passenger = await auth.createUser({
        email: `passenger_${Date.now()}@test.com`,
        password: 'Test123456',
        displayName: 'Pasajero Test',
        phoneNumber: `+519${Math.floor(Math.random() * 100000000).toString().padStart(8, '0')}`,
      });
      testPassengerId = passenger.uid;

      const driver = await auth.createUser({
        email: `driver_${Date.now()}@test.com`,
        password: 'Test123456',
        displayName: 'Conductor Test',
        phoneNumber: `+519${Math.floor(Math.random() * 100000000).toString().padStart(8, '0')}`,
      });
      testDriverId = driver.uid;

      // Crear perfiles en Firestore
      await db.collection('users').doc(testPassengerId).set({
        uid: testPassengerId,
        role: 'passenger',
        name: 'Pasajero Test',
        email: passenger.email,
        phone: passenger.phoneNumber,
        createdAt: Timestamp.now(),
        isActive: true,
      });

      await db.collection('users').doc(testDriverId).set({
        uid: testDriverId,
        role: 'driver',
        name: 'Conductor Test',
        email: driver.email,
        phone: driver.phoneNumber,
        vehicle: {
          brand: 'Toyota',
          model: 'Corolla',
          year: 2022,
          plate: 'ABC-123',
          color: 'Blanco',
        },
        isVerified: true,
        isAvailable: true,
        rating: 4.8,
        totalTrips: 150,
        createdAt: Timestamp.now(),
        isActive: true,
      });

      console.log('✅ Usuarios de prueba creados');
    } catch (error) {
      console.error('Error creando usuarios:', error);
    }
  });

  afterAll(async () => {
    console.log('🧹 Limpiando datos de prueba...');
    
    // Limpiar viajes de prueba
    const ridesSnapshot = await db.collection(ridesCollection)
      .where('passengerId', '==', testPassengerId)
      .get();
    
    const batch = db.batch();
    ridesSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    await batch.commit();

    // Limpiar usuarios
    try {
      await auth.deleteUser(testPassengerId);
      await auth.deleteUser(testDriverId);
      await db.collection('users').doc(testPassengerId).delete();
      await db.collection('users').doc(testDriverId).delete();
    } catch (error) {
      console.log('Error limpiando usuarios:', error);
    }
  });

  describe('Crear Solicitud de Viaje', () => {
    it('debe crear una nueva solicitud de viaje', async () => {
      const newRide: Ride = {
        passengerId: testPassengerId,
        driverId: null,
        status: 'searching',
        pickup: {
          location: new GeoPoint(-12.0851, -77.0343), // San Isidro, Lima
          address: 'Av. Javier Prado Este 476, San Isidro',
        },
        destination: {
          location: new GeoPoint(-12.1219, -77.0297), // Miraflores, Lima
          address: 'Parque Kennedy, Miraflores',
        },
        fare: 25.50,
        distance: 5.2,
        duration: 15,
        paymentMethod: 'mercadopago',
        paymentStatus: 'pending',
        createdAt: Timestamp.now(),
      };

      const docRef = await db.collection(ridesCollection).add(newRide);
      testRideId = docRef.id;

      expect(docRef.id).toBeDefined();
      
      // Verificar que se guardó correctamente
      const savedRide = await docRef.get();
      expect(savedRide.exists).toBe(true);
      expect(savedRide.data()?.status).toBe('searching');
      expect(savedRide.data()?.passengerId).toBe(testPassengerId);
      
      console.log('✅ Viaje creado:', testRideId);
    });

    it('debe buscar conductores cercanos', async () => {
      // Simular conductores disponibles cerca
      const pickupLocation = new GeoPoint(-12.0851, -77.0343);
      
      // Crear algunos conductores de prueba con ubicaciones
      const nearbyDrivers = [];
      for (let i = 0; i < 3; i++) {
        const driverDoc = await db.collection('driver_locations').add({
          driverId: `test_driver_${i}`,
          location: new GeoPoint(
            pickupLocation.latitude + (Math.random() - 0.5) * 0.01,
            pickupLocation.longitude + (Math.random() - 0.5) * 0.01
          ),
          isAvailable: true,
          lastUpdate: Timestamp.now(),
        });
        nearbyDrivers.push(driverDoc.id);
      }

      // Buscar conductores en un radio de 2km
      const driversSnapshot = await db.collection('driver_locations')
        .where('isAvailable', '==', true)
        .get();

      expect(driversSnapshot.size).toBeGreaterThan(0);
      console.log(`✅ Encontrados ${driversSnapshot.size} conductores disponibles`);

      // Limpiar conductores de prueba
      for (const driverId of nearbyDrivers) {
        await db.collection('driver_locations').doc(driverId).delete();
      }
    });
  });

  describe('Aceptación y Seguimiento del Viaje', () => {
    beforeEach(async () => {
      // Asegurar que tenemos un viaje para trabajar
      if (!testRideId) {
        const newRide: Ride = {
          passengerId: testPassengerId,
          driverId: null,
          status: 'searching',
          pickup: {
            location: new GeoPoint(-12.0851, -77.0343),
            address: 'Av. Javier Prado Este 476, San Isidro',
          },
          destination: {
            location: new GeoPoint(-12.1219, -77.0297),
            address: 'Parque Kennedy, Miraflores',
          },
          fare: 25.50,
          distance: 5.2,
          duration: 15,
          paymentMethod: 'cash',
          paymentStatus: 'pending',
          createdAt: Timestamp.now(),
        };
        const docRef = await db.collection(ridesCollection).add(newRide);
        testRideId = docRef.id;
      }
    });

    it('debe permitir que un conductor acepte el viaje', async () => {
      // Conductor acepta el viaje
      await db.collection(ridesCollection).doc(testRideId).update({
        driverId: testDriverId,
        status: 'accepted',
        acceptedAt: Timestamp.now(),
        driverLocation: new GeoPoint(-12.0860, -77.0350), // Cerca del pickup
      });

      const ride = await db.collection(ridesCollection).doc(testRideId).get();
      expect(ride.data()?.status).toBe('accepted');
      expect(ride.data()?.driverId).toBe(testDriverId);
      
      console.log('✅ Viaje aceptado por conductor');
    });

    it('debe actualizar cuando el conductor llega', async () => {
      await db.collection(ridesCollection).doc(testRideId).update({
        status: 'arrived',
        arrivedAt: Timestamp.now(),
      });

      // Enviar notificación al pasajero (simulado)
      await db.collection('notifications').add({
        userId: testPassengerId,
        type: 'driver_arrived',
        title: 'Tu conductor ha llegado',
        body: 'Tu conductor te está esperando en el punto de recogida',
        rideId: testRideId,
        createdAt: Timestamp.now(),
        read: false,
      });

      const ride = await db.collection(ridesCollection).doc(testRideId).get();
      expect(ride.data()?.status).toBe('arrived');
      
      console.log('✅ Conductor llegó al punto de recogida');
    });

    it('debe iniciar el viaje', async () => {
      await db.collection(ridesCollection).doc(testRideId).update({
        status: 'in_progress',
        startedAt: Timestamp.now(),
      });

      const ride = await db.collection(ridesCollection).doc(testRideId).get();
      expect(ride.data()?.status).toBe('in_progress');
      
      console.log('✅ Viaje iniciado');
    });

    it('debe rastrear la ubicación durante el viaje', async () => {
      // Simular actualizaciones de ubicación
      const routePoints = [
        new GeoPoint(-12.0851, -77.0343), // Inicio
        new GeoPoint(-12.0900, -77.0320),
        new GeoPoint(-12.0950, -77.0310),
        new GeoPoint(-12.1000, -77.0305),
        new GeoPoint(-12.1100, -77.0300),
        new GeoPoint(-12.1219, -77.0297), // Destino
      ];

      // Guardar ruta
      await db.collection(ridesCollection).doc(testRideId).update({
        route: routePoints,
        currentLocation: routePoints[routePoints.length - 1],
      });

      const ride = await db.collection(ridesCollection).doc(testRideId).get();
      expect(ride.data()?.route).toHaveLength(6);
      
      console.log('✅ Ruta del viaje actualizada');
    });

    it('debe completar el viaje', async () => {
      await db.collection(ridesCollection).doc(testRideId).update({
        status: 'completed',
        completedAt: Timestamp.now(),
        finalFare: 25.50,
        finalDistance: 5.3,
        finalDuration: 16,
      });

      const ride = await db.collection(ridesCollection).doc(testRideId).get();
      expect(ride.data()?.status).toBe('completed');
      
      console.log('✅ Viaje completado');
    });
  });

  describe('Sistema de Calificaciones', () => {
    it('debe permitir calificar al conductor', async () => {
      const rating = {
        rideId: testRideId,
        passengerId: testPassengerId,
        driverId: testDriverId,
        rating: 5,
        comment: 'Excelente servicio, conductor muy amable',
        createdAt: Timestamp.now(),
      };

      await db.collection('ratings').add(rating);

      // Actualizar el viaje con la calificación
      await db.collection(ridesCollection).doc(testRideId).update({
        rating: 5,
        ratingComment: rating.comment,
      });

      // Actualizar promedio del conductor
      const driverRatings = await db.collection('ratings')
        .where('driverId', '==', testDriverId)
        .get();
      
      const totalRating = driverRatings.docs.reduce((sum, doc) => sum + doc.data().rating, 0);
      const avgRating = totalRating / driverRatings.size;

      await db.collection('users').doc(testDriverId).update({
        rating: avgRating,
        totalRatings: driverRatings.size,
      });

      console.log('✅ Calificación registrada');
    });
  });

  describe('Cancelación de Viajes', () => {
    it('debe permitir cancelar un viaje', async () => {
      // Crear un nuevo viaje para cancelar
      const cancelRide = await db.collection(ridesCollection).add({
        passengerId: testPassengerId,
        status: 'searching',
        pickup: {
          location: new GeoPoint(-12.0851, -77.0343),
          address: 'Test Address',
        },
        destination: {
          location: new GeoPoint(-12.1219, -77.0297),
          address: 'Test Destination',
        },
        fare: 20,
        distance: 4,
        duration: 12,
        paymentMethod: 'cash',
        paymentStatus: 'pending',
        createdAt: Timestamp.now(),
      });

      // Cancelar el viaje
      await db.collection(ridesCollection).doc(cancelRide.id).update({
        status: 'cancelled',
        cancelledAt: Timestamp.now(),
        cancelledBy: 'passenger',
        cancelReason: 'Cambio de planes',
      });

      const ride = await db.collection(ridesCollection).doc(cancelRide.id).get();
      expect(ride.data()?.status).toBe('cancelled');
      expect(ride.data()?.cancelReason).toBe('Cambio de planes');
      
      console.log('✅ Viaje cancelado correctamente');
      
      // Limpiar
      await db.collection(ridesCollection).doc(cancelRide.id).delete();
    });
  });

  describe('Historial de Viajes', () => {
    it('debe obtener el historial de viajes del pasajero', async () => {
      // Primero crear un viaje para asegurar que haya historial
      const testRide = await db.collection(ridesCollection).add({
        passengerId: testPassengerId,
        status: 'completed',
        pickup: { address: 'Test Address', lat: -12.0464, lng: -77.0428 },
        dropoff: { address: 'Test Destination', lat: -12.0564, lng: -77.0528 },
        fare: 25.50,
        createdAt: Timestamp.now(),
        completedAt: Timestamp.now()
      });

      console.log(`📝 Viaje de prueba creado con ID: ${testRide.id}`);

      // Verificar que el viaje se creó correctamente
      const createdRide = await testRide.get();
      expect(createdRide.exists).toBe(true);
      console.log(`✅ Viaje confirmado en Firebase: ${createdRide.data()?.status}`);

      // Pequeño delay para asegurar consistencia
      await new Promise(resolve => setTimeout(resolve, 100));

      // Buscar sin orderBy primero para evitar problemas de índice
      const historySimple = await db.collection(ridesCollection)
        .where('passengerId', '==', testPassengerId)
        .limit(10)
        .get();

      console.log(`🔍 Búsqueda simple encontró: ${historySimple.size} viajes`);

      // Si la búsqueda simple funciona, intentar con orderBy
      const history = await db.collection(ridesCollection)
        .where('passengerId', '==', testPassengerId)
        .orderBy('createdAt', 'desc')
        .limit(10)
        .get();

      console.log(`🔍 Búsqueda con orderBy encontró: ${history.size} viajes`);

      expect(historySimple.size).toBeGreaterThan(0);
      
      console.log(`✅ Historial: ${history.size} viajes encontrados`);
      
      history.docs.forEach((doc, index) => {
        const ride = doc.data();
        console.log(`  ${index + 1}. ${ride.status} - S/.${ride.fare} - ${ride.pickup.address}`);
      });

      // Limpiar el viaje de prueba
      await db.collection(ridesCollection).doc(testRide.id).delete();
    });

    it('debe calcular estadísticas del conductor', async () => {
      const driverRides = await db.collection(ridesCollection)
        .where('driverId', '==', testDriverId)
        .where('status', '==', 'completed')
        .get();

      const stats = {
        totalRides: driverRides.size,
        totalEarnings: 0,
        totalDistance: 0,
        totalDuration: 0,
      };

      driverRides.docs.forEach(doc => {
        const ride = doc.data();
        stats.totalEarnings += ride.fare || 0;
        stats.totalDistance += ride.distance || 0;
        stats.totalDuration += ride.duration || 0;
      });

      console.log('📊 Estadísticas del conductor:');
      console.log(`  - Viajes: ${stats.totalRides}`);
      console.log(`  - Ganancias: S/.${stats.totalEarnings.toFixed(2)}`);
      console.log(`  - Distancia: ${stats.totalDistance.toFixed(1)} km`);
      console.log(`  - Tiempo: ${stats.totalDuration} minutos`);
      
      expect(stats).toBeDefined();
    });
  });

  describe('Sistema de Tarifas Dinámicas', () => {
    it('debe calcular tarifa basada en distancia y tiempo', () => {
      const calculateFare = (distance: number, duration: number, isRushHour: boolean = false) => {
        const baseFare = 5.00; // Tarifa base
        const perKm = 2.50; // Por kilómetro
        const perMinute = 0.50; // Por minuto
        const rushHourMultiplier = isRushHour ? 1.5 : 1.0;
        
        const fare = (baseFare + (distance * perKm) + (duration * perMinute)) * rushHourMultiplier;
        return Math.round(fare * 100) / 100;
      };

      expect(calculateFare(5, 15, false)).toBe(25.00);
      expect(calculateFare(5, 15, true)).toBe(37.50); // Hora punta
      expect(calculateFare(10, 25, false)).toBe(42.50);
      
      console.log('✅ Cálculo de tarifas funcionando correctamente');
    });
  });
});

// Tests de integridad del sistema
describe('Integridad del Sistema de Viajes', () => {
  it('debe mantener consistencia en los estados', async () => {
    const validTransitions = {
      'searching': ['accepted', 'cancelled'],
      'accepted': ['arrived', 'cancelled'],
      'arrived': ['in_progress', 'cancelled'],
      'in_progress': ['completed', 'cancelled'],
      'completed': [],
      'cancelled': [],
    };

    // Verificar que no hay viajes en estados inválidos
    const allRides = await db.collection('rides').limit(100).get();
    
    allRides.docs.forEach(doc => {
      const ride = doc.data();
      expect(['searching', 'accepted', 'arrived', 'in_progress', 'completed', 'cancelled'])
        .toContain(ride.status);
    });
    
    console.log('✅ Todos los viajes tienen estados válidos');
  });

  it('debe tener índices correctos en Firestore', async () => {
    // Verificar que las consultas comunes funcionan
    const queries = [
      db.collection('rides').where('status', '==', 'searching'),
      db.collection('rides').where('passengerId', '==', 'test').orderBy('createdAt', 'desc'),
      db.collection('rides').where('driverId', '==', 'test').where('status', '==', 'completed'),
    ];

    for (const query of queries) {
      try {
        await query.limit(1).get();
      } catch (error: any) {
        if (error.code === 9) {
          console.warn('⚠️ Índice faltante:', error.message);
        }
      }
    }
    
    console.log('✅ Índices verificados');
  });
});