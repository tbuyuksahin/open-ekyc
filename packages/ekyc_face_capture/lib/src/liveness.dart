import 'dart:typed_data';

/// Outcome of a presentation attack (liveness) check.
enum LivenessOutcome {
  /// A live person.
  live,

  /// A photo, screen, mask or other presentation attack.
  spoof,

  /// The user completed randomized active challenges (head turns,
  /// smile, blink). Stops photos and static screens, but is weaker than
  /// certified presentation attack detection.
  challengesPassed,

  /// No check was performed.
  notPerformed,
}

/// Decides whether a selfie comes from a live person rather than a photo,
/// screen or mask.
///
/// Plug in a certified provider (ISO/IEC 30107-3 tested) or an active
/// challenge flow. [NoLivenessCheck] performs none and says so: head-angle
/// or blink heuristics alone are easy to fool and must not be presented as
/// liveness.
// One method today; providers usually add session setup later.
// ignore: one_member_abstracts
abstract interface class LivenessCheck {
  /// Checks [selfie].
  Future<LivenessOutcome> check(Uint8List selfie);
}

/// Performs no liveness check and reports that honestly.
class NoLivenessCheck implements LivenessCheck {
  /// Creates the no-op check.
  const NoLivenessCheck();

  @override
  Future<LivenessOutcome> check(Uint8List selfie) async =>
      LivenessOutcome.notPerformed;
}
