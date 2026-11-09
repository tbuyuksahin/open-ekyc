import 'dart:typed_data';

import 'package:ekyc_demo/kyc/domain/kyc_error.dart';
import 'package:ekyc_demo/kyc/domain/kyc_repository.dart';
import 'package:ekyc_sdk/ekyc_sdk.dart';
import 'package:equatable/equatable.dart';

/// The verification flow as a state machine. Each state is one screen.
sealed class KycFlowState extends Equatable {
  const KycFlowState();

  @override
  List<Object?> get props => [];
}

/// Explains what is collected and asks for explicit consent.
final class ConsentStep extends KycFlowState {
  const ConsentStep({this.loading = false});

  final bool loading;

  @override
  List<Object?> get props => [loading];
}

/// Collects the MRZ key by camera or by hand.
final class MrzStep extends KycFlowState {
  const MrzStep({this.prefill, this.error, this.isDemo = false});

  final MrzKey? prefill;
  final KycError? error;
  final bool isDemo;

  @override
  List<Object?> get props => [prefill, error, isDemo];
}

/// Reading the chip.
final class ChipStep extends KycFlowState {
  const ChipStep({required this.key, required this.step, this.progress = 0});

  final MrzKey key;
  final ChipReadStep step;
  final double progress;

  @override
  List<Object?> get props => [key, step, progress];
}

/// Reading failed with a retryable error.
final class ChipErrorStep extends KycFlowState {
  const ChipErrorStep({required this.key, required this.error});

  final MrzKey key;
  final KycError error;

  @override
  List<Object?> get props => [key, error];
}

/// Capturing the selfie.
final class FaceStep extends KycFlowState {
  const FaceStep({required this.document, this.sampleSelfie});

  final DocumentData document;
  final Uint8List? sampleSelfie;

  @override
  List<Object?> get props => [document, sampleSelfie];
}

/// Showing what will be sent, before submission.
final class ReviewStep extends KycFlowState {
  const ReviewStep({
    required this.document,
    required this.selfie,
    required this.liveness,
    this.submitting = false,
    this.error,
  });

  final DocumentData document;
  final Uint8List selfie;
  final LivenessOutcome liveness;
  final bool submitting;
  final KycError? error;

  ReviewStep copyWith({bool? submitting, KycError? error}) => ReviewStep(
    document: document,
    selfie: selfie,
    liveness: liveness,
    submitting: submitting ?? this.submitting,
    error: error,
  );

  @override
  List<Object?> get props => [document, selfie, liveness, submitting, error];
}

/// The server's decision. All personal data has been wiped.
final class ResultStep extends KycFlowState {
  const ResultStep(this.decision);

  final VerificationDecision decision;

  @override
  List<Object?> get props => [decision];
}
