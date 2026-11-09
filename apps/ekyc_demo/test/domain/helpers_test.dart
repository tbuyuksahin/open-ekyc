import 'dart:typed_data';
import 'dart:ui';

import 'package:ekyc_demo/kyc/data/fake_kyc_repository.dart';
import 'package:ekyc_demo/kyc/domain/face_quality.dart';
import 'package:ekyc_demo/kyc/domain/kyc_repository.dart';
import 'package:ekyc_demo/kyc/domain/liveness.dart';
import 'package:ekyc_demo/kyc/domain/masking.dart';
import 'package:ekyc_demo/kyc/domain/mrz_input.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icao_mrtd/icao_mrtd.dart';

void main() {
  group('MrzInput', () {
    test('normalizes and validates document numbers', () {
      expect(MrzInput.normalizeNumber(' a12 34b '), 'A1234B');
      expect(MrzInput.isValidNumber('A12-3'), isFalse);
      expect(MrzInput.isValidNumber(''), isFalse);
      expect(MrzInput.isValidNumber('U12345678'), isTrue);
    });

    test('parses only real dates', () {
      expect(MrzInput.parseDate('08.01.1995'), DateTime(1995, 1, 8));
      expect(MrzInput.parseDate('31.02.1995'), isNull);
      expect(MrzInput.parseDate('1995-01-08'), isNull);
      expect(MrzInput.formatDate(DateTime(2029, 10, 8)), '08.10.2029');
    });

    test('builds the BAC key', () {
      final key = MrzInput.toKey(
        documentNumber: 'l898902c',
        dateOfBirth: DateTime(1969, 8, 6),
        dateOfExpiry: DateTime(1994, 6, 23),
      );
      expect(key?.information, 'L898902C<369080619406236');
      expect(
        MrzInput.toKey(
          documentNumber: 'X',
          dateOfBirth: null,
          dateOfExpiry: DateTime(2030),
        ),
        isNull,
      );
    });
  });

  test('maskMiddle hides the middle of a value', () {
    expect(maskMiddle('L898902C3'), 'L8•••••C3');
    expect(maskMiddle('AB12'), '••••');
  });

  group('FaceQualityGate', () {
    const size = Size(480, 640);
    FaceObservation face({
      Rect box = const Rect.fromLTWH(120, 180, 240, 280),
      double yaw = 0,
      double eyes = 0.9,
    }) => FaceObservation(
      box: box,
      imageSize: size,
      yaw: yaw,
      roll: 0,
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
      expect(gate.evaluate([face(eyes: 0.1)]), FaceHint.openEyes);
    });

    test('fires only after consecutive good frames', () {
      final gate = FaceQualityGate(requiredStableFrames: 3);
      expect(gate.evaluate([face()]), FaceHint.holdStill);
      expect(gate.evaluate([face()]), FaceHint.holdStill);
      expect(gate.evaluate([face(yaw: 30)]), FaceHint.lookStraight);
      expect(gate.evaluate([face()]), FaceHint.holdStill);
      expect(gate.evaluate([face()]), FaceHint.holdStill);
      expect(gate.evaluate([face()]), isNull);
    });
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
