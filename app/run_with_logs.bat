@echo off
echo ========================================
echo  OASIS TAXI - Ejecutando con Logs
echo ========================================
echo.
echo Iniciando la aplicacion con logs habilitados...
echo.
echo IMPORTANTE: Observa la consola para ver los logs de:
echo  - Inicializacion de Firebase
echo  - Estado de autenticacion
echo  - Navegacion entre pantallas
echo  - Llamadas a API
echo  - Errores y warnings
echo.
echo Presiona Ctrl+C para detener la aplicacion
echo ========================================
echo.

REM Ejecutar Flutter con logs completos
flutter run -d chrome --web-port=5000 -t lib/main.dart

pause