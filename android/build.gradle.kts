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
        // Its version follows the pinned Kotlin plugin declaration in settings.
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
