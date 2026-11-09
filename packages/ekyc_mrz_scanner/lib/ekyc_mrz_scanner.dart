/// MRZ step of an e-KYC flow: camera scanning with a document template
/// overlay, and a manual entry form for the chip access key.
///
/// ```dart
/// MrzScanner(
///   onDetected: (mrz) => readChip(mrz.key),
///   unavailableBuilder: (_) => const Text('No camera'),
///   hintText: (status) => 'Align the bottom of the card',
///   style: const MrzOverlayStyle(successColor: Colors.teal),
/// )
/// ```
library;

export 'package:icao_mrz/icao_mrz.dart' show Mrz, MrzFormat, MrzKey;

export 'src/manual_mrz_form.dart';
export 'src/mrz_input.dart';
export 'src/mrz_overlay.dart';
export 'src/mrz_scanner.dart';
