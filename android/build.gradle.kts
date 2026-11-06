allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

/*
 Force a modern compileSdk on every Android (plugin) module. Some older plugins
 pin their own low compileSdk (e.g. 30), which breaks release resource
 verification with "resource android:attr/lStar not found".
*/
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        if (androidExt != null) {
            androidExt.compileSdkVersion(36)
        }
    }
}

/*
 Add core library desugaring to Android library (plugin) modules that enable it,
 so the coreLibraryDesugaring configuration is not empty when AGP requires it.
*/
subprojects {
    afterEvaluate {
        val androidLib = extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
        val desugaringEnabled = androidLib?.compileOptions?.isCoreLibraryDesugaringEnabled == true

        if (desugaringEnabled && configurations.findByName("coreLibraryDesugaring") != null) {
            dependencies.add("coreLibraryDesugaring", "com.android.tools:desugar_jdk_libs:2.1.4")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
