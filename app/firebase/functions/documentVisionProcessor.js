/**
 * Cloud Function para procesamiento automático de documentos usando Google Cloud Vision API
 * Especializado para documentos peruanos: DNI, Licencias, SOAT, etc.
 * 
 * @author OasisTaxi Development Team
 * @version 1.0.0
 * @date 2025-01-11
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const vision = require('@google-cloud/vision');
const { Storage } = require('@google-cloud/storage');
const axios = require('axios');

// Inicializar servicios
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const storage = new Storage();
const visionClient = new vision.ImageAnnotatorClient();

/**
 * Cloud Function principal para procesar documentos con Vision API
 */
exports.processDocumentVision = functions
  .runWith({
    timeoutSeconds: 540,
    memory: '2GB',
    maxInstances: 10
  })
  .https.onCall(async (data, context) => {
    try {
      // Verificar autenticación
      if (!context.auth) {
        throw new functions.https.HttpsError(
          'unauthenticated',
          'Usuario debe estar autenticado para procesar documentos'
        );
      }

      const { imageUrl, documentType, features = [], maxResults = 50 } = data;

      if (!imageUrl || !documentType) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'imageUrl y documentType son requeridos'
        );
      }

      console.log(`Procesando documento: ${documentType} para usuario: ${context.auth.uid}`);

      // 1. Descargar imagen de Storage
      const imageBuffer = await downloadImageFromStorage(imageUrl);

      // 2. Procesar con Cloud Vision API
      const visionResults = await processWithVisionAPI(imageBuffer, features, maxResults);

      // 3. Aplicar análisis específico por tipo de documento
      const analysisResult = await analyzeDocumentByType(visionResults, documentType);

      // 4. Validar con base de datos de autoridades peruanas
      const validationResult = await validateWithPeruvianAuthorities(analysisResult, documentType);

      // 5. Calcular score de confianza final
      const finalScore = calculateFinalConfidenceScore(visionResults, analysisResult, validationResult);

      // 6. Guardar resultado en Firestore
      await saveProcessingResult(context.auth.uid, {
        imageUrl,
        documentType,
        visionResults,
        analysisResult,
        validationResult,
        finalScore,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 7. Retornar resultado procesado
      return {
        success: true,
        data: {
          ...visionResults,
          analysisResult,
          validationResult,
          finalScore,
          timestamp: new Date().toISOString(),
        }
      };

    } catch (error) {
      console.error('Error procesando documento:', error);
      
      // Registrar error en Firestore para debugging
      await db.collection('processing_errors').add({
        userId: context.auth?.uid || 'anonymous',
        error: error.message,
        stack: error.stack,
        data: data,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      throw new functions.https.HttpsError(
        'internal',
        `Error procesando documento: ${error.message}`
      );
    }
  });

/**
 * Descarga imagen desde Firebase Storage
 */
async function downloadImageFromStorage(imageUrl) {
  try {
    // Extraer bucket y path de la URL
    const urlParts = new URL(imageUrl);
    const pathWithBucket = urlParts.pathname.substring(1);
    const [bucketName, ...pathParts] = pathWithBucket.split('/');
    const filePath = pathParts.join('/');

    const bucket = storage.bucket(bucketName);
    const file = bucket.file(filePath);
    
    const [buffer] = await file.download();
    
    console.log(`Imagen descargada: ${buffer.length} bytes`);
    return buffer;
    
  } catch (error) {
    console.error('Error descargando imagen:', error);
    throw new Error(`No se pudo descargar la imagen: ${error.message}`);
  }
}

/**
 * Procesa imagen con Google Cloud Vision API
 */
async function processWithVisionAPI(imageBuffer, features, maxResults) {
  try {
    // Configurar features por defecto si no se especifican
    const defaultFeatures = [
      { type: 'TEXT_DETECTION', maxResults },
      { type: 'DOCUMENT_TEXT_DETECTION', maxResults },
      { type: 'OBJECT_LOCALIZATION', maxResults: 10 },
      { type: 'SAFE_SEARCH_DETECTION' },
      { type: 'IMAGE_PROPERTIES' },
    ];

    const requestFeatures = features.length > 0 
      ? features.map(f => ({ type: f, maxResults }))
      : defaultFeatures;

    // Realizar análisis con Vision API
    const [result] = await visionClient.annotateImage({
      image: { content: imageBuffer },
      features: requestFeatures,
      imageContext: {
        languageHints: ['es', 'en'], // Español y inglés para Perú
        textDetectionParams: {
          enableTextDetectionConfidenceScore: true,
        },
      },
    });

    console.log('Vision API processing completed');

    // Extraer información relevante
    const visionData = {
      textAnnotations: result.textAnnotations || [],
      fullTextAnnotation: result.fullTextAnnotation || null,
      localizedObjectAnnotations: result.localizedObjectAnnotations || [],
      safeSearchAnnotation: result.safeSearchAnnotation || null,
      imagePropertiesAnnotation: result.imagePropertiesAnnotation || null,
      error: result.error || null,
    };

    return visionData;

  } catch (error) {
    console.error('Error en Vision API:', error);
    throw new Error(`Error procesando con Vision API: ${error.message}`);
  }
}

/**
 * Analiza documento según su tipo específico
 */
async function analyzeDocumentByType(visionResults, documentType) {
  try {
    const fullText = visionResults.fullTextAnnotation?.text || '';
    const textAnnotations = visionResults.textAnnotations || [];

    console.log(`Analizando documento tipo: ${documentType}`);

    switch (documentType.toLowerCase()) {
      case 'dni':
        return analyzeDniDocument(fullText, textAnnotations);
      
      case 'licensea':
      case 'licenseb':
        return analyzeLicenseDocument(fullText, textAnnotations, documentType);
      
      case 'soat':
        return analyzeSoatDocument(fullText, textAnnotations);
      
      case 'vehicleregistration':
        return analyzeVehicleRegistrationDocument(fullText, textAnnotations);
      
      case 'technicalreview':
        return analyzeTechnicalReviewDocument(fullText, textAnnotations);
      
      case 'criminalrecord':
        return analyzeCriminalRecordDocument(fullText, textAnnotations);
      
      default:
        return analyzeGenericDocument(fullText, textAnnotations, documentType);
    }

  } catch (error) {
    console.error('Error analizando documento por tipo:', error);
    return {
      success: false,
      error: error.message,
      extractedData: {},
      confidence: 0.0,
    };
  }
}

/**
 * Análisis específico para DNI peruano
 */
function analyzeDniDocument(fullText, textAnnotations) {
  const extractedData = {};
  const errors = [];
  let confidence = 0.0;

  try {
    const upperText = fullText.toUpperCase();
    
    // Verificar que es un DNI peruano
    const isDniPeruvian = upperText.includes('PERÚ') || 
                         upperText.includes('RENIEC') || 
                         upperText.includes('DOCUMENTO NACIONAL');
    
    if (isDniPeruvian) {
      confidence += 0.2;
      extractedData.isPeruvianDni = true;
    } else {
      errors.push('No se detectaron marcas oficiales del DNI peruano');
      extractedData.isPeruvianDni = false;
    }

    // Extraer número de DNI (8 dígitos)
    const dniMatches = fullText.match(/\b\d{8}\b/g);
    if (dniMatches && dniMatches.length > 0) {
      // Tomar el primer número de 8 dígitos que aparezca
      extractedData.dniNumber = dniMatches[0];
      confidence += 0.3;
      
      // Validar que el DNI es válido para Perú (no puede empezar con 0)
      if (!extractedData.dniNumber.startsWith('0')) {
        confidence += 0.1;
      } else {
        errors.push('DNI no puede empezar con 0');
      }
    } else {
      errors.push('Número de DNI no encontrado');
    }

    // Extraer información personal
    const lines = fullText.split('\n').filter(line => line.trim().length > 0);
    
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim().toUpperCase();
      const nextLine = i + 1 < lines.length ? lines[i + 1].trim() : '';

      // Buscar apellidos y nombres
      if (line.includes('APELLIDOS Y NOMBRES') || line.includes('APELLIDOS Y NOMBRE')) {
        if (nextLine && nextLine.length > 5) {
          extractedData.fullName = nextLine;
          confidence += 0.15;
        }
      }

      // Buscar fecha de nacimiento
      if (line.includes('FECHA DE NACIMIENTO') || line.includes('NACIMIENTO')) {
        const dateMatch = nextLine.match(/\b\d{2}\/\d{2}\/\d{4}\b/);
        if (dateMatch) {
          extractedData.birthDate = dateMatch[0];
          confidence += 0.1;
          
          // Validar edad razonable (18-100 años)
          const birthYear = parseInt(dateMatch[0].split('/')[2]);
          const currentYear = new Date().getFullYear();
          const age = currentYear - birthYear;
          
          if (age >= 18 && age <= 100) {
            confidence += 0.05;
          } else {
            errors.push(`Edad calculada (${age}) fuera del rango válido`);
          }
        }
      }

      // Buscar estado civil
      if (line.includes('ESTADO CIVIL')) {
        const validStates = ['SOLTERO', 'CASADO', 'VIUDO', 'DIVORCIADO'];
        const stateMatch = validStates.find(state => nextLine.includes(state));
        if (stateMatch) {
          extractedData.maritalStatus = stateMatch;
          confidence += 0.05;
        }
      }

      // Buscar domicilio
      if (line.includes('DOMICILIO')) {
        if (nextLine && nextLine.length > 10) {
          extractedData.address = nextLine;
          confidence += 0.05;
        }
      }
    }

    // Buscar fecha de emisión
    const emissionMatches = fullText.match(/(?:EMISIÓN|EMISION)\s*:?\s*(\d{2}\/\d{2}\/\d{4})/i);
    if (emissionMatches) {
      extractedData.emissionDate = emissionMatches[1];
      confidence += 0.05;
    }

    return {
      success: true,
      documentType: 'dni',
      extractedData,
      confidence: Math.min(confidence, 1.0),
      errors,
      ocrText: fullText,
    };

  } catch (error) {
    console.error('Error analizando DNI:', error);
    return {
      success: false,
      error: error.message,
      extractedData: {},
      confidence: 0.0,
    };
  }
}

/**
 * Análisis específico para Licencia de Conducir
 */
function analyzeLicenseDocument(fullText, textAnnotations, documentType) {
  const extractedData = {};
  const errors = [];
  let confidence = 0.0;

  try {
    const upperText = fullText.toUpperCase();
    
    // Verificar que es una licencia peruana
    const isPeruvianLicense = upperText.includes('MTC') || 
                             upperText.includes('MINISTERIO DE TRANSPORTES') || 
                             upperText.includes('LICENCIA DE CONDUCIR');
    
    if (isPeruvianLicense) {
      confidence += 0.2;
      extractedData.isPeruvianLicense = true;
    } else {
      errors.push('No se detectaron marcas oficiales del MTC');
      extractedData.isPeruvianLicense = false;
    }

    // Extraer número de licencia (formato: letra + 8 dígitos)
    const licenseMatches = fullText.match(/\b[A-Z]\d{8}\b/g);
    if (licenseMatches && licenseMatches.length > 0) {
      extractedData.licenseNumber = licenseMatches[0];
      confidence += 0.3;
    } else {
      errors.push('Número de licencia no encontrado');
    }

    // Extraer clase de licencia
    const classMatches = fullText.match(/CLASE\s*:?\s*([ABCI]+[0-9]*)/i);
    if (classMatches) {
      extractedData.licenseClass = classMatches[1];
      confidence += 0.2;
      
      // Verificar que coincide con el tipo esperado
      const expectedClass = documentType.toLowerCase() === 'licensea' ? 'A' : 'B';
      if (extractedData.licenseClass.includes(expectedClass)) {
        confidence += 0.1;
      } else {
        errors.push(`Clase de licencia (${extractedData.licenseClass}) no coincide con la esperada (${expectedClass})`);
      }
    } else {
      errors.push('Clase de licencia no encontrada');
    }

    // Extraer fechas (emisión y vencimiento)
    const dateMatches = fullText.match(/\b\d{2}\/\d{2}\/\d{4}\b/g);
    if (dateMatches && dateMatches.length >= 2) {
      extractedData.issueDate = dateMatches[0];
      extractedData.expiryDate = dateMatches[dateMatches.length - 1];
      confidence += 0.15;
      
      // Verificar que no está vencida
      try {
        const [day, month, year] = extractedData.expiryDate.split('/').map(n => parseInt(n));
        const expiryDate = new Date(year, month - 1, day);
        const now = new Date();
        
        if (expiryDate > now) {
          confidence += 0.1;
        } else {
          errors.push('Licencia vencida');
        }
      } catch (e) {
        errors.push('Error validando fecha de vencimiento');
      }
    } else {
      errors.push('Fechas de emisión/vencimiento no encontradas');
    }

    // Extraer nombre del titular
    const lines = fullText.split('\n').filter(line => line.trim().length > 0);
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim().toUpperCase();
      const nextLine = i + 1 < lines.length ? lines[i + 1].trim() : '';

      if ((line.includes('APELLIDOS Y NOMBRES') || line.includes('TITULAR')) && nextLine) {
        extractedData.holderName = nextLine;
        confidence += 0.1;
        break;
      }
    }

    return {
      success: true,
      documentType: 'license',
      extractedData,
      confidence: Math.min(confidence, 1.0),
      errors,
      ocrText: fullText,
    };

  } catch (error) {
    console.error('Error analizando licencia:', error);
    return {
      success: false,
      error: error.message,
      extractedData: {},
      confidence: 0.0,
    };
  }
}

/**
 * Análisis específico para SOAT
 */
function analyzeSoatDocument(fullText, textAnnotations) {
  const extractedData = {};
  const errors = [];
  let confidence = 0.0;

  try {
    const upperText = fullText.toUpperCase();
    
    // Verificar que es un SOAT peruano
    const isSoatPeruvian = upperText.includes('SOAT') || 
                          upperText.includes('SEGURO OBLIGATORIO') || 
                          upperText.includes('ACCIDENTES DE TRÁNSITO');
    
    if (isSoatPeruvian) {
      confidence += 0.2;
      extractedData.isPeruvianSoat = true;
    } else {
      errors.push('No se detectaron marcas oficiales del SOAT');
      extractedData.isPeruvianSoat = false;
    }

    // Extraer número de póliza
    const policyMatches = fullText.match(/\b[A-Z0-9]{10,15}\b/g);
    if (policyMatches && policyMatches.length > 0) {
      // Buscar el que más se parezca a un número de póliza
      const policyNumber = policyMatches.find(match => 
        match.length >= 10 && /[A-Z]/.test(match) && /\d/.test(match)
      );
      
      if (policyNumber) {
        extractedData.policyNumber = policyNumber;
        confidence += 0.3;
      }
    } else {
      errors.push('Número de póliza no encontrado');
    }

    // Extraer placa del vehículo (formato peruano: ABC-123 o AB-1234)
    const plateMatches = fullText.match(/\b[A-Z]{2,3}-?\d{3,4}\b/g);
    if (plateMatches && plateMatches.length > 0) {
      extractedData.vehiclePlate = plateMatches[0].replace('-', '-'); // Normalizar formato
      confidence += 0.2;
    } else {
      errors.push('Placa del vehículo no encontrada');
    }

    // Extraer fechas de vigencia
    const dateMatches = fullText.match(/\b\d{2}\/\d{2}\/\d{4}\b/g);
    if (dateMatches && dateMatches.length >= 2) {
      extractedData.startDate = dateMatches[0];
      extractedData.endDate = dateMatches[dateMatches.length - 1];
      confidence += 0.15;
      
      // Verificar vigencia
      try {
        const [day, month, year] = extractedData.endDate.split('/').map(n => parseInt(n));
        const endDate = new Date(year, month - 1, day);
        const now = new Date();
        
        if (endDate > now) {
          confidence += 0.15;
        } else {
          errors.push('SOAT vencido');
        }
      } catch (e) {
        errors.push('Error validando vigencia del SOAT');
      }
    } else {
      errors.push('Fechas de vigencia no encontradas');
    }

    // Extraer aseguradora
    const insurers = ['RIMAC', 'PACIFICO', 'INTERSEGURO', 'LA POSITIVA', 'HDI', 'MAPFRE'];
    const foundInsurer = insurers.find(insurer => upperText.includes(insurer));
    if (foundInsurer) {
      extractedData.insurer = foundInsurer;
      confidence += 0.1;
    }

    return {
      success: true,
      documentType: 'soat',
      extractedData,
      confidence: Math.min(confidence, 1.0),
      errors,
      ocrText: fullText,
    };

  } catch (error) {
    console.error('Error analizando SOAT:', error);
    return {
      success: false,
      error: error.message,
      extractedData: {},
      confidence: 0.0,
    };
  }
}

/**
 * Análisis específico para Tarjeta de Propiedad del Vehículo
 */
function analyzeVehicleRegistrationDocument(fullText, textAnnotations) {
  const extractedData = {};
  const errors = [];
  let confidence = 0.0;

  try {
    const upperText = fullText.toUpperCase();
    
    // Verificar que es una tarjeta de propiedad peruana
    const isPeruvianRegistration = upperText.includes('SUNARP') || 
                                  upperText.includes('TARJETA DE PROPIEDAD') || 
                                  upperText.includes('REGISTRO VEHICULAR');
    
    if (isPeruvianRegistration) {
      confidence += 0.2;
      extractedData.isPeruvianRegistration = true;
    } else {
      errors.push('No se detectaron marcas oficiales de SUNARP');
      extractedData.isPeruvianRegistration = false;
    }

    // Extraer placa del vehículo
    const plateMatches = fullText.match(/\b[A-Z]{2,3}-?\d{3,4}\b/g);
    if (plateMatches && plateMatches.length > 0) {
      extractedData.vehiclePlate = plateMatches[0];
      confidence += 0.3;
    } else {
      errors.push('Placa del vehículo no encontrada');
    }

    // Extraer información del vehículo
    const lines = fullText.split('\n').filter(line => line.trim().length > 0);
    
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim().toUpperCase();
      const nextLine = i + 1 < lines.length ? lines[i + 1].trim() : '';

      if (line.includes('MARCA') && nextLine) {
        extractedData.brand = nextLine;
        confidence += 0.1;
      }

      if (line.includes('MODELO') && nextLine) {
        extractedData.model = nextLine;
        confidence += 0.1;
      }

      if ((line.includes('AÑO') || line.includes('FABRICACION')) && nextLine) {
        const year = nextLine.match(/\d{4}/);
        if (year) {
          extractedData.year = parseInt(year[0]);
          confidence += 0.1;
          
          // Validar año razonable (1980-2030)
          if (extractedData.year >= 1980 && extractedData.year <= 2030) {
            confidence += 0.05;
          }
        }
      }

      if (line.includes('MOTOR') && nextLine) {
        extractedData.engineNumber = nextLine;
        confidence += 0.05;
      }

      if (line.includes('SERIE') && nextLine) {
        extractedData.serialNumber = nextLine;
        confidence += 0.05;
      }
    }

    return {
      success: true,
      documentType: 'vehicle_registration',
      extractedData,
      confidence: Math.min(confidence, 1.0),
      errors,
      ocrText: fullText,
    };

  } catch (error) {
    console.error('Error analizando tarjeta de propiedad:', error);
    return {
      success: false,
      error: error.message,
      extractedData: {},
      confidence: 0.0,
    };
  }
}

/**
 * Análisis específico para Revisión Técnica Vehicular
 */
function analyzeTechnicalReviewDocument(fullText, textAnnotations) {
  const extractedData = {};
  const errors = [];
  let confidence = 0.0;

  try {
    const upperText = fullText.toUpperCase();
    
    // Verificar que es una revisión técnica peruana
    const isPeruvianTechnical = upperText.includes('REVISIÓN TÉCNICA') || 
                               upperText.includes('CERTIFICADO DE INSPECCIÓN') || 
                               upperText.includes('CIT');
    
    if (isPeruvianTechnical) {
      confidence += 0.2;
      extractedData.isPeruvianTechnicalReview = true;
    } else {
      errors.push('No se detectaron marcas oficiales de revisión técnica');
      extractedData.isPeruvianTechnicalReview = false;
    }

    // Extraer número de certificado
    const certMatches = fullText.match(/\b[A-Z0-9]{10,20}\b/g);
    if (certMatches && certMatches.length > 0) {
      extractedData.certificateNumber = certMatches[0];
      confidence += 0.3;
    } else {
      errors.push('Número de certificado no encontrado');
    }

    // Extraer placa del vehículo
    const plateMatches = fullText.match(/\b[A-Z]{2,3}-?\d{3,4}\b/g);
    if (plateMatches && plateMatches.length > 0) {
      extractedData.vehiclePlate = plateMatches[0];
      confidence += 0.2;
    } else {
      errors.push('Placa del vehículo no encontrada');
    }

    // Extraer fechas
    const dateMatches = fullText.match(/\b\d{2}\/\d{2}\/\d{4}\b/g);
    if (dateMatches && dateMatches.length >= 2) {
      extractedData.issueDate = dateMatches[0];
      extractedData.expiryDate = dateMatches[dateMatches.length - 1];
      confidence += 0.15;
      
      // Verificar vigencia
      try {
        const [day, month, year] = extractedData.expiryDate.split('/').map(n => parseInt(n));
        const expiryDate = new Date(year, month - 1, day);
        const now = new Date();
        
        if (expiryDate > now) {
          confidence += 0.15;
        } else {
          errors.push('Revisión técnica vencida');
        }
      } catch (e) {
        errors.push('Error validando vigencia de revisión técnica');
      }
    } else {
      errors.push('Fechas no encontradas');
    }

    // Extraer resultado de la inspección
    if (upperText.includes('APROBADO') || upperText.includes('APTO')) {
      extractedData.result = 'APROBADO';
      confidence += 0.1;
    } else if (upperText.includes('RECHAZADO') || upperText.includes('NO APTO')) {
      extractedData.result = 'RECHAZADO';
      confidence += 0.1;
      errors.push('Vehículo rechazado en revisión técnica');
    }

    return {
      success: true,
      documentType: 'technical_review',
      extractedData,
      confidence: Math.min(confidence, 1.0),
      errors,
      ocrText: fullText,
    };

  } catch (error) {
    console.error('Error analizando revisión técnica:', error);
    return {
      success: false,
      error: error.message,
      extractedData: {},
      confidence: 0.0,
    };
  }
}

/**
 * Análisis para Antecedentes Penales
 */
function analyzeCriminalRecordDocument(fullText, textAnnotations) {
  const extractedData = {};
  const errors = [];
  let confidence = 0.0;

  try {
    const upperText = fullText.toUpperCase();
    
    // Verificar que es un certificado peruano
    const isPeruvianCriminalRecord = upperText.includes('ANTECEDENTES PENALES') || 
                                    upperText.includes('PODER JUDICIAL') || 
                                    upperText.includes('CERTIFICADO JUDICIAL');
    
    if (isPeruvianCriminalRecord) {
      confidence += 0.3;
      extractedData.isPeruvianCriminalRecord = true;
    } else {
      errors.push('No se detectaron marcas oficiales del Poder Judicial');
      extractedData.isPeruvianCriminalRecord = false;
    }

    // Extraer DNI del titular
    const dniMatches = fullText.match(/\b\d{8}\b/g);
    if (dniMatches && dniMatches.length > 0) {
      extractedData.holderDni = dniMatches[0];
      confidence += 0.2;
    }

    // Verificar si NO registra antecedentes
    if (upperText.includes('NO REGISTRA') || 
        upperText.includes('SIN ANTECEDENTES') ||
        upperText.includes('NO TIENE ANTECEDENTES')) {
      extractedData.hasRecord = false;
      confidence += 0.3;
    } else if (upperText.includes('REGISTRA') || upperText.includes('CON ANTECEDENTES')) {
      extractedData.hasRecord = true;
      errors.push('El certificado registra antecedentes penales');
      confidence += 0.2;
    }

    // Extraer fecha de emisión
    const dateMatches = fullText.match(/\b\d{2}\/\d{2}\/\d{4}\b/g);
    if (dateMatches && dateMatches.length > 0) {
      extractedData.issueDate = dateMatches[0];
      confidence += 0.1;
      
      // Verificar que no sea muy antiguo (máximo 30 días)
      try {
        const [day, month, year] = dateMatches[0].split('/').map(n => parseInt(n));
        const issueDate = new Date(year, month - 1, day);
        const now = new Date();
        const daysDiff = Math.floor((now - issueDate) / (1000 * 60 * 60 * 24));
        
        if (daysDiff <= 30) {
          confidence += 0.1;
        } else {
          errors.push(`Certificado muy antiguo (${daysDiff} días)`);
        }
      } catch (e) {
        errors.push('Error validando fecha de emisión');
      }
    }

    return {
      success: true,
      documentType: 'criminal_record',
      extractedData,
      confidence: Math.min(confidence, 1.0),
      errors,
      ocrText: fullText,
    };

  } catch (error) {
    console.error('Error analizando antecedentes penales:', error);
    return {
      success: false,
      error: error.message,
      extractedData: {},
      confidence: 0.0,
    };
  }
}

/**
 * Análisis genérico para documentos no específicos
 */
function analyzeGenericDocument(fullText, textAnnotations, documentType) {
  const extractedData = {};
  const errors = [];
  let confidence = 0.5; // Base confidence para documentos genéricos

  try {
    extractedData.fullText = fullText;
    extractedData.wordCount = fullText.split(/\s+/).length;
    extractedData.characterCount = fullText.length;

    // Extraer números
    const numbers = fullText.match(/\b\d+\b/g) || [];
    extractedData.extractedNumbers = numbers;

    // Extraer fechas
    const dates = fullText.match(/\b\d{2}\/\d{2}\/\d{4}\b/g) || [];
    extractedData.extractedDates = dates;

    // Validar longitud mínima del texto
    if (fullText.length > 100) {
      confidence += 0.2;
    } else {
      errors.push('Texto extraído insuficiente');
    }

    // Validar que contiene información relevante
    if (numbers.length > 0) {
      confidence += 0.1;
    }

    if (dates.length > 0) {
      confidence += 0.1;
    }

    return {
      success: true,
      documentType: 'generic',
      extractedData,
      confidence: Math.min(confidence, 1.0),
      errors,
      ocrText: fullText,
    };

  } catch (error) {
    console.error('Error analizando documento genérico:', error);
    return {
      success: false,
      error: error.message,
      extractedData: {},
      confidence: 0.0,
    };
  }
}

/**
 * Valida documentos con APIs de autoridades peruanas
 */
async function validateWithPeruvianAuthorities(analysisResult, documentType) {
  try {
    const validationResult = {
      validated: false,
      source: null,
      details: {},
      errors: [],
    };

    switch (documentType.toLowerCase()) {
      case 'dni':
        // Validar con RENIEC (simulado - en producción usar API real)
        if (analysisResult.extractedData.dniNumber) {
          validationResult.validated = await validateDniWithReniec(analysisResult.extractedData.dniNumber);
          validationResult.source = 'RENIEC';
        }
        break;

      case 'licensea':
      case 'licenseb':
        // Validar con MTC (simulado)
        if (analysisResult.extractedData.licenseNumber) {
          validationResult.validated = await validateLicenseWithMTC(analysisResult.extractedData.licenseNumber);
          validationResult.source = 'MTC';
        }
        break;

      case 'soat':
        // Validar con ASPEC o aseguradoras (simulado)
        if (analysisResult.extractedData.policyNumber) {
          validationResult.validated = await validateSoatWithASPEC(analysisResult.extractedData.policyNumber);
          validationResult.source = 'ASPEC';
        }
        break;

      case 'vehicleregistration':
        // Validar con SUNARP (simulado)
        if (analysisResult.extractedData.vehiclePlate) {
          validationResult.validated = await validateVehicleWithSUNARP(analysisResult.extractedData.vehiclePlate);
          validationResult.source = 'SUNARP';
        }
        break;

      default:
        validationResult.validated = true; // Sin validación específica
        validationResult.source = 'manual';
    }

    return validationResult;

  } catch (error) {
    console.error('Error validando con autoridades:', error);
    return {
      validated: false,
      source: null,
      details: {},
      errors: [error.message],
    };
  }
}

/**
 * Validación simulada con RENIEC
 * En producción, usar API real del RENIEC
 */
async function validateDniWithReniec(dniNumber) {
  try {
    // Validar formato básico
    if (!/^\d{8}$/.test(dniNumber)) {
      return false;
    }
    
    // Simulación: considerar válidos DNIs que no empiecen con 0 o 1
    return !dniNumber.startsWith('0') && !dniNumber.startsWith('1');
    
  } catch (error) {
    console.error('Error validando DNI con RENIEC:', error);
    return false;
  }
}

/**
 * Validación simulada con MTC
 */
async function validateLicenseWithMTC(licenseNumber) {
  try {
    // Simulación de validación con MTC
    return /^[A-Z]\d{8}$/.test(licenseNumber);
  } catch (error) {
    console.error('Error validando licencia con MTC:', error);
    return false;
  }
}

/**
 * Validación simulada con ASPEC
 */
async function validateSoatWithASPEC(policyNumber) {
  try {
    // Simulación de validación SOAT
    return policyNumber.length >= 10;
  } catch (error) {
    console.error('Error validando SOAT con ASPEC:', error);
    return false;
  }
}

/**
 * Validación simulada con SUNARP
 */
async function validateVehicleWithSUNARP(vehiclePlate) {
  try {
    // Simulación de validación con SUNARP
    return /^[A-Z]{2,3}-?\d{3,4}$/.test(vehiclePlate);
  } catch (error) {
    console.error('Error validando vehículo con SUNARP:', error);
    return false;
  }
}

/**
 * Calcula puntuación de confianza final
 */
function calculateFinalConfidenceScore(visionResults, analysisResult, validationResult) {
  try {
    let finalScore = analysisResult.confidence || 0.0;
    
    // Bonificar si fue validado con autoridades
    if (validationResult.validated) {
      finalScore += 0.2;
    }

    // Penalizar si hay muchos errores
    const errorCount = (analysisResult.errors || []).length;
    finalScore -= (errorCount * 0.1);

    // Bonificar calidad del texto OCR
    const textLength = visionResults.fullTextAnnotation?.text?.length || 0;
    if (textLength > 200) {
      finalScore += 0.1;
    }

    // Penalizar detección de contenido seguro problemático
    const safeSearch = visionResults.safeSearchAnnotation;
    if (safeSearch) {
      if (safeSearch.adult === 'LIKELY' || safeSearch.adult === 'VERY_LIKELY') {
        finalScore -= 0.5;
      }
      if (safeSearch.violence === 'LIKELY' || safeSearch.violence === 'VERY_LIKELY') {
        finalScore -= 0.3;
      }
    }

    return Math.max(0.0, Math.min(1.0, finalScore));

  } catch (error) {
    console.error('Error calculando puntuación final:', error);
    return 0.5;
  }
}

/**
 * Guarda resultado de procesamiento en Firestore
 */
async function saveProcessingResult(userId, processingData) {
  try {
    const docRef = await db.collection('document_vision_processing').add({
      userId,
      ...processingData,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      version: '1.0.0',
    });

    console.log(`Resultado guardado con ID: ${docRef.id}`);
    return docRef.id;

  } catch (error) {
    console.error('Error guardando resultado de procesamiento:', error);
    throw error;
  }
}

/**
 * Cloud Function para procesar múltiples documentos en lote
 */
exports.batchProcessDocuments = functions
  .runWith({
    timeoutSeconds: 540,
    memory: '4GB',
    maxInstances: 5
  })
  .https.onCall(async (data, context) => {
    try {
      if (!context.auth) {
        throw new functions.https.HttpsError(
          'unauthenticated',
          'Usuario debe estar autenticado'
        );
      }

      const { documents } = data;
      if (!documents || !Array.isArray(documents)) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Se requiere array de documentos'
        );
      }

      const results = [];
      
      for (const doc of documents) {
        try {
          const result = await exports.processDocumentVision.run(doc, context);
          results.push({
            documentId: doc.documentId,
            success: true,
            result: result.data,
          });
        } catch (error) {
          results.push({
            documentId: doc.documentId,
            success: false,
            error: error.message,
          });
        }
      }

      return {
        success: true,
        processed: results.length,
        results,
      };

    } catch (error) {
      console.error('Error en procesamiento por lotes:', error);
      throw new functions.https.HttpsError(
        'internal',
        `Error en procesamiento por lotes: ${error.message}`
      );
    }
  });

/**
 * Cloud Function para obtener estadísticas de procesamiento
 */
exports.getProcessingStats = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Usuario debe estar autenticado'
      );
    }

    const userId = context.auth.uid;
    const { period = '30d' } = data;

    // Calcular fecha de inicio según período
    const now = new Date();
    let startDate = new Date(now);
    
    switch (period) {
      case '7d':
        startDate.setDate(now.getDate() - 7);
        break;
      case '30d':
        startDate.setDate(now.getDate() - 30);
        break;
      case '90d':
        startDate.setDate(now.getDate() - 90);
        break;
      default:
        startDate.setDate(now.getDate() - 30);
    }

    // Consultar estadísticas
    const snapshot = await db
      .collection('document_vision_processing')
      .where('userId', '==', userId)
      .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(startDate))
      .get();

    const stats = {
      total: snapshot.docs.length,
      byType: {},
      byConfidence: { high: 0, medium: 0, low: 0 },
      validated: 0,
      averageConfidence: 0,
    };

    let totalConfidence = 0;

    snapshot.docs.forEach(doc => {
      const data = doc.data();
      
      // Contar por tipo
      const docType = data.analysisResult?.documentType || 'unknown';
      stats.byType[docType] = (stats.byType[docType] || 0) + 1;
      
      // Contar por confianza
      const confidence = data.finalScore || 0;
      totalConfidence += confidence;
      
      if (confidence >= 0.8) {
        stats.byConfidence.high++;
      } else if (confidence >= 0.6) {
        stats.byConfidence.medium++;
      } else {
        stats.byConfidence.low++;
      }
      
      // Contar validados
      if (data.validationResult?.validated) {
        stats.validated++;
      }
    });

    stats.averageConfidence = stats.total > 0 ? totalConfidence / stats.total : 0;

    return {
      success: true,
      period,
      stats,
    };

  } catch (error) {
    console.error('Error obteniendo estadísticas:', error);
    throw new functions.https.HttpsError(
      'internal',
      `Error obteniendo estadísticas: ${error.message}`
    );
  }
});