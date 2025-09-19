# 🏗️ DIAGRAMAS DE ARQUITECTURA - OASISTAXI PERÚ

## 📊 ARQUITECTURA GENERAL DEL SISTEMA

```mermaid
graph TB
    subgraph "Frontend Layer"
        A[Flutter App]
        B[Web Landing Page]
        C[Admin Dashboard]
    end
    
    subgraph "Firebase Services"
        D[Firebase Auth]
        E[Cloud Firestore]
        F[Firebase Storage]
        G[Firebase Functions]
        H[Firebase Hosting]
        I[Firebase Messaging]
        J[Firebase Analytics]
    end
    
    subgraph "Google Cloud Platform"
        K[Cloud CDN]
        L[Cloud Armor]
        M[Load Balancer]
        N[Identity Platform]
        O[Security Command Center]
        P[Cloud KMS]
    end
    
    subgraph "External Services"
        Q[Google Maps API]
        R[MercadoPago API]
        S[SMS Gateway]
        T[Email Service]
    end
    
    A --> D
    A --> E
    A --> F
    A --> G
    A --> I
    B --> H
    B --> K
    C --> E
    C --> G
    
    G --> E
    G --> F
    G --> Q
    G --> R
    G --> S
    G --> T
    
    H --> K
    K --> L
    L --> M
    D --> N
    N --> O
    E --> P
    F --> P
    
    style A fill:#4CAF50
    style E fill:#FF9800
    style G fill:#2196F3
    style Q fill:#9C27B0
    style R fill:#FF5722
```

## 🔄 FLUJO DE DATOS PRINCIPAL

```mermaid
sequenceDiagram
    participant P as Pasajero App
    participant D as Conductor App
    participant A as Admin Panel
    participant F as Firebase
    participant G as Google Cloud
    participant M as MercadoPago
    
    Note over P,M: Flujo Completo de Viaje
    
    P->>F: 1. Autenticación (Phone/Google)
    F-->>P: Token de acceso
    
    P->>F: 2. Solicitar viaje con precio inicial
    F->>D: 3. Notificar conductores cercanos
    
    D->>F: 4. Aceptar/Contraoferta
    F->>P: 5. Notificar negociación
    
    P->>F: 6. Aceptar precio final
    F->>D: 7. Confirmar viaje
    
    D->>F: 8. Actualizaciones de ubicación
    F->>P: 9. Tracking en tiempo real
    
    P->>F: 10. Completar viaje
    P->>M: 11. Procesar pago
    M-->>F: 12. Webhook confirmación
    
    F->>A: 13. Registrar métricas
    A->>G: 14. Análisis y reportes
```

## 🎯 ARQUITECTURA POR CAPAS

```mermaid
graph TB
    subgraph "Presentation Layer"
        A1[Screens - UI Components]
        A2[Widgets - Reusable Components]
        A3[Navigation - Route Management]
    end
    
    subgraph "Business Logic Layer"
        B1[Providers - State Management]
        B2[Models - Data Structures]
        B3[Utils - Helper Functions]
    end
    
    subgraph "Service Layer"
        C1[Firebase Service]
        C2[Location Service]
        C3[Payment Service]
        C4[Notification Service]
        C5[Security Service]
    end
    
    subgraph "Data Layer"
        D1[Firestore Database]
        D2[Firebase Storage]
        D3[Local Storage]
        D4[Cache Management]
    end
    
    A1 --> B1
    A2 --> B1
    A3 --> B1
    
    B1 --> C1
    B1 --> C2
    B1 --> C3
    B1 --> C4
    B1 --> C5
    
    C1 --> D1
    C1 --> D2
    C2 --> D3
    C3 --> D1
    C4 --> D1
    C5 --> D4
    
    style A1 fill:#E3F2FD
    style B1 fill:#F3E5F5
    style C1 fill:#E8F5E8
    style D1 fill:#FFF3E0
```

## 🔐 ARQUITECTURA DE SEGURIDAD

```mermaid
graph TB
    subgraph "Authentication Layer"
        A1[Firebase Auth]
        A2[Phone Verification]
        A3[Google OAuth]
        A4[Biometric Auth]
    end
    
    subgraph "Authorization Layer"
        B1[Identity Platform]
        B2[IAM Roles]
        B3[Firestore Rules]
        B4[Storage Rules]
    end
    
    subgraph "Security Controls"
        C1[Cloud Armor WAF]
        C2[DDoS Protection]
        C3[Rate Limiting]
        C4[SSL/TLS Encryption]
    end
    
    subgraph "Data Protection"
        D1[Encryption at Rest]
        D2[Encryption in Transit]
        D3[Cloud KMS]
        D4[VPC Service Controls]
    end
    
    subgraph "Monitoring & Compliance"
        E1[Security Command Center]
        E2[Audit Logging]
        E3[Threat Detection]
        E4[Compliance Reports]
    end
    
    A1 --> B1
    A2 --> B1
    A3 --> B1
    A4 --> B1
    
    B1 --> C1
    B2 --> C1
    B3 --> C2
    B4 --> C3
    
    C1 --> D1
    C2 --> D2
    C3 --> D3
    C4 --> D4
    
    D1 --> E1
    D2 --> E2
    D3 --> E3
    D4 --> E4
    
    style A1 fill:#FFEBEE
    style B1 fill:#F3E5F5
    style C1 fill:#E0F2F1
    style D1 fill:#FFF3E0
    style E1 fill:#E8EAF6
```

## 🚗 FLUJO DE NEGOCIACIÓN DE PRECIOS

```mermaid
stateDiagram-v2
    [*] --> SolicitarViaje
    SolicitarViaje --> EsperandoConductor: Precio inicial propuesto
    
    EsperandoConductor --> ConductorAcepta: Conductor acepta precio
    EsperandoConductor --> ConductorContraoferta: Conductor hace contraoferta
    EsperandoConductor --> Expirado: Timeout (15 min)
    
    ConductorContraoferta --> PasajeroAcepta: Pasajero acepta
    ConductorContraoferta --> PasajeroRechaza: Pasajero rechaza
    ConductorContraoferta --> ExpiradoNegociacion: Timeout (5 min)
    
    PasajeroRechaza --> NuevoRound: Round < 3
    PasajeroRechaza --> Cancelado: Round = 3
    
    NuevoRound --> EsperandoConductor: Nueva propuesta
    
    ConductorAcepta --> ViajeConfirmado
    PasajeroAcepta --> ViajeConfirmado
    
    ViajeConfirmado --> EnCamino: Conductor en route
    EnCamino --> Recogido: Pasajero recogido
    Recogido --> Completado: Destino alcanzado
    
    Expirado --> [*]
    Cancelado --> [*]
    ExpiradoNegociacion --> [*]
    Completado --> [*]
```

## 📱 ARQUITECTURA MÓVIL

```mermaid
graph TB
    subgraph "Flutter App Structure"
        A1[main.dart - Entry Point]
        A2[App Router - Navigation]
        A3[Theme Provider - Styling]
        A4[Firebase Initializer]
    end
    
    subgraph "Feature Modules"
        B1[Auth Module]
        B2[Trip Module]
        B3[Payment Module]
        B4[Chat Module]
        B5[Profile Module]
        B6[Admin Module]
    end
    
    subgraph "Shared Components"
        C1[Common Widgets]
        C2[Service Classes]
        C3[Model Classes]
        C4[Utility Functions]
        C5[Constants]
    end
    
    subgraph "External Dependencies"
        D1[Firebase SDK]
        D2[Google Maps]
        D3[MercadoPago SDK]
        D4[Push Notifications]
        D5[Local Storage]
    end
    
    A1 --> A2
    A1 --> A3
    A1 --> A4
    
    A2 --> B1
    A2 --> B2
    A2 --> B3
    A2 --> B4
    A2 --> B5
    A2 --> B6
    
    B1 --> C1
    B2 --> C2
    B3 --> C3
    B4 --> C4
    B5 --> C5
    B6 --> C1
    
    C2 --> D1
    C2 --> D2
    C2 --> D3
    C2 --> D4
    C2 --> D5
    
    style A1 fill:#4CAF50
    style B1 fill:#2196F3
    style C1 fill:#FF9800
    style D1 fill:#9C27B0
```

## 🔄 ARQUITECTURA DE MICROSERVICIOS

```mermaid
graph TB
    subgraph "API Gateway"
        A[Firebase Functions Gateway]
    end
    
    subgraph "Core Services"
        B1[User Service]
        B2[Trip Service]
        B3[Payment Service]
        B4[Notification Service]
        B5[Location Service]
    end
    
    subgraph "Support Services"
        C1[Analytics Service]
        C2[Security Service]
        C3[File Upload Service]
        C4[Chat Service]
        C5[Admin Service]
    end
    
    subgraph "External Integrations"
        D1[Google Maps Service]
        D2[MercadoPago Service]
        D3[SMS Service]
        D4[Email Service]
        D5[Push Notification Service]
    end
    
    subgraph "Data Stores"
        E1[Firestore Users]
        E2[Firestore Trips]
        E3[Firestore Payments]
        E4[Firestore Chat]
        E5[Firebase Storage]
    end
    
    A --> B1
    A --> B2
    A --> B3
    A --> B4
    A --> B5
    
    A --> C1
    A --> C2
    A --> C3
    A --> C4
    A --> C5
    
    B1 --> E1
    B2 --> E2
    B3 --> E3
    B4 --> D5
    B5 --> D1
    
    B3 --> D2
    B4 --> D3
    B4 --> D4
    C3 --> E5
    C4 --> E4
    
    style A fill:#FF5722
    style B1 fill:#4CAF50
    style C1 fill:#2196F3
    style D1 fill:#FF9800
    style E1 fill:#9C27B0
```

## 🗄️ MODELO DE DATOS FIRESTORE

```mermaid
erDiagram
    USERS ||--o{ TRIPS : creates
    USERS ||--o{ DOCUMENTS : uploads
    USERS ||--o{ VEHICLES : owns
    USERS ||--o{ PAYMENTS : makes
    
    TRIPS ||--o{ PRICE_NEGOTIATIONS : has
    TRIPS ||--o{ CHAT_MESSAGES : contains
    TRIPS ||--o{ TRIP_UPDATES : generates
    TRIPS ||--o{ RATINGS : receives
    
    PRICE_NEGOTIATIONS ||--o{ NEGOTIATION_ROUNDS : contains
    
    USERS {
        string uid PK
        string email
        string phone
        string firstName
        string lastName
        string userType
        string profileImage
        boolean isActive
        timestamp createdAt
        timestamp lastLoginAt
        map preferences
        number rating
        number totalTrips
    }
    
    TRIPS {
        string tripId PK
        string passengerId FK
        string driverId FK
        string status
        map pickupLocation
        map destinationLocation
        string vehicleType
        number estimatedDistance
        number estimatedDuration
        number finalPrice
        string paymentMethod
        timestamp createdAt
        timestamp completedAt
        map rating
    }
    
    PRICE_NEGOTIATIONS {
        string negotiationId PK
        string tripId FK
        string passengerId FK
        string driverId FK
        string status
        number initialPrice
        number driverOffer
        number finalPrice
        array rounds
        timestamp expiresAt
        timestamp createdAt
    }
    
    VEHICLES {
        string vehicleId PK
        string driverId FK
        string make
        string model
        number year
        string color
        string licensePlate
        string vehicleType
        number capacity
        boolean isActive
        map documents
    }
    
    DOCUMENTS {
        string documentId PK
        string userId FK
        string documentType
        string fileName
        string fileUrl
        string status
        string verificationNotes
        timestamp uploadedAt
        timestamp verifiedAt
        string verifiedBy
        timestamp expirationDate
    }
    
    PAYMENTS {
        string paymentId PK
        string tripId FK
        string userId FK
        number amount
        string method
        string status
        string transactionId
        map metadata
        timestamp createdAt
        timestamp processedAt
    }
    
    CHAT_MESSAGES {
        string messageId PK
        string tripId FK
        string senderId FK
        string senderType
        string content
        string type
        map location
        timestamp timestamp
        boolean isRead
    }
```

## 🌐 ARQUITECTURA DE RED

```mermaid
graph TB
    subgraph "Internet"
        A[Client Devices]
    end
    
    subgraph "Google Cloud CDN"
        B[Edge Locations]
        C[Origin Servers]
    end
    
    subgraph "Cloud Armor"
        D[WAF Rules]
        E[DDoS Protection]
        F[Rate Limiting]
    end
    
    subgraph "Load Balancer"
        G[Global LB]
        H[Regional LB]
        I[Health Checks]
    end
    
    subgraph "Firebase Hosting"
        J[Static Assets]
        K[Web App]
        L[PWA Support]
    end
    
    subgraph "Firebase Functions"
        M[API Endpoints]
        N[Background Tasks]
        O[Scheduled Functions]
    end
    
    subgraph "Firebase Services"
        P[Firestore]
        Q[Storage]
        R[Auth]
        S[Messaging]
    end
    
    A --> B
    B --> C
    C --> D
    D --> E
    E --> F
    F --> G
    G --> H
    H --> I
    I --> J
    I --> M
    
    J --> K
    J --> L
    
    M --> N
    M --> O
    
    N --> P
    N --> Q
    O --> R
    O --> S
    
    style A fill:#E3F2FD
    style B fill:#F3E5F5
    style D fill:#E8F5E8
    style G fill:#FFF3E0
    style J fill:#FFEBEE
    style M fill:#F9FBE7
    style P fill:#FCE4EC
```

## 📊 ARQUITECTURA DE ANALYTICS

```mermaid
graph TB
    subgraph "Data Collection"
        A1[Firebase Analytics]
        A2[Custom Events]
        A3[Performance Monitoring]
        A4[Crashlytics]
    end
    
    subgraph "Data Processing"
        B1[Firebase Functions]
        B2[Data Aggregation]
        B3[Real-time Processing]
        B4[Batch Processing]
    end
    
    subgraph "Data Storage"
        C1[BigQuery]
        C2[Cloud Storage]
        C3[Firestore Aggregates]
        C4[Cloud SQL Reports]
    end
    
    subgraph "Data Visualization"
        D1[Firebase Console]
        D2[Google Analytics]
        D3[Custom Dashboards]
        D4[Admin Reports]
    end
    
    subgraph "Business Intelligence"
        E1[Trip Analytics]
        E2[Revenue Reports]
        E3[User Behavior]
        E4[Performance KPIs]
    end
    
    A1 --> B1
    A2 --> B2
    A3 --> B3
    A4 --> B4
    
    B1 --> C1
    B2 --> C2
    B3 --> C3
    B4 --> C4
    
    C1 --> D1
    C2 --> D2
    C3 --> D3
    C4 --> D4
    
    D1 --> E1
    D2 --> E2
    D3 --> E3
    D4 --> E4
    
    style A1 fill:#E8F5E8
    style B1 fill:#E3F2FD
    style C1 fill:#FFF3E0
    style D1 fill:#F3E5F5
    style E1 fill:#FFEBEE
```

## 🔧 ARQUITECTURA DE DEPLOYMENT

```mermaid
graph TB
    subgraph "Development"
        A1[Local Development]
        A2[Feature Branches]
        A3[Unit Testing]
    end
    
    subgraph "Staging"
        B1[Staging Environment]
        B2[Integration Testing]
        B3[User Acceptance Testing]
    end
    
    subgraph "Production"
        C1[Production Environment]
        C2[Blue-Green Deployment]
        C3[Canary Releases]
    end
    
    subgraph "CI/CD Pipeline"
        D1[GitHub Actions]
        D2[Automated Testing]
        D3[Security Scanning]
        D4[Performance Testing]
    end
    
    subgraph "Monitoring"
        E1[Firebase Performance]
        E2[Cloud Monitoring]
        E3[Error Tracking]
        E4[Alerting]
    end
    
    A1 --> D1
    A2 --> D2
    A3 --> D3
    
    D1 --> B1
    D2 --> B2
    D3 --> B3
    D4 --> B1
    
    B1 --> C1
    B2 --> C2
    B3 --> C3
    
    C1 --> E1
    C2 --> E2
    C3 --> E3
    C3 --> E4
    
    style A1 fill:#E8F5E8
    style B1 fill:#FFF3E0
    style C1 fill:#FFEBEE
    style D1 fill:#E3F2FD
    style E1 fill:#F3E5F5
```

## 📱 RESPONSIVE DESIGN ARCHITECTURE

```mermaid
graph TB
    subgraph "Screen Sizes"
        A1[Mobile Phone]
        A2[Tablet]
        A3[Desktop Web]
        A4[Large Screen]
    end
    
    subgraph "Layout System"
        B1[Responsive Widgets]
        B2[Adaptive Layouts]
        B3[Breakpoint Management]
        B4[Orientation Handling]
    end
    
    subgraph "Navigation Patterns"
        C1[Bottom Navigation]
        C2[Drawer Navigation]
        C3[Tab Navigation]
        C4[Nested Navigation]
    end
    
    subgraph "UI Components"
        D1[Scalable Widgets]
        D2[Flexible Grids]
        D3[Adaptive Typography]
        D4[Touch Targets]
    end
    
    A1 --> B1
    A2 --> B2
    A3 --> B3
    A4 --> B4
    
    B1 --> C1
    B2 --> C2
    B3 --> C3
    B4 --> C4
    
    C1 --> D1
    C2 --> D2
    C3 --> D3
    C4 --> D4
    
    style A1 fill:#4CAF50
    style B1 fill:#2196F3
    style C1 fill:#FF9800
    style D1 fill:#9C27B0
```

## 🌍 DISTRIBUCIÓN GEOGRÁFICA

```mermaid
graph TB
    subgraph "Perú - Primary Region"
        A1[Lima - Primary DC]
        A2[Arequipa - Secondary]
        A3[Trujillo - Edge]
    end
    
    subgraph "South America"
        B1[São Paulo - Backup]
        B2[Santiago - CDN Edge]
    end
    
    subgraph "North America"
        C1[US Central - Analytics]
        C2[US East - CDN Edge]
    end
    
    subgraph "Global Services"
        D1[Firebase Global]
        D2[Google CDN Global]
        D3[Cloud Armor Global]
    end
    
    A1 --> B1
    A2 --> B2
    A3 --> C1
    
    B1 --> D1
    B2 --> D2
    C1 --> D3
    C2 --> D1
    
    D1 --> D2
    D2 --> D3
    
    style A1 fill:#4CAF50
    style B1 fill:#FF9800
    style C1 fill:#2196F3
    style D1 fill:#9C27B0
```

---

**Versión de Diagramas:** 1.0.0  
**Última Actualización:** Enero 2025  
**Herramientas Utilizadas:** Mermaid.js  
**Mantenido por:** OasisTaxi Development Team

**Notas:**
- Todos los diagramas están en formato Mermaid para fácil edición
- Los diagramas se pueden renderizar en cualquier herramienta compatible con Mermaid
- Para modificaciones, actualizar este archivo y regenerar las imágenes según sea necesario