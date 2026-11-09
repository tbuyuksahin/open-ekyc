import 'dart:typed_data';

import 'package:icao_mrtd/icao_mrtd.dart';
import 'package:icao_mrtd/testing.dart';
import 'package:icao_mrz/icao_mrz.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  test('EF.COM lists data groups', () {
    final com = EfCom.parse(LdsBuilder.com([LdsFile.dg1, LdsFile.dg2]));
    expect(com.ldsVersion, '0107');
    expect(com.dataGroups, [LdsFile.dg1, LdsFile.dg2]);
    expect(
      () => EfCom.parse(LdsBuilder.dg1(specimenMrz)),
      throwsA(isA<LdsFormatException>()),
    );
  });

  test('DG1 yields the MRZ', () {
    final mrz = parseDg1(LdsBuilder.dg1(specimenMrz));
    expect(mrz.format, MrzFormat.td3);
    expect(mrz.isValid, isTrue);
    expect(
      () => parseDg1(encodeTlv(0x61, encodeTlv(0x5F1F, [0x41]))),
      throwsA(isA<LdsFormatException>()),
    );
  });

  group('DG2', () {
    test('extracts the JPEG by walking the record headers', () {
      final jpeg = LdsBuilder.fakeJpeg(300);
      // 0xFF feature points before the image used to fool naive scanners.
      final face = parseDg2(LdsBuilder.dg2(jpeg, featurePoints: 3));
      expect(face.bytes, jpeg);
      expect(face.format, FaceImageFormat.jpeg);
      expect((face.width, face.height), (240, 320));
      expect(face.toString(), contains('jpeg'));
    });

    test('recognizes JPEG 2000', () {
      final jp2 = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x0C, 0x6A, 0x50, 0x20, 0x20, 1, 2, 3, //
      ]);
      final face = parseDg2(LdsBuilder.dg2(jp2, jpeg2000: true));
      expect(face.format, FaceImageFormat.jpeg2000);
    });

    test('rejects an image whose signature does not match its type', () {
      expect(
        () => parseDg2(LdsBuilder.dg2(Uint8List.fromList([1, 2, 3, 4]))),
        throwsA(isA<LdsFormatException>()),
      );
    });
  });

  test('DG11 keeps Unicode names and the full date of birth', () {
    final dg11 = Dg11.parse(
      LdsBuilder.dg11(
        fullName: 'ÇAKIR<<ŞÜKRÜ<İSMAİL',
        personalNumber: '10000000146',
        fullDateOfBirth: '19950108',
        placeOfBirth: 'İSTANBUL',
      ),
    );
    expect(dg11.primaryIdentifier, 'ÇAKIR');
    expect(dg11.secondaryIdentifier, 'ŞÜKRÜ İSMAİL');
    expect(dg11.personalNumber, '10000000146');
    expect(dg11.fullDateOfBirth, DateTime(1995, 1, 8));
    expect(dg11.placeOfBirth, 'İSTANBUL');
    expect(dg11.toString(), isNot(contains('ÇAKIR')));
  });

  test('DG11 tolerates missing and malformed fields', () {
    final dg11 = Dg11.parse(LdsBuilder.dg11(fullDateOfBirth: '19951341'));
    expect(dg11.fullName, isNull);
    expect(dg11.primaryIdentifier, isNull);
    expect(dg11.fullDateOfBirth, isNull);
  });
}
