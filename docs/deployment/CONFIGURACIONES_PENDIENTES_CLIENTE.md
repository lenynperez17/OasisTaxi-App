# ⚠️ CONFIGURACIONES PENDIENTES - ACCIÓN REQUERIDA DEL CLIENTE
## OasisTaxiPeru - Elementos que Requieren Configuración Manual
### Documento de Transferencia y Setup Final

---

## 🔴 ITEMS CRÍTICOS QUE REQUIEREN ACCIÓN INMEDIATA DEL CLIENTE

### 1. CUENTAS Y SUSCRIPCIONES A CREAR

#### 1.1 Google Cloud Platform (GCP)
```yaml
Estado: PENDIENTE - Requiere tarjeta de crédito del cliente
Acciones necesarias:
  1. Crear cuenta GCP en: https://console.cloud.google.com
  2. Configurar billing con tarjeta corporativa
  3. Activar free tier ($300 USD crédito inicial)
  4. Crear proyecto: "oasistaxiperu-production"
  
Información requerida:
  - Tarjeta de crédito corporativa
  - Email corporativo para admin
  - Datos fiscales de la empresa
  
Costo estimado: $200-500 USD/mes después del free tier
```

#### 1.2 MercadoPago Perú
```yaml
Estado: PENDIENTE - Requiere documentación empresarial
Acciones necesarias:
  1. Registrar cuenta business: https://www.mercadopago.com.pe/developers
  2. Verificar identidad empresarial
  3. Configurar cuenta bancaria para cobros
  4. Obtener credenciales de producción
  
Documentos requeridos:
  - RUC de la empresa
  - Ficha RUC actualizada
  - Poderes del representante legal
  - Cuenta bancaria empresarial en soles
  
Tiempo de verificación: 3-5 días hábiles
```

#### 1.3 Apple Developer Program
```yaml
Estado: PENDIENTE - Requiere DUNS y verificación
Acciones necesarias:
  1. Obtener número DUNS (si no lo tiene)
  2. Registrarse en: https://developer.apple.com/programs/
  3. Pagar membresía anual: $99 USD
  4. Verificación de empresa (2-7 días)
  
Requisitos:
  - Número DUNS
  - Información legal de la empresa
  - Tarjeta de crédito
  - Verificación telefónica de Apple
```

#### 1.4 Google Play Console
```yaml
Estado: PENDIENTE - Pago único requerido
Acciones necesarias:
  1. Crear cuenta: https://play.google.com/console
  2. Pago único de registro: $25 USD
  3. Verificar identidad
  4. Configurar perfil de desarrollador
  
Requisitos:
  - Cuenta Google corporativa
  - Tarjeta de crédito
  - Información de la empresa
```

---

### 2. CONFIGURACIONES DE APIS Y SERVICIOS

#### 2.1 Google Maps Platform
```yaml
Estado: PARCIAL - Falta configurar billing y restricciones
Acciones pendientes:
  1. Vincular a cuenta de billing de GCP
  2. Configurar restricciones de API key:
     - Restringir por aplicación Android (SHA-1)
     - Restringir por bundle iOS
     - Restringir por dominio web
  3. Configurar cuotas:
     - Límite diario: 25,000 requests
     - Alertas de uso excesivo
  
APIs a habilitar:
  - Maps SDK for Android ✓
  - Maps SDK for iOS ✓
  - Maps JavaScript API ✓
  - Places API ✓
  - Geocoding API ✓
  - Directions API ✓
  - Distance Matrix API ✓
```

#### 2.2 Firebase Phone Authentication
```yaml
Estado: PARCIAL - Falta configuración iOS
Acciones pendientes:
  1. Configurar APNs para iOS:
     - Generar certificado APNs en Apple Developer
     - Subir a Firebase Console
  2. Verificar números de prueba
  3. Configurar reCAPTCHA para web
  
Límites actuales:
  - 10,000 SMS/mes gratis
  - Después: $0.01-0.06 por SMS
```

---

### 3. CERTIFICADOS Y FIRMA DE APLICACIONES

#### 3.1 Android - Keystore de Producción
```yaml
Estado: PENDIENTE - Crítico para publicación
Acciones requeridas:
  1. Generar keystore de producción:
     keytool -genkey -v -keystore production.keystore -alias oasistaxiperu -keyalg RSA -keysize 2048 -validity 10000
  
  2. Guardar de forma segura:
     - Backup en múltiples ubicaciones
     - Documentar passwords
     - NUNCA perder - irreemplazable
  
  3. Configurar en Play Console:
     - App signing by Google Play
     - Upload key certificate
```

#### 3.2 iOS - Certificados y Provisioning
```yaml
Estado: PENDIENTE - Requiere Apple Developer Account
Acciones requeridas:
  1. Generar certificados en Apple Developer:
     - iOS Distribution Certificate
     - Push Notification Certificate
  2. Crear App ID: com.oasistaxiperu.app
  3. Crear Provisioning Profiles:
     - Development
     - Ad Hoc
     - App Store
```

---

### 4. TRANSFERENCIAS DE PROPIEDAD

#### 4.1 Proyecto Firebase
```yaml
Proyecto actual: oasis-taxi-peru (propiedad del desarrollador)
Acción requerida:
  1. Cliente crea su propio proyecto Firebase
  2. Migrar configuración:
     - Firestore rules
     - Storage rules
     - Cloud Functions
     - Authentication settings
  3. Actualizar app con nuevas credenciales
  
Alternativa:
  - Transferir ownership del proyecto actual
  - Agregar email del cliente como Owner
  - Remover acceso del desarrollador
```

#### 4.2 Repositorio de Código
```yaml
Estado: PENDIENTE - Definir estrategia
Opciones:
  1. Transfer a GitHub del cliente:
     - Cliente crea organización GitHub
     - Transferir repositorio completo
     - Mantener historial de commits
  
  2. Entrega en formato ZIP:
     - Exportar código completo
     - Incluir documentación
     - Sin historial de versiones
  
  3. Setup en servidor del cliente:
     - Instalar en infraestructura propia
     - Configuración on-premise
```

---

### 5. CONFIGURACIONES DE PRODUCCIÓN

#### 5.1 Variables de Entorno (.env)
```bash
# PENDIENTE: Cliente debe configurar valores de producción

# Firebase (actualizar con proyecto del cliente)
FIREBASE_API_KEY="obtener-de-firebase-console"
FIREBASE_AUTH_DOMAIN="obtener-de-firebase-console"
FIREBASE_PROJECT_ID="nuevo-proyecto-cliente"
FIREBASE_STORAGE_BUCKET="obtener-de-firebase-console"
FIREBASE_MESSAGING_SENDER_ID="obtener-de-firebase-console"
FIREBASE_APP_ID="obtener-de-firebase-console"

# Google Maps (configurar restricciones)
GOOGLE_MAPS_API_KEY="api-key-con-restricciones"

# MercadoPago (obtener credenciales producción)
MERCADOPAGO_PUBLIC_KEY="credencial-produccion"
MERCADOPAGO_ACCESS_TOKEN="token-produccion"

# OAuth (crear en GCP Console)
GOOGLE_OAUTH_CLIENT_ID="crear-oauth-client"
GOOGLE_OAUTH_CLIENT_SECRET="secret-oauth"
```

#### 5.2 Dominios y Hosting
```yaml
Estado: PENDIENTE - Cliente debe adquirir
Acciones:
  1. Registrar dominio: oasistaxiperu.com (o similar)
  2. Configurar DNS:
     - A record → Firebase Hosting
     - CNAME www → Firebase Hosting
  3. SSL Certificate:
     - Automático con Firebase Hosting
  4. Email corporativo:
     - Google Workspace recomendado
     - info@oasistaxiperu.com
     - soporte@oasistaxiperu.com
```

---

### 6. ASPECTOS LEGALES Y COMPLIANCE

#### 6.1 Términos y Condiciones
```yaml
Estado: PENDIENTE - Requiere revisión legal
Acciones:
  1. Revisar templates provistos
  2. Adaptar a legislación peruana
  3. Validar con abogado especializado
  4. Incluir:
     - Ley de Protección de Datos Personales
     - Regulaciones de transporte
     - Política de reembolsos
     - Limitación de responsabilidad
```

#### 6.2 Política de Privacidad
```yaml
Estado: PENDIENTE - Obligatorio para app stores
Contenido requerido:
  - Qué datos se recolectan
  - Cómo se usan los datos
  - Con quién se comparten
  - Derechos de los usuarios
  - Contacto del DPO
  
Debe cumplir:
  - Ley N° 29733 (Protección de Datos)
  - GDPR (si opera en Europa)
  - Requisitos de app stores
```

#### 6.3 Registro en INDECOPI
```yaml
Estado: PENDIENTE - Protección de marca
Recomendaciones:
  1. Registrar marca "OasisTaxi"
  2. Registrar logo
  3. Clase 39: Servicios de transporte
  4. Clase 42: Software
  
Costo aproximado: S/. 535 por clase
Tiempo: 4-6 meses
```

---

### 7. TESTING Y VALIDACIÓN

#### 7.1 Firebase Test Lab - iOS
```yaml
Estado: PENDIENTE - Requiere cuenta Apple Developer
Dispositivos a testear:
  - iPhone 12, 13, 14, 15
  - Diferentes versiones iOS (14-17)
  - iPad compatibility
  
Sin Apple Developer Account:
  - No se puede testear en dispositivos reales iOS
  - Solo simulador local disponible
```

#### 7.2 Pruebas con Usuarios Reales
```yaml
Estado: PENDIENTE - Organizar beta testing
Plan recomendado:
  1. Fase Alpha (1 semana):
     - 10 usuarios internos
     - Testing funcional completo
  
  2. Fase Beta Cerrada (2 semanas):
     - 50 usuarios seleccionados
     - TestFlight (iOS)
     - Google Play Beta (Android)
  
  3. Fase Beta Abierta (2 semanas):
     - 500 usuarios
     - Feedback y mejoras
  
  4. Lanzamiento Soft:
     - Lima Metropolitana primero
     - Expansión gradual
```

---

### 8. CONFIGURACIÓN DE MONITOREO Y ALERTAS

#### 8.1 Cloud Monitoring
```yaml
Estado: PENDIENTE - Configurar en GCP del cliente
Alertas a configurar:
  1. Errores > 1% → Email + SMS
  2. Latencia > 3s → Email
  3. Costo diario > $50 → Email urgente
  4. Usuarios concurrentes > 1000 → Escalar
  5. CPU > 80% → Auto-scaling
  
Contactos para alertas:
  - Email técnico: (pendiente)
  - Teléfono emergencias: (pendiente)
  - Slack webhook: (pendiente)
```

#### 8.2 Firebase Crashlytics
```yaml
Estado: LISTO - Falta configurar notificaciones
Acciones:
  1. Agregar emails para alertas críticas
  2. Configurar webhook Slack
  3. Definir umbrales:
     - Crash rate > 1%
     - ANR rate > 0.5%
     - Nuevo tipo de crash
```

---

### 9. CAPACITACIÓN Y DOCUMENTACIÓN

#### 9.1 Sesiones de Capacitación Requeridas
```yaml
Firebase Console (2 horas):
  - Navegación básica
  - Ver usuarios y datos
  - Gestionar notificaciones
  - Revisar analytics
  
Google Cloud Console (3 horas):
  - Monitoreo de costos
  - Ver logs y errores
  - Gestionar usuarios
  - Backups y recovery
  
Administración App (2 horas):
  - Panel admin web
  - Verificar conductores
  - Gestionar disputas
  - Reportes financieros
```

#### 9.2 Documentación a Entregar
```yaml
Documentos listos:
  ✓ Manual de Usuario
  ✓ Manual Técnico
  ✓ Guía de Deployment
  ✓ API Documentation
  ✓ Arquitectura del Sistema
  ✓ Guía de Video Tutoriales
  
Pendiente personalización:
  - Runbooks operacionales
  - Contactos de emergencia
  - Escalation matrix
```

---

### 10. PRESUPUESTO Y COSTOS RECURRENTES

#### 10.1 Costos Iniciales (Setup)
```yaml
Inversión única:
  - Apple Developer: $99 USD/año
  - Google Play: $25 USD (una vez)
  - Dominio: $15 USD/año
  - SSL: Gratis con Firebase
  - Marca INDECOPI: S/. 1,070 (2 clases)
  
Total aproximado: $150 USD + S/. 1,070
```

#### 10.2 Costos Mensuales Estimados
```yaml
Primeros 1,000 usuarios:
  - Firebase: Gratis (dentro de límites)
  - Google Maps: ~$50 USD
  - Cloud Functions: ~$20 USD
  - Cloud Storage: ~$10 USD
  Total: ~$80 USD/mes
  
1,000-10,000 usuarios:
  - Firebase: ~$100 USD
  - Google Maps: ~$200 USD
  - Cloud Functions: ~$100 USD
  - Cloud Storage: ~$50 USD
  - Cloud SQL: ~$50 USD
  Total: ~$500 USD/mes
  
10,000+ usuarios:
  - Requiere arquitectura enterprise
  - Costos: $2,000-5,000 USD/mes
```

---

## 📋 CHECKLIST DE VALIDACIÓN PRE-LANZAMIENTO

### Técnico
- [ ] Keystore Android generado y respaldado
- [ ] Certificados iOS configurados
- [ ] Variables .env de producción
- [ ] Dominio configurado
- [ ] SSL activo
- [ ] Backup automático configurado

### Legal
- [ ] Términos y Condiciones aprobados
- [ ] Política de Privacidad publicada
- [ ] Marca registrada (en proceso)
- [ ] Licencias de software verificadas

### Operacional
- [ ] Equipo de soporte entrenado
- [ ] Proceso de verificación de conductores
- [ ] Sistema de pagos activo
- [ ] Monitoreo 24/7 configurado

### Marketing
- [ ] Landing page lista
- [ ] Redes sociales creadas
- [ ] Campaña de lanzamiento
- [ ] Material promocional

---

## 🚨 ACCIONES INMEDIATAS REQUERIDAS

1. **HOY**: Crear cuenta GCP y configurar billing
2. **Esta semana**: Registrar Apple Developer y Google Play
3. **Próxima semana**: Configurar MercadoPago producción
4. **Antes del lanzamiento**: Generar certificados y keystores

---

## 📞 SOPORTE Y CONTACTO

Para asistencia en cualquiera de estos puntos:
- Email: [correo del desarrollador]
- WhatsApp: [número del desarrollador]
- Documentación: /docs en el repositorio

---

*Este documento lista TODOS los elementos que requieren acción directa del cliente y no pueden ser completados por el equipo de desarrollo.*

*Última actualización: Enero 2024*
*Criticidad: ALTA - Bloquea lanzamiento a producción*
