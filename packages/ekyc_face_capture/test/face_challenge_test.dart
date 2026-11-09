import 'dart:math';
import 'dart:ui';

import 'package:ekyc_face_capture/ekyc_face_capture.dart';
import 'package:flutter_test/flutter_test.dart';

FaceObservation face({
  double yaw = 0,
  double pitch = 0,
  double smiling = 0.1,
  double eyes = 0.9,
}) => FaceObservation(
  box: const Rect.fromLTWH(120, 180, 240, 280),
  imageSize: const Size(480, 640),
  yaw: yaw,
  pitch: pitch,
  smiling: smiling,
  leftEyeOpen: eyes,
  rightEyeOpen: eyes,
);

void main() {
  final t0 = DateTime(2026, 11, 10, 12);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  FaceChallengeSession single(FaceChallenge challenge, {int hold = 2}) =>
      FaceChallengeSession(pool: [challenge], holdFrames: hold);

  // Feeds frames 100 ms apart and returns the last event.
  FaceChallengeEvent feed(
    FaceChallengeSession session,
    List<FaceObservation> frames, {
    int start = 0,
  }) {
    var event = FaceChallengeEvent.inProgress;
    for (var i = 0; i < frames.length; i++) {
      event = session.evaluate([frames[i]], at(start + i * 100));
    }
    return event;
  }

  test('recognizes each pose after it is held', () {
    final poses = {
      FaceChallenge.turnLeft: face(yaw: 30),
      FaceChallenge.turnRight: face(yaw: -30),
      FaceChallenge.lookUp: face(pitch: 20),
      FaceChallenge.lookDown: face(pitch: -20),
      FaceChallenge.smile: face(smiling: 0.95),
    };
    for (final MapEntry(key: challenge, value: pose) in poses.entries) {
      final session = single(challenge);
      expect(feed(session, [face(), pose]), FaceChallengeEvent.inProgress);
      expect(
        feed(session, [pose], start: 200),
        FaceChallengeEvent.completed,
        reason: challenge.name,
      );
      expect(session.isComplete, isTrue);
      expect(session.current, isNull);
    }
  });

  test('a pose already held when the challenge starts does not count', () {
    final session = single(FaceChallenge.turnLeft);
    expect(
      feed(session, [face(yaw: 30), face(yaw: 30), face(yaw: 30)]),
      FaceChallengeEvent.inProgress,
    );
    expect(
      feed(session, [face(), face(yaw: 30), face(yaw: 30)], start: 300),
      FaceChallengeEvent.completed,
    );
  });

  test('the other direction does not count', () {
    final session = single(FaceChallenge.turnLeft);
    expect(
      feed(session, [face(), face(yaw: -40), face(yaw: -40), face(yaw: -40)]),
      FaceChallengeEvent.inProgress,
    );
  });

  test('a mirrored platform can flip the yaw sign', () {
    final session = FaceChallengeSession(
      pool: [FaceChallenge.turnLeft],
      holdFrames: 1,
      thresholds: const FaceChallengeThresholds(yawSign: -1),
    );
    expect(
      feed(session, [face(), face(yaw: -30)]),
      FaceChallengeEvent.completed,
    );
  });

  test('a blink needs open, closed, then open eyes', () {
    final session = single(FaceChallenge.blink);
    expect(
      feed(session, [face(eyes: 0.1), face(), face(eyes: 0.4)]),
      FaceChallengeEvent.inProgress,
      reason: 'half-closed eyes are not a blink',
    );
    expect(
      feed(session, [face(eyes: 0.1)], start: 300),
      FaceChallengeEvent.inProgress,
    );
    expect(
      feed(session, [face(eyes: 0.95)], start: 400),
      FaceChallengeEvent.completed,
    );
    // Without classification a blink cannot be seen.
    final blind = single(FaceChallenge.blink);
    expect(
      blind.evaluate([
        const FaceObservation(
          box: Rect.fromLTWH(0, 0, 10, 10),
          imageSize: Size(10, 10),
        ),
      ], t0),
      FaceChallengeEvent.inProgress,
    );
  });

  test('runs a sequence step by step and waits without a single face', () {
    final session = FaceChallengeSession(
      pool: [FaceChallenge.smile, FaceChallenge.turnRight],
      randomOrder: false,
      holdFrames: 1,
    );
    expect(session.sequence, [FaceChallenge.smile, FaceChallenge.turnRight]);
    expect(session.current, FaceChallenge.smile);
    expect(session.evaluate([], t0), FaceChallengeEvent.waitingForFace);
    expect(
      session.evaluate([face(), face()], at(50)),
      FaceChallengeEvent.waitingForFace,
    );
    expect(
      feed(session, [face(), face(smiling: 0.9)], start: 100),
      FaceChallengeEvent.stepCompleted,
    );
    expect(session.completedCount, 1);
    expect(session.current, FaceChallenge.turnRight);
    expect(
      feed(session, [face(), face(yaw: -30)], start: 300),
      FaceChallengeEvent.completed,
    );
    expect(session.evaluate([face()], at(600)), FaceChallengeEvent.completed);
  });

  test('picks and shuffles challenges per attempt', () {
    final session = FaceChallengeSession(
      pool: FaceChallenge.values,
      count: 3,
      random: Random(1),
    );
    expect(session.count, 3);
    expect(session.sequence, hasLength(3));
    expect(session.sequence.toSet(), hasLength(3));
    // More than the pool is clamped; duplicates are ignored.
    final small = FaceChallengeSession(
      pool: [FaceChallenge.smile, FaceChallenge.smile],
      count: 5,
    );
    expect(small.sequence, [FaceChallenge.smile]);
  });

  test('times out, starts over with a new attempt, then fails', () {
    final session = FaceChallengeSession(
      pool: FaceChallenge.values,
      count: 2,
      maxAttempts: 2,
      timeout: const Duration(seconds: 1),
      random: Random(7),
    );
    expect(session.evaluate([face()], t0), FaceChallengeEvent.inProgress);
    expect(
      session.evaluate([face()], at(1500)),
      FaceChallengeEvent.timedOut,
    );
    expect(session.attempt, 2);
    expect(session.completedCount, 0);
    expect(session.evaluate([face()], at(1600)), FaceChallengeEvent.inProgress);
    expect(session.evaluate([face()], at(3000)), FaceChallengeEvent.failed);
    expect(session.isFailed, isTrue);
    expect(session.current, isNull);
    expect(session.evaluate([face()], at(3100)), FaceChallengeEvent.failed);

    session.restart();
    expect(session.isFailed, isFalse);
    expect(session.attempt, 1);
    expect(session.current, isNotNull);
  });
}
