import 'package:ekyc_mrz_scanner/ekyc_mrz_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MrzInput', () {
    test('normalizes and validates document numbers', () {
      expect(MrzInput.normalizeNumber(' a12 34b '), 'A1234B');
      expect(MrzInput.isValidNumber('A12-3'), isFalse);
      expect(MrzInput.isValidNumber(''), isFalse);
      expect(MrzInput.isValidNumber('U12345678'), isTrue);
    });

    test('parses only real dates', () {
      expect(MrzInput.parseDate('08.01.1995'), DateTime(1995, 1, 8));
      expect(MrzInput.parseDate('31.02.1995'), isNull);
      expect(MrzInput.parseDate('1995-01-08'), isNull);
      expect(MrzInput.formatDate(DateTime(2029, 10, 8)), '08.10.2029');
    });

    test('builds the BAC key', () {
      final key = MrzInput.toKey(
        documentNumber: 'l898902c',
        dateOfBirth: DateTime(1969, 8, 6),
        dateOfExpiry: DateTime(1994, 6, 23),
      );
      expect(key?.information, 'L898902C<369080619406236');
      expect(
        MrzInput.toKey(
          documentNumber: 'X',
          dateOfBirth: null,
          dateOfExpiry: DateTime(2030),
        ),
        isNull,
      );
    });
  });

  group('ManualMrzForm', () {
    const labels = MrzFormLabels();

    Future<List<MrzKey>> pumpForm(
      WidgetTester tester, {
      MrzKey? prefill,
      String? errorText,
      VoidCallback? onScan,
    }) async {
      final submitted = <MrzKey>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ManualMrzForm(
                onSubmit: submitted.add,
                onScan: onScan,
                prefill: prefill,
                errorText: errorText,
                now: DateTime(2026, 11, 9),
              ),
            ),
          ),
        ),
      );
      return submitted;
    }

    Future<void> fill(
      WidgetTester tester,
      String n,
      String dob,
      String doe,
    ) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), n);
      await tester.enterText(fields.at(1), dob);
      await tester.enterText(fields.at(2), doe);
      await tester.tap(find.text(labels.submit));
      await tester.pump();
    }

    testWidgets('shows a message for every invalid field', (tester) async {
      final submitted = await pumpForm(tester);
      await fill(tester, 'A-1', '31.02.1990', '01.01.1980');
      expect(find.text(labels.invalidNumber), findsOneWidget);
      expect(find.text(labels.invalidDate), findsOneWidget);
      await fill(tester, 'A1', '01.01.2030', '01.01.2031');
      expect(find.text(labels.birthInFuture), findsOneWidget);
      await fill(tester, 'A1', '01.01.1990', '01.01.1980');
      expect(find.text(labels.expiryBeforeBirth), findsOneWidget);
      await fill(tester, 'A1', '01.01.1990', '');
      expect(find.text(labels.invalidDate), findsOneWidget);
      expect(submitted, isEmpty);
    });

    testWidgets('submits a normalized key', (tester) async {
      final submitted = await pumpForm(tester);
      await fill(tester, 'l898902c', '06.08.1969', '23.06.1994');
      expect(submitted.single.information, 'L898902C<369080619406236');
    });

    testWidgets('starts from a prefilled key, shows an error and offers the '
        'camera', (tester) async {
      var scans = 0;
      final key = MrzInput.toKey(
        documentNumber: 'L898902C',
        dateOfBirth: DateTime(1969, 8, 6),
        dateOfExpiry: DateTime(2034, 6, 23),
      );
      final submitted = await pumpForm(
        tester,
        prefill: key,
        errorText: 'Wrong details',
        onScan: () => scans++,
      );
      expect(find.text('Wrong details'), findsOneWidget);
      expect(find.text('L898902C'), findsOneWidget);
      expect(find.text('06.08.1969'), findsOneWidget);
      expect(find.text('23.06.2034'), findsOneWidget);
      await tester.tap(find.text(labels.submit));
      await tester.pump();
      expect(submitted.single.information, key!.information);
      await tester.tap(find.text(labels.scanWithCamera));
      expect(scans, 1);
    });
  });
}
