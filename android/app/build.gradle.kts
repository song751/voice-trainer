plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.local.voice_trainer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.local.voice_trainer"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

val verifyReleaseBackupPolicy by tasks.registering {
    group = "verification"
    description = "Checks the merged release manifest keeps all app data out of backup and transfer."
    dependsOn("processReleaseMainManifest")
    doLast {
        val mergedManifest = layout.buildDirectory.file(
            "intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml",
        ).get().asFile
        check(mergedManifest.isFile) {
            "Merged release manifest was not produced: ${mergedManifest.absolutePath}"
        }
        val manifest = mergedManifest.readText()
        check("android:allowBackup=\"false\"" in manifest) {
            "Merged release manifest must disable Android backup."
        }
        check("android:dataExtractionRules=\"@xml/data_extraction_rules\"" in manifest) {
            "Merged release manifest lost the Android 12+ extraction policy."
        }
        check("android:fullBackupContent=\"@xml/backup_rules\"" in manifest) {
            "Merged release manifest lost the legacy full-backup exclusion policy."
        }
    }
}

tasks.matching { it.name == "assembleRelease" }.configureEach {
    dependsOn(verifyReleaseBackupPolicy)
}
