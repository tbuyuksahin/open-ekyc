import 'package:icao_mrz/icao_mrz.dart';
import 'package:test/test.dart';

// Specimen zones from ICAO Doc 9303 (Utopia, fictitious holder).
const td3 = [
  'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<',
  'L898902C36UTO7408122F1204159ZE184226B<<<<<10',
];
const td2 = [
  'I<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<',
  'D231458907UTO7408122F1204159<<<<<<<6',
];
const td1 = [
  'I<UTOD231458907<<<<<<<<<<<<<<<',
  '7408122F1204159UTO<<<<<<<<<<<6',
  'ERIKSSON<<ANNA<MARIA<<<<<<<<<<',
];

/// Replaces the character at [index] of [line].
String replaceAt(String line, int index, String c) =>
    line.substring(0, index) + c + line.substring(index + 1);

void main() {
  group('checkDigit', () {
    test('matches ICAO examples', () {
      expect(checkDigit('L898902C<'), 3);
      expect(checkDigit('690806'), 1);
      expect(checkDigit('940623'), 6);
      expect(checkDigit('<<<<<<<<<'), 0);
    });

    test('rejects characters outside the MRZ set', () {
      expect(() => checkDigit('a'), throwsFormatException);
    });
  });

  group('TD3', () {
    final mrz = Mrz.parse(td3.join('\n'));

    test('parses every field', () {
      expect(mrz.format, MrzFormat.td3);
      expect(mrz.documentCode, 'P');
      expect(mrz.issuingState, 'UTO');
      expect(mrz.documentNumber, 'L898902C3');
      expect(mrz.nationality, 'UTO');
      expect(mrz.dateOfBirth, const MrzDate('740812'));
      expect(mrz.sex, Sex.female);
      expect(mrz.dateOfExpiry, const MrzDate('120415'));
      expect(mrz.primaryIdentifier, 'ERIKSSON');
      expect(mrz.secondaryIdentifier, 'ANNA MARIA');
      expect(mrz.optionalData, 'ZE184226B');
    });

    test('validates all five check digits', () {
      expect(mrz.isValid, isTrue);
      expect(mrz.checks.keys, hasLength(5));
    });

    test('reports which check digit fails', () {
      final broken = Mrz.parse([td3[0], replaceAt(td3[1], 19, '9')]);
      expect(broken.isValid, isFalse);
      expect(
        broken.failedChecks,
        [MrzCheckedField.dateOfBirth, MrzCheckedField.composite],
      );
    });

    test('accepts lower case and surrounding whitespace', () {
      final parsed = Mrz.parse(
        '  ${td3[0].toLowerCase()} \r\n\n ${td3[1]}  ',
      );
      expect(parsed.isValid, isTrue);
    });
  });

  group('TD2', () {
    test('parses and validates', () {
      final mrz = Mrz.parse(td2);
      expect(mrz.format, MrzFormat.td2);
      expect(mrz.documentCode, 'I');
      expect(mrz.documentNumber, 'D23145890');
      expect(mrz.secondaryIdentifier, 'ANNA MARIA');
      expect(mrz.isValid, isTrue);
      expect(mrz.checks.containsKey(MrzCheckedField.optionalData), isFalse);
    });
  });

  group('TD1', () {
    test('parses and validates', () {
      final mrz = Mrz.parse(td1);
      expect(mrz.format, MrzFormat.td1);
      expect(mrz.documentNumber, 'D23145890');
      expect(mrz.dateOfBirth.raw, '740812');
      expect(mrz.primaryIdentifier, 'ERIKSSON');
      expect(mrz.isValid, isTrue);
    });

    test('reads a document number that overflows into optional data', () {
      // ICAO 9303-5: a 12 character number continues after a '<'.
      const number = 'D23145890734';
      final cd = checkDigit(number);
      final line1 = 'I<UTOD23145890<7349'.replaceRange(18, 19, '$cd');
      final l1 = line1.padRight(30, '<');
      const l2Body = '7408122F1204159UTO<<<<<<<<<<<';
      final composite =
          l1.substring(5, 30) +
          l2Body.substring(0, 7) +
          l2Body.substring(8, 15) +
          l2Body.substring(18, 29);
      final mrz = Mrz.parse([
        l1,
        '$l2Body${checkDigit(composite)}',
        td1[2],
      ]);
      expect(mrz.documentNumber, number);
      expect(mrz.isValid, isTrue);
      expect(mrz.key.information.substring(0, 13), '$number$cd');
    });
  });

  test('rejects unknown shapes and characters', () {
    expect(() => Mrz.parse(const ['ABC']), throwsFormatException);
    expect(
      () => Mrz.parse([td3[0], td3[1].replaceFirst('L', '-')]),
      throwsFormatException,
    );
    expect(Mrz.tryParse('nope'), isNull);
  });

  test('toString does not leak personal data', () {
    final text = Mrz.parse(td3).toString();
    expect(text, isNot(contains('ERIKSSON')));
    expect(text, isNot(contains('L898902C3')));
  });
}
