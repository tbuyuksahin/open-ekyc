import 'package:ekyc_camera/ekyc_camera.dart' show ShutterButton;
import 'package:ekyc_camera/testing.dart';
import 'package:ekyc_document_capture/ekyc_document_capture.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const frontText =
    'UTOPIA IDENTITY CARD\nERIKSSON\nANNA MARIA\n'
    '12.08.1974\nD23145890\n15.04.2012';
const backText =
    'I<UTOD231458907<<<<<<<<<<<<<<<\n'
    '7408122F1204159UTO<<<<<<<<<<<6\n'
    'ERIKSSON<<ANNA<MARIA<<<<<<<<<<';
const passportText =
    'ERIKSSON\nANNA MARIA\n'
    'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<\n'
    'L898902C36UTO7408122F1204159ZE184226B<<<<<10';

const good = FrameQuality(brightness: 140, glare: 0, sharpness: 30);

void main() {
  const channel = MethodChannel('google_mlkit_text_recognizer');
  const faceChannel = MethodChannel('google_mlkit_face_detector');
  late FakeCameraPlatform camera;
  late String ocrText;
  late int portraits;
  FrameQuality? quality;

  setUp(() {
    CameraPlatform.instance = camera = FakeCameraPlatform();
    ocrText = '';
    portraits = 1;
    quality = good;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'vision#startTextRecognizer'
            ? {'text': ocrText, 'blocks': <Object>[]}
            : null,
      )
      ..setMockMethodCallHandler(
        faceChannel,
        (call) async => call.method == 'vision#startFaceDetector'
            ? [
                for (var i = 0; i < portraits; i++)
                  {
                    'rect': {
                      'left': 40,
                      'top': 200,
                      'right': 120,
                      'bottom': 300,
                    },
                    'headEulerAngleX': 0.0,
                    'headEulerAngleY': 0.0,
                    'headEulerAngleZ': 0.0,
                    'landmarks': <String, Object?>{},
                  },
              ]
            : null,
      );
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(channel, null)
      ..setMockMethodCallHandler(faceChannel, null),
  );

  // Photo capture reads and deletes a real file, so frames run with real
  // async IO.
  Future<void> frame(WidgetTester tester, {int count = 1}) async {
    for (var n = 0; n < count; n++) {
      camera.emitFrame();
      for (var i = 0; i < 30; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
    }
  }

  Widget app(
    ValueChanged<DocumentCaptureResult> onCaptured, {
    DocumentKind kind = DocumentKind.idCard,
    List<DocumentSide>? sides,
    DocumentCaptureMode mode = DocumentCaptureMode.auto,
    bool manualRequiresGoodFrame = true,
  }) => MaterialApp(
    home: DocumentCapture(
      onCaptured: onCaptured,
      kind: kind,
      sides: sides,
      captureMode: mode,
      manualRequiresGoodFrame: manualRequiresGoodFrame,
      frameInterval: Duration.zero,
      capturedDelay: Duration.zero,
      gate: DocumentQualityGate(requiredStableFrames: 2),
      measure: (_) => quality,
      hintText: (hint, side) => '${side.name}: ${hint.name}',
      sideLabel: (side) => 'side ${side.name}',
      shutterLabel: 'Shoot',
      unavailableBuilder: (_) => const Text('no camera'),
    ),
  );

  DocumentOverlay overlay(WidgetTester tester) =>
      tester.widget<DocumentOverlay>(find.byType(DocumentOverlay));

  testWidgets('captures the front, then the back, with the back camera', (
    tester,
  ) async {
    final results = <DocumentCaptureResult>[];
    await tester.pumpWidget(app(results.add));
    await tester.pump();
    expect(camera.created, ['back']);
    expect(find.text('side front'), findsOneWidget);
    expect(find.text('front: noDocument'), findsOneWidget);
    expect(overlay(tester).state, DocumentGuideState.searching);

    ocrText = frontText;
    camera.pictureBytes = Uint8List.fromList([1, 1, 1]);
    await frame(tester);
    expect(find.text('front: holdStill'), findsOneWidget);
    expect(overlay(tester).state, DocumentGuideState.ready);
    expect(overlay(tester).progress, 0.5);
    await frame(tester);
    expect(camera.pictures, hasLength(1));
    expect(results, isEmpty);

    expect(find.text('side back'), findsOneWidget);
    expect(find.text('back: noDocument'), findsOneWidget);
    expect(overlay(tester).side, DocumentSide.back);
    // Still showing the front: not the side that is wanted now.
    await frame(tester, count: 2);
    expect(camera.pictures, hasLength(1));

    ocrText = backText;
    camera.pictureBytes = Uint8List.fromList([2, 2]);
    await frame(tester, count: 2);
    expect(camera.pictures, hasLength(2));
    final result = results.single;
    expect(result.kind, DocumentKind.idCard);
    expect(result.front, [1, 1, 1]);
    expect(result.back, [2, 2]);
    expect(result.mrz!.documentNumber, 'D23145890');
    expect(result.frontText, contains('ERIKSSON'));
    expect(result.crossCheck(now: DateTime(2011))!.allFound, isTrue);
    expect(overlay(tester).state, DocumentGuideState.captured);
  });

  testWidgets('asks to turn the card when the back is shown first', (
    tester,
  ) async {
    final results = <DocumentCaptureResult>[];
    await tester.pumpWidget(app(results.add));
    await tester.pump();
    ocrText = backText;
    await frame(tester, count: 3);
    expect(find.text('front: wrongSide'), findsOneWidget);
    expect(overlay(tester).state, DocumentGuideState.adjusting);
    expect(camera.pictures, isEmpty);
  });

  testWidgets('a back whose MRZ cannot be read is still the wrong side', (
    tester,
  ) async {
    await tester.pumpWidget(app((_) {}));
    await tester.pump();
    ocrText =
        'KİMLİK KARTI\nIDENTITY CARD\nYAPAN MAKAM\n'
        'I<TURA12B3456<<<<<<<<<<<<\n7408122F12<<';
    await frame(tester, count: 3);
    expect(find.text('front: wrongSide'), findsOneWidget);
    expect(camera.pictures, isEmpty);
  });

  testWidgets('the front needs a portrait', (tester) async {
    await tester.pumpWidget(app((_) {}));
    await tester.pump();
    ocrText = frontText;
    portraits = 0;
    await frame(tester, count: 3);
    expect(find.text('front: noDocument'), findsOneWidget);
    expect(camera.pictures, isEmpty);
    portraits = 1;
    await frame(tester, count: 2);
    expect(camera.pictures, hasLength(1));
  });

  testWidgets('waits for light, no glare and focus', (tester) async {
    await tester.pumpWidget(app((_) {}));
    await tester.pump();
    ocrText = frontText;
    quality = const FrameQuality(brightness: 10, glare: 0, sharpness: 30);
    await frame(tester);
    expect(find.text('front: tooDark'), findsOneWidget);
    quality = const FrameQuality(brightness: 140, glare: 0.3, sharpness: 30);
    await frame(tester);
    expect(find.text('front: glare'), findsOneWidget);
    quality = const FrameQuality(brightness: 140, glare: 0, sharpness: 1);
    await frame(tester);
    expect(find.text('front: blurry'), findsOneWidget);
    expect(camera.pictures, isEmpty);
    // Frames whose format cannot be measured are judged by content only.
    quality = null;
    await frame(tester, count: 2);
    expect(camera.pictures, hasLength(1));
  });

  testWidgets('a passport is one page with the MRZ on it', (tester) async {
    final results = <DocumentCaptureResult>[];
    await tester.pumpWidget(app(results.add, kind: DocumentKind.passport));
    await tester.pump();
    ocrText = frontText;
    await frame(tester, count: 2);
    expect(find.text('front: noDocument'), findsOneWidget);
    ocrText = passportText;
    await frame(tester, count: 2);
    final result = results.single;
    expect(result.images.keys, [DocumentSide.front]);
    expect(result.back, isNull);
    expect(result.mrz!.documentNumber, 'L898902C3');
    expect(result.frontText, hasLength(4));
  });

  testWidgets('captures only the sides that were asked for', (tester) async {
    final results = <DocumentCaptureResult>[];
    await tester.pumpWidget(
      app(results.add, sides: const [DocumentSide.front]),
    );
    await tester.pump();
    ocrText = frontText;
    await frame(tester, count: 2);
    expect(results.single.images.keys, [DocumentSide.front]);
    expect(results.single.mrz, isNull);
    expect(results.single.crossCheck(), isNull);
  });

  testWidgets('manual mode enables the shutter on a good frame', (
    tester,
  ) async {
    final results = <DocumentCaptureResult>[];
    await tester.pumpWidget(
      app(
        results.add,
        mode: DocumentCaptureMode.manual,
        sides: const [DocumentSide.front],
      ),
    );
    await tester.pump();
    ShutterButton shutter() =>
        tester.widget<ShutterButton>(find.byType(ShutterButton));
    expect(shutter().onPressed, isNull);
    ocrText = frontText;
    await frame(tester, count: 3);
    expect(camera.pictures, isEmpty);
    expect(overlay(tester).progress, 0);
    expect(shutter().onPressed, isNotNull);

    await tester.tap(find.bySemanticsLabel('Shoot'));
    await frame(tester);
    expect(results, hasLength(1));
    expect(find.byType(ShutterButton), findsNothing);
  });

  testWidgets('manual mode can allow any frame', (tester) async {
    final results = <DocumentCaptureResult>[];
    await tester.pumpWidget(
      app(
        results.add,
        mode: DocumentCaptureMode.manual,
        manualRequiresGoodFrame: false,
        sides: const [DocumentSide.back],
      ),
    );
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Shoot'));
    await frame(tester);
    expect(results.single.back, isNotNull);
    expect(results.single.mrz, isNull);
  });

  testWidgets('a failed photo starts the countdown again', (tester) async {
    final results = <DocumentCaptureResult>[];
    await tester.pumpWidget(
      app(results.add, sides: const [DocumentSide.front]),
    );
    await tester.pump();
    ocrText = frontText;
    camera.pictureError = PlatformException(code: 'fail');
    await frame(tester, count: 2);
    expect(results, isEmpty);
    expect(overlay(tester).state, DocumentGuideState.ready);
    await frame(tester, count: 2);
    expect(results, hasLength(1));
  });

  testWidgets('photos are wiped when the view is removed early', (
    tester,
  ) async {
    final bytes = Uint8List.fromList([7, 7, 7]);
    final results = <DocumentCaptureResult>[];
    await tester.pumpWidget(app(results.add));
    await tester.pump();
    ocrText = frontText;
    camera.pictureBytes = bytes;
    await frame(tester, count: 2);
    expect(camera.pictures, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    expect(results, isEmpty);
  });

  testWidgets('shows the fallback without a camera', (tester) async {
    CameraPlatform.instance = FakeCameraPlatform(denyPermission: true);
    await tester.pumpWidget(app((_) {}));
    await tester.pump();
    await tester.pump();
    expect(find.text('no camera'), findsOneWidget);
  });
}
