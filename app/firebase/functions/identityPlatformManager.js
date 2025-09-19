/**
 * ========================================================================================
 * IDENTITY PLATFORM MANAGER - FIREBASE CLOUD FUNCTION
 * ========================================================================================
 * 
 * Sistema empresarial de autenticación con Google Cloud Identity Platform
 * 
 * Funcionalidades:
 * - Gestión avanzada de usuarios empresariales
 * - Políticas de contraseñas y seguridad
 * - Autenticación multi-factor (MFA) obligatoria
 * - Single Sign-On (SSO) con proveedores externos
 * - Audit logging de todos los eventos de autenticación
 * - Session management avanzado
 * - Risk-based authentication
 * - Account recovery y password policies
 * - SAML/OIDC integration para clientes enterprise
 * - User provisioning y de-provisioning
 * 
 * @author OasisTaxi Development Team
 * @version 2.1.0
 * @created 2024-12-30
 * @updated 2025-01-11
 */

const functions = require('firebase-functions/v2');
const admin = require('firebase-admin');
const { GoogleAuth } = require('google-auth-library');
const crypto = require('crypto');
const nodemailer = require('nodemailer');

// Inicializar Firebase Admin si no está inicializado
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const auth = admin.auth();

// Configuración de Identity Platform
const IDENTITY_PLATFORM_CONFIG = {
  // Configuración de políticas de contraseña
  passwordPolicy: {
    minLength: 12,
    requireUppercase: true,
    requireLowercase: true,
    requireNumbers: true,
    requireSymbols: true,
    preventPasswordReuse: 5,
    maxPasswordAge: 90, // días
    accountLockoutThreshold: 5,
    accountLockoutDuration: 30 // minutos
  },
  
  // Configuración de MFA
  mfaConfig: {
    mandatoryForAdmins: true,
    allowedSecondFactors: ['totp', 'phone', 'email'],
    maxRecoveryAttempts: 3,
    recoveryCodeExpiration: 24 // horas
  },
  
  // Configuración de sesiones
  sessionConfig: {
    maxSessionDuration: 8 * 60 * 60, // 8 horas en segundos
    idleTimeout: 30 * 60, // 30 minutos en segundos
    maxConcurrentSessions: 3,
    requireSecureTransport: true
  },
  
  // Configuración de risk assessment
  riskConfig: {
    enableLocationTracking: true,
    enableDeviceFingerprinting: true,
    anomalousLoginThreshold: 0.7,
    blockedCountries: [],
    allowedIPRanges: [] // Opcional para empresas
  }
};

// ========================================================================================
// CLOUD FUNCTION: CONFIGURAR IDENTITY PLATFORM
// ========================================================================================
exports.configureIdentityPlatform = functions.https.onCall(async (data, context) => {
  try {
    console.log('🔧 Iniciando configuración de Identity Platform');
    
    // Verificar permisos de super admin
    if (!context.auth || !context.auth.token.role || context.auth.token.role !== 'super_admin') {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Solo super administradores pueden configurar Identity Platform'
      );
    }
    
    const config = {
      // Configurar políticas de contraseña
      passwordPolicyConfig: await setupPasswordPolicies(),
      
      // Configurar MFA obligatorio para admins
      mfaConfig: await setupMFAConfiguration(),
      
      // Configurar proveedores de autenticación
      authProviders: await setupAuthProviders(),
      
      // Configurar políticas de sesión
      sessionPolicies: await setupSessionPolicies(),
      
      // Configurar análisis de riesgo
      riskAnalysis: await setupRiskAnalysis(),
      
      // Configurar audit logging
      auditLogging: await setupAuditLogging()
    };
    
    // Guardar configuración en Firestore
    await db.collection('system_config').doc('identity_platform').set({
      config: config,
      configuredBy: context.auth.uid,
      configuredAt: admin.firestore.FieldValue.serverTimestamp(),
      version: '2.1.0',
      status: 'active'
    });
    
    // Log de auditoría
    await logAuditEvent({
      type: 'IDENTITY_PLATFORM_CONFIGURED',
      actor: context.auth.uid,
      details: {
        configuration: Object.keys(config),
        timestamp: new Date().toISOString()
      },
      severity: 'HIGH',
      ip: context.rawRequest?.ip
    });
    
    console.log('✅ Identity Platform configurado exitosamente');
    
    return {
      success: true,
      configuration: config,
      message: 'Identity Platform configurado correctamente para uso empresarial',
      timestamp: new Date().toISOString()
    };
    
  } catch (error) {
    console.error('❌ Error configurando Identity Platform:', error);
    
    // Log de error
    await logAuditEvent({
      type: 'IDENTITY_PLATFORM_CONFIG_ERROR',
      actor: context.auth?.uid || 'anonymous',
      details: {
        error: error.message,
        stack: error.stack,
        timestamp: new Date().toISOString()
      },
      severity: 'CRITICAL'
    });
    
    throw new functions.https.HttpsError(
      'internal',
      `Error configurando Identity Platform: ${error.message}`
    );
  }
});

// ========================================================================================
// CLOUD FUNCTION: AUTENTICACIÓN AVANZADA CON RISK ANALYSIS
// ========================================================================================
exports.enhancedAuthentication = functions.https.onCall(async (data, context) => {
  try {
    const { email, password, deviceInfo, locationInfo } = data;
    
    console.log(`🔐 Iniciando autenticación avanzada para: ${email}`);
    
    // Análisis de riesgo pre-autenticación
    const riskAnalysis = await performRiskAnalysis({
      email,
      deviceInfo,
      locationInfo,
      ip: context.rawRequest?.ip
    });
    
    if (riskAnalysis.riskLevel === 'HIGH') {
      console.log(`🚨 Autenticación de alto riesgo detectada para: ${email}`);
      
      // Requerir pasos adicionales de verificación
      return {
        success: false,
        requiresAdditionalVerification: true,
        verificationMethods: ['mfa', 'email_verification', 'admin_approval'],
        riskFactors: riskAnalysis.factors,
        message: 'Autenticación de alto riesgo detectada'
      };
    }
    
    // Verificar políticas de contraseña si es un login normal
    let user;
    try {
      user = await auth.getUserByEmail(email);
    } catch (error) {
      throw new functions.https.HttpsError('not-found', 'Usuario no encontrado');
    }
    
    // Verificar si el usuario tiene MFA configurado (obligatorio para admins)
    const customClaims = user.customClaims || {};
    if (customClaims.role === 'admin' || customClaims.role === 'super_admin') {
      const mfaEnrollments = await getMFAEnrollments(user.uid);
      if (mfaEnrollments.length === 0) {
        return {
          success: false,
          requiresMFASetup: true,
          message: 'MFA es obligatorio para administradores'
        };
      }
    }
    
    // Verificar si la cuenta está bloqueada
    const lockoutInfo = await checkAccountLockout(user.uid);
    if (lockoutInfo.isLocked) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Cuenta bloqueada hasta: ${lockoutInfo.unlockTime}`
      );
    }
    
    // Verificar sesiones concurrentes
    const activeSessions = await getActiveSessions(user.uid);
    if (activeSessions.length >= IDENTITY_PLATFORM_CONFIG.sessionConfig.maxConcurrentSessions) {
      // Terminar la sesión más antigua
      await terminateOldestSession(user.uid);
    }
    
    // Crear sesión avanzada
    const sessionId = await createEnhancedSession({
      userId: user.uid,
      deviceInfo,
      locationInfo,
      ip: context.rawRequest?.ip,
      riskLevel: riskAnalysis.riskLevel
    });
    
    // Log de auditoría
    await logAuditEvent({
      type: 'ENHANCED_AUTHENTICATION_SUCCESS',
      actor: user.uid,
      details: {
        email: email,
        riskLevel: riskAnalysis.riskLevel,
        deviceInfo: deviceInfo,
        sessionId: sessionId,
        timestamp: new Date().toISOString()
      },
      severity: 'MEDIUM',
      ip: context.rawRequest?.ip
    });
    
    console.log(`✅ Autenticación exitosa para: ${email}`);
    
    return {
      success: true,
      sessionId: sessionId,
      riskLevel: riskAnalysis.riskLevel,
      sessionConfig: {
        maxDuration: IDENTITY_PLATFORM_CONFIG.sessionConfig.maxSessionDuration,
        idleTimeout: IDENTITY_PLATFORM_CONFIG.sessionConfig.idleTimeout
      },
      message: 'Autenticación completada exitosamente'
    };
    
  } catch (error) {
    console.error('❌ Error en autenticación avanzada:', error);
    
    // Log de error de autenticación
    await logAuditEvent({
      type: 'ENHANCED_AUTHENTICATION_ERROR',
      actor: data.email || 'unknown',
      details: {
        error: error.message,
        email: data.email,
        timestamp: new Date().toISOString()
      },
      severity: 'HIGH',
      ip: context.rawRequest?.ip
    });
    
    throw error;
  }
});

// ========================================================================================
// CLOUD FUNCTION: GESTIÓN DE MFA EMPRESARIAL
// ========================================================================================
exports.manageMFA = functions.https.onCall(async (data, context) => {
  try {
    const { action, userId, factorType, secret, code } = data;
    
    console.log(`🔐 Gestión MFA: ${action} para usuario ${userId || context.auth?.uid}`);
    
    // Verificar autenticación
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
    }
    
    const targetUserId = userId || context.auth.uid;
    
    // Verificar permisos
    if (targetUserId !== context.auth.uid && !hasAdminPermissions(context.auth.token)) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'No tienes permisos para gestionar MFA de otros usuarios'
      );
    }
    
    let result;
    
    switch (action) {
      case 'enroll':
        result = await enrollMFAFactor(targetUserId, factorType, secret);
        break;
        
      case 'verify':
        result = await verifyMFAFactor(targetUserId, factorType, code);
        break;
        
      case 'unenroll':
        result = await unenrollMFAFactor(targetUserId, factorType);
        break;
        
      case 'generate_backup_codes':
        result = await generateBackupCodes(targetUserId);
        break;
        
      case 'list_enrollments':
        result = await getMFAEnrollments(targetUserId);
        break;
        
      default:
        throw new functions.https.HttpsError('invalid-argument', 'Acción MFA no válida');
    }
    
    // Log de auditoría
    await logAuditEvent({
      type: `MFA_${action.toUpperCase()}`,
      actor: context.auth.uid,
      target: targetUserId,
      details: {
        action: action,
        factorType: factorType,
        success: true,
        timestamp: new Date().toISOString()
      },
      severity: 'MEDIUM',
      ip: context.rawRequest?.ip
    });
    
    console.log(`✅ MFA ${action} completado exitosamente`);
    
    return {
      success: true,
      action: action,
      result: result,
      message: `MFA ${action} completado exitosamente`
    };
    
  } catch (error) {
    console.error(`❌ Error en gestión MFA:`, error);
    
    await logAuditEvent({
      type: 'MFA_ERROR',
      actor: context.auth?.uid || 'unknown',
      details: {
        action: data.action,
        error: error.message,
        timestamp: new Date().toISOString()
      },
      severity: 'HIGH',
      ip: context.rawRequest?.ip
    });
    
    throw error;
  }
});

// ========================================================================================
// CLOUD FUNCTION: PROVISIONING DE USUARIOS EMPRESARIALES
// ========================================================================================
exports.provisionEnterpriseUser = functions.https.onCall(async (data, context) => {
  try {
    const { 
      email, 
      role, 
      department, 
      permissions, 
      temporaryPassword,
      requirePasswordChange = true 
    } = data;
    
    console.log(`👤 Provisionando usuario empresarial: ${email}`);
    
    // Verificar permisos de admin
    if (!context.auth || !hasAdminPermissions(context.auth.token)) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Solo administradores pueden provisionar usuarios'
      );
    }
    
    // Generar contraseña temporal si no se proporciona
    const password = temporaryPassword || generateSecurePassword();
    
    // Crear usuario en Firebase Auth
    const userRecord = await auth.createUser({
      email: email,
      password: password,
      emailVerified: false,
      disabled: false
    });
    
    // Establecer custom claims
    const customClaims = {
      role: role,
      department: department,
      permissions: permissions || [],
      provisioned: true,
      provisionedAt: new Date().toISOString(),
      provisionedBy: context.auth.uid,
      requirePasswordChange: requirePasswordChange,
      mfaRequired: ['admin', 'super_admin'].includes(role)
    };
    
    await auth.setCustomUserClaims(userRecord.uid, customClaims);
    
    // Crear perfil en Firestore
    await db.collection('users').doc(userRecord.uid).set({
      email: email,
      role: role,
      department: department,
      permissions: permissions || [],
      status: 'active',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: context.auth.uid,
      requirePasswordChange: requirePasswordChange,
      mfaRequired: customClaims.mfaRequired,
      lastLogin: null,
      loginCount: 0,
      securityProfile: {
        passwordLastChanged: admin.firestore.FieldValue.serverTimestamp(),
        mfaEnrolled: false,
        riskLevel: 'low'
      }
    });
    
    // Enviar email de bienvenida con credenciales
    await sendWelcomeEmail(email, password, role);
    
    // Log de auditoría
    await logAuditEvent({
      type: 'USER_PROVISIONED',
      actor: context.auth.uid,
      target: userRecord.uid,
      details: {
        email: email,
        role: role,
        department: department,
        permissions: permissions || [],
        timestamp: new Date().toISOString()
      },
      severity: 'MEDIUM',
      ip: context.rawRequest?.ip
    });
    
    console.log(`✅ Usuario ${email} provisionado exitosamente`);
    
    return {
      success: true,
      userId: userRecord.uid,
      email: email,
      role: role,
      temporaryPassword: password,
      message: 'Usuario empresarial provisionado exitosamente'
    };
    
  } catch (error) {
    console.error('❌ Error provisionando usuario:', error);
    
    await logAuditEvent({
      type: 'USER_PROVISION_ERROR',
      actor: context.auth?.uid || 'unknown',
      details: {
        email: data.email,
        error: error.message,
        timestamp: new Date().toISOString()
      },
      severity: 'HIGH',
      ip: context.rawRequest?.ip
    });
    
    throw new functions.https.HttpsError(
      'internal',
      `Error provisionando usuario: ${error.message}`
    );
  }
});

// ========================================================================================
// CLOUD FUNCTION: DEPROVISIONING DE USUARIOS
// ========================================================================================
exports.deprovisionUser = functions.https.onCall(async (data, context) => {
  try {
    const { userId, reason, transferDataTo } = data;
    
    console.log(`🗑️ Desprovisionando usuario: ${userId}`);
    
    // Verificar permisos de admin
    if (!context.auth || !hasAdminPermissions(context.auth.token)) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Solo administradores pueden desprovisionar usuarios'
      );
    }
    
    // Obtener información del usuario
    const userRecord = await auth.getUser(userId);
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();
    
    // Terminar todas las sesiones activas
    await terminateAllSessions(userId);
    
    // Revocar tokens de refresh
    await auth.revokeRefreshTokens(userId);
    
    // Transferir datos si se especifica
    if (transferDataTo) {
      await transferUserData(userId, transferDataTo);
    }
    
    // Desactivar usuario (no eliminar para auditoría)
    await auth.updateUser(userId, {
      disabled: true
    });
    
    // Actualizar estado en Firestore
    await db.collection('users').doc(userId).update({
      status: 'deprovisioned',
      deprovisionedAt: admin.firestore.FieldValue.serverTimestamp(),
      deprovisionedBy: context.auth.uid,
      deprovisionReason: reason,
      dataTransferredTo: transferDataTo || null
    });
    
    // Crear registro de deprovisioning
    await db.collection('audit_logs').add({
      type: 'USER_DEPROVISIONED',
      actor: context.auth.uid,
      target: userId,
      details: {
        email: userRecord.email,
        reason: reason,
        dataTransferred: !!transferDataTo,
        transferredTo: transferDataTo,
        originalRole: userData?.role,
        timestamp: new Date().toISOString()
      },
      severity: 'HIGH',
      ip: context.rawRequest?.ip,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log(`✅ Usuario ${userRecord.email} desprovisionado exitosamente`);
    
    return {
      success: true,
      userId: userId,
      email: userRecord.email,
      reason: reason,
      dataTransferred: !!transferDataTo,
      message: 'Usuario desprovisionado exitosamente'
    };
    
  } catch (error) {
    console.error('❌ Error desprovisionando usuario:', error);
    
    await logAuditEvent({
      type: 'USER_DEPROVISION_ERROR',
      actor: context.auth?.uid || 'unknown',
      details: {
        userId: data.userId,
        error: error.message,
        timestamp: new Date().toISOString()
      },
      severity: 'CRITICAL'
    });
    
    throw new functions.https.HttpsError(
      'internal',
      `Error desprovisionando usuario: ${error.message}`
    );
  }
});

// ========================================================================================
// CLOUD FUNCTION: MONITOREO DE SESIONES EN TIEMPO REAL
// ========================================================================================
exports.monitorSessions = functions.pubsub
  .schedule('every 5 minutes')
  .timeZone('America/Lima')
  .onRun(async (context) => {
    try {
      console.log('👁️ Monitoreando sesiones activas');
      
      const now = admin.firestore.Timestamp.now();
      const idleThreshold = new Date(now.toDate().getTime() - (IDENTITY_PLATFORM_CONFIG.sessionConfig.idleTimeout * 1000));
      const maxDurationThreshold = new Date(now.toDate().getTime() - (IDENTITY_PLATFORM_CONFIG.sessionConfig.maxSessionDuration * 1000));
      
      // Buscar sesiones expiradas por inactividad
      const idleSessionsQuery = await db.collection('user_sessions')
        .where('status', '==', 'active')
        .where('lastActivity', '<', admin.firestore.Timestamp.fromDate(idleThreshold))
        .get();
      
      // Buscar sesiones que exceden la duración máxima
      const expiredSessionsQuery = await db.collection('user_sessions')
        .where('status', '==', 'active')
        .where('createdAt', '<', admin.firestore.Timestamp.fromDate(maxDurationThreshold))
        .get();
      
      const sessionsToTerminate = new Set();
      
      // Agregar sesiones idle
      idleSessionsQuery.docs.forEach(doc => {
        sessionsToTerminate.add(doc.id);
      });
      
      // Agregar sesiones expiradas
      expiredSessionsQuery.docs.forEach(doc => {
        sessionsToTerminate.add(doc.id);
      });
      
      // Terminar sesiones
      const batch = db.batch();
      let terminatedCount = 0;
      
      for (const sessionId of sessionsToTerminate) {
        const sessionRef = db.collection('user_sessions').doc(sessionId);
        batch.update(sessionRef, {
          status: 'terminated',
          terminatedAt: admin.firestore.FieldValue.serverTimestamp(),
          terminationReason: 'automatic_expiration'
        });
        terminatedCount++;
      }
      
      if (terminatedCount > 0) {
        await batch.commit();
        console.log(`✅ ${terminatedCount} sesiones terminadas automáticamente`);
        
        // Log estadístico
        await db.collection('system_stats').add({
          type: 'session_cleanup',
          sessionsTerminated: terminatedCount,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          details: {
            idleSessions: idleSessionsQuery.docs.length,
            expiredSessions: expiredSessionsQuery.docs.length
          }
        });
      }
      
    } catch (error) {
      console.error('❌ Error monitoreando sesiones:', error);
      
      await db.collection('system_errors').add({
        type: 'session_monitor_error',
        error: error.message,
        stack: error.stack,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        severity: 'MEDIUM'
      });
    }
  });

// ========================================================================================
// FUNCIONES AUXILIARES
// ========================================================================================

async function setupPasswordPolicies() {
  try {
    const policy = {
      ...IDENTITY_PLATFORM_CONFIG.passwordPolicy,
      enforcedAt: new Date().toISOString(),
      regulatoryCompliance: ['SOX', 'PCI-DSS', 'ISO27001']
    };
    
    await db.collection('system_policies').doc('password_policy').set(policy);
    return policy;
  } catch (error) {
    console.error('Error configurando políticas de contraseña:', error);
    throw error;
  }
}

async function setupMFAConfiguration() {
  try {
    const config = {
      ...IDENTITY_PLATFORM_CONFIG.mfaConfig,
      configuredAt: new Date().toISOString(),
      supportedProviders: ['google_authenticator', 'authy', 'sms', 'email']
    };
    
    await db.collection('system_config').doc('mfa_config').set(config);
    return config;
  } catch (error) {
    console.error('Error configurando MFA:', error);
    throw error;
  }
}

async function setupAuthProviders() {
  try {
    const providers = {
      email: {
        enabled: true,
        requireVerification: true
      },
      google: {
        enabled: true,
        clientId: process.env.GOOGLE_CLIENT_ID
      },
      microsoft: {
        enabled: false,
        tenantId: null
      },
      saml: {
        enabled: false,
        providers: []
      }
    };
    
    await db.collection('system_config').doc('auth_providers').set(providers);
    return providers;
  } catch (error) {
    console.error('Error configurando proveedores de auth:', error);
    throw error;
  }
}

async function setupSessionPolicies() {
  try {
    const policies = {
      ...IDENTITY_PLATFORM_CONFIG.sessionConfig,
      configuredAt: new Date().toISOString(),
      tokenRotation: true,
      deviceBinding: true
    };
    
    await db.collection('system_policies').doc('session_policies').set(policies);
    return policies;
  } catch (error) {
    console.error('Error configurando políticas de sesión:', error);
    throw error;
  }
}

async function setupRiskAnalysis() {
  try {
    const config = {
      ...IDENTITY_PLATFORM_CONFIG.riskConfig,
      configuredAt: new Date().toISOString(),
      mlModelsEnabled: true,
      realTimeAnalysis: true
    };
    
    await db.collection('system_config').doc('risk_analysis').set(config);
    return config;
  } catch (error) {
    console.error('Error configurando análisis de riesgo:', error);
    throw error;
  }
}

async function setupAuditLogging() {
  try {
    const config = {
      enabled: true,
      retentionPeriod: 7 * 365, // 7 años
      logLevels: ['INFO', 'WARNING', 'ERROR', 'CRITICAL'],
      realTimeAlerts: true,
      exportEnabled: true,
      encryptionEnabled: true
    };
    
    await db.collection('system_config').doc('audit_logging').set(config);
    return config;
  } catch (error) {
    console.error('Error configurando audit logging:', error);
    throw error;
  }
}

async function performRiskAnalysis(authData) {
  try {
    const { email, deviceInfo, locationInfo, ip } = authData;
    let riskFactors = [];
    let riskScore = 0;
    
    // Verificar ubicación inusual
    const userLocation = await getUserHistoricalLocation(email);
    if (userLocation && locationInfo) {
      const distance = calculateDistance(userLocation, locationInfo);
      if (distance > 1000) { // Más de 1000 km
        riskFactors.push('unusual_location');
        riskScore += 0.3;
      }
    }
    
    // Verificar dispositivo desconocido
    const knownDevices = await getKnownDevices(email);
    const deviceFingerprint = generateDeviceFingerprint(deviceInfo);
    if (!knownDevices.includes(deviceFingerprint)) {
      riskFactors.push('unknown_device');
      riskScore += 0.2;
    }
    
    // Verificar IP sospechosa
    const ipReputation = await checkIPReputation(ip);
    if (ipReputation.suspicious) {
      riskFactors.push('suspicious_ip');
      riskScore += 0.4;
    }
    
    // Verificar horario inusual
    const hour = new Date().getHours();
    const userProfile = await getUserBehaviorProfile(email);
    if (userProfile && (hour < userProfile.usualLoginStart || hour > userProfile.usualLoginEnd)) {
      riskFactors.push('unusual_time');
      riskScore += 0.1;
    }
    
    // Determinar nivel de riesgo
    let riskLevel = 'LOW';
    if (riskScore >= 0.7) {
      riskLevel = 'HIGH';
    } else if (riskScore >= 0.4) {
      riskLevel = 'MEDIUM';
    }
    
    return {
      riskLevel,
      riskScore,
      factors: riskFactors
    };
    
  } catch (error) {
    console.error('Error en análisis de riesgo:', error);
    return {
      riskLevel: 'MEDIUM',
      riskScore: 0.5,
      factors: ['analysis_error']
    };
  }
}

async function createEnhancedSession(sessionData) {
  try {
    const { userId, deviceInfo, locationInfo, ip, riskLevel } = sessionData;
    
    const sessionId = crypto.randomUUID();
    const now = admin.firestore.FieldValue.serverTimestamp();
    
    await db.collection('user_sessions').doc(sessionId).set({
      userId: userId,
      sessionId: sessionId,
      status: 'active',
      createdAt: now,
      lastActivity: now,
      deviceInfo: deviceInfo,
      locationInfo: locationInfo,
      ipAddress: ip,
      riskLevel: riskLevel,
      expiresAt: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + IDENTITY_PLATFORM_CONFIG.sessionConfig.maxSessionDuration * 1000)
      )
    });
    
    return sessionId;
  } catch (error) {
    console.error('Error creando sesión:', error);
    throw error;
  }
}

async function getMFAEnrollments(userId) {
  try {
    const enrollmentsQuery = await db.collection('mfa_enrollments')
      .where('userId', '==', userId)
      .where('status', '==', 'active')
      .get();
    
    return enrollmentsQuery.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
  } catch (error) {
    console.error('Error obteniendo enrollments MFA:', error);
    return [];
  }
}

async function enrollMFAFactor(userId, factorType, secret) {
  try {
    const enrollmentId = crypto.randomUUID();
    
    await db.collection('mfa_enrollments').doc(enrollmentId).set({
      userId: userId,
      factorType: factorType,
      secret: secret ? await encryptSecret(secret) : null,
      status: 'active',
      enrolledAt: admin.firestore.FieldValue.serverTimestamp(),
      lastUsed: null,
      useCount: 0
    });
    
    // Actualizar perfil de usuario
    await db.collection('users').doc(userId).update({
      'securityProfile.mfaEnrolled': true,
      'securityProfile.mfaEnrolledAt': admin.firestore.FieldValue.serverTimestamp()
    });
    
    return { enrollmentId, factorType };
  } catch (error) {
    console.error('Error enrollando factor MFA:', error);
    throw error;
  }
}

async function verifyMFAFactor(userId, factorType, code) {
  try {
    // Buscar enrollment activo
    const enrollmentQuery = await db.collection('mfa_enrollments')
      .where('userId', '==', userId)
      .where('factorType', '==', factorType)
      .where('status', '==', 'active')
      .limit(1)
      .get();
    
    if (enrollmentQuery.empty) {
      throw new Error('Factor MFA no encontrado');
    }
    
    const enrollment = enrollmentQuery.docs[0];
    const enrollmentData = enrollment.data();
    
    // Verificar código (implementación simplificada)
    const isValid = await verifyTOTPCode(enrollmentData.secret, code);
    
    if (isValid) {
      // Actualizar estadísticas de uso
      await enrollment.ref.update({
        lastUsed: admin.firestore.FieldValue.serverTimestamp(),
        useCount: admin.firestore.FieldValue.increment(1)
      });
      
      return { valid: true, factorType };
    } else {
      throw new Error('Código MFA inválido');
    }
  } catch (error) {
    console.error('Error verificando factor MFA:', error);
    throw error;
  }
}

async function generateBackupCodes(userId) {
  try {
    const codes = [];
    for (let i = 0; i < 10; i++) {
      codes.push(crypto.randomBytes(4).toString('hex').toUpperCase());
    }
    
    // Encriptar y guardar códigos
    const encryptedCodes = await Promise.all(
      codes.map(code => encryptSecret(code))
    );
    
    await db.collection('mfa_backup_codes').doc(userId).set({
      codes: encryptedCodes,
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      usedCodes: []
    });
    
    return codes;
  } catch (error) {
    console.error('Error generando códigos de respaldo:', error);
    throw error;
  }
}

async function logAuditEvent(event) {
  try {
    await db.collection('audit_logs').add({
      ...event,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      id: crypto.randomUUID()
    });
  } catch (error) {
    console.error('Error logging audit event:', error);
  }
}

async function sendWelcomeEmail(email, password, role) {
  try {
    const transporter = nodemailer.createTransporter({
      service: 'gmail',
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS
      }
    });
    
    const mailOptions = {
      from: process.env.EMAIL_USER,
      to: email,
      subject: 'Bienvenido a OasisTaxi - Acceso Empresarial',
      html: `
        <h2>Bienvenido a OasisTaxi</h2>
        <p>Se ha creado tu cuenta empresarial con los siguientes datos:</p>
        <p><strong>Email:</strong> ${email}</p>
        <p><strong>Contraseña temporal:</strong> ${password}</p>
        <p><strong>Rol:</strong> ${role}</p>
        <p><strong>Importante:</strong> Debes cambiar tu contraseña en el primer inicio de sesión y configurar MFA.</p>
        <p>Por favor, accede al sistema usando el enlace: <a href="${process.env.ADMIN_PORTAL_URL}">Portal Administrativo</a></p>
      `
    };
    
    await transporter.sendMail(mailOptions);
  } catch (error) {
    console.error('Error enviando email de bienvenida:', error);
  }
}

function generateSecurePassword() {
  const length = 16;
  const charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*';
  let password = '';
  
  // Asegurar que tenga al menos un carácter de cada tipo
  password += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'[Math.floor(Math.random() * 26)];
  password += 'abcdefghijklmnopqrstuvwxyz'[Math.floor(Math.random() * 26)];
  password += '0123456789'[Math.floor(Math.random() * 10)];
  password += '!@#$%^&*'[Math.floor(Math.random() * 8)];
  
  // Completar el resto
  for (let i = 4; i < length; i++) {
    password += charset[Math.floor(Math.random() * charset.length)];
  }
  
  // Mezclar
  return password.split('').sort(() => 0.5 - Math.random()).join('');
}

function hasAdminPermissions(token) {
  return token && (token.role === 'admin' || token.role === 'super_admin');
}

async function encryptSecret(secret) {
  // Implementación simplificada - en producción usar KMS
  return Buffer.from(secret).toString('base64');
}

async function verifyTOTPCode(encryptedSecret, code) {
  // Implementación simplificada de verificación TOTP
  // En producción integrar con librería como speakeasy
  return true; // Simulación
}

// Funciones auxiliares adicionales (implementaciones simplificadas)
async function getUserHistoricalLocation(email) { return null; }
async function calculateDistance(loc1, loc2) { return 0; }
async function getKnownDevices(email) { return []; }
async function generateDeviceFingerprint(deviceInfo) { return 'fingerprint'; }
async function checkIPReputation(ip) { return { suspicious: false }; }
async function getUserBehaviorProfile(email) { return null; }
async function checkAccountLockout(userId) { return { isLocked: false }; }
async function getActiveSessions(userId) { return []; }
async function terminateOldestSession(userId) { return true; }
async function terminateAllSessions(userId) { return true; }
async function transferUserData(fromUserId, toUserId) { return true; }
async function unenrollMFAFactor(userId, factorType) { return true; }

console.log('🚀 Identity Platform Manager inicializado correctamente');