import 'package:ekyc_demo/kyc/domain/nfc_session.dart';
import 'package:flutter/services.dart';
import 'package:icao_mrtd/icao_mrtd.dart';
import 'package:icao_mrtd/testing.dart';
import 'package:icao_mrz/icao_mrz.dart';

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

  /// An NFC session that "finds" this document after a short delay.
  NfcSession asNfcSession() => _DemoNfcSession(this);
}

class _DemoNfcSession implements NfcSession {
  _DemoNfcSession(this.document);

  final DemoDocument document;

  @override
  Future<NfcStatus> status() async => NfcStatus.available;

  @override
  Future<ApduTransceiver> connect({required String prompt}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return _SlowChip(
      VirtualMrtd(key: document.mrz.key, files: document.files),
    );
  }

  @override
  Future<void> setMessage(String message) async {}

  @override
  Future<void> close({String? message, String? errorMessage}) async {}
}

/// Adds realistic latency so the progress UI is visible in the demo.
class _SlowChip implements ApduTransceiver {
  _SlowChip(this.chip);

  final ApduTransceiver chip;

  @override
  Future<Uint8List> transceive(Uint8List command) async {
    await Future<void>.delayed(const Duration(milliseconds: 15));
    return chip.transceive(command);
  }
}
