import 'package:ekyc_nfc_reader/ekyc_nfc_reader.dart';
import 'package:ekyc_nfc_reader/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('a slow virtual session still reads the document', () async {
    final doc = TestDocument();
    final session = VirtualNfcSession(
      key: specimenKey,
      files: doc.files,
      connectDelay: const Duration(milliseconds: 1),
      commandDelay: const Duration(microseconds: 1),
    );
    final data = await ChipReader(
      session: session,
      trustStore: doc.trustStore,
    ).read(specimenKey);
    expect(data.passiveAuth.status, PassiveAuthStatus.verified);
    // The default (English) iOS sheet texts are used.
    expect(session.messages, [
      const ChipReadMessages().prompt,
      const ChipReadMessages().reading,
    ]);
    expect(session.closed, isTrue);
  });

  test('errors say whether retrying can help', () {
    expect(ChipReadError.nfcNotSupported.isRetryable, isFalse);
    expect(ChipReadError.documentNotAuthentic.isRetryable, isFalse);
    expect(ChipReadError.timeout.isRetryable, isTrue);
    expect(
      const ChipReadException(ChipReadError.timeout).toString(),
      'ChipReadException(timeout)',
    );
  });
}
