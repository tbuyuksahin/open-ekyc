import 'package:ekyc_document_capture/src/frame_quality.dart';
import 'package:flutter/foundation.dart';

/// What the user should fix before the photo is taken.
enum DocumentHint {
  /// The expected side is not in view (on the front, also when no
  /// portrait is seen).
  noDocument,

  /// The other side of the document is in view.
  wrongSide,

  /// There is not enough light.
  tooDark,

  /// A reflection hides part of the document.
  glare,

  /// The image is out of focus or moving.
  blurry,

  /// Everything is fine; keep the document still.
  holdStill,
}

/// What one frame showed.
@immutable
class DocumentObservation {
  /// Creates an observation.
  const DocumentObservation({
    required this.textLines,
    required this.hasMrz,
    this.mrzLike = false,
    this.portraits,
    this.quality,
  });

  /// Whether [line] looks like a line of a machine readable zone even if
  /// it could not be read in full: filler signs, or a long run of capital
  /// letters and digits without spaces.
  static bool looksLikeMrz(String line) {
    final compact = line.replaceAll(' ', '').toUpperCase();
    final fillers = RegExp('[<«‹]').allMatches(compact).length;
    if (fillers >= 3 && compact.length >= 10) return true;
    return _mrzRun.hasMatch(compact);
  }

  static final _mrzRun = RegExp('[A-Z0-9<]{25,}');

  /// Lines of text recognized in the frame.
  final int textLines;

  /// Whether a valid machine readable zone was read.
  final bool hasMrz;

  /// Whether any line looks like a machine readable zone, read in full or
  /// not. See [looksLikeMrz].
  final bool mrzLike;

  /// Faces found in the frame, or `null` when no one looked.
  final int? portraits;

  /// Image quality, or `null` when the frame format cannot be measured;
  /// quality checks are skipped then.
  final FrameQuality? quality;
}

/// Decides when a document frame is good enough to photograph.
///
/// A side counts as present when its machine readable zone is read (on
/// the side that has one), or when at least [minTextLines] lines of text,
/// nothing that looks like a machine readable zone and, on the front, a
/// portrait are seen. The photo is released after [requiredStableFrames]
/// good frames in a row.
class DocumentQualityGate {
  /// Creates a gate.
  DocumentQualityGate({
    this.thresholds = const FrameQualityThresholds(),
    this.minTextLines = 3,
    this.requiredStableFrames = 3,
    this.requirePortrait = true,
  }) : assert(requiredStableFrames >= 1, 'At least one frame is required');

  /// Image quality limits.
  final FrameQualityThresholds thresholds;

  /// Text lines that make a side without an MRZ count as present.
  final int minTextLines;

  /// Good frames in a row before the photo.
  final int requiredStableFrames;

  /// Whether the front must show a portrait. Turn it off for documents
  /// whose front has no photo.
  final bool requirePortrait;

  int _stable = 0;

  /// How close the photo is, 0 to 1.
  double get progress => _stable / requiredStableFrames;

  /// The hint for one frame, without counting it.
  ///
  /// [expectPortrait] asks for a face, and applies only when
  /// [requirePortrait] is set.
  DocumentHint hintFor(
    DocumentObservation observation, {
    required bool expectMrz,
    bool expectPortrait = false,
  }) {
    final quality = observation.quality;
    if (quality != null && quality.brightness < thresholds.minBrightness) {
      return DocumentHint.tooDark;
    }
    if (quality != null && quality.glare > thresholds.maxGlare) {
      return DocumentHint.glare;
    }
    if (expectMrz) {
      if (!observation.hasMrz) return DocumentHint.noDocument;
    } else {
      if (observation.hasMrz || observation.mrzLike) {
        return DocumentHint.wrongSide;
      }
      if (observation.textLines < minTextLines) return DocumentHint.noDocument;
      if (expectPortrait &&
          requirePortrait &&
          (observation.portraits ?? 0) == 0) {
        return DocumentHint.noDocument;
      }
    }
    if (quality != null && quality.sharpness < thresholds.minSharpness) {
      return DocumentHint.blurry;
    }
    return DocumentHint.holdStill;
  }

  /// Counts one frame. Returns `null` when the photo should be taken,
  /// otherwise the hint to show.
  DocumentHint? evaluate(
    DocumentObservation observation, {
    required bool expectMrz,
    bool expectPortrait = false,
  }) {
    final hint = hintFor(
      observation,
      expectMrz: expectMrz,
      expectPortrait: expectPortrait,
    );
    if (hint != DocumentHint.holdStill) {
      _stable = 0;
      return hint;
    }
    _stable++;
    if (_stable < requiredStableFrames) return hint;
    return null;
  }

  /// Starts counting again, for the next side or after a failed photo.
  void reset() => _stable = 0;
}
