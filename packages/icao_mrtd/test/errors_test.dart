import 'dart:typed_data';

import 'package:icao_mrtd/icao_mrtd.dart';
import 'package:test/test.dart';

void main() {
  test('exceptions describe the failure without data', () {
    expect(
      ApduException(0x6A82, 'SELECT').toString(),
      'ApduException: SELECT failed with SW 6a82',
    );
    expect(const AccessDeniedException('x').kind, 'AccessDeniedException');
    expect(
      const SecureMessagingException('x').kind,
      'SecureMessagingException',
    );
    expect(const LdsFormatException('x').toString(), 'LdsFormatException: x');
  });

  test('LDS file metadata', () {
    expect(LdsFile.dg11.dataGroup, 11);
    expect(LdsFile.sod.dataGroup, isNull);
    expect(LdsFile.forDataGroup(2), LdsFile.dg2);
    expect(LdsFile.forDataGroup(99), isNull);
    expect(LdsFile.forTag(0x6B), LdsFile.dg11);
    expect(LdsFile.forTag(0x01), isNull);
  });

  test('APDU encoding', () {
    expect(
      CommandApdu(cla: 0, ins: 0xB0, p1: 0, p2: 0, ne: 256).toBytes(),
      [0, 0xB0, 0, 0, 0],
    );
    expect(
      () => CommandApdu(cla: 0, ins: 0, p1: 0, p2: 0, ne: 0),
      throwsArgumentError,
    );
    expect(() => ResponseApdu.fromBytes(Uint8List(1)), throwsArgumentError);
  });
}
