plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Keep credentials outside Git. Environment values also support CI secret stores.
val releaseProperties = java.util.Properties()
val releasePropertiesFile = rootProject.file("key.properties")
if (releasePropertiesFile.exists()) {
    releasePropertiesFile.inputStream().use { releaseProperties.load(it) }
}
fun releaseValue(property: String, environment: String): String? =
    System.getenv(environment)?.takeIf { it.isNotBlank() }
        ?: releaseProperties.getProperty(property)?.takeIf { it.isNotBlank() }
val releaseStore = releaseValue("storeFile", "STRANNIK_KEYSTORE_PATH")
val releaseStorePassword = releaseValue("storePassword", "STRANNIK_KEYSTORE_PASSWORD")
val releaseAlias = releaseValue("keyAlias", "STRANNIK_KEY_ALIAS")
val releaseKeyPassword = releaseValue("keyPassword", "STRANNIK_KEY_PASSWORD")
val releaseSigningConfigured = listOf(
    releaseStore, releaseStorePassword, releaseAlias, releaseKeyPassword
).all { it != null }

// Fail before packaging rather than silently producing a debug-signed release.
val validateReleaseSigning by tasks.registering {
    doLast {
        check(releaseSigningConfigured) {
            "Production signing is missing. Supply android/key.properties or STRANNIK_KEYSTORE_PATH, " +
                "STRANNIK_KEYSTORE_PASSWORD, STRANNIK_KEY_ALIAS and STRANNIK_KEY_PASSWORD. " +
                "See docs/RELEASE_READINESS.md."
        }
        check(rootProject.file(releaseStore!!).isFile) { "Production keystore file does not exist." }
        check(releaseAlias != "androiddebugkey") { "The Android debug key cannot sign production releases." }
    }
}
tasks.configureEach {
    if (name == "preReleaseBuild") dependsOn(validateReleaseSigning)
}

android {
    namespace = "ru.strannik.strannik"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "ru.strannik.strannik"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("production") {
                storeFile = rootProject.file(releaseStore!!)
                storePassword = releaseStorePassword
                keyAlias = releaseAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("production")
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
