import 'package:ekyc_document_capture/ekyc_document_capture.dart';
import 'package:flutter_test/flutter_test.dart';

const good = FrameQuality(brightness: 140, glare: 0, sharpness: 30);

DocumentObservation see({
  int lines = 5,
  bool mrz = false,
  FrameQuality? quality = good,
}) => DocumentObservation(textLines: lines, hasMrz: mrz, quality: quality);

void main() {
  group('DocumentQualityGate.hintFor', () {
    final gate = DocumentQualityGate();

    test('a side without an MRZ needs text and no MRZ', () {
      expect(
        gate.hintFor(see(lines: 1), expectMrz: false),
        DocumentHint.noDocument,
      );
      expect(
        gate.hintFor(see(mrz: true), expectMrz: false),
        DocumentHint.wrongSide,
      );
      expect(gate.hintFor(see(), expectMrz: false), DocumentHint.holdStill);
    });

    test('a side with an MRZ needs it to be read', () {
      expect(gate.hintFor(see(), expectMrz: true), DocumentHint.noDocument);
      expect(
        gate.hintFor(see(mrz: true, lines: 0), expectMrz: true),
        DocumentHint.holdStill,
      );
    });

    test('light and glare come before everything else', () {
      expect(
        gate.hintFor(
          see(
            lines: 0,
            quality: const FrameQuality(
              brightness: 20,
              glare: 0.5,
              sharpness: 0,
            ),
          ),
          expectMrz: false,
        ),
        DocumentHint.tooDark,
      );
      expect(
        gate.hintFor(
          see(
            quality: const FrameQuality(
              brightness: 150,
              glare: 0.2,
              sharpness: 30,
            ),
          ),
          expectMrz: false,
        ),
        DocumentHint.glare,
      );
    });

    test('a soft frame of the right side is blurry', () {
      expect(
        gate.hintFor(
          see(
            quality: const FrameQuality(
              brightness: 150,
              glare: 0,
              sharpness: 1,
            ),
          ),
          expectMrz: false,
        ),
        DocumentHint.blurry,
      );
    });

    test('quality checks are skipped when it cannot be measured', () {
      expect(
        gate.hintFor(see(quality: null), expectMrz: false),
        DocumentHint.holdStill,
      );
    });
  });

  group('DocumentQualityGate.evaluate', () {
    test('releases after consecutive good frames', () {
      final gate = DocumentQualityGate();
      expect(gate.evaluate(see(), expectMrz: false), DocumentHint.holdStill);
      expect(gate.progress, closeTo(1 / 3, 0.001));
      expect(gate.evaluate(see(), expectMrz: false), DocumentHint.holdStill);
      expect(gate.evaluate(see(), expectMrz: false), isNull);
      expect(gate.progress, 1);
    });

    test('a bad frame starts the count again', () {
      final gate = DocumentQualityGate(requiredStableFrames: 2);
      expect(gate.evaluate(see(), expectMrz: false), DocumentHint.holdStill);
      expect(
        gate.evaluate(see(lines: 0), expectMrz: false),
        DocumentHint.noDocument,
      );
      expect(gate.progress, 0);
      expect(gate.evaluate(see(), expectMrz: false), DocumentHint.holdStill);
      gate.reset();
      expect(gate.progress, 0);
      expect(gate.evaluate(see(), expectMrz: false), DocumentHint.holdStill);
      expect(gate.evaluate(see(), expectMrz: false), isNull);
    });
  });

  test('DocumentKind knows its sides and where the MRZ is', () {
    expect(DocumentKind.idCard.sides, [DocumentSide.front, DocumentSide.back]);
    expect(DocumentKind.idCard.hasMrzOn(DocumentSide.front), isFalse);
    expect(DocumentKind.idCard.hasMrzOn(DocumentSide.back), isTrue);
    expect(DocumentKind.passport.sides, [DocumentSide.front]);
    expect(DocumentKind.passport.hasMrzOn(DocumentSide.front), isTrue);
    expect(
      DocumentKind.idCard.aspectRatio,
      greaterThan(DocumentKind.passport.aspectRatio),
    );
  });
}
