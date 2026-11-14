import 'dart:async';

import 'package:camera/camera.dart';
import 'package:ekyc_camera/ekyc_camera.dart';
import 'package:ekyc_mrz_scanner/src/mrz_overlay.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:icao_mrz/icao_mrz.dart';
import 'package:material_ui/material_ui.dart';

/// Accepts an MRZ only after the same text was read several times in a
/// row, so a single misread frame that happens to pass the check digits
/// is never used.
class MrzReadConfirmer {
  /// Creates a confirmer that needs [requiredReads] identical reads.
  MrzReadConfirmer({this.requiredReads = 2})
    : assert(requiredReads >= 1, 'At least one read is required');

  /// Identical consecutive reads needed.
  final int requiredReads;

  String? _last;
  int _count = 0;
  Mrz? _confirmed;

  /// The confirmed MRZ, once [add] returned [MrzScanStatus.detected].
  Mrz? get confirmed => _confirmed;

  /// Adds the result of one frame (`null` when nothing valid was read).
  MrzScanStatus add(Mrz? mrz) {
    if (_confirmed != null) return MrzScanStatus.detected;
    if (mrz == null) {
      _last = null;
      _count = 0;
      return MrzScanStatus.searching;
    }
    final signature = mrz.lines.join('\n');
    _count = signature == _last ? _count + 1 : 1;
    _last = signature;
    if (_count < requiredReads) return MrzScanStatus.confirming;
    _confirmed = mrz;
    _last = null;
    return MrzScanStatus.detected;
  }

  /// Forgets everything, including the confirmed MRZ.
  void reset() {
    _last = null;
    _count = 0;
    _confirmed = null;
  }
}

/// Live camera preview that reads an MRZ on the device.
///
/// Calls [onDetected] once, after [MrzReadConfirmer] confirmed the read and
/// the success state was shown for [successDelay]. Frames never leave the
/// device and are not stored.
class MrzScanner extends StatefulWidget {
  /// Creates a scanner.
  const MrzScanner({
    required this.onDetected,
    required this.unavailableBuilder,
    this.format = MrzFormat.td1,
    this.hintText,
    this.style = const MrzOverlayStyle(),
    this.requiredReads = 2,
    this.frameInterval = const Duration(milliseconds: 250),
    this.successDelay = const Duration(milliseconds: 450),
    super.key,
  });

  /// Receives the confirmed MRZ.
  final ValueChanged<Mrz> onDetected;

  /// Shown when there is no camera or permission was denied.
  final WidgetBuilder unavailableBuilder;

  /// The document template drawn before anything is read; the overlay
  /// switches to the format of the MRZ once one is in view.
  final MrzFormat format;

  /// Hint text for each status; no hint when `null`.
  final String Function(MrzScanStatus status)? hintText;

  /// Overlay style.
  final MrzOverlayStyle style;

  /// See [MrzReadConfirmer.requiredReads].
  final int requiredReads;

  /// Minimum time between recognized frames.
  final Duration frameInterval;

  /// How long the success state is shown before [onDetected] fires.
  final Duration successDelay;

  @override
  State<MrzScanner> createState() => _MrzScannerState();
}

class _MrzScannerState extends State<MrzScanner> {
  late final MlKitCamera _camera = MlKitCamera(
    lensDirection: CameraLensDirection.back,
    onFrame: _onFrame,
    frameInterval: widget.frameInterval,
  );
  final _recognizer = TextRecognizer();
  late final _confirmer = MrzReadConfirmer(
    requiredReads: widget.requiredReads,
  );
  MrzScanStatus _status = MrzScanStatus.searching;
  MrzFormat? _seen;

  @override
  void initState() {
    super.initState();
    unawaited(_camera.start());
  }

  Future<void> _onFrame(InputImage image) async {
    if (_status == MrzScanStatus.detected) return;
    final text = await _recognizer.processImage(image);
    if (!mounted) return;
    final mrz = MrzRecognizer.recognize(text.text);
    final status = _confirmer.add(mrz);
    if (status != _status || mrz?.format != _seen) {
      setState(() {
        _status = status;
        if (mrz != null) _seen = mrz.format;
      });
    }
    final confirmed = _confirmer.confirmed;
    if (status == MrzScanStatus.detected && confirmed != null) {
      _camera.stopProcessing();
      await Future<void>.delayed(widget.successDelay);
      if (mounted) widget.onDetected(confirmed);
    }
  }

  @override
  void dispose() {
    _camera.dispose();
    unawaited(_recognizer.close());
    _confirmer.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MlKitCameraView(
    camera: _camera,
    unavailableBuilder: widget.unavailableBuilder,
    overlay: MrzOverlay(
      format: _seen ?? widget.format,
      status: _status,
      hint: widget.hintText?.call(_status),
      style: widget.style,
    ),
  );
}
