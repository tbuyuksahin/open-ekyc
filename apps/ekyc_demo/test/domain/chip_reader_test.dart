import 'package:ekyc_demo/core/app_log.dart';
import 'package:ekyc_demo/kyc/domain/chip_reader.dart';
import 'package:ekyc_demo/kyc/domain/kyc_error.dart';
import 'package:ekyc_demo/kyc/domain/nfc_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icao_mrtd/icao_mrtd.dart';
import 'package:icao_mrz/icao_mrz.dart';

import '../helpers.dart';

const messages = ChipReadMessages(
  prompt: 'prompt',
  reading: 'reading',
  done: 'done',
  failed: 'failed',
);

void main() {
  late TestDocument doc;
  final logged = <String, Map<String, Object>>{};
  setUpAll(() {
    doc = TestDocument();
    AppLog.sink = (e, f) => logged[e] = f;
  });
  tearDownAll(() => AppLog.sink = null);

  Matcher failsWith(KycError error) => throwsA(
    isA<ChipReadException>().having((e) => e.error, 'error', error),
  );

  test('reads, parses and verifies a document', () async {
    final session = FakeNfcSession(doc.files);
    final steps = <ChipReadStep>[];
    final fractions = <double>[];
    final data =
        await ChipReader(
          session: session,
          trustStore: doc.trustStore,
        ).read(
          specimenKey,
          messages: messages,
          onProgress: (s, f) {
            steps.add(s);
            fractions.add(f);
          },
        );
    expect(data.mrz.documentNumber, 'L898902C3');
    expect(data.surname, 'ERİKSSON');
    expect(data.givenNames, 'ANNA MARİA');
    expect(data.passiveAuth.status, PassiveAuthStatus.verified);
    expect(data.rawFiles.keys, containsAll([LdsFile.dg1, LdsFile.sod]));
    expect(steps.first, ChipReadStep.waitingForCard);
    expect(steps.last, ChipReadStep.verifying);
    expect(fractions, orderedEquals([...fractions]..sort()));
    expect(session.messages, ['prompt', 'reading']);
    expect(session.closedWithError, isNull);
    expect(logged['chip_read'], {'passive_auth': 'verified', 'dg11': true});
  });

  test('DG11 is optional; names then come from the MRZ', () async {
    final noDg11 = TestDocument(withDg11: false);
    final data = await ChipReader(
      session: FakeNfcSession(noDg11.files),
      trustStore: noDg11.trustStore,
    ).read(specimenKey, messages: messages);
    expect(data.dg11, isNull);
    expect(data.surname, 'ERIKSSON');
  });

  test('without a trust anchor the result is untrusted, not failed', () async {
    final data = await ChipReader(
      session: FakeNfcSession(doc.files),
      trustStore: CscaStore.empty(),
    ).read(specimenKey, messages: messages);
    expect(data.passiveAuth.status, PassiveAuthStatus.untrusted);
  });

  test('a tampered data group is reported as not authentic', () async {
    final forged = TestDocument(tamperDg1: true);
    final session = FakeNfcSession(forged.files);
    await expectLater(
      ChipReader(
        session: session,
        trustStore: forged.trustStore,
      ).read(specimenKey, messages: messages),
      failsWith(KycError.documentNotAuthentic),
    );
    expect(session.closedWithError, 'failed');
  });

  test('maps protocol and platform failures to user errors', () async {
    final wrongKey = MrzKey(
      documentNumber: 'X1234567',
      dateOfBirth: const MrzDate('740812'),
      dateOfExpiry: const MrzDate('120415'),
    );
    final cases = <(FakeNfcSession, MrzKey, KycError)>[
      (FakeNfcSession(doc.files), wrongKey, KycError.wrongMrz),
      (
        FakeNfcSession(doc.files, nfcStatus: NfcStatus.disabled),
        specimenKey,
        KycError.nfcDisabled,
      ),
      (
        FakeNfcSession(doc.files, nfcStatus: NfcStatus.notSupported),
        specimenKey,
        KycError.nfcNotSupported,
      ),
      (
        FakeNfcSession(doc.files, connectFailure: NfcFailure.timeout),
        specimenKey,
        KycError.timeout,
      ),
      (
        FakeNfcSession(doc.files, connectFailure: NfcFailure.cancelled),
        specimenKey,
        KycError.cancelled,
      ),
      (
        FakeNfcSession(doc.files, connectFailure: NfcFailure.tagLost),
        specimenKey,
        KycError.tagLost,
      ),
      (
        FakeNfcSession(doc.files, connectFailure: NfcFailure.unavailable),
        specimenKey,
        KycError.nfcDisabled,
      ),
      (
        FakeNfcSession(doc.files, connectFailure: NfcFailure.other),
        specimenKey,
        KycError.unknown,
      ),
      (
        FakeNfcSession({...doc.files}..remove(LdsFile.sod)),
        specimenKey,
        KycError.unknown,
      ),
    ];
    for (final (session, key, error) in cases) {
      await expectLater(
        ChipReader(
          session: session,
          trustStore: doc.trustStore,
        ).read(key, messages: messages),
        failsWith(error),
        reason: error.name,
      );
    }
    expect(logged['chip_read_failed'], {'error': 'unknown'});
  });

  test('a card that leaves the field mid-read is not a crash', () async {
    await expectLater(
      ChipReader(
        session: FakeNfcSession(doc.files, loseTagAfter: 8),
        trustStore: doc.trustStore,
      ).read(specimenKey, messages: messages),
      failsWith(KycError.unknown),
    );
  });

  test('wiping clears the portrait and raw files', () async {
    final data = await ChipReader(
      session: FakeNfcSession(doc.files),
      trustStore: doc.trustStore,
    ).read(specimenKey, messages: messages);
    data.wipe();
    expect(data.isWiped, isTrue);
    expect(data.face.bytes.every((b) => b == 0), isTrue);
    expect(
      data.rawFiles.values.every((f) => f.every((b) => b == 0)),
      isTrue,
    );
    expect(data.toString(), isNot(contains('ERIKSSON')));
  });
}
