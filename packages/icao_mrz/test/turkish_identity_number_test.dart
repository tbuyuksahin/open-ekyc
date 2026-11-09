import 'package:icao_mrz/icao_mrz.dart';
import 'package:test/test.dart';

void main() {
  test('accepts numbers with valid checksums', () {
    // Widely used synthetic test number, not a real person.
    expect(TurkishIdentityNumber.isValid('10000000146'), isTrue);
  });

  test('rejects wrong shapes and checksums', () {
    expect(TurkishIdentityNumber.isValid('00000000146'), isFalse);
    expect(TurkishIdentityNumber.isValid('1000000014'), isFalse);
    expect(TurkishIdentityNumber.isValid('1000000014a'), isFalse);
    expect(TurkishIdentityNumber.isValid('10000000156'), isFalse);
    expect(TurkishIdentityNumber.isValid('10000000147'), isFalse);
  });
}
