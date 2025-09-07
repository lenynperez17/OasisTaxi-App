# Guía de Contribución - OASIS TAXI

## 📋 Tabla de Contenidos

- [Código de Conducta](#código-de-conducta)
- [¿Cómo Contribuir?](#cómo-contribuir)
- [Flujo de Trabajo](#flujo-de-trabajo)
- [Estándares de Código](#estándares-de-código)
- [Proceso de Pull Request](#proceso-de-pull-request)
- [Reportar Bugs](#reportar-bugs)
- [Sugerir Mejoras](#sugerir-mejoras)

## 📜 Código de Conducta

### Nuestro Compromiso

Nos comprometemos a hacer de la participación en nuestro proyecto una experiencia libre de acoso para todos, independientemente de la edad, tamaño corporal, discapacidad, etnia, identidad y expresión de género, nivel de experiencia, nacionalidad, apariencia personal, raza, religión o identidad y orientación sexual.

### Nuestros Estándares

Ejemplos de comportamiento que contribuyen a crear un ambiente positivo:

- ✅ Usar lenguaje acogedor e inclusivo
- ✅ Respetar diferentes puntos de vista y experiencias
- ✅ Aceptar críticas constructivas con gracia
- ✅ Enfocarse en lo mejor para la comunidad
- ✅ Mostrar empatía hacia otros miembros

## 🤝 ¿Cómo Contribuir?

### 1. Fork del Repositorio

```bash
# Fork desde GitHub UI
# Luego clonar tu fork
git clone https://github.com/TU_USUARIO/oasis-taxi.git
cd oasis-taxi
git remote add upstream https://github.com/oasis-taxi/platform.git
```

### 2. Configurar Ambiente

```bash
# Instalar dependencias
make install

# Configurar pre-commit hooks
./tools/scripts/setup-hooks.sh
```

## 🔄 Flujo de Trabajo

Utilizamos **Gitflow** como modelo de branching:

```
main
  └── develop
       ├── feature/JIRA-123-nueva-funcionalidad
       ├── bugfix/JIRA-456-corregir-error
       ├── hotfix/JIRA-789-fix-critico
       └── release/v1.2.0
```

### Crear Nueva Rama

```bash
# Actualizar develop
git checkout develop
git pull upstream develop

# Crear rama feature
git checkout -b feature/JIRA-123-descripcion-corta

# Trabajar en tu feature
git add .
git commit -m "feat(passenger): agregar nueva funcionalidad"
```

## 📝 Estándares de Código

### Conventional Commits

Formato: `<tipo>(<alcance>): <descripción>`

**Tipos permitidos:**
- `feat`: Nueva funcionalidad
- `fix`: Corrección de bug
- `docs`: Cambios en documentación
- `style`: Cambios de formato (no afectan funcionalidad)
- `refactor`: Refactorización de código
- `perf`: Mejoras de rendimiento
- `test`: Agregar o corregir tests
- `chore`: Cambios en build o herramientas auxiliares

**Ejemplos:**
```bash
feat(passenger): agregar botón de pánico
fix(driver): corregir cálculo de distancia
docs(api): actualizar documentación de endpoints
perf(maps): optimizar renderizado de rutas
```

### Estilo de Código

#### Flutter/Dart
```dart
// ✅ Bueno
class RideService {
  static const int maxRetries = 3;
  
  Future<Ride> createRide({
    required String passengerId,
    required Location pickup,
    required Location destination,
  }) async {
    // Implementación
  }
}

// ❌ Evitar
class ride_service {
  var MAX_RETRIES = 3;
  
  createRide(passenger_id, pickup, destination) {
    // Implementación
  }
}
```

#### JavaScript/TypeScript
```typescript
// ✅ Bueno
export interface RideRequest {
  passengerId: string;
  pickup: Location;
  destination: Location;
  paymentMethod: PaymentMethod;
}

export async function createRide(request: RideRequest): Promise<Ride> {
  // Implementación
}

// ❌ Evitar
export function create_ride(passenger_id, pickup, destination) {
  // Implementación
}
```

## 🔄 Proceso de Pull Request

### 1. Antes de Crear PR

```bash
# Ejecutar tests
make test

# Verificar formato
make lint

# Verificar cobertura (mínimo 80%)
make coverage
```

### 2. Crear Pull Request

**Título:** Usar formato Conventional Commits

**Descripción debe incluir:**
```markdown
## Descripción
Breve descripción de los cambios

## Tipo de Cambio
- [ ] Bug fix
- [ ] Nueva funcionalidad
- [ ] Breaking change
- [ ] Documentación

## Checklist
- [ ] Mi código sigue los estándares del proyecto
- [ ] He realizado auto-revisión de mi código
- [ ] He comentado código complejo
- [ ] He actualizado la documentación
- [ ] Mis cambios no generan warnings
- [ ] He agregado tests que prueban mi fix/feature
- [ ] Todos los tests pasan localmente
- [ ] La cobertura se mantiene >= 80%

## Screenshots (si aplica)
[Agregar screenshots aquí]

## Issues Relacionados
Closes #123
```

### 3. Proceso de Revisión

- Mínimo 2 aprobaciones requeridas
- CI/CD debe pasar todos los checks
- No conflictos con rama base
- Cobertura de código >= 80%

## 🐛 Reportar Bugs

### Antes de Reportar

1. Verificar en [issues existentes](https://github.com/oasis-taxi/platform/issues)
2. Actualizar a última versión
3. Verificar en FAQ

### Crear Issue

Usar plantilla de bug report con:

```markdown
## Descripción
Clara descripción del bug

## Pasos para Reproducir
1. Ir a '...'
2. Click en '....'
3. Ver error

## Comportamiento Esperado
Descripción de lo que debería pasar

## Comportamiento Actual
Descripción de lo que pasa actualmente

## Screenshots
Si aplica, agregar screenshots

## Ambiente
- App: [passenger/driver/admin]
- Versión: [e.g. 1.2.0]
- OS: [e.g. iOS 15, Android 12]
- Device: [e.g. iPhone 13, Samsung S21]

## Contexto Adicional
Cualquier otro contexto sobre el problema
```

## 💡 Sugerir Mejoras

### Feature Request

Usar plantilla con:

```markdown
## Problema
Descripción del problema que resuelve esta feature

## Solución Propuesta
Descripción de la solución

## Alternativas Consideradas
Otras soluciones que consideraste

## Contexto Adicional
Screenshots, mockups, o contexto adicional
```

## 🏗️ Arquitectura de Decisiones

Para cambios arquitecturales significativos, crear un ADR (Architecture Decision Record):

```markdown
# ADR-001: Título de la Decisión

## Estado
Propuesto | Aceptado | Rechazado | Deprecado

## Contexto
¿Cuál es el problema?

## Decisión
¿Qué decidimos hacer?

## Consecuencias
¿Qué pasa como resultado?

## Alternativas Consideradas
- Opción 1: Descripción
- Opción 2: Descripción
```

## 📞 Contacto

- **Discord**: [discord.gg/oasistaxidev](https://discord.gg/oasistaxidev)
- **Email**: dev@oasistaxiapp.com
- **Foro**: [forum.oasistaxiapp.com](https://forum.oasistaxiapp.com)

---

¡Gracias por contribuir a OASIS TAXI! 🚕✨