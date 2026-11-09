import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

/// The image format ML Kit accepts from camera streams on each platform.
ImageFormatGroup get mlKitImageFormat =>
    Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888;

const Map<DeviceOrientation, int> _orientations = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// The rotation ML Kit needs to see a frame upright.
///
/// iOS frames only need the sensor orientation. Android frames also depend
/// on how the device is held and, for the front camera, on mirroring.
/// Returns `null` for an orientation the camera plugin should never report.
InputImageRotation? inputImageRotation({
  required bool isIOS,
  required int sensorOrientation,
  required CameraLensDirection lensDirection,
  required DeviceOrientation deviceOrientation,
}) {
  if (isIOS) return InputImageRotationValue.fromRawValue(sensorOrientation);
  final device = _orientations[deviceOrientation];
  if (device == null) return null;
  final degrees = lensDirection == CameraLensDirection.front
      ? (sensorOrientation + device) % 360
      : (sensorOrientation - device + 360) % 360;
  return InputImageRotationValue.fromRawValue(degrees);
}

/// Converts a camera frame to an ML Kit input, or `null` if the frame
/// format is not supported.
InputImage? toInputImage(
  CameraImage image,
  CameraDescription camera,
  DeviceOrientation deviceOrientation,
) {
  final rotation = inputImageRotation(
    isIOS: Platform.isIOS,
    sensorOrientation: camera.sensorOrientation,
    lensDirection: camera.lensDirection,
    deviceOrientation: deviceOrientation,
  );
  if (rotation == null) return null;
  final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
  final supported = Platform.isAndroid
      ? format == InputImageFormat.nv21
      : format == InputImageFormat.bgra8888;
  if (format == null || !supported || image.planes.length != 1) return null;
  final plane = image.planes.single;
  return InputImage.fromBytes(
    bytes: plane.bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: plane.bytesPerRow,
    ),
  );
}
