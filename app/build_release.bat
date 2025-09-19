@echo off
echo ========================================
echo    OASISTAXIPERU - BUILD RELEASE
echo ========================================
echo.

REM Verificar que existe key.properties
if not exist "android\key.properties" (
    echo ERROR: No se encuentra android\key.properties
    echo Por favor, crea el archivo key.properties primero.
    echo Consulta DEPLOYMENT_GUIDE.md para instrucciones.
    pause
    exit /b 1
)

REM Verificar que existe el keystore
if not exist "android\app\oasistaxiperu.keystore" (
    echo ERROR: No se encuentra android\app\oasistaxiperu.keystore
    echo Por favor, crea el keystore primero.
    echo Consulta DEPLOYMENT_GUIDE.md para instrucciones.
    pause
    exit /b 1
)

echo [1/5] Limpiando build anterior...
call flutter clean

echo.
echo [2/5] Obteniendo dependencias...
call flutter pub get

echo.
echo [3/5] Ejecutando analisis de codigo...
call flutter analyze --no-fatal-warnings --no-fatal-infos

echo.
echo [4/5] Construyendo APK Release...
call flutter build apk --release --obfuscate --split-debug-info=build/debug-info

echo.
echo [5/5] Construyendo App Bundle para Play Store...
call flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info

echo.
echo ========================================
echo    BUILD COMPLETADO EXITOSAMENTE!
echo ========================================
echo.
echo Archivos generados:
echo - APK: build\app\outputs\flutter-apk\app-release.apk
echo - AAB: build\app\outputs\bundle\release\app-release.aab
echo.
echo Tamaños:
dir build\app\outputs\flutter-apk\app-release.apk | findstr "app-release.apk"
dir build\app\outputs\bundle\release\app-release.aab | findstr "app-release.aab"
echo.
echo Siguiente paso: Subir el AAB a Google Play Console
echo.
pause