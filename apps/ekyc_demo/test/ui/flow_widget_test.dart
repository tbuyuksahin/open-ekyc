import 'package:ekyc_demo/app.dart';
import 'package:ekyc_demo/kyc/data/demo_document.dart';
import 'package:ekyc_demo/kyc/data/fake_kyc_repository.dart';
import 'package:ekyc_demo/kyc/flow/kyc_services.dart';
import 'package:ekyc_demo/l10n/gen/app_localizations_en.dart';
import 'package:ekyc_demo/l10n/gen/app_localizations_tr.dart';
import 'package:ekyc_sdk/ekyc_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Pumps frames until [finder] matches, for screens with endless
/// progress animations where pumpAndSettle would never return.
Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 300; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('Timed out waiting for $finder');
}

Widget app({Locale locale = const Locale('en'), FakeKycRepository? repo}) {
  final repository = repo ?? FakeKycRepository(latency: Duration.zero);
  return EkycApp(
    locale: locale,
    cameraAvailable: false,
    loadServices: ({required demo}) async {
      final document = await DemoDocument.create(rootBundle);
      return KycServices(
        chipReader: ChipReader(
          session: document.asNfcSession(),
          trustStore: document.trustStore,
        ),
        repository: repository,
        demoKey: demo ? document.mrz.key : null,
        sampleSelfie: document.portrait,
      );
    },
  );
}

void main() {
  final en = AppLocalizationsEn();
  final tr = AppLocalizationsTr();

  testWidgets('consent is required before anything starts', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final start = find.widgetWithText(FilledButton, en.consentStart);
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
  });

  testWidgets('demo flow runs end to end in Turkish and erases data', (
    tester,
  ) async {
    final repo = FakeKycRepository(latency: Duration.zero);
    await tester.pumpWidget(app(locale: const Locale('tr'), repo: repo));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text(tr.consentDemo));
    await pumpUntil(tester, find.text(EkycStrings.tr.mrzContinue));

    // The specimen key is prefilled; continue to the chip.
    expect(find.text('L898902C3'), findsOneWidget);
    await tester.tap(find.text(EkycStrings.tr.mrzContinue));
    await pumpUntil(tester, find.text(tr.faceUseSample));

    await tester.tap(find.text(tr.faceUseSample));
    await pumpUntil(tester, find.text(tr.reviewSubmit));
    expect(find.text(tr.paVerified), findsOneWidget);
    expect(find.text(tr.livenessNotPerformed), findsOneWidget);
    expect(find.text('ANNA MARİA ERİKSSON'), findsOneWidget);
    expect(find.text('L8•••••C3'), findsOneWidget);

    await tester.ensureVisible(find.text(tr.reviewSubmit));
    await tester.tap(find.text(tr.reviewSubmit));
    await pumpUntil(tester, find.text(tr.resultManualReview));
    expect(find.text(tr.resultDataErased), findsOneWidget);
    expect(repo.lastSubmission!.selfie.every((b) => b == 0), isTrue);

    await tester.tap(find.text(tr.resultRestart));
    await tester.pumpAndSettle();
    expect(find.text(tr.consentTitle), findsOneWidget);
  });
}
