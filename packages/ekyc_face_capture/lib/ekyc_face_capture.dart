/// Selfie step of an e-KYC flow: an on-device quality gate that captures
/// automatically, an oval guide overlay and a liveness check interface.
///
/// ```dart
/// FaceCapture(
///   onCaptured: (result) => match(result.image),
///   unavailableBuilder: (_) => const Text('No camera'),
///   hintText: (hint) => hints[hint]!,
///   style: const FaceOverlayStyle(readyColor: Colors.teal),
/// )
/// ```
library;

export 'src/face_capture.dart';
export 'src/face_challenge.dart';
export 'src/face_overlay.dart';
export 'src/face_quality.dart';
export 'src/liveness.dart';
