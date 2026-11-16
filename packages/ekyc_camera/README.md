# ekyc_camera

Camera code shared by `ekyc_mrz_scanner` and `ekyc_face_capture`.

* `MlKitCamera` opens the preferred lens and streams frames to ML Kit.
  * It processes one frame at a time, at the interval you choose.
  * It releases the camera while the app is in the background and reopens
    it on return.
  * `takePicture()` deletes the plugin's temporary file once the photo is
    read.
* `MlKitCameraView` shows the camera cover-fit with an overlay on top. It
  shows a loading view while the camera opens and a fallback when there is
  no camera or permission.
* `ScrimPainter` darkens everything outside a capture guide.
* `inputImageRotation` and `toInputImage` convert camera frames for ML Kit
  on Android (NV21) and iOS (BGRA).
* `package:ekyc_camera/testing.dart` provides `FakeCameraPlatform`, so
  camera code can be widget-tested without a device. It can emit frames,
  write photos and deny permission.

## Setup

### Android

In `android/app/build.gradle.kts`, ML Kit and the camera plugin need API 24
or later:

```kotlin
defaultConfig {
    minSdk = maxOf(24, flutter.minSdkVersion)
}
```

In `android/app/src/main/AndroidManifest.xml`, inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="false" />
```

### iOS

ML Kit needs iOS 15.5 or later. Set `IPHONEOS_DEPLOYMENT_TARGET = 15.5` in
the Runner target (and `platform :ios, '15.5'` in `ios/Podfile` if your
project uses CocoaPods).

In `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Used to photograph your document and take a selfie for identity verification.</string>
```
