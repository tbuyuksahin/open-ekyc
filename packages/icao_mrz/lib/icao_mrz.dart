/// Parse and validate ICAO 9303 machine readable zones.
///
/// ```dart
/// final mrz = Mrz.parse(lines);
/// if (mrz.isValid) print(mrz.documentNumber);
/// ```
library;

export 'src/check_digit.dart' show checkDigit, mrzCharValue;
export 'src/mrz.dart';
export 'src/mrz_date.dart';
export 'src/mrz_key.dart';
export 'src/mrz_recognizer.dart';
export 'src/turkish_identity_number.dart';
