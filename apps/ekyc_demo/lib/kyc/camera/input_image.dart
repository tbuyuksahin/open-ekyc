import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// The image format ML Kit accepts from camera streams on each platform.
ImageFormatGroup get mlKitImageFormat =>
    Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888;

const Map<DeviceOrientation, int> _orientations = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// Converts a camera frame to an ML Kit input, or `null` if the frame
/// format is not supported.
InputImage? toInputImage(
  CameraImage image,
  CameraDescription camera,
  DeviceOrientation deviceOrientation,
) {
  final sensor = camera.sensorOrientation;
  InputImageRotation? rotation;
  if (Platform.isIOS) {
    rotation = InputImageRotationValue.fromRawValue(sensor);
  } else {
    final device = _orientations[deviceOrientation];
    if (device == null) return null;
    final degrees = camera.lensDirection == CameraLensDirection.front
        ? (sensor + device) % 360
        : (sensor - device + 360) % 360;
    rotation = InputImageRotationValue.fromRawValue(degrees);
  }
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
