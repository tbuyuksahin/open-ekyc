# ekyc_nfc_reader

The NFC step of an e-KYC flow in Flutter. It reads an ePassport or eID
chip and verifies that the issuing state signed the data.

* `ChipReader` runs the whole read:
  * BAC with the MRZ key.
  * Reads EF.COM, DG1, DG2 (portrait), DG11 (optional) and EF.SOD.
  * Runs Passive Authentication against your CSCA store.
  * Reports progress through each step.
  * Every failure becomes one actionable `ChipReadError` (wrong MRZ,
    card moved, timeout, NFC off, not authentic…).
* `FlutterNfcSession` connects to the card through `flutter_nfc_kit`
  (Android IsoDep, iOS NFCTagReaderSession, polling NFC-A and NFC-B).
* `NfcScanOverlay` is an animated illustration: the document moves to the
  antenna on the back of the phone with radio waves. A progress ring
  follows the read, then shows success or error.
* `DocumentData` keeps the raw chip files for server-side verification
  and has a `wipe()` method.
* `package:ekyc_nfc_reader/testing.dart` provides `VirtualNfcSession`,
  which runs the full read against a virtual chip in tests or demos.

```dart
final reader = ChipReader(
  session: const FlutterNfcSession(),
  trustStore: CscaStore.fromMasterList(masterListBytes),
);
try {
  final document = await reader.read(
    mrz.key,
    onProgress: (step, fraction) =>
        setState(() => (_step, _progress) = (step, fraction)),
  );
} on ChipReadException catch (e) {
  showError(e.error); // e.error.isRetryable tells you whether to offer retry
}

NfcScanOverlay(
  status: NfcScanStatus.of(_step, failed: _error != null),
  progress: _progress,
  semanticLabel: 'Hold the document over the antenna',
  style: const NfcOverlayStyle(
    document: NfcDocumentKind.card,          // or passport
    antennaAlignment: Alignment(0, -0.45),   // where the antenna is
    accentColor: Colors.indigo,
    successColor: Colors.green,
    height: 240,
  ),
)
```

## Antenna position

NFC antennas sit in different places on different phones. Usually they
are in the upper half, around the cameras. Change `antennaAlignment` if
your users' devices differ, and say where to hold the document in the text
next to the overlay.

## What it does not do (yet)

It has no PACE, Chip or Active Authentication and no certificate
revocation checks. Passive Authentication on the device is advisory only:
send `DocumentData.rawFiles` to your server and verify there.
