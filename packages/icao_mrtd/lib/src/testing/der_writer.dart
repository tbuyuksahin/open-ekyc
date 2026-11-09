import 'dart:convert';
import 'dart:typed_data';

import 'package:icao_mrtd/src/pa/der.dart';
import 'package:icao_mrtd/src/tlv.dart';

/// Minimal DER encoders used to build test certificates and EF.SOD files.
abstract final class Der {
  /// SEQUENCE of [items].
  static Uint8List seq(List<List<int>> items) =>
      encodeTlv(DerTag.sequence, items.expand((e) => e).toList());

  /// SET of [items], sorted as DER requires.
  static Uint8List set(List<List<int>> items) {
    final sorted = [...items]..sort(_compare);
    return encodeTlv(DerTag.set, sorted.expand((e) => e).toList());
  }

  static int _compare(List<int> a, List<int> b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) return a[i] - b[i];
    }
    return a.length - b.length;
  }

  /// INTEGER.
  static Uint8List integer(BigInt value) {
    var bytes = bigIntToBytes(value);
    if (bytes.isEmpty) bytes = Uint8List(1);
    if (bytes[0] & 0x80 != 0) bytes = Uint8List.fromList([0, ...bytes]);
    return encodeTlv(DerTag.integer, bytes);
  }

  /// INTEGER from a small value.
  static Uint8List smallInt(int value) => integer(BigInt.from(value));

  /// OBJECT IDENTIFIER from dotted form.
  static Uint8List oid(String dotted) {
    final parts = dotted.split('.').map(int.parse).toList();
    final out = <int>[parts[0] * 40 + parts[1]];
    for (final p in parts.skip(2)) {
      final chunk = <int>[p & 0x7F];
      for (var v = p >> 7; v > 0; v >>= 7) {
        chunk.insert(0, 0x80 | (v & 0x7F));
      }
      out.addAll(chunk);
    }
    return encodeTlv(DerTag.oid, out);
  }

  /// OCTET STRING.
  static Uint8List octets(List<int> value) =>
      encodeTlv(DerTag.octetString, value);

  /// BIT STRING without unused bits.
  static Uint8List bits(List<int> value) =>
      encodeTlv(DerTag.bitString, [0, ...value]);

  /// NULL.
  static Uint8List get nullValue => encodeTlv(DerTag.nullValue, const []);

  /// PrintableString.
  static Uint8List printable(String s) =>
      encodeTlv(DerTag.printableString, ascii.encode(s));

  /// UTF8String.
  static Uint8List utf8String(String s) =>
      encodeTlv(DerTag.utf8String, utf8.encode(s));

  /// UTCTime.
  static Uint8List utcTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    final u = t.toUtc();
    return encodeTlv(
      DerTag.utcTime,
      ascii.encode(
        '${two(u.year % 100)}${two(u.month)}${two(u.day)}'
        '${two(u.hour)}${two(u.minute)}${two(u.second)}Z',
      ),
    );
  }

  /// Context-specific constructed `[n]` wrapping [content].
  static Uint8List explicit(int n, List<int> content) =>
      encodeTlv(DerTag.context(n), content);

  /// AlgorithmIdentifier.
  static Uint8List algorithm(String oid, [List<int>? params]) =>
      seq([Der.oid(oid), ?params]);

  /// A Name with country and common name.
  static Uint8List name({required String country, required String cn}) => seq([
    set([
      seq([oid('2.5.4.6'), printable(country)]),
    ]),
    set([
      seq([oid('2.5.4.3'), utf8String(cn)]),
    ]),
  ]);
}
