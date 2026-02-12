import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val secretsFile = rootProject.file("secrets.properties")
val secrets = Properties()
if (secretsFile.exists()) {
    secrets.load(secretsFile.inputStream())
}
val auth0DomainDev = secrets.getProperty("auth0DomainDev", "example.com")
val auth0DomainProd = secrets.getProperty("auth0DomainProd", "example.com")
val auth0Scheme = secrets.getProperty("auth0Scheme", "https")

android {
    namespace = "com.shenepoy.hisab"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.shenepoy.hisab"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Required by auth0_flutter. Values from android/secrets.properties (gitignored).
        manifestPlaceholders["auth0Domain"] = auth0DomainDev
        manifestPlaceholders["auth0Scheme"] = auth0Scheme
    }

    buildTypes {
        debug {
            manifestPlaceholders["auth0Domain"] = auth0DomainDev
            manifestPlaceholders["auth0Scheme"] = auth0Scheme
        }
        release {
            manifestPlaceholders["auth0Domain"] = auth0DomainProd
            manifestPlaceholders["auth0Scheme"] = auth0Scheme
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}
