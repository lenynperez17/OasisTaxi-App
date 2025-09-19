// ====================================================================
// 🗺️ OFFLINE MAPS CACHE MANAGER - CLOUD FUNCTIONS OASISTAXI
// ====================================================================
// Gestión completa de caché de mapas offline para Lima, Perú
// Descarga inteligente, limpieza automática y optimización por zonas
// ====================================================================

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const sharp = require('sharp');
const { Storage } = require('@google-cloud/storage');
const { v4: uuidv4 } = require('uuid');

// Configuración para región de Perú
const runtimeOpts = {
  timeoutSeconds: 540,
  memory: '2GB',
  maxInstances: 50,
};

// ====================================================================
// 🔧 CONFIGURACIÓN PARA LIMA, PERÚ
// ====================================================================

class OfflineMapsCacheManager {
  constructor() {
    this.storage = new Storage();
    this.bucket = this.storage.bucket(process.env.FIREBASE_STORAGE_BUCKET || 'oasis-taxi-peru.appspot.com');
    this.firestore = admin.firestore();
    
    // Configuración específica para Perú
    this.config = {
      country: 'PE',
      timezone: 'America/Lima',
      language: 'es-PE',
      currency: 'PEN',
      
      // Límites de Lima metropolitana
      limaBounds: {
        southwest: { lat: -12.3500, lng: -77.1500 },
        northeast: { lat: -11.8500, lng: -76.7500 }
      },
      
      // Zonas prioritarias de Lima
      priorityZones: [
        {
          name: 'Lima Centro',
          priority: 'critical',
          bounds: {
            southwest: { lat: -12.0800, lng: -77.0800 },
            northeast: { lat: -12.0200, lng: -77.0200 }
          },
          maxZoomLevel: 18,
          updateFrequency: 'daily'
        },
        {
          name: 'Miraflores - San Isidro',
          priority: 'high',
          bounds: {
            southwest: { lat: -12.1400, lng: -77.0600 },
            northeast: { lat: -12.0800, lng: -77.0000 }
          },
          maxZoomLevel: 17,
          updateFrequency: 'weekly'
        },
        {
          name: 'Aeropuerto Jorge Chávez',
          priority: 'high',
          bounds: {
            southwest: { lat: -12.0300, lng: -77.1300 },
            northeast: { lat: -11.9900, lng: -77.0900 }
          },
          maxZoomLevel: 17,
          updateFrequency: 'daily'
        },
        {
          name: 'Surco - La Molina',
          priority: 'medium',
          bounds: {
            southwest: { lat: -12.1800, lng: -76.9800 },
            northeast: { lat: -12.0800, lng: -76.9000 }
          },
          maxZoomLevel: 16,
          updateFrequency: 'weekly'
        },
        {
          name: 'San Juan de Lurigancho',
          priority: 'medium',
          bounds: {
            southwest: { lat: -11.9500, lng: -77.0000 },
            northeast: { lat: -11.8500, lng: -76.9000 }
          },
          maxZoomLevel: 15,
          updateFrequency: 'weekly'
        }
      ],
      
      // Configuración de caché
      cache: {
        maxSizeMB: 500,
        tileExpiryDays: 30,
        concurrentDownloads: 10,
        retryAttempts: 3,
        requestTimeoutMs: 10000,
        batchSize: 100
      },
      
      // URLs de mapas
      mapUrls: {
        roadmap: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
        satellite: 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
        traffic: 'https://mt1.google.com/vt/lyrs=m,traffic&x={x}&y={y}&z={z}'
      }
    };
  }

  // ====================================================================
  // 📥 DESCARGA MASIVA DE MAPAS DE LIMA
  // ====================================================================

  async downloadLimaMaps(mapType = 'roadmap', forceUpdate = false) {
    try {
      console.log(`🗺️ Iniciando descarga masiva de mapas de Lima - Tipo: ${mapType}`);
      
      const downloadStats = {
        startTime: new Date(),
        totalTiles: 0,
        downloadedTiles: 0,
        skippedTiles: 0,
        failedTiles: 0,
        totalSizeMB: 0,
        zonesProcessed: []
      };

      // Procesar zonas por prioridad
      const sortedZones = this.config.priorityZones
        .sort((a, b) => this._getPriorityValue(b.priority) - this._getPriorityValue(a.priority));

      for (const zone of sortedZones) {
        console.log(`🔄 Procesando zona: ${zone.name} (${zone.priority})`);
        
        const zoneStats = await this._downloadZone(zone, mapType, forceUpdate);
        
        downloadStats.totalTiles += zoneStats.totalTiles;
        downloadStats.downloadedTiles += zoneStats.downloadedTiles;
        downloadStats.skippedTiles += zoneStats.skippedTiles;
        downloadStats.failedTiles += zoneStats.failedTiles;
        downloadStats.totalSizeMB += zoneStats.sizeMB;
        downloadStats.zonesProcessed.push({
          name: zone.name,
          ...zoneStats
        });

        // Pausa entre zonas para evitar rate limiting
        await this._sleep(2000);
      }

      downloadStats.endTime = new Date();
      downloadStats.durationMinutes = (downloadStats.endTime - downloadStats.startTime) / (1000 * 60);

      // Guardar estadísticas en Firestore
      await this._saveDownloadStats(downloadStats, mapType);

      // Notificar a apps móviles sobre actualización
      await this._notifyMobileApps('maps_updated', {
        mapType,
        stats: downloadStats
      });

      console.log(`✅ Descarga completada: ${downloadStats.downloadedTiles}/${downloadStats.totalTiles} tiles en ${downloadStats.durationMinutes.toFixed(1)} minutos`);
      
      return downloadStats;

    } catch (error) {
      console.error('❌ Error en descarga masiva:', error);
      throw error;
    }
  }

  async _downloadZone(zone, mapType, forceUpdate) {
    const zoneStats = {
      totalTiles: 0,
      downloadedTiles: 0,
      skippedTiles: 0,
      failedTiles: 0,
      sizeMB: 0
    };

    try {
      // Calcular tiles necesarios para la zona
      const tilesToDownload = [];
      
      for (let zoom = 10; zoom <= zone.maxZoomLevel; zoom++) {
        const tiles = this._getTilesForZoom(zone.bounds, zoom);
        tilesToDownload.push(...tiles);
      }

      zoneStats.totalTiles = tilesToDownload.length;
      console.log(`📊 Zona ${zone.name}: ${zoneStats.totalTiles} tiles a procesar`);

      // Descargar en lotes para evitar sobrecarga
      const batches = this._chunkArray(tilesToDownload, this.config.cache.batchSize);
      
      for (const batch of batches) {
        const batchResults = await Promise.allSettled(
          batch.map(tile => this._downloadTile(tile, mapType, forceUpdate))
        );

        for (const result of batchResults) {
          if (result.status === 'fulfilled') {
            const tileResult = result.value;
            if (tileResult.downloaded) {
              zoneStats.downloadedTiles++;
              zoneStats.sizeMB += tileResult.sizeMB || 0;
            } else {
              zoneStats.skippedTiles++;
            }
          } else {
            zoneStats.failedTiles++;
            console.warn('⚠️ Error descargando tile:', result.reason?.message);
          }
        }

        // Pausa entre lotes
        await this._sleep(1000);
      }

      return zoneStats;

    } catch (error) {
      console.error(`❌ Error procesando zona ${zone.name}:`, error);
      throw error;
    }
  }

  async _downloadTile(tile, mapType, forceUpdate) {
    try {
      const tileKey = `maps/${mapType}/${tile.z}/${tile.x}/${tile.y}.png`;
      const file = this.bucket.file(tileKey);

      // Verificar si ya existe y no ha expirado
      if (!forceUpdate) {
        try {
          const [exists] = await file.exists();
          if (exists) {
            const [metadata] = await file.getMetadata();
            const ageInDays = (new Date() - new Date(metadata.timeCreated)) / (1000 * 60 * 60 * 24);
            
            if (ageInDays < this.config.cache.tileExpiryDays) {
              return { downloaded: false, cached: true };
            }
          }
        } catch (error) {
          // Si hay error verificando, proceder con descarga
        }
      }

      // Construir URL del tile
      const url = this.config.mapUrls[mapType]
        .replace('{x}', tile.x)
        .replace('{y}', tile.y)
        .replace('{z}', tile.z);

      // Descargar tile con reintentos
      let tileData = null;
      let lastError = null;

      for (let attempt = 0; attempt < this.config.cache.retryAttempts; attempt++) {
        try {
          const response = await axios.get(url, {
            responseType: 'arraybuffer',
            timeout: this.config.cache.requestTimeoutMs,
            headers: {
              'User-Agent': 'OasisTaxi/1.0 (Peru)',
              'Accept': 'image/png,image/jpeg,image/*'
            }
          });

          if (response.status === 200 && response.data) {
            tileData = response.data;
            break;
          }
        } catch (error) {
          lastError = error;
          if (attempt < this.config.cache.retryAttempts - 1) {
            await this._sleep(Math.pow(2, attempt) * 1000); // Backoff exponencial
          }
        }
      }

      if (!tileData) {
        throw lastError || new Error('Failed to download tile');
      }

      // Optimizar imagen si es necesario
      let optimizedData = tileData;
      try {
        // Comprimir PNG para ahorrar espacio
        optimizedData = await sharp(tileData)
          .png({ compressionLevel: 9, quality: 90 })
          .toBuffer();
      } catch (error) {
        console.warn('⚠️ Error optimizando imagen, usando original:', error.message);
        optimizedData = tileData;
      }

      // Subir a Cloud Storage
      await file.save(optimizedData, {
        metadata: {
          contentType: 'image/png',
          cacheControl: 'public, max-age=2592000', // 30 días
          metadata: {
            tileX: tile.x.toString(),
            tileY: tile.y.toString(),
            tileZ: tile.z.toString(),
            mapType: mapType,
            country: 'PE',
            downloadDate: new Date().toISOString()
          }
        }
      });

      const sizeMB = optimizedData.length / (1024 * 1024);

      return {
        downloaded: true,
        sizeMB: sizeMB,
        originalSize: tileData.length,
        optimizedSize: optimizedData.length
      };

    } catch (error) {
      console.error(`❌ Error descargando tile ${tile.x},${tile.y},${tile.z}:`, error.message);
      throw error;
    }
  }

  // ====================================================================
  // 🧹 LIMPIEZA AUTOMÁTICA DE CACHÉ
  // ====================================================================

  async cleanupExpiredTiles() {
    try {
      console.log('🧹 Iniciando limpieza de tiles expirados...');
      
      const cleanupStats = {
        startTime: new Date(),
        totalFilesChecked: 0,
        expiredFilesDeleted: 0,
        spaceFreedenMB: 0,
        errors: 0
      };

      // Listar todos los archivos de mapas
      const [files] = await this.bucket.getFiles({
        prefix: 'maps/',
        maxResults: 10000
      });

      cleanupStats.totalFilesChecked = files.length;
      console.log(`📊 Verificando ${files.length} archivos...`);

      const filesToDelete = [];
      
      for (const file of files) {
        try {
          const [metadata] = await file.getMetadata();
          const ageInDays = (new Date() - new Date(metadata.timeCreated)) / (1000 * 60 * 60 * 24);
          
          if (ageInDays > this.config.cache.tileExpiryDays) {
            filesToDelete.push({
              file: file,
              sizeMB: (metadata.size || 0) / (1024 * 1024)
            });
          }
        } catch (error) {
          cleanupStats.errors++;
          console.warn(`⚠️ Error verificando archivo ${file.name}:`, error.message);
        }
      }

      console.log(`🗑️ Eliminando ${filesToDelete.length} archivos expirados...`);

      // Eliminar archivos en lotes
      const deleteBatches = this._chunkArray(filesToDelete, 50);
      
      for (const batch of deleteBatches) {
        const deletePromises = batch.map(async ({ file, sizeMB }) => {
          try {
            await file.delete();
            cleanupStats.expiredFilesDeleted++;
            cleanupStats.spaceFreedenMB += sizeMB;
            return true;
          } catch (error) {
            cleanupStats.errors++;
            console.warn(`⚠️ Error eliminando ${file.name}:`, error.message);
            return false;
          }
        });

        await Promise.allSettled(deletePromises);
        
        // Pausa entre lotes
        if (deleteBatches.indexOf(batch) < deleteBatches.length - 1) {
          await this._sleep(1000);
        }
      }

      cleanupStats.endTime = new Date();
      cleanupStats.durationMinutes = (cleanupStats.endTime - cleanupStats.startTime) / (1000 * 60);

      // Guardar estadísticas de limpieza
      await this.firestore.collection('system_logs').add({
        type: 'cache_cleanup',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        stats: cleanupStats,
        country: 'PE'
      });

      console.log(`✅ Limpieza completada: ${cleanupStats.expiredFilesDeleted} archivos eliminados, ${cleanupStats.spaceFreedenMB.toFixed(2)} MB liberados`);
      
      return cleanupStats;

    } catch (error) {
      console.error('❌ Error en limpieza automática:', error);
      throw error;
    }
  }

  // ====================================================================
  // 📊 OPTIMIZACIÓN BASADA EN ANALYTICS
  // ====================================================================

  async optimizePopularZones(daysBack = 7) {
    try {
      console.log(`📊 Analizando zonas populares de los últimos ${daysBack} días...`);
      
      const endDate = new Date();
      const startDate = new Date(endDate.getTime() - (daysBack * 24 * 60 * 60 * 1000));

      // Obtener datos de viajes desde Firestore
      const tripsQuery = await this.firestore
        .collection('trips')
        .where('createdAt', '>=', startDate)
        .where('createdAt', '<=', endDate)
        .where('status', '==', 'completed')
        .get();

      if (tripsQuery.empty) {
        console.log('⚠️ No hay datos de viajes para analizar');
        return { popularZones: [] };
      }

      // Analizar coordenadas más frecuentes
      const locationFrequency = new Map();
      const gridSize = 0.01; // ~1.1km cuadrado

      tripsQuery.docs.forEach(doc => {
        const trip = doc.data();
        
        // Procesar pickup y destination
        [trip.pickup, trip.destination].forEach(location => {
          if (location && location.latitude && location.longitude) {
            const gridKey = this._getGridKey(location.latitude, location.longitude, gridSize);
            locationFrequency.set(gridKey, (locationFrequency.get(gridKey) || 0) + 1);
          }
        });
      });

      // Ordenar zonas por frecuencia
      const sortedZones = Array.from(locationFrequency.entries())
        .sort((a, b) => b[1] - a[1])
        .slice(0, 10) // Top 10 zonas
        .map(([gridKey, frequency]) => {
          const [lat, lng] = this._parseGridKey(gridKey);
          return {
            center: { latitude: lat, longitude: lng },
            frequency: frequency,
            bounds: this._getBoundsFromCenter(lat, lng, 1.0) // 1km radio
          };
        });

      console.log(`🎯 Encontradas ${sortedZones.length} zonas populares`);

      // Descargar mapas de alta calidad para estas zonas
      for (const zone of sortedZones.slice(0, 5)) { // Top 5 zonas
        console.log(`📥 Descargando zona popular (${zone.frequency} viajes)...`);
        
        const customZone = {
          name: `Zona Popular ${zone.center.latitude.toFixed(4)}, ${zone.center.longitude.toFixed(4)}`,
          priority: 'high',
          bounds: zone.bounds,
          maxZoomLevel: 17,
          updateFrequency: 'daily'
        };

        await this._downloadZone(customZone, 'roadmap', true);
        await this._sleep(2000);
      }

      // Guardar análisis
      await this.firestore.collection('analytics').doc('popular_zones').set({
        lastUpdate: admin.firestore.FieldValue.serverTimestamp(),
        analysisDate: endDate,
        daysAnalyzed: daysBack,
        totalTrips: tripsQuery.size,
        popularZones: sortedZones,
        country: 'PE'
      });

      return {
        popularZones: sortedZones,
        totalTrips: tripsQuery.size,
        zonesOptimized: Math.min(5, sortedZones.length)
      };

    } catch (error) {
      console.error('❌ Error optimizando zonas populares:', error);
      throw error;
    }
  }

  // ====================================================================
  // 📱 NOTIFICACIONES A APPS MÓVILES
  // ====================================================================

  async notifyMobileApps(eventType, data) {
    try {
      console.log(`📱 Notificando apps móviles: ${eventType}`);

      const message = {
        data: {
          type: eventType,
          timestamp: new Date().toISOString(),
          country: 'PE',
          ...data
        },
        topic: 'maps_updates_peru'
      };

      // Enviar notificación FCM
      const response = await admin.messaging().send({
        ...message,
        android: {
          priority: 'high',
          data: message.data
        },
        apns: {
          headers: {
            'apns-priority': '10'
          },
          payload: {
            aps: {
              contentAvailable: true,
              category: 'MAPS_UPDATE'
            }
          }
        }
      });

      // Log en Firestore para debugging
      await this.firestore.collection('fcm_logs').add({
        messageId: response,
        eventType: eventType,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        data: data,
        country: 'PE'
      });

      console.log('✅ Notificación enviada a apps móviles');

    } catch (error) {
      console.error('❌ Error enviando notificaciones:', error);
      // No fallar todo el proceso por error en notificaciones
    }
  }

  // ====================================================================
  // 📊 MONITOREO Y MÉTRICAS
  // ====================================================================

  async getStorageMetrics() {
    try {
      const [files] = await this.bucket.getFiles({
        prefix: 'maps/',
        maxResults: 10000
      });

      const metrics = {
        totalFiles: files.length,
        totalSizeMB: 0,
        typeBreakdown: {},
        zoomLevelBreakdown: {},
        oldestFile: null,
        newestFile: null
      };

      for (const file of files) {
        try {
          const [metadata] = await file.getMetadata();
          const sizeMB = (metadata.size || 0) / (1024 * 1024);
          metrics.totalSizeMB += sizeMB;

          // Extraer información del path
          const pathParts = file.name.split('/');
          if (pathParts.length >= 4) {
            const mapType = pathParts[1];
            const zoomLevel = pathParts[2];
            
            metrics.typeBreakdown[mapType] = (metrics.typeBreakdown[mapType] || 0) + 1;
            metrics.zoomLevelBreakdown[zoomLevel] = (metrics.zoomLevelBreakdown[zoomLevel] || 0) + 1;
          }

          const created = new Date(metadata.timeCreated);
          if (!metrics.oldestFile || created < new Date(metrics.oldestFile)) {
            metrics.oldestFile = metadata.timeCreated;
          }
          if (!metrics.newestFile || created > new Date(metrics.newestFile)) {
            metrics.newestFile = metadata.timeCreated;
          }

        } catch (error) {
          console.warn(`⚠️ Error procesando metadata de ${file.name}`);
        }
      }

      return metrics;

    } catch (error) {
      console.error('❌ Error obteniendo métricas:', error);
      throw error;
    }
  }

  // ====================================================================
  // 🔧 UTILIDADES PRIVADAS
  // ====================================================================

  _getTilesForZoom(bounds, zoom) {
    const tiles = [];
    
    const minTileX = this._longitudeToTileX(bounds.southwest.lng, zoom);
    const maxTileX = this._longitudeToTileX(bounds.northeast.lng, zoom);
    const minTileY = this._latitudeToTileY(bounds.northeast.lat, zoom);
    const maxTileY = this._latitudeToTileY(bounds.southwest.lat, zoom);

    for (let x = minTileX; x <= maxTileX; x++) {
      for (let y = minTileY; y <= maxTileY; y++) {
        tiles.push({ x, y, z: zoom });
      }
    }

    return tiles;
  }

  _longitudeToTileX(longitude, zoom) {
    return Math.floor((longitude + 180.0) / 360.0 * Math.pow(2.0, zoom));
  }

  _latitudeToTileY(latitude, zoom) {
    const latRad = latitude * Math.PI / 180.0;
    return Math.floor((1.0 - Math.log(Math.tan(latRad) + 1.0 / Math.cos(latRad)) / Math.PI) / 2.0 * Math.pow(2.0, zoom));
  }

  _getPriorityValue(priority) {
    const values = { low: 1, medium: 2, high: 3, critical: 4 };
    return values[priority] || 1;
  }

  _chunkArray(array, size) {
    const chunks = [];
    for (let i = 0; i < array.length; i += size) {
      chunks.push(array.slice(i, i + size));
    }
    return chunks;
  }

  _sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  _getGridKey(lat, lng, gridSize) {
    const gridLat = Math.floor(lat / gridSize) * gridSize;
    const gridLng = Math.floor(lng / gridSize) * gridSize;
    return `${gridLat.toFixed(6)},${gridLng.toFixed(6)}`;
  }

  _parseGridKey(gridKey) {
    const [lat, lng] = gridKey.split(',').map(parseFloat);
    return [lat, lng];
  }

  _getBoundsFromCenter(lat, lng, radiusKm) {
    const kmPerDegree = 111.32;
    const latOffset = radiusKm / kmPerDegree;
    const lngOffset = radiusKm / (kmPerDegree * Math.cos(lat * Math.PI / 180));

    return {
      southwest: { lat: lat - latOffset, lng: lng - lngOffset },
      northeast: { lat: lat + latOffset, lng: lng + lngOffset }
    };
  }

  async _saveDownloadStats(stats, mapType) {
    try {
      await this.firestore.collection('download_stats').add({
        type: 'lima_download',
        mapType: mapType,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        stats: stats,
        country: 'PE'
      });
    } catch (error) {
      console.warn('⚠️ Error guardando estadísticas:', error.message);
    }
  }
}

// ====================================================================
// 🌐 CLOUD FUNCTIONS EXPORTS
// ====================================================================

const cacheManager = new OfflineMapsCacheManager();

// Función para descarga masiva de Lima
exports.downloadLimaMaps = functions
  .region('southamerica-east1')
  .runWith(runtimeOpts)
  .pubsub.topic('offline-maps-download')
  .onPublish(async (message, context) => {
    const { mapType = 'roadmap', forceUpdate = false } = JSON.parse(
      Buffer.from(message.data, 'base64').toString()
    );

    try {
      const result = await cacheManager.downloadLimaMaps(mapType, forceUpdate);
      
      console.log(`✅ Descarga masiva completada: ${result.downloadedTiles} tiles`);
      return { success: true, stats: result };

    } catch (error) {
      console.error('❌ Error en descarga masiva:', error);
      throw error;
    }
  });

// Función para limpieza automática
exports.cleanupExpiredTiles = functions
  .region('southamerica-east1')
  .runWith(runtimeOpts)
  .pubsub.schedule('30 3 * * *')
  .timeZone('America/Lima')
  .onRun(async (context) => {
    try {
      const result = await cacheManager.cleanupExpiredTiles();
      
      console.log(`✅ Limpieza completada: ${result.expiredFilesDeleted} archivos eliminados`);
      return { success: true, stats: result };

    } catch (error) {
      console.error('❌ Error en limpieza automática:', error);
      throw error;
    }
  });

// Función para optimización de zonas populares
exports.optimizePopularZones = functions
  .region('southamerica-east1')
  .runWith(runtimeOpts)
  .pubsub.schedule('0 1 * * 1')
  .timeZone('America/Lima')
  .onRun(async (context) => {
    try {
      const result = await cacheManager.optimizePopularZones(7);
      
      console.log(`✅ Optimización completada: ${result.zonesOptimized} zonas actualizadas`);
      return { success: true, stats: result };

    } catch (error) {
      console.error('❌ Error en optimización:', error);
      throw error;
    }
  });

// Función para monitoreo de almacenamiento
exports.monitorStorage = functions
  .region('southamerica-east1')
  .runWith({ ...runtimeOpts, memory: '512MB' })
  .pubsub.schedule('*/30 * * * *')
  .timeZone('America/Lima')
  .onRun(async (context) => {
    try {
      const metrics = await cacheManager.getStorageMetrics();
      
      // Verificar límites
      const alerts = [];
      if (metrics.totalSizeMB > 400) { // 80% del límite de 500MB
        alerts.push({
          type: 'storage_warning',
          message: `Almacenamiento de mapas al ${((metrics.totalSizeMB / 500) * 100).toFixed(1)}%`,
          currentSizeMB: metrics.totalSizeMB
        });
      }

      // Guardar métricas
      await admin.firestore().collection('storage_metrics').add({
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        metrics: metrics,
        alerts: alerts,
        country: 'PE'
      });

      // Enviar alertas si es necesario
      if (alerts.length > 0) {
        for (const alert of alerts) {
          console.warn(`🚨 ${alert.type}: ${alert.message}`);
          await cacheManager.notifyMobileApps('storage_alert', alert);
        }
      }

      console.log(`📊 Métricas actualizadas: ${metrics.totalFiles} archivos, ${metrics.totalSizeMB.toFixed(2)} MB`);
      return { success: true, metrics, alerts };

    } catch (error) {
      console.error('❌ Error monitoreando almacenamiento:', error);
      throw error;
    }
  });

// Función HTTP para obtener estadísticas
exports.getMapsStatistics = functions
  .region('southamerica-east1')
  .runWith({ memory: '512MB' })
  .https.onRequest(async (req, res) => {
    try {
      const metrics = await cacheManager.getStorageMetrics();
      
      res.status(200).json({
        success: true,
        data: {
          ...metrics,
          lastUpdate: new Date().toISOString(),
          country: 'PE'
        }
      });

    } catch (error) {
      console.error('❌ Error obteniendo estadísticas:', error);
      res.status(500).json({
        success: false,
        error: error.message
      });
    }
  });

// Función para trigger manual de descarga
exports.triggerMapsDownload = functions
  .region('southamerica-east1')
  .runWith({ memory: '512MB' })
  .https.onCall(async (data, context) => {
    // Verificar autenticación de admin
    if (!context.auth || !context.auth.token.admin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Solo administradores pueden ejecutar descargas manuales'
      );
    }

    try {
      const { mapType = 'roadmap', forceUpdate = false } = data;
      
      // Publicar mensaje para trigger la descarga
      const topic = admin.messaging().topic('offline-maps-download');
      await admin.messaging().send({
        topic: 'offline-maps-download',
        data: {
          mapType: mapType,
          forceUpdate: forceUpdate.toString(),
          triggeredBy: context.auth.uid,
          triggeredAt: new Date().toISOString()
        }
      });

      return {
        success: true,
        message: 'Descarga programada exitosamente',
        mapType: mapType,
        forceUpdate: forceUpdate
      };

    } catch (error) {
      console.error('❌ Error programando descarga:', error);
      throw new functions.https.HttpsError(
        'internal',
        'Error interno del servidor'
      );
    }
  });