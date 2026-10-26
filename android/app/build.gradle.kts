import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}

android {
    namespace = "com.stepandemianenko.focustrace"
    // 36, not Flutter's 35: FocusTrace targets Android 16.
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    testOptions {
        unitTests.isIncludeAndroidResources = true
    }

    defaultConfig {
        applicationId = "com.stepandemianenko.focustrace"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // 24: Play automatic protection rejects bundles below it. (23 was
        // already needed: the sync refresh token is sealed with an
        // AndroidKeyStore AES key, and KeyGenParameterSpec is API 23.)
        // Drops Android 6.0.
        minSdk = 24
        // Pinned: FocusTrace targets Android 16; Flutter's default lags at 35.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Only for connectedAndroidTest: the keystore work in
        // SecureCredentialStore cannot be exercised off-device.
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        getByName("debug") {
            // Keep normal `flutter run` sessions separate from the Play app.
            // A debug APK is signed with a different certificate, so reusing the
            // production application ID can make Flutter uninstall the Play copy.
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
        }

        release {
            // Falls back to debug signing when key.properties is absent
            // so `flutter run --release` still works on dev machines.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

// Profile APKs are small enough to sideload; keep them beside the Play app.
// Set per variant because a profile buildType suffix leaks into plugin libraries.
androidComponents {
    onVariants(selector().withBuildType("profile")) { variant ->
        variant.applicationId.set("com.stepandemianenko.focustrace.dev")
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 2.10.x was pinned because it was the newest line supporting minSdk 21.
    // That constraint is gone, but nothing here needs a newer line.
    implementation("androidx.work:work-runtime-ktx:2.10.5")
    // Optional workout import. Stable line; it declares minSdk 26, so the
    // manifest overrides that and HealthConnectImporter reports Health Connect
    // as unavailable below Android 8.
    implementation("androidx.health.connect:connect-client:1.1.0")
    // connect-client brings full Guava at runtime, which swaps WorkManager's
    // listenablefuture for an empty stub at compile time. Compile against the
    // same Guava so SyncPlatformChannel's ListenableFuture still resolves.
    compileOnly("com.google.guava:guava:31.1-android")
    testImplementation("junit:junit:4.13.2")
    testImplementation("androidx.health.connect:connect-testing:1.0.0-alpha03")
    testImplementation("org.json:json:20240303")
    testImplementation("org.robolectric:robolectric:4.15.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
}
