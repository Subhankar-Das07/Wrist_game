plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.subhankardas.jesture"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    aaptOptions {
        noCompress("tflite")
        noCompress("task") // MediaPipe model file
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    defaultConfig {
        applicationId = "com.subhankardas.jesture"
        minSdk = 24
        targetSdk = 34
        versionCode = 2
        versionName = "1.0.1"
    }

    buildTypes {
        release {
            // TODO: Replace with a production keystore before Play Store submission.
            // See android/key.properties for setup instructions.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    jvmToolchain(21)
}

flutter {
    source = "../.."
}

dependencies {
    // MediaPipe Hand Landmarker for fist tracking
    implementation("com.google.mediapipe:tasks-vision:0.10.14")

    // Razorpay Payment Gateway — pre-wired, activated when credentials are received
    implementation("com.razorpay:checkout:1.6.40")
}
