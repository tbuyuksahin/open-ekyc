import 'package:icao_mrz/src/check_digit.dart';
import 'package:icao_mrz/src/mrz_date.dart';
import 'package:icao_mrz/src/mrz_key.dart';
import 'package:meta/meta.dart';

/// The three MRZ layouts defined by ICAO 9303.
enum MrzFormat {
  /// ID-1 size cards (national ID cards): 3 lines of 30 characters.
  td1(3, 30),

  /// ID-2 size documents: 2 lines of 36 characters.
  td2(2, 36),

  /// Passports: 2 lines of 44 characters.
  td3(2, 44);

  const MrzFormat(this.lineCount, this.lineLength);

  /// Number of lines in the zone.
  final int lineCount;

  /// Number of characters on each line.
  final int lineLength;

  /// The format with [lineCount] lines of [lineLength], if any.
  static MrzFormat? of(int lineCount, int lineLength) {
    for (final f in values) {
      if (f.lineCount == lineCount && f.lineLength == lineLength) return f;
    }
    return null;
  }
}

/// The holder's sex as printed in the MRZ.
enum Sex {
  /// `M`.
  male,

  /// `F`.
  female,

  /// `<` or `X`.
  unspecified,
}

/// A field of the MRZ that is protected by a check digit.
enum MrzCheckedField {
  /// The document number check digit.
  documentNumber,

  /// The date of birth check digit.
  dateOfBirth,

  /// The date of expiry check digit.
  dateOfExpiry,

  /// The personal number check digit (TD3 only).
  optionalData,

  /// The composite check digit over the whole zone.
  composite,
}

/// A parsed machine readable zone.
///
/// Parsing never fails because of a wrong check digit. Inspect [isValid]
/// and [failedChecks] before trusting the data, for example before using it
/// to open a chip session.
///
/// [toString] deliberately omits personal data so that an MRZ can be
/// logged by accident without leaking it.
@immutable
class Mrz {
  const Mrz._({
    required this.format,
    required this.lines,
    required this.documentCode,
    required this.issuingState,
    required this.documentNumber,
    required this.nationality,
    required this.dateOfBirth,
    required this.sex,
    required this.dateOfExpiry,
    required this.primaryIdentifier,
    required this.secondaryIdentifier,
    required this.optionalData,
    required this.optionalData2,
    required this.checks,
  });

  /// Parses an MRZ from a multi-line string or a list of lines.
  ///
  /// Whitespace is removed and letters are upper-cased. Throws a
  /// [FormatException] when the input is not a TD1, TD2 or TD3 zone.
  factory Mrz.parse(Object input) {
    final lines = _normalize(input);
    final format = MrzFormat.of(
      lines.length,
      lines.isEmpty ? 0 : lines.first.length,
    );
    if (format == null || lines.any((l) => l.length != format.lineLength)) {
      throw FormatException(
        'Expected 3x30 (TD1), 2x36 (TD2) or 2x44 (TD3) characters, got '
        '${lines.map((l) => l.length).join('/')}.',
      );
    }
    for (final line in lines) {
      if (!_charset.hasMatch(line)) {
        throw const FormatException('MRZ lines may only contain A-Z, 0-9, <.');
      }
    }
    return switch (format) {
      MrzFormat.td1 => Mrz._td1(lines),
      MrzFormat.td2 => Mrz._twoLine(lines, format),
      MrzFormat.td3 => Mrz._twoLine(lines, format),
    };
  }

  factory Mrz._td1(List<String> l) {
    final docField = l[0].substring(5, 14);
    final docCheck = l[0][14];
    final optional1 = l[0].substring(15, 30);
    final (number, numberOk, rest) = _documentNumber(
      docField,
      docCheck,
      optional1,
    );
    final names = _names(l[2]);
    final composite =
        l[0].substring(5, 30) +
        l[1].substring(0, 7) +
        l[1].substring(8, 15) +
        l[1].substring(18, 29);
    return Mrz._(
      format: MrzFormat.td1,
      lines: List.unmodifiable(l),
      documentCode: _strip(l[0].substring(0, 2)),
      issuingState: _strip(l[0].substring(2, 5)),
      documentNumber: number,
      nationality: _strip(l[1].substring(15, 18)),
      dateOfBirth: MrzDate(l[1].substring(0, 6)),
      sex: _sex(l[1][7]),
      dateOfExpiry: MrzDate(l[1].substring(8, 14)),
      primaryIdentifier: names.$1,
      secondaryIdentifier: names.$2,
      optionalData: _strip(rest),
      optionalData2: _strip(l[1].substring(18, 29)),
      checks: Map.unmodifiable({
        MrzCheckedField.documentNumber: numberOk,
        MrzCheckedField.dateOfBirth: verifyCheckDigit(
          l[1].substring(0, 6),
          l[1][6],
        ),
        MrzCheckedField.dateOfExpiry: verifyCheckDigit(
          l[1].substring(8, 14),
          l[1][14],
        ),
        MrzCheckedField.composite: verifyCheckDigit(composite, l[1][29]),
      }),
    );
  }

  factory Mrz._twoLine(List<String> l, MrzFormat format) {
    final td3 = format == MrzFormat.td3;
    final optionalEnd = td3 ? 42 : 35;
    final optional = l[1].substring(28, optionalEnd);
    final (number, numberOk, rest) = td3
        ? (_strip(l[1].substring(0, 9)), _check(l[1], 0, 9), optional)
        : _documentNumber(l[1].substring(0, 9), l[1][9], optional);
    final names = _names(l[0].substring(5));
    final composite =
        l[1].substring(0, 10) +
        l[1].substring(13, 20) +
        l[1].substring(21, td3 ? 43 : 35);
    return Mrz._(
      format: format,
      lines: List.unmodifiable(l),
      documentCode: _strip(l[0].substring(0, 2)),
      issuingState: _strip(l[0].substring(2, 5)),
      documentNumber: number,
      nationality: _strip(l[1].substring(10, 13)),
      dateOfBirth: MrzDate(l[1].substring(13, 19)),
      sex: _sex(l[1][20]),
      dateOfExpiry: MrzDate(l[1].substring(21, 27)),
      primaryIdentifier: names.$1,
      secondaryIdentifier: names.$2,
      optionalData: _strip(rest),
      optionalData2: '',
      checks: Map.unmodifiable({
        MrzCheckedField.documentNumber: numberOk,
        MrzCheckedField.dateOfBirth: _check(l[1], 13, 19),
        MrzCheckedField.dateOfExpiry: _check(l[1], 21, 27),
        if (td3)
          MrzCheckedField.optionalData: verifyCheckDigit(
            optional,
            l[1][42],
            allowFiller: true,
          ),
        MrzCheckedField.composite: verifyCheckDigit(
          composite,
          l[1][format.lineLength - 1],
        ),
      }),
    );
  }

  /// Like [Mrz.parse], but returns `null` instead of throwing.
  static Mrz? tryParse(Object input) {
    try {
      return Mrz.parse(input);
    } on FormatException {
      return null;
    }
  }

  /// The layout of the zone.
  final MrzFormat format;

  /// The normalized lines.
  final List<String> lines;

  /// Document code without fillers, for example `P`, `I` or `ID`.
  final String documentCode;

  /// Three-letter code of the issuing state or organization.
  final String issuingState;

  /// The document number without fillers, including any digits that
  /// overflow into the optional data field.
  final String documentNumber;

  /// Three-letter nationality code.
  final String nationality;

  /// Date of birth.
  final MrzDate dateOfBirth;

  /// Sex.
  final Sex sex;

  /// Date of expiry.
  final MrzDate dateOfExpiry;

  /// Primary identifier (surname), with `<` replaced by spaces.
  final String primaryIdentifier;

  /// Secondary identifier (given names), with `<` replaced by spaces.
  final String secondaryIdentifier;

  /// The personal number (TD3) or first optional data field (TD1, TD2),
  /// without fillers.
  final String optionalData;

  /// The second optional data field (TD1 only), without fillers.
  final String optionalData2;

  /// The result of every check digit present in this format.
  final Map<MrzCheckedField, bool> checks;

  /// Whether every check digit is correct.
  bool get isValid => checks.values.every((ok) => ok);

  /// The fields whose check digit is wrong.
  List<MrzCheckedField> get failedChecks => [
    for (final e in checks.entries)
      if (!e.value) e.key,
  ];

  /// The key material for Basic Access Control.
  MrzKey get key => MrzKey(
    documentNumber: documentNumber,
    dateOfBirth: dateOfBirth,
    dateOfExpiry: dateOfExpiry,
  );

  @override
  String toString() => 'Mrz(${format.name}, valid: $isValid)';

  static final _charset = RegExp(r'^[A-Z0-9<]+$');

  static List<String> _normalize(Object input) {
    final raw = switch (input) {
      final String s => s.split(RegExp(r'\r?\n')),
      final List<String> l => l,
      _ => throw ArgumentError.value(input, 'input', 'String or List<String>'),
    };
    return [
      for (final l in raw)
        if (l.trim().isNotEmpty) l.replaceAll(RegExp(r'\s'), '').toUpperCase(),
    ];
  }

  static bool _check(String line, int start, int end) =>
      verifyCheckDigit(line.substring(start, end), line[end]);

  /// Resolves document numbers longer than nine characters, which ICAO
  /// continues in the optional data field after a `<` check digit.
  static (String, bool, String) _documentNumber(
    String field,
    String check,
    String optional,
  ) {
    if (check != '<' || optional.isEmpty || optional[0] == '<') {
      return (_strip(field), verifyCheckDigit(field, check), optional);
    }
    final end = optional.indexOf('<');
    final overflow = end == -1 ? optional : optional.substring(0, end);
    if (overflow.length < 2) {
      return (_strip(field), false, optional);
    }
    final number = field + overflow.substring(0, overflow.length - 1);
    final ok = verifyCheckDigit(number, overflow[overflow.length - 1]);
    final rest = end == -1 ? '' : optional.substring(end);
    return (number, ok, rest);
  }

  static (String, String) _names(String field) {
    final trimmed = field.replaceFirst(RegExp(r'<+$'), '');
    final split = trimmed.indexOf('<<');
    String clean(String s) =>
        s.replaceAll('<', ' ').replaceAll(RegExp(' +'), ' ').trim();
    if (split == -1) return (clean(trimmed), '');
    return (
      clean(trimmed.substring(0, split)),
      clean(trimmed.substring(split + 2)),
    );
  }

  static String _strip(String s) =>
      s.replaceAll('<', ' ').trim().replaceAll(' ', '<');

  static Sex _sex(String c) => switch (c) {
    'M' => Sex.male,
    'F' => Sex.female,
    _ => Sex.unspecified,
  };
}
