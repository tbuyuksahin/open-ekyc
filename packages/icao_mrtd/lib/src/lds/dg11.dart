import 'dart:convert';
import 'dart:typed_data';

import 'package:icao_mrtd/src/errors.dart';
import 'package:icao_mrtd/src/lds/lds_file.dart';
import 'package:icao_mrtd/src/tlv.dart';
import 'package:meta/meta.dart';

/// DG11: additional personal details (ICAO 9303-10, 4.7.11).
///
/// Unlike the MRZ, DG11 stores names in full Unicode (for example Turkish
/// `Ş`, `İ`, `Ğ`) and the full date of birth. Every field is optional.
@immutable
class Dg11 {
  const Dg11._({
    this.fullName,
    this.otherNames = const [],
    this.personalNumber,
    this.fullDateOfBirth,
    this.placeOfBirth,
    this.address,
    this.telephone,
    this.profession,
    this.title,
  });

  /// Parses the raw contents of DG11.
  factory Dg11.parse(Uint8List bytes) {
    final root = Tlv.decode(bytes);
    if (root.tag != LdsFile.dg11.tag) {
      throw const LdsFormatException('DG11 must start with tag 6B');
    }
    String? text(int tag) {
      final v = root.child(tag)?.value;
      return v == null ? null : _decode(v);
    }

    final others = <String>[];
    final otherTemplate = root.child(0xA0);
    if (otherTemplate != null) {
      for (final c in otherTemplate.children) {
        if (c.tag == 0x5F0F) others.add(_decode(c.value));
      }
    }
    final dob = text(0x5F2B);
    return Dg11._(
      fullName: text(0x5F0E),
      otherNames: List.unmodifiable(others),
      personalNumber: text(0x5F10),
      fullDateOfBirth: dob == null ? null : _date(dob),
      placeOfBirth: text(0x5F11),
      address: text(0x5F42),
      telephone: text(0x5F12),
      profession: text(0x5F13),
      title: text(0x5F14),
    );
  }

  /// Full name in the `PRIMARY<<SECONDARY` form, with `<` between words.
  final String? fullName;

  /// Other names (tag 5F0F).
  final List<String> otherNames;

  /// Personal number, for example the Turkish identity number.
  final String? personalNumber;

  /// The full date of birth, if present and well formed.
  final DateTime? fullDateOfBirth;

  /// Place of birth, `<` separated.
  final String? placeOfBirth;

  /// Permanent address, `<` separated.
  final String? address;

  /// Telephone number.
  final String? telephone;

  /// Profession.
  final String? profession;

  /// Title.
  final String? title;

  /// The surname part of [fullName], with `<` replaced by spaces.
  String? get primaryIdentifier => _namePart(0);

  /// The given names part of [fullName], with `<` replaced by spaces.
  String? get secondaryIdentifier => _namePart(1);

  String? _namePart(int index) {
    final name = fullName;
    if (name == null) return null;
    final parts = name.split('<<');
    if (index >= parts.length) return '';
    return parts[index].replaceAll('<', ' ').trim();
  }

  static String _decode(Uint8List v) {
    try {
      return utf8.decode(v);
    } on FormatException {
      // Older documents use ISO 8859-1.
      return latin1.decode(v);
    }
  }

  static DateTime? _date(String s) {
    if (!RegExp(r'^\d{8}$').hasMatch(s)) return null;
    final y = int.parse(s.substring(0, 4));
    final m = int.parse(s.substring(4, 6));
    final d = int.parse(s.substring(6, 8));
    final date = DateTime(y, m, d);
    return date.month == m && date.day == d ? date : null;
  }

  @override
  String toString() => 'Dg11(<redacted>)';
}
