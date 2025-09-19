// Configuración para Google Services (Firebase)
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
    
    // Configuración global para suprimir warnings
    tasks.withType<JavaCompile> {
        options.compilerArgs.addAll(listOf("-Xlint:-deprecation", "-Xlint:-options"))
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    
    // Configurar Java 17 y Kotlin para todos los subproyectos de forma agresiva
    afterEvaluate {
        // Configurar Android
        if (hasProperty("android")) {
            extensions.configure<com.android.build.gradle.BaseExtension> {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
                
                // Forzar kotlinOptions si está disponible
                if (this is com.android.build.gradle.LibraryExtension || this is com.android.build.gradle.AppExtension) {
                    try {
                        @Suppress("UNCHECKED_CAST")
                        val kotlinOptionsMethod = this::class.java.getMethod("getKotlinOptions")
                        val kotlinOptions = kotlinOptionsMethod.invoke(this) as Any
                        val setJvmTargetMethod = kotlinOptions::class.java.getMethod("setJvmTarget", String::class.java)
                        setJvmTargetMethod.invoke(kotlinOptions, JavaVersion.VERSION_17.toString())
                    } catch (e: Exception) {
                        // Si no funciona, continuamos sin error
                    }
                }
            }
        }
        
        // Configurar Kotlin tasks
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
            kotlinOptions {
                jvmTarget = JavaVersion.VERSION_17.toString()
            }
        }
        
        // Configurar JavaCompile tasks para forzar Java 17 y suprimir warnings externos
        tasks.withType<JavaCompile> {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
            options.compilerArgs.addAll(listOf("-Xlint:-deprecation", "-Xlint:-options"))
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
