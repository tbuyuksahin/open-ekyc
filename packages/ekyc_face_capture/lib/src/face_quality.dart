import 'dart:ui';

/// What the face detector saw in one frame, independent of ML Kit types.
class FaceObservation {
  /// Creates an observation.
  const FaceObservation({
    required this.box,
    required this.imageSize,
    this.yaw,
    this.roll,
    this.pitch,
    this.smiling,
    this.leftEyeOpen,
    this.rightEyeOpen,
  });

  /// Face bounding box in image coordinates.
  final Rect box;

  /// Size of the (upright) image the box refers to.
  final Size imageSize;

  /// Head rotation around the vertical axis, in degrees.
  final double? yaw;

  /// Head tilt, in degrees.
  final double? roll;

  /// Head rotation around the horizontal axis, in degrees; positive when
  /// looking up.
  final double? pitch;

  /// Smiling probability (0-1), if classification ran.
  final double? smiling;

  /// Left eye open probability (0-1), if classification ran.
  final double? leftEyeOpen;

  /// Right eye open probability (0-1), if classification ran.
  final double? rightEyeOpen;
}

/// Guidance shown while framing the face.
enum FaceHint {
  /// No face in view.
  noFace,

  /// More than one face in view.
  multipleFaces,

  /// The face is too small.
  moveCloser,

  /// The face is off center.
  center,

  /// The head is turned or tilted.
  lookStraight,

  /// The eyes are closed.
  openEyes,

  /// The frame is good; capture fires after a few more like it.
  holdStill;

  /// Whether a single face is in view and only needs adjusting.
  bool get isAdjustment => switch (this) {
    noFace || multipleFaces || holdStill => false,
    _ => true,
  };
}

/// Decides when a selfie is good enough for face matching.
///
/// A frame passes when exactly one face fills enough of the image, is
/// centered, looks straight at the camera with open eyes; capture fires
/// after [requiredStableFrames] consecutive passing frames so motion blur
/// is unlikely. This is a quality gate, not a liveness check.
class FaceQualityGate {
  /// Creates a gate with the given thresholds.
  FaceQualityGate({
    this.requiredStableFrames = 5,
    this.minFaceWidthRatio = 0.35,
    this.maxCenterOffset = 0.15,
    this.maxAngle = 12,
    this.minEyeOpen = 0.5,
  }) : assert(requiredStableFrames >= 1, 'Need at least one frame');

  /// Consecutive good frames before capture.
  final int requiredStableFrames;

  /// Minimum face width as a fraction of the image width.
  final double minFaceWidthRatio;

  /// Maximum distance of the face center from the image center, as a
  /// fraction of the image size.
  final double maxCenterOffset;

  /// Maximum yaw and roll, in degrees.
  final double maxAngle;

  /// Minimum eye open probability.
  final double minEyeOpen;

  int _stable = 0;

  /// How far the gate is towards firing (0-1).
  double get progress => _stable / requiredStableFrames;

  /// Evaluates one frame. Returns `null` when the capture should fire,
  /// otherwise the hint to show.
  FaceHint? evaluate(List<FaceObservation> faces) {
    final hint = hintFor(faces);
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

  /// Starts counting good frames from zero.
  void reset() => _stable = 0;

  /// The hint for one frame, without counting it towards capture.
  FaceHint hintFor(List<FaceObservation> faces) {
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
    if (!eyesOpen) return FaceHint.openEyes;
    return FaceHint.holdStill;
  }
}
