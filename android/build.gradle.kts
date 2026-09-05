import com.android.build.api.dsl.LibraryExtension

allprojects {
    repositories {
        google()
        mavenCentral()
        // Tesseract4Android (local receipt OCR)
        maven(url = uri("https://jitpack.io"))
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

// Some Flutter plugins still declare an older compile SDK in their own
// Android library module. Keep their AAR metadata compatible with the
// dependency graph resolved by the app (notably clipboard + AndroidX).
subprojects {
    afterEvaluate {
        plugins.withId("com.android.library") {
            extensions.configure<LibraryExtension> {
                compileSdk = 37
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
