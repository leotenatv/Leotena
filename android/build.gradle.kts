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

    // flutter_inappwebview uses Android compatibility APIs internally. Keep its
    // upstream javac notices from obscuring warnings produced by this app.
    if (name == "flutter_inappwebview_android") {
        tasks.withType<JavaCompile>().configureEach {
            options.compilerArgs.add("-XDsuppressNotes")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
