import 'package:ekyc_face_capture/ekyc_face_capture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('derives the guide state from the hint', () {
    expect(FaceGuideState.of(FaceHint.noFace), FaceGuideState.idle);
    expect(FaceGuideState.of(FaceHint.multipleFaces), FaceGuideState.idle);
    expect(FaceGuideState.of(FaceHint.center), FaceGuideState.adjusting);
    expect(FaceGuideState.of(FaceHint.holdStill), FaceGuideState.ready);
    expect(FaceGuideState.of(null), FaceGuideState.captured);
    expect(
      FaceGuideState.of(FaceHint.noFace, captured: true),
      FaceGuideState.captured,
    );
  });

  test('style copies, compares and picks state colors', () {
    const style = FaceOverlayStyle();
    final copy = style.copyWith(
      scrimColor: Colors.black,
      idleColor: Colors.grey,
      adjustColor: Colors.orange,
      challengeColor: Colors.blue,
      readyColor: Colors.teal,
      strokeWidth: 2,
      progressStrokeWidth: 4,
      widthFactor: 0.6,
      aspectRatio: 1.4,
      alignment: Alignment.center,
      showProgress: false,
      pulse: false,
      pulseDuration: const Duration(seconds: 1),
      hintStyle: const TextStyle(fontSize: 12),
      hintBackgroundColor: Colors.black54,
    );
    expect(copy, isNot(style));
    expect(copy, copy.copyWith());
    expect(copy.hashCode, copy.copyWith().hashCode);
    expect(style.copyWith(), style);
    expect(copy.colorFor(FaceGuideState.idle), Colors.grey);
    expect(copy.colorFor(FaceGuideState.adjusting), Colors.orange);
    expect(copy.colorFor(FaceGuideState.ready), Colors.teal);
    expect(copy.colorFor(FaceGuideState.captured), Colors.teal);
  });

  test('the oval is centered horizontally with the requested shape', () {
    const style = FaceOverlayStyle();
    final oval = FaceOverlay.ovalRect(const Size(400, 800), style);
    expect(oval.center.dx, 200);
    expect(oval.width, 400 * style.widthFactor);
    expect(oval.height / oval.width, closeTo(style.aspectRatio, 1e-9));
  });

  Future<void> pump(
    WidgetTester tester,
    FaceGuideState state, {
    FaceOverlayStyle style = const FaceOverlayStyle(),
    String? hint = 'Center your face',
    bool reduceMotion = false,
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: FaceOverlay(
          state: state,
          progress: 0.6,
          hint: hint,
          style: style,
        ),
      ),
    ),
  );

  FaceOverlayPainter painter(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.descendant(
                  of: find.byType(FaceOverlay),
                  matching: find.byType(CustomPaint),
                ),
              )
              .painter!
          as FaceOverlayPainter;

  testWidgets('pulses while idle and shows progress when ready', (
    tester,
  ) async {
    await pump(tester, FaceGuideState.idle);
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.hasRunningAnimations, isTrue);
    expect(painter(tester).progress, 0);
    expect(find.text('Center your face'), findsOneWidget);

    await pump(tester, FaceGuideState.adjusting);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    expect(painter(tester).color, const FaceOverlayStyle().adjustColor);

    await pump(tester, FaceGuideState.ready);
    await tester.pumpAndSettle();
    expect(painter(tester).progress, closeTo(0.6, 1e-9));

    await pump(tester, FaceGuideState.captured, hint: null);
    await tester.pumpAndSettle();
    expect(painter(tester).progress, 1);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('stays still with reduced motion or pulse off', (tester) async {
    await pump(tester, FaceGuideState.idle, reduceMotion: true);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    await pump(
      tester,
      FaceGuideState.idle,
      style: const FaceOverlayStyle(
        pulse: false,
        pulseDuration: Duration(seconds: 2),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  test('the painter repaints when anything visible changes', () {
    const a = FaceOverlayPainter(
      style: FaceOverlayStyle(),
      color: Colors.white,
    );
    expect(a.shouldRepaint(a), isFalse);
    expect(
      a.shouldRepaint(
        const FaceOverlayPainter(
          style: FaceOverlayStyle(),
          color: Colors.white,
          pulse: 0.5,
        ),
      ),
      isTrue,
    );
  });

  testWidgets('shows a guide and step dots for every challenge', (
    tester,
  ) async {
    for (final challenge in FaceChallenge.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: FaceOverlay(
            state: FaceGuideState.challenge,
            challenge: challenge,
            challengeCount: 3,
            challengesDone: 1,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.hasRunningAnimations, isTrue, reason: challenge.name);
      expect(find.byType(Icon), findsOneWidget);
      expect(find.bySemanticsLabel('1 / 3'), findsOneWidget);
    }
    expect(
      const FaceOverlayStyle().colorFor(FaceGuideState.challenge),
      const FaceOverlayStyle().challengeColor,
    );
  });
}
