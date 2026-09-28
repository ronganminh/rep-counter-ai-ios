import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.ronganminh.repcoach"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.ronganminh.repcoach"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }

    // Hai bien the:
    //   store -> ban len Google Play. KHONG chua ma ghi man hinh.
    //   diag  -> ban chan doan gui cho nguoi test. Co ghi man hinh.
    //
    // Tach bang flavor chu khong bang co `if` trong code, de ma ghi man hinh
    // va quyen MediaProjection KHONG the lot vao ban phat hanh. Lop
    // DiagRecorder co hai ban cai dat: src/diag (that) va src/store (rong).
    flavorDimensions += "audience"
    productFlavors {
        create("store") {
            dimension = "audience"
        }
        create("diag") {
            dimension = "audience"
            // Doi applicationId de cai song song voi ban store, va de khong bao
            // gio nop nham len Play.
            applicationIdSuffix = ".diag"
            versionNameSuffix = "-diag"
        }
    }
}

// Chan dong goi ban `diag` thanh .aab.
//
// Ban diag chi phat hanh duoi dang APK gui tay. Neu de Gradle sinh ra
// app-diag-release.aab thi mot lan bam nham la nop ban CO quyen ghi man hinh
// len Google Play. `flutter build appbundle --release` (thieu --flavor) dung
// la sinh ca hai ban, nen chan o day chu khong chi ghi trong tai lieu.
// `bundleDiagRelease` chi la task vong doi, chan no thi file .aab DA duoc tao
// xong roi (da kiem chung: file 91,5 MB voi 383 entry van xuat hien). Task tao
// file that la `packageDiagReleaseBundle`. Cung khong duoc dung
// startsWith("bundleDiag") vi no khop ca `bundleDiagReleaseClassesToCompileJar`
// — chan nham task do se lam vo luon ban APK diag.
tasks.configureEach {
    if ((name.startsWith("packageDiag") || name.startsWith("signDiag")) &&
        name.endsWith("Bundle")
    ) {
        doFirst {
            throw GradleException(
                "Ban diag khong duoc dong goi thanh .aab. " +
                "Ban gui nguoi test: flutter build apk --release --flavor diag | " +
                "Ban nop Play: flutter build appbundle --release --flavor store"
            )
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
