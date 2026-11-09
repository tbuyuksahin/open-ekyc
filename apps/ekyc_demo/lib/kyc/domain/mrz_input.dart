import 'package:icao_mrz/icao_mrz.dart';

/// Converts and validates the manual MRZ key form.
abstract final class MrzInput {
  static final _number = RegExp(r'^[A-Z0-9]{1,15}$');
  static final _date = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$');

  /// Normalizes a document number as typed (spaces, lower case).
  static String normalizeNumber(String input) =>
      input.replaceAll(RegExp(r'\s'), '').toUpperCase();

  static bool isValidNumber(String input) =>
      _number.hasMatch(normalizeNumber(input));

  /// Parses `DD.MM.YYYY`; returns `null` for impossible dates.
  static DateTime? parseDate(String input) {
    final m = _date.firstMatch(input.trim());
    if (m == null) return null;
    final d = int.parse(m[1]!);
    final mo = int.parse(m[2]!);
    final y = int.parse(m[3]!);
    final date = DateTime(y, mo, d);
    return date.year == y && date.month == mo && date.day == d ? date : null;
  }

  /// Formats a date as `DD.MM.YYYY`.
  static String formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.${date.year}';

  /// Builds the BAC key, or `null` if any field is invalid.
  static MrzKey? toKey({
    required String documentNumber,
    required DateTime? dateOfBirth,
    required DateTime? dateOfExpiry,
  }) {
    if (!isValidNumber(documentNumber) ||
        dateOfBirth == null ||
        dateOfExpiry == null) {
      return null;
    }
    return MrzKey(
      documentNumber: normalizeNumber(documentNumber),
      dateOfBirth: MrzDate.fromDateTime(dateOfBirth),
      dateOfExpiry: MrzDate.fromDateTime(dateOfExpiry),
    );
  }
}
