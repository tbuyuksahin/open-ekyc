import 'dart:typed_data';

import 'package:ekyc_nfc_reader/testing.dart';
import 'package:ekyc_sdk/ekyc_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class _Live implements LivenessCheck {
  @override
  Future<LivenessOutcome> check(Uint8List selfie) async => LivenessOutcome.live;
}

void main() {
  late TestDocument doc;
  setUpAll(() => doc = TestDocument());

  EkycConfig config({
    List<EkycStep> steps = EkycStep.values,
    MrzKey? mrzKey,
    NfcFailure? connectFailure,
    Map<LdsFile, Uint8List>? files,
    LivenessCheck liveness = const NoLivenessCheck(),
  }) => EkycConfig(
    steps: steps,
    mrzKey: mrzKey,
    liveness: liveness,
    trustStore: doc.trustStore,
    nfcSession: VirtualNfcSession(
      key: specimenKey,
      files: files ?? doc.files,
      connectFailure: connectFailure,
    ),
  );

  final wrongKey = MrzInput.toKey(
    documentNumber: 'X1234567',
    dateOfBirth: DateTime(1974, 8, 12),
    dateOfExpiry: DateTime(2032, 4, 15),
  )!;
  final selfie = FaceCaptureResult(image: Uint8List.fromList([1, 2, 3]));

  test('runs MRZ, NFC and selfie and hands over the result', () async {
    final c = EkycFlowController(config());
    final stages = <EkycStage>[];
    c.addListener(() => stages.add(c.stage));
    expect(c.stage, isA<EkycMrzStage>());
    await c.start();
    await c.submitMrz(specimenKey);
    final chip = stages.whereType<EkycChipStage>().toList();
    expect(chip.first.step, ChipReadStep.waitingForCard);
    expect(chip.last.progress, 1);
    expect(c.stage, isA<EkycFaceStage>());

    await c.faceCaptured(selfie);
    final result = (c.stage as EkycDoneStage).result;
    expect(result.mrzKey, specimenKey);
    expect(result.document!.passiveAuth.status, PassiveAuthStatus.verified);
    expect(result.selfie, [1, 2, 3]);
    expect(result.liveness, LivenessOutcome.notPerformed);
    expect(result.toString(), isNot(contains('ERIKSSON')));

    // The host owns the data after completion; disposing leaves it.
    c.dispose();
    expect(result.document!.isWiped, isFalse);
    result.wipe();
    expect(result.document!.isWiped, isTrue);
    expect(result.selfie, [0, 0, 0]);
  });

  test('completed movements are reported, a provider overrides them', () async {
    final moved = FaceCaptureResult(
      image: Uint8List(2),
      challenges: const [FaceChallenge.smile],
    );
    final a = EkycFlowController(config(steps: [EkycStep.face]));
    expect(a.stage, isA<EkycFaceStage>());
    await a.faceCaptured(moved);
    final result = (a.stage as EkycDoneStage).result;
    expect(result.liveness, LivenessOutcome.challengesPassed);
    expect(result.challenges, [FaceChallenge.smile]);
    expect(result.document, isNull);

    final b = EkycFlowController(
      config(steps: [EkycStep.face], liveness: _Live()),
    );
    await b.faceCaptured(moved);
    expect((b.stage as EkycDoneStage).result.liveness, LivenessOutcome.live);
  });

  test('a single MRZ step returns just the key', () async {
    final c = EkycFlowController(config(steps: [EkycStep.mrz]));
    await c.submitMrz(specimenKey);
    final result = (c.stage as EkycDoneStage).result;
    expect(result.mrzKey, specimenKey);
    expect(result.document, isNull);
    expect(result.selfie, isNull);
  });

  test('a wrong key goes back to the MRZ step with the values kept', () async {
    final c = EkycFlowController(config());
    await c.submitMrz(wrongKey);
    final stage = c.stage as EkycMrzStage;
    expect(stage.error, ChipReadError.wrongMrz);
    expect(stage.prefill, wrongKey);
  });

  test('other failures stay on the chip step and can be retried or '
      'edited', () async {
    final c = EkycFlowController(
      config(connectFailure: NfcFailure.timeout),
    );
    await c.submitMrz(specimenKey);
    expect((c.stage as EkycChipStage).error, ChipReadError.timeout);
    await c.retryChip();
    expect((c.stage as EkycChipStage).error, ChipReadError.timeout);
    c.editMrz();
    expect((c.stage as EkycMrzStage).prefill, specimenKey);
    // Retry and edit do nothing outside the chip step.
    await c.retryChip();
    c.editMrz();
    expect(c.stage, isA<EkycMrzStage>());
  });

  test('NFC alone starts reading with the given key', () async {
    final c = EkycFlowController(
      config(steps: [EkycStep.nfc], mrzKey: specimenKey),
    );
    await c.start();
    final result = (c.stage as EkycDoneStage).result;
    expect(result.document!.mrz.documentNumber, 'L898902C3');

    // Without the MRZ step a wrong key is a chip error, and there is no
    // form to go back to.
    final wrong = EkycFlowController(
      config(steps: [EkycStep.nfc], mrzKey: wrongKey),
    );
    await wrong.start();
    expect((wrong.stage as EkycChipStage).error, ChipReadError.wrongMrz);
    wrong.editMrz();
    expect(wrong.stage, isA<EkycChipStage>());
  });

  test('rejects configurations that cannot run', () {
    expect(
      () => EkycFlowController(const EkycConfig(steps: [])),
      throwsArgumentError,
    );
    expect(
      () => EkycFlowController(const EkycConfig(steps: [EkycStep.nfc])),
      throwsArgumentError,
    );
  });

  test(
    'a selfie that arrives after disposal is wiped, not delivered',
    () async {
      final image = Uint8List.fromList([9, 9]);
      final c = EkycFlowController(config(steps: [EkycStep.face]))..dispose();
      await c.faceCaptured(FaceCaptureResult(image: image));
      expect(c.stage, isA<EkycFaceStage>());
    },
  );

  test('a read that finishes after disposal is wiped', () async {
    final c = EkycFlowController(config());
    final reading = c.submitMrz(specimenKey);
    c.dispose();
    await reading;
    expect(c.stage, isNot(isA<EkycDoneStage>()));
  });
}
