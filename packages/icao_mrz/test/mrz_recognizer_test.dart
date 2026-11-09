import 'package:icao_mrz/icao_mrz.dart';
import 'package:test/test.dart';

void main() {
  test('finds a TD3 zone among other OCR text and repairs digits', () {
    const ocr = '''
PASSPORT  PASSEPORT
UTOPIA
P<UTOERIKSSON<<ANNA<MARIA«<<<<<<<<<<<<<<<<<
L898902C36UTO74O8122F12O4l59ZE184226B<<<<<1O
''';
    final mrz = MrzRecognizer.recognize(ocr);
    expect(mrz, isNotNull);
    expect(mrz!.isValid, isTrue);
    expect(mrz.dateOfBirth.raw, '740812');
  });

  test('finds a TD1 zone with spaces and letter/digit swaps in names', () {
    const ocr = '''
I<UTOD231458907<<<<<<<<<<<<<<<
74O8122F12O4159UT0<<<<<<<<<<<6
ER1KSSON<<ANNA<MAR1A<<<<<<<<<<
''';
    final mrz = MrzRecognizer.recognize(ocr);
    expect(mrz?.format, MrzFormat.td1);
    expect(mrz?.primaryIdentifier, 'ERIKSSON');
    expect(mrz?.nationality, 'UTO');
  });

  test('pads lines that lost trailing fillers', () {
    const ocr =
        'I<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<\n'
        'D231458907UTO7408122F1204159<<<<<<<6';
    expect(MrzRecognizer.recognize(ocr)?.format, MrzFormat.td2);
  });

  test('rejects zones whose check digits cannot be satisfied', () {
    const ocr =
        'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<\n'
        'L898902C36UTO7408122F1204159ZE184226B<<<<<11';
    expect(MrzRecognizer.recognize(ocr), isNull);
    expect(MrzRecognizer.recognize(''), isNull);
  });
}
