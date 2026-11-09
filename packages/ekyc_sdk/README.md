# ekyc_sdk

Drop-in identity verification for Flutter. One call runs the MRZ scan, the
NFC chip read (with Passive Authentication) and the selfie, or any single
step. English and Turkish texts are built in, and every overlay can be
themed.

```dart
final result = await Ekyc.start(context);
if (result != null) {
  await upload(result.document!.rawFiles, result.selfie!);
  result.wipe(); // erase the chip data and the selfie from memory
}
```

## Pick the level you need

| Level | API | What the user sees |
| --- | --- | --- |
| Whole flow | `Ekyc.start(context, config: ...)` | The SDK's screens for every step in `config.steps` |
| One step | `Ekyc.scanMrz`, `Ekyc.readChip`, `Ekyc.captureSelfie` | The SDK's screen for that step only |
| Embedded flow | `EkycFlow(onCompleted: ...)` | The same screens inside your own page or navigator |
| One screen | `EkycMrzScreen`, `EkycNfcScreen`, `EkycFaceScreen` | A step screen that you drive with your own state |
| Bare widgets | `MrzScanner`, `ManualMrzForm`, `NfcScanOverlay`, `ChipReader`, `FaceCapture` | Only the camera area or illustration, inside your own layout |

The SDK re-exports the step packages, so one import covers every level.

## Single steps

```dart
// Only the MRZ: the key that opens the chip, from the camera or the form.
final MrzKey? key = await Ekyc.scanMrz(context);

// Only NFC, with a key you already have.
final DocumentData? document = await Ekyc.readChip(context, mrzKey: key!);

// Only the selfie.
final EkycResult? selfie = await Ekyc.captureSelfie(context);
```

Each call returns `null` when the user closes the screen.

## Configuration

```dart
await Ekyc.start(
  context,
  config: EkycConfig(
    steps: const [EkycStep.mrz, EkycStep.nfc, EkycStep.face],
    trustStore: CscaStore.fromMasterList(masterListBytes),
    theme: EkycTheme.brand(primary: Colors.indigo),
    strings: EkycStrings.tr.copyWith(mrzTitle: 'Kimlik bilgileri'),
    face: const EkycFaceOptions(
      challenges: FaceChallenge.values,
      challengeCount: 3,
      captureMode: FaceCaptureMode.auto,
      allowModeSwitch: true,
    ),
  ),
);
```

* **`steps`** selects the steps to run. NFC without the MRZ step needs
  `mrzKey`.
* **`strings`** defaults to the built-in texts for the app's locale
  (Turkish for `tr`, English otherwise). Use `copyWith` to change single
  texts, or pass your own `EkycStrings` for another language.
* **`theme`** holds one overlay style per step. `EkycTheme.brand` sets
  your colors on all three.
* **`trustStore`** holds the CSCA certificates. Without it a genuine chip
  is reported as `untrusted`, not `verified`.
* **`nfcSession`** is the NFC transport. Pass a `VirtualNfcSession` from
  `package:ekyc_nfc_reader/testing.dart` to run the flow in tests or demos
  without hardware.
* **`liveness`** plugs in a certified liveness provider.

## The result

`EkycResult` has the `mrzKey`, the `document` (parsed data, the on-device
Passive Authentication result and the raw chip files), the `selfie`, the
completed `challenges` and the `liveness` outcome.

* Send `document.rawFiles` to your server and repeat Passive
  Authentication there. The check on the device is advisory, because a
  modified app can lie.
* Completed movements are reported as `challengesPassed`, never as
  `live`.
* Call `wipe()` when you are done. If the user cancels, or the flow is
  removed before it completes, the SDK wipes what it collected.

## What it leaves to your app

Consent, your backend calls and the final decision screen are yours. See
`apps/ekyc_demo` for an app that adds those around the SDK screens.
