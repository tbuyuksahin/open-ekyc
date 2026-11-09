# icao_mrtd

Read ICAO 9303 eMRTD chips (ePassports, eID cards) over any NFC transport,
in pure Dart.

* **BAC** and **3DES secure messaging**, verified against the ICAO 9303-11
  Appendix D worked example.
* **LDS**: EF.COM, DG1 (MRZ), DG2 (portrait, located by walking the
  ISO/IEC 19794-5 headers, JPEG and JPEG 2000), DG11 (Unicode names),
  EF.SOD.
* **Passive Authentication**: data group hashes, CMS signature, Document
  Signer → CSCA chain, validity. RSA PKCS #1 v1.5, RSA-PSS, ECDSA (named
  and explicit curves, DER and plain signatures). CSCA master lists.
* `package:icao_mrtd/testing.dart`: a virtual chip, LDS builders and a
  throw-away PKI for testing your app without hardware.

```dart
final reader = MrtdReader(myNfcTransceiver);
await reader.openSession(mrz.key);
final dg1 = await reader.readFile(LdsFile.dg1);
final sod = EfSod.parse(await reader.readFile(LdsFile.sod));
final result = verifyPassiveAuthentication(
  sod: sod,
  dataGroups: {1: dg1},
  trustStore: CscaStore(trustedCscas),
);
```

Not implemented yet: PACE, Chip/Active Authentication, CRL checks.
