allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

dependencyLocking {
    lockAllConfigurations()
    lockMode = LockMode.STRICT
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
    if (name == "flutter_local_notifications") {
        // Keep the new plugin on the app's AGP baseline instead of resolving
        // its older, unused build-tool classpath alongside it.
        buildscript.configurations.configureEach {
            resolutionStrategy.eachDependency {
                if (requested.group == "com.android.tools.build" && requested.name == "gradle") {
                    useVersion("9.1.1")
                    because("Match TerraManager's pinned Android Gradle Plugin")
                }
                if (requested.group == "org.jetbrains.kotlin" && requested.name == "kotlin-gradle-plugin") {
                    useVersion("2.4.20")
                    because("Match TerraManager's AGP-hosted Kotlin compiler baseline")
                }
            }
        }
        configurations.configureEach {
            if (name.contains("UnitTest", ignoreCase = true)) {
                resolutionStrategy.eachDependency {
                    if (requested.group == "junit" && requested.name == "junit") {
                        useVersion("4.13.2")
                        because("Avoid GHSA-269g-pwp5-87pp in plugin tests")
                    }
                    if (requested.group == "org.bouncycastle" && requested.name == "bcprov-jdk18on") {
                        useVersion("1.86")
                        because("Use a patched provider in the plugin's Robolectric tests")
                    }
                }
            }
        }
    }
    dependencyLocking {
        lockAllConfigurations()
        lockMode = LockMode.STRICT
        // Flutter plugins live in the Pub cache, so keep their Gradle locks in Git.
        if (project.name != "app") {
            lockFile = rootProject.file("gradle-locks/${project.name}.lockfile")
        }
        // Engine artifacts are fixed by the pinned Flutter SDK, not by Pub plugins.
        ignoredDependencies.add("io.flutter:*")
        // Gradle can introduce this Kotlin transitive only after applying a lock.
        // Its version follows the pinned Kotlin compiler classpath in settings.
        ignoredDependencies.add("org.jetbrains.kotlin:kotlin-stdlib-common")
    }
    buildscript {
        dependencyLocking {
            lockAllConfigurations()
            lockMode = LockMode.STRICT
            lockFile = rootProject.file("gradle-locks/${project.name}-buildscript.lockfile")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

tasks.register("resolveAndroidDependencyLocks") {
    group = "verification"
    description = "Resolve every Android project dependency report for lockfile updates."
    dependsOn(subprojects.map { "${it.path}:dependencies" })
}

tasks.register("verifyAndroidBuiltInKotlin") {
    group = "verification"
    description = "Verify that Android modules compile without the external Kotlin Android plugin."
    doLast {
        check(providers.gradleProperty("android.builtInKotlin").orNull == "true") {
            "TerraManager requires android.builtInKotlin=true."
        }
        val androidProjects = subprojects.filter {
            it.plugins.hasPlugin("com.android.application") ||
                it.plugins.hasPlugin("com.android.library")
        }
        val legacyProjects = androidProjects.filter {
            it.plugins.hasPlugin("org.jetbrains.kotlin.android") ||
                it.plugins.hasPlugin("kotlin-android")
        }
        check(legacyProjects.isEmpty()) {
            "External Kotlin Android plugin is still applied by: " +
                legacyProjects.joinToString { it.path }
        }
        check(project(":app").extensions.findByName("kotlin") != null) {
            "The app's Built-in Kotlin extension is missing."
        }
        logger.lifecycle("Built-in Kotlin verified in ${androidProjects.size} Android modules.")
    }
}
