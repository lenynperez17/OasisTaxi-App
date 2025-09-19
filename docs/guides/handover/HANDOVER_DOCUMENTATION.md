# 🤝 HANDOVER DOCUMENTATION - OASISTÁXI PERÚ
## Documentación Completa de Transferencia y Entrenamiento
### Versión 1.0 - Ecosistema Google Cloud Platform

---

## 📋 TABLA DE CONTENIDOS

1. [GCP Console Walkthrough](#gcp-console-walkthrough)
2. [Firebase Console Training](#firebase-console-training)
3. [Cloud Functions Review](#cloud-functions-review)
4. [Monitoring Setup](#monitoring-setup)
5. [Incident Response](#incident-response)
6. [Cost Management](#cost-management)
7. [Scaling Procedures](#scaling-procedures)
8. [Daily Operations Guide](#daily-operations-guide)
9. [Troubleshooting Guide](#troubleshooting-guide)
10. [Emergency Procedures](#emergency-procedures)

---

## 1. GCP CONSOLE WALKTHROUGH

### 1.1 Acceso Inicial y Navegación
```yaml
URL Principal: https://console.cloud.google.com
Proyecto: oasis-taxi-peru
Region Principal: us-central1
```

### 1.2 Dashboard Principal - Elementos Clave
```typescript
// Configuración del Dashboard Personalizado
export class GCPDashboardGuide {
  static readonly ESSENTIAL_WIDGETS = {
    // Widget 1: Estado del Sistema
    SYSTEM_STATUS: {
      location: 'Top Left',
      metrics: [
        'Cloud Run service health',
        'Firestore operations/sec',
        'Active users count',
        'Error rate percentage'
      ],
      refreshRate: '1 minute'
    },
    
    // Widget 2: Métricas de Negocio
    BUSINESS_METRICS: {
      location: 'Top Right',
      metrics: [
        'Active trips',
        'Revenue today',
        'Completed trips',
        'Driver availability'
      ],
      customQuery: `
        SELECT 
          COUNT(CASE WHEN status = 'ongoing' THEN 1 END) as active_trips,
          SUM(CASE WHEN DATE(created_at) = CURRENT_DATE() THEN fare END) as revenue_today,
          COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_trips
        FROM trips
        WHERE DATE(created_at) = CURRENT_DATE()
      `
    },
    
    // Widget 3: Alertas Activas
    ACTIVE_ALERTS: {
      location: 'Center',
      source: 'Cloud Monitoring',
      filter: 'severity >= WARNING',
      autoRefresh: true
    },
    
    // Widget 4: Costos en Tiempo Real
    COST_TRACKING: {
      location: 'Bottom',
      metrics: [
        'Daily spend',
        'Monthly projection',
        'Budget utilization',
        'Top costly services'
      ]
    }
  };

  // Navegación Rápida - Atajos Importantes
  static readonly QUICK_NAVIGATION = {
    PRODUCTION_SERVICES: [
      {
        name: 'API Gateway',
        path: '/apis-services/api/oasistáxi-api',
        criticalMetrics: ['Latency', 'Error rate', 'QPS']
      },
      {
        name: 'Cloud Run Services',
        path: '/run',
        services: [
          'trip-service',
          'payment-service',
          'notification-service',
          'matching-service'
        ]
      },
      {
        name: 'Firestore Database',
        path: '/firestore/data',
        collections: [
          'users',
          'trips',
          'drivers',
          'payments',
          'price_negotiations'
        ]
      }
    ],
    
    MONITORING_TOOLS: [
      {
        name: 'Cloud Monitoring',
        path: '/monitoring',
        dashboards: [
          'Executive Overview',
          'Technical Metrics',
          'Business KPIs',
          'Real-time Operations'
        ]
      },
      {
        name: 'Cloud Logging',
        path: '/logs/query',
        savedQueries: [
          'Error logs last hour',
          'Payment failures',
          'Slow API calls',
          'User authentication issues'
        ]
      },
      {
        name: 'Error Reporting',
        path: '/errors',
        filters: 'service:production AND resolved:false'
      }
    ]
  };
}
```

### 1.3 Configuración de IAM y Permisos
```typescript
// Roles y Permisos Recomendados
export class IAMConfiguration {
  static readonly ROLE_DEFINITIONS = {
    // Administrador del Sistema
    SYSTEM_ADMIN: {
      email: 'admin@oasistaxiperu.com',
      roles: [
        'roles/owner',  // Solo para emergencias
        'roles/iam.securityAdmin'
      ],
      description: 'Acceso completo para gestión de emergencias'
    },
    
    // Desarrollador Senior
    SENIOR_DEVELOPER: {
      email: 'dev-lead@oasistaxiperu.com',
      roles: [
        'roles/editor',
        'roles/cloudfunctions.developer',
        'roles/cloudrun.admin',
        'roles/firestore.owner'
      ],
      description: 'Desarrollo y deployment de servicios'
    },
    
    // Equipo de Operaciones
    OPERATIONS_TEAM: {
      email: 'ops-team@oasistaxiperu.com',
      roles: [
        'roles/monitoring.editor',
        'roles/logging.viewer',
        'roles/cloudtrace.user',
        'roles/errorreporting.user'
      ],
      description: 'Monitoreo y respuesta a incidentes'
    },
    
    // Analista de Datos
    DATA_ANALYST: {
      email: 'analytics@oasistaxiperu.com',
      roles: [
        'roles/bigquery.dataViewer',
        'roles/bigquery.jobUser',
        'roles/datastudio.viewer'
      ],
      description: 'Análisis y reportes'
    },
    
    // Soporte Técnico
    TECH_SUPPORT: {
      email: 'support@oasistaxiperu.com',
      roles: [
        'roles/firestore.viewer',
        'roles/logging.viewer',
        'roles/monitoring.viewer'
      ],
      description: 'Soporte a usuarios y debugging básico'
    }
  };

  // Script para configurar IAM
  static setupIAMRoles() {
    return `
#!/bin/bash
# Setup IAM roles for OasisTaxi

PROJECT_ID="oasis-taxi-peru"

# Función para agregar rol
add_role() {
  local email=$1
  local role=$2
  echo "Agregando $role a $email..."
  gcloud projects add-iam-policy-binding $PROJECT_ID \\
    --member="user:$email" \\
    --role="$role"
}

# Configurar System Admin
add_role "admin@oasistaxiperu.com" "roles/owner"
add_role "admin@oasistaxiperu.com" "roles/iam.securityAdmin"

# Configurar Senior Developer
add_role "dev-lead@oasistaxiperu.com" "roles/editor"
add_role "dev-lead@oasistaxiperu.com" "roles/cloudfunctions.developer"
add_role "dev-lead@oasistaxiperu.com" "roles/cloudrun.admin"
add_role "dev-lead@oasistaxiperu.com" "roles/firestore.owner"

# Configurar Operations Team
add_role "ops-team@oasistaxiperu.com" "roles/monitoring.editor"
add_role "ops-team@oasistaxiperu.com" "roles/logging.viewer"

echo "✅ Configuración IAM completada"
    `;
  }
}
```

### 1.4 Servicios Críticos - Checklist Diario
```typescript
export class DailyServiceCheck {
  static readonly CRITICAL_SERVICES = {
    CLOUD_RUN: {
      services: [
        {
          name: 'trip-service',
          url: 'https://trip-service-xxxxx-uc.a.run.app',
          healthCheck: '/health',
          expectedStatus: 200,
          maxLatency: 500, // ms
          minInstances: 2,
          maxInstances: 100
        },
        {
          name: 'payment-service',
          url: 'https://payment-service-xxxxx-uc.a.run.app',
          healthCheck: '/health',
          expectedStatus: 200,
          maxLatency: 300,
          minInstances: 1,
          maxInstances: 50
        }
      ],
      checkScript: `
        # Verificar servicios Cloud Run
        for service in trip-service payment-service notification-service; do
          echo "Checking $service..."
          STATUS=$(gcloud run services describe $service --region=us-central1 --format="value(status.conditions[0].status)")
          if [ "$STATUS" = "True" ]; then
            echo "✅ $service is healthy"
          else
            echo "❌ $service has issues"
          fi
        done
      `
    },
    
    FIRESTORE: {
      databases: ['(default)'],
      criticalCollections: [
        'users',
        'trips',
        'drivers',
        'payments',
        'price_negotiations'
      ],
      healthCheck: async () => {
        const admin = require('firebase-admin');
        const db = admin.firestore();
        
        // Test write
        const testDoc = await db.collection('health_check').add({
          timestamp: new Date(),
          status: 'checking'
        });
        
        // Test read
        const snapshot = await testDoc.get();
        
        // Clean up
        await testDoc.delete();
        
        return snapshot.exists;
      }
    },
    
    CLOUD_STORAGE: {
      buckets: [
        'oasis-taxi-peru.appspot.com',
        'oasis-taxi-peru-backups',
        'oasis-taxi-peru-exports'
      ],
      criticalFolders: [
        'user-documents/',
        'driver-documents/',
        'trip-receipts/',
        'profile-pictures/'
      ]
    }
  };
}
```

---

## 2. FIREBASE CONSOLE TRAINING

### 2.1 Navegación Firebase Console
```typescript
export class FirebaseConsoleGuide {
  static readonly CONSOLE_URL = 'https://console.firebase.google.com/project/oasis-taxi-peru';
  
  static readonly MAIN_SECTIONS = {
    AUTHENTICATION: {
      path: '/authentication/users',
      keyFeatures: [
        'User management',
        'Auth providers configuration',
        'User activity monitoring',
        'Custom claims management'
      ],
      commonTasks: {
        disableUser: `
          1. Go to Authentication > Users
          2. Find user by email/phone
          3. Click ⋮ menu > Disable account
          4. Confirm action
        `,
        resetPassword: `
          1. Authentication > Users
          2. Search user
          3. Click ⋮ > Reset password
          4. Email will be sent automatically
        `,
        setCustomClaims: `
          // Via Admin SDK
          admin.auth().setCustomUserClaims(uid, {
            role: 'driver',
            verified: true,
            tier: 'premium'
          });
        `
      }
    },
    
    FIRESTORE: {
      path: '/firestore/data',
      keyCollections: {
        users: {
          structure: {
            uid: 'string',
            email: 'string',
            phone: 'string',
            userType: 'passenger|driver|admin',
            createdAt: 'timestamp',
            profile: {
              name: 'string',
              photo: 'string',
              rating: 'number'
            }
          },
          indexes: [
            'userType_createdAt',
            'phone_userType',
            'email_userType'
          ]
        },
        trips: {
          structure: {
            id: 'string',
            passengerId: 'string',
            driverId: 'string',
            status: 'requested|accepted|ongoing|completed|cancelled',
            fare: 'number',
            route: {
              start: 'geopoint',
              end: 'geopoint',
              distance: 'number'
            },
            createdAt: 'timestamp'
          },
          indexes: [
            'status_createdAt',
            'passengerId_createdAt',
            'driverId_createdAt',
            'status_driverId_createdAt'
          ]
        }
      },
      backupSchedule: {
        frequency: 'DAILY',
        time: '02:00 AM PET',
        retention: '30 days',
        location: 'gs://oasis-taxi-peru-backups'
      }
    },
    
    CLOUD_MESSAGING: {
      path: '/notification',
      configuration: {
        serverKey: 'Stored in Secret Manager',
        vapidKey: 'For web push',
        topics: [
          '/topics/all_users',
          '/topics/drivers',
          '/topics/passengers',
          '/topics/lima_users'
        ]
      },
      testNotification: `
        // Send test notification
        const message = {
          notification: {
            title: 'Test Notification',
            body: 'This is a test message'
          },
          topic: 'all_users'
        };
        
        admin.messaging().send(message)
          .then(response => console.log('Sent:', response));
      `
    },
    
    STORAGE: {
      path: '/storage/files',
      buckets: {
        default: 'oasis-taxi-peru.appspot.com',
        structure: {
          'user-documents/': 'User verification documents',
          'driver-documents/': 'Driver licenses, insurance',
          'vehicle-photos/': 'Vehicle images',
          'profile-pictures/': 'User profile images',
          'trip-receipts/': 'PDF receipts'
        }
      },
      securityRules: `
        rules_version = '2';
        service firebase.storage {
          match /b/{bucket}/o {
            // User documents
            match /user-documents/{userId}/{document} {
              allow read: if request.auth != null && 
                (request.auth.uid == userId || 
                 request.auth.token.role == 'admin');
              allow write: if request.auth != null && 
                request.auth.uid == userId;
            }
            
            // Public profile pictures
            match /profile-pictures/{userId}/{image} {
              allow read: if true;
              allow write: if request.auth != null && 
                request.auth.uid == userId;
            }
          }
        }
      `
    }
  };

  // Tareas Comunes en Firebase
  static readonly COMMON_TASKS = {
    exportData: {
      description: 'Exportar datos para análisis',
      steps: [
        '1. Firestore > ⋮ > Import/Export',
        '2. Select Export',
        '3. Choose collections or export all',
        '4. Select GCS bucket: gs://oasis-taxi-peru-exports',
        '5. Click Export',
        '6. Monitor progress in Operations tab'
      ],
      script: `
        gcloud firestore export gs://oasis-taxi-peru-exports/$(date +%Y%m%d) \\
          --collection-ids=users,trips,drivers,payments
      `
    },
    
    performanceMonitoring: {
      description: 'Revisar performance de la app',
      navigation: 'Performance > Dashboard',
      keyMetrics: [
        'App start time',
        'Screen rendering',
        'Network latency',
        'Custom traces'
      ],
      alerts: {
        appStartTime: '> 3 seconds',
        networkLatency: '> 1 second',
        screenRendering: '> 16ms'
      }
    },
    
    userEngagement: {
      description: 'Analizar engagement de usuarios',
      navigation: 'Analytics > Dashboard',
      keyEvents: [
        'first_open',
        'session_start',
        'trip_requested',
        'trip_completed',
        'payment_completed',
        'user_engagement'
      ],
      funnels: [
        'Registration → First Trip',
        'Search → Booking → Complete',
        'App Open → Trip Request'
      ]
    }
  };
}
```

### 2.2 Firebase Security Rules Management
```typescript
export class FirebaseSecurityManagement {
  static readonly SECURITY_RULES = {
    FIRESTORE: {
      location: 'Firestore > Rules',
      currentRules: `
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    function isAdmin() {
      return isAuthenticated() && 
        request.auth.token.role == 'admin';
    }
    
    function isDriver() {
      return isAuthenticated() && 
        request.auth.token.userType == 'driver';
    }
    
    function isPassenger() {
      return isAuthenticated() && 
        request.auth.token.userType == 'passenger';
    }
    
    // Users collection
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow write: if isOwner(userId) || isAdmin();
    }
    
    // Trips collection
    match /trips/{tripId} {
      allow read: if isAuthenticated() && 
        (resource.data.passengerId == request.auth.uid ||
         resource.data.driverId == request.auth.uid ||
         isAdmin());
      allow create: if isPassenger();
      allow update: if isAuthenticated() &&
        (resource.data.passengerId == request.auth.uid ||
         resource.data.driverId == request.auth.uid);
    }
    
    // Price negotiations
    match /price_negotiations/{negotiationId} {
      allow read: if isAuthenticated();
      allow create: if isPassenger();
      allow update: if isDriver() || 
        (isPassenger() && resource.data.passengerId == request.auth.uid);
    }
    
    // Admin only collections
    match /system_config/{doc} {
      allow read: if isAuthenticated();
      allow write: if isAdmin();
    }
    
    match /analytics/{doc} {
      allow read: if isAdmin();
      allow write: if false; // Only backend
    }
  }
}
      `,
      testingRules: `
        // En Firebase Console > Rules Playground
        // Simular diferentes escenarios:
        
        // Test 1: Passenger reading their own data
        Simulation:
          - Authentication: Yes (uid: user123, claims: {userType: 'passenger'})
          - Operation: get
          - Path: /users/user123
          - Expected: ALLOW
        
        // Test 2: Driver updating trip status
        Simulation:
          - Authentication: Yes (uid: driver456, claims: {userType: 'driver'})
          - Operation: update
          - Path: /trips/trip789
          - Data: {status: 'completed'}
          - Expected: ALLOW (if driver456 is the trip's driver)
        
        // Test 3: Unauthorized access
        Simulation:
          - Authentication: No
          - Operation: get
          - Path: /users/anyuser
          - Expected: DENY
      `
    },
    
    STORAGE: {
      location: 'Storage > Rules',
      uploadLimits: {
        maxFileSize: '10MB',
        allowedTypes: ['image/jpeg', 'image/png', 'application/pdf'],
        virusScan: 'Automatic via Cloud Security Scanner'
      }
    },
    
    REALTIME_DATABASE: {
      location: 'Realtime Database > Rules',
      currentRules: `
{
  "rules": {
    "active_trips": {
      "$tripId": {
        ".read": "auth != null",
        ".write": "auth != null && (auth.token.userType == 'driver' || auth.token.userType == 'passenger')"
      }
    },
    "driver_locations": {
      "$driverId": {
        ".read": "auth != null",
        ".write": "auth != null && auth.uid == $driverId"
      }
    },
    "chat_messages": {
      "$tripId": {
        ".read": "auth != null",
        ".write": "auth != null"
      }
    }
  }
}
      `
    }
  };

  // Audit y Compliance
  static readonly AUDIT_PROCEDURES = {
    weeklyReview: [
      'Check failed authentication attempts',
      'Review permission denied errors',
      'Analyze unusual access patterns',
      'Verify admin actions log'
    ],
    
    monthlyAudit: [
      'Export audit logs to BigQuery',
      'Review security rules effectiveness',
      'Check for unused rules',
      'Update rules based on new features'
    ],
    
    complianceChecks: {
      GDPR: [
        'Data retention policies active',
        'User deletion procedures working',
        'Data export functionality operational'
      ],
      PCI: [
        'No credit card data in Firestore',
        'Payment tokens properly secured',
        'Audit logs for payment operations'
      ]
    }
  };
}
```

---

## 3. CLOUD FUNCTIONS REVIEW

### 3.1 Funciones Desplegadas
```typescript
export class CloudFunctionsInventory {
  static readonly PRODUCTION_FUNCTIONS = {
    // Funciones de Negocio Core
    TRIP_FUNCTIONS: {
      createTrip: {
        trigger: 'HTTP',
        endpoint: '/api/trips/create',
        memory: '256MB',
        timeout: '60s',
        minInstances: 1,
        maxInstances: 100,
        description: 'Crea nueva solicitud de viaje',
        criticalLevel: 'HIGH',
        monitoringAlert: true
      },
      
      matchDriver: {
        trigger: 'Firestore',
        path: 'trips/{tripId}',
        event: 'onCreate',
        memory: '512MB',
        timeout: '120s',
        description: 'Busca y asigna conductor disponible',
        algorithm: 'Nearest available with rating > 4.0'
      },
      
      calculateFare: {
        trigger: 'HTTP',
        endpoint: '/api/trips/calculate-fare',
        memory: '128MB',
        timeout: '10s',
        description: 'Calcula tarifa basada en distancia y demanda'
      },
      
      completeTrip: {
        trigger: 'HTTP',
        endpoint: '/api/trips/complete',
        memory: '256MB',
        timeout: '30s',
        description: 'Finaliza viaje y procesa pago'
      }
    },
    
    PAYMENT_FUNCTIONS: {
      processPayment: {
        trigger: 'HTTP',
        endpoint: '/api/payments/process',
        memory: '256MB',
        timeout: '30s',
        minInstances: 2,
        description: 'Procesa pagos con MercadoPago',
        retryPolicy: {
          maxAttempts: 3,
          backoffMultiplier: 2
        }
      },
      
      handleWebhook: {
        trigger: 'HTTP',
        endpoint: '/api/payments/webhook',
        memory: '128MB',
        timeout: '10s',
        description: 'Recibe webhooks de MercadoPago',
        security: 'Verify signature header'
      },
      
      calculateCommission: {
        trigger: 'Firestore',
        path: 'payments/{paymentId}',
        event: 'onCreate',
        memory: '128MB',
        timeout: '10s',
        description: 'Calcula y registra comisión (20%)'
      }
    },
    
    NOTIFICATION_FUNCTIONS: {
      sendTripNotification: {
        trigger: 'Firestore',
        path: 'trips/{tripId}',
        event: 'onUpdate',
        memory: '256MB',
        timeout: '10s',
        description: 'Envía notificaciones push sobre estado del viaje'
      },
      
      sendDriverBroadcast: {
        trigger: 'PubSub',
        topic: 'new-trip-request',
        memory: '512MB',
        timeout: '30s',
        description: 'Notifica a conductores cercanos'
      },
      
      sendMarketingCampaign: {
        trigger: 'Schedule',
        schedule: '0 10 * * 1', // Lunes 10 AM
        memory: '1GB',
        timeout: '540s',
        description: 'Envía campañas de marketing masivas'
      }
    },
    
    SCHEDULED_FUNCTIONS: {
      dailyReports: {
        trigger: 'Schedule',
        schedule: '0 2 * * *', // 2 AM daily
        memory: '1GB',
        timeout: '540s',
        description: 'Genera reportes diarios',
        tasks: [
          'Revenue calculation',
          'Driver performance',
          'User statistics',
          'Export to BigQuery'
        ]
      },
      
      cleanupOldData: {
        trigger: 'Schedule',
        schedule: '0 3 * * 0', // Domingo 3 AM
        memory: '512MB',
        timeout: '540s',
        description: 'Limpia datos antiguos (> 90 días)'
      },
      
      backupDatabase: {
        trigger: 'Schedule',
        schedule: '0 1 * * *', // 1 AM daily
        memory: '256MB',
        timeout: '300s',
        description: 'Backup automático a Cloud Storage'
      }
    }
  };

  // Debugging y Logs
  static readonly DEBUGGING_GUIDE = {
    viewLogs: `
      # Ver logs de una función específica
      gcloud functions logs read createTrip --limit 50
      
      # Ver logs con filtro de severidad
      gcloud functions logs read --filter="severity>=ERROR"
      
      # Stream logs en tiempo real
      gcloud functions logs read createTrip --follow
    `,
    
    commonErrors: {
      TIMEOUT: {
        error: 'Function execution took longer than configured timeout',
        solution: 'Increase timeout in function config or optimize code',
        example: 'Change timeout from 60s to 120s'
      },
      
      MEMORY_EXCEEDED: {
        error: 'Memory limit exceeded',
        solution: 'Increase memory allocation',
        example: 'Change from 256MB to 512MB'
      },
      
      COLD_START: {
        error: 'High latency on first invocation',
        solution: 'Set minimum instances',
        example: 'minInstances: 1'
      },
      
      PERMISSION_DENIED: {
        error: 'Missing IAM permissions',
        solution: 'Add required roles to function service account',
        example: 'roles/datastore.user for Firestore access'
      }
    },
    
    testingFunctions: `
      // Test HTTP function locally
      npm run serve
      curl http://localhost:5001/oasis-taxi-peru/us-central1/createTrip
      
      // Test with Firebase Emulator
      firebase emulators:start --only functions,firestore
      
      // Deploy single function
      firebase deploy --only functions:createTrip
      
      // Deploy with environment variables
      firebase functions:config:set payment.key="SECRET_KEY"
      firebase deploy --only functions
    `
  };

  // Optimización y Mejores Prácticas
  static readonly OPTIMIZATION_TIPS = {
    coldStartReduction: [
      'Use global variables for persistent connections',
      'Lazy load heavy dependencies',
      'Keep functions lightweight',
      'Set appropriate minimum instances'
    ],
    
    costOptimization: [
      'Use appropriate memory allocation',
      'Implement proper error handling to avoid retries',
      'Clean up resources after use',
      'Use Cloud Scheduler for batch operations'
    ],
    
    codeStructure: `
      // Estructura recomendada
      const admin = require('firebase-admin');
      admin.initializeApp(); // Global scope
      
      // Lazy loading
      let heavyLibrary;
      
      exports.myFunction = functions.https.onRequest(async (req, res) => {
        // Load only when needed
        if (!heavyLibrary) {
          heavyLibrary = require('heavy-library');
        }
        
        try {
          // Business logic
          const result = await processRequest(req);
          res.status(200).json(result);
        } catch (error) {
          console.error('Error:', error);
          res.status(500).json({ error: error.message });
        }
      });
    `
  };
}
```

---

## 4. MONITORING SETUP

### 4.1 Dashboard de Monitoreo Principal
```typescript
export class MonitoringSetupGuide {
  static readonly MONITORING_ARCHITECTURE = {
    DASHBOARDS: {
      executive: {
        url: '/monitoring/dashboards/custom/executive-overview',
        widgets: [
          'Revenue metrics',
          'User growth',
          'System health',
          'Active incidents'
        ],
        refreshRate: '1 minute',
        audience: 'C-Level, Product Managers'
      },
      
      operational: {
        url: '/monitoring/dashboards/custom/operations',
        widgets: [
          'Real-time trips',
          'Driver availability',
          'API latency',
          'Error rates'
        ],
        refreshRate: '30 seconds',
        audience: 'Operations Team'
      },
      
      technical: {
        url: '/monitoring/dashboards/custom/technical',
        widgets: [
          'Service health',
          'Resource utilization',
          'Database performance',
          'Network traffic'
        ],
        refreshRate: '1 minute',
        audience: 'DevOps, Engineers'
      }
    },
    
    ALERT_POLICIES: {
      critical: [
        {
          name: 'API Down',
          condition: 'Uptime check failure',
          threshold: '1 failure',
          duration: '1 minute',
          notification: ['PagerDuty', 'SMS', 'Email']
        },
        {
          name: 'Payment Failures High',
          condition: 'Payment error rate > 5%',
          duration: '5 minutes',
          notification: ['Slack', 'Email']
        },
        {
          name: 'Database Connection Lost',
          condition: 'Firestore unreachable',
          duration: '30 seconds',
          notification: ['PagerDuty', 'SMS']
        }
      ],
      
      warning: [
        {
          name: 'High Latency',
          condition: 'P95 latency > 1000ms',
          duration: '5 minutes',
          notification: ['Slack']
        },
        {
          name: 'Low Driver Availability',
          condition: 'Active drivers < 50',
          duration: '10 minutes',
          notification: ['Email']
        }
      ]
    },
    
    SLO_DEFINITIONS: {
      availability: {
        target: 99.9,
        measurement: 'Uptime checks',
        window: '30 days rolling'
      },
      
      latency: {
        target: 'P95 < 500ms',
        measurement: 'API response time',
        window: '1 hour rolling'
      },
      
      errorRate: {
        target: '< 1%',
        measurement: '5xx errors / total requests',
        window: '1 hour rolling'
      }
    }
  };

  // Configuración de Logging
  static readonly LOGGING_CONFIGURATION = {
    LOG_SINKS: {
      bigquery: {
        name: 'sink-to-bigquery',
        destination: 'bigquery.googleapis.com/projects/oasis-taxi-peru/datasets/logs',
        filter: 'severity >= WARNING',
        description: 'Archive logs for analysis'
      },
      
      storage: {
        name: 'sink-to-storage',
        destination: 'storage.googleapis.com/oasis-taxi-peru-logs',
        filter: 'resource.type="cloud_function"',
        description: 'Backup function logs'
      },
      
      pubsub: {
        name: 'sink-to-pubsub',
        destination: 'pubsub.googleapis.com/projects/oasis-taxi-peru/topics/critical-errors',
        filter: 'severity >= ERROR AND resource.type="cloud_run_revision"',
        description: 'Stream critical errors for processing'
      }
    },
    
    LOG_QUERIES: {
      recentErrors: `
        resource.type="cloud_run_revision"
        severity>=ERROR
        timestamp>="2024-01-01T00:00:00Z"
        logName=~"projects/oasis-taxi-peru/logs/*"
      `,
      
      slowAPICalls: `
        resource.type="api"
        httpRequest.latency>"1s"
        timestamp>="2024-01-01T00:00:00Z"
      `,
      
      failedPayments: `
        resource.labels.service_name="payment-service"
        jsonPayload.status="failed"
        timestamp>="2024-01-01T00:00:00Z"
      `,
      
      userAuthentication: `
        protoPayload.methodName="google.firebase.auth.v1.AuthService.SignIn"
        timestamp>="2024-01-01T00:00:00Z"
      `
    },
    
    LOG_BASED_METRICS: [
      {
        name: 'error_count',
        filter: 'severity >= ERROR',
        metricType: 'COUNTER',
        labelExtractors: {
          service: 'EXTRACT(resource.labels.service_name)',
          error_type: 'EXTRACT(jsonPayload.error_type)'
        }
      },
      {
        name: 'api_latency',
        filter: 'resource.type="api"',
        metricType: 'DISTRIBUTION',
        valueExtractor: 'EXTRACT(httpRequest.latency)',
        bucketOptions: {
          exponentialBuckets: {
            numFiniteBuckets: 64,
            growthFactor: 2,
            scale: 0.01
          }
        }
      }
    ]
  };

  // Uptime Checks
  static readonly UPTIME_CHECKS = [
    {
      displayName: 'API Gateway Health',
      monitoredResource: {
        type: 'uptime_url',
        labels: {
          host: 'api.oasistaxiperu.com',
          project_id: 'oasis-taxi-peru'
        }
      },
      httpCheck: {
        path: '/health',
        port: 443,
        requestMethod: 'GET',
        useSsl: true,
        validateSsl: true
      },
      period: '60s',
      timeout: '10s',
      selectedRegions: ['USA', 'SOUTH_AMERICA']
    },
    {
      displayName: 'Trip Service Health',
      monitoredResource: {
        type: 'uptime_url',
        labels: {
          host: 'trip-service-xxxxx-uc.a.run.app'
        }
      },
      httpCheck: {
        path: '/health',
        headers: {
          'Authorization': 'Bearer ${SECRET_TOKEN}'
        }
      },
      period: '60s'
    }
  ];
}
```

---

## 5. INCIDENT RESPONSE

### 5.1 Procedimientos de Respuesta a Incidentes
```typescript
export class IncidentResponseProcedures {
  static readonly SEVERITY_LEVELS = {
    CRITICAL: {
      definition: 'Sistema completamente inoperativo o pérdida de datos',
      examples: [
        'API Gateway no responde',
        'Base de datos corrupta',
        'Pérdida de datos de pagos',
        'Brecha de seguridad activa'
      ],
      responseTime: '15 minutos',
      escalation: 'Inmediata a CTO y CEO',
      team: ['On-call engineer', 'Team lead', 'CTO']
    },
    
    HIGH: {
      definition: 'Funcionalidad crítica degradada',
      examples: [
        'Pagos fallando > 10%',
        'Matching de conductores lento',
        'Login intermitente'
      ],
      responseTime: '30 minutos',
      escalation: 'Team lead en 1 hora',
      team: ['On-call engineer', 'Team lead']
    },
    
    MEDIUM: {
      definition: 'Funcionalidad no crítica afectada',
      examples: [
        'Reportes no generándose',
        'Notificaciones retrasadas',
        'Búsqueda lenta'
      ],
      responseTime: '2 horas',
      escalation: 'Si no se resuelve en 4 horas',
      team: ['On-call engineer']
    },
    
    LOW: {
      definition: 'Issues menores sin impacto en usuarios',
      examples: [
        'Logs con warnings',
        'UI glitches menores',
        'Optimizaciones pendientes'
      ],
      responseTime: '24 horas',
      escalation: 'No requerida',
      team: ['Developer on duty']
    }
  };

  static readonly INCIDENT_PLAYBOOKS = {
    API_DOWN: {
      symptoms: [
        'Health check failing',
        'No response from endpoints',
        'Timeout errors'
      ],
      diagnostics: `
        # 1. Check service status
        gcloud run services describe trip-service --region=us-central1
        
        # 2. Check recent deployments
        gcloud run revisions list --service=trip-service
        
        # 3. Check logs for errors
        gcloud logging read "resource.type=cloud_run_revision 
          AND resource.labels.service_name=trip-service 
          AND severity>=ERROR" --limit=50
        
        # 4. Check upstream dependencies
        curl https://api.oasistaxiperu.com/health
      `,
      immediateActions: [
        'Rollback to previous version if recent deployment',
        'Scale up instances if load issue',
        'Check Cloud Load Balancer configuration',
        'Verify SSL certificates'
      ],
      rollbackProcedure: `
        # Rollback to previous revision
        gcloud run services update-traffic trip-service \\
          --to-revisions=trip-service-00001-abc=100 \\
          --region=us-central1
      `,
      communication: {
        internal: 'Post in #incidents Slack channel',
        external: 'Update status page if > 5 minutes'
      }
    },
    
    DATABASE_ISSUES: {
      symptoms: [
        'Firestore permission denied',
        'Slow queries',
        'Connection timeouts'
      ],
      diagnostics: `
        # 1. Check Firestore status
        gcloud firestore operations list --limit=10
        
        # 2. Check quotas
        gcloud compute project-info describe --project=oasis-taxi-peru
        
        # 3. Check index status
        gcloud firestore indexes list
        
        # 4. Monitor active connections
        # Go to Console > Firestore > Usage tab
      `,
      immediateActions: [
        'Check and increase quotas if needed',
        'Verify security rules haven\'t changed',
        'Clear application cache',
        'Implement circuit breaker'
      ]
    },
    
    PAYMENT_FAILURES: {
      symptoms: [
        'MercadoPago webhooks failing',
        'Payment processing errors',
        'Commission calculation errors'
      ],
      diagnostics: `
        # 1. Check payment service logs
        gcloud functions logs read processPayment --limit=100
        
        # 2. Verify MercadoPago API status
        curl https://api.mercadopago.com/v1/payment_methods
        
        # 3. Check webhook signatures
        # Review webhook handler logs
        
        # 4. Verify API credentials
        firebase functions:config:get payment
      `,
      immediateActions: [
        'Enable payment fallback mode',
        'Queue failed payments for retry',
        'Notify finance team',
        'Check with MercadoPago support'
      ],
      criticalContacts: {
        mercadoPago: '+51 1 XXX-XXXX',
        internalFinance: 'finance@oasistaxiperu.com'
      }
    },
    
    HIGH_LATENCY: {
      symptoms: [
        'API response > 1000ms',
        'User complaints about slowness',
        'Timeout errors increasing'
      ],
      diagnostics: `
        # 1. Check Cloud Trace
        # Console > Trace > Latency overview
        
        # 2. Identify slow operations
        gcloud trace traces list --project=oasis-taxi-peru
        
        # 3. Check CPU and memory usage
        gcloud monitoring metrics list --filter="metric.type=run.googleapis.com"
        
        # 4. Review recent code changes
        git log --since="2 hours ago"
      `,
      immediateActions: [
        'Scale up services',
        'Enable caching if disabled',
        'Reduce batch sizes',
        'Implement request throttling'
      ]
    }
  };

  // Post-Incident Review Template
  static readonly POST_INCIDENT_TEMPLATE = `
    # Incident Post-Mortem: [INCIDENT_ID]
    
    ## Summary
    - Date: [DATE]
    - Duration: [START_TIME] - [END_TIME]
    - Severity: [CRITICAL/HIGH/MEDIUM/LOW]
    - Services Affected: [LIST]
    - Users Impacted: [NUMBER/%]
    
    ## Timeline
    - HH:MM - First alert received
    - HH:MM - Engineer acknowledged
    - HH:MM - Root cause identified
    - HH:MM - Fix implemented
    - HH:MM - Service restored
    - HH:MM - Monitoring confirmed normal
    
    ## Root Cause
    [Detailed explanation of what caused the incident]
    
    ## Resolution
    [Steps taken to resolve the issue]
    
    ## Impact
    - Users affected: [NUMBER]
    - Revenue impact: [S/. AMOUNT]
    - SLA impact: [PERCENTAGE]
    
    ## Lessons Learned
    1. What went well
    2. What could be improved
    3. Action items
    
    ## Action Items
    - [ ] [ACTION] - Owner: [NAME] - Due: [DATE]
    - [ ] [ACTION] - Owner: [NAME] - Due: [DATE]
    
    ## Prevention Measures
    [Long-term fixes to prevent recurrence]
  `;
}
```

---

## 6. COST MANAGEMENT

### 6.1 Estrategias de Gestión de Costos
```typescript
export class CostManagementStrategies {
  static readonly COST_BREAKDOWN = {
    CURRENT_MONTHLY: {
      total: 3500, // USD
      breakdown: {
        'Google Maps API': 1200,
        'Cloud Run': 500,
        'Firestore': 400,
        'Cloud Functions': 300,
        'Cloud Storage': 200,
        'BigQuery': 150,
        'Networking': 250,
        'Other': 500
      }
    },
    
    OPTIMIZATION_TARGETS: {
      mapsAPI: {
        current: 1200,
        target: 800,
        strategy: [
          'Implement geocoding cache',
          'Batch direction requests',
          'Use static maps where possible',
          'Reduce update frequency'
        ]
      },
      
      firestore: {
        current: 400,
        target: 300,
        strategy: [
          'Implement Redis cache layer',
          'Optimize queries with indexes',
          'Archive old data to Cloud Storage',
          'Reduce document reads with local cache'
        ]
      },
      
      cloudFunctions: {
        current: 300,
        target: 200,
        strategy: [
          'Optimize cold starts',
          'Right-size memory allocation',
          'Implement request batching',
          'Use Cloud Run for long-running tasks'
        ]
      }
    }
  };

  static readonly BUDGET_ALERTS = {
    setup: `
      # Create budget with alerts
      gcloud billing budgets create \\
        --billing-account=BILLING_ACCOUNT_ID \\
        --display-name="OasisTaxi Monthly Budget" \\
        --budget-amount=3500 \\
        --threshold-rule=percent=50 \\
        --threshold-rule=percent=75 \\
        --threshold-rule=percent=90 \\
        --threshold-rule=percent=100
    `,
    
    notificationChannels: [
      {
        type: 'email',
        recipients: ['finance@oasistaxiperu.com', 'cto@oasistaxiperu.com']
      },
      {
        type: 'pubsub',
        topic: 'projects/oasis-taxi-peru/topics/budget-alerts'
      }
    ],
    
    automatedActions: {
      at75Percent: 'Send warning to team',
      at90Percent: 'Disable non-critical services',
      at100Percent: 'Emergency meeting + cost reduction mode'
    }
  };

  static readonly COST_OPTIMIZATION_SCRIPTS = {
    // Identificar recursos no utilizados
    findUnusedResources: `
      #!/bin/bash
      
      echo "Checking for unused resources..."
      
      # Unused Cloud Storage buckets
      echo "Checking Cloud Storage..."
      gsutil ls -L -b gs:// | grep "Total objects: 0"
      
      # Unused Cloud SQL instances
      echo "Checking Cloud SQL..."
      gcloud sql instances list --filter="state:RUNNABLE" --format="table(name,settings.activationPolicy)"
      
      # Unused static IPs
      echo "Checking unused IPs..."
      gcloud compute addresses list --filter="status:RESERVED"
      
      # Old disk snapshots
      echo "Checking old snapshots..."
      gcloud compute snapshots list --filter="creationTimestamp < -P30D"
    `,
    
    // Optimizar Firestore
    optimizeFirestore: `
      // Clean up old data
      const admin = require('firebase-admin');
      const db = admin.firestore();
      
      async function archiveOldTrips() {
        const cutoffDate = new Date();
        cutoffDate.setDate(cutoffDate.getDate() - 90);
        
        const oldTrips = await db.collection('trips')
          .where('createdAt', '<', cutoffDate)
          .limit(500)
          .get();
        
        const batch = db.batch();
        const archiveBatch = db.batch();
        
        oldTrips.forEach(doc => {
          // Archive to separate collection
          archiveBatch.set(
            db.collection('trips_archive').doc(doc.id),
            doc.data()
          );
          
          // Delete from main collection
          batch.delete(doc.ref);
        });
        
        await archiveBatch.commit();
        await batch.commit();
        
        console.log(\`Archived \${oldTrips.size} trips\`);
      }
    `,
    
    // Optimizar Cloud Functions
    optimizeFunctions: `
      # Right-size function memory
      for func in createTrip processPayment matchDriver; do
        echo "Analyzing $func..."
        gcloud functions logs read $func --limit=1000 | grep "Memory used"
      done
      
      # Update function configuration
      gcloud functions deploy createTrip \\
        --memory=128MB \\  # Reduced from 256MB
        --timeout=30s \\    # Reduced from 60s
        --min-instances=0 \\ # Remove minimum instances for dev
        --max-instances=50   # Limit max scaling
    `
  };

  static readonly MONITORING_QUERIES = {
    dailyCost: `
      SELECT 
        service.description as service,
        sku.description as sku,
        SUM(cost) as total_cost,
        currency
      FROM \`oasis-taxi-peru.billing.gcp_billing_export_v1\`
      WHERE DATE(usage_start_time) = CURRENT_DATE() - 1
      GROUP BY service, sku, currency
      ORDER BY total_cost DESC
      LIMIT 20
    `,
    
    costTrend: `
      SELECT 
        DATE(usage_start_time) as date,
        service.description as service,
        SUM(cost) as daily_cost
      FROM \`oasis-taxi-peru.billing.gcp_billing_export_v1\`
      WHERE DATE(usage_start_time) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
      GROUP BY date, service
      ORDER BY date DESC, daily_cost DESC
    `,
    
    projectedMonthly: `
      WITH daily_avg AS (
        SELECT 
          AVG(daily_cost) as avg_daily_cost
        FROM (
          SELECT 
            DATE(usage_start_time) as date,
            SUM(cost) as daily_cost
          FROM \`oasis-taxi-peru.billing.gcp_billing_export_v1\`
          WHERE DATE(usage_start_time) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
          GROUP BY date
        )
      )
      SELECT 
        avg_daily_cost,
        avg_daily_cost * 30 as projected_monthly,
        3500 as budget,
        ROUND((avg_daily_cost * 30 / 3500) * 100, 2) as budget_utilization_percent
      FROM daily_avg
    `
  };
}
```

---

## 7. SCALING PROCEDURES

### 7.1 Procedimientos de Escalado
```typescript
export class ScalingProcedures {
  static readonly SCALING_TRIGGERS = {
    AUTOMATIC: {
      cloudRun: {
        metric: 'CPU utilization',
        threshold: '60%',
        scaleUp: 'Add 2 instances',
        scaleDown: 'Remove 1 instance',
        cooldown: '60 seconds',
        config: `
          gcloud run services update trip-service \\
            --min-instances=2 \\
            --max-instances=100 \\
            --cpu-throttling \\
            --memory=512Mi \\
            --concurrency=1000
        `
      },
      
      firestore: {
        metric: 'Read/Write operations',
        threshold: '50000 ops/second',
        action: 'Automatic scaling',
        sharding: 'Automatic for hot documents'
      },
      
      cloudFunctions: {
        metric: 'Concurrent executions',
        threshold: '80% of max',
        maxInstances: 1000,
        scaleUp: 'Exponential',
        config: `
          // In function configuration
          exports.myFunction = functions
            .runWith({
              minInstances: 10,
              maxInstances: 1000,
              memory: '512MB'
            })
            .https.onRequest(handler);
        `
      }
    },
    
    MANUAL: {
      peakHours: {
        schedule: '07:00-09:00, 17:00-20:00 PET',
        preScaling: `
          # Pre-scale for morning peak
          gcloud scheduler jobs create app-engine scale-morning \\
            --schedule="0 7 * * MON-FRI" \\
            --uri="https://api.oasistaxiperu.com/admin/scale" \\
            --http-method=POST \\
            --message-body='{"minInstances": 10}'
          
          # Scale down after peak
          gcloud scheduler jobs create app-engine scale-down \\
            --schedule="0 10 * * MON-FRI" \\
            --uri="https://api.oasistaxiperu.com/admin/scale" \\
            --http-method=POST \\
            --message-body='{"minInstances": 2}'
        `
      },
      
      specialEvents: {
        procedure: [
          '1. Identify expected load increase',
          '2. Pre-scale all services 1 hour before',
          '3. Monitor metrics closely',
          '4. Adjust scaling policies temporarily',
          '5. Return to normal after event'
        ],
        script: `
          #!/bin/bash
          # Scale for special event
          
          echo "Scaling up for special event..."
          
          # Scale Cloud Run
          gcloud run services update trip-service --min-instances=20
          gcloud run services update payment-service --min-instances=10
          
          # Increase Cloud Functions quota
          gcloud functions deploy matchDriver --max-instances=500
          
          # Notify team
          curl -X POST https://hooks.slack.com/services/XXX \\
            -H 'Content-Type: application/json' \\
            -d '{"text":"Services scaled for special event"}'
        `
      }
    }
  };

  static readonly CAPACITY_PLANNING = {
    currentCapacity: {
      dailyTrips: 10000,
      concurrentUsers: 5000,
      driversOnline: 1000,
      peakRPS: 500
    },
    
    growthProjections: {
      '3_months': {
        dailyTrips: 25000,
        concurrentUsers: 12000,
        requiredChanges: [
          'Increase Cloud Run instances',
          'Add Redis cache layer',
          'Implement database sharding'
        ]
      },
      
      '6_months': {
        dailyTrips: 50000,
        concurrentUsers: 25000,
        requiredChanges: [
          'Multi-region deployment',
          'CDN implementation',
          'Microservices architecture'
        ]
      },
      
      '1_year': {
        dailyTrips: 100000,
        concurrentUsers: 50000,
        requiredChanges: [
          'Full Kubernetes migration',
          'Global load balancing',
          'Real-time data streaming'
        ]
      }
    },
    
    scalingRoadmap: {
      phase1: {
        users: '10K-50K',
        architecture: 'Current monolithic with caching',
        timeline: 'Month 1-3'
      },
      
      phase2: {
        users: '50K-200K',
        architecture: 'Microservices with Cloud Run',
        timeline: 'Month 4-6'
      },
      
      phase3: {
        users: '200K-1M',
        architecture: 'Kubernetes with multi-region',
        timeline: 'Month 7-12'
      }
    }
  };

  static readonly LOAD_TESTING = {
    tools: {
      k6: {
        installation: 'brew install k6',
        basicTest: `
          import http from 'k6/http';
          import { check } from 'k6';
          
          export let options = {
            stages: [
              { duration: '2m', target: 100 }, // Ramp up
              { duration: '5m', target: 100 }, // Stay at 100
              { duration: '2m', target: 200 }, // Ramp to 200
              { duration: '5m', target: 200 }, // Stay at 200
              { duration: '2m', target: 0 },   // Ramp down
            ],
            thresholds: {
              http_req_duration: ['p(95)<500'], // 95% of requests under 500ms
              http_req_failed: ['rate<0.1'],    // Error rate under 10%
            },
          };
          
          export default function() {
            let response = http.post('https://api.oasistaxiperu.com/api/trips/create', 
              JSON.stringify({
                pickup: { lat: -12.0464, lng: -77.0428 },
                destination: { lat: -12.0564, lng: -77.0528 },
                userId: 'test_user_' + Math.random()
              }),
              { headers: { 'Content-Type': 'application/json' } }
            );
            
            check(response, {
              'status is 200': (r) => r.status === 200,
              'response time < 500ms': (r) => r.timings.duration < 500,
            });
          }
        `
      },
      
      artillery: {
        installation: 'npm install -g artillery',
        configFile: `
          config:
            target: 'https://api.oasistaxiperu.com'
            phases:
              - duration: 60
                arrivalRate: 10
                name: "Warm up"
              - duration: 300
                arrivalRate: 50
                name: "Sustained load"
              - duration: 120
                arrivalRate: 100
                name: "Peak load"
          scenarios:
            - name: "Create Trip Flow"
              flow:
                - post:
                    url: "/api/auth/login"
                    json:
                      phone: "+51987654321"
                      password: "test123"
                    capture:
                      - json: "$.token"
                        as: "token"
                - post:
                    url: "/api/trips/create"
                    headers:
                      Authorization: "Bearer {{ token }}"
                    json:
                      pickup: { lat: -12.0464, lng: -77.0428 }
                      destination: { lat: -12.0564, lng: -77.0528 }
        `
      }
    },
    
    scenarios: [
      {
        name: 'Normal Load',
        users: 500,
        duration: '30m',
        expected: 'All services stable'
      },
      {
        name: 'Peak Hours',
        users: 2000,
        duration: '2h',
        expected: 'Auto-scaling triggers'
      },
      {
        name: 'Stress Test',
        users: 5000,
        duration: '1h',
        expected: 'Identify breaking point'
      },
      {
        name: 'Spike Test',
        users: '100 to 3000 in 30s',
        duration: '5m',
        expected: 'Test sudden load'
      }
    ]
  };
}
```

---

## 8. DAILY OPERATIONS GUIDE

### 8.1 Checklist Diario de Operaciones
```typescript
export class DailyOperationsGuide {
  static readonly MORNING_CHECKLIST = {
    '08:00': [
      {
        task: 'Review overnight alerts',
        command: 'gcloud logging read "severity>=WARNING" --limit=50 --format=json',
        expectedTime: '10 minutes'
      },
      {
        task: 'Check system health dashboard',
        url: 'https://console.cloud.google.com/monitoring/dashboards/custom/operations',
        checkItems: ['All services green', 'No critical alerts', 'Normal latency']
      },
      {
        task: 'Verify backup completion',
        command: 'gsutil ls -l gs://oasis-taxi-peru-backups/$(date +%Y%m%d)*',
        expected: 'Firestore backup file present'
      },
      {
        task: 'Review cost dashboard',
        url: 'https://console.cloud.google.com/billing',
        check: 'Daily spend within budget'
      }
    ],
    
    '09:00': [
      {
        task: 'Check driver availability',
        query: `
          SELECT 
            COUNT(DISTINCT driver_id) as online_drivers,
            AVG(CASE WHEN status = 'busy' THEN 1 ELSE 0 END) as utilization
          FROM driver_status
          WHERE last_ping > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 5 MINUTE)
        `,
        threshold: 'Minimum 100 drivers online'
      },
      {
        task: 'Review pending support tickets',
        url: 'https://support.oasistaxiperu.com/admin',
        priority: 'Address critical issues first'
      }
    ]
  };

  static readonly MONITORING_ROTATION = {
    schedule: {
      monday: 'engineer1@oasistaxiperu.com',
      tuesday: 'engineer2@oasistaxiperu.com',
      wednesday: 'engineer3@oasistaxiperu.com',
      thursday: 'engineer1@oasistaxiperu.com',
      friday: 'engineer2@oasistaxiperu.com',
      weekend: 'on-call-rotation'
    },
    
    responsibilities: [
      'Monitor alerts channel',
      'First response to incidents',
      'Daily health checks',
      'Coordinate with team for major issues',
      'Update status page',
      'Document any incidents'
    ],
    
    handover: {
      time: '17:00 PET',
      template: `
        ## Handover Report - [DATE]
        
        ### Completed Today
        - [ ] Morning health check
        - [ ] Resolved incidents: [LIST]
        - [ ] Deployments: [LIST]
        
        ### Ongoing Issues
        - [Issue 1]: Status, next steps
        - [Issue 2]: Status, next steps
        
        ### For Tomorrow
        - [High priority items]
        - [Scheduled maintenance]
        
        ### Notes
        [Any special considerations]
        
        Signed off: [NAME] at [TIME]
      `
    }
  };

  static readonly DEPLOYMENT_PROCEDURES = {
    preDeployment: [
      'Create deployment ticket',
      'Review and test changes locally',
      'Run automated tests',
      'Get code review approval',
      'Check deployment window'
    ],
    
    deployment: {
      backend: `
        # 1. Deploy to staging
        gcloud run deploy trip-service-staging \\
          --image gcr.io/oasis-taxi-peru/trip-service:$VERSION \\
          --region us-central1
        
        # 2. Run smoke tests
        npm run test:staging
        
        # 3. Deploy to production with traffic splitting
        gcloud run services update-traffic trip-service \\
          --to-revisions trip-service-$VERSION=10 \\
          --region us-central1
        
        # 4. Monitor metrics (15 minutes)
        
        # 5. Gradually increase traffic
        gcloud run services update-traffic trip-service \\
          --to-revisions trip-service-$VERSION=50
        
        # 6. Full rollout if stable
        gcloud run services update-traffic trip-service \\
          --to-revisions trip-service-$VERSION=100
      `,
      
      frontend: `
        # 1. Build Flutter app
        cd app
        flutter build web --release
        
        # 2. Deploy to Firebase Hosting preview
        firebase hosting:channel:deploy preview
        
        # 3. Test preview URL
        # https://oasis-taxi-peru--preview-xxxxx.web.app
        
        # 4. Deploy to production
        firebase deploy --only hosting
      `,
      
      database: `
        # 1. Backup current data
        gcloud firestore export gs://oasis-taxi-peru-backups/pre-deploy-$(date +%Y%m%d)
        
        # 2. Apply security rules to test project
        firebase deploy --only firestore:rules --project oasis-taxi-peru-test
        
        # 3. Run tests against test rules
        npm run test:rules
        
        # 4. Deploy to production
        firebase deploy --only firestore:rules --project oasis-taxi-peru
      `
    },
    
    rollback: {
      trigger: 'Error rate > 5% or P95 latency > 2s',
      procedure: `
        # Immediate rollback
        gcloud run services update-traffic trip-service \\
          --to-revisions trip-service-previous=100 \\
          --region us-central1
        
        # Notify team
        curl -X POST $SLACK_WEBHOOK -d '{"text":"ROLLBACK: trip-service"}'
        
        # Create incident report
        echo "Rollback performed at $(date)" >> incidents.log
      `
    }
  };

  static readonly MAINTENANCE_WINDOWS = {
    scheduled: {
      weekly: {
        day: 'Sunday',
        time: '02:00-04:00 PET',
        tasks: [
          'Database optimization',
          'Log rotation',
          'Certificate renewal check',
          'Security updates'
        ]
      },
      
      monthly: {
        day: 'First Sunday',
        time: '02:00-06:00 PET',
        tasks: [
          'Major version updates',
          'Infrastructure changes',
          'Backup restoration test',
          'Disaster recovery drill'
        ]
      }
    },
    
    notification: {
      internal: '1 week before via Slack',
      external: '3 days before via email and in-app',
      statusPage: 'Update 24 hours before'
    }
  };
}
```

---

## 9. TROUBLESHOOTING GUIDE

### 9.1 Problemas Comunes y Soluciones
```typescript
export class TroubleshootingGuide {
  static readonly COMMON_ISSUES = {
    AUTHENTICATION_ERRORS: {
      symptoms: [
        'Users cannot login',
        'Token validation failures',
        'Permission denied errors'
      ],
      
      diagnostics: {
        checkFirebaseAuth: `
          # Check Firebase Auth status
          curl https://api.oasistaxiperu.com/api/auth/health
          
          # Check recent auth errors
          gcloud logging read "protoPayload.methodName=~'SignIn'" \\
            --limit=20 --format=json
        `,
        
        checkTokens: `
          // Verify JWT token
          const jwt = require('jsonwebtoken');
          const token = 'USER_TOKEN_HERE';
          
          try {
            const decoded = jwt.decode(token, {complete: true});
            console.log('Token claims:', decoded.payload);
            console.log('Expiry:', new Date(decoded.payload.exp * 1000));
          } catch(e) {
            console.error('Invalid token:', e);
          }
        `,
        
        checkCustomClaims: `
          // Check user's custom claims
          admin.auth().getUser(uid)
            .then(user => {
              console.log('Custom claims:', user.customClaims);
              console.log('Email verified:', user.emailVerified);
              console.log('Disabled:', user.disabled);
            });
        `
      },
      
      solutions: [
        {
          issue: 'Token expired',
          fix: 'Force token refresh on client',
          code: 'await FirebaseAuth.instance.currentUser?.getIdToken(true);'
        },
        {
          issue: 'Missing custom claims',
          fix: 'Set claims via Admin SDK',
          code: `admin.auth().setCustomUserClaims(uid, {role: 'passenger'})`
        },
        {
          issue: 'User disabled',
          fix: 'Re-enable user account',
          code: `admin.auth().updateUser(uid, {disabled: false})`
        }
      ]
    },
    
    SLOW_QUERIES: {
      symptoms: [
        'App loading slowly',
        'Timeout errors',
        'High Firestore costs'
      ],
      
      diagnostics: {
        identifySlowQueries: `
          # Check Firestore metrics
          gcloud monitoring metrics-explorer \\
            --metric=firestore.googleapis.com/document/read_count
          
          # Find missing indexes
          gcloud firestore indexes list --format=json | jq '.[] | select(.state != "READY")'
        `,
        
        analyzeUsage: `
          // Analyze collection sizes
          const db = admin.firestore();
          
          async function analyzeCollection(name) {
            const snapshot = await db.collection(name).count().get();
            console.log(\`\${name}: \${snapshot.data().count} documents\`);
          }
          
          ['users', 'trips', 'drivers'].forEach(analyzeCollection);
        `
      },
      
      solutions: [
        {
          issue: 'Missing indexes',
          fix: 'Create composite index',
          command: `
            // firestore.indexes.json
            {
              "indexes": [{
                "collectionGroup": "trips",
                "queryScope": "COLLECTION",
                "fields": [
                  {"fieldPath": "status", "order": "ASCENDING"},
                  {"fieldPath": "createdAt", "order": "DESCENDING"}
                ]
              }]
            }
            
            firebase deploy --only firestore:indexes
          `
        },
        {
          issue: 'Large collections',
          fix: 'Implement pagination',
          code: `
            const pageSize = 20;
            let lastDoc = null;
            
            let query = db.collection('trips')
              .orderBy('createdAt', 'desc')
              .limit(pageSize);
            
            if (lastDoc) {
              query = query.startAfter(lastDoc);
            }
          `
        }
      ]
    },
    
    PAYMENT_ISSUES: {
      symptoms: [
        'Payment processing failures',
        'Webhook not received',
        'Commission calculation errors'
      ],
      
      diagnostics: {
        checkMercadoPago: `
          # Test MercadoPago API
          curl -X GET https://api.mercadopago.com/v1/payment_methods \\
            -H "Authorization: Bearer $MERCADOPAGO_ACCESS_TOKEN"
          
          # Check webhook logs
          gcloud functions logs read handleWebhook --limit=50
        `,
        
        verifyWebhookSignature: `
          const crypto = require('crypto');
          
          function verifyWebhook(payload, signature, secret) {
            const hash = crypto
              .createHmac('sha256', secret)
              .update(payload)
              .digest('hex');
            
            return hash === signature;
          }
        `
      },
      
      solutions: [
        {
          issue: 'Invalid webhook signature',
          fix: 'Update webhook secret',
          command: 'firebase functions:config:set mercadopago.webhook_secret="NEW_SECRET"'
        },
        {
          issue: 'Payment timeout',
          fix: 'Implement retry with exponential backoff',
          code: `
            async function retryPayment(attempt = 1) {
              try {
                return await processPayment();
              } catch (error) {
                if (attempt < 3) {
                  await new Promise(r => setTimeout(r, Math.pow(2, attempt) * 1000));
                  return retryPayment(attempt + 1);
                }
                throw error;
              }
            }
          `
        }
      ]
    },
    
    NOTIFICATION_FAILURES: {
      symptoms: [
        'Push notifications not received',
        'FCM token errors',
        'Topic subscription issues'
      ],
      
      diagnostics: {
        checkFCM: `
          # Test FCM sending
          curl -X POST https://fcm.googleapis.com/fcm/send \\
            -H "Authorization: key=$FCM_SERVER_KEY" \\
            -H "Content-Type: application/json" \\
            -d '{
              "to": "/topics/test",
              "notification": {
                "title": "Test",
                "body": "Test notification"
              }
            }'
        `,
        
        validateToken: `
          // Validate FCM token
          admin.messaging().send({
            token: 'USER_FCM_TOKEN',
            notification: {
              title: 'Test',
              body: 'Token validation'
            }
          }).catch(error => {
            if (error.code === 'messaging/invalid-registration-token') {
              console.log('Invalid token, remove from database');
            }
          });
        `
      },
      
      solutions: [
        {
          issue: 'Invalid FCM tokens',
          fix: 'Clean invalid tokens',
          code: `
            async function cleanInvalidTokens() {
              const users = await db.collection('users').get();
              const batch = db.batch();
              
              for (const doc of users.docs) {
                const token = doc.data().fcmToken;
                if (token) {
                  try {
                    await admin.messaging().send({token, data: {test: 'true'}}, true);
                  } catch (error) {
                    if (error.code === 'messaging/invalid-registration-token') {
                      batch.update(doc.ref, {fcmToken: null});
                    }
                  }
                }
              }
              
              await batch.commit();
            }
          `
        }
      ]
    }
  };

  static readonly EMERGENCY_CONTACTS = {
    internal: {
      CTO: '+51 999 888 777',
      LeadDeveloper: '+51 999 888 776',
      DevOps: '+51 999 888 775',
      Support: 'support@oasistaxiperu.com'
    },
    
    external: {
      GoogleCloud: '+1-855-817-1841',
      Firebase: 'https://firebase.google.com/support',
      MercadoPago: '+51 1 640 8000',
      Twilio: '+1-415-390-2337'
    },
    
    escalation: {
      level1: '0-15 min: On-call engineer',
      level2: '15-30 min: Team lead',
      level3: '30-60 min: CTO',
      level4: '60+ min: CEO'
    }
  };
}
```

---

## 10. EMERGENCY PROCEDURES

### 10.1 Procedimientos de Emergencia
```typescript
export class EmergencyProcedures {
  static readonly DATA_BREACH_RESPONSE = {
    immediateActions: [
      '1. Isolate affected systems',
      '2. Preserve evidence',
      '3. Notify security team',
      '4. Begin investigation',
      '5. Prepare communication'
    ],
    
    isolation: `
      # Disable affected service account
      gcloud iam service-accounts disable suspicious-account@oasis-taxi-peru.iam.gserviceaccount.com
      
      # Revoke all user sessions
      firebase auth:export users.json
      firebase auth:import users.json --hash-algo=HMAC_SHA256 --hash-key=NEW_KEY
      
      # Enable emergency mode
      gcloud firestore databases update "(default)" --type=FIRESTORE_NATIVE --enable-delete-protection
    `,
    
    communication: {
      internal: 'Notify all stakeholders within 1 hour',
      authorities: 'Report to authorities within 24 hours',
      users: 'Notify affected users within 72 hours',
      template: `
        Subject: Important Security Update
        
        Dear User,
        
        We detected unusual activity on our systems on [DATE].
        As a precaution, we have:
        - Reset all passwords
        - Enhanced security measures
        - Initiated a full investigation
        
        Required Action:
        - Reset your password
        - Review your account activity
        - Enable 2FA
        
        We take security seriously and apologize for any inconvenience.
        
        OasisTaxi Security Team
      `
    }
  };

  static readonly COMPLETE_OUTAGE = {
    warRoom: {
      participants: ['CTO', 'Lead Dev', 'DevOps', 'Support Lead'],
      communicationChannel: '#emergency Slack channel',
      meetingLink: 'https://meet.google.com/emergency-room'
    },
    
    recovery: `
      #!/bin/bash
      # Emergency recovery script
      
      echo "Starting emergency recovery..."
      
      # 1. Check all services
      for service in trip-service payment-service notification-service; do
        STATUS=$(gcloud run services describe $service --region=us-central1 --format="value(status.url)")
        if [ -z "$STATUS" ]; then
          echo "Redeploying $service..."
          gcloud run deploy $service --image=gcr.io/oasis-taxi-peru/$service:stable
        fi
      done
      
      # 2. Restore from backup if needed
      LATEST_BACKUP=$(gsutil ls gs://oasis-taxi-peru-backups | tail -1)
      echo "Latest backup: $LATEST_BACKUP"
      
      # 3. Switch to disaster recovery site
      gcloud dns record-sets transaction start --zone=oasistaxiperu-com
      gcloud dns record-sets transaction add --name=api.oasistaxiperu.com. \\
        --ttl=300 --type=A --zone=oasistaxiperu-com "35.244.181.201"
      gcloud dns record-sets transaction execute --zone=oasistaxiperu-com
      
      echo "Recovery complete. Verify all services."
    `,
    
    disasterRecoverySite: {
      location: 'us-east1',
      type: 'Cold standby',
      activationTime: '< 1 hour',
      dataLossObjective: '< 1 hour',
      procedure: [
        'Restore latest backup to DR region',
        'Update DNS to point to DR site',
        'Scale up DR services',
        'Verify functionality',
        'Communicate status'
      ]
    }
  };

  static readonly RUNBOOKS = {
    databaseCorruption: {
      detection: 'Inconsistent data, read errors',
      steps: [
        'Stop writes to affected collections',
        'Export current state',
        'Identify corruption scope',
        'Restore from backup',
        'Replay transactions from logs',
        'Verify data integrity',
        'Resume normal operations'
      ]
    },
    
    ddosAttack: {
      detection: 'Abnormal traffic spike, high latency',
      steps: [
        'Enable Cloud Armor',
        'Configure rate limiting',
        'Block suspicious IPs',
        'Scale up services',
        'Enable Cloudflare if available',
        'Monitor and adjust rules'
      ],
      cloudArmor: `
        # Create security policy
        gcloud compute security-policies create ddos-protection \\
          --description "DDoS protection policy"
        
        # Add rate limiting rule
        gcloud compute security-policies rules create 1000 \\
          --security-policy ddos-protection \\
          --expression "true" \\
          --action "rate-based-ban" \\
          --rate-limit-threshold-count 100 \\
          --rate-limit-threshold-interval-sec 60 \\
          --ban-duration-sec 600
        
        # Apply to load balancer
        gcloud compute backend-services update api-backend \\
          --security-policy ddos-protection
      `
    }
  };
}
```

---

## 📋 RESUMEN EJECUTIVO DE HANDOVER

### Entregables Completados
- ✅ **GCP Console Walkthrough** completo con navegación y configuración
- ✅ **Firebase Console Training** con todas las secciones críticas
- ✅ **Cloud Functions Review** de todas las funciones en producción
- ✅ **Monitoring Setup** con dashboards y alertas configuradas
- ✅ **Incident Response** procedures con playbooks detallados
- ✅ **Cost Management** estrategias y scripts de optimización
- ✅ **Scaling Procedures** automáticas y manuales
- ✅ **Daily Operations Guide** con checklists y rotaciones
- ✅ **Troubleshooting Guide** para problemas comunes
- ✅ **Emergency Procedures** para situaciones críticas

### Información Crítica
- **Proyecto GCP**: oasis-taxi-peru
- **Region Principal**: us-central1
- **Presupuesto Mensual**: $3,500 USD
- **SLA Objetivo**: 99.9% uptime
- **RTO**: 15 minutos
- **RPO**: 1 hora

### Contactos Clave
- **Soporte Google Cloud**: +1-855-817-1841
- **On-call Engineer**: Según rotación diaria
- **Escalación**: CTO en 30 minutos para incidentes críticos

### Próximos Pasos Recomendados
1. Realizar sesión de training hands-on con el equipo
2. Ejecutar simulacro de incident response
3. Revisar y ajustar alertas según patrones reales
4. Implementar automation adicional para tareas repetitivas
5. Establecer métricas de mejora continua

---

**Documentación de Handover Completa para OasisTaxi**
**100% en Google Cloud Platform**
**Producción Ready** 🚀

*Documento preparado para transferencia inmediata al equipo de operaciones*