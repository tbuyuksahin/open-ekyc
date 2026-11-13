# Architecture

```text
apps/ekyc_demo            Example host: consent, review and submission around the SDK screens
 ├─ kyc/flow              KycFlowCubit: a state machine, one state per screen
 │                        Consent → Mrz → Chip(progress) / ChipError → Face → Review → Result
 ├─ kyc/domain            KycError, KycRepository, masking
 ├─ kyc/data              FakeKycRepository, DemoDocument, CSCA loader
 └─ kyc/ui                Consent, review and result screens; SDK screens for the steps

packages/ekyc_sdk           Ekyc.start / captureDocument / scanMrz / readChip / captureSelfie, EkycFlow,
                            EkycFlowController, step screens, EkycStrings (EN/TR), EkycTheme
packages/ekyc_mrz_scanner   MrzScanner, MrzOverlay(+Style), ManualMrzForm, MrzInput
packages/ekyc_nfc_reader    ChipReader, NfcSession, FlutterNfcSession, DocumentData,
                            NfcScanOverlay(+Style), testing: VirtualNfcSession
packages/ekyc_document_capture  DocumentCapture, FrameAnalyzer, DocumentQualityGate,
                            DocumentOverlay(+Style), DocumentCrossCheck
packages/ekyc_face_capture  FaceCapture, FaceQualityGate, FaceOverlay(+Style), LivenessCheck
packages/ekyc_camera        MlKitCamera, MlKitCameraView, ScrimPainter, ShutterButton,
                            testing: FakeCameraPlatform
packages/icao_mrtd          ApduTransceiver ← MrtdReader (BAC + SM) → LDS parsers → Passive Authentication
packages/icao_mrz           MRZ parsing, check digits, OCR recovery, BAC key input
```

```text
ekyc_demo ──▶ ekyc_sdk ──▶ ekyc_mrz_scanner ──▶ ekyc_camera, icao_mrz
                      ├──▶ ekyc_nfc_reader  ──▶ icao_mrtd ──▶ icao_mrz
                      ├──▶ ekyc_document_capture ──▶ ekyc_camera, icao_mrz
                      └──▶ ekyc_face_capture ─▶ ekyc_camera
```

Most apps depend on `ekyc_sdk` and call `Ekyc.start`. Each step package
can also be used on its own: a host app that only needs NFC reading
depends on `ekyc_nfc_reader` alone. Step packages never log,
never localize and never navigate. They take texts and styles as
parameters and report results through callbacks or exceptions, so the
host decides what to log, translate and show next.

## Principles

* **Platform at the edges.** NFC, camera and ML Kit sit behind small
  interfaces (`ApduTransceiver`, `NfcSession`, `FaceObservation`,
  `MlKitCamera`), so the protocol, verification, overlays and flow are
  tested without devices.
* **Two independent implementations meet in tests.** The reader is checked
  against the ICAO 9303 worked example and against `VirtualMrtd`, whose
  chip-side protocol is written separately.
* **Errors are mapped once.** Every chip exception becomes a
  `ChipReadError` in `ChipReader`; the app maps it to its own `KycError`
  and the UI only translates that enum.
* **Personal data has an owner.** `KycFlowCubit` owns `DocumentData` and
  the selfie and wipes them on every exit path.

## Adding a real backend

Implement `KycRepository`:

1. `startSession` → your server returns a session id and a short-lived token.
2. `submit` → POST `KycSubmission.toJson()` with the token in the
   `Authorization` header.
3. On the server, run Passive Authentication on `chip.sod` and the data
   groups against your CSCA list, then face matching and liveness.
