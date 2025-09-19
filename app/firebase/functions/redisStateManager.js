// ====================================================================
// 🚀 REDIS STATE MANAGER - CLOUD FUNCTIONS OASISTAXI
// ====================================================================
// Gestión avanzada de estado en tiempo real con Redis Memory Store
// Funciones optimizadas para Perú con alta concurrencia
// ====================================================================

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const redis = require('redis');
const { v4: uuidv4 } = require('uuid');

// Configuración para región de Perú
const runtimeOpts = {
  timeoutSeconds: 540,
  memory: '2GB',
  maxInstances: 100,
};

// ====================================================================
// 🔧 CONFIGURACIÓN REDIS PARA PERÚ
// ====================================================================

class RedisStateManager {
  constructor() {
    this.client = null;
    this.isConnected = false;
    this.connectionAttempts = 0;
    this.maxRetries = 5;
    
    // Configuración específica para Perú
    this.config = {
      host: process.env.REDIS_HOST || 'localhost',
      port: process.env.REDIS_PORT || 6379,
      password: process.env.REDIS_PASSWORD || 'OasisTaxiPeru2024Redis!@#',
      database: 0,
      retryDelayOnFailover: 100,
      maxRetriesPerRequest: 3,
      lazyConnect: true,
      keepAlive: 30000,
      family: 4,
      connectTimeout: 10000,
      commandTimeout: 5000,
    };

    // TTL configurations (segundos)
    this.ttl = {
      driverActive: 300,      // 5 minutos
      driverLocation: 60,     // 1 minuto
      driverStatus: 600,      // 10 minutos
      rideRequest: 900,       // 15 minutos
      rideMatching: 180,      // 3 minutos
      negotiation: 600,       // 10 minutos
      pricing: 1800,          // 30 minutos
      surge: 300,             // 5 minutos
      chatSession: 7200,      // 2 horas
      analytics: 3600,        // 1 hora
    };

    // Prefijos para organizar keys
    this.keys = {
      driver: 'oasis:driver:',
      ride: 'oasis:ride:',
      negotiation: 'oasis:negotiation:',
      pricing: 'oasis:pricing:',
      chat: 'oasis:chat:',
      analytics: 'oasis:analytics:',
      location: 'oasis:location:',
      session: 'oasis:session:',
      queue: 'oasis:queue:',
      lock: 'oasis:lock:',
    };
  }

  // ====================================================================
  // 🔌 CONEXIÓN Y GESTIÓN
  // ====================================================================

  async connect() {
    if (this.isConnected && this.client) {
      return this.client;
    }

    try {
      this.client = redis.createClient(this.config);
      
      this.client.on('error', (err) => {
        console.error('❌ Redis connection error:', err);
        this.isConnected = false;
      });

      this.client.on('connect', () => {
        console.log('🔄 Connecting to Redis...');
      });

      this.client.on('ready', () => {
        console.log('✅ Redis connected successfully');
        this.isConnected = true;
        this.connectionAttempts = 0;
      });

      this.client.on('end', () => {
        console.log('🔌 Redis connection closed');
        this.isConnected = false;
      });

      await this.client.connect();
      return this.client;

    } catch (error) {
      console.error('❌ Failed to connect to Redis:', error);
      this.connectionAttempts++;
      
      if (this.connectionAttempts < this.maxRetries) {
        const delay = Math.pow(2, this.connectionAttempts) * 1000;
        console.log(`⏳ Retrying connection in ${delay}ms...`);
        
        await new Promise(resolve => setTimeout(resolve, delay));
        return this.connect();
      }
      
      throw new Error(`Failed to connect to Redis after ${this.maxRetries} attempts`);
    }
  }

  async disconnect() {
    if (this.client) {
      await this.client.quit();
      this.client = null;
      this.isConnected = false;
    }
  }

  async ensureConnection() {
    if (!this.isConnected || !this.client) {
      await this.connect();
    }
    return this.client;
  }

  // ====================================================================
  // 🚗 GESTIÓN DE CONDUCTORES
  // ====================================================================

  async setDriverActive(driverId, locationData) {
    const client = await this.ensureConnection();
    const timestamp = new Date().toISOString();
    
    const driverData = {
      id: driverId,
      status: 'active',
      latitude: locationData.latitude,
      longitude: locationData.longitude,
      lastUpdate: timestamp,
      country: 'PE',
      timezone: 'America/Lima',
      vehicleType: locationData.vehicleType || 'standard',
      rating: locationData.rating || 0,
      completedTrips: locationData.completedTrips || 0,
      ...locationData.metadata
    };

    const pipeline = client.multi();
    
    // Estado activo del conductor
    pipeline.setEx(
      `${this.keys.driver}active:${driverId}`,
      this.ttl.driverActive,
      JSON.stringify(driverData)
    );

    // Ubicación para búsquedas geográficas
    pipeline.geoAdd(
      `${this.keys.location}drivers:active`,
      {
        longitude: locationData.longitude,
        latitude: locationData.latitude,
        member: driverId
      }
    );

    // Estado general con TTL mayor
    pipeline.setEx(
      `${this.keys.driver}status:${driverId}`,
      this.ttl.driverStatus,
      JSON.stringify({
        status: 'active',
        lastSeen: timestamp
      })
    );

    // Set de conductores activos
    pipeline.sAdd(`${this.keys.driver}active_set`, driverId);

    // Métricas
    pipeline.incrBy(`${this.keys.analytics}drivers_active_count`, 1);
    pipeline.expire(`${this.keys.analytics}drivers_active_count`, this.ttl.analytics);

    const results = await pipeline.exec();
    
    // Log para monitoreo
    console.log(`🚗 Driver ${driverId} set as active at (${locationData.latitude}, ${locationData.longitude})`);
    
    return results.every(result => result[0] === null);
  }

  async getNearbyDrivers(latitude, longitude, radiusKm = 5, limit = 20, filters = {}) {
    const client = await this.ensureConnection();
    
    try {
      // Búsqueda geográfica
      const nearbyDriverIds = await client.geoRadius(
        `${this.keys.location}drivers:active`,
        { longitude, latitude },
        radiusKm,
        'km',
        {
          WITHDIST: true,
          WITHCOORD: true,
          COUNT: limit,
          SORT: 'ASC'
        }
      );

      if (!nearbyDriverIds || nearbyDriverIds.length === 0) {
        return [];
      }

      // Obtener datos completos de conductores
      const drivers = [];
      for (const result of nearbyDriverIds) {
        const driverId = result.member;
        const distance = parseFloat(result.distance);
        
        const driverData = await client.get(`${this.keys.driver}active:${driverId}`);
        if (driverData) {
          const driver = JSON.parse(driverData);
          
          // Aplicar filtros
          if (this._matchesFilters(driver, filters)) {
            drivers.push({
              ...driver,
              driverId,
              distance,
              estimatedArrival: this._calculateETA(distance)
            });
          }
        }
      }

      // Ordenar por criterios de calidad
      drivers.sort((a, b) => {
        const scoreA = this._calculateDriverScore(a);
        const scoreB = this._calculateDriverScore(b);
        return scoreB - scoreA;
      });

      console.log(`🔍 Found ${drivers.length} nearby drivers`);
      return drivers;

    } catch (error) {
      console.error('❌ Error finding nearby drivers:', error);
      return [];
    }
  }

  async setDriverOffline(driverId, reason = 'manual') {
    const client = await this.ensureConnection();
    const timestamp = new Date().toISOString();

    const pipeline = client.multi();

    // Eliminar de activos
    pipeline.del(`${this.keys.driver}active:${driverId}`);
    
    // Eliminar de geolocalización
    pipeline.zRem(`${this.keys.location}drivers:active`, driverId);
    
    // Remover de set activo
    pipeline.sRem(`${this.keys.driver}active_set`, driverId);
    
    // Actualizar estado a offline
    pipeline.setEx(
      `${this.keys.driver}status:${driverId}`,
      this.ttl.driverStatus,
      JSON.stringify({
        status: 'offline',
        lastSeen: timestamp,
        reason
      })
    );

    // Métricas
    pipeline.decrBy(`${this.keys.analytics}drivers_active_count`, 1);

    await pipeline.exec();

    console.log(`🚗 Driver ${driverId} set offline (${reason})`);
    return true;
  }

  // ====================================================================
  // 🚖 GESTIÓN DE SOLICITUDES DE VIAJE
  // ====================================================================

  async createRideRequest(requestData) {
    const client = await this.ensureConnection();
    const timestamp = new Date().toISOString();
    const requestId = requestData.id || uuidv4();

    const rideData = {
      id: requestId,
      passengerId: requestData.passengerId,
      pickup: requestData.pickup,
      destination: requestData.destination,
      estimatedPrice: requestData.estimatedPrice,
      vehicleType: requestData.vehicleType || 'standard',
      status: 'searching',
      createdAt: timestamp,
      expiresAt: new Date(Date.now() + this.ttl.rideRequest * 1000).toISOString(),
      country: 'PE',
      currency: 'PEN',
      priority: requestData.priority || 'normal',
      ...requestData.metadata
    };

    const pipeline = client.multi();

    // Almacenar solicitud
    pipeline.setEx(
      `${this.keys.ride}request:${requestId}`,
      this.ttl.rideRequest,
      JSON.stringify(rideData)
    );

    // Cola de matching por prioridad
    const queueKey = requestData.priority === 'high' 
      ? `${this.keys.queue}matching:high`
      : `${this.keys.queue}matching:normal`;
    
    pipeline.lPush(queueKey, requestId);

    // Set de solicitudes activas
    pipeline.sAdd(`${this.keys.ride}active_requests`, requestId);

    // Índice por pasajero
    pipeline.setEx(
      `${this.keys.ride}by_passenger:${requestData.passengerId}`,
      this.ttl.rideRequest,
      requestId
    );

    // Métricas
    pipeline.incr(`${this.keys.analytics}ride_requests_count`);
    pipeline.expire(`${this.keys.analytics}ride_requests_count`, this.ttl.analytics);

    await pipeline.exec();

    // Trigger matching process
    await this._triggerRideMatching(requestId, rideData);

    console.log(`🚖 Ride request ${requestId} created`);
    return { requestId, ...rideData };
  }

  async updateRideStatus(requestId, status, updateData = {}) {
    const client = await this.ensureConnection();
    
    const currentDataStr = await client.get(`${this.keys.ride}request:${requestId}`);
    if (!currentDataStr) {
      throw new Error(`Ride request ${requestId} not found`);
    }

    const currentData = JSON.parse(currentDataStr);
    const updatedData = {
      ...currentData,
      status,
      lastUpdate: new Date().toISOString(),
      ...updateData
    };

    await client.setEx(
      `${this.keys.ride}request:${requestId}`,
      this.ttl.rideRequest,
      JSON.stringify(updatedData)
    );

    // Remover de colas si se completa o cancela
    if (['completed', 'cancelled'].includes(status)) {
      const pipeline = client.multi();
      pipeline.sRem(`${this.keys.ride}active_requests`, requestId);
      pipeline.lRem(`${this.keys.queue}matching:normal`, 1, requestId);
      pipeline.lRem(`${this.keys.queue}matching:high`, 1, requestId);
      await pipeline.exec();
    }

    // Métricas por estado
    await client.incr(`${this.keys.analytics}rides_${status}_count`);
    await client.expire(`${this.keys.analytics}rides_${status}_count`, this.ttl.analytics);

    console.log(`🚖 Ride ${requestId} status updated to ${status}`);
    return updatedData;
  }

  // ====================================================================
  // 💰 SISTEMA DE NEGOCIACIÓN DE PRECIOS
  // ====================================================================

  async createPriceNegotiation(negotiationData) {
    const client = await this.ensureConnection();
    const negotiationId = negotiationData.id || uuidv4();
    const timestamp = new Date().toISOString();

    const data = {
      id: negotiationId,
      requestId: negotiationData.requestId,
      driverId: negotiationData.driverId,
      passengerId: negotiationData.passengerId,
      originalPrice: negotiationData.originalPrice,
      proposedPrice: negotiationData.proposedPrice,
      status: 'pending',
      createdAt: timestamp,
      expiresAt: new Date(Date.now() + this.ttl.negotiation * 1000).toISOString(),
      country: 'PE',
      currency: 'PEN',
      rounds: 1,
      ...negotiationData.metadata
    };

    const pipeline = client.multi();

    // Negociación principal
    pipeline.setEx(
      `${this.keys.negotiation}${negotiationId}`,
      this.ttl.negotiation,
      JSON.stringify(data)
    );

    // Índices para búsqueda rápida
    pipeline.setEx(
      `${this.keys.negotiation}by_request:${negotiationData.requestId}:${negotiationData.driverId}`,
      this.ttl.negotiation,
      negotiationId
    );

    pipeline.setEx(
      `${this.keys.negotiation}by_driver:${negotiationData.driverId}`,
      this.ttl.negotiation,
      negotiationId
    );

    // Set de negociaciones activas
    pipeline.sAdd(`${this.keys.negotiation}active`, negotiationId);

    // Métricas
    pipeline.incr(`${this.keys.analytics}negotiations_created_count`);
    pipeline.expire(`${this.keys.analytics}negotiations_created_count`, this.ttl.analytics);

    await pipeline.exec();

    // Programar expiración automática
    setTimeout(async () => {
      await this._expireNegotiation(negotiationId);
    }, this.ttl.negotiation * 1000);

    console.log(`💰 Price negotiation ${negotiationId} created`);
    return { negotiationId, ...data };
  }

  async updateNegotiationStatus(negotiationId, status, updateData = {}) {
    const client = await this.ensureConnection();
    
    const currentDataStr = await client.get(`${this.keys.negotiation}${negotiationId}`);
    if (!currentDataStr) {
      throw new Error(`Negotiation ${negotiationId} not found`);
    }

    const currentData = JSON.parse(currentDataStr);
    const updatedData = {
      ...currentData,
      status,
      updatedAt: new Date().toISOString(),
      ...updateData
    };

    await client.setEx(
      `${this.keys.negotiation}${negotiationId}`,
      this.ttl.negotiation,
      JSON.stringify(updatedData)
    );

    // Remover de activos si se finaliza
    if (['accepted', 'rejected', 'expired'].includes(status)) {
      await client.sRem(`${this.keys.negotiation}active`, negotiationId);
    }

    // Métricas por estado
    await client.incr(`${this.keys.analytics}negotiations_${status}_count`);
    await client.expire(`${this.keys.analytics}negotiations_${status}_count`, this.ttl.analytics);

    console.log(`💰 Negotiation ${negotiationId} updated to ${status}`);
    return updatedData;
  }

  // ====================================================================
  // 📊 PRICING DINÁMICO Y SURGE
  // ====================================================================

  async calculateSurgePrice(latitude, longitude, vehicleType = 'standard') {
    const client = await this.ensureConnection();
    const zoneKey = this._getZoneKey(latitude, longitude);
    
    try {
      // Obtener demanda actual en la zona
      const demandData = await client.hGetAll(`${this.keys.pricing}demand:${zoneKey}`);
      const supply = await this._getDriverSupplyInZone(zoneKey, vehicleType);
      
      const demand = parseInt(demandData.requests || '0');
      const surgeMultiplier = this._calculateSurgeMultiplier(demand, supply);
      
      const surgeData = {
        zone: zoneKey,
        vehicleType,
        demand,
        supply,
        surgeMultiplier,
        timestamp: new Date().toISOString(),
        expiresAt: new Date(Date.now() + this.ttl.surge * 1000).toISOString()
      };

      // Cache del surge pricing
      await client.setEx(
        `${this.keys.pricing}surge:${zoneKey}:${vehicleType}`,
        this.ttl.surge,
        JSON.stringify(surgeData)
      );

      console.log(`💱 Surge calculated for ${zoneKey}: ${surgeMultiplier}x`);
      return surgeData;

    } catch (error) {
      console.error('❌ Error calculating surge price:', error);
      return {
        surgeMultiplier: 1.0,
        error: error.message
      };
    }
  }

  async updateDemandMetrics(latitude, longitude, action) {
    const client = await this.ensureConnection();
    const zoneKey = this._getZoneKey(latitude, longitude);
    const timestamp = Math.floor(Date.now() / 1000);

    const pipeline = client.multi();

    if (action === 'request') {
      pipeline.hIncrBy(`${this.keys.pricing}demand:${zoneKey}`, 'requests', 1);
      pipeline.hSet(`${this.keys.pricing}demand:${zoneKey}`, 'lastRequest', timestamp);
    } else if (action === 'complete') {
      pipeline.hIncrBy(`${this.keys.pricing}demand:${zoneKey}`, 'completions', 1);
      pipeline.hSet(`${this.keys.pricing}demand:${zoneKey}`, 'lastCompletion', timestamp);
    }

    // TTL para datos de demanda
    pipeline.expire(`${this.keys.pricing}demand:${zoneKey}`, this.ttl.pricing);

    await pipeline.exec();
  }

  // ====================================================================
  // 💬 GESTIÓN DE CHAT EN TIEMPO REAL
  // ====================================================================

  async createChatSession(sessionData) {
    const client = await this.ensureConnection();
    const sessionId = sessionData.id || uuidv4();
    const timestamp = new Date().toISOString();

    const data = {
      id: sessionId,
      rideId: sessionData.rideId,
      passengerId: sessionData.passengerId,
      driverId: sessionData.driverId,
      status: 'active',
      createdAt: timestamp,
      lastActivity: timestamp,
      messageCount: 0,
      language: 'es',
      country: 'PE'
    };

    const pipeline = client.multi();

    // Sesión principal
    pipeline.setEx(
      `${this.keys.chat}session:${sessionId}`,
      this.ttl.chatSession,
      JSON.stringify(data)
    );

    // Índices
    pipeline.setEx(
      `${this.keys.chat}by_ride:${sessionData.rideId}`,
      this.ttl.chatSession,
      sessionId
    );

    pipeline.sAdd(`${this.keys.chat}active_sessions`, sessionId);

    await pipeline.exec();

    console.log(`💬 Chat session ${sessionId} created`);
    return { sessionId, ...data };
  }

  async updateChatActivity(sessionId, messageData = {}) {
    const client = await this.ensureConnection();
    
    const currentDataStr = await client.get(`${this.keys.chat}session:${sessionId}`);
    if (!currentDataStr) {
      return false;
    }

    const currentData = JSON.parse(currentDataStr);
    const updatedData = {
      ...currentData,
      lastActivity: new Date().toISOString(),
      messageCount: (currentData.messageCount || 0) + 1,
      ...messageData
    };

    await client.setEx(
      `${this.keys.chat}session:${sessionId}`,
      this.ttl.chatSession,
      JSON.stringify(updatedData)
    );

    return true;
  }

  // ====================================================================
  // 📈 ANALYTICS EN TIEMPO REAL
  // ====================================================================

  async recordEvent(eventName, eventData) {
    const client = await this.ensureConnection();
    const timestamp = new Date().toISOString();

    const event = {
      event: eventName,
      timestamp,
      data: eventData,
      country: 'PE'
    };

    const pipeline = client.multi();

    // Lista de eventos recientes
    pipeline.lPush(
      `${this.keys.analytics}events:${eventName}`,
      JSON.stringify(event)
    );

    // Mantener solo últimos 1000 eventos
    pipeline.lTrim(`${this.keys.analytics}events:${eventName}`, 0, 999);
    
    // TTL para limpieza automática
    pipeline.expire(`${this.keys.analytics}events:${eventName}`, this.ttl.analytics);

    // Contador del evento
    pipeline.incr(`${this.keys.analytics}counter:${eventName}`);
    pipeline.expire(`${this.keys.analytics}counter:${eventName}`, this.ttl.analytics);

    await pipeline.exec();

    return true;
  }

  async getAnalyticsSummary() {
    const client = await this.ensureConnection();
    
    const summary = await Promise.all([
      client.sCard(`${this.keys.driver}active_set`),
      client.sCard(`${this.keys.ride}active_requests`),
      client.sCard(`${this.keys.negotiation}active`),
      client.sCard(`${this.keys.chat}active_sessions`),
      client.get(`${this.keys.analytics}counter:ride_created`) || '0',
      client.get(`${this.keys.analytics}counter:ride_completed`) || '0',
    ]);

    return {
      activeDrivers: summary[0] || 0,
      activeRideRequests: summary[1] || 0,
      activeNegotiations: summary[2] || 0,
      activeChatSessions: summary[3] || 0,
      totalRideRequests: parseInt(summary[4]) || 0,
      totalRideCompletions: parseInt(summary[5]) || 0,
      timestamp: new Date().toISOString()
    };
  }

  // ====================================================================
  // 🧹 LIMPIEZA Y MANTENIMIENTO
  // ====================================================================

  async cleanupExpiredData() {
    const client = await this.ensureConnection();
    
    const patterns = [
      `${this.keys.driver}active:*`,
      `${this.keys.ride}request:*`,
      `${this.keys.negotiation}*`,
      `${this.keys.chat}session:*`,
    ];

    let cleanedCount = 0;

    for (const pattern of patterns) {
      const keys = await client.keys(pattern);
      
      for (const key of keys) {
        const ttl = await client.ttl(key);
        
        // Si TTL es -1 (sin expiración), aplicar TTL por defecto
        if (ttl === -1) {
          await client.expire(key, 86400); // 24 horas
          cleanedCount++;
        }
        
        // Si TTL es -2 (key no existe), contar para stats
        if (ttl === -2) {
          cleanedCount++;
        }
      }
    }

    console.log(`🧹 Cleanup completed: ${cleanedCount} keys processed`);
    return cleanedCount;
  }

  // ====================================================================
  // 🔒 MÉTODOS PRIVADOS
  // ====================================================================

  _matchesFilters(driver, filters) {
    if (filters.vehicleType && driver.vehicleType !== filters.vehicleType) {
      return false;
    }
    
    if (filters.minRating && driver.rating < filters.minRating) {
      return false;
    }
    
    if (filters.maxDistance && driver.distance > filters.maxDistance) {
      return false;
    }
    
    return true;
  }

  _calculateDriverScore(driver) {
    const distanceScore = Math.max(0, 10 - driver.distance);
    const ratingScore = (driver.rating || 0) * 2;
    const experienceScore = Math.min(5, (driver.completedTrips || 0) / 100);
    
    return distanceScore + ratingScore + experienceScore;
  }

  _calculateETA(distanceKm) {
    // ETA simple basado en velocidad promedio en Lima (15 km/h en tráfico)
    const avgSpeedKmh = 15;
    const etaMinutes = Math.round((distanceKm / avgSpeedKmh) * 60);
    return Math.max(2, etaMinutes); // Mínimo 2 minutos
  }

  _getZoneKey(latitude, longitude) {
    // Dividir Lima en zonas de ~1km para surge pricing
    const latZone = Math.floor(latitude * 100);
    const lngZone = Math.floor(longitude * 100);
    return `${latZone}_${lngZone}`;
  }

  _calculateSurgeMultiplier(demand, supply) {
    if (supply === 0) return 2.5; // Máximo surge
    
    const ratio = demand / supply;
    
    if (ratio < 0.5) return 1.0;      // Sin surge
    if (ratio < 1.0) return 1.2;     // Surge bajo
    if (ratio < 2.0) return 1.5;     // Surge medio
    if (ratio < 3.0) return 2.0;     // Surge alto
    
    return 2.5; // Surge máximo
  }

  async _getDriverSupplyInZone(zoneKey, vehicleType) {
    // Implementar lógica para contar conductores en zona
    // Por simplicidad, retornamos un número fijo
    return 5;
  }

  async _triggerRideMatching(requestId, rideData) {
    // Trigger matching process en background
    // Se podría implementar con Cloud Tasks o Pub/Sub
    console.log(`🔍 Triggering matching for ride ${requestId}`);
  }

  async _expireNegotiation(negotiationId) {
    try {
      const client = await this.ensureConnection();
      const data = await client.get(`${this.keys.negotiation}${negotiationId}`);
      
      if (data) {
        const negotiation = JSON.parse(data);
        if (negotiation.status === 'pending') {
          await this.updateNegotiationStatus(negotiationId, 'expired');
        }
      }
    } catch (error) {
      console.error(`❌ Error expiring negotiation ${negotiationId}:`, error);
    }
  }
}

// ====================================================================
// 🌐 CLOUD FUNCTIONS EXPORTS
// ====================================================================

const redisManager = new RedisStateManager();

// Función para manejo de estado de conductores
exports.manageDriverState = functions
  .region('southamerica-east1')
  .runWith(runtimeOpts)
  .pubsub.topic('driver-state-management')
  .onPublish(async (message, context) => {
    const { action, driverId, data } = JSON.parse(
      Buffer.from(message.data, 'base64').toString()
    );

    try {
      let result;

      switch (action) {
        case 'set_active':
          result = await redisManager.setDriverActive(driverId, data);
          break;
        
        case 'set_offline':
          result = await redisManager.setDriverOffline(driverId, data.reason);
          break;
        
        case 'find_nearby':
          result = await redisManager.getNearbyDrivers(
            data.latitude,
            data.longitude,
            data.radius,
            data.limit,
            data.filters
          );
          break;
        
        default:
          throw new Error(`Unknown action: ${action}`);
      }

      console.log(`✅ Driver state management completed: ${action}`);
      return { success: true, result };

    } catch (error) {
      console.error(`❌ Driver state management failed:`, error);
      throw error;
    }
  });

// Función para gestión de solicitudes de viaje
exports.manageRideRequests = functions
  .region('southamerica-east1')
  .runWith(runtimeOpts)
  .pubsub.topic('ride-request-management')
  .onPublish(async (message, context) => {
    const { action, requestId, data } = JSON.parse(
      Buffer.from(message.data, 'base64').toString()
    );

    try {
      let result;

      switch (action) {
        case 'create':
          result = await redisManager.createRideRequest(data);
          break;
        
        case 'update_status':
          result = await redisManager.updateRideStatus(requestId, data.status, data.updateData);
          break;
        
        default:
          throw new Error(`Unknown action: ${action}`);
      }

      console.log(`✅ Ride request management completed: ${action}`);
      return { success: true, result };

    } catch (error) {
      console.error(`❌ Ride request management failed:`, error);
      throw error;
    }
  });

// Función para sistema de negociación
exports.managePriceNegotiations = functions
  .region('southamerica-east1')
  .runWith(runtimeOpts)
  .pubsub.topic('price-negotiation-management')
  .onPublish(async (message, context) => {
    const { action, negotiationId, data } = JSON.parse(
      Buffer.from(message.data, 'base64').toString()
    );

    try {
      let result;

      switch (action) {
        case 'create':
          result = await redisManager.createPriceNegotiation(data);
          break;
        
        case 'update_status':
          result = await redisManager.updateNegotiationStatus(negotiationId, data.status, data.updateData);
          break;
        
        default:
          throw new Error(`Unknown action: ${action}`);
      }

      console.log(`✅ Price negotiation management completed: ${action}`);
      return { success: true, result };

    } catch (error) {
      console.error(`❌ Price negotiation management failed:`, error);
      throw error;
    }
  });

// Función para pricing dinámico y surge
exports.manageDynamicPricing = functions
  .region('southamerica-east1')
  .runWith(runtimeOpts)
  .pubsub.topic('dynamic-pricing-management')
  .onPublish(async (message, context) => {
    const { action, data } = JSON.parse(
      Buffer.from(message.data, 'base64').toString()
    );

    try {
      let result;

      switch (action) {
        case 'calculate_surge':
          result = await redisManager.calculateSurgePrice(
            data.latitude,
            data.longitude,
            data.vehicleType
          );
          break;
        
        case 'update_demand':
          result = await redisManager.updateDemandMetrics(
            data.latitude,
            data.longitude,
            data.action
          );
          break;
        
        default:
          throw new Error(`Unknown action: ${action}`);
      }

      console.log(`✅ Dynamic pricing management completed: ${action}`);
      return { success: true, result };

    } catch (error) {
      console.error(`❌ Dynamic pricing management failed:`, error);
      throw error;
    }
  });

// Función para gestión de chat
exports.manageChatSessions = functions
  .region('southamerica-east1')
  .runWith(runtimeOpts)
  .pubsub.topic('chat-session-management')
  .onPublish(async (message, context) => {
    const { action, sessionId, data } = JSON.parse(
      Buffer.from(message.data, 'base64').toString()
    );

    try {
      let result;

      switch (action) {
        case 'create':
          result = await redisManager.createChatSession(data);
          break;
        
        case 'update_activity':
          result = await redisManager.updateChatActivity(sessionId, data);
          break;
        
        default:
          throw new Error(`Unknown action: ${action}`);
      }

      console.log(`✅ Chat session management completed: ${action}`);
      return { success: true, result };

    } catch (error) {
      console.error(`❌ Chat session management failed:`, error);
      throw error;
    }
  });

// Función para analytics en tiempo real
exports.recordAnalyticsEvent = functions
  .region('southamerica-east1')
  .runWith(runtimeOpts)
  .pubsub.topic('analytics-events')
  .onPublish(async (message, context) => {
    const { eventName, eventData } = JSON.parse(
      Buffer.from(message.data, 'base64').toString()
    );

    try {
      await redisManager.recordEvent(eventName, eventData);
      
      console.log(`📊 Analytics event recorded: ${eventName}`);
      return { success: true };

    } catch (error) {
      console.error(`❌ Analytics event recording failed:`, error);
      throw error;
    }
  });

// Función para limpieza programada
exports.cleanupRedisData = functions
  .region('southamerica-east1')
  .runWith(runtimeOpts)
  .pubsub.schedule('every 4 hours')
  .timeZone('America/Lima')
  .onRun(async (context) => {
    try {
      const cleanedCount = await redisManager.cleanupExpiredData();
      
      console.log(`🧹 Scheduled cleanup completed: ${cleanedCount} items processed`);
      return { success: true, cleanedCount };

    } catch (error) {
      console.error('❌ Scheduled cleanup failed:', error);
      throw error;
    }
  });

// Función para obtener resumen de analytics
exports.getAnalyticsSummary = functions
  .region('southamerica-east1')
  .runWith(runtimeOpts)
  .https.onRequest(async (req, res) => {
    try {
      const summary = await redisManager.getAnalyticsSummary();
      
      res.status(200).json({
        success: true,
        data: summary
      });

    } catch (error) {
      console.error('❌ Failed to get analytics summary:', error);
      res.status(500).json({
        success: false,
        error: error.message
      });
    }
  });

// Función para health check de Redis
exports.redisHealthCheck = functions
  .region('southamerica-east1')
  .runWith(runtimeOpts)
  .https.onRequest(async (req, res) => {
    try {
      const client = await redisManager.ensureConnection();
      await client.ping();
      
      res.status(200).json({
        success: true,
        status: 'healthy',
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      console.error('❌ Redis health check failed:', error);
      res.status(503).json({
        success: false,
        status: 'unhealthy',
        error: error.message,
        timestamp: new Date().toISOString()
      });
    }
  });