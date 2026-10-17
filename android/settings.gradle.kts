pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // AGP hosts Kotlin compilation. Keep the existing compiler/security
        // baseline on its classpath without applying the external Android KGP.
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.4.20")
    }
    dependencyLocking {
        lockAllConfigurations()
        lockMode = LockMode.STRICT
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.1" apply false
}

include(":app")
