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
    List<EkycStep> steps = EkycStep.standard,
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

  group('document photo step', () {
    const all = [
      EkycStep.document,
      EkycStep.mrz,
      EkycStep.nfc,
      EkycStep.face,
    ];

    DocumentCaptureResult photos({bool withMrz = true}) =>
        DocumentCaptureResult(
          kind: DocumentKind.passport,
          images: {
            DocumentSide.front: Uint8List.fromList([9, 9, 9]),
          },
          frontText: const ['ERIKSSON', 'ANNA MARIA', 'L898902C3'],
          mrz: withMrz ? Mrz.parse(specimenMrz) : null,
        );

    test('comes first, and its MRZ opens the chip without typing', () async {
      final c = EkycFlowController(config(steps: all));
      expect(c.stage, isA<EkycDocumentStage>());
      await c.start();
      final capture = photos();
      await c.documentCaptured(capture);
      expect(c.stage, isA<EkycFaceStage>());

      await c.faceCaptured(selfie);
      final result = (c.stage as EkycDoneStage).result;
      expect(result.mrzKey, specimenKey);
      expect(result.documentPhotos, same(capture));
      expect(result.document!.passiveAuth.status, PassiveAuthStatus.verified);
      // Compared with the chip: number and names are printed, dates not.
      expect(result.crossCheck!.found, [
        DocumentField.documentNumber,
        DocumentField.surname,
        DocumentField.givenNames,
      ]);
      expect(result.crossCheck!.missing, [
        DocumentField.dateOfBirth,
        DocumentField.dateOfExpiry,
      ]);

      final front = capture.front!;
      result.wipe();
      expect(front, [0, 0, 0]);
    });

    test(
      'asks for the MRZ when it was not read or must be confirmed',
      () async {
        final unread = EkycFlowController(config(steps: all));
        await unread.documentCaptured(photos(withMrz: false));
        expect(unread.stage, isA<EkycMrzStage>());

        final confirm = EkycFlowController(
          config(steps: all).copyWith(
            document: const EkycDocumentOptions(skipMrzWhenRead: false),
          ),
        );
        await confirm.documentCaptured(photos());
        expect(confirm.stage, isA<EkycMrzStage>());
      },
    );

    test('a key the chip rejects goes to the MRZ step', () async {
      final c = EkycFlowController(config(steps: all));
      await c.documentCaptured(
        DocumentCaptureResult(
          kind: DocumentKind.idCard,
          images: const {},
          mrz: Mrz.parse(const [
            'I<UTOD231458907<<<<<<<<<<<<<<<',
            '7408122F1204159UTO<<<<<<<<<<<6',
            'ERIKSSON<<ANNA<MARIA<<<<<<<<<<',
          ]),
        ),
      );
      final stage = c.stage as EkycMrzStage;
      expect(stage.error, ChipReadError.wrongMrz);
      expect(stage.prefill!.documentNumber, 'D23145890');
    });

    test('on its own it checks the front against its own MRZ', () async {
      final c = EkycFlowController(
        config(steps: const [EkycStep.document]),
      );
      await c.documentCaptured(photos());
      final result = (c.stage as EkycDoneStage).result;
      expect(result.document, isNull);
      expect(result.mrzKey, isNull);
      expect(result.crossCheck!.fields[DocumentField.surname], isTrue);

      final bare = EkycFlowController(
        config(steps: const [EkycStep.document]),
      );
      await bare.documentCaptured(photos(withMrz: false));
      expect((bare.stage as EkycDoneStage).result.crossCheck, isNull);
    });

    test('without an MRZ step the given key reads the chip', () async {
      final c = EkycFlowController(
        config(
          steps: const [EkycStep.document, EkycStep.nfc],
          mrzKey: specimenKey,
        ),
      );
      expect(c.stage, isA<EkycDocumentStage>());
      await c.documentCaptured(photos(withMrz: false));
      final result = (c.stage as EkycDoneStage).result;
      expect(result.document, isNotNull);
      expect(result.crossCheck, isNotNull);
    });

    test('photos are wiped when the flow is abandoned', () async {
      final c = EkycFlowController(config(steps: all));
      final first = photos(withMrz: false);
      final second = photos(withMrz: false);
      await c.documentCaptured(first);
      final a = first.front!;
      // A second capture replaces and wipes the first.
      await c.documentCaptured(second);
      expect(a, [0, 0, 0]);
      final b = second.front!;
      c.dispose();
      expect(b, [0, 0, 0]);

      final late = photos();
      final bytes = late.front!;
      await c.documentCaptured(late);
      expect(bytes, [0, 0, 0]);
    });
  });
}
