# Implementation Plan: Auditoría y Optimización Completa - OasisTaxi App

**Branch**: `001-auditor-a-y` | **Date**: 2025-01-14 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-auditor-a-y/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path
   → Feature spec loaded successfully
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detected Project Type: Mobile application with API
   → Set Structure Decision: Option 3 (Mobile + API)
3. Evaluate Constitution Check section below
   → No violations detected - App already exists
   → Update Progress Tracking: Initial Constitution Check
4. Execute Phase 0 → research.md
   → All clarifications resolved through existing codebase
5. Execute Phase 1 → contracts, data-model.md, quickstart.md, CLAUDE.md
6. Re-evaluate Constitution Check section
   → No new violations detected
   → Update Progress Tracking: Post-Design Constitution Check
7. Plan Phase 2 → Task generation approach defined
8. STOP - Ready for /tasks command
```

## Summary
Auditoría exhaustiva y optimización completa de la aplicación OasisTaxi para alcanzar producción con 0 errores, 0 warnings, y funcionalidad 100% real. Incluye limpieza de código, eliminación de mocks, integración Firebase real, y optimización UI/UX para tres flujos de usuario: Pasajero, Conductor, y Administrador.

## Technical Context
**Language/Version**: Flutter 3.35.3 / Dart SDK 3.9.2
**Primary Dependencies**: Firebase (Auth, Firestore, FCM, Storage), Google Maps, MercadoPago
**Storage**: Firebase Firestore (NoSQL), Firebase Storage (archivos)
**Testing**: Flutter test framework, integration_test
**Target Platform**: Android 6+ / iOS 12+ / Web
**Project Type**: mobile - Flutter app con backend Firebase
**Performance Goals**: <2 segundos respuesta, 60 FPS UI, reconexión automática
**Constraints**: 0 errores compilación, 0 warnings, sin datos mock, 100% funcional
**Scale/Scope**: 10,000 usuarios concurrentes, 3 roles de usuario, 35+ pantallas

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Simplicity**:
- Projects: 2 (app Flutter, Firebase backend)
- Using framework directly? ✓ (Flutter/Firebase SDK directo)
- Single data model? ✓ (modelos Dart compartidos)
- Avoiding patterns? ✓ (Provider pattern simple)

**Architecture**:
- EVERY feature as library? N/A (auditoría de app existente)
- Libraries listed: Servicios existentes (auth, location, payment, etc.)
- CLI per library: N/A (app móvil)
- Library docs: Documentación inline existente

**Testing (NON-NEGOTIABLE)**:
- RED-GREEN-Refactor cycle enforced? ✓ (para nuevas correcciones)
- Git commits show tests before implementation? ✓
- Order: Contract→Integration→E2E→Unit strictly followed? ✓
- Real dependencies used? ✓ (Firebase real, no mocks)
- Integration tests for: new libraries, contract changes, shared schemas? ✓
- FORBIDDEN: Implementation before test, skipping RED phase ✓

**Observability**:
- Structured logging included? ✓ (AppLogger implementado)
- Frontend logs → backend? ✓ (Firebase Crashlytics)
- Error context sufficient? ✓ (stack traces completos)

**Versioning**:
- Version number assigned? ✓ (pubspec.yaml)
- BUILD increments on every change? ✓
- Breaking changes handled? N/A (auditoría)

## Project Structure

### Documentation (this feature)
```
specs/001-auditor-a-y/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
# Option 3: Mobile + API (Flutter + Firebase)
app/
├── lib/
│   ├── models/          # Modelos de datos
│   ├── providers/       # State management
│   ├── screens/         # UI screens
│   ├── services/        # Business logic
│   ├── widgets/         # Reusable components
│   └── core/           # Config, theme, utils
├── test/               # Unit tests
├── integration_test/   # Integration tests
└── firebase/          # Firebase config files

firebase/
├── firestore.rules    # Security rules
├── storage.rules      # Storage rules
└── functions/         # Cloud Functions (si existen)
```

**Structure Decision**: Option 3 - Mobile + API (Flutter app con Firebase backend)

## Phase 0: Outline & Research
1. **Extract unknowns from Technical Context**:
   - Estado actual del código (errores, warnings)
   - Datos mock/placeholder existentes
   - Integraciones Firebase configuradas
   - Dependencias deprecadas

2. **Generate and dispatch research agents**:
   ```
   Task: "Analizar estado actual con flutter analyze"
   Task: "Buscar todos los TODOs y FIXMEs"
   Task: "Identificar datos mock y placeholders"
   Task: "Verificar configuración Firebase"
   Task: "Revisar dependencias en pubspec.yaml"
   ```

3. **Consolidate findings** in `research.md`:
   - Decision: Correcciones necesarias identificadas
   - Rationale: Alcanzar calidad producción
   - Alternatives considered: Refactorización completa vs correcciones puntuales

**Output**: research.md con análisis completo del estado actual

## Phase 1: Design & Contracts
*Prerequisites: research.md complete*

1. **Extract entities from feature spec** → `data-model.md`:
   - Usuario (roles: pasajero, conductor, admin)
   - Viaje (estados, negociación)
   - Vehículo (documentación)
   - Documento (verificación)
   - Pago (métodos, comisiones)
   - Calificación (bidireccional)
   - Wallet (balance, transacciones)
   - Negociación (ofertas/contraofertas)
   - Emergencia (SOS)
   - Notificación (push, alertas)

2. **Generate API contracts** from functional requirements:
   - Auth endpoints (registro, login, OTP)
   - Trip endpoints (solicitar, aceptar, trackear)
   - Payment endpoints (procesar, wallet)
   - Admin endpoints (verificar, gestionar)
   - Output Firestore schemas to `/contracts/`

3. **Generate contract tests** from contracts:
   - Firestore security rules tests
   - API integration tests
   - Tests must fail initially

4. **Extract test scenarios** from user stories:
   - Flujo completo pasajero
   - Flujo completo conductor
   - Flujo completo admin
   - Edge cases identificados

5. **Update CLAUDE.md incrementally**:
   - Add Flutter/Firebase best practices
   - Document correcciones realizadas
   - Keep under 150 lines

**Output**: data-model.md, /contracts/*, failing tests, quickstart.md, CLAUDE.md

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:
- Auditoría inicial completa (flutter analyze)
- Tareas de limpieza de código (warnings, imports)
- Eliminación de mocks/placeholders
- Correcciones de integración Firebase
- Optimización UI/UX
- Verificación de flujos end-to-end
- Tests de regresión

**Ordering Strategy**:
- Prioridad 1: Errores de compilación [P]
- Prioridad 2: Warnings y código muerto [P]
- Prioridad 3: Integración real Firebase
- Prioridad 4: UI/UX consistency
- Prioridad 5: Testing completo

**Estimated Output**: 40-50 tareas numeradas y priorizadas en tasks.md

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)
**Phase 4**: Implementation (execute tasks following audit plan)
**Phase 5**: Validation (0 errors, 0 warnings, APK release ready)

## Complexity Tracking
*No violations detected - working with existing app*

## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
- [ ] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented (none)

---
*Based on Constitution v2.1.1 - See `/memory/constitution.md`*