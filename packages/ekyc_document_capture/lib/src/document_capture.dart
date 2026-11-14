import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:ekyc_camera/ekyc_camera.dart';
import 'package:ekyc_document_capture/src/document_gate.dart';
import 'package:ekyc_document_capture/src/document_kind.dart';
import 'package:ekyc_document_capture/src/document_overlay.dart';
import 'package:ekyc_document_capture/src/document_result.dart';
import 'package:ekyc_document_capture/src/frame_quality.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:icao_mrz/icao_mrz.dart';
import 'package:material_ui/material_ui.dart';

/// How the photo of each side is taken.
enum DocumentCaptureMode {
  /// Taken as soon as the frame is good and steady.
  auto,

  /// Taken when the user presses the shutter.
  manual,
}

/// Measures the quality of one frame; `null` skips the quality checks.
typedef FrameQualityMeasure = FrameQuality? Function(InputImage image);

/// Live camera view that photographs the sides of an identity document.
///
/// Each frame is checked on the device: light, glare, sharpness, and
/// whether the expected side is in view (the side with the machine
/// readable zone is recognized by reading it). Calls [onCaptured] once,
/// after the last side. Frames are never stored; the photos exist only in
/// memory and are wiped if the widget is removed before it completes.
class DocumentCapture extends StatefulWidget {
  /// Creates a capture view.
  const DocumentCapture({
    required this.onCaptured,
    required this.unavailableBuilder,
    this.kind = DocumentKind.idCard,
    this.sides,
    this.captureMode = DocumentCaptureMode.auto,
    this.manualRequiresGoodFrame = true,
    this.hintText,
    this.sideLabel,
    this.shutterLabel,
    this.style = const DocumentOverlayStyle(),
    this.gate,
    this.measure = FrameAnalyzer.analyze,
    this.frameInterval = const Duration(milliseconds: 200),
    this.capturedDelay = const Duration(milliseconds: 700),
    super.key,
  });

  /// Receives the photos after the last side.
  final ValueChanged<DocumentCaptureResult> onCaptured;

  /// Shown when there is no camera or permission was denied.
  final WidgetBuilder unavailableBuilder;

  /// The document being captured.
  final DocumentKind kind;

  /// The sides to capture, in order; every side of [kind] when `null`.
  final List<DocumentSide>? sides;

  /// Automatic or manual photo.
  final DocumentCaptureMode captureMode;

  /// In manual mode, whether the shutter stays disabled until the frame
  /// passes the checks.
  final bool manualRequiresGoodFrame;

  /// Hint text for each state of each side; no hint when `null`.
  final String Function(DocumentHint hint, DocumentSide side)? hintText;

  /// Short name of each side, shown above the frame; hidden when `null`.
  final String Function(DocumentSide side)? sideLabel;

  /// Accessibility label of the manual shutter.
  final String? shutterLabel;

  /// Overlay style.
  final DocumentOverlayStyle style;

  /// Decides when a frame is good enough; a default gate when `null`.
  final DocumentQualityGate? gate;

  /// Measures frame quality.
  final FrameQualityMeasure measure;

  /// Minimum time between checked frames.
  final Duration frameInterval;

  /// How long the success state of a side is shown.
  final Duration capturedDelay;

  @override
  State<DocumentCapture> createState() => _DocumentCaptureState();
}

class _DocumentCaptureState extends State<DocumentCapture> {
  late final MlKitCamera _camera = MlKitCamera(
    lensDirection: CameraLensDirection.back,
    onFrame: _onFrame,
    frameInterval: widget.frameInterval,
  );
  final _recognizer = TextRecognizer();
  late final DocumentQualityGate _gate = widget.gate ?? DocumentQualityGate();
  late final List<DocumentSide> _sides = widget.sides ?? widget.kind.sides;
  final _images = <DocumentSide, Uint8List>{};
  List<String> _frontText = const [];
  List<String> _seenText = const [];
  Mrz? _mrz;
  Mrz? _seenMrz;
  int _index = 0;
  DocumentHint _hint = DocumentHint.noDocument;
  double _progress = 0;
  bool _busy = false;
  bool _captured = false;
  bool _handedOver = false;

  DocumentSide get _side => _sides[_index];

  @override
  void initState() {
    super.initState();
    assert(_sides.isNotEmpty, 'Give at least one side');
    unawaited(_camera.start());
  }

  Future<void> _onFrame(InputImage input) async {
    if (_busy) return;
    final quality = widget.measure(input);
    final text = await _recognizer.processImage(input);
    if (!mounted || _busy) return;
    final lines = [
      for (final line in text.text.split('\n'))
        if (line.trim().length >= 3) line.trim(),
    ];
    final mrz = MrzRecognizer.recognize(text.text);
    _seenText = lines;
    _seenMrz = mrz;
    final observation = DocumentObservation(
      textLines: lines.length,
      hasMrz: mrz != null,
      quality: quality,
    );
    final expectMrz = widget.kind.hasMrzOn(_side);
    if (widget.captureMode == DocumentCaptureMode.manual) {
      final hint = _gate.hintFor(observation, expectMrz: expectMrz);
      if (hint != _hint) setState(() => _hint = hint);
      return;
    }
    final hint = _gate.evaluate(observation, expectMrz: expectMrz);
    if (hint == null) {
      await _capture();
    } else if (hint != _hint || _gate.progress != _progress) {
      setState(() {
        _hint = hint;
        _progress = _gate.progress;
      });
    }
  }

  Future<void> _capture() async {
    if (_busy) return;
    final side = _side;
    final text = _seenText;
    final mrz = _seenMrz;
    setState(() => _busy = true);
    final bytes = await _camera.takePicture();
    if (!mounted) {
      bytes?.fillRange(0, bytes.length, 0);
      return;
    }
    if (bytes == null) {
      _gate.reset();
      setState(() {
        _busy = false;
        _progress = 0;
      });
      return;
    }
    _images[side] = bytes;
    if (side == DocumentSide.front) _frontText = text;
    if (mrz != null && widget.kind.hasMrzOn(side)) _mrz = mrz;
    setState(() => _captured = true);
    if (widget.capturedDelay > Duration.zero) {
      await Future<void>.delayed(widget.capturedDelay);
      if (!mounted) return;
    }
    if (_index == _sides.length - 1) {
      _handedOver = true;
      widget.onCaptured(
        DocumentCaptureResult(
          kind: widget.kind,
          images: _images,
          frontText: _frontText,
          mrz: _mrz,
        ),
      );
      return;
    }
    _gate.reset();
    setState(() {
      _index++;
      _busy = false;
      _captured = false;
      _hint = DocumentHint.noDocument;
      _progress = 0;
    });
    await _camera.resumeProcessing();
  }

  bool get _canShoot =>
      !_busy &&
      (!widget.manualRequiresGoodFrame || _hint == DocumentHint.holdStill);

  @override
  void dispose() {
    _camera.dispose();
    unawaited(_recognizer.close());
    if (!_handedOver) {
      for (final bytes in _images.values) {
        bytes.fillRange(0, bytes.length, 0);
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manual = widget.captureMode == DocumentCaptureMode.manual;
    return Stack(
      fit: StackFit.expand,
      children: [
        MlKitCameraView(
          camera: _camera,
          unavailableBuilder: widget.unavailableBuilder,
          overlay: DocumentOverlay(
            kind: widget.kind,
            side: _side,
            state: DocumentGuideState.of(_hint, captured: _captured),
            progress: manual ? 0 : _progress,
            hint: _captured ? null : widget.hintText?.call(_hint, _side),
            label: widget.sideLabel?.call(_side),
            style: widget.style,
          ),
        ),
        if (manual && !_captured)
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: ShutterButton(
                label: widget.shutterLabel,
                color: widget.style.readyColor,
                onPressed: _canShoot ? _capture : null,
              ),
            ),
          ),
      ],
    );
  }
}
