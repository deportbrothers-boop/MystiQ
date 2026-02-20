plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

android {
    namespace = "com.mystiq.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Target JDK 17 to avoid "source 8 is obsolete" warnings on modern JDKs
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by some libraries (e.g., flutter_local_notifications)
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mystiq.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // AdMob App ID placeholder
        manifestPlaceholders["ADMOB_APP_ID"] = (System.getenv("ADMOB_APP_ID")
            ?: "ca-app-pub-4678612524495888~7606654160")
    }

    // Release signing: load from android/key.properties (do NOT fall back to debug signing)
    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { fis ->
            keystoreProperties.load(fis)
        }
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                val storeFilePath = (keystoreProperties["storeFile"] as String).trim()
                storeFile = rootProject.file(storeFilePath)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            if (!keystorePropertiesFile.exists()) {
                throw org.gradle.api.GradleException(
                    "Missing android/key.properties for release signing. Copy android/key.properties.example and configure your upload keystore."
                )
            }
            signingConfig = signingConfigs.getByName("release")

            // Size optimizations (no asset quality changes):
            // - Shrink Java/Kotlin bytecode and Android resources for release.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )

            // Exclude emulator ABIs from release to reduce bundle size.
            ndk {
                abiFilters.clear()
                abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a"))
            }
        }
        debug {
            // Debug builds:
            // - Prefer ADMOB_APP_ID_DEBUG if provided, else fall back to ADMOB_APP_ID (prod).
            // Note: Android emulators are treated as test devices by Google Mobile Ads SDK.
            manifestPlaceholders["ADMOB_APP_ID"] = (System.getenv("ADMOB_APP_ID_DEBUG")
                ?: System.getenv("ADMOB_APP_ID")
                ?: "ca-app-pub-4678612524495888~7606654160")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.9.0"))
    implementation("com.google.firebase:firebase-crashlytics")

    // Core library desugaring support for java.time, streams etc.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
