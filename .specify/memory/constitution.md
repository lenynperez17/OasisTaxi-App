# OasisTaxi Constitution

## Core Principles

### I. Zero Defects Policy
Cada release debe cumplir con cero errores de compilación, cero warnings, y funcionalidad 100% real. No se permite código mock, placeholder, o datos de ejemplo en producción. Todo código debe pasar análisis estático sin issues antes de merge.

### II. Real-Time First
Toda funcionalidad crítica debe operar en tiempo real usando Firebase Firestore listeners. Las actualizaciones de estado (viajes, ubicación, pagos) deben reflejarse instantáneamente en todos los clientes conectados sin necesidad de refresh manual.

### III. Test-First Development (NON-NEGOTIABLE)
TDD obligatorio para toda nueva funcionalidad:
- Tests escritos ANTES de implementación
- Ciclo RED → GREEN → REFACTOR estrictamente aplicado
- Mínimo 80% cobertura de código
- Tests de integración para flujos críticos (registro, solicitud viaje, pago)

### IV. Three-Actor Architecture
El sistema mantiene estricta separación entre tres roles:
- **Pasajero**: Solicita servicios, negocia precios, realiza pagos
- **Conductor**: Acepta viajes, provee servicios, recibe pagos
- **Administrador**: Verifica documentos, gestiona usuarios, monitorea operaciones
Cada rol tiene interfaces, permisos, y flujos completamente separados.

### V. Security & Privacy by Design
- Autenticación multi-factor obligatoria para administradores
- Cifrado de datos sensibles en reposo y tránsito
- Validación y sanitización de TODAS las entradas
- Principio de menor privilegio en Firestore rules
- Logs de auditoría para acciones administrativas
- Cumplimiento LGPD/GDPR para datos personales

### VI. Mobile-First Performance
- Tiempo de respuesta <2 segundos para operaciones normales
- 60 FPS sostenido en animaciones y transiciones
- Reconexión automática en <5 segundos tras pérdida de conectividad
- APK <50MB, memoria <200MB en uso normal
- Soporte offline para datos críticos con sincronización automática

### VII. Observability & Monitoring
- Logging estructurado con AppLogger en todos los servicios
- Integración con Firebase Crashlytics para crash reporting
- Métricas de performance en tiempo real
- Alertas automáticas para errores críticos
- Dashboard de monitoreo para administradores

## Technical Requirements

### Platform Support
- **Android**: Mínimo API 21 (Android 5.0 Lollipop), Target API 34
- **iOS**: Mínimo iOS 12.0, optimizado para iOS 17+
- **Web**: Chrome 90+, Safari 14+, Firefox 88+
- **Responsive**: 5" a 7" smartphones, tablets 10"+

### Technology Stack (IMMUTABLE)
- **Framework**: Flutter 3.35.3+ con Dart 3.9.2+
- **Backend**: Firebase Suite (Auth, Firestore, FCM, Storage)
- **Maps**: Google Maps Platform con Places API
- **Payments**: MercadoPago SDK para Perú
- **State Management**: Provider pattern (no Redux/Bloc)
- **Logging**: AppLogger personalizado + Firebase Crashlytics

### Data Architecture
- **Database**: Cloud Firestore con estructura NoSQL definida
- **Storage**: Firebase Storage para documentos e imágenes
- **Cache**: Firestore offline persistence habilitado
- **Real-time**: Firestore listeners para actualizaciones
- **Backup**: Exportación diaria automática de Firestore

### Integration Standards
- **API Version**: Siempre usar última versión estable de Firebase
- **Authentication**: Firebase Auth con providers (Email, Phone, Google)
- **Push Notifications**: FCM con topics por rol de usuario
- **Maps**: Google Maps con API key restringida por bundle ID
- **Payments**: MercadoPago en modo sandbox para desarrollo

## Quality Gates

### Pre-Commit Checks
1. `flutter analyze` debe retornar 0 issues
2. `dart format` aplicado a todos los archivos
3. No TODO, FIXME, o HACK comments
4. No `print()` statements (usar AppLogger)
5. No datos hardcodeados o credenciales

### Pre-Merge Requirements
1. Todos los tests unitarios pasando
2. Tests de integración para features nuevas
3. Code review por al menos 1 desarrollador
4. Documentación actualizada si hay cambios de API
5. Version bump en pubspec.yaml

### Pre-Release Validation
1. Build release sin errores ni warnings
2. Testing manual en 3+ dispositivos físicos
3. Verificación de flujos E2E completos
4. Performance profiling cumple métricas
5. Security scan sin vulnerabilidades críticas

## Development Workflow

### Branch Strategy
```
main (producción)
  ├── develop (integración)
  │   ├── feature/XXX-nombre
  │   ├── bugfix/XXX-nombre
  │   └── hotfix/XXX-nombre
```

### Commit Convention
```
tipo(scope): descripción breve

- feat: nueva funcionalidad
- fix: corrección de bug
- refactor: refactorización
- test: agregar/modificar tests
- docs: documentación
- style: formato sin cambios de lógica
- perf: mejoras de performance
- chore: tareas de mantenimiento
```

### Review Process
1. **Self-review**: Autor verifica su código
2. **Automated checks**: CI/CD ejecuta tests
3. **Peer review**: Mínimo 1 aprobación
4. **QA validation**: Testing manual si aplica
5. **Merge**: Solo con todos los checks en verde

## Performance Standards

### Response Times
- Login/Register: <3 segundos
- Búsqueda direcciones: <1 segundo
- Solicitud viaje: <2 segundos
- Actualización ubicación: <500ms
- Chat mensaje: <300ms
- Procesamiento pago: <5 segundos

### Resource Usage
- CPU: <60% promedio, <80% pico
- Memoria: <200MB promedio, <300MB pico
- Batería: <5% por hora de uso activo
- Red: <1MB por viaje completo
- Storage: <100MB instalación inicial

### Scalability Targets
- Usuarios concurrentes: 10,000+
- Viajes simultáneos: 1,000+
- Mensajes chat/segundo: 100+
- Notificaciones push/minuto: 1,000+
- Tiempo uptime: 99.9%

## Security Requirements

### Authentication
- MFA obligatorio para administradores
- Session timeout: 30 días usuarios, 1 día admins
- Password policy: 8+ caracteres, mayúsculas, números
- Bloqueo tras 5 intentos fallidos
- Recovery por email y SMS

### Data Protection
- Cifrado AES-256 para datos sensibles
- TLS 1.3 para todas las comunicaciones
- No logs de información personal identificable
- Anonimización de datos para analytics
- Derecho al olvido implementado

### Compliance
- Firestore Security Rules restrictivas
- OWASP Top 10 mitigaciones aplicadas
- PCI DSS para procesamiento de pagos
- LGPD/GDPR para datos personales
- Auditoría de acceso a datos sensibles

## Monitoring & Alerts

### Critical Alerts (Inmediato)
- App crash rate >1%
- Error rate >5%
- Response time >5 segundos
- Disponibilidad <99%
- Fallo en procesamiento de pagos

### Warning Alerts (15 minutos)
- Memory leak detectado
- CPU usage >80%
- Error rate >2%
- Queue backlog >100
- Disk usage >80%

### Info Notifications (Daily)
- Daily active users
- Viajes completados
- Revenue procesado
- New registrations
- Performance metrics

## Governance

### Constitution Authority
Esta constitución reemplaza todas las prácticas previas y es la autoridad máxima para decisiones técnicas del proyecto OasisTaxi.

### Amendment Process
1. Propuesta documentada con justificación
2. Revisión por equipo técnico (mínimo 3 personas)
3. Período de comentarios (48 horas)
4. Votación (requiere 2/3 mayoría)
5. Plan de migración si hay breaking changes
6. Actualización de versión y fecha

### Enforcement
- Todos los PRs deben verificar cumplimiento
- Violaciones bloquean merge automáticamente
- Excepciones requieren justificación documentada
- Revisión mensual de cumplimiento
- Reporte trimestral de métricas

### Documentation
- CLAUDE.md para guía de desarrollo IA
- README.md para setup y configuración
- CHECKLIST_MAESTRO_COMPLETO.md para validación
- docs/ para documentación técnica detallada

**Version**: 1.0.0 | **Ratified**: 2025-01-14 | **Last Amended**: 2025-01-14

---
*OasisTaxi Constitution - El estándar de calidad para transporte urbano en Perú*