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
    // ── ADDED: enables BuildConfig class generation ──────────────────────────
    buildFeatures {
        buildConfig = true
    }
    // ─────────────────────────────────────────────────────────────────────────
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
            // ── ADDED: backend URL for local WiFi testing ──────────────────
            buildConfigField("String", "API_BASE_URL", "\"http://192.168.100.8:3000\"")
        }
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // ── ADDED: replace with your Railway URL before client delivery ─
            buildConfigField("String", "API_BASE_URL", "\"https://observant-smile-production-a472.up.railway.app\"")
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
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
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
    // ===== ADD THESE =====
    // Coroutines for async operations
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")

    // ===== W3.E: WorkManager (scheduled-transaction firing + boot reconciliation) =====
    // CoroutineWorker now lives in the main work-runtime artifact; -ktx pulls it
    // transitively. The work-runtime AAR also contributes the built-in
    // RescheduleReceiver (BOOT_COMPLETED / TIME_SET / TIMEZONE_CHANGED) to the
    // merged manifest — this is what re-arms scheduled one-shots after a reboot
    // and fires any that came due while the phone was off (D-W3-18: match
    // Hybrid's "fire all overdues on boot"; no custom boot code required).
    implementation("androidx.work:work-runtime-ktx:2.11.2")
}