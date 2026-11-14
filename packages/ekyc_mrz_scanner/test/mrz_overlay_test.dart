import 'package:ekyc_mrz_scanner/ekyc_mrz_scanner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('document and MRZ geometry follow ICAO sizes', () {
    const size = Size(400, 800);
    const style = MrzOverlayStyle();
    for (final format in MrzFormat.values) {
      final doc = MrzOverlay.documentRect(size, format, style);
      expect(doc.width, 400 * style.widthFactor);
      expect(doc.width / doc.height, closeTo(format.aspectRatio, 1e-9));
      expect(doc.center.dx, 200);
      final band = MrzOverlay.mrzRect(doc, format);
      expect(doc.contains(band.topLeft), isTrue);
      expect(doc.contains(band.bottomRight), isTrue);
      expect(band.height / doc.height, closeTo(format.mrzZoneHeight, 1e-9));
    }
    // A passport page is squarer than an ID card.
    expect(
      MrzFormat.td3.aspectRatio,
      lessThan(MrzFormat.td1.aspectRatio),
    );
  });

  test('style copies, compares and picks status colors', () {
    const style = MrzOverlayStyle();
    final copy = style.copyWith(
      scrimColor: Colors.black,
      frameColor: Colors.grey,
      accentColor: Colors.blue,
      successColor: Colors.teal,
      templateColor: Colors.white24,
      mrzBandColor: Colors.white10,
      borderWidth: 1,
      cornerWidth: 0,
      cornerLength: 10,
      cornerRadius: 4,
      widthFactor: 0.8,
      alignment: Alignment.center,
      showTemplate: false,
      showScanLine: false,
      scanDuration: const Duration(seconds: 1),
      hintStyle: const TextStyle(fontSize: 12),
    );
    expect(copy, isNot(style));
    expect(copy, copy.copyWith());
    expect(copy.hashCode, copy.copyWith().hashCode);
    expect(style.copyWith(), style);
    expect(copy.frameColorFor(MrzScanStatus.searching), Colors.grey);
    expect(copy.frameColorFor(MrzScanStatus.confirming), Colors.blue);
    expect(copy.frameColorFor(MrzScanStatus.detected), Colors.teal);
  });

  Future<void> pump(
    WidgetTester tester, {
    MrzFormat format = MrzFormat.td1,
    MrzScanStatus status = MrzScanStatus.searching,
    MrzOverlayStyle style = const MrzOverlayStyle(),
    String? hint = 'Align the MRZ',
    bool reduceMotion = false,
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: MrzOverlay(
          format: format,
          status: status,
          style: style,
          hint: hint,
        ),
      ),
    ),
  );

  testWidgets('scans while searching and stops once detected', (tester) async {
    for (final format in MrzFormat.values) {
      await pump(tester, format: format);
      await tester.pump(const Duration(milliseconds: 900));
      expect(tester.hasRunningAnimations, isTrue);
      expect(find.text('Align the MRZ'), findsOneWidget);
      await pump(tester, format: format, status: MrzScanStatus.confirming);
      await tester.pump(const Duration(milliseconds: 100));
      await pump(tester, format: format, status: MrzScanStatus.detected);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    }
  });

  testWidgets('respects reduced motion and a plain style', (tester) async {
    await pump(
      tester,
      reduceMotion: true,
      hint: null,
      style: const MrzOverlayStyle(showTemplate: false, cornerWidth: 0),
    );
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.byType(Text), findsNothing);

    await pump(
      tester,
      style: const MrzOverlayStyle(
        showScanLine: false,
        scanDuration: Duration(seconds: 3),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  test('the painter repaints when anything visible changes', () {
    const painter = MrzOverlayPainter(
      format: MrzFormat.td1,
      status: MrzScanStatus.searching,
      style: MrzOverlayStyle(),
      frameColor: Colors.white,
      scanPosition: 0.5,
    );
    expect(painter.shouldRepaint(painter), isFalse);
    expect(
      painter.shouldRepaint(
        const MrzOverlayPainter(
          format: MrzFormat.td1,
          status: MrzScanStatus.searching,
          style: MrzOverlayStyle(),
          frameColor: Colors.white,
          scanPosition: 0.6,
        ),
      ),
      isTrue,
    );
  });
}
