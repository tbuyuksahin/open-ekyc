# ekyc_mrz_scanner

The MRZ step of an e-KYC flow in Flutter.

* `MrzScanner`: a live camera preview that reads the MRZ on the device
  with ML Kit. It accepts a result only when two consecutive frames read
  the same text and every check digit passes.
* `MrzOverlay`: a document-shaped guide drawn to ICAO sizes (ID-1 card,
  ID-2, passport data page). It has an MRZ band, an animated scan line and
  status colors. The template switches to the format in view.
* `ManualMrzForm`: the three fields that open the chip (document number,
  date of birth, expiry date), with validation and replaceable labels.

```dart
MrzScanner(
  onDetected: (mrz) => readChip(mrz.key),
  unavailableBuilder: (_) => const Text('Camera not available'),
  format: MrzFormat.td1, // template shown before anything is read
  hintText: (status) => switch (status) {
    MrzScanStatus.searching => 'Line up the bottom lines with the band',
    MrzScanStatus.confirming => 'Hold still…',
    MrzScanStatus.detected => 'Got it',
  },
  style: const MrzOverlayStyle(
    frameColor: Colors.white,
    accentColor: Colors.lightBlueAccent,
    successColor: Colors.greenAccent,
    scrimColor: Color(0xAA000000),
    cornerRadius: 16,
    widthFactor: 0.92,
    showTemplate: true,
    showScanLine: true,
  ),
)
```

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

## Overlay states

| Status | Outline | Motion |
| --- | --- | --- |
| `searching` | `frameColor` | Scan line moves over the MRZ band |
| `confirming` | `accentColor` | Scan line continues |
| `detected` | `successColor`, band tinted, check mark | Stops |

Motion stops when the system asks for reduced animations.
`MrzOverlay.documentRect` and `MrzOverlay.mrzRect` expose the geometry, so
you can crop frames or build your own overlay with `MrzOverlayPainter`.

## Privacy

Frames are processed one at a time and never stored or sent anywhere. The
camera is released while the app is in the background. Form fields are
cleared when the form is disposed.
