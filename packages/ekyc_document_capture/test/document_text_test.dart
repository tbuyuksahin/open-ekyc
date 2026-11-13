import 'dart:typed_data';

import 'package:ekyc_document_capture/ekyc_document_capture.dart';
import 'package:flutter_test/flutter_test.dart';

const td1 = [
  'I<UTOD231458907<<<<<<<<<<<<<<<',
  '7408122F1204159UTO<<<<<<<<<<<6',
  'ERIKSSON<<ANNA<MARIA<<<<<<<<<<',
];

const front = [
  'UTOPIA IDENTITY CARD',
  'Surname / Nom',
  'Eriksson',
  'Given names / Prénoms',
  'Anna María',
  'Date of birth  12.08.1974',
  'Document No.  D23145890',
  'Valid until 15/04/2012',
];

void main() {
  final now = DateTime(2011);
  final mrz = Mrz.parse(td1);

  group('DocumentFields.fromMrz', () {
    test('takes the comparable values of the MRZ', () {
      final f = DocumentFields.fromMrz(mrz, now: now);
      expect(f.documentNumber, 'D23145890');
      expect(f.surname, 'ERIKSSON');
      expect(f.givenNames, 'ANNA MARIA');
      expect(f.dateOfBirth, DateTime(1974, 8, 12));
      expect(f.dateOfExpiry, DateTime(2012, 4, 15));
      expect(f.personalNumber, isNull);
    });

    test('uses all-digit optional data as the personal number', () {
      final card = Mrz.parse(const [
        'I<UTOD23145890712345678901<<<<',
        '7408122F1204159UTO<<<<<<<<<<<0',
        'ERIKSSON<<ANNA<MARIA<<<<<<<<<<',
      ]);
      final f = DocumentFields.fromMrz(card, now: now);
      expect(f.personalNumber, '12345678901');
    });
  });

  group('DocumentCrossCheck.compare', () {
    test('finds every field despite case, accents and separators', () {
      final check = DocumentCrossCheck.compare(
        printedText: front,
        expected: DocumentFields.fromMrz(mrz, now: now),
      );
      expect(check.fields.keys, [
        DocumentField.documentNumber,
        DocumentField.surname,
        DocumentField.givenNames,
        DocumentField.dateOfBirth,
        DocumentField.dateOfExpiry,
      ]);
      expect(check.allFound, isTrue);
      expect(check.score, 1);
      expect(check.missing, isEmpty);
      expect(check.toString(), 'DocumentCrossCheck(found: 5/5)');
    });

    test('reports the fields that differ', () {
      final check = DocumentCrossCheck.compare(
        printedText: front,
        expected: DocumentFields(
          documentNumber: 'X99999999',
          surname: 'Eriksson',
          givenNames: 'Anna Karin',
          dateOfBirth: DateTime(1974, 8, 13),
        ),
      );
      expect(check.found, [DocumentField.surname]);
      expect(check.missing, [
        DocumentField.documentNumber,
        DocumentField.givenNames,
        DocumentField.dateOfBirth,
      ]);
      expect(check.allFound, isFalse);
      expect(check.score, 0.25);
    });

    test('tolerates common OCR confusions in numbers only', () {
      final check = DocumentCrossCheck.compare(
        printedText: const ['No: D2314S89O', 'ER1KSSON'],
        expected: const DocumentFields(
          documentNumber: 'D23145890',
          surname: 'ERIKSSON',
        ),
      );
      expect(check.fields[DocumentField.documentNumber], isTrue);
      expect(check.fields[DocumentField.surname], isFalse);
    });

    test('folds Turkish letters and reads ISO dates', () {
      final check = DocumentCrossCheck.compare(
        printedText: const [
          'ÖZTÜRK',
          'Işıl Çağla',
          '1990-03-07',
          '12345678901',
        ],
        expected: DocumentFields(
          surname: 'OZTURK',
          givenNames: 'ISIL CAGLA',
          dateOfBirth: DateTime(1990, 3, 7),
          personalNumber: '12345678901',
        ),
      );
      expect(check.allFound, isTrue);
    });

    test('a name must match whole words, not parts of words', () {
      final check = DocumentCrossCheck.compare(
        printedText: const ['MARIANNE'],
        expected: const DocumentFields(givenNames: 'ANNA'),
      );
      expect(check.fields[DocumentField.givenNames], isFalse);
    });

    test('compares nothing when nothing is expected', () {
      final check = DocumentCrossCheck.compare(
        printedText: front,
        expected: const DocumentFields(surname: ' ', documentNumber: ''),
      );
      expect(check.fields, isEmpty);
      expect(check.allFound, isFalse);
      expect(check.score, 0);
    });
  });

  group('DocumentCaptureResult', () {
    DocumentCaptureResult result({List<String> text = front, Mrz? mrz}) =>
        DocumentCaptureResult(
          kind: DocumentKind.idCard,
          images: {
            DocumentSide.front: Uint8List.fromList([1, 2, 3]),
            DocumentSide.back: Uint8List.fromList([4, 5]),
          },
          frontText: text,
          mrz: mrz,
        );

    test('checks the front against its own MRZ by default', () {
      final r = result(mrz: mrz);
      expect(r.crossCheck(now: now)!.allFound, isTrue);
      expect(
        r
            .crossCheck(expected: const DocumentFields(surname: 'OTHER'))!
            .allFound,
        isFalse,
      );
    });

    test('has nothing to check without an MRZ or without text', () {
      expect(result().crossCheck(), isNull);
      expect(result(text: const [], mrz: mrz).crossCheck(), isNull);
    });

    test('wipe zeroes the photos and forgets the text', () {
      final r = result(mrz: mrz);
      final front = r.front!;
      final back = r.back!;
      expect(r.frontText, hasLength(8));
      r.wipe();
      expect(front, [0, 0, 0]);
      expect(back, [0, 0]);
      expect(r.frontText, isEmpty);
      expect(r.toString(), 'DocumentCaptureResult(<redacted>)');
    });
  });
}
