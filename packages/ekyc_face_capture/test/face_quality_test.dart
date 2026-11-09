import 'dart:typed_data';
import 'dart:ui';

import 'package:ekyc_face_capture/ekyc_face_capture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const size = Size(480, 640);
  FaceObservation face({
    Rect box = const Rect.fromLTWH(120, 180, 240, 280),
    double yaw = 0,
    double roll = 0,
    double eyes = 0.9,
  }) => FaceObservation(
    box: box,
    imageSize: size,
    yaw: yaw,
    roll: roll,
    leftEyeOpen: eyes,
    rightEyeOpen: eyes,
  );

  test('guides the user until the frame is good', () {
    final gate = FaceQualityGate();
    expect(gate.evaluate([]), FaceHint.noFace);
    expect(gate.evaluate([face(), face()]), FaceHint.multipleFaces);
    expect(
      gate.evaluate([face(box: const Rect.fromLTWH(200, 280, 80, 100))]),
      FaceHint.moveCloser,
    );
    expect(
      gate.evaluate([face(box: const Rect.fromLTWH(0, 0, 240, 280))]),
      FaceHint.center,
    );
    expect(gate.evaluate([face(yaw: 25)]), FaceHint.lookStraight);
    expect(gate.evaluate([face(roll: -20)]), FaceHint.lookStraight);
    expect(gate.evaluate([face(eyes: 0.1)]), FaceHint.openEyes);
  });

  test('fires only after consecutive good frames, reporting progress', () {
    final gate = FaceQualityGate(requiredStableFrames: 3);
    expect(gate.evaluate([face()]), FaceHint.holdStill);
    expect(gate.progress, closeTo(1 / 3, 1e-9));
    expect(gate.evaluate([face()]), FaceHint.holdStill);
    expect(gate.evaluate([face(yaw: 30)]), FaceHint.lookStraight);
    expect(gate.progress, 0);
    expect(gate.evaluate([face()]), FaceHint.holdStill);
    gate.reset();
    expect(gate.progress, 0);
    expect(gate.evaluate([face()]), FaceHint.holdStill);
    expect(gate.evaluate([face()]), FaceHint.holdStill);
    expect(gate.evaluate([face()]), isNull);
    expect(gate.progress, 0);
  });

  test('hints know whether they are adjustments', () {
    expect(FaceHint.noFace.isAdjustment, isFalse);
    expect(FaceHint.multipleFaces.isAdjustment, isFalse);
    expect(FaceHint.holdStill.isAdjustment, isFalse);
    expect(FaceHint.moveCloser.isAdjustment, isTrue);
    expect(FaceHint.openEyes.isAdjustment, isTrue);
  });

  test('the no-op liveness check says it did nothing', () async {
    expect(
      await const NoLivenessCheck().check(Uint8List(0)),
      LivenessOutcome.notPerformed,
    );
  });
}
