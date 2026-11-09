import 'package:icao_mrtd/icao_mrtd.dart';
import 'package:icao_mrtd/testing.dart';
import 'package:icao_mrz/icao_mrz.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  late Document doc;
  setUpAll(() => doc = Document(imageSize: 2000));

  test('reads every file from a virtual chip', () async {
    final reader = MrtdReader(doc.chip());
    await reader.openSession(specimenKey);
    expect(reader.hasSession, isTrue);
    for (final file in doc.files.keys) {
      expect(await reader.readFile(file), doc.files[file], reason: file.name);
    }
    reader.close();
    expect(reader.hasSession, isFalse);
  });

  test('reads large files in chunks and reports progress', () async {
    final reader = MrtdReader(doc.chip(), maxReadLength: 100);
    await reader.openSession(specimenKey);
    final progress = <int>[];
    final dg2 = await reader.readFile(
      LdsFile.dg2,
      onProgress: (read, total) {
        expect(total, doc.files[LdsFile.dg2]!.length);
        progress.add(read);
      },
    );
    expect(dg2, doc.files[LdsFile.dg2]);
    expect(progress.length, greaterThan(10));
    expect(progress.last, dg2.length);
    expect(progress, orderedEquals([...progress]..sort()));
  });

  test('a wrong MRZ key is reported as access denied', () async {
    final reader = MrtdReader(doc.chip());
    final wrong = MrzKey(
      documentNumber: 'L898902C3',
      dateOfBirth: const MrzDate('740813'),
      dateOfExpiry: const MrzDate('120415'),
    );
    await expectLater(
      reader.openSession(wrong),
      throwsA(isA<AccessDeniedException>()),
    );
  });

  test('a missing file is an ApduException with 6A82', () async {
    final reader = MrtdReader(doc.chip());
    await reader.openSession(specimenKey);
    await expectLater(
      reader.readFile(LdsFile.dg15),
      throwsA(
        isA<ApduException>().having((e) => e.sw, 'sw', StatusWord.fileNotFound),
      ),
    );
    // The session survives and can read other files.
    expect(await reader.readFile(LdsFile.dg1), doc.files[LdsFile.dg1]);
  });

  test('a forged response MAC ends the session', () async {
    final reader = MrtdReader(doc.chip(corruptResponseMac: true));
    await reader.openSession(specimenKey);
    await expectLater(
      reader.readFile(LdsFile.dg1),
      throwsA(isA<SecureMessagingException>()),
    );
    expect(reader.hasSession, isFalse);
  });

  test('transport errors propagate unchanged', () async {
    final reader = MrtdReader(doc.chip(loseTagAfter: 6));
    await reader.openSession(specimenKey);
    await expectLater(
      reader.readFile(LdsFile.dg2),
      throwsA(isA<TagLostException>()),
    );
  });
}
