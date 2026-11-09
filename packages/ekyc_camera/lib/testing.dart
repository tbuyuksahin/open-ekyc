/// Test support: a camera platform that needs no hardware.
///
/// ```dart
/// final camera = FakeCameraPlatform();
/// CameraPlatform.instance = camera;
/// // pump a widget that uses MlKitCamera, then:
/// camera.emitFrame();
/// ```
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/widgets.dart';

export 'package:camera_platform_interface/camera_platform_interface.dart'
    show CameraException, CameraPlatform;

/// A [CameraPlatform] backed by memory.
///
/// Frames are pushed with [emitFrame]; [takePicture] writes [pictureBytes]
/// to a temporary file like the real plugin does.
class FakeCameraPlatform extends CameraPlatform {
  /// Creates a platform with a back and a front camera.
  FakeCameraPlatform({
    this.cameras = const [
      CameraDescription(
        name: 'back',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      ),
      CameraDescription(
        name: 'front',
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 270,
      ),
    ],
    this.denyPermission = false,
  });

  /// What [availableCameras] returns.
  final List<CameraDescription> cameras;

  /// When true, initializing a camera fails like a denied permission.
  final bool denyPermission;

  /// Bytes of the next photo.
  Uint8List pictureBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

  /// When set, the next [takePicture] throws this.
  Exception? pictureError;

  final _frames = StreamController<CameraImageData>.broadcast();
  int _nextId = 0;

  /// Cameras opened and not yet disposed.
  final Set<int> open = {};

  /// Names of the cameras that were created, in order.
  final List<String> created = [];

  /// Paths of photos written by [takePicture].
  final List<String> pictures = [];

  /// Whether a frame listener is attached.
  bool get isStreaming => _frames.hasListener;

  /// Pushes one BGRA frame of [size] to the image stream.
  void emitFrame({Size size = const Size(480, 640), int? rawFormat}) {
    final width = size.width.toInt();
    final height = size.height.toInt();
    _frames.add(
      CameraImageData(
        format: CameraImageFormat(
          ImageFormatGroup.bgra8888,
          // BGRA8888 as ML Kit numbers it.
          raw: rawFormat ?? 1111970369,
        ),
        width: width,
        height: height,
        planes: [
          CameraImagePlane(
            bytes: Uint8List(width * height * 4),
            bytesPerRow: width * 4,
          ),
        ],
      ),
    );
  }

  @override
  Future<List<CameraDescription>> availableCameras() async => cameras;

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings? mediaSettings,
  ) async {
    created.add(cameraDescription.name);
    return _nextId++;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    if (denyPermission) {
      throw CameraException('CameraAccessDenied', 'Permission denied');
    }
    open.add(cameraId);
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(
        CameraInitializedEvent(
          cameraId,
          640,
          480,
          ExposureMode.auto,
          true,
          FocusMode.auto,
          true,
        ),
      );

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) =>
      StreamController<CameraErrorEvent>().stream;

  @override
  Stream<CameraClosingEvent> onCameraClosing(int cameraId) =>
      StreamController<CameraClosingEvent>().stream;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      StreamController<DeviceOrientationChangedEvent>().stream;

  @override
  bool supportsImageStreaming() => true;

  @override
  Stream<CameraImageData> onStreamedFrameAvailable(
    int cameraId, {
    CameraImageStreamOptions? options,
  }) => _frames.stream;

  @override
  Future<XFile> takePicture(int cameraId) async {
    final error = pictureError;
    if (error != null) {
      pictureError = null;
      throw error;
    }
    final file = File(
      '${Directory.systemTemp.path}/fake_camera_${pictures.length}.jpg',
    )..writeAsBytesSync(pictureBytes);
    pictures.add(file.path);
    return XFile(file.path);
  }

  @override
  Widget buildPreview(int cameraId) => const SizedBox.expand();

  @override
  Future<void> dispose(int cameraId) async => open.remove(cameraId);
}
