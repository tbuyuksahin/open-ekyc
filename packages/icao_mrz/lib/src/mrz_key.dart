import 'package:icao_mrz/src/check_digit.dart';
import 'package:icao_mrz/src/mrz_date.dart';
import 'package:meta/meta.dart';

/// The three MRZ fields that seed Basic Access Control (BAC) and the MRZ
/// variant of PACE (ICAO 9303 Part 11, 4.3).
@immutable
class MrzKey {
  /// Creates a key from the document number and the two dates.
  ///
  /// Throws an [ArgumentError] if the document number is empty or contains
  /// characters outside `A-Z0-9<`, or if a date is not well formed.
  MrzKey({
    required String documentNumber,
    required this.dateOfBirth,
    required this.dateOfExpiry,
  }) : documentNumber = documentNumber.toUpperCase() {
    if (!RegExp(r'^[A-Z0-9<]+$').hasMatch(this.documentNumber)) {
      throw ArgumentError.value(
        '<redacted>',
        'documentNumber',
        'must be non-empty and use only A-Z, 0-9 and <',
      );
    }
    if (!dateOfBirth.isWellFormed) {
      throw ArgumentError.value('<redacted>', 'dateOfBirth', 'not YYMMDD');
    }
    if (!dateOfExpiry.isWellFormed) {
      throw ArgumentError.value('<redacted>', 'dateOfExpiry', 'not YYMMDD');
    }
  }

  /// The document number, without trailing fillers.
  final String documentNumber;

  /// The date of birth.
  final MrzDate dateOfBirth;

  /// The date of expiry.
  final MrzDate dateOfExpiry;

  /// The `MRZ_information` string: document number (padded to nine
  /// characters), date of birth and date of expiry, each followed by its
  /// check digit.
  String get information {
    final number = documentNumber.padRight(9, '<');
    String withCheck(String v) => '$v${checkDigit(v)}';
    return withCheck(number) +
        withCheck(dateOfBirth.raw) +
        withCheck(dateOfExpiry.raw);
  }

  @override
  bool operator ==(Object other) =>
      other is MrzKey &&
      other.documentNumber == documentNumber &&
      other.dateOfBirth == dateOfBirth &&
      other.dateOfExpiry == dateOfExpiry;

  @override
  int get hashCode => Object.hash(documentNumber, dateOfBirth, dateOfExpiry);

  @override
  String toString() => 'MrzKey(<redacted>)';
}
