import 'dart:typed_data';

import 'package:icao_mrtd/icao_mrtd.dart';
import 'package:icao_mrtd/testing.dart';
import 'package:icao_mrz/icao_mrz.dart';

/// ICAO 9303 specimen MRZ (fictitious holder).
const specimenMrz = [
  'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<',
  'L898902C36UTO7408122F1204159ZE184226B<<<<<10',
];

/// The specimen's BAC key.
final MrzKey specimenKey = Mrz.parse(specimenMrz).key;

/// A complete synthetic document.
class Document {
  /// Builds a document signed by [pki].
  factory Document({TestPki? pki, int imageSize = 900}) {
    final p = pki ?? TestPki();
    final dg1 = LdsBuilder.dg1(specimenMrz);
    final dg2 = LdsBuilder.dg2(LdsBuilder.fakeJpeg(imageSize));
    final dg11 = LdsBuilder.dg11(
      fullName: 'ERİKSSON<<ANNA<MARİA',
      personalNumber: '10000000146',
      fullDateOfBirth: '19740812',
    );
    return Document._({
      LdsFile.com: LdsBuilder.com([LdsFile.dg1, LdsFile.dg2, LdsFile.dg11]),
      LdsFile.dg1: dg1,
      LdsFile.dg2: dg2,
      LdsFile.dg11: dg11,
      LdsFile.sod: LdsBuilder.sod(
        dataGroups: {1: dg1, 2: dg2, 11: dg11},
        signer: p.documentSigner,
      ),
    }, p);
  }

  Document._(this.files, this.pki);

  /// The files on the chip.
  final Map<LdsFile, Uint8List> files;

  /// The PKI that signed it.
  final TestPki pki;

  /// A chip holding the files.
  VirtualMrtd chip({int? loseTagAfter, bool corruptResponseMac = false}) =>
      VirtualMrtd(
        key: specimenKey,
        files: files,
        loseTagAfter: loseTagAfter,
        corruptResponseMac: corruptResponseMac,
      );
}
