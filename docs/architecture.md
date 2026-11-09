# Architecture

```text
apps/ekyc_demo
 ├─ kyc/flow      KycFlowCubit: a state machine, one state per screen
 │                Consent → Mrz → Chip(progress) / ChipError → Face → Review → Result
 ├─ kyc/domain    ChipReader, DocumentData, FaceQualityGate, LivenessCheck,
 │                KycRepository, NfcSession (interfaces + pure logic)
 ├─ kyc/data      FlutterNfcSession, FakeKycRepository, DemoDocument, CSCA loader
 ├─ kyc/camera    ML Kit MRZ scanner and face capture (thin, platform-bound)
 └─ kyc/ui        Widgets; no business logic
packages/icao_mrtd  ApduTransceiver ← MrtdReader (BAC + SM) → LDS parsers → Passive Authentication
packages/icao_mrz   MRZ parsing, check digits, OCR recovery, BAC key input
```

## Principles

* **Platform at the edges.** NFC, camera and ML Kit sit behind small
  interfaces (`ApduTransceiver`, `NfcSession`, `FaceObservation`), so the
  protocol, verification and flow are tested without devices.
* **Two independent implementations meet in tests.** The reader is checked
  against the ICAO 9303 worked example and against `VirtualMrtd`, whose
  chip-side protocol is written separately.
* **Errors are mapped once.** Every exception becomes a `KycError` in
  `ChipReader` and the UI only translates that enum.
* **Personal data has an owner.** `KycFlowCubit` owns `DocumentData` and
  the selfie and wipes them on every exit path.

## Adding a real backend

Implement `KycRepository`:

1. `startSession` → your server returns a session id and a short-lived token.
2. `submit` → POST `KycSubmission.toJson()` with the token in the
   `Authorization` header.
3. On the server, run Passive Authentication on `chip.sod` and the data
   groups against your CSCA list, then face matching and liveness.
