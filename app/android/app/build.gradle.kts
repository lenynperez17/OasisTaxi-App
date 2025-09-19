plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Google Services plugin para Firebase
    id("com.google.gms.google-services")
}

android {
    namespace = "com.oasistaxis.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // Signing configurations for production
    signingConfigs {
        create("release") {
            keyAlias = System.getenv("KEYSTORE_ALIAS") ?: "oasistaxikey"
            keyPassword = System.getenv("KEYSTORE_KEY_PASSWORD") ?: ""
            storeFile = file(System.getenv("KEYSTORE_PATH") ?: "../keystore/oasistaxiperu.jks")
            storePassword = System.getenv("KEYSTORE_PASSWORD") ?: ""
        }
    }

    defaultConfig {
        // Application ID configurado para OasisTaxi
        applicationId = "com.oasistaxis.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Enable multidex for production
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Configuración para Release (producción)
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")

            // Production signing configuration
            signingConfig = signingConfigs.getByName("release")

            // Ndk configuration for native libraries
            ndk {
                // debugSymbolLevel = com.android.build.api.dsl.DebugSymbolLevel.FULL
                // Commented out temporarily for compatibility
            }
        }

        debug {
            isDebuggable = true
            versionNameSuffix = "-debug"
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Encryption for secure storage
    implementation("androidx.security:security-crypto:1.1.0-alpha06")

    // App integrity verification
    implementation("com.google.android.play:integrity:1.3.0")

    // Additional security measures
    implementation("com.google.android.gms:play-services-safetynet:18.0.1")
}
