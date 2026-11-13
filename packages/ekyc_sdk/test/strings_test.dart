import 'dart:ui';

import 'package:ekyc_sdk/ekyc_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('picks Turkish for Turkish locales and English otherwise', () {
    expect(EkycStrings.of(const Locale('tr', 'TR')), same(EkycStrings.tr));
    expect(EkycStrings.of(const Locale('de')), same(EkycStrings.en));
    expect(EkycStrings.tr.cancel, 'İptal');
    expect(EkycStrings.en.cancel, 'Cancel');
  });

  test('every enum value has its own text in both languages', () {
    for (final s in [EkycStrings.en, EkycStrings.tr]) {
      expect(
        ChipReadError.values.map(s.error).toSet(),
        hasLength(ChipReadError.values.length),
      );
      expect(
        MrzScanStatus.values.map(s.mrzStatus).toSet(),
        hasLength(MrzScanStatus.values.length),
      );
      expect(
        ChipReadStep.values.map(s.nfcStep).toSet(),
        hasLength(ChipReadStep.values.length),
      );
      expect(
        FaceHint.values.map(s.faceHint).toSet(),
        hasLength(FaceHint.values.length),
      );
      expect(
        FaceChallenge.values.map(s.faceChallenge).toSet(),
        hasLength(FaceChallenge.values.length),
      );
      expect(
        DocumentHint.values
            .map((h) => s.documentHint(h, DocumentSide.front))
            .toSet(),
        hasLength(DocumentHint.values.length),
      );
      expect(
        s.documentHint(DocumentHint.noDocument, DocumentSide.back),
        s.documentShowBack,
      );
      expect(
        DocumentSide.values.map(s.documentSide).toSet(),
        hasLength(DocumentSide.values.length),
      );
    }
  });

  test('feeds the form labels and the iOS sheet', () {
    const s = EkycStrings.tr;
    expect(s.formLabels.submit, s.mrzContinue);
    expect(s.formLabels.documentNumber, s.mrzDocNumber);
    expect(s.chipMessages.prompt, s.nfcIosPrompt);
    expect(s.chipMessages.failed, s.nfcIosFailed);
  });

  test('copyWith replaces only what is given', () {
    final custom = EkycStrings.tr.copyWith(mrzTitle: 'Kimlik');
    expect(custom.mrzTitle, 'Kimlik');
    expect(custom.nfcTitle, EkycStrings.tr.nfcTitle);
    expect(custom.faceShutter, EkycStrings.tr.faceShutter);
    expect(custom.documentTitle, EkycStrings.tr.documentTitle);
    expect(
      EkycStrings.en.copyWith(documentGlare: 'Shiny').documentGlare,
      'Shiny',
    );
  });

  test('the brand theme colors every overlay', () {
    const primary = Color(0xFF123456);
    const success = Color(0xFF00AA00);
    final theme = EkycTheme.brand(primary: primary, success: success);
    expect(theme.mrz.accentColor, primary);
    expect(theme.nfc.accentColor, primary);
    expect(theme.face.challengeColor, primary);
    expect(theme.mrz.successColor, success);
    expect(theme.nfc.successColor, success);
    expect(theme.face.readyColor, success);
    expect(theme.document.readyColor, primary);
    expect(theme.document.successColor, success);
  });
}
