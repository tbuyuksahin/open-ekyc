import 'package:ekyc_document_capture/ekyc_document_capture.dart';
import 'package:ekyc_face_capture/ekyc_face_capture.dart';
import 'package:ekyc_nfc_reader/ekyc_nfc_reader.dart';
import 'package:ekyc_sdk/src/config.dart';
import 'package:flutter/foundation.dart';

/// Where the flow is; each stage is one screen.
@immutable
sealed class EkycStage {
  const EkycStage();
}

/// Photographing the document.
final class EkycDocumentStage extends EkycStage {
  /// Creates the stage.
  const EkycDocumentStage();
}

/// Collecting the MRZ key.
final class EkycMrzStage extends EkycStage {
  /// Creates the stage.
  const EkycMrzStage({this.prefill, this.error});

  /// Values to start the form with.
  final MrzKey? prefill;

  /// Set when the chip rejected the previous key.
  final ChipReadError? error;
}

/// Reading the chip, or showing why it failed.
final class EkycChipStage extends EkycStage {
  /// Creates the stage.
  const EkycChipStage({
    required this.mrzKey,
    this.step = ChipReadStep.waitingForCard,
    this.progress = 0,
    this.error,
  });

  /// The key in use.
  final MrzKey mrzKey;

  /// Current read step.
  final ChipReadStep step;

  /// Overall progress (0-1).
  final double progress;

  /// Set when the read failed.
  final ChipReadError? error;
}

/// Taking the selfie.
final class EkycFaceStage extends EkycStage {
  /// Creates the stage.
  const EkycFaceStage();
}

/// Finished; [result] holds what was collected.
final class EkycDoneStage extends EkycStage {
  /// Creates the stage.
  const EkycDoneStage(this.result);

  /// What the flow collected.
  final EkycResult result;
}

/// Runs the steps of an [EkycConfig] and owns the personal data until the
/// flow completes.
///
/// If the flow is cancelled or disposed before it completes, everything
/// collected so far is wiped.
class EkycFlowController extends ChangeNotifier {
  /// Creates a controller for [config].
  ///
  /// Throws [ArgumentError] when the steps cannot run as configured.
  EkycFlowController(this.config, {this.messages = const ChipReadMessages()})
    : _reader = ChipReader(
        session: config.nfcSession,
        trustStore: config.trustStore ?? CscaStore.empty(),
      ) {
    if (config.steps.isEmpty) {
      throw ArgumentError.value(config.steps, 'steps', 'Give at least one');
    }
    if (config.has(EkycStep.nfc) &&
        !config.has(EkycStep.mrz) &&
        config.mrzKey == null) {
      throw ArgumentError(
        'EkycStep.nfc without EkycStep.mrz needs EkycConfig.mrzKey',
      );
    }
    if (config.has(EkycStep.document)) {
      _stage = const EkycDocumentStage();
    } else if (config.has(EkycStep.mrz)) {
      _stage = EkycMrzStage(prefill: config.mrzKey);
    } else if (config.has(EkycStep.nfc)) {
      _stage = EkycChipStage(mrzKey: config.mrzKey!);
    } else {
      _stage = const EkycFaceStage();
    }
  }

  /// The configuration being run.
  final EkycConfig config;

  /// Texts for the iOS NFC sheet.
  ChipReadMessages messages;

  final ChipReader _reader;
  late EkycStage _stage;
  MrzKey? _key;
  DocumentData? _document;
  DocumentCaptureResult? _photos;
  bool _disposed = false;
  bool _handedOver = false;

  /// The current stage.
  EkycStage get stage => _stage;

  /// Starts the first step's work. Call once after construction.
  Future<void> start() async {
    final stage = _stage;
    if (stage is EkycChipStage) await _readChip(stage.mrzKey);
  }

  /// The document photo step produced [capture].
  ///
  /// When the MRZ was read on the way and
  /// [EkycDocumentOptions.skipMrzWhenRead] is set, the MRZ step is
  /// skipped.
  Future<void> documentCaptured(DocumentCaptureResult capture) async {
    if (_disposed) {
      capture.wipe();
      return;
    }
    _photos?.wipe();
    _photos = capture;
    final mrz = capture.mrz;
    if (mrz != null &&
        config.document.skipMrzWhenRead &&
        config.has(EkycStep.mrz)) {
      await submitMrz(mrz.key);
    } else {
      await _advanceFrom(EkycStep.document);
    }
  }

  /// The MRZ step produced [key].
  Future<void> submitMrz(MrzKey key) async {
    _key = key;
    await _advanceFrom(EkycStep.mrz);
  }

  /// Reads the chip again with the same key.
  Future<void> retryChip() async {
    final stage = _stage;
    if (stage is EkycChipStage) await _readChip(stage.mrzKey);
  }

  /// Goes back to the MRZ step, keeping what was entered.
  void editMrz() {
    final stage = _stage;
    if (!config.has(EkycStep.mrz) || stage is! EkycChipStage) return;
    _set(EkycMrzStage(prefill: stage.mrzKey));
  }

  /// The selfie step produced [capture].
  Future<void> faceCaptured(FaceCaptureResult capture) async {
    // Own a copy so wiping never touches the camera's buffer.
    final selfie = Uint8List.fromList(capture.image);
    final checked = await config.liveness.check(selfie);
    if (_disposed) {
      selfie.fillRange(0, selfie.length, 0);
      return;
    }
    final liveness =
        checked == LivenessOutcome.notPerformed && capture.challengesPassed
        ? LivenessOutcome.challengesPassed
        : checked;
    _finish(
      selfie: selfie,
      challenges: capture.challenges,
      liveness: liveness,
    );
  }

  Future<void> _readChip(MrzKey key) async {
    _key = key;
    _document?.wipe();
    _document = null;
    _set(EkycChipStage(mrzKey: key));
    try {
      final document = await _reader.read(
        key,
        messages: messages,
        onProgress: (step, progress) =>
            _set(EkycChipStage(mrzKey: key, step: step, progress: progress)),
      );
      if (_disposed) {
        document.wipe();
        return;
      }
      _document = document;
      await _advanceFrom(EkycStep.nfc);
    } on ChipReadException catch (e) {
      if (e.error == ChipReadError.wrongMrz && config.has(EkycStep.mrz)) {
        _set(EkycMrzStage(prefill: key, error: e.error));
      } else {
        _set(EkycChipStage(mrzKey: key, error: e.error));
      }
    }
  }

  static const List<EkycStep> _order = [
    EkycStep.document,
    EkycStep.mrz,
    EkycStep.nfc,
    EkycStep.face,
  ];

  Future<void> _advanceFrom(EkycStep done) async {
    for (final step in _order.skip(_order.indexOf(done) + 1)) {
      if (!config.has(step)) continue;
      switch (step) {
        case EkycStep.mrz:
          _set(EkycMrzStage(prefill: config.mrzKey));
        case EkycStep.nfc:
          // The constructor guarantees a key when there is no MRZ step.
          await _readChip((_key ?? config.mrzKey)!);
        case EkycStep.face:
          _set(const EkycFaceStage());
        case EkycStep.document:
          continue;
      }
      return;
    }
    _finish();
  }

  void _finish({
    Uint8List? selfie,
    List<FaceChallenge> challenges = const [],
    LivenessOutcome liveness = LivenessOutcome.notPerformed,
  }) {
    _handedOver = true;
    final document = _document;
    final photos = _photos;
    _set(
      EkycDoneStage(
        EkycResult(
          mrzKey: _key,
          document: document,
          documentPhotos: photos,
          crossCheck: photos?.crossCheck(
            expected: document == null
                ? null
                : DocumentFields.fromMrz(document.mrz),
          ),
          selfie: selfie,
          challenges: challenges,
          liveness: liveness,
        ),
      ),
    );
  }

  void _set(EkycStage stage) {
    if (_disposed) return;
    _stage = stage;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    // Once the result was handed over, the host owns the data.
    if (!_handedOver) {
      _document?.wipe();
      _photos?.wipe();
    }
    _document = null;
    _photos = null;
    super.dispose();
  }
}
