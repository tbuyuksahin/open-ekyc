import 'package:flutter/foundation.dart';
import 'package:icao_mrz/icao_mrz.dart';

/// A value printed on the document that can be compared with trusted data.
enum DocumentField {
  /// Document number.
  documentNumber,

  /// Surname.
  surname,

  /// Given names.
  givenNames,

  /// Date of birth.
  dateOfBirth,

  /// Date of expiry.
  dateOfExpiry,

  /// National or personal number.
  personalNumber,
}

/// The values the printed side is expected to show, taken from the MRZ or
/// the chip.
@immutable
class DocumentFields {
  /// Creates the expected values; leave out what you do not know.
  const DocumentFields({
    this.documentNumber,
    this.surname,
    this.givenNames,
    this.dateOfBirth,
    this.dateOfExpiry,
    this.personalNumber,
  });

  /// The values of a parsed machine readable zone.
  ///
  /// The optional data of a card is used as the personal number when it
  /// is all digits, as on Turkish identity cards.
  factory DocumentFields.fromMrz(Mrz mrz, {DateTime? now}) {
    final optional = mrz.optionalData.replaceAll('<', '').trim();
    return DocumentFields(
      documentNumber: mrz.documentNumber,
      surname: mrz.primaryIdentifier,
      givenNames: mrz.secondaryIdentifier,
      dateOfBirth: mrz.dateOfBirth.asBirthDate(now: now),
      dateOfExpiry: mrz.dateOfExpiry.asExpiryDate(now: now),
      personalNumber: _digits.hasMatch(optional) ? optional : null,
    );
  }

  static final _digits = RegExp(r'^\d{6,}$');

  /// Document number.
  final String? documentNumber;

  /// Surname.
  final String? surname;

  /// Given names, separated by spaces.
  final String? givenNames;

  /// Date of birth.
  final DateTime? dateOfBirth;

  /// Date of expiry.
  final DateTime? dateOfExpiry;

  /// National or personal number.
  final String? personalNumber;
}

/// Whether printed text agrees with trusted data, field by field.
///
/// This is advisory. OCR misses text, and a missing field is not proof of
/// forgery; a found field is not proof of authenticity either. Only the
/// chip signature proves the data. Use the result to ask for a retake or
/// to flag a case for review.
@immutable
class DocumentCrossCheck {
  /// Creates a result.
  const DocumentCrossCheck(this.fields);

  /// Looks for every value of [expected] in the lines of [printedText].
  ///
  /// Comparison ignores case, spacing, punctuation and diacritics. Numbers
  /// also tolerate the usual OCR confusions (O/0, I/1, S/5, B/8, Z/2).
  /// Fields that [expected] does not have are left out.
  factory DocumentCrossCheck.compare({
    required Iterable<String> printedText,
    required DocumentFields expected,
  }) {
    final lines = [for (final l in printedText) _fold(l)];
    final loose = [for (final l in lines) _confusable(l)];
    final words = lines.join(' ').split(' ').toSet();

    bool hasWords(String value) {
      final tokens = _fold(value).split(' ').where((t) => t.isNotEmpty);
      return tokens.isNotEmpty && tokens.every(words.contains);
    }

    bool hasCode(String value) {
      final code = _confusable(_fold(value));
      return code.isNotEmpty && loose.any((l) => l.contains(code));
    }

    bool hasDate(DateTime date) {
      final d = date.day.toString().padLeft(2, '0');
      final m = date.month.toString().padLeft(2, '0');
      final y = date.year.toString().padLeft(4, '0');
      final forms = ['$d$m$y', '$y$m$d'];
      return lines.any((l) {
        final digits = l.replaceAll(' ', '');
        return forms.any(digits.contains);
      });
    }

    final number = expected.documentNumber;
    final surname = expected.surname;
    final given = expected.givenNames;
    final birth = expected.dateOfBirth;
    final expiry = expected.dateOfExpiry;
    final personal = expected.personalNumber;
    return DocumentCrossCheck({
      if (number != null && number.isNotEmpty)
        DocumentField.documentNumber: hasCode(number),
      if (surname != null && surname.trim().isNotEmpty)
        DocumentField.surname: hasWords(surname),
      if (given != null && given.trim().isNotEmpty)
        DocumentField.givenNames: hasWords(given),
      if (birth != null) DocumentField.dateOfBirth: hasDate(birth),
      if (expiry != null) DocumentField.dateOfExpiry: hasDate(expiry),
      if (personal != null && personal.isNotEmpty)
        DocumentField.personalNumber: hasCode(personal),
    });
  }

  /// Whether each compared field was found in the printed text.
  final Map<DocumentField, bool> fields;

  /// Fields that were found.
  List<DocumentField> get found => [
    for (final e in fields.entries)
      if (e.value) e.key,
  ];

  /// Fields that were not found.
  List<DocumentField> get missing => [
    for (final e in fields.entries)
      if (!e.value) e.key,
  ];

  /// Whether at least one field was compared and all were found.
  bool get allFound => fields.isNotEmpty && missing.isEmpty;

  /// Share of compared fields that were found, 0 to 1 (0 when nothing was
  /// compared).
  double get score => fields.isEmpty ? 0 : found.length / fields.length;

  static const _letters = {
    'İ': 'I',
    'I': 'I',
    'ı': 'I',
    'Ş': 'S',
    'ş': 'S',
    'Ğ': 'G',
    'ğ': 'G',
    'Ü': 'U',
    'ü': 'U',
    'Ö': 'O',
    'ö': 'O',
    'Ç': 'C',
    'ç': 'C',
    'Á': 'A',
    'À': 'A',
    'Â': 'A',
    'Ä': 'A',
    'Ã': 'A',
    'Å': 'A',
    'á': 'A',
    'à': 'A',
    'â': 'A',
    'ä': 'A',
    'ã': 'A',
    'å': 'A',
    'É': 'E',
    'È': 'E',
    'Ê': 'E',
    'Ë': 'E',
    'é': 'E',
    'è': 'E',
    'ê': 'E',
    'ë': 'E',
    'Í': 'I',
    'Ì': 'I',
    'Î': 'I',
    'Ï': 'I',
    'í': 'I',
    'ì': 'I',
    'î': 'I',
    'ï': 'I',
    'Ó': 'O',
    'Ò': 'O',
    'Ô': 'O',
    'Õ': 'O',
    'ó': 'O',
    'ò': 'O',
    'ô': 'O',
    'õ': 'O',
    'Ú': 'U',
    'Ù': 'U',
    'Û': 'U',
    'ú': 'U',
    'ù': 'U',
    'û': 'U',
    'Ñ': 'N',
    'ñ': 'N',
  };

  static const _confusions = {
    'O': '0',
    'Q': '0',
    'D': '0',
    'I': '1',
    'L': '1',
    'S': '5',
    'B': '8',
    'Z': '2',
  };

  static final _separator = RegExp('[^A-Z0-9]+');

  // Upper case ASCII letters and digits, single spaces between words.
  static String _fold(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_letters[char] ?? char.toUpperCase());
    }
    return buffer.toString().replaceAll(_separator, ' ').trim();
  }

  static String _confusable(String folded) {
    final buffer = StringBuffer();
    for (final rune in folded.runes) {
      final char = String.fromCharCode(rune);
      if (char != ' ') buffer.write(_confusions[char] ?? char);
    }
    return buffer.toString();
  }

  @override
  String toString() =>
      'DocumentCrossCheck(found: ${found.length}/'
      '${fields.length})';
}
