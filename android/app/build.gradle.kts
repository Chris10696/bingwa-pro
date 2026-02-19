plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // MUST be applied AFTER Android + Kotlin plugins
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.bingwa_pro"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.bingwa_pro"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
        
        // Add multiDex for older devices
        multiDexEnabled = true
    }

    buildTypes {
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    
    // Add packaging options
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            excludes += "/META-INF/DEPENDENCIES"
        }
    }
}

flutter {
    source = "../.."
}

// Remove the force resolution strategy - use version catalogs instead
dependencies {
    // Core AndroidX dependencies
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("androidx.browser:browser:1.6.0")
    
    // Support for older devices
    implementation("androidx.multidex:multidex:2.0.1")
    
    // Material design
    implementation("com.google.android.material:material:1.11.0")
    
    // Kotlin stdlib
    implementation("org.jetbrains.kotlin:kotlin-stdlib:2.1.0")
}
