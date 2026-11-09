import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:ekyc_demo/core/app_log.dart';
import 'package:ekyc_demo/kyc/camera/input_image.dart';
import 'package:ekyc_demo/kyc/domain/face_quality.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Front camera with an oval guide that captures a selfie automatically
/// once [FaceQualityGate] is satisfied.
///
/// The photo file the camera plugin writes is deleted immediately after
/// it is read into memory.
class FaceCameraView extends StatefulWidget {
  const FaceCameraView({
    required this.onCaptured,
    required this.hintText,
    required this.unavailableBuilder,
    super.key,
  });

  final ValueChanged<Uint8List> onCaptured;
  final String Function(FaceHint hint) hintText;
  final WidgetBuilder unavailableBuilder;

  @override
  State<FaceCameraView> createState() => _FaceCameraViewState();
}

class _FaceCameraViewState extends State<FaceCameraView> {
  CameraController? _controller;
  final _detector = FaceDetector(
    options: FaceDetectorOptions(enableClassification: true),
  );
  final _gate = FaceQualityGate();
  FaceHint _hint = FaceHint.noFace;
  bool _busy = false;
  bool _capturing = false;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: mlKitImageFormat,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.startImageStream((image) => _onFrame(image, front));
      setState(() => _controller = controller);
    } on Object {
      AppLog.event('face_camera_unavailable');
      if (mounted) setState(() => _unavailable = true);
    }
  }

  Future<void> _onFrame(CameraImage image, CameraDescription camera) async {
    final controller = _controller;
    if (_busy || _capturing || controller == null) return;
    _busy = true;
    try {
      final input = toInputImage(
        image,
        camera,
        controller.value.deviceOrientation,
      );
      if (input == null) return;
      final faces = await _detector.processImage(input);
      final size = input.metadata!.size;
      // ML Kit reports boxes in the rotated (upright) frame on Android.
      final upright = Platform.isAndroid ? Size(size.height, size.width) : size;
      final hint = _gate.evaluate([
        for (final f in faces)
          FaceObservation(
            box: f.boundingBox,
            imageSize: upright,
            yaw: f.headEulerAngleY,
            roll: f.headEulerAngleZ,
            leftEyeOpen: f.leftEyeOpenProbability,
            rightEyeOpen: f.rightEyeOpenProbability,
          ),
      ]);
      if (hint == null) {
        await _capture(controller);
      } else if (mounted && hint != _hint) {
        setState(() => _hint = hint);
      }
    } on Object {
      // Skip the frame.
    } finally {
      _busy = false;
    }
  }

  Future<void> _capture(CameraController controller) async {
    _capturing = true;
    try {
      await controller.stopImageStream();
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      await File(file.path).delete();
      if (mounted) widget.onCaptured(bytes);
    } on Object {
      AppLog.event('face_capture_failed');
      _gate.reset();
      _capturing = false;
      if (mounted) {
        await controller.startImageStream(
          (image) => _onFrame(image, controller.description),
        );
      }
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    unawaited(_detector.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_unavailable) return widget.unavailableBuilder(context);
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.previewSize?.height ?? 1,
            height: controller.value.previewSize?.width ?? 1,
            child: CameraPreview(controller),
          ),
        ),
        const CustomPaint(painter: _OvalMask()),
        Positioned(
          left: 24,
          right: 24,
          bottom: 48,
          child: Semantics(
            liveRegion: true,
            child: Text(
              widget.hintText(_hint),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OvalMask extends CustomPainter {
  const _OvalMask();

  @override
  void paint(Canvas canvas, Size size) {
    final oval = Rect.fromCenter(
      center: size.center(Offset.zero).translate(0, -size.height * 0.05),
      width: size.width * 0.7,
      height: size.width * 0.9,
    );
    final mask = Path()
      ..addRect(Offset.zero & size)
      ..addOval(oval)
      ..fillType = PathFillType.evenOdd;
    canvas
      ..drawPath(mask, Paint()..color = Colors.black54)
      ..drawOval(
        oval,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white,
      );
  }

  @override
  bool shouldRepaint(_OvalMask oldDelegate) => false;
}
