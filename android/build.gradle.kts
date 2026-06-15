allprojects {
    repositories {
        google()
        mavenCentral()
    }
    extra["firebase_bom_version"] = "33.8.0"
}

// Some Flutter plugins (notably some FlutterFire modules) still hard-code an
// older AGP version in their own `buildscript { dependencies { classpath(...) } }`.
// With newer Gradle wrappers this can break the build at task-graph time.
// Force a single AGP version across subprojects.
subprojects {
    buildscript {
        configurations.matching { it.name == "classpath" }.all {
            resolutionStrategy.eachDependency {
                if (requested.group == "com.android.tools.build" && requested.name == "gradle") {
                    useVersion("8.9.1")
                }
            }
        }
    }
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
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
