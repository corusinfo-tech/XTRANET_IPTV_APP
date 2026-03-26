plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.xeranet_tv_application"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

packaging {
    jniLibs {
        useLegacyPackaging = true
        pickFirsts += setOf("**/libpandrm.so")
    }
}
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.xeranet_tv_application"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName

    ndk {
        abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
    }
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

repositories {
    flatDir {
        dirs("libs")
    }
}

// Force exclusion of the standard HLS module so Panaccess's custom HLS module takes precedence
configurations.all {
    exclude(group = "androidx.media3", module = "media3-exoplayer-hls")
}

dependencies {
    // Load all AAR files from the libs directory (including drm, copyprotect, cvintercom, exoplayer)
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.aar"))))
    // Media3 ExoPlayer
    val media3Version = "1.5.1"
    implementation("androidx.media3:media3-exoplayer:$media3Version")
    implementation("androidx.media3:media3-ui:$media3Version")
    implementation("androidx.media3:media3-datasource:$media3Version")
    // implementation("androidx.media3:media3-exoplayer-hls:$media3Version") // Removed as it conflicts with Panaccess HLS AAR
    implementation("androidx.media3:media3-common:$media3Version")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
}