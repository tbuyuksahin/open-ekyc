import 'package:ekyc_nfc_reader/ekyc_nfc_reader.dart';
import 'package:ekyc_nfc_reader/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icao_mrz/icao_mrz.dart';

import 'helpers.dart';

const messages = ChipReadMessages(
  prompt: 'prompt',
  reading: 'reading',
  done: 'done',
  failed: 'failed',
);

void main() {
  late TestDocument doc;
  setUpAll(() => doc = TestDocument());

  Matcher failsWith(ChipReadError error) => throwsA(
    isA<ChipReadException>().having((e) => e.error, 'error', error),
  );

  test('reads, parses and verifies a document', () async {
    final session = fakeSession(doc.files);
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
  });

  test('DG11 is optional; names then come from the MRZ', () async {
    final noDg11 = TestDocument(withDg11: false);
    final data = await ChipReader(
      session: fakeSession(noDg11.files),
      trustStore: noDg11.trustStore,
    ).read(specimenKey, messages: messages);
    expect(data.dg11, isNull);
    expect(data.surname, 'ERIKSSON');
  });

  test('without a trust anchor the result is untrusted, not failed', () async {
    final data = await ChipReader(
      session: fakeSession(doc.files),
      trustStore: CscaStore.empty(),
    ).read(specimenKey, messages: messages);
    expect(data.passiveAuth.status, PassiveAuthStatus.untrusted);
  });

  test('a tampered data group is reported as not authentic', () async {
    final forged = TestDocument(tamperDg1: true);
    final session = fakeSession(forged.files);
    await expectLater(
      ChipReader(
        session: session,
        trustStore: forged.trustStore,
      ).read(specimenKey, messages: messages),
      failsWith(ChipReadError.documentNotAuthentic),
    );
    expect(session.closedWithError, 'failed');
  });

  test('maps protocol and platform failures to user errors', () async {
    final wrongKey = MrzKey(
      documentNumber: 'X1234567',
      dateOfBirth: const MrzDate('740812'),
      dateOfExpiry: const MrzDate('120415'),
    );
    final cases = <(VirtualNfcSession, MrzKey, ChipReadError)>[
      (fakeSession(doc.files), wrongKey, ChipReadError.wrongMrz),
      (
        fakeSession(doc.files, nfcStatus: NfcStatus.disabled),
        specimenKey,
        ChipReadError.nfcDisabled,
      ),
      (
        fakeSession(doc.files, nfcStatus: NfcStatus.notSupported),
        specimenKey,
        ChipReadError.nfcNotSupported,
      ),
      (
        fakeSession(doc.files, connectFailure: NfcFailure.timeout),
        specimenKey,
        ChipReadError.timeout,
      ),
      (
        fakeSession(doc.files, connectFailure: NfcFailure.cancelled),
        specimenKey,
        ChipReadError.cancelled,
      ),
      (
        fakeSession(doc.files, connectFailure: NfcFailure.tagLost),
        specimenKey,
        ChipReadError.tagLost,
      ),
      (
        fakeSession(doc.files, connectFailure: NfcFailure.unavailable),
        specimenKey,
        ChipReadError.nfcDisabled,
      ),
      (
        fakeSession(doc.files, connectFailure: NfcFailure.other),
        specimenKey,
        ChipReadError.unknown,
      ),
      (
        fakeSession({...doc.files}..remove(LdsFile.sod)),
        specimenKey,
        ChipReadError.unknown,
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
  });

  test('a card that leaves the field mid-read is not a crash', () async {
    await expectLater(
      ChipReader(
        session: fakeSession(doc.files, loseTagAfter: 8),
        trustStore: doc.trustStore,
      ).read(specimenKey, messages: messages),
      failsWith(ChipReadError.unknown),
    );
  });

  test('wiping clears the portrait and raw files', () async {
    final data = await ChipReader(
      session: fakeSession(doc.files),
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
