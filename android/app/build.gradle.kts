import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Optional release signing. Distribution builds must provide an (untracked)
// android/key.properties pointing at a keystore; both key.properties and *.jks
// are gitignored. Without it, the release build falls back to debug signing so
// `flutter run --release` still works for local development. See
// DEVELOPMENT.md §3.3.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.luminaapps.cairn"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.luminaapps.cairn"
        // Health Connect requires Android 8.0 (API 26); see DEVELOPMENT.md §3.3.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Default to debug signing so `flutter run --release` works without a
            // keystore; the line below overrides it when android/key.properties
            // exists. Each assignment is a single statement whose value has no
            // spaces, so F-Droid's signing-config scrubber strips both cleanly
            // (F-Droid builds unsigned and signs with its own key). A multi-line
            // or spaced expression here breaks that scrub. See DEVELOPMENT.md §3.3.
            signingConfig = signingConfigs.getByName("debug")
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
