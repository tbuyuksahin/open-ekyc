const _weights = [7, 3, 1];

/// The numeric value of an MRZ character, as defined in ICAO 9303 Part 3.
///
/// Digits map to themselves, `A`–`Z` to 10–35 and the filler `<` to 0.
/// Throws a [FormatException] for any other character.
int mrzCharValue(int codeUnit) {
  if (codeUnit >= 0x30 && codeUnit <= 0x39) return codeUnit - 0x30;
  if (codeUnit >= 0x41 && codeUnit <= 0x5A) return codeUnit - 0x41 + 10;
  if (codeUnit == 0x3C) return 0;
  throw FormatException(
    'Not an MRZ character: ${String.fromCharCode(codeUnit)}',
  );
}

/// Computes the ICAO 9303 check digit (weights 7, 3, 1, modulo 10) of
/// [value].
int checkDigit(String value) {
  var sum = 0;
  for (var i = 0; i < value.length; i++) {
    sum += mrzCharValue(value.codeUnitAt(i)) * _weights[i % 3];
  }
  return sum % 10;
}

/// Whether [digit] is the correct check digit for [value].
///
/// A `<` digit is accepted only when [allowFiller] is set and [value]
/// consists solely of fillers, as ICAO allows for empty optional data.
bool verifyCheckDigit(String value, String digit, {bool allowFiller = false}) {
  if (digit == '<') {
    return allowFiller && value.split('').every((c) => c == '<');
  }
  final parsed = int.tryParse(digit);
  return parsed != null && parsed == checkDigit(value);
}
