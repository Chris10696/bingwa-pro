buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        // Update to AGP 8.9.1 to match dependency requirements
        classpath("com.android.tools.build:gradle:8.9.1")
        // Update to Kotlin 2.1.0 as warned in earlier message
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Move build outputs to a single /build directory
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}