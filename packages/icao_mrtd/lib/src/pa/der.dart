import 'dart:typed_data';

import 'package:icao_mrtd/src/errors.dart';
import 'package:icao_mrtd/src/tlv.dart';

/// DER universal tags used by X.509 and CMS.
abstract final class DerTag {
  /// BOOLEAN.
  static const boolean = 0x01;

  /// INTEGER.
  static const integer = 0x02;

  /// BIT STRING.
  static const bitString = 0x03;

  /// OCTET STRING.
  static const octetString = 0x04;

  /// NULL.
  static const nullValue = 0x05;

  /// OBJECT IDENTIFIER.
  static const oid = 0x06;

  /// UTF8String.
  static const utf8String = 0x0C;

  /// PrintableString.
  static const printableString = 0x13;

  /// UTCTime.
  static const utcTime = 0x17;

  /// GeneralizedTime.
  static const generalizedTime = 0x18;

  /// SEQUENCE.
  static const sequence = 0x30;

  /// SET.
  static const set = 0x31;

  /// Context-specific constructed tag `[n]`.
  static int context(int n) => 0xA0 | n;
}

/// Throws an [LdsFormatException] unless [tlv] has [tag].
Tlv expectTag(Tlv tlv, int tag, String what) {
  if (tlv.tag != tag) {
    throw LdsFormatException(
      '$what: expected tag ${tag.toRadixString(16)}, '
      'got ${tlv.tag.toRadixString(16)}',
    );
  }
  return tlv;
}

/// Decodes an OBJECT IDENTIFIER value into dotted form.
String decodeOid(Tlv tlv) {
  final v = expectTag(tlv, DerTag.oid, 'OID').value;
  if (v.isEmpty) throw const LdsFormatException('Empty OID');
  final parts = <int>[];
  var value = 0;
  for (final b in v) {
    value = (value << 7) | (b & 0x7F);
    if (b & 0x80 == 0) {
      parts.add(value);
      value = 0;
    }
  }
  final first = parts.first;
  final head = first < 80 ? [first ~/ 40, first % 40] : [2, first - 80];
  return [...head, ...parts.skip(1)].join('.');
}

/// Decodes a non-negative INTEGER.
BigInt decodeInteger(Tlv tlv) {
  final v = expectTag(tlv, DerTag.integer, 'INTEGER').value;
  var result = BigInt.zero;
  for (final b in v) {
    result = (result << 8) | BigInt.from(b);
  }
  return result;
}

/// Converts [value] to an unsigned big-endian byte array.
Uint8List bigIntToBytes(BigInt value, [int length = 0]) {
  var hex = value.toRadixString(16);
  if (hex.length.isOdd) hex = '0$hex';
  final bytes = [
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ];
  while (bytes.length < length) {
    bytes.insert(0, 0);
  }
  return Uint8List.fromList(bytes);
}

/// Decodes unsigned big-endian bytes.
BigInt bytesToBigInt(List<int> bytes) {
  var result = BigInt.zero;
  for (final b in bytes) {
    result = (result << 8) | BigInt.from(b);
  }
  return result;
}

/// Returns the content of a BIT STRING with no unused bits.
Uint8List decodeBitString(Tlv tlv) {
  final v = expectTag(tlv, DerTag.bitString, 'BIT STRING').value;
  if (v.isEmpty || v[0] != 0) {
    throw const LdsFormatException('Unsupported BIT STRING padding');
  }
  return Uint8List.sublistView(v, 1);
}

/// Decodes a UTCTime or GeneralizedTime in UTC (`Z`) form.
DateTime decodeTime(Tlv tlv) {
  final s = String.fromCharCodes(tlv.value);
  final match = switch (tlv.tag) {
    DerTag.utcTime => RegExp(r'^(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?Z$'),
    DerTag.generalizedTime => RegExp(
      r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?Z$',
    ),
    _ => throw const LdsFormatException('Expected UTCTime or GeneralizedTime'),
  }.firstMatch(s);
  if (match == null) throw const LdsFormatException('Malformed time value');
  var year = int.parse(match[1]!);
  if (tlv.tag == DerTag.utcTime) year += year < 50 ? 2000 : 1900;
  return DateTime.utc(
    year,
    int.parse(match[2]!),
    int.parse(match[3]!),
    int.parse(match[4]!),
    int.parse(match[5]!),
    int.parse(match[6] ?? '0'),
  );
}
