plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val naverApiKey: String = run {
    val envFile = project.file("../../.env")
    if (envFile.exists()) {
        envFile.readLines().forEach { line ->
            val parts = line.split("=", limit = 2)
            if (parts.size == 2 && parts[0].trim() == "NAVER_API_KEY") {
                return@run parts[1].trim()
            }
        }
    }
    logger.warn("WARNING: NAVER_API_KEY not found in .env file!")
    logger.warn("Please create a .env file in the project root with NAVER_API_KEY=your_api_key")
    ""
}

android {
    namespace = "com.example.tomapto"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
        freeCompilerArgs += listOf(
            "-Xno-param-assertions",
            "-Xno-call-assertions",
            "-Xno-receiver-assertions"
        )
    }

    defaultConfig {
        applicationId = "com.example.tomapto"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        if (naverApiKey.isEmpty()) {
            logger.warn("Building with empty NAVER_API_KEY - map functionality may not work")
        }
        manifestPlaceholders["NAVER_API_KEY"] = naverApiKey
    }

    buildTypes {
        debug {
        }
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:32.8.0"))
    implementation("com.google.firebase:firebase-analytics-ktx")
    implementation("com.google.firebase:firebase-messaging-ktx")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}