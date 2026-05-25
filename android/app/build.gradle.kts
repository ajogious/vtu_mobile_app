import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------------
// Helper: load a key.properties file if it exists (returns empty map otherwise)
// ---------------------------------------------------------------------------
fun loadKeyProperties(fileName: String): Properties {
    val props = Properties()
    val file = rootProject.file(fileName)
    if (file.exists()) {
        file.inputStream().use { props.load(it) }
    }
    return props
}

val a3techKeys     = loadKeyProperties("a3tech-key.properties")
val amazcomKeys    = loadKeyProperties("amazcom-key.properties")
val zamanKeys      = loadKeyProperties("zamanconcept-key.properties")
val azdigitalKeys  = loadKeyProperties("azdigital-key.properties")

android {
    namespace = "com.a3tech.vtumobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // -------------------------------------------------------------------------
    // Signing configs — one per client. Credentials live in gitignored
    // <client>-key.properties files at the android/ project root.
    // -------------------------------------------------------------------------
    signingConfigs {
        create("a3tech_release") {
            storeFile     = a3techKeys.getProperty("storeFile")?.let { file(it) }
            storePassword = a3techKeys.getProperty("storePassword") ?: ""
            keyAlias      = a3techKeys.getProperty("keyAlias") ?: ""
            keyPassword   = a3techKeys.getProperty("keyPassword") ?: ""
        }
        create("amazcom_release") {
            storeFile     = amazcomKeys.getProperty("storeFile")?.let { file(it) }
            storePassword = amazcomKeys.getProperty("storePassword") ?: ""
            keyAlias      = amazcomKeys.getProperty("keyAlias") ?: ""
            keyPassword   = amazcomKeys.getProperty("keyPassword") ?: ""
        }
        create("zamanconcept_release") {
            storeFile     = zamanKeys.getProperty("storeFile")?.let { file(it) }
            storePassword = zamanKeys.getProperty("storePassword") ?: ""
            keyAlias      = zamanKeys.getProperty("keyAlias") ?: ""
            keyPassword   = zamanKeys.getProperty("keyPassword") ?: ""
        }
        create("azdigital_release") {
            storeFile     = azdigitalKeys.getProperty("storeFile")?.let { file(it) }
            storePassword = azdigitalKeys.getProperty("storePassword") ?: ""
            keyAlias      = azdigitalKeys.getProperty("keyAlias") ?: ""
            keyPassword   = azdigitalKeys.getProperty("keyPassword") ?: ""
        }
    }

    // -------------------------------------------------------------------------
    // Flavor dimensions
    // -------------------------------------------------------------------------
    flavorDimensions += "client"

    productFlavors {
        create("a3tech") {
            dimension       = "client"
            applicationId   = "com.a3tech.vtumobile"
            resValue("string", "app_name", "A3TECH DATA")
            signingConfig   = if (a3techKeys.isEmpty) signingConfigs.getByName("debug")
                              else signingConfigs.getByName("a3tech_release")
        }
        create("amazcom") {
            dimension       = "client"
            applicationId   = "com.amazcom.vtumobile"
            resValue("string", "app_name", "Amazcom")
            signingConfig   = if (amazcomKeys.isEmpty) signingConfigs.getByName("debug")
                              else signingConfigs.getByName("amazcom_release")
        }
        create("zamanconcept") {
            dimension       = "client"
            applicationId   = "com.zamanconcept.vtumobile"
            resValue("string", "app_name", "ZamanConcept")
            signingConfig   = if (zamanKeys.isEmpty) signingConfigs.getByName("debug")
                              else signingConfigs.getByName("zamanconcept_release")
        }
        create("azdigital") {
            dimension       = "client"
            applicationId   = "com.azdigital.vtumobile"
            resValue("string", "app_name", "AzDigital")
            signingConfig   = if (azdigitalKeys.isEmpty) signingConfigs.getByName("debug")
                              else signingConfigs.getByName("azdigital_release")
        }
    }

    defaultConfig {
        minSdk     = flutter.minSdkVersion
        targetSdk  = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Skip native debug symbol stripping (NDK not required locally;
        // Google Play strips symbols automatically on upload)
        ndk {
            debugSymbolLevel = "NONE"
        }
    }

    buildTypes {
        release {
            // R8 shrinking & obfuscation
            isMinifyEnabled   = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Signing is configured per-flavor above
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
