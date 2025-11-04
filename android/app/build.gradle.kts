plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.mystiq"
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
        applicationId = "com.example.mystiq"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // AdMob App ID placeholder (Google sample test App ID by default)
        manifestPlaceholders["ADMOB_APP_ID"] = (System.getenv("ADMOB_APP_ID")
            ?: "ca-app-pub-3940256099942544~3347511713")
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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

