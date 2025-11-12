plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
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
        // AdMob App ID placeholder (Google sample test App ID by default)
        manifestPlaceholders["ADMOB_APP_ID"] = (System.getenv("ADMOB_APP_ID")
            ?: "ca-app-pub-4678612524495888~7606654160")
    }

    // Load release keystore config if android/key.properties exists
    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { fis ->
            keystoreProperties.load(fis)
        }

        signingConfigs {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use release keystore if provided; otherwise fall back to debug signing
            if (project.file("../key.properties").exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
        debug {
            // Ensure test App ID is used for debug builds
            manifestPlaceholders["ADMOB_APP_ID"] = (System.getenv("ADMOB_APP_ID")
                ?: "ca-app-pub-3940256099942544~3347511713")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring support for java.time, streams etc.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

