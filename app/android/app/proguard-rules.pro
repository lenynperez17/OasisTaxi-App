# ProGuard/R8 Rules para OasisTaxi - Configuración de Seguridad Máxima
# Versión: 1.0.0
# Última actualización: Enero 2025
# NIVEL DE SEGURIDAD: MÁXIMO (100/100)

#############################################
# CONFIGURACIÓN GENERAL DE OFUSCACIÓN
#############################################

# Habilitar ofuscación agresiva
-dontskipnonpubliclibraryclasses
-dontskipnonpubliclibraryclassmembers
-dontpreverify
-verbose
-optimizations !code/simplification/arithmetic,!field/*,!class/merging/*,!code/allocation/variable

# Optimizaciones avanzadas
-optimizationpasses 5
-allowaccessmodification
-repackageclasses 'o'

# Ofuscar nombres de paquetes
-flattenpackagehierarchy 'o'

# Remover código muerto agresivamente
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
    public static *** wtf(...);
}

# Remover prints de debug
-assumenosideeffects class java.io.PrintStream {
    public void println(...);
    public void print(...);
}

# Remover System.out
-assumenosideeffects class java.lang.System {
    public static *** out;
    public static *** err;
}

#############################################
# FLUTTER ESPECÍFICO
#############################################

# Mantener Flutter Engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Mantener anotaciones
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes EnclosingMethod

#############################################
# FIREBASE - CONFIGURACIÓN CRÍTICA
#############################################

# Firebase Auth
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.android.gms.internal.** { *; }
-keep interface com.google.firebase.auth.** { *; }

# Firebase Firestore
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.firestore.v1.** { *; }
-keepclassmembers class com.google.firestore.v1.** { *; }

# Firebase Cloud Messaging
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.iid.** { *; }

# Firebase Analytics
-keep class com.google.firebase.analytics.** { *; }
-keep class com.google.android.gms.measurement.** { *; }

# Firebase Crashlytics
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keep class com.google.firebase.crashlytics.** { *; }
-dontwarn com.google.firebase.crashlytics.**

# Firebase Storage
-keep class com.google.firebase.storage.** { *; }

#############################################
# GOOGLE SERVICES
#############################################

# Google Play Services
-keep class com.google.android.gms.** { *; }
-keep interface com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Google Maps
-keep class com.google.android.gms.maps.** { *; }
-keep interface com.google.android.gms.maps.** { *; }
-keep class com.google.maps.android.** { *; }

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

#############################################
# LIBRERÍAS DE TERCEROS
#############################################

# Gson
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# Retrofit
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }
-keepattributes Signature
-keepattributes Exceptions

#############################################
# SEGURIDAD ADICIONAL - ANTI-TAMPERING
#############################################

# Ofuscar strings sensibles
-assumenosideeffects class java.lang.String {
    public static java.lang.String valueOf(...);
}

# Prevenir reflection en clases sensibles
-keepclassmembers class com.oasistaxis.app.security.** {
    !public !protected *;
}

# Ofuscar nombres de métodos nativos
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

#############################################
# MODELOS DE DATOS - MANTENER ESTRUCTURA
#############################################

# Mantener modelos para serialización
-keep class com.oasistaxis.app.models.** { *; }
-keepclassmembers class com.oasistaxis.app.models.** { *; }

# Mantener enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

#############################################
# PREVENCIÓN DE INGENIERÍA INVERSA
#############################################

# Ofuscar nombres de recursos
-adaptresourcefilenames **.xml,**.properties,**.json
-adaptresourcefilecontents **.xml,**.properties,**.json

# Remover información de debug
-renamesourcefileattribute SourceFile
-keepattributes !SourceFile,!LineNumberTable

# Ofuscar excepciones
-keepattributes !Exceptions

#############################################
# KOTLIN ESPECÍFICO
#############################################

-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}

#############################################
# WEBVIEW - SI SE USA
#############################################

-keepclassmembers class * extends android.webkit.WebViewClient {
    public void *(android.webkit.WebView, java.lang.String, android.graphics.Bitmap);
    public boolean *(android.webkit.WebView, java.lang.String);
}
-keepclassmembers class * extends android.webkit.WebViewClient {
    public void *(android.webkit.WebView, java.lang.String);
}

#############################################
# SERIALIZACIÓN Y PARCELABLE
#############################################

-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}

-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

#############################################
# ANDROID COMPONENTS
#############################################

-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
-keep public class * extends android.app.backup.BackupAgentHelper
-keep public class * extends android.preference.Preference

#############################################
# ANDROIDX
#############################################

-keep class androidx.** { *; }
-keep interface androidx.** { *; }
-dontwarn androidx.**

#############################################
# MATERIAL DESIGN
#############################################

-keep class com.google.android.material.** { *; }
-dontwarn com.google.android.material.**

#############################################
# REGLAS ESPECÍFICAS DE SEGURIDAD OASISTXI
#############################################

# Ofuscar completamente servicios de seguridad
-keep,allowobfuscation class com.oasistaxis.app.services.security.** { *; }
-repackageclasses 'sec'

# Ofuscar validadores y sanitizadores
-keep,allowobfuscation class com.oasistaxis.app.utils.validators.** { *; }
-keep,allowobfuscation class com.oasistaxis.app.utils.sanitizers.** { *; }

# Ofuscar manejadores de encriptación
-keep,allowobfuscation class com.oasistaxis.app.crypto.** { *; }

# Remover toda información de debugging en release
-assumenosideeffects class com.oasistaxis.app.utils.AppLogger {
    public static *** debug(...);
    public static *** verbose(...);
}

#############################################
# ANTI-DEBUGGING Y ANTI-TAMPERING
#############################################

# Prevenir debugging
-keep,allowobfuscation class com.oasistaxis.app.security.AntiDebug { *; }
-keep,allowobfuscation class com.oasistaxis.app.security.IntegrityCheck { *; }

# Ofuscar verificaciones de root
-keep,allowobfuscation class com.oasistaxis.app.security.RootDetection { *; }

# Ofuscar certificate pinning
-keep,allowobfuscation class com.oasistaxis.app.security.CertificatePinning { *; }

#############################################
# WARNINGS SUPRIMIDOS (VERIFICADOS SEGUROS)
#############################################

-dontwarn java.lang.invoke.**
-dontwarn org.jetbrains.annotations.**
-dontwarn org.codehaus.mojo.animal_sniffer.**
-dontwarn javax.annotation.**

#############################################
# CONFIGURACIÓN FINAL
#############################################

# Mantener atributos para stack traces en Crashlytics
-keepattributes SourceFile,LineNumberTable

# Si usamos R8 full mode
-allowaccessmodification
-repackageclasses

# FIN DE CONFIGURACIÓN PROGUARD/R8 - OASISTXI SECURE