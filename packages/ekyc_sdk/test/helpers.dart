import 'dart:typed_data';

import 'package:ekyc_sdk/ekyc_sdk.dart';
import 'package:icao_mrtd/testing.dart';

const specimenMrz = [
  'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<',
  'L898902C36UTO7408122F1204159ZE184226B<<<<<10',
];

final MrzKey specimenKey = Mrz.parse(specimenMrz).key;

/// A signed synthetic document and its trust store.
class TestDocument {
  factory TestDocument({bool tamperDg1 = false}) {
    final pki = TestPki(cscaKey: TestKeyType.ecdsaP256);
    final dg1 = LdsBuilder.dg1(specimenMrz);
    final dg2 = LdsBuilder.dg2(LdsBuilder.fakeJpeg(300));
    final sod = LdsBuilder.sod(
      dataGroups: {1: dg1, 2: dg2},
      signer: pki.documentSigner,
    );
    final storedDg1 = Uint8List.fromList(dg1);
    if (tamperDg1) storedDg1[12] ^= 0x01;
    return TestDocument._({
      LdsFile.com: LdsBuilder.com([LdsFile.dg1, LdsFile.dg2]),
      LdsFile.dg1: storedDg1,
      LdsFile.dg2: dg2,
      LdsFile.sod: sod,
    }, CscaStore([pki.csca.certificate]));
  }

  TestDocument._(this.files, this.trustStore);

  final Map<LdsFile, Uint8List> files;
  final CscaStore trustStore;
}
