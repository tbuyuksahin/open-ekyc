import 'dart:typed_data';

import 'package:ekyc_demo/kyc/data/fake_kyc_repository.dart';
import 'package:ekyc_demo/kyc/domain/kyc_repository.dart';
import 'package:ekyc_demo/kyc/domain/masking.dart';
import 'package:ekyc_sdk/ekyc_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maskMiddle hides the middle of a value', () {
    expect(maskMiddle('L898902C3'), 'L8•••••C3');
    expect(maskMiddle('AB12'), '••••');
  });

  group('FakeKycRepository and KycSubmission', () {
    KycSubmission submission({
      PassiveAuthStatus pa = PassiveAuthStatus.verified,
      LivenessOutcome liveness = LivenessOutcome.live,
      bool withSod = true,
    }) => KycSubmission(
      session: const VerificationSession(id: 's1', token: 't'),
      chipFiles: {
        LdsFile.dg1: Uint8List.fromList([1, 2]),
        if (withSod) LdsFile.sod: Uint8List.fromList([3]),
      },
      selfie: Uint8List.fromList([9]),
      liveness: liveness,
      clientPassiveAuth: pa,
    );

    test('serializes raw files for server-side verification', () {
      final json = submission().toJson();
      expect(json['sessionId'], 's1');
      expect(json['chip'], {'dg1': 'AQI=', 'sod': 'Aw=='});
      expect(json.containsKey('token'), isFalse);
      expect(submission().toString(), contains('<redacted>'));
    });

    test('decides like a cautious server', () async {
      final repo = FakeKycRepository(latency: Duration.zero);
      final session = await repo.startSession();
      expect(session.id, startsWith('demo-'));
      expect(await repo.submit(submission()), VerificationDecision.approved);
      expect(
        await repo.submit(submission(liveness: LivenessOutcome.notPerformed)),
        VerificationDecision.manualReview,
      );
      expect(
        await repo.submit(submission(pa: PassiveAuthStatus.untrusted)),
        VerificationDecision.manualReview,
      );
      expect(
        await repo.submit(submission(liveness: LivenessOutcome.spoof)),
        VerificationDecision.rejected,
      );
      await expectLater(
        repo.submit(submission(withSod: false)),
        throwsA(isA<KycRepositoryException>()),
      );
      expect(
        await const NoLivenessCheck().check(Uint8List(1)),
        LivenessOutcome.notPerformed,
      );
    });
  });
}
