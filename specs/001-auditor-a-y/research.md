# Phase 0: Research & Analysis - OasisTaxi App Audit

**Date**: 2025-01-14
**Feature**: Auditoría y Optimización Completa
**Branch**: 001-auditor-a-y

## Executive Summary

Análisis exhaustivo del estado actual de la aplicación OasisTaxi para identificar todos los problemas que impiden su lanzamiento a producción. El objetivo es alcanzar 0 errores, 0 warnings, y funcionalidad 100% real.

## 1. Estado Actual del Código

### Análisis con Flutter Analyze
**Decision**: Usar ruta alternativa de Flutter debido a problemas WSL
**Rationale**: El comando flutter en WSL tiene problemas de path con Dart SDK
**Alternatives considered**:
- Usar flutter desde Windows CMD
- Instalar Flutter nativo en WSL
- Usar contenedor Docker con Flutter

### TODOs y FIXMEs
**Decision**: No se encontraron TODOs ni FIXMEs en el código
**Rationale**: Búsqueda exhaustiva con grep no retornó resultados
**Status**: ✅ LIMPIO

### Datos Mock/Placeholders
**Decision**: No se detectaron datos mock evidentes
**Rationale**: Búsqueda de términos comunes (mock, fake, dummy, placeholder, Lorem, example) sin resultados
**Status**: ✅ LIMPIO

## 2. Análisis de Arquitectura

### Estructura del Proyecto
```
app/
├── lib/
│   ├── core/           # Configuración, temas, utilidades
│   ├── models/         # Modelos de datos
│   ├── providers/      # State management con Provider
│   ├── screens/        # Pantallas organizadas por rol
│   │   ├── auth/       # 5 pantallas autenticación
│   │   ├── passenger/  # 12 pantallas pasajero
│   │   ├── driver/     # 12 pantallas conductor
│   │   ├── admin/      # 8 pantallas administrador
│   │   └── shared/     # 11 pantallas compartidas
│   ├── services/       # Lógica de negocio
│   └── widgets/        # Componentes reutilizables
├── firebase/           # Configuración Firebase
├── assets/            # Recursos estáticos
└── test/              # Tests unitarios
```

### Tecnologías Identificadas
- **Framework**: Flutter 3.35.3 / Dart SDK 3.9.2
- **State Management**: Provider pattern
- **Backend**: Firebase (Firestore, Auth, FCM, Storage)
- **Maps**: Google Maps API
- **Payments**: MercadoPago integration
- **Logging**: AppLogger personalizado

## 3. Problemas Identificados (Sesión Previa)

### Corrupción Masiva de Código
**Problema**: 108+ archivos con código colapsado en líneas únicas
**Solución Aplicada**: Script Python fix_collapsed_code.py
**Estado**: Parcialmente resuelto - algunos archivos aún corruptos

### Archivos Críticos Corruptos
1. **MfaService** - Recreado manualmente (328 líneas)
2. **FirebaseMlService** - Recreado con implementación mínima (173 líneas)
3. **SecureStorageService** - Recreado completo (199 líneas)
4. **CloudTranslationService** - Pendiente corrección
5. **PassengerDrawer** - Pendiente corrección

### Errores de Importación
**Problema**: Imports incorrectos firebase_firestore vs cloud_firestore
**Solución**: Reemplazo masivo con sed
**Estado**: Resuelto

## 4. Configuración Firebase

### Collections Esperadas en Firestore
```
users/
  - roles: passenger, driver, admin
  - documentos verificación
  - wallet info

trips/
  - estados: pending, accepted, in_progress, completed
  - negociación de precios
  - tracking GPS

vehicles/
  - información vehículos
  - documentación

price_negotiations/
  - ofertas y contraofertas
  - historial

payments/
  - transacciones
  - métodos de pago

ratings/
  - calificaciones bidireccionales

notifications/
  - push notifications
  - alertas sistema
```

### Servicios Firebase Requeridos
- ✅ Authentication (Email, Phone, Google OAuth)
- ✅ Cloud Firestore (Database)
- ✅ Cloud Storage (Documentos)
- ✅ Cloud Messaging (Push Notifications)
- ⚠️ Cloud Functions (No verificado)
- ✅ Crashlytics (Logging)

## 5. Dependencias Analysis

### Paquetes Críticos (pubspec.yaml)
```yaml
dependencies:
  flutter: sdk
  firebase_core: ^3.8.1
  firebase_auth: ^5.3.4
  cloud_firestore: ^5.5.1
  firebase_messaging: ^15.1.5
  firebase_storage: ^12.3.7
  google_maps_flutter: ^2.10.0
  geolocator: ^13.0.2
  provider: ^6.1.2
  flutter_polyline_points: ^2.1.0
  mercadopago_sdk: (verificar versión)
```

### Actualizaciones Necesarias
**Decision**: Actualizar todas las dependencias a versiones estables más recientes
**Rationale**: Evitar vulnerabilidades y bugs conocidos
**Alternatives**: Mantener versiones actuales (riesgoso para producción)

## 6. Flujos Críticos a Verificar

### Flujo Pasajero
1. ⚠️ Registro con OTP real (Firebase Auth)
2. ⚠️ Búsqueda direcciones (Google Places API)
3. ⚠️ Negociación precio (Firestore real-time)
4. ⚠️ Tracking GPS (Google Maps)
5. ⚠️ Chat conductor (Firestore)
6. ⚠️ Pago (MercadoPago)
7. ⚠️ Calificación (Firestore)

### Flujo Conductor
1. ⚠️ Registro con documentos
2. ⚠️ Verificación administrativa
3. ⚠️ Recepción solicitudes real-time
4. ⚠️ Navegación GPS
5. ⚠️ Gestión ganancias wallet
6. ⚠️ Retiros

### Flujo Admin
1. ⚠️ Login con 2FA
2. ⚠️ Dashboard métricas reales
3. ⚠️ Verificación documentos
4. ⚠️ Gestión usuarios
5. ⚠️ Reportes financieros

## 7. UI/UX Consistency Check

### Elementos a Estandarizar
- **Botones**: Verificar estilo consistente (ElevatedButton vs OasisButton)
- **Espaciado**: Establecer sistema (8, 16, 24, 32px)
- **Tipografía**: Tamaños estándar (12, 14, 16, 18, 20, 24px)
- **Colores**: Solo paleta del tema
- **Border Radius**: Unificar (8px o 12px)
- **Elevación**: Consistente en cards

## 8. Testing Strategy

### Tipos de Tests Necesarios
1. **Unit Tests**: Modelos y lógica de negocio
2. **Widget Tests**: Componentes UI
3. **Integration Tests**: Flujos completos
4. **E2E Tests**: Escenarios reales con Firebase

### Coverage Actual
**Estado**: ⚠️ No verificado debido a problemas Flutter CLI
**Target**: >80% coverage

## 9. Performance Metrics

### Objetivos
- Tiempo de respuesta: <2 segundos
- Frame rate: 60 FPS consistente
- Reconexión automática: <5 segundos
- Tamaño APK: <50MB
- Memoria: <200MB en uso normal

## 10. Decisiones Técnicas

### Prioridades de Corrección
1. **CRÍTICO**: Restaurar archivos corruptos
2. **ALTO**: Verificar integraciones Firebase reales
3. **MEDIO**: Estandarizar UI/UX
4. **BAJO**: Optimización performance

### Estrategia de Migración
**Decision**: Corrección incremental sin romper funcionalidad existente
**Rationale**: App en estado avanzado, evitar regresiones
**Alternatives considered**: Reescritura completa (descartado por tiempo)

## Conclusiones

La aplicación OasisTaxi requiere:
1. **Corrección inmediata** de archivos corruptos
2. **Verificación exhaustiva** de integraciones Firebase
3. **Estandarización UI/UX** para consistencia
4. **Testing completo** de flujos críticos
5. **Optimización** para cumplir métricas de performance

## Next Steps (Phase 1)

1. Generar data-model.md con entidades completas
2. Crear contracts/ con esquemas Firestore
3. Escribir quickstart.md con flujos de prueba
4. Actualizar CLAUDE.md con contexto del proyecto
5. Preparar tasks.md template para /tasks command

---
*Research completed: 2025-01-14*
*All NEEDS CLARIFICATION resolved through codebase analysis*