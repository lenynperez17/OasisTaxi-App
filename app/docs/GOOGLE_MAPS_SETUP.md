# 🗺️ Configuración de Google Maps APIs

## ✅ CONFIGURACIÓN CENTRALIZADA IMPLEMENTADA

Este documento explica cómo se ha centralizado la configuración de las Google Maps APIs en el proyecto.

## 📁 Estructura de Configuración

### 1. Variables de Entorno (.env)
```env
# Google Maps API - PRODUCCIÓN
GOOGLE_MAPS_API_KEY=AIzaSyBmNv8kL9pQ7xR3wT6jF2sY4tE8uQ5mG9O
GOOGLE_PLACES_API_KEY=AIzaSyCtPw7mF4qN8xL9vR6jK3sY8tE5wQ2mG7P
GOOGLE_DIRECTIONS_API_KEY=AIzaSyDrKy4nQ8pL3xM9vT7jF6sY8tE9wQ8mG3T
```

### 2. Configuración Centralizada (lib/core/config/app_config.dart)
```dart
class AppConfig {
  // Google Maps API Keys - Configuración centralizada desde .env
  static const String googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: '');
  static const String googlePlacesApiKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY', defaultValue: '');
  static const String googleDirectionsApiKey = String.fromEnvironment('GOOGLE_DIRECTIONS_API_KEY', defaultValue: '');
}
```

## 🔧 Archivos Actualizados

### ✅ Archivos Corregidos
1. **`/lib/core/config/app_config.dart`**
   - Configuración centralizada con variables de entorno
   - Separación de keys por servicio (Maps, Places, Directions)

2. **`/lib/providers/location_provider.dart`**
   - Eliminada key hardcodeada `AIzaSyBX5KlV9cJH2oNfPr8QWqD7fGHjK9mRxYc`
   - Ahora usa `AppConfig.googleMapsApiKey`

3. **`/lib/services/google_maps_service_real.dart`**
   - Eliminada key hardcodeada `AIzaSyBX5KlV9cJH2oNfPr8QWqD7fGHjK9mRxYc`
   - Ahora usa `AppConfig.googleMapsApiKey`

4. **`/web/index.html`**
   - Eliminada key hardcodeada `AIzaSyB2lHyFVQhey6C1Dib1mDBijVGopWvvhGg`
   - Ahora usa placeholder `{{GOOGLE_MAPS_API_KEY}}` procesado en build time

### ✅ Archivos que ya estaban correctos
- **`/lib/core/services/places_service.dart`** - Ya usaba `AppConfig.googleMapsApiKey`

### ✅ Archivos que NO se modificaron (son correctos)
- **`/lib/firebase_options.dart`** - Keys de Firebase (diferentes a Google Maps)
- **`/ios/Runner/GoogleService-Info.plist`** - Configuración de Firebase iOS

## 🚀 Scripts de Automatización

### 1. Script de Desarrollo (`scripts/dev_setup.sh`)
Configura el entorno de desarrollo reemplazando placeholders con keys del .env:
```bash
./scripts/dev_setup.sh
```

### 2. Script de Build Producción (`scripts/build_web.sh`)
Construye la aplicación web inyectando las APIs keys:
```bash
./scripts/build_web.sh
```

## 💡 Uso para Desarrolladores

### Desarrollo Local
```bash
# 1. Configurar entorno
./scripts/dev_setup.sh

# 2. Ejecutar con variables de entorno
flutter run -d chrome \
  --dart-define=GOOGLE_MAPS_API_KEY="$GOOGLE_MAPS_API_KEY" \
  --dart-define=GOOGLE_PLACES_API_KEY="$GOOGLE_PLACES_API_KEY" \
  --dart-define=GOOGLE_DIRECTIONS_API_KEY="$GOOGLE_DIRECTIONS_API_KEY"
```

### Build de Producción
```bash
./scripts/build_web.sh
```

## 🔐 Seguridad Implementada

### ✅ Buenas Prácticas Aplicadas
- ❌ **NO hay API keys hardcodeadas** en código fuente
- ✅ **Configuración centralizada** desde variables de entorno
- ✅ **Separación de keys** por servicio (Maps, Places, Directions)
- ✅ **Scripts automatizados** para desarrollo y producción
- ✅ **Placeholders** en archivos web procesados en build time

### ✅ Verificación de Seguridad
```bash
# Buscar keys hardcodeadas (debe retornar solo Firebase keys)
grep -r "AIzaSy" --exclude-dir=node_modules --include="*.dart" lib/
```

## 🎯 Servicios Que Usan Cada Key

### GOOGLE_MAPS_API_KEY
- Visualización de mapas
- Geocodificación inversa
- Distance Matrix API
- Directions API (si no se especifica GOOGLE_DIRECTIONS_API_KEY)

### GOOGLE_PLACES_API_KEY
- Autocomplete de lugares
- Place Details API
- Places Search API

### GOOGLE_DIRECTIONS_API_KEY
- Cálculo de rutas optimizadas
- Turn-by-turn directions
- Route optimization

## 🔄 Migración Completada

### Antes (❌ PROBLEMÁTICO)
- Keys hardcodeadas en múltiples archivos
- Diferentes keys en diferentes servicios
- No había configuración centralizada
- Riesgo de seguridad alto

### Después (✅ SOLUCIONADO)
- Configuración centralizada en `AppConfig`
- Variables de entorno desde `.env`
- Scripts automatizados para builds
- Separación clara por tipo de servicio
- Seguridad mejorada

## 📋 Checklist de Verificación

- [x] Eliminadas todas las API keys hardcodeadas de Google Maps
- [x] Configuración centralizada en `AppConfig`
- [x] Variables de entorno en `.env`
- [x] Scripts de desarrollo y producción creados
- [x] Servicios actualizados para usar configuración centralizada
- [x] Documentación completa
- [x] Verificación de seguridad realizada

## 🆘 Resolución de Problemas

### Error: API key no encontrada
```
Causa: Variable de entorno no definida
Solución: Verificar que GOOGLE_MAPS_API_KEY esté en .env
```

### Error: Web no carga mapas
```
Causa: Placeholder no reemplazado en index.html
Solución: Ejecutar ./scripts/dev_setup.sh
```

### Error: App móvil no funciona
```
Causa: dart-define no pasado al flutter run
Solución: Usar el comando completo con --dart-define
```

---
**✅ CONFIGURACIÓN COMPLETADA EXITOSAMENTE**

Todas las Google Maps API keys han sido centralizadas y configuradas correctamente usando variables de entorno y configuración centralizada.