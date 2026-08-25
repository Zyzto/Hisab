import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase config only ships with the cloud flavor. A clean clone of the public
// repo has no google-services.json at all, so applying the plugin unconditionally
// would fail the build for anyone without the cloud credentials.
val cloudGoogleServices = file("src/cloud/google-services.json")
if (cloudGoogleServices.exists()) {
    apply(plugin = "com.google.gms.google-services")

    // The plugin, once applied, wires itself into every variant — including
    // foss, which has no config and does not want Firebase. Without this the
    // foss build fails for anyone who also happens to have the cloud
    // credentials on disk, which is every maintainer.
    tasks.matching {
        it.name.startsWith("process") && it.name.endsWith("GoogleServices") &&
            !it.name.contains("Cloud")
    }.configureEach {
        enabled = false
    }
}

// Load key.properties if it exists (CI writes it from secrets; local dev may not have it).
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "com.shenepoy.hisab"
    // permission_handler_android (and peers) compile against 37; Flutter's
    // default is still 36. compileSdk is backward compatible.
    compileSdk = maxOf(flutter.compileSdkVersion, 37)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.shenepoy.hisab"
        // ML Kit GenAI Prompt (Gemini Nano) requires API 26+
        minSdk = maxOf(flutter.minSdkVersion, 26)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // App ships en + ar only; drop unused dependency locale resources.
        resourceConfigurations += listOf("en", "ar")
    }

    signingConfigs {
        if (keyPropertiesFile.exists()) {
            create("release") {
                storeFile = file(keyProperties["storeFile"] as String)
                storePassword = keyProperties["storePassword"] as String
                keyAlias = keyProperties["keyAlias"] as String
                keyPassword = keyProperties["keyPassword"] as String
            }
        }
    }

    // cloud: the published app — Firebase, deep links, production signing key.
    //        Built only from the private repo, which supplies the credentials.
    // foss:  the offline build from the public repo. Installs side by side with
    //        cloud and is signed with a separate key held in the public repo.
    flavorDimensions += "distribution"
    productFlavors {
        create("cloud") {
            dimension = "distribution"
        }
        create("foss") {
            dimension = "distribution"
            applicationIdSuffix = ".foss"
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
        }
        release {
            signingConfig = if (keyPropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                // Fall back to debug signing for local development.
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Tesseract 5 for local receipt OCR (see ReceiptOcrBridge).
    implementation("cz.adaptech.tesseract4android:tesseract4android:4.9.0")
}

flutter {
    source = "../.."
}
