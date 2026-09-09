import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningPropertiesFile = rootProject.file("key.properties")
val releaseSigningProperties = Properties()

if (releaseSigningPropertiesFile.isFile) {
    FileInputStream(releaseSigningPropertiesFile).use { input ->
        releaseSigningProperties.load(input)
    }
}

fun releaseSigningValue(propertyName: String, environmentName: String): String? =
    System.getenv(environmentName)?.trim()?.takeIf { it.isNotEmpty() }
        ?: releaseSigningProperties
            .getProperty(propertyName)
            ?.trim()
            ?.takeIf { it.isNotEmpty() }

val releaseStoreFilePath =
    releaseSigningValue("storeFile", "TERRAMANAGER_KEYSTORE_FILE")
val releaseStorePassword =
    releaseSigningValue("storePassword", "TERRAMANAGER_KEYSTORE_PASSWORD")
val releaseKeyAlias =
    releaseSigningValue("keyAlias", "TERRAMANAGER_KEY_ALIAS")
val releaseKeyPassword =
    releaseSigningValue("keyPassword", "TERRAMANAGER_KEY_PASSWORD")
val releaseStoreFile = releaseStoreFilePath?.let { path -> rootProject.file(path) }
val missingReleaseSigningValues =
    listOf(
        "storeFile" to releaseStoreFilePath,
        "storePassword" to releaseStorePassword,
        "keyAlias" to releaseKeyAlias,
        "keyPassword" to releaseKeyPassword,
    ).filter { (_, value) -> value == null }.map { (name, _) -> name }
val releaseBuildRequested =
    gradle.startParameter.taskNames.any { taskName ->
        taskName.contains("release", ignoreCase = true)
    }

if (releaseBuildRequested && missingReleaseSigningValues.isNotEmpty()) {
    throw GradleException(
        "Production signing is required for release builds. Missing: " +
            missingReleaseSigningValues.joinToString() +
            ". Copy android/key.properties.example to android/key.properties " +
            "or configure the TERRAMANAGER_* environment variables.",
    )
}

if (releaseBuildRequested && releaseStoreFile?.isFile != true) {
    throw GradleException(
        "The configured TerraManager release keystore does not exist: " +
            (releaseStoreFile?.absolutePath ?: releaseStoreFilePath),
    )
}

val releaseSigningConfigured =
    missingReleaseSigningValues.isEmpty() && releaseStoreFile?.isFile == true

android {
    namespace = "com.codefrog.terramanager"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.codefrog.terramanager"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val productionSigningConfig =
        if (releaseSigningConfigured) {
            signingConfigs.create("release") {
                storeFile = requireNotNull(releaseStoreFile)
                storePassword = requireNotNull(releaseStorePassword)
                keyAlias = requireNotNull(releaseKeyAlias)
                keyPassword = requireNotNull(releaseKeyPassword)
            }
        } else {
            null
        }

    buildTypes {
        release {
            if (productionSigningConfig != null) {
                signingConfig = productionSigningConfig
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
