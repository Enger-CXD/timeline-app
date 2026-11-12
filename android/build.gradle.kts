allprojects {
    repositories {
        // 国内加速镜像（阿里云），失败时自动回落到官方源
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
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
    // 部分插件（如 file_picker）自身声明的 compileSdk 偏低，统一抬到 36 避免 AAR metadata 校验失败
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            try {
                val android = ext as com.android.build.gradle.BaseExtension
                android.compileSdkVersion(36)
            } catch (_: Throwable) {
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
