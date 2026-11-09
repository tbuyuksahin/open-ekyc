import 'dart:typed_data';

/// Outcome of a presentation attack (liveness) check.
enum LivenessOutcome { live, spoof, notPerformed }

/// Decides whether a selfie comes from a live person rather than a photo,
/// screen or mask.
///
/// Plug in a certified provider (ISO/IEC 30107-3 tested) or an active
/// challenge flow. The demo ships [NoLivenessCheck] and says so in the UI:
/// head-angle or blink heuristics alone are easy to fool and must not be
/// presented as liveness.
// One method today; providers usually add session setup later.
// ignore: one_member_abstracts
abstract interface class LivenessCheck {
  Future<LivenessOutcome> check(Uint8List selfie);
}

/// Performs no liveness check and reports that honestly.
class NoLivenessCheck implements LivenessCheck {
  const NoLivenessCheck();

  @override
  Future<LivenessOutcome> check(Uint8List selfie) async =>
      LivenessOutcome.notPerformed;
}
