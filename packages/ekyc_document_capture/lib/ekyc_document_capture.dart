/// Document photo step of an e-KYC flow: capture the front and back of an
/// ID card or a passport page with on-device quality checks, and compare
/// the printed text with the MRZ or chip data.
///
/// ```dart
/// DocumentCapture(
///   kind: DocumentKind.idCard,
///   onCaptured: (result) {
///     final check = result.crossCheck();
///     upload(result.front!, result.back!);
///     result.wipe();
///   },
///   unavailableBuilder: (_) => const Text('No camera'),
///   hintText: (hint, side) => 'Hold the $side inside the frame',
/// )
/// ```
library;

export 'package:icao_mrz/icao_mrz.dart' show Mrz;

export 'src/document_capture.dart';
export 'src/document_gate.dart';
export 'src/document_kind.dart';
export 'src/document_overlay.dart';
export 'src/document_result.dart';
export 'src/document_text.dart';
export 'src/frame_quality.dart';
