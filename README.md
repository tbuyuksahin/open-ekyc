# open-ekyc

**English** | [Türkçe](README.tr.md)

A reference implementation of mobile identity verification (e-KYC) in
Flutter: scan the MRZ, read the passport or ID card chip over NFC, prove
the chip data was signed by the issuing state, and capture a selfie.

Everything is written from the public ICAO Doc 9303 standard, in pure Dart
where possible, and tested without hardware against a virtual chip.

| Package | What it does |
| --- | --- |
| [`icao_mrz`](packages/icao_mrz) | Parse and validate TD1/TD2/TD3 MRZs, recover them from noisy OCR, build the BAC key. Pure Dart, no dependencies. |
| [`icao_mrtd`](packages/icao_mrtd) | BAC, 3DES secure messaging, LDS files (COM, DG1, DG2, DG11, SOD) and **Passive Authentication** (RSA, RSA-PSS, ECDSA incl. explicit curves). Transport-agnostic, pure Dart. |
| [`ekyc_demo`](apps/ekyc_demo) | The Flutter app: consent → MRZ (camera or manual) → NFC → selfie → review → submit, with a demo mode that runs the whole flow on a virtual specimen document. |

## Why it exists

Most e-KYC code reads the chip and then sends **parsed JSON** to the
server. That throws away the only thing that makes NFC worth it: the
issuing state's signature. A modified client can then claim any identity.

This project keeps the chain intact:

```text
chip ──BAC/SM──▶ raw DG1, DG2, DG11, SOD ──▶ on-device Passive Authentication (advisory)
                                        └──▶ server re-verifies the same raw files (authoritative)
```

## Try it

```sh
flutter pub get
cd apps/ekyc_demo
flutter run            # tap "Try with a sample document" for the demo mode
```

Demo mode needs no camera, NFC or personal data: it uses the fictitious
ICAO specimen (Utopia) on a virtual chip, signed by a throw-away CSCA.

## Quality gates

* `dart analyze --fatal-infos` with `very_good_analysis` and strict
  casts/inference/raw types; `avoid_print` is an error.
* 100 tests: ICAO 9303-11 Appendix D vectors for every BAC and secure
  messaging step, a virtual chip for the full read path (wrong key, lost
  tag, forged MAC), real signatures for Passive Authentication (tampered
  data, wrong CSCA, expired certificates), the flow state machine and an
  end-to-end widget test of the demo flow.
* Coverage ≥ 90 % enforced in CI (currently 96 % / 95 %).
* CI builds a release AAB and an iOS app and runs
  [`preflight`](https://pub.dev/packages/preflight) against both.

## Security and privacy

See [SECURITY.md](SECURITY.md) for the threat model. In short:

* Personal data stays in memory, is never logged (enforced by lint and an
  event-only logger), and is wiped on submit, cancel or app close.
* Android: `FLAG_SECURE`, backups disabled. iOS: content hidden in the app
  switcher. No network permission in release builds of the demo.
* Clearly stated gaps: no liveness detection (interface only), no PACE,
  no certificate revocation checks, fake backend.

## Docs

* [Architecture](docs/architecture.md)
* [Security and threat model](SECURITY.md)

## License

MIT. ICAO specimen data is fictitious. No code, assets or APIs of any
employer or third-party KYC product are used.
