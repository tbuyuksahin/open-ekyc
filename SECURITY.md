# Security and threat model

This is a reference implementation. Read this before using any part of it
for real identity verification.

## Assets

* Personal data from the chip (name, date of birth, document number) and
  the portrait (biometric, special category data under KVKK art. 6 and
  GDPR art. 9).
* The selfie.
* The photos of the document and the text recognized on them.
* The MRZ key, which unlocks the chip.

## What is protected, and how

| Threat | Mitigation | Where |
| --- | --- | --- |
| Forged or altered chip data | Passive Authentication: DG hashes, DS signature, CSCA chain | `icao_mrtd` `verifyPassiveAuthentication` |
| Modified client sends fake identity | The app sends **raw** LDS files; the server must repeat Passive Authentication. The client result is advisory | `KycSubmission` |
| Eavesdropping on NFC | BAC + 3DES secure messaging; every response MAC verified in constant time; session closed on any SM error | `SecureMessaging`, `MrtdReader` |
| Data leaking into logs and crash reports | No `print` (lint error); `AppLog` accepts only primitive event fields; exception and `toString()` texts are redacted | `AppLog`, `Mrz`, `MrzKey`, `Dg11`, `DocumentData` |
| Data left on the device | Memory only; byte buffers (chip files, document photos, selfie) wiped on submit, cancel, retake and close; camera temp file deleted at once; camera released in the background; Android backups and device transfer disabled | `KycFlowCubit`, `MlKitCamera.takePicture`, `data_extraction_rules.xml` |
| Shoulder surfing / screenshots | Document number masked on review; Android `FLAG_SECURE`; iOS snapshot shield | `maskMiddle`, `MainActivity`, `PrivacyShield` |
| Replay of a verification session | Server-issued, short-lived session token sent with each submission | `VerificationSession` |

## Known gaps (not implemented)

* **Liveness / presentation attack detection.** `LivenessCheck` is an
  interface; the demo reports "not performed". Do not ship face matching
  without an ISO/IEC 30107-3 tested solution.
* **Face matching** is the server's job and is not part of this repository.
* **PACE**, **Chip Authentication** and **Active Authentication** are not
  implemented, so cloned chips (same data, copied signature) are not
  detected. Passive Authentication alone proves integrity, not that the
  chip is genuine.
* **Document photos are not authenticated.** The document photo step
  checks light, glare, sharpness and which side is shown, and compares the
  printed text with the chip. It does not detect holograms, printing
  quality, screens or photocopies, so a photo of a photo passes. The
  cross-check is advisory because OCR misses text.
* **Certificate revocation** (CRLs) is not checked.
* **Trust anchors** are not bundled. Without CSCA certificates the result is
  "untrusted". The server must hold the authoritative list.
* The **backend** is a fake that runs in-process.
* Dart strings cannot be wiped; names remain in memory until garbage
  collected.

## Reporting

Please open a private security advisory on GitHub rather than a public
issue.
