import 'package:ekyc_nfc_reader/ekyc_nfc_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('maps chip read steps to overlay states', () {
    expect(NfcScanStatus.of(null), NfcScanStatus.waiting);
    expect(
      NfcScanStatus.of(ChipReadStep.waitingForCard),
      NfcScanStatus.waiting,
    );
    expect(
      NfcScanStatus.of(ChipReadStep.authenticating),
      NfcScanStatus.reading,
    );
    expect(NfcScanStatus.of(ChipReadStep.reading), NfcScanStatus.reading);
    expect(NfcScanStatus.of(ChipReadStep.verifying), NfcScanStatus.success);
    expect(
      NfcScanStatus.of(ChipReadStep.reading, failed: true),
      NfcScanStatus.error,
    );
  });

  test('style copies, compares and resolves theme colors', () {
    const style = NfcOverlayStyle();
    final copy = style.copyWith(
      document: NfcDocumentKind.passport,
      antennaAlignment: Alignment.center,
      height: 100,
      phoneColor: Colors.black,
      phoneOutlineColor: Colors.grey,
      cardColor: Colors.blue,
      chipColor: Colors.yellow,
      accentColor: Colors.teal,
      successColor: Colors.green,
      errorColor: Colors.red,
      progressStrokeWidth: 3,
      showProgress: false,
      animationDuration: const Duration(seconds: 1),
    );
    expect(copy, isNot(style));
    expect(copy, copy.copyWith());
    expect(copy.hashCode, copy.copyWith().hashCode);
    expect(style.copyWith(), style);

    final scheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
    final themed = ResolvedNfcColors(style, scheme);
    expect(themed.accent, scheme.primary);
    expect(themed.error, scheme.error);
    expect(themed, ResolvedNfcColors(style, scheme));
    expect(themed.hashCode, ResolvedNfcColors(style, scheme).hashCode);
    final custom = ResolvedNfcColors(copy, scheme);
    expect(custom.accent, Colors.teal);
    expect(custom.ringFor(NfcScanStatus.reading), Colors.teal);
    expect(custom.ringFor(NfcScanStatus.success), Colors.green);
    expect(custom.ringFor(NfcScanStatus.error), Colors.red);
  });

  test('places the antenna inside the phone', () {
    const size = Size(300, 240);
    final phone = NfcOverlayPainter.phoneRect(size);
    expect(phone.center, size.center(Offset.zero));
    final antenna = NfcOverlayPainter.antenna(size, const NfcOverlayStyle());
    expect(phone.contains(antenna), isTrue);
    expect(antenna.dy, lessThan(phone.center.dy));
  });

  Future<void> pump(
    WidgetTester tester,
    NfcScanStatus status, {
    NfcOverlayStyle style = const NfcOverlayStyle(),
    bool reduceMotion = false,
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: NfcScanOverlay(
            status: status,
            progress: 0.4,
            style: style,
            semanticLabel: 'Hold the card here',
          ),
        ),
      ),
    ),
  );

  testWidgets('animates while waiting and reading, then settles', (
    tester,
  ) async {
    for (final document in NfcDocumentKind.values) {
      final style = NfcOverlayStyle(document: document);
      await pump(tester, NfcScanStatus.waiting, style: style);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(tester.hasRunningAnimations, isTrue);
      await pump(tester, NfcScanStatus.reading, style: style);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isTrue);
      for (final done in [NfcScanStatus.success, NfcScanStatus.error]) {
        await pump(tester, done, style: style);
        await tester.pumpAndSettle();
        expect(tester.hasRunningAnimations, isFalse);
      }
    }
    expect(find.bySemanticsLabel('Hold the card here'), findsOneWidget);
  });

  testWidgets('stays still when reduced motion is requested', (tester) async {
    await pump(tester, NfcScanStatus.waiting, reduceMotion: true);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('hides the progress ring when asked', (tester) async {
    await pump(
      tester,
      NfcScanStatus.reading,
      style: const NfcOverlayStyle(showProgress: false),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(NfcScanOverlay),
        matching: find.byType(CustomPaint),
      ),
    );
    final painter = paint.painter! as NfcOverlayPainter;
    expect(painter.style.showProgress, isFalse);
    expect(
      painter.shouldRepaint(
        NfcOverlayPainter(
          status: NfcScanStatus.success,
          progress: 1,
          style: painter.style,
          colors: painter.colors,
        ),
      ),
      isTrue,
    );
  });
}
