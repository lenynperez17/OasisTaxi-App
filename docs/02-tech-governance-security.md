# Stack Tecnológico, Gobernanza y Seguridad - OASIS TAXI

## 7. Selección de Stack Tecnológico & GCP

### Stack Tecnológico Completo

#### Frontend - Aplicaciones Móviles

| Componente | Tecnología | Versión | Justificación |
|------------|-----------|---------|---------------|
| **Framework** | Flutter | 3.24.x | Desarrollo multiplataforma, hot reload, rendimiento nativo |
| **Lenguaje** | Dart | 3.5.x | Type-safe, async/await nativo, null safety |
| **State Management** | Riverpod | 2.5.x | Reactive, testeable, type-safe |
| **Navegación** | Go Router | 14.x | Declarativa, deep linking, guards |
| **HTTP Client** | Dio | 5.x | Interceptors, retry logic, cache |
| **Almacenamiento Local** | Hive | 2.x | NoSQL rápido, encriptación |
| **Mapas** | Google Maps Flutter | 2.x | Integración nativa, personalizable |
| **Pagos** | Mercado Pago SDK | Latest | Soporte local, múltiples métodos |
| **Analytics** | Firebase Analytics | Latest | Eventos custom, funnels |
| **Crash Reporting** | Firebase Crashlytics | Latest | Stack traces, alertas |

#### Backend - Servicios y APIs

| Componente | Tecnología | Versión | Justificación |
|------------|-----------|---------|---------------|
| **Runtime** | Node.js | 20 LTS | Performance, ecosystem, async |
| **Framework** | Express | 4.x | Minimalista, flexible, maduro |
| **TypeScript** | TypeScript | 5.x | Type safety, mejor DX |
| **API Docs** | OpenAPI 3.0 | 3.x | Estándar industria, generación SDK |
| **Validación** | Joi | 17.x | Schemas robustos, mensajes custom |
| **ORM** | Prisma | 5.x | Type-safe, migrations, performance |
| **Queue** | Bull | 4.x | Redis-based, reliable, dashboard |
| **WebSockets** | Socket.io | 4.x | Real-time, reconexión automática |
| **Testing** | Jest | 29.x | Rápido, mocking, coverage |

#### Infraestructura - Google Cloud Platform

| Servicio | Uso | Configuración |
|----------|-----|---------------|
| **Cloud Run** | Microservicios | Autoscaling, min 1 - max 100 instancias |
| **Cloud Functions** | Procesamiento async | Cold start optimizado, 512MB RAM |
| **Cloud SQL** | PostgreSQL 15 | HA, replicas lectura, backups automáticos |
| **Firestore** | Real-time data | Multi-region, índices compuestos |
| **Cloud Storage** | Archivos estáticos | Standard tier, lifecycle policies |
| **Memorystore** | Redis cache | 2GB, alta disponibilidad |
| **Cloud Pub/Sub** | Mensajería | At-least-once delivery, DLQ |
| **Cloud Load Balancer** | Distribución tráfico | HTTPS, CDN, WAF |
| **Cloud Endpoints** | API Gateway | Rate limiting, API keys |
| **Cloud Build** | CI/CD | Triggers automáticos, cache |
| **Container Registry** | Docker images | Vulnerability scanning |
| **Cloud Monitoring** | Observabilidad | Custom metrics, alertas |
| **Cloud Logging** | Logs centralizados | Retención 30 días, export a BigQuery |
| **Secret Manager** | Gestión secretos | Rotación automática |
| **Cloud IAM** | Control acceso | Principio menor privilegio |

### Decisiones Técnicas Clave

#### ¿Por qué Flutter para las 3 apps?

```dart
// Código compartido entre las 3 apps
// packages/shared/lib/models/user.dart
class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? photoUrl;
  
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.photoUrl,
  });
}

// Reutilización de widgets
// packages/shared/lib/widgets/oasis_button.dart
class OasisButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final ButtonType type;
  
  const OasisButton({
    required this.text,
    required this.onPressed,
    this.type = ButtonType.primary,
  });
  
  @override
  Widget build(BuildContext context) {
    // Implementación compartida
  }
}
```

**Ventajas**:
- 70% código compartido
- Un solo equipo de desarrollo
- Consistencia UI/UX
- Time to market reducido
- Mantenimiento simplificado

#### ¿Por qué Node.js + TypeScript?

```typescript
// Type safety + async performance
// services/ride-service/src/controllers/ride.controller.ts

interface CreateRideDTO {
  passengerId: string;
  pickup: Location;
  destination: Location;
  paymentMethod: PaymentMethod;
}

export class RideController {
  async createRide(req: Request<{}, {}, CreateRideDTO>, res: Response) {
    try {
      const ride = await this.rideService.create(req.body);
      res.status(201).json({ success: true, data: ride });
    } catch (error) {
      this.handleError(error, res);
    }
  }
}
```

**Ventajas**:
- Non-blocking I/O ideal para real-time
- Mismo lenguaje que Flutter (similar sintaxis)
- Gran ecosistema de librerías
- TypeScript previene errores en desarrollo
- Excelente para microservicios

## 8. Gobernanza de Código

### Flujo de Trabajo Git (Gitflow)

```
main (producción)
  │
  └── develop (desarrollo)
       │
       ├── feature/OT-123-payment-integration
       ├── feature/OT-124-driver-notifications
       │
       ├── bugfix/OT-125-fix-location-update
       │
       ├── release/v1.2.0
       │
       └── hotfix/OT-126-critical-payment-fix
```

### Conventional Commits

```bash
# Formato estricto
<type>(<scope>): <subject>

<body>

<footer>

# Ejemplos reales del proyecto
feat(passenger): agregar botón de pánico con geolocalización
fix(driver): corregir cálculo de distancia en rutas con desvíos
perf(maps): optimizar renderizado de marcadores en zoom out
docs(api): actualizar documentación de endpoint de pagos
refactor(auth): migrar a Firebase Auth v10
test(rides): agregar pruebas E2E para flujo completo
chore(deps): actualizar Flutter a 3.24.0
```

### Configuración de Hooks

```bash
# .githooks/commit-msg
#!/bin/bash
# Validar formato Conventional Commits

commit_regex='^(feat|fix|docs|style|refactor|perf|test|chore)(\([a-z]+\))?: .{1,50}$'

if ! grep -qE "$commit_regex" "$1"; then
    echo "Error: Commit no sigue Conventional Commits"
    echo "Formato: <type>(<scope>): <subject>"
    exit 1
fi
```

### Branch Protection Rules

```yaml
# .github/branch-protection.yml
protection_rules:
  main:
    required_reviews: 2
    dismiss_stale_reviews: true
    require_code_owner_reviews: true
    required_status_checks:
      - build
      - test
      - security-scan
    enforce_admins: true
    restrictions:
      users: ["cto", "lead-dev"]
      
  develop:
    required_reviews: 1
    required_status_checks:
      - build
      - test
```

### Code Review Checklist

```markdown
## Checklist de Revisión

### Funcionalidad
- [ ] El código cumple con los requisitos
- [ ] Sin regresiones identificadas
- [ ] Edge cases considerados

### Código
- [ ] Sigue estándares del proyecto
- [ ] Sin código duplicado
- [ ] Complejidad apropiada
- [ ] Nombres descriptivos

### Testing
- [ ] Tests unitarios agregados
- [ ] Tests de integración si aplica
- [ ] Cobertura >= 80%

### Seguridad
- [ ] Sin credenciales hardcodeadas
- [ ] Validación de inputs
- [ ] Sin vulnerabilidades conocidas

### Performance
- [ ] Sin N+1 queries
- [ ] Uso eficiente de memoria
- [ ] Operaciones async donde corresponde

### Documentación
- [ ] Código auto-documentado
- [ ] README actualizado si necesario
- [ ] Comentarios en lógica compleja
```

### Versionado Semántico

```bash
# MAJOR.MINOR.PATCH

# v1.0.0 - Lanzamiento inicial
# v1.1.0 - Nueva funcionalidad (pagos QR)
# v1.1.1 - Bugfix en cálculo de tarifas
# v2.0.0 - Breaking change (nueva API)

# Tags automáticos
git tag -a v1.2.0 -m "Release: Agregar viajes compartidos"
git push origin v1.2.0
```

## 9. Seguridad y Cumplimiento Normativo

### Arquitectura de Seguridad

```
┌─────────────────────────────────────────────────────────┐
│                    Security Layers                       │
├─────────────────────────────────────────────────────────┤
│ Layer 1: Network Security                               │
│ - Cloud Armor (DDoS protection)                        │
│ - VPC with private subnets                             │
│ - Cloud NAT for egress                                 │
├─────────────────────────────────────────────────────────┤
│ Layer 2: Application Security                          │
│ - OAuth 2.0 + JWT                                      │
│ - API rate limiting                                    │
│ - Input validation & sanitization                      │
├─────────────────────────────────────────────────────────┤
│ Layer 3: Data Security                                 │
│ - Encryption at rest (AES-256)                         │
│ - Encryption in transit (TLS 1.3)                      │
│ - Field-level encryption for PII                       │
├─────────────────────────────────────────────────────────┤
│ Layer 4: Access Control                                │
│ - IAM with least privilege                             │
│ - MFA for admin accounts                               │
│ - Service accounts with limited scope                  │
└─────────────────────────────────────────────────────────┘
```

### OWASP MASVS Compliance

#### 1. Arquitectura y Diseño

```dart
// Implementación de Certificate Pinning
class SecureHttpClient {
  static final dio = Dio();
  
  static void configurePinning() {
    (dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (client) {
      client.badCertificateCallback = (cert, host, port) {
        // Verificar fingerprint del certificado
        final fingerprint = sha256.convert(cert.der).toString();
        return _validFingerprints.contains(fingerprint);
      };
      return client;
    };
  }
}
```

#### 2. Almacenamiento de Datos

```dart
// Encriptación local con Hive
class SecureStorage {
  static Future<Box> openSecureBox(String name) async {
    final encryptionKey = await _getOrGenerateKey();
    return await Hive.openBox(
      name,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
  }
  
  static Future<Uint8List> _getOrGenerateKey() async {
    const storage = FlutterSecureStorage();
    String? key = await storage.read(key: 'encryption_key');
    
    if (key == null) {
      final newKey = Hive.generateSecureKey();
      await storage.write(
        key: 'encryption_key',
        value: base64.encode(newKey),
      );
      return newKey;
    }
    
    return base64.decode(key);
  }
}
```

#### 3. Criptografía

```typescript
// Backend: Encriptación de datos sensibles
import { createCipheriv, createDecipheriv, randomBytes } from 'crypto';

export class EncryptionService {
  private algorithm = 'aes-256-gcm';
  private key = Buffer.from(process.env.ENCRYPTION_KEY!, 'base64');
  
  encrypt(text: string): EncryptedData {
    const iv = randomBytes(16);
    const cipher = createCipheriv(this.algorithm, this.key, iv);
    
    let encrypted = cipher.update(text, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    
    const authTag = cipher.getAuthTag();
    
    return {
      encrypted,
      iv: iv.toString('hex'),
      authTag: authTag.toString('hex')
    };
  }
  
  decrypt(encryptedData: EncryptedData): string {
    const decipher = createDecipheriv(
      this.algorithm,
      this.key,
      Buffer.from(encryptedData.iv, 'hex')
    );
    
    decipher.setAuthTag(Buffer.from(encryptedData.authTag, 'hex'));
    
    let decrypted = decipher.update(encryptedData.encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    
    return decrypted;
  }
}
```

#### 4. Autenticación y Gestión de Sesiones

```typescript
// JWT con refresh tokens
export class AuthService {
  generateTokens(userId: string, role: UserRole) {
    const accessToken = jwt.sign(
      { userId, role },
      process.env.JWT_SECRET!,
      { expiresIn: '15m' }
    );
    
    const refreshToken = jwt.sign(
      { userId, type: 'refresh' },
      process.env.JWT_REFRESH_SECRET!,
      { expiresIn: '7d' }
    );
    
    // Guardar refresh token hasheado en DB
    const hashedToken = crypto
      .createHash('sha256')
      .update(refreshToken)
      .digest('hex');
      
    this.storeRefreshToken(userId, hashedToken);
    
    return { accessToken, refreshToken };
  }
}
```

#### 5. Comunicación de Red

```dart
// Implementación de request signing
class ApiClient {
  Future<Response> secureRequest(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final nonce = _generateNonce();
    
    final signature = _generateSignature(
      method: 'POST',
      endpoint: endpoint,
      timestamp: timestamp,
      nonce: nonce,
      body: jsonEncode(data),
    );
    
    return dio.post(
      endpoint,
      data: data,
      options: Options(headers: {
        'X-Timestamp': timestamp,
        'X-Nonce': nonce,
        'X-Signature': signature,
      }),
    );
  }
}
```

### Cumplimiento GDPR

#### 1. Privacidad por Diseño

```typescript
// Anonimización de datos
export class PrivacyService {
  anonymizeUser(user: User): AnonymizedUser {
    return {
      id: this.hashId(user.id),
      ageRange: this.getAgeRange(user.birthDate),
      city: user.address.city, // Sin dirección exacta
      // Omitir nombre, email, teléfono
    };
  }
  
  async deleteUserData(userId: string) {
    // Soft delete manteniendo datos mínimos para cumplimiento legal
    await db.transaction(async (tx) => {
      // Anonimizar datos personales
      await tx.users.update({
        where: { id: userId },
        data: {
          email: `deleted_${userId}@deleted.com`,
          phone: '0000000000',
          name: 'Usuario Eliminado',
          status: 'deleted'
        }
      });
      
      // Eliminar datos no esenciales
      await tx.paymentMethods.deleteMany({ where: { userId } });
      await tx.favoriteLocations.deleteMany({ where: { userId } });
    });
  }
}
```

#### 2. Consentimiento Explícito

```dart
class ConsentManager {
  static Future<bool> requestConsents() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConsentDialog(
        consents: [
          Consent(
            type: ConsentType.dataProcessing,
            title: 'Procesamiento de Datos',
            description: 'Necesitamos procesar tus datos...',
            required: true,
          ),
          Consent(
            type: ConsentType.marketing,
            title: 'Comunicaciones de Marketing',
            description: 'Recibir ofertas y promociones...',
            required: false,
          ),
        ],
      ),
    );
  }
}
```

### Cumplimiento PCI DSS

#### 1. No Almacenar Datos de Tarjetas

```typescript
// Tokenización con Mercado Pago
export class PaymentService {
  async processPayment(
    rideId: string,
    paymentMethodId: string, // Token de MP, no número de tarjeta
    amount: number
  ) {
    const payment = await mercadopago.payment.create({
      transaction_amount: amount,
      token: paymentMethodId,
      description: `Viaje ${rideId}`,
      installments: 1,
      payment_method_id: 'visa',
      payer: { email: user.email }
    });
    
    // Solo guardamos referencia, no datos sensibles
    await this.savePaymentReference(rideId, payment.id);
  }
}
```

#### 2. Logs de Auditoría

```typescript
// Sistema de auditoría completo
export class AuditLogger {
  async log(event: AuditEvent) {
    const entry: AuditLog = {
      timestamp: new Date(),
      userId: event.userId,
      action: event.action,
      resource: event.resource,
      ip: event.ip,
      userAgent: event.userAgent,
      result: event.result,
      // Nunca loguear datos sensibles
      metadata: this.sanitizeMetadata(event.metadata)
    };
    
    await db.auditLogs.create({ data: entry });
    
    // Alertas para eventos críticos
    if (this.isCriticalEvent(event)) {
      await this.alertSecurityTeam(event);
    }
  }
  
  private sanitizeMetadata(metadata: any): any {
    // Remover campos sensibles
    const { password, cardNumber, cvv, ...safe } = metadata;
    return safe;
  }
}
```

### Security Headers

```typescript
// Configuración de headers de seguridad
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", "https://api.mercadopago.com"],
      fontSrc: ["'self'"],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'"],
      frameSrc: ["'none'"],
    },
  },
  crossOriginEmbedderPolicy: true,
  crossOriginOpenerPolicy: true,
  crossOriginResourcePolicy: { policy: "cross-origin" },
  dnsPrefetchControl: true,
  frameguard: { action: 'deny' },
  hidePoweredBy: true,
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  },
  ieNoOpen: true,
  noSniff: true,
  originAgentCluster: true,
  permittedCrossDomainPolicies: false,
  referrerPolicy: { policy: "no-referrer" },
  xssFilter: true,
}));
```

### Monitoreo de Seguridad

```yaml
# Cloud Security Command Center
security_monitoring:
  - vulnerability_scanning:
      containers: true
      web_apps: true
      frequency: daily
      
  - intrusion_detection:
      network: true
      application: true
      
  - compliance_monitoring:
      standards:
        - OWASP_MASVS
        - PCI_DSS
        - GDPR
        
  - alerts:
      - suspicious_activity
      - failed_auth_attempts > 5
      - data_exfiltration_attempts
      - privilege_escalation
```

---

Este documento establece los estándares técnicos, de gobernanza y seguridad para garantizar un desarrollo robusto, mantenible y seguro de la plataforma OASIS TAXI.