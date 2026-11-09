import 'package:icao_mrz/icao_mrz.dart';
import 'package:test/test.dart';

void main() {
  test('builds MRZ_information from ICAO 9303-11 Appendix D', () {
    final key = MrzKey(
      documentNumber: 'L898902C',
      dateOfBirth: const MrzDate('690806'),
      dateOfExpiry: const MrzDate('940623'),
    );
    expect(key.information, 'L898902C<369080619406236');
  });

  test('rejects malformed input without echoing it', () {
    expect(
      () => MrzKey(
        documentNumber: 'A-1',
        dateOfBirth: const MrzDate('690806'),
        dateOfExpiry: const MrzDate('940623'),
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.toString(),
          'message',
          isNot(contains('A-1')),
        ),
      ),
    );
    expect(
      () => MrzKey(
        documentNumber: 'X',
        dateOfBirth: const MrzDate('691306'),
        dateOfExpiry: const MrzDate('940623'),
      ),
      throwsArgumentError,
    );
  });

  test('equality and redacted toString', () {
    MrzKey make() => MrzKey(
      documentNumber: 'l898902c',
      dateOfBirth: const MrzDate('690806'),
      dateOfExpiry: const MrzDate('940623'),
    );
    expect(make(), make());
    expect(make().hashCode, make().hashCode);
    expect(make().toString(), isNot(contains('L898902C')));
  });
}
