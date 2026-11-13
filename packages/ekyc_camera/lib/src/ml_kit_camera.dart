import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:ekyc_camera/src/input_image.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

/// Where an [MlKitCamera] is in its life.
enum MlKitCameraStatus {
  /// Opening the camera (also while the app is in the background).
  starting,

  /// The preview is live and frames are being delivered.
  ready,

  /// There is no matching camera or permission was denied.
  unavailable,
}

/// Handles one ML Kit frame. Frames that arrive while it runs are dropped.
typedef MlKitFrameHandler = Future<void> Function(InputImage image);

/// Opens a camera and streams its frames to ML Kit.
///
/// Frames are processed one at a time and never stored. The camera is
/// released while the app is in the background and reopened when it comes
/// back, so other apps can use it and nothing is captured off screen.
class MlKitCamera extends ChangeNotifier with WidgetsBindingObserver {
  /// Creates a camera that prefers [lensDirection].
  MlKitCamera({
    required this.lensDirection,
    required this.onFrame,
    this.frameInterval = Duration.zero,
    this.resolution = ResolutionPreset.high,
  });

  /// The lens to use; any camera is used if there is none facing this way.
  final CameraLensDirection lensDirection;

  /// Receives every frame that is not dropped.
  final MlKitFrameHandler onFrame;

  /// Minimum time between processed frames, to save battery.
  final Duration frameInterval;

  /// Capture resolution.
  final ResolutionPreset resolution;

  MlKitCameraStatus _status = MlKitCameraStatus.starting;
  CameraController? _controller;
  bool _observing = false;
  bool _busy = false;
  bool _capturing = false;
  bool _processing = true;
  bool _background = false;
  bool _disposed = false;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);

  /// Current status.
  MlKitCameraStatus get status => _status;

  /// The live controller while [status] is [MlKitCameraStatus.ready].
  CameraController? get controller => _controller;

  /// Opens the camera and starts delivering frames.
  Future<void> start() async {
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    await _open();
  }

  /// Stops handing frames to [onFrame]; the preview stays live.
  void stopProcessing() => _processing = false;

  /// Hands frames to [onFrame] again after [stopProcessing] or a
  /// successful [takePicture], which leaves the frame stream stopped.
  Future<void> resumeProcessing() async {
    _processing = true;
    final controller = _controller;
    if (controller == null || _capturing) return;
    if (!controller.value.isStreamingImages) await _startStream(controller);
  }

  /// Takes a full resolution photo and returns its bytes.
  ///
  /// The file the camera plugin writes is deleted right after it is read.
  /// Returns `null` and resumes the frame stream if the capture fails.
  Future<Uint8List?> takePicture() async {
    final controller = _controller;
    if (controller == null || _capturing) return null;
    _capturing = true;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      await File(file.path).delete();
      return bytes;
    } on Object {
      if (!_disposed && identical(_controller, controller)) {
        await _startStream(controller);
      }
      return null;
    } finally {
      _capturing = false;
    }
  }

  Future<void> _open() async {
    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == lensDirection,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        resolution,
        enableAudio: false,
        imageFormatGroup: mlKitImageFormat,
      );
      await controller.initialize();
      if (_disposed || _background) {
        await controller.dispose();
        return;
      }
      await _startStream(controller);
      _controller = controller;
      _setStatus(MlKitCameraStatus.ready);
    } on Object {
      _setStatus(MlKitCameraStatus.unavailable);
    }
  }

  Future<void> _startStream(CameraController controller) =>
      controller.startImageStream((image) => _onImage(image, controller));

  Future<void> _onImage(CameraImage image, CameraController controller) async {
    if (_busy || _capturing || !_processing) return;
    final now = DateTime.now();
    if (now.difference(_lastFrame) < frameInterval) return;
    _busy = true;
    _lastFrame = now;
    try {
      final input = toInputImage(
        image,
        controller.description,
        controller.value.deviceOrientation,
      );
      if (input != null) await onFrame(input);
    } on Object {
      // A failed frame is skipped; the next one will be tried.
    } finally {
      _busy = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_background) return;
      _background = true;
      final controller = _controller;
      _controller = null;
      if (_status == MlKitCameraStatus.ready) {
        _setStatus(MlKitCameraStatus.starting);
      }
      unawaited(controller?.dispose());
    } else if (state == AppLifecycleState.resumed && _background) {
      _background = false;
      if (_status != MlKitCameraStatus.unavailable) unawaited(_open());
    }
  }

  void _setStatus(MlKitCameraStatus status) {
    if (_disposed) return;
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller?.dispose());
    _controller = null;
    super.dispose();
  }
}
