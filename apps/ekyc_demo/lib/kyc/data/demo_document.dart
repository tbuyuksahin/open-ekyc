import 'package:ekyc_nfc_reader/testing.dart';
import 'package:ekyc_sdk/ekyc_sdk.dart';
import 'package:flutter/services.dart';
import 'package:icao_mrtd/testing.dart';

/// A fictitious ICAO specimen document on a virtual chip, so the whole
/// flow can be shown and tested without a real passport or NFC hardware.
///
/// Its CSCA is generated at runtime and trusted only in demo mode.
class DemoDocument {
  DemoDocument._(this.mrz, this.files, this.trustStore, this.portrait);

  static const mrzLines = [
    'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<',
    'L898902C36UTO7408122F1204159ZE184226B<<<<<10',
  ];

  /// The portrait asset bundled for the demo.
  static const portraitAsset = 'assets/demo/portrait.jpg';

  static Future<DemoDocument> create(AssetBundle bundle) async {
    final portrait = (await bundle.load(portraitAsset)).buffer.asUint8List();
    // ECDSA keys generate quickly enough for a phone.
    final pki = TestPki(cscaKey: TestKeyType.ecdsaP256);
    final dg1 = LdsBuilder.dg1(mrzLines);
    final dg2 = LdsBuilder.dg2(portrait);
    final dg11 = LdsBuilder.dg11(
      fullName: 'ERİKSSON<<ANNA<MARİA',
      personalNumber: 'ZE184226B',
      fullDateOfBirth: '19740812',
      placeOfBirth: 'UTOPIA',
    );
    return DemoDocument._(
      Mrz.parse(mrzLines),
      {
        LdsFile.com: LdsBuilder.com([LdsFile.dg1, LdsFile.dg2, LdsFile.dg11]),
        LdsFile.dg1: dg1,
        LdsFile.dg2: dg2,
        LdsFile.dg11: dg11,
        LdsFile.sod: LdsBuilder.sod(
          dataGroups: {1: dg1, 2: dg2, 11: dg11},
          signer: pki.documentSigner,
        ),
      },
      CscaStore([pki.csca.certificate]),
      portrait,
    );
  }

  final Mrz mrz;
  final Map<LdsFile, Uint8List> files;
  final CscaStore trustStore;
  final Uint8List portrait;

  /// An NFC session that "finds" this document after a short delay, with
  /// realistic latency so the progress UI is visible.
  NfcSession asNfcSession() => VirtualNfcSession(
    key: mrz.key,
    files: files,
    connectDelay: const Duration(milliseconds: 600),
    commandDelay: const Duration(milliseconds: 15),
  );
}
