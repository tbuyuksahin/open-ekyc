/// Validation for the 11-digit Turkish identity number (T.C. Kimlik No).
///
/// The number is printed in the optional data of Turkish ID card MRZs and
/// stored in DG11 of the chip. Only the published checksum is verified;
/// this does not prove that the number was ever issued.
abstract final class TurkishIdentityNumber {
  /// Whether [value] has 11 digits, does not start with 0 and satisfies
  /// both checksum digits.
  static bool isValid(String value) {
    if (!RegExp(r'^[1-9]\d{10}$').hasMatch(value)) return false;
    final d = value.codeUnits.map((c) => c - 0x30).toList();
    final odd = d[0] + d[2] + d[4] + d[6] + d[8];
    final even = d[1] + d[3] + d[5] + d[7];
    final tenth = ((odd * 7 - even) % 10 + 10) % 10;
    if (d[9] != tenth) return false;
    final eleventh = d.take(10).fold(0, (a, b) => a + b) % 10;
    return d[10] == eleventh;
  }
}
