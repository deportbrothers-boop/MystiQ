allprojects {
    repositories {
        google()
        mavenCentral()
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

// Enforce Java 17 and Kotlin JVM 17 across all Android subprojects (including plugins)
// Do not override Kotlin JVM target globally; let each module decide to avoid
// mismatches with third‑party plugins that still use 1.8.

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
