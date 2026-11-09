# icao_mrz

Parse and validate ICAO 9303 machine readable zones in pure Dart.

* TD1 (ID cards), TD2 and TD3 (passports), including document numbers
  longer than nine characters.
* Every check digit is verified and reported per field.
* `MrzRecognizer` finds an MRZ in noisy OCR text and repairs common
  confusions (`0`/`O`, `1`/`I`, `«`) by position, accepting only results
  whose check digits all pass.
* `MrzKey` builds the BAC/PACE key input.
* `TurkishIdentityNumber` validates T.C. Kimlik No checksums.
* `toString()` never prints personal data.

```dart
final mrz = Mrz.parse([
  'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<',
  'L898902C36UTO7408122F1204159ZE184226B<<<<<10',
]);
mrz.isValid;            // true
mrz.dateOfBirth.asBirthDate(); // 1974-08-12
mrz.key.information;    // BAC input
```
