import 'dart:math';

import 'package:ekyc_demo/kyc/domain/kyc_repository.dart';
import 'package:ekyc_face_capture/ekyc_face_capture.dart';
import 'package:icao_mrtd/icao_mrtd.dart';

/// An in-memory stand-in for the verification backend.
///
/// It never sends data anywhere. Its decision rules mirror what a real
/// server should do, except that a real server must re-run Passive
/// Authentication on the raw files instead of reading the client's claim.
class FakeKycRepository implements KycRepository {
  FakeKycRepository({
    this.latency = const Duration(milliseconds: 800),
    Random? random,
  }) : _random = random ?? Random.secure();

  final Duration latency;
  final Random _random;

  /// The last submission received, for tests.
  KycSubmission? lastSubmission;

  String _token() => List.generate(
    16,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  @override
  Future<VerificationSession> startSession() async {
    await Future<void>.delayed(latency);
    return VerificationSession(id: 'demo-${_token()}', token: _token());
  }

  @override
  Future<VerificationDecision> submit(KycSubmission submission) async {
    await Future<void>.delayed(latency);
    lastSubmission = submission;
    if (!submission.chipFiles.containsKey(LdsFile.sod) ||
        submission.selfie.isEmpty) {
      throw const KycRepositoryException('Incomplete submission');
    }
    final authentic =
        submission.clientPassiveAuth == PassiveAuthStatus.verified;
    final live = submission.liveness == LivenessOutcome.live;
    if (submission.liveness == LivenessOutcome.spoof) {
      return VerificationDecision.rejected;
    }
    return authentic && live
        ? VerificationDecision.approved
        : VerificationDecision.manualReview;
  }
}
