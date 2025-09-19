// 🤖 CLOUD VISION API - VERIFICACIÓN DE DOCUMENTOS PERÚ
// Cloud Function para procesar documentos con IA de Google Cloud

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { ImageAnnotatorClient } from '@google-cloud/vision';
import { Storage } from '@google-cloud/storage';

// Inicializar clientes de Google Cloud
const vision = new ImageAnnotatorClient();
const storage = new Storage();
const db = admin.firestore();

interface DocumentData {
  numero?: string;
  nombres?: string;
  apellidos?: string;
  fechaNacimiento?: string;
  vigencia?: string;
  categoria?: string;
  placa?: string;
  poliza?: string;
  aseguradora?: string;
}

interface VerificationResult {
  isValid: boolean;
  confidence: number;
  extractedData: DocumentData;
  errors: string[];
  processingId: string;
  timestamp: string;
  documentType: string;
}

// Configuración para documentos peruanos
const DOCUMENT_PATTERNS = {
  DNI: {
    numero: /\d{8}/,
    codigo: /PE[A-Z]{3}\d{9}[A-Z]{1}/,
    requiredFields: ['numero', 'nombres', 'apellidos', 'fechaNacimiento'],
    minConfidence: 0.85
  },
  LICENCIA: {
    numero: /[A-Z]\d{8}/,
    categoria: /A-I|A-IIa|A-IIb|A-IIIa|A-IIIb|A-IIIc/,
    requiredFields: ['numero', 'categoria', 'vigencia', 'nombres'],
    minConfidence: 0.80
  },
  SOAT: {
    poliza: /\d{10,15}/,
    placa: /[A-Z]{1,2}\d{4}[A-Z]{1,2}|\d{3}-\d{3}/,
    requiredFields: ['poliza', 'vigencia', 'placa', 'aseguradora'],
    minConfidence: 0.75
  },
  TARJETA_PROPIEDAD: {
    placa: /[A-Z]{1,2}\d{4}[A-Z]{1,2}|\d{3}-\d{3}/,
    motor: /[A-Z0-9]{8,17}/,
    requiredFields: ['placa', 'propietario', 'motor'],
    minConfidence: 0.80
  },
  ANTECEDENTES: {
    numero: /\d{8}/,
    expedicion: /\d{2}\/\d{2}\/\d{4}/,
    requiredFields: ['numero', 'nombres', 'apellidos', 'expedicion'],
    minConfidence: 0.85
  },
  CERTIFICADO_SALUD: {
    numero: /CMS-\d{8}/,
    vigencia: /\d{2}\/\d{2}\/\d{4}/,
    requiredFields: ['numero', 'nombres', 'vigencia', 'medico'],
    minConfidence: 0.80
  }
};

/**
 * Cloud Function para verificar documentos con Cloud Vision API
 */
export const verifyDriverDocument = functions
  .region('us-central1')
  .runWith({
    timeoutSeconds: 300,
    memory: '1GB'
  })
  .https
  .onCall(async (data, context) => {
    try {
      // Verificar autenticación
      if (!context.auth) {
        throw new functions.https.HttpsError(
          'unauthenticated',
          'Usuario no autenticado'
        );
      }

      const { imageUrl, documentType, driverId } = data;

      // Validar parámetros
      if (!imageUrl || !documentType || !driverId) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Parámetros requeridos: imageUrl, documentType, driverId'
        );
      }

      const processingId = admin.firestore().collection('temp').doc().id;

      functions.logger.info(`Iniciando verificación de documento`, {
        driverId,
        documentType,
        processingId
      });

      // 1. Procesar imagen con Cloud Vision API
      const visionResult = await processImageWithVision(imageUrl);

      // 2. Extraer datos específicos del tipo de documento
      const extractedData = extractDocumentData(visionResult.text, documentType);

      // 3. Validar datos según regulaciones peruanas
      const validationResult = validatePeruvianDocument(extractedData, documentType);

      // 4. Calcular nivel de confianza
      const confidence = calculateConfidence(visionResult, extractedData, documentType);

      // 5. Crear resultado final
      const result: VerificationResult = {
        isValid: validationResult.isValid && confidence >= DOCUMENT_PATTERNS[documentType].minConfidence,
        confidence,
        extractedData,
        errors: validationResult.errors,
        processingId,
        timestamp: new Date().toISOString(),
        documentType
      };

      // 6. Guardar resultado en Firestore
      await saveVerificationResult(driverId, documentType, result);

      // 7. Actualizar estado del conductor si todos los documentos están válidos
      await updateDriverVerificationStatus(driverId);

      functions.logger.info(`Verificación completada`, {
        driverId,
        documentType,
        isValid: result.isValid,
        confidence: result.confidence
      });

      return result;

    } catch (error) {
      functions.logger.error('Error en verificación de documento', error);
      
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError(
        'internal',
        'Error interno del sistema de verificación'
      );
    }
  });

/**
 * Procesar imagen con Cloud Vision API
 */
async function processImageWithVision(imageUrl: string) {
  try {
    const [result] = await vision.textDetection(imageUrl);
    const detections = result.textAnnotations;

    if (!detections || detections.length === 0) {
      throw new Error('No se pudo extraer texto de la imagen');
    }

    const fullText = detections[0].description || '';
    const words = detections.slice(1).map(detection => ({
      text: detection.description || '',
      confidence: detection.confidence || 0,
      bounds: detection.boundingPoly
    }));

    return {
      text: fullText,
      words,
      confidence: words.reduce((sum, word) => sum + word.confidence, 0) / words.length
    };

  } catch (error) {
    functions.logger.error('Error en Cloud Vision API', error);
    throw new Error('Error procesando imagen con Cloud Vision');
  }
}

/**
 * Extraer datos específicos según tipo de documento
 */
function extractDocumentData(text: string, documentType: string): DocumentData {
  const extractedData: DocumentData = {};
  const lines = text.split('\n').map(line => line.trim()).filter(line => line.length > 0);

  switch (documentType) {
    case 'DNI':
      extractedData.numero = extractPattern(text, /\b\d{8}\b/);
      extractedData.nombres = extractNames(lines, 'NOMBRES');
      extractedData.apellidos = extractNames(lines, 'APELLIDOS');
      extractedData.fechaNacimiento = extractPattern(text, /\b\d{2}\/\d{2}\/\d{4}\b/);
      break;

    case 'LICENCIA':
      extractedData.numero = extractPattern(text, /\b[A-Z]\d{8}\b/);
      extractedData.categoria = extractPattern(text, /A-I{1,3}[abc]?/);
      extractedData.vigencia = extractPattern(text, /\b\d{2}\/\d{2}\/\d{4}\b/);
      extractedData.nombres = extractNames(lines, 'APELLIDOS Y NOMBRES');
      break;

    case 'SOAT':
      extractedData.poliza = extractPattern(text, /\b\d{10,15}\b/);
      extractedData.placa = extractPattern(text, /\b[A-Z]{1,2}\d{4}[A-Z]{1,2}\b|\b\d{3}-\d{3}\b/);
      extractedData.vigencia = extractPattern(text, /VIGENCIA.*?(\d{2}\/\d{2}\/\d{4})/i);
      extractedData.aseguradora = extractInsurer(lines);
      break;

    case 'TARJETA_PROPIEDAD':
      extractedData.placa = extractPattern(text, /PLACA.*?([A-Z]{1,2}\d{4}[A-Z]{1,2}|\d{3}-\d{3})/i);
      extractedData.nombres = extractNames(lines, 'PROPIETARIO');
      break;

    case 'ANTECEDENTES':
      extractedData.numero = extractPattern(text, /\b\d{8}\b/);
      extractedData.nombres = extractNames(lines, 'NOMBRES');
      extractedData.apellidos = extractNames(lines, 'APELLIDOS');
      break;

    case 'CERTIFICADO_SALUD':
      extractedData.numero = extractPattern(text, /CMS-\d{8}/);
      extractedData.vigencia = extractPattern(text, /VIGENCIA.*?(\d{2}\/\d{2}\/\d{4})/i);
      extractedData.nombres = extractNames(lines, 'PACIENTE');
      break;
  }

  return extractedData;
}

/**
 * Extraer patrón específico del texto
 */
function extractPattern(text: string, pattern: RegExp): string | undefined {
  const match = text.match(pattern);
  return match ? match[1] || match[0] : undefined;
}

/**
 * Extraer nombres de las líneas del documento
 */
function extractNames(lines: string[], keyword: string): string | undefined {
  const nameLineIndex = lines.findIndex(line => 
    line.toUpperCase().includes(keyword.toUpperCase())
  );
  
  if (nameLineIndex !== -1 && nameLineIndex + 1 < lines.length) {
    return lines[nameLineIndex + 1];
  }
  
  return undefined;
}

/**
 * Extraer aseguradora del SOAT
 */
function extractInsurer(lines: string[]): string | undefined {
  const insurers = ['PACIFICO', 'RIMAC', 'LA POSITIVA', 'MAPFRE', 'INTERSEGURO'];
  
  for (const line of lines) {
    for (const insurer of insurers) {
      if (line.toUpperCase().includes(insurer)) {
        return insurer;
      }
    }
  }
  
  return undefined;
}

/**
 * Validar documento según regulaciones peruanas
 */
function validatePeruvianDocument(data: DocumentData, documentType: string): {
  isValid: boolean;
  errors: string[];
} {
  const errors: string[] = [];
  const config = DOCUMENT_PATTERNS[documentType];

  if (!config) {
    return { isValid: false, errors: ['Tipo de documento no soportado'] };
  }

  // Verificar campos requeridos
  for (const field of config.requiredFields) {
    if (!data[field as keyof DocumentData]) {
      errors.push(`Campo requerido faltante: ${field}`);
    }
  }

  // Validar formatos específicos
  Object.entries(config).forEach(([key, pattern]) => {
    if (pattern instanceof RegExp && data[key as keyof DocumentData]) {
      const value = data[key as keyof DocumentData] as string;
      if (!pattern.test(value)) {
        errors.push(`Formato inválido en ${key}: ${value}`);
      }
    }
  });

  // Validar vigencia si existe
  if (data.vigencia) {
    const vigencia = parseDate(data.vigencia);
    if (vigencia && vigencia < new Date()) {
      errors.push('Documento vencido');
    }
  }

  return {
    isValid: errors.length === 0,
    errors
  };
}

/**
 * Calcular nivel de confianza de la verificación
 */
function calculateConfidence(
  visionResult: any,
  extractedData: DocumentData,
  documentType: string
): number {
  let confidence = visionResult.confidence || 0;

  // Penalizar por campos faltantes
  const config = DOCUMENT_PATTERNS[documentType];
  const requiredFields = config.requiredFields.length;
  const foundFields = config.requiredFields.filter(
    field => extractedData[field as keyof DocumentData]
  ).length;

  confidence *= (foundFields / requiredFields);

  // Bonificar por patrones válidos
  let validPatterns = 0;
  let totalPatterns = 0;

  Object.entries(config).forEach(([key, pattern]) => {
    if (pattern instanceof RegExp) {
      totalPatterns++;
      const value = extractedData[key as keyof DocumentData] as string;
      if (value && pattern.test(value)) {
        validPatterns++;
      }
    }
  });

  if (totalPatterns > 0) {
    confidence *= (0.7 + 0.3 * (validPatterns / totalPatterns));
  }

  return Math.min(confidence, 1.0);
}

/**
 * Guardar resultado de verificación en Firestore
 */
async function saveVerificationResult(
  driverId: string,
  documentType: string,
  result: VerificationResult
): Promise<void> {
  try {
    await db
      .collection('drivers')
      .doc(driverId)
      .collection('documents')
      .doc(documentType)
      .set({
        ...result,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

    // Guardar en historial
    await db
      .collection('documentVerificationHistory')
      .add({
        driverId,
        documentType,
        result,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });

  } catch (error) {
    functions.logger.error('Error guardando resultado de verificación', error);
    throw error;
  }
}

/**
 * Actualizar estado general de verificación del conductor
 */
async function updateDriverVerificationStatus(driverId: string): Promise<void> {
  try {
    const requiredDocs = ['DNI', 'LICENCIA', 'SOAT', 'TARJETA_PROPIEDAD', 'ANTECEDENTES', 'CERTIFICADO_SALUD'];
    const documentSnapshots = await Promise.all(
      requiredDocs.map(docType =>
        db.collection('drivers').doc(driverId).collection('documents').doc(docType).get()
      )
    );

    const allValid = documentSnapshots.every(snapshot => {
      const data = snapshot.data();
      return data && data.isValid === true;
    });

    await db.collection('drivers').doc(driverId).update({
      documentVerificationStatus: allValid ? 'verified' : 'pending',
      lastDocumentCheck: admin.firestore.FieldValue.serverTimestamp()
    });

    functions.logger.info(`Estado de verificación actualizado`, {
      driverId,
      allValid
    });

  } catch (error) {
    functions.logger.error('Error actualizando estado de verificación', error);
  }
}

/**
 * Parsear fecha en formato DD/MM/YYYY
 */
function parseDate(dateStr: string): Date | null {
  try {
    const [day, month, year] = dateStr.split('/').map(Number);
    return new Date(year, month - 1, day);
  } catch {
    return null;
  }
}

/**
 * Obtener estado de documentos del conductor
 */
export const getDriverDocumentStatus = functions
  .region('us-central1')
  .https
  .onCall(async (data, context) => {
    try {
      if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
      }

      const { driverId } = data;
      if (!driverId) {
        throw new functions.https.HttpsError('invalid-argument', 'driverId requerido');
      }

      const documentsSnapshot = await db
        .collection('drivers')
        .doc(driverId)
        .collection('documents')
        .get();

      const status: Record<string, any> = {};
      documentsSnapshot.forEach(doc => {
        status[doc.id] = doc.data();
      });

      return status;

    } catch (error) {
      functions.logger.error('Error obteniendo estado de documentos', error);
      throw new functions.https.HttpsError('internal', 'Error interno del sistema');
    }
  });