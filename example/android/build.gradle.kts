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

    // Flutter's integration_test exports these dependencies to the app.
    // Use the resolved versions without fetching Maven version lists.
    if (path == ":integration_test" || path == ":app") {
        configurations.configureEach {
            resolutionStrategy.eachDependency {
                when ("${requested.group}:${requested.name}:${requested.version}") {
                    "androidx.test:runner:1.2+" -> useVersion("1.3.0")
                    "androidx.test:rules:1.2+" -> useVersion("1.2.0")
                    "androidx.test.espresso:espresso-core:3.3+" -> useVersion("3.3.0")
                }
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
