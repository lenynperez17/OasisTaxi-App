@echo off
echo ========================================
echo    CREADOR DE KEYSTORE - OASISTAXIPERU
echo ========================================
echo.
echo Este script te ayudara a crear el keystore para firmar tu app.
echo IMPORTANTE: Guarda las contraseñas en un lugar seguro!
echo.
pause

cd android\app

echo.
echo Creando keystore...
echo.
echo Cuando se te pida, ingresa la siguiente informacion:
echo - Contraseña del keystore: (minimo 6 caracteres)
echo - Nombre y apellido: Tu nombre o nombre de la empresa
echo - Unidad organizativa: Desarrollo
echo - Organizacion: OasisTaxiPeru
echo - Ciudad: Lima
echo - Estado/Provincia: Lima
echo - Codigo de pais: PE
echo.

keytool -genkey -v -keystore oasistaxiperu.keystore -alias oasistaxiperu -keyalg RSA -keysize 2048 -validity 10000

if %errorlevel% neq 0 (
    echo.
    echo ERROR: No se pudo crear el keystore.
    echo Asegurate de tener Java instalado.
    pause
    exit /b 1
)

echo.
echo ========================================
echo    KEYSTORE CREADO EXITOSAMENTE!
echo ========================================
echo.
echo Ahora crea el archivo android\key.properties con el siguiente contenido:
echo.
echo storePassword=TU_CONTRASEÑA_DEL_KEYSTORE
echo keyPassword=TU_CONTRASEÑA_DE_LA_LLAVE
echo keyAlias=oasistaxiperu
echo storeFile=oasistaxiperu.keystore
echo.
echo IMPORTANTE:
echo 1. Reemplaza TU_CONTRASEÑA con las contraseñas que usaste
echo 2. NUNCA subas key.properties a Git
echo 3. Haz backup seguro del keystore y las contraseñas
echo.
pause

cd ..\..

echo.
echo Deseas crear el archivo key.properties ahora? (S/N)
set /p crear=

if /i "%crear%"=="S" (
    echo Ingresa la contraseña del keystore:
    set /p storepass=
    echo Ingresa la contraseña de la llave (puede ser la misma):
    set /p keypass=
    
    echo storePassword=%storepass%> android\key.properties
    echo keyPassword=%keypass%>> android\key.properties
    echo keyAlias=oasistaxiperu>> android\key.properties
    echo storeFile=oasistaxiperu.keystore>> android\key.properties
    
    echo.
    echo key.properties creado exitosamente!
    echo.
    echo Agregando key.properties a .gitignore...
    echo android/key.properties>> .gitignore
    echo.
    echo Listo! Ya puedes ejecutar build_release.bat
)

echo.
pause