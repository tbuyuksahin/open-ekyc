import 'dart:ui';

/// What the face detector saw in one frame, independent of ML Kit types.
class FaceObservation {
  const FaceObservation({
    required this.box,
    required this.imageSize,
    this.yaw,
    this.roll,
    this.leftEyeOpen,
    this.rightEyeOpen,
  });

  /// Face bounding box in image coordinates.
  final Rect box;
  final Size imageSize;

  /// Head rotation around the vertical axis, in degrees.
  final double? yaw;

  /// Head tilt, in degrees.
  final double? roll;

  /// Eye-open probabilities (0-1), if classification ran.
  final double? leftEyeOpen;
  final double? rightEyeOpen;
}

/// Guidance shown while framing the face.
enum FaceHint {
  noFace,
  multipleFaces,
  moveCloser,
  center,
  lookStraight,
  openEyes,
  holdStill,
}

/// Decides when a selfie is good enough for face matching.
///
/// A frame passes when exactly one face fills enough of the image, is
/// centered, looks straight at the camera with open eyes; capture fires
/// after [requiredStableFrames] consecutive passing frames so motion blur
/// is unlikely. This is a quality gate, not a liveness check.
class FaceQualityGate {
  FaceQualityGate({
    this.requiredStableFrames = 5,
    this.minFaceWidthRatio = 0.35,
    this.maxCenterOffset = 0.15,
    this.maxAngle = 12,
    this.minEyeOpen = 0.5,
  });

  final int requiredStableFrames;
  final double minFaceWidthRatio;
  final double maxCenterOffset;
  final double maxAngle;
  final double minEyeOpen;

  int _stable = 0;

  /// Evaluates one frame. Returns `null` when the capture should fire,
  /// otherwise the hint to show.
  FaceHint? evaluate(List<FaceObservation> faces) {
    final hint = _hint(faces);
    if (hint != FaceHint.holdStill) {
      _stable = 0;
      return hint;
    }
    _stable++;
    if (_stable >= requiredStableFrames) {
      _stable = 0;
      return null;
    }
    return FaceHint.holdStill;
  }

  void reset() => _stable = 0;

  FaceHint _hint(List<FaceObservation> faces) {
    if (faces.isEmpty) return FaceHint.noFace;
    if (faces.length > 1) return FaceHint.multipleFaces;
    final f = faces.single;
    final w = f.imageSize.width;
    final h = f.imageSize.height;
    if (f.box.width / w < minFaceWidthRatio) return FaceHint.moveCloser;
    final dx = (f.box.center.dx - w / 2).abs() / w;
    final dy = (f.box.center.dy - h / 2).abs() / h;
    if (dx > maxCenterOffset || dy > maxCenterOffset) return FaceHint.center;
    if ((f.yaw ?? 0).abs() > maxAngle || (f.roll ?? 0).abs() > maxAngle) {
      return FaceHint.lookStraight;
    }
    final eyesOpen =
        (f.leftEyeOpen ?? 1) >= minEyeOpen &&
        (f.rightEyeOpen ?? 1) >= minEyeOpen;
    if (!eyesOpen) {
      return FaceHint.openEyes;
    }
    return FaceHint.holdStill;
  }
}
