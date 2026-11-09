import 'package:ekyc_demo/kyc/domain/kyc_error.dart';
import 'package:ekyc_demo/kyc/domain/kyc_repository.dart';
import 'package:ekyc_demo/kyc/flow/kyc_flow_cubit.dart';
import 'package:ekyc_demo/kyc/ui/error_text.dart';
import 'package:ekyc_demo/kyc/ui/nfc_view.dart';
import 'package:ekyc_demo/kyc/ui/result_view.dart';
import 'package:ekyc_demo/l10n/gen/app_localizations.dart';
import 'package:ekyc_demo/l10n/gen/app_localizations_en.dart';
import 'package:ekyc_demo/l10n/gen/app_localizations_tr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Widget host(Widget child) => BlocProvider(
  create: (_) => KycFlowCubit(
    ({required demo}) async =>
        throw UnimplementedError('not used in screen tests'),
  ),
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  ),
);

void main() {
  test('every error has a distinct message in both languages', () {
    for (final l in [AppLocalizationsEn(), AppLocalizationsTr()]) {
      final texts = KycError.values.map((e) => e.message(l)).toSet();
      expect(texts, hasLength(KycError.values.length));
    }
    expect(KycError.documentNotAuthentic.isRetryable, isFalse);
    expect(KycError.nfcNotSupported.isRetryable, isFalse);
    expect(KycError.tagLost.isRetryable, isTrue);
  });

  testWidgets('a retryable chip error offers retry and editing', (
    tester,
  ) async {
    final en = AppLocalizationsEn();
    await tester.pumpWidget(
      host(NfcView(mrzKey: specimenKey, error: KycError.tagLost)),
    );
    expect(find.text(en.errorTagLost), findsOneWidget);
    expect(find.text(en.retry), findsOneWidget);
    expect(find.text(en.editMrz), findsOneWidget);
  });

  testWidgets('a forged document offers no retry', (tester) async {
    final en = AppLocalizationsEn();
    await tester.pumpWidget(
      host(NfcView(mrzKey: specimenKey, error: KycError.documentNotAuthentic)),
    );
    expect(find.text(en.errorNotAuthentic), findsOneWidget);
    expect(find.text(en.retry), findsNothing);
  });

  testWidgets('result screens', (tester) async {
    final en = AppLocalizationsEn();
    for (final (decision, title) in [
      (VerificationDecision.approved, en.resultApproved),
      (VerificationDecision.rejected, en.resultRejected),
      (VerificationDecision.manualReview, en.resultManualReview),
    ]) {
      await tester.pumpWidget(host(ResultView(decision: decision)));
      expect(find.text(title), findsOneWidget);
      expect(find.text(en.resultDataErased), findsOneWidget);
    }
  });
}
