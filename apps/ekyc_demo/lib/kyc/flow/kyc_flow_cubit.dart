import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:ekyc_demo/core/app_log.dart';
import 'package:ekyc_demo/kyc/domain/kyc_error.dart';
import 'package:ekyc_demo/kyc/domain/kyc_repository.dart';
import 'package:ekyc_demo/kyc/flow/kyc_flow_state.dart';
import 'package:ekyc_demo/kyc/flow/kyc_services.dart';
import 'package:ekyc_sdk/ekyc_sdk.dart';

/// Loads the services for a run: real hardware or the demo document.
typedef KycServicesLoader = Future<KycServices> Function({required bool demo});

/// Drives the verification flow and owns the personal data it collects.
///
/// Personal data lives only in states and is wiped on submit, restart and
/// close, so abandoning the flow at any point leaves nothing behind.
class KycFlowCubit extends Cubit<KycFlowState> {
  KycFlowCubit(this._load, {this.photographDocument = false})
    : super(const ConsentStep());

  final KycServicesLoader _load;

  /// Whether the flow starts by photographing the document. Skipped in
  /// demo mode, which has no physical document.
  final bool photographDocument;
  KycServices? _services;
  DocumentData? _document;
  DocumentCaptureResult? _photos;
  Uint8List? _selfie;

  KycServices get _s => _services ?? (throw StateError('Flow not started'));

  /// The user agreed to the processing described on the consent screen.
  Future<void> start({required bool demo}) async {
    emit(const ConsentStep(loading: true));
    _services = await _load(demo: demo);
    AppLog.event('flow_started', {'demo': demo});
    if (photographDocument && !_s.isDemo) {
      emit(const DocumentStep());
    } else {
      emit(MrzStep(prefill: _s.demoKey, isDemo: _s.isDemo));
    }
  }

  /// The document was photographed. When its MRZ was read on the way, the
  /// chip is read straight away; otherwise the MRZ step follows.
  Future<void> documentCaptured(
    DocumentCaptureResult capture,
    ChipReadMessages messages,
  ) async {
    if (isClosed || state is! DocumentStep) {
      capture.wipe();
      return;
    }
    _photos?.wipe();
    _photos = capture;
    final mrz = capture.mrz;
    AppLog.event('document_captured', {
      'sides': capture.images.length,
      'mrz': mrz != null,
    });
    if (mrz == null) {
      emit(const MrzStep());
    } else {
      await readChip(mrz.key, messages);
    }
  }

  /// Reads the chip with [key].
  Future<void> readChip(MrzKey key, ChipReadMessages messages) async {
    _wipeChip();
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
    final crossCheck = _photos?.crossCheck(
      expected: DocumentFields.fromMrz(document.mrz),
    );
    AppLog.event('face_captured', {
      'liveness': liveness.name,
      'printed_fields_found': ?crossCheck?.found.length,
    });
    emit(
      ReviewStep(
        document: document,
        selfie: copy,
        liveness: liveness,
        crossCheck: crossCheck,
      ),
    );
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
          documentPhotos: _photos?.images ?? const {},
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

  void _wipeChip() {
    _document?.wipe();
    _document = null;
    _clearSelfie();
  }

  void _wipe() {
    _wipeChip();
    _photos?.wipe();
    _photos = null;
  }

  @override
  Future<void> close() {
    _wipe();
    return super.close();
  }
}
