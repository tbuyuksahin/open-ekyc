import 'package:ekyc_camera/testing.dart';
import 'package:ekyc_face_capture/ekyc_face_capture.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const channel = MethodChannel('google_mlkit_face_detector');
  late FakeCameraPlatform camera;
  late List<Map<String, Object?>> faces;

  Map<String, Object?> face({
    double left = 120,
    double yaw = 0,
    double smiling = 0.1,
  }) => {
    'rect': {'left': left, 'top': 180, 'right': left + 240, 'bottom': 460},
    'headEulerAngleX': 0.0,
    'headEulerAngleY': yaw,
    'headEulerAngleZ': 0.0,
    'smilingProbability': smiling,
    'leftEyeOpenProbability': 0.9,
    'rightEyeOpenProbability': 0.9,
    'landmarks': <String, Object?>{},
  };

  setUp(() {
    CameraPlatform.instance = camera = FakeCameraPlatform();
    faces = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async =>
              call.method == 'vision#startFaceDetector' ? faces : null,
        );
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  // Photo capture reads and deletes a real file, so frames run with real
  // async IO.
  Future<void> frame(WidgetTester tester) async {
    camera.emitFrame();
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
  }

  Widget app(
    ValueChanged<FaceCaptureResult> onCaptured, {
    List<FaceChallenge> challenges = const [],
    FaceCaptureMode mode = FaceCaptureMode.auto,
    Duration timeout = const Duration(seconds: 8),
    VoidCallback? onFailed,
  }) => MaterialApp(
    home: FaceCapture(
      onCaptured: onCaptured,
      frameInterval: Duration.zero,
      gate: FaceQualityGate(requiredStableFrames: 2),
      hintText: (hint) => 'hint: ${hint.name}',
      challengeText: (challenge) => 'do: ${challenge.name}',
      timeoutText: 'too slow',
      shutterLabel: 'Shoot',
      challenges: challenges,
      challengeTimeout: timeout,
      maxAttempts: 1,
      onChallengesFailed: onFailed,
      captureMode: mode,
      unavailableBuilder: (_) => const Text('no camera'),
    ),
  );

  FaceOverlay overlay(WidgetTester tester) =>
      tester.widget<FaceOverlay>(find.byType(FaceOverlay));

  testWidgets('guides, then captures automatically with the front camera', (
    tester,
  ) async {
    final captured = <FaceCaptureResult>[];
    await tester.pumpWidget(app(captured.add));
    await tester.pump();
    expect(camera.created, ['front']);
    expect(find.text('hint: noFace'), findsOneWidget);
    expect(overlay(tester).challengeCount, 0);

    faces = [face(left: 0)];
    await frame(tester);
    expect(overlay(tester).state, FaceGuideState.adjusting);
    expect(find.text('hint: center'), findsOneWidget);

    faces = [face()];
    await frame(tester);
    expect(overlay(tester).state, FaceGuideState.ready);
    expect(overlay(tester).progress, 0.5);

    await frame(tester);
    expect(captured.single.image, camera.pictureBytes);
    expect(captured.single.challengesPassed, isFalse);
    expect(overlay(tester).state, FaceGuideState.captured);
    expect(find.textContaining('hint:'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('asks for challenges before the photo', (tester) async {
    final captured = <FaceCaptureResult>[];
    await tester.pumpWidget(
      app(captured.add, challenges: [FaceChallenge.smile]),
    );
    await tester.pump();
    expect(overlay(tester).challengeCount, 1);

    // Positioning first.
    faces = [face(left: 0)];
    await frame(tester);
    expect(overlay(tester).challenge, isNull);
    faces = [face()];
    await frame(tester);
    expect(overlay(tester).challenge, FaceChallenge.smile);

    // A neutral frame arms the challenge, then the smile is held.
    await frame(tester);
    expect(overlay(tester).state, FaceGuideState.challenge);
    expect(find.text('do: smile'), findsOneWidget);
    faces = [];
    await frame(tester);
    expect(find.text('hint: noFace'), findsOneWidget);
    faces = [face(smiling: 0.95)];
    await frame(tester);
    await frame(tester);
    expect(overlay(tester).challenge, isNull);
    expect(overlay(tester).challengesDone, 1);

    // Then the usual automatic photo of a frontal, neutral face.
    faces = [face()];
    await frame(tester);
    await frame(tester);
    expect(captured.single.challenges, [FaceChallenge.smile]);
    expect(captured.single.challengesPassed, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reports failed challenges', (tester) async {
    var failed = 0;
    await tester.pumpWidget(
      app(
        (_) {},
        challenges: [FaceChallenge.blink],
        timeout: Duration.zero,
        onFailed: () => failed++,
      ),
    );
    await tester.pump();
    faces = [face()];
    await frame(tester);
    await frame(tester);
    await frame(tester);
    expect(failed, 1);
    expect(find.textContaining('do:'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('restarts challenges that time out when nobody handles it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FaceCapture(
          onCaptured: (_) {},
          frameInterval: Duration.zero,
          challenges: const [FaceChallenge.turnLeft],
          challengeTimeout: Duration.zero,
          maxAttempts: 2,
          timeoutText: 'too slow',
          unavailableBuilder: (_) => const SizedBox(),
        ),
      ),
    );
    await tester.pump();
    faces = [face()];
    await frame(tester); // positioned
    await frame(tester); // timer starts
    await frame(tester); // times out once
    expect(find.text('too slow'), findsOneWidget);
    await frame(tester); // the new attempt's timer starts
    await frame(tester); // fails, starts over from positioning
    expect(overlay(tester).challenge, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('manual mode waits for the shutter on a good frame', (
    tester,
  ) async {
    final captured = <FaceCaptureResult>[];
    await tester.pumpWidget(app(captured.add, mode: FaceCaptureMode.manual));
    await tester.pump();
    final shutter = find.bySemanticsLabel('Shoot');
    expect(shutter, findsOneWidget);

    faces = [face(left: 0)];
    await frame(tester);
    await tester.tap(shutter, warnIfMissed: false);
    await frame(tester);
    expect(captured, isEmpty, reason: 'disabled on a bad frame');

    faces = [face()];
    await frame(tester);
    await frame(tester);
    await frame(tester);
    expect(captured, isEmpty, reason: 'never automatic');
    await tester.tap(shutter);
    await frame(tester);
    expect(captured.single.image, camera.pictureBytes);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('starts over when the photo fails', (tester) async {
    final captured = <FaceCaptureResult>[];
    camera.pictureError = CameraException('busy', null);
    await tester.pumpWidget(app(captured.add));
    await tester.pump();
    faces = [face()];
    await frame(tester);
    await frame(tester);
    expect(captured, isEmpty);
    // The countdown starts again from zero.
    expect(overlay(tester).state, FaceGuideState.ready);
    expect(overlay(tester).progress, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shows the fallback without a camera', (tester) async {
    CameraPlatform.instance = FakeCameraPlatform(denyPermission: true);
    await tester.pumpWidget(app((_) {}));
    await tester.pump();
    expect(find.text('no camera'), findsOneWidget);
  });
}
