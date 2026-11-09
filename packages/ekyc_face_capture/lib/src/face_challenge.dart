import 'dart:math';

import 'package:ekyc_face_capture/src/face_quality.dart';
import 'package:flutter/foundation.dart';

/// A movement the user is asked to make in front of the camera.
enum FaceChallenge {
  /// Turn the head to the user's own left.
  turnLeft,

  /// Turn the head to the user's own right.
  turnRight,

  /// Tilt the head up.
  lookUp,

  /// Tilt the head down.
  lookDown,

  /// Smile.
  smile,

  /// Close both eyes and open them again.
  blink,
}

/// Thresholds for recognizing [FaceChallenge]s from ML Kit values.
@immutable
class FaceChallengeThresholds {
  /// Creates thresholds; the defaults work for ML Kit's face detector.
  const FaceChallengeThresholds({
    this.turnAngle = 25,
    this.tiltAngle = 15,
    this.smile = 0.8,
    this.eyesClosed = 0.25,
    this.eyesOpen = 0.6,
    this.yawSign = 1,
    this.pitchSign = 1,
  });

  /// Head yaw, in degrees, that counts as a turn.
  final double turnAngle;

  /// Head pitch, in degrees, that counts as looking up or down.
  final double tiltAngle;

  /// Smiling probability that counts as a smile.
  final double smile;

  /// Eye open probability below which an eye counts as closed.
  final double eyesClosed;

  /// Eye open probability above which an eye counts as open.
  final double eyesOpen;

  /// `1` when a positive yaw means the user turned to their own left,
  /// `-1` when it means right. Depends on how the platform reports the
  /// front camera.
  final double yawSign;

  /// `1` when a positive pitch means looking up, `-1` otherwise.
  final double pitchSign;
}

/// What happened in a frame of a challenge session.
enum FaceChallengeEvent {
  /// No single face in view; the session waits.
  waitingForFace,

  /// The current challenge is not done yet.
  inProgress,

  /// The current challenge was just completed; the next one starts.
  stepCompleted,

  /// All challenges are done.
  completed,

  /// The current challenge took too long; the session starts over.
  timedOut,

  /// Too many timeouts; the session gave up.
  failed,
}

/// Asks for a sequence of head movements and expressions and checks them
/// frame by frame.
///
/// A challenge only counts once its pose was *not* held when it started
/// and is then held for [holdFrames] frames, so a user cannot pass two
/// challenges with one pose. With [randomOrder] the order (and, when
/// [count] is smaller than the pool, the selection) changes on every
/// attempt, which makes replaying a recorded video harder.
///
/// This is an active challenge, not certified presentation attack
/// detection: a live video of the user can pass it.
class FaceChallengeSession {
  /// Creates a session drawing [count] challenges from [pool].
  FaceChallengeSession({
    required List<FaceChallenge> pool,
    int? count,
    this.randomOrder = true,
    this.timeout = const Duration(seconds: 8),
    this.maxAttempts = 3,
    this.holdFrames = 2,
    this.thresholds = const FaceChallengeThresholds(),
    Random? random,
  }) : assert(pool.isNotEmpty, 'Give at least one challenge'),
       _pool = pool.toSet().toList(),
       _random = random ?? Random.secure(),
       count = min(count ?? pool.toSet().length, pool.toSet().length) {
    _shuffle();
  }

  final List<FaceChallenge> _pool;
  final Random _random;

  /// How many challenges are asked per attempt.
  final int count;

  /// Whether to shuffle (and pick) challenges on every attempt.
  final bool randomOrder;

  /// Time allowed for each challenge.
  final Duration timeout;

  /// Attempts before the session fails.
  final int maxAttempts;

  /// Consecutive frames a pose must be held.
  final int holdFrames;

  /// Detection thresholds.
  final FaceChallengeThresholds thresholds;

  List<FaceChallenge> _sequence = const [];
  int _index = 0;
  int _attempt = 1;
  int _held = 0;
  bool _armed = false;
  bool _eyesWereOpen = false;
  bool _eyesWereClosed = false;
  DateTime? _startedAt;
  bool _failed = false;

  /// The challenges of the current attempt, in order.
  List<FaceChallenge> get sequence => List.unmodifiable(_sequence);

  /// The challenge being asked, or `null` when done or failed.
  FaceChallenge? get current =>
      isComplete || _failed ? null : _sequence[_index];

  /// How many challenges of this attempt are done.
  int get completedCount => _index;

  /// The current attempt, starting at 1.
  int get attempt => _attempt;

  /// Whether every challenge was completed.
  bool get isComplete => _index >= _sequence.length;

  /// Whether the session gave up after [maxAttempts] timeouts.
  bool get isFailed => _failed;

  /// Evaluates one frame seen at [now].
  FaceChallengeEvent evaluate(List<FaceObservation> faces, DateTime now) {
    if (_failed) return FaceChallengeEvent.failed;
    if (isComplete) return FaceChallengeEvent.completed;
    final started = _startedAt ??= now;
    if (now.difference(started) > timeout) return _timeOut();
    if (faces.length != 1) {
      _held = 0;
      return FaceChallengeEvent.waitingForFace;
    }
    final face = faces.single;
    final challenge = _sequence[_index];
    final done = challenge == FaceChallenge.blink
        ? _blinked(face)
        : _holds(challenge, face);
    if (!done) return FaceChallengeEvent.inProgress;
    _index++;
    _resetStep(now);
    return isComplete
        ? FaceChallengeEvent.completed
        : FaceChallengeEvent.stepCompleted;
  }

  /// Starts over with a fresh order and a full set of attempts.
  void restart() {
    _attempt = 1;
    _failed = false;
    _shuffle();
  }

  bool _holds(FaceChallenge challenge, FaceObservation face) {
    final t = thresholds;
    final yaw = (face.yaw ?? 0) * t.yawSign;
    final pitch = (face.pitch ?? 0) * t.pitchSign;
    final pose = switch (challenge) {
      FaceChallenge.turnLeft => yaw >= t.turnAngle,
      FaceChallenge.turnRight => yaw <= -t.turnAngle,
      FaceChallenge.lookUp => pitch >= t.tiltAngle,
      FaceChallenge.lookDown => pitch <= -t.tiltAngle,
      FaceChallenge.smile => (face.smiling ?? 0) >= t.smile,
      FaceChallenge.blink => false,
    };
    if (!pose) {
      _armed = true;
      _held = 0;
      return false;
    }
    if (!_armed) return false;
    _held++;
    return _held >= holdFrames;
  }

  bool _blinked(FaceObservation face) {
    final left = face.leftEyeOpen;
    final right = face.rightEyeOpen;
    if (left == null || right == null) return false;
    final t = thresholds;
    if (left >= t.eyesOpen && right >= t.eyesOpen) {
      if (_eyesWereClosed) return true;
      _eyesWereOpen = true;
    } else if (left <= t.eyesClosed && right <= t.eyesClosed) {
      if (_eyesWereOpen) _eyesWereClosed = true;
    }
    return false;
  }

  FaceChallengeEvent _timeOut() {
    if (_attempt >= maxAttempts) {
      _failed = true;
      return FaceChallengeEvent.failed;
    }
    _attempt++;
    _shuffle();
    return FaceChallengeEvent.timedOut;
  }

  void _shuffle() {
    final pool = [..._pool];
    if (randomOrder) pool.shuffle(_random);
    _sequence = pool.take(count).toList();
    _index = 0;
    _resetStep(null);
  }

  void _resetStep(DateTime? now) {
    _startedAt = now;
    _held = 0;
    _armed = false;
    _eyesWereOpen = false;
    _eyesWereClosed = false;
  }
}
