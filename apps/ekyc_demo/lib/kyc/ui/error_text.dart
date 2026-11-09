import 'package:ekyc_demo/kyc/domain/kyc_error.dart';
import 'package:ekyc_demo/l10n/gen/app_localizations.dart';

extension KycErrorText on KycError {
  String message(AppLocalizations l) => switch (this) {
    KycError.nfcNotSupported => l.errorNfcNotSupported,
    KycError.nfcDisabled => l.errorNfcDisabled,
    KycError.wrongMrz => l.errorWrongMrz,
    KycError.tagLost => l.errorTagLost,
    KycError.timeout => l.errorTimeout,
    KycError.cancelled => l.errorCancelled,
    KycError.documentNotAuthentic => l.errorNotAuthentic,
    KycError.unsupportedDocument => l.errorUnsupported,
    KycError.submissionFailed => l.errorSubmission,
    KycError.unknown => l.errorUnknown,
  };

  /// Whether trying again can help, as opposed to a dead end.
  bool get isRetryable => switch (this) {
    KycError.nfcNotSupported || KycError.documentNotAuthentic => false,
    _ => true,
  };
}
