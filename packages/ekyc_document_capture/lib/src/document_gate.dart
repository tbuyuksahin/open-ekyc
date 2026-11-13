import 'package:ekyc_document_capture/src/frame_quality.dart';
import 'package:flutter/foundation.dart';

/// What the user should fix before the photo is taken.
enum DocumentHint {
  /// The expected side is not in view.
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
    this.quality,
  });

  /// Lines of text recognized in the frame.
  final int textLines;

  /// Whether a valid machine readable zone was read.
  final bool hasMrz;

  /// Image quality, or `null` when the frame format cannot be measured;
  /// quality checks are skipped then.
  final FrameQuality? quality;
}

/// Decides when a document frame is good enough to photograph.
///
/// A side counts as present when its machine readable zone is read (on
/// the side that has one) or when at least [minTextLines] lines of text
/// are seen (on the side that has none). The photo is released after
/// [requiredStableFrames] good frames in a row.
class DocumentQualityGate {
  /// Creates a gate.
  DocumentQualityGate({
    this.thresholds = const FrameQualityThresholds(),
    this.minTextLines = 3,
    this.requiredStableFrames = 3,
  }) : assert(requiredStableFrames >= 1, 'At least one frame is required');

  /// Image quality limits.
  final FrameQualityThresholds thresholds;

  /// Text lines that make a side without an MRZ count as present.
  final int minTextLines;

  /// Good frames in a row before the photo.
  final int requiredStableFrames;

  int _stable = 0;

  /// How close the photo is, 0 to 1.
  double get progress => _stable / requiredStableFrames;

  /// The hint for one frame, without counting it.
  DocumentHint hintFor(
    DocumentObservation observation, {
    required bool expectMrz,
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
      if (observation.hasMrz) return DocumentHint.wrongSide;
      if (observation.textLines < minTextLines) return DocumentHint.noDocument;
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
  }) {
    final hint = hintFor(observation, expectMrz: expectMrz);
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
