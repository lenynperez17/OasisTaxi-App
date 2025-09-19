# Configuración del archivo .env

## ⚠️ IMPORTANTE
La aplicación requiere un archivo `.env` en el directorio `app/` para funcionar correctamente.

## Pasos para configurar:

1. **Copiar el archivo de ejemplo:**
   ```bash
   cp .env.example .env
   ```

2. **Editar el archivo `.env` con tus credenciales reales**

3. **NO subir el archivo `.env` al repositorio**
   - El archivo ya está en `.gitignore`
   - Contiene información sensible

## Variables requeridas:

- `GOOGLE_MAPS_API_KEY`: API key de Google Maps (obligatorio)
- Credenciales de Firebase (si no usas google-services.json)
- OAuth credentials para login social
- Otras configuraciones según necesidad

## Nota para desarrollo:
Si recibes el error "Unable to load asset: .env", asegúrate de:
1. Crear el archivo `.env` en `app/`
2. Ejecutar `flutter pub get` después de crear el archivo