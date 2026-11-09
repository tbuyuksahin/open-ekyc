import 'dart:typed_data';

import 'package:icao_mrtd/icao_mrtd.dart';
import 'package:test/test.dart';

import 'hex.dart';

void main() {
  test('decodes multi-byte tags and long lengths', () {
    final value = List.filled(300, 0xAB);
    final encoded = encodeTlv(0x5F1F, value);
    expect(toHex(encoded.sublist(0, 5)), '5F1F82012C');
    final tlv = Tlv.decode(encoded);
    expect(tlv.tag, 0x5F1F);
    expect(tlv.value, value);
    expect(tlv.isConstructed, isFalse);
    expect(Tlv.encodedLength(encoded.sublist(0, 6)), encoded.length);
  });

  test('walks constructed objects', () {
    final tlv = Tlv.decode(
      encodeTlv(0x7F61, [
        ...encodeTlv(0x02, [1]),
        ...encodeTlv(0x80, [7]),
      ]),
    );
    expect(tlv.isConstructed, isTrue);
    expect(tlv.children.map((c) => c.tag), [0x02, 0x80]);
    expect(tlv.child(0x80)!.value, [7]);
    expect(tlv.child(0x99), isNull);
    expect(() => tlv.require(0x99), throwsA(isA<LdsFormatException>()));
  });

  test('skips padding between objects', () {
    final all = Tlv.decodeAll(
      Uint8List.fromList([
        ...encodeTlv(0x01, [1]),
        0x00,
        0xFF,
      ]),
    );
    expect(all, hasLength(1));
  });

  test('rejects truncated input', () {
    expect(
      () => Tlv.decode(Uint8List.fromList([0x30, 0x05, 0x01])),
      throwsA(isA<LdsFormatException>()),
    );
    expect(Tlv.encodedLength(Uint8List.fromList([0x5F])), isNull);
    expect(
      () => Tlv.decode(Uint8List.fromList([0x30, 0x85, 1, 1, 1, 1, 1])),
      throwsA(isA<LdsFormatException>()),
    );
  });
}
