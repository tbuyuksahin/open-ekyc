# ekyc_document_capture

The document photo step of an e-KYC flow in Flutter: photograph the front
and back of an ID card, or the data page of a passport, and compare what
is printed with the MRZ or the chip.

* `DocumentCapture` uses the back camera and checks every frame on the
  device before it takes the photo:
  * enough light,
  * no glare,
  * sharp,
  * the expected side is in view.

  It captures each side in turn, automatically or with a shutter button.
  The temporary photo file is deleted right after it is read, and the
  photos are wiped if the widget is removed before it completes.
* `FrameAnalyzer` measures brightness, glare and sharpness from the raw
  camera frame (NV21 and BGRA8888). `DocumentQualityGate` turns the
  measurements into a hint and releases the photo after several good
  frames in a row.
* The side with the machine readable zone is recognized by reading it, so
  the user is told when the wrong side is shown. The MRZ comes back with
  the result, and can open the chip without a separate scan.
* `DocumentOverlay` draws a frame in the proportions of the document with
  a placeholder layout of the expected side. Its color follows the state
  (searching, adjusting, ready, captured).
* `DocumentCrossCheck` looks for the document number, names, dates and
  personal number in the text recognized on the front. It ignores case,
  spacing, punctuation and diacritics, and tolerates the usual OCR
  confusions in numbers.

```dart
DocumentCapture(
  kind: DocumentKind.idCard,
  onCaptured: (result) async {
    final check = result.crossCheck(); // front text against the MRZ
    await upload(result.front!, result.back!);
    result.wipe();
  },
  unavailableBuilder: (_) => const Text('Camera not available'),
  hintText: (hint, side) => switch (hint) {
    DocumentHint.noDocument => 'Place the ${side.name} inside the frame',
    DocumentHint.wrongSide => 'Turn the document over',
    DocumentHint.tooDark => 'Find more light',
    DocumentHint.glare => 'Tilt the document to remove the reflection',
    DocumentHint.blurry => 'Hold the phone steady',
    DocumentHint.holdStill => 'Hold still…',
  },
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

## Options

| Option | What it does |
| --- | --- |
| `kind` | `idCard` (front and back) or `passport` (one page) |
| `sides` | Capture only some sides |
| `captureMode` | `auto` or `manual` |
| `manualRequiresGoodFrame` | Keep the shutter disabled until the frame passes |
| `gate` | Thresholds, text lines needed, good frames needed |
| `measure` | Replace the frame quality measurement |
| `style` | Colors, sizes and position of the overlay |

## Comparing with the chip

`result.crossCheck()` compares the front with the MRZ read from the same
document. To compare with the chip instead, pass its data:

```dart
final check = result.crossCheck(
  expected: DocumentFields.fromMrz(chipDocument.mrz),
);
if (!check!.allFound) askForRetake(check.missing);
```

## Limits

* The cross-check is advisory. OCR misses text, so a missing field is not
  proof of forgery, and a found field is not proof of authenticity. Only
  the chip signature (Passive Authentication) proves the data.
* There is no detection of holograms, printing quality, screens or
  photocopies. A photo of a photo passes.
* The document is not located or cropped. The photo is the full camera
  frame; the frame on screen is a guide.
* The sharpness scale depends on the camera. The default thresholds are
  conservative starting points; tune `FrameQualityThresholds` on the
  devices you support.
* Names are compared as printed. A document that prints a name in another
  script, or transliterates it differently from the MRZ, reports that
  field as missing.
