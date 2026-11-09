import 'package:icao_mrz/icao_mrz.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026, 11, 9);

  test('birth dates are never in the future', () {
    expect(const MrzDate('950108').asBirthDate(now: now), DateTime(1995, 1, 8));
    expect(const MrzDate('100101').asBirthDate(now: now), DateTime(2010));
    expect(
      const MrzDate('261231').asBirthDate(now: now),
      DateTime(1926, 12, 31),
    );
  });

  test('expiry dates resolve to the nearest plausible century', () {
    expect(
      const MrzDate('291008').asExpiryDate(now: now),
      DateTime(2029, 10, 8),
    );
    expect(
      const MrzDate('940623').asExpiryDate(now: now),
      DateTime(1994, 6, 23),
    );
  });

  test('rejects impossible dates', () {
    expect(const MrzDate('011301').isWellFormed, isFalse);
    expect(const MrzDate('010230').isWellFormed, isFalse);
    expect(const MrzDate('01<<01').isWellFormed, isFalse);
    expect(const MrzDate('12345').asBirthDate(), isNull);
    // 29 Feb exists in 2000 but not in 1900.
    expect(
      const MrzDate('000229').asBirthDate(now: now),
      DateTime(2000, 2, 29),
    );
    expect(const MrzDate('000229').asBirthDate(now: DateTime(1999)), isNull);
  });

  test('round-trips through DateTime', () {
    expect(MrzDate.fromDateTime(DateTime(2031, 3, 7)).raw, '310307');
  });
}
