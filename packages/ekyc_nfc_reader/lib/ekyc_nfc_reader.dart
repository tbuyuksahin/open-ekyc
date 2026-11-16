/// NFC step of an e-KYC flow: read and verify an ePassport or eID chip,
/// and show where to hold the document.
///
/// ```dart
/// final reader = ChipReader(
///   session: const FlutterNfcSession(),
///   trustStore: cscaStore,
/// );
/// final document = await reader.read(
///   mrzKey,
///   onProgress: (step, fraction) => setState(() => ...),
/// );
/// ```
library;

export 'package:icao_mrtd/icao_mrtd.dart'
    show
        CscaStore,
        Dg11,
        FaceImage,
        FaceImageFormat,
        LdsFile,
        PassiveAuthFailure,
        PassiveAuthResult,
        PassiveAuthStatus;

export 'src/chip_reader.dart';
export 'src/document_data.dart';
export 'src/flutter_nfc_session.dart';
export 'src/nfc_scan_overlay.dart';
export 'src/nfc_session.dart';
