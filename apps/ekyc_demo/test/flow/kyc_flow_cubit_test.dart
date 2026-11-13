import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:ekyc_demo/kyc/domain/kyc_error.dart';
import 'package:ekyc_demo/kyc/domain/kyc_repository.dart';
import 'package:ekyc_demo/kyc/flow/kyc_flow_cubit.dart';
import 'package:ekyc_demo/kyc/flow/kyc_flow_state.dart';
import 'package:ekyc_demo/kyc/flow/kyc_services.dart';
import 'package:ekyc_nfc_reader/testing.dart';
import 'package:ekyc_sdk/ekyc_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

class _MockRepository extends Mock implements KycRepository {}

class _FakeSubmission extends Fake implements KycSubmission {}

class _ErrorReader extends ChipReader {
  _ErrorReader(this.error)
    : super(
        session: VirtualNfcSession(key: specimenKey, files: const {}),
        trustStore: _empty,
      );

  final ChipReadError error;

  @override
  Future<Never> read(
    MrzKey key, {
    ChipReadMessages messages = const ChipReadMessages(),
    ChipReadProgress? onProgress,
  }) async => throw ChipReadException(error);
}

final CscaStore _empty = TestDocument().trustStore;

void main() {
  setUpAll(() => registerFallbackValue(_FakeSubmission()));

  late TestDocument doc;
  late _MockRepository repo;
  setUp(() {
    doc = TestDocument();
    repo = _MockRepository();
    when(repo.startSession).thenAnswer(
      (_) async => const VerificationSession(id: 'id', token: 'tok'),
    );
    when(() => repo.submit(any())).thenAnswer(
      (_) async => VerificationDecision.approved,
    );
  });

  KycFlowCubit cubit({ChipReader? reader, bool photograph = false}) =>
      KycFlowCubit(
        photographDocument: photograph,
        ({required demo}) async => KycServices(
          chipReader:
              reader ??
              ChipReader(
                session: VirtualNfcSession(key: specimenKey, files: doc.files),
                trustStore: doc.trustStore,
              ),
          repository: repo,
          demoKey: demo ? specimenKey : null,
        ),
      );

  final selfie = Uint8List.fromList([1, 2, 3]);

  test('completed movement challenges are reported, not called live', () async {
    final c = cubit();
    await c.start(demo: false);
    await c.readChip(specimenKey, messages);
    await c.faceCaptured(
      selfie,
      challenges: const [FaceChallenge.smile, FaceChallenge.turnLeft],
    );
    expect(
      (c.state as ReviewStep).liveness,
      LivenessOutcome.challengesPassed,
    );
    await c.close();
  });

  test('happy path from consent to an approved result', () async {
    final c = cubit();
    final states = <KycFlowState>[];
    final sub = c.stream.listen(states.add);
    await c.start(demo: false);
    await c.readChip(specimenKey, messages);
    await c.faceCaptured(selfie);
    await c.submit();
    // Cubit streams deliver asynchronously; let the last events arrive.
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(states.take(2), [const ConsentStep(loading: true), const MrzStep()]);
    final progress = states.whereType<ChipStep>().map((s) => s.progress);
    expect(progress.length, greaterThan(5));
    expect(progress, orderedEquals([...progress]..sort()));
    expect(states.whereType<FaceStep>(), hasLength(1));
    expect(states.whereType<ReviewStep>().map((s) => s.submitting), [
      false,
      true,
    ]);
    expect(states.last, const ResultStep(VerificationDecision.approved));

    final sent =
        verify(() => repo.submit(captureAny())).captured.single
            as KycSubmission;
    expect(sent.session.token, 'tok');
    expect(sent.liveness, LivenessOutcome.notPerformed);
    // Everything was wiped after submission.
    expect(sent.selfie.every((b) => b == 0), isTrue);
    expect(sent.chipFiles.values.every((f) => f.every((b) => b == 0)), isTrue);
    await c.close();
  });

  blocTest<KycFlowCubit, KycFlowState>(
    'demo mode prefills the specimen key',
    build: cubit,
    act: (c) => c.start(demo: true),
    expect: () => [
      const ConsentStep(loading: true),
      MrzStep(prefill: specimenKey, isDemo: true),
    ],
  );

  blocTest<KycFlowCubit, KycFlowState>(
    'a rejected MRZ key returns to the form with the error',
    build: () => cubit(reader: _ErrorReader(ChipReadError.wrongMrz)),
    act: (c) async {
      await c.start(demo: false);
      await c.readChip(specimenKey, messages);
    },
    skip: 3,
    expect: () => [MrzStep(prefill: specimenKey, error: KycError.wrongMrz)],
  );

  blocTest<KycFlowCubit, KycFlowState>(
    'other read errors offer retry and editing',
    build: () => cubit(reader: _ErrorReader(ChipReadError.tagLost)),
    act: (c) async {
      await c.start(demo: false);
      await c.readChip(specimenKey, messages);
      c.editMrz();
    },
    skip: 3,
    expect: () => [
      ChipErrorStep(key: specimenKey, error: KycError.tagLost),
      MrzStep(prefill: specimenKey),
    ],
  );

  blocTest<KycFlowCubit, KycFlowState>(
    'a failed submission keeps the review and shows the error',
    build: cubit,
    setUp: () => when(() => repo.submit(any())).thenThrow(
      const KycRepositoryException('down'),
    ),
    act: (c) async {
      await c.start(demo: false);
      await c.readChip(specimenKey, messages);
      await c.faceCaptured(selfie);
      await c.submit();
    },
    verify: (c) {
      final state = c.state as ReviewStep;
      expect(state.error, KycError.submissionFailed);
      expect(state.submitting, isFalse);
    },
  );

  test('retaking the selfie wipes the old one; restart wipes all', () async {
    final c = cubit();
    await c.start(demo: false);
    await c.readChip(specimenKey, messages);
    final face = c.state as FaceStep;
    await c.faceCaptured(selfie);
    final review = c.state as ReviewStep;
    c.retakeFace();
    expect(review.selfie.every((b) => b == 0), isTrue);
    expect(selfie, [1, 2, 3], reason: 'caller buffer untouched');
    expect(c.state, isA<FaceStep>());
    c.restart();
    expect(c.state, const ConsentStep());
    expect(face.document.isWiped, isTrue);
    await c.close();
  });

  test('closing mid-flow wipes collected data', () async {
    final c = cubit();
    await c.start(demo: false);
    await c.readChip(specimenKey, messages);
    final face = c.state as FaceStep;
    await c.close();
    expect(face.document.isWiped, isTrue);
  });

  group('document photo', () {
    DocumentCaptureResult photos({bool withMrz = true}) =>
        DocumentCaptureResult(
          kind: DocumentKind.passport,
          images: {
            DocumentSide.front: Uint8List.fromList([5, 5]),
          },
          frontText: const ['ERIKSSON', 'ANNA MARIA', 'L898902C3'],
          mrz: withMrz ? Mrz.parse(specimenMrz) : null,
        );

    test('comes first and its MRZ opens the chip', () async {
      final c = cubit(photograph: true);
      await c.start(demo: false);
      expect(c.state, const DocumentStep());
      final capture = photos();
      await c.documentCaptured(capture, messages);
      expect(c.state, isA<FaceStep>());
      await c.faceCaptured(selfie);
      final review = c.state as ReviewStep;
      expect(review.crossCheck!.found, hasLength(3));
      expect(review.copyWith(submitting: true).crossCheck, review.crossCheck);

      await c.submit();
      final sent =
          verify(() => repo.submit(captureAny())).captured.single
              as KycSubmission;
      expect(sent.documentPhotos.keys, [DocumentSide.front]);
      expect(sent.toJson()['documentPhotos'], {'front': 'AAA='});
      // Wiped after submission.
      expect(capture.front, [0, 0]);
      await c.close();
    });

    test('falls back to the MRZ step when the MRZ was not read', () async {
      final c = cubit(photograph: true);
      await c.start(demo: false);
      final first = photos(withMrz: false);
      await c.documentCaptured(first, messages);
      expect(c.state, const MrzStep());
      // A capture that arrives outside the document step is discarded.
      final stray = photos();
      await c.documentCaptured(stray, messages);
      expect(stray.front, [0, 0]);
      expect(c.state, const MrzStep());
      c.restart();
      expect(first.front, [0, 0]);
      await c.close();
    });

    test('is skipped in demo mode', () async {
      final c = cubit(photograph: true);
      await c.start(demo: true);
      expect(c.state, isA<MrzStep>());
      await c.close();
    });
  });
}
