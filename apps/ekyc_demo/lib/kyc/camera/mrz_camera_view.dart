import 'dart:async';

import 'package:camera/camera.dart';
import 'package:ekyc_demo/core/app_log.dart';
import 'package:ekyc_demo/kyc/camera/input_image.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:icao_mrz/icao_mrz.dart';

/// Live camera preview that reports an MRZ once it has been read
/// identically in two consecutive frames with all check digits valid.
///
/// Text recognition runs on the device; frames never leave it.
class MrzCameraView extends StatefulWidget {
  const MrzCameraView({
    required this.onDetected,
    required this.unavailableBuilder,
    super.key,
  });

  final ValueChanged<Mrz> onDetected;

  /// Shown when there is no camera or permission was denied.
  final WidgetBuilder unavailableBuilder;

  @override
  State<MrzCameraView> createState() => _MrzCameraViewState();
}

class _MrzCameraViewState extends State<MrzCameraView>
    with WidgetsBindingObserver {
  CameraController? _controller;
  final _recognizer = TextRecognizer();
  bool _busy = false;
  bool _done = false;
  bool _unavailable = false;
  String? _previous;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: mlKitImageFormat,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.startImageStream((image) => _onFrame(image, back));
      setState(() => _controller = controller);
    } on Object {
      AppLog.event('mrz_camera_unavailable');
      if (mounted) setState(() => _unavailable = true);
    }
  }

  Future<void> _onFrame(CameraImage image, CameraDescription camera) async {
    final now = DateTime.now();
    if (_busy || _done || now.difference(_lastFrame).inMilliseconds < 250) {
      return;
    }
    _busy = true;
    _lastFrame = now;
    try {
      final controller = _controller;
      final input = controller == null
          ? null
          : toInputImage(image, camera, controller.value.deviceOrientation);
      if (input == null) return;
      final text = await _recognizer.processImage(input);
      final mrz = MrzRecognizer.recognize(text.text);
      if (mrz == null) {
        _previous = null;
        return;
      }
      final signature = mrz.lines.join();
      if (signature == _previous && !_done && mounted) {
        _done = true;
        AppLog.event('mrz_scanned', {'format': mrz.format.name});
        widget.onDetected(mrz);
      }
      _previous = signature;
    } on Object {
      // A failed frame is skipped; the next one will be tried.
    } finally {
      _busy = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null) return;
    if (state == AppLifecycleState.inactive) {
      _controller = null;
      unawaited(controller.dispose());
    } else if (state == AppLifecycleState.resumed && !_done) {
      unawaited(_start());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller?.dispose());
    unawaited(_recognizer.close());
    _previous = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_unavailable) return widget.unavailableBuilder(context);
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
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
        const _MrzFrame(),
      ],
    );
  }
}

class _MrzFrame extends StatelessWidget {
  const _MrzFrame();

  @override
  Widget build(BuildContext context) => Align(
    alignment: const Alignment(0, 0.45),
    child: FractionallySizedBox(
      widthFactor: 0.92,
      child: AspectRatio(
        aspectRatio: 5,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    ),
  );
}
