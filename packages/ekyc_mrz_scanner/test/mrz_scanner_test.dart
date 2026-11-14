import 'package:ekyc_camera/testing.dart';
import 'package:ekyc_mrz_scanner/ekyc_mrz_scanner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const td1 = [
  'I<UTOD231458907<<<<<<<<<<<<<<<',
  '7408122F1204159UTO<<<<<<<<<<<6',
  'ERIKSSON<<ANNA<MARIA<<<<<<<<<<',
];

const td3 = [
  'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<',
  'L898902C36UTO7408122F1204159ZE184226B<<<<<10',
];

void main() {
  group('MrzReadConfirmer', () {
    final a = Mrz.parse(td1);
    final b = Mrz.parse(td3);

    test('needs identical consecutive reads', () {
      final confirmer = MrzReadConfirmer();
      expect(confirmer.add(null), MrzScanStatus.searching);
      expect(confirmer.add(a), MrzScanStatus.confirming);
      expect(confirmer.add(b), MrzScanStatus.confirming);
      expect(confirmer.add(null), MrzScanStatus.searching);
      expect(confirmer.add(b), MrzScanStatus.confirming);
      expect(confirmer.confirmed, isNull);
      expect(confirmer.add(b), MrzScanStatus.detected);
      expect(confirmer.confirmed, b);
      // Later frames do not change the result.
      expect(confirmer.add(a), MrzScanStatus.detected);
      expect(confirmer.confirmed, b);
      confirmer.reset();
      expect(confirmer.confirmed, isNull);
    });

    test('can accept a single read', () {
      final confirmer = MrzReadConfirmer(requiredReads: 1);
      expect(confirmer.add(a), MrzScanStatus.detected);
    });
  });

  group('MrzScanner', () {
    const channel = MethodChannel('google_mlkit_text_recognizer');
    late FakeCameraPlatform camera;
    late String ocrText;
    var recognized = 0;

    setUp(() {
      CameraPlatform.instance = camera = FakeCameraPlatform();
      ocrText = '';
      recognized = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method != 'vision#startTextRecognizer') return null;
            recognized++;
            return {'text': ocrText, 'blocks': <Object>[]};
          });
    });

    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    Future<void> frame(WidgetTester tester) async {
      camera.emitFrame();
      await tester.pump();
      await tester.pump();
    }

    MrzOverlay overlay(WidgetTester tester) =>
        tester.widget<MrzOverlay>(find.byType(MrzOverlay));

    testWidgets('confirms an MRZ over two frames, then reports it once', (
      tester,
    ) async {
      final detected = <Mrz>[];
      await tester.pumpWidget(
        MaterialApp(
          home: MrzScanner(
            onDetected: detected.add,
            frameInterval: Duration.zero,
            hintText: (status) => 'hint: ${status.name}',
            unavailableBuilder: (_) => const Text('no camera'),
          ),
        ),
      );
      await tester.pump();
      expect(overlay(tester).status, MrzScanStatus.searching);
      expect(find.text('hint: searching'), findsOneWidget);

      ocrText = 'noise';
      await frame(tester);
      expect(overlay(tester).status, MrzScanStatus.searching);

      ocrText = td3.join('\n');
      await frame(tester);
      expect(overlay(tester).status, MrzScanStatus.confirming);
      // The template follows the document in view.
      expect(overlay(tester).format, MrzFormat.td3);

      await frame(tester);
      expect(overlay(tester).status, MrzScanStatus.detected);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(detected, isEmpty, reason: 'the success state shows first');

      // Frames after detection are not recognized.
      final before = recognized;
      await frame(tester);
      expect(recognized, before);

      await tester.pump(const Duration(milliseconds: 500));
      expect(detected.single.key.documentNumber, 'L898902C3');
      await tester.pumpWidget(const SizedBox());
      expect(camera.open, isEmpty);
    });

    testWidgets('shows the fallback without a camera', (tester) async {
      CameraPlatform.instance = FakeCameraPlatform(denyPermission: true);
      await tester.pumpWidget(
        MaterialApp(
          home: MrzScanner(
            onDetected: (_) {},
            unavailableBuilder: (_) => const Text('no camera'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('no camera'), findsOneWidget);
    });
  });
}
