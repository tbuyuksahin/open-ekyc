import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:ekyc_demo/core/app_log.dart';
import 'package:ekyc_demo/kyc/domain/kyc_error.dart';
import 'package:ekyc_demo/kyc/domain/kyc_repository.dart';
import 'package:ekyc_demo/kyc/flow/kyc_flow_state.dart';
import 'package:ekyc_demo/kyc/flow/kyc_services.dart';
import 'package:ekyc_face_capture/ekyc_face_capture.dart';
import 'package:ekyc_nfc_reader/ekyc_nfc_reader.dart';
import 'package:icao_mrz/icao_mrz.dart';

/// Loads the services for a run: real hardware or the demo document.
typedef KycServicesLoader = Future<KycServices> Function({required bool demo});

/// Drives the verification flow and owns the personal data it collects.
///
/// Personal data lives only in states and is wiped on submit, restart and
/// close, so abandoning the flow at any point leaves nothing behind.
class KycFlowCubit extends Cubit<KycFlowState> {
  KycFlowCubit(this._load) : super(const ConsentStep());

  final KycServicesLoader _load;
  KycServices? _services;
  DocumentData? _document;
  Uint8List? _selfie;

  KycServices get _s => _services ?? (throw StateError('Flow not started'));

  /// The user agreed to the processing described on the consent screen.
  Future<void> start({required bool demo}) async {
    emit(const ConsentStep(loading: true));
    _services = await _load(demo: demo);
    AppLog.event('flow_started', {'demo': demo});
    emit(MrzStep(prefill: _s.demoKey, isDemo: _s.isDemo));
  }

  /// Reads the chip with [key].
  Future<void> readChip(MrzKey key, ChipReadMessages messages) async {
    _wipe();
    emit(ChipStep(key: key, step: ChipReadStep.waitingForCard));
    try {
      final document = await _s.chipReader.read(
        key,
        messages: messages,
        onProgress: (step, fraction) {
          if (!isClosed) {
            emit(ChipStep(key: key, step: step, progress: fraction));
          }
        },
      );
      AppLog.event('chip_read', {
        'passive_auth': document.passiveAuth.status.name,
        'dg11': document.dg11 != null,
      });
      if (isClosed) {
        document.wipe();
        return;
      }
      _document = document;
      emit(FaceStep(document: document, sampleSelfie: _s.sampleSelfie));
    } on ChipReadException catch (e) {
      final error = kycErrorFromChip(e.error);
      AppLog.event('chip_read_failed', {'error': error.name});
      if (isClosed) return;
      if (error == KycError.wrongMrz) {
        emit(MrzStep(prefill: key, error: error, isDemo: _s.isDemo));
      } else {
        emit(ChipErrorStep(key: key, error: error));
      }
    }
  }

  /// Goes back to the MRZ form, keeping what was entered.
  void editMrz() {
    final current = state;
    final key = switch (current) {
      ChipErrorStep(:final key) => key,
      ChipStep(:final key) => key,
      _ => _s.demoKey,
    };
    emit(MrzStep(prefill: key, isDemo: _s.isDemo));
  }

  /// A selfie was captured, after the active [challenges] if any.
  ///
  /// A configured liveness provider decides first; completed challenges
  /// are reported only when no provider ran.
  Future<void> faceCaptured(
    Uint8List selfie, {
    List<FaceChallenge> challenges = const [],
  }) async {
    final document = _document;
    if (document == null) return;
    // Own a copy so wiping it never touches the caller's buffer.
    final copy = Uint8List.fromList(selfie);
    _selfie = copy;
    final checked = await _s.liveness.check(copy);
    final liveness =
        checked == LivenessOutcome.notPerformed && challenges.isNotEmpty
        ? LivenessOutcome.challengesPassed
        : checked;
    AppLog.event('face_captured', {'liveness': liveness.name});
    emit(ReviewStep(document: document, selfie: copy, liveness: liveness));
  }

  void retakeFace() {
    final document = _document;
    if (document == null) return;
    _clearSelfie();
    emit(FaceStep(document: document, sampleSelfie: _s.sampleSelfie));
  }

  /// Sends the raw chip files and the selfie for verification.
  Future<void> submit() async {
    final current = state;
    if (current is! ReviewStep || current.submitting) return;
    emit(current.copyWith(submitting: true));
    try {
      final session = await _s.repository.startSession();
      final decision = await _s.repository.submit(
        KycSubmission(
          session: session,
          chipFiles: current.document.rawFiles,
          selfie: current.selfie,
          liveness: current.liveness,
          clientPassiveAuth: current.document.passiveAuth.status,
        ),
      );
      AppLog.event('submitted', {'decision': decision.name});
      _wipe();
      emit(ResultStep(decision));
    } on KycRepositoryException {
      AppLog.event('submit_failed');
      emit(current.copyWith(error: KycError.submissionFailed));
    }
  }

  /// Discards everything and returns to the start.
  void restart() {
    _wipe();
    _services = null;
    emit(const ConsentStep());
  }

  void _clearSelfie() {
    final selfie = _selfie;
    if (selfie != null) selfie.fillRange(0, selfie.length, 0);
    _selfie = null;
  }

  void _wipe() {
    _document?.wipe();
    _document = null;
    _clearSelfie();
  }

  @override
  Future<void> close() {
    _wipe();
    return super.close();
  }
}
