plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.zen.music.zenmusic.lossless"
    compileSdk = 37

    defaultConfig {
        minSdk = 24

        externalNativeBuild {
            cmake {
                // STL choice and the 16 KB page-size support flag match the
                // proven reference. The policy floor lets soxr 0.1.3's
                // legacy CMake configure under modern CMake — do not drop it.
                arguments += listOf(
                    "-DANDROID_STL=c++_shared",
                    "-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON",
                    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5",
                )
            }
        }
    }

    buildFeatures {
        // Consumes com.google.oboe:oboe's prefab-packaged native library.
        prefab = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    externalNativeBuild {
        cmake {
            path = file("cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.media3:media3-common:1.4.1")
    implementation("com.google.oboe:oboe:1.10.0")
}