import 'package:ekyc_document_capture/ekyc_document_capture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Widget host(DocumentOverlay overlay) => MaterialApp(
    home: SizedBox(width: 400, height: 800, child: overlay),
  );

  test('guide states follow the hints', () {
    expect(
      DocumentGuideState.of(DocumentHint.noDocument),
      DocumentGuideState.searching,
    );
    for (final hint in [
      DocumentHint.wrongSide,
      DocumentHint.tooDark,
      DocumentHint.glare,
      DocumentHint.blurry,
    ]) {
      expect(DocumentGuideState.of(hint), DocumentGuideState.adjusting);
    }
    expect(
      DocumentGuideState.of(DocumentHint.holdStill),
      DocumentGuideState.ready,
    );
    expect(
      DocumentGuideState.of(DocumentHint.noDocument, captured: true),
      DocumentGuideState.captured,
    );
  });

  test('style picks a color per state and copies by value', () {
    const style = DocumentOverlayStyle();
    expect(style.frameColorFor(DocumentGuideState.searching), style.frameColor);
    expect(
      style.frameColorFor(DocumentGuideState.adjusting),
      style.accentColor,
    );
    expect(style.frameColorFor(DocumentGuideState.ready), style.readyColor);
    expect(
      style.frameColorFor(DocumentGuideState.captured),
      style.successColor,
    );
    expect(style.copyWith(), style);
    expect(style.copyWith().hashCode, style.hashCode);
    final changed = style.copyWith(
      scrimColor: Colors.black,
      frameColor: Colors.red,
      accentColor: Colors.orange,
      readyColor: Colors.blue,
      successColor: Colors.green,
      templateColor: Colors.grey,
      mrzBandColor: Colors.white24,
      borderWidth: 1,
      cornerWidth: 0,
      cornerLength: 10,
      cornerRadius: 2,
      widthFactor: 0.5,
      alignment: Alignment.center,
      showTemplate: false,
      showScanLine: false,
      animateFlip: false,
      scanDuration: const Duration(seconds: 1),
      flipDuration: const Duration(seconds: 1),
      hintStyle: const TextStyle(fontSize: 20),
      labelStyle: const TextStyle(fontSize: 10),
    );
    expect(changed, isNot(style));
    expect(changed.widthFactor, 0.5);
    expect(changed.showTemplate, isFalse);
    expect(changed.labelStyle!.fontSize, 10);
  });

  test('the frame keeps the proportions of the document', () {
    const size = Size(400, 800);
    const style = DocumentOverlayStyle(widthFactor: 0.8);
    final card = DocumentOverlay.documentRect(
      size,
      DocumentKind.idCard,
      style,
    );
    final page = DocumentOverlay.documentRect(
      size,
      DocumentKind.passport,
      style,
    );
    expect(card.width, 320);
    expect(card.width / card.height, closeTo(85.6 / 53.98, 0.001));
    expect(page.width / page.height, closeTo(125 / 88, 0.001));
    expect(card.center.dx, 200);
    final band = DocumentOverlay.mrzRect(card, DocumentKind.idCard);
    expect(band.height / card.height, closeTo(17.9 / 53.98, 0.001));
    expect(band.bottom, lessThan(card.bottom));
  });

  testWidgets('scans while searching and stops for reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(host(const DocumentOverlay()));
    await tester.pump(const Duration(milliseconds: 100));
    DocumentOverlayPainter painter() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .whereType<DocumentOverlayPainter>()
        .single;
    final first = painter().scanPosition;
    await tester.pump(const Duration(milliseconds: 300));
    expect(painter().scanPosition, isNot(first));

    await tester.pumpWidget(
      host(const DocumentOverlay(state: DocumentGuideState.ready)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(painter().scanPosition, isNull);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: SizedBox(
            width: 400,
            height: 800,
            child: DocumentOverlay(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(painter().scanPosition, isNull);
  });

  testWidgets('turns the template over when the side changes', (
    tester,
  ) async {
    DocumentOverlayPainter painter() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .whereType<DocumentOverlayPainter>()
        .single;
    await tester.pumpWidget(host(const DocumentOverlay()));
    expect(painter().templateScale, 1);
    expect(painter().side, DocumentSide.front);

    await tester.pumpWidget(
      host(const DocumentOverlay(side: DocumentSide.back, step: 1)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(painter().side, DocumentSide.front);
    expect(painter().templateScale, lessThan(1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(painter().side, DocumentSide.back);
    await tester.pump(const Duration(milliseconds: 300));
    expect(painter().templateScale, 1);

    await tester.pumpWidget(
      host(
        const DocumentOverlay(
          style: DocumentOverlayStyle(animateFlip: false),
        ),
      ),
    );
    await tester.pump();
    expect(painter().side, DocumentSide.front);
    expect(painter().templateScale, 1);
  });

  testWidgets('dots show which side of how many is wanted', (tester) async {
    await tester.pumpWidget(
      host(const DocumentOverlay(label: 'Back', step: 1, stepCount: 2)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final dots = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .toList();
    expect(dots, hasLength(2));
    expect(tester.getSize(find.byWidget(dots[1])).width, 22);
    expect(tester.getSize(find.byWidget(dots[0])).width, 8);

    await tester.pumpWidget(host(const DocumentOverlay()));
    expect(find.byType(AnimatedContainer), findsNothing);
  });

  testWidgets('shows the label, the hint and a check when captured', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const DocumentOverlay(hint: 'Show the front', label: 'Front')),
    );
    expect(find.text('Front'), findsOneWidget);
    expect(find.text('Show the front'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);

    await tester.pumpWidget(
      host(const DocumentOverlay(state: DocumentGuideState.captured)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('Front'), findsNothing);
  });

  testWidgets('paints every side, kind and state', (tester) async {
    for (final kind in DocumentKind.values) {
      for (final side in DocumentSide.values) {
        for (final state in DocumentGuideState.values) {
          await tester.pumpWidget(
            host(
              DocumentOverlay(
                kind: kind,
                side: side,
                state: state,
                progress: 0.5,
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
        }
      }
    }
    await tester.pumpWidget(
      host(
        const DocumentOverlay(style: DocumentOverlayStyle(showTemplate: false)),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  test('the painter repaints only when something changed', () {
    const base = DocumentOverlayPainter(
      kind: DocumentKind.idCard,
      side: DocumentSide.front,
      state: DocumentGuideState.searching,
      progress: 0,
      style: DocumentOverlayStyle(),
      frameColor: Colors.white,
    );
    expect(
      base.shouldRepaint(
        const DocumentOverlayPainter(
          kind: DocumentKind.idCard,
          side: DocumentSide.front,
          state: DocumentGuideState.searching,
          progress: 0,
          style: DocumentOverlayStyle(),
          frameColor: Colors.white,
          scanPosition: 0.5,
          templateScale: 0.4,
        ),
      ),
      isTrue,
    );
    DocumentOverlayPainter painter({
      DocumentSide side = DocumentSide.front,
      double progress = 0,
      Color color = Colors.white,
    }) => DocumentOverlayPainter(
      kind: DocumentKind.idCard,
      side: side,
      state: DocumentGuideState.ready,
      progress: progress,
      style: const DocumentOverlayStyle(),
      frameColor: color,
    );
    expect(painter().shouldRepaint(painter()), isFalse);
    expect(painter().shouldRepaint(painter(progress: 0.4)), isTrue);
    expect(painter().shouldRepaint(painter(side: DocumentSide.back)), isTrue);
    expect(painter().shouldRepaint(painter(color: Colors.red)), isTrue);
  });
}
