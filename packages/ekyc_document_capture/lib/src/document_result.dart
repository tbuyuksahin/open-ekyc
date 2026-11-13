import 'dart:typed_data';

import 'package:ekyc_document_capture/src/document_kind.dart';
import 'package:ekyc_document_capture/src/document_text.dart';
import 'package:icao_mrz/icao_mrz.dart';

/// The photos of a document and what was read from them on the device.
///
/// Holds personal data. Keep it in memory only and call [wipe] when you
/// are done.
class DocumentCaptureResult {
  /// Creates a result.
  DocumentCaptureResult({
    required this.kind,
    required Map<DocumentSide, Uint8List> images,
    List<String> frontText = const [],
    this.mrz,
  }) : images = Map.unmodifiable(images),
       _frontText = List.of(frontText);

  /// The document that was captured.
  final DocumentKind kind;

  /// JPEG bytes of each captured side.
  final Map<DocumentSide, Uint8List> images;

  final List<String> _frontText;

  /// The machine readable zone, when it was read while capturing the side
  /// that carries it.
  final Mrz? mrz;

  /// JPEG bytes of the front.
  Uint8List? get front => images[DocumentSide.front];

  /// JPEG bytes of the back.
  Uint8List? get back => images[DocumentSide.back];

  /// Lines of text recognized on the front when its photo was taken.
  List<String> get frontText => List.unmodifiable(_frontText);

  /// Compares the text printed on the front with [expected], or with the
  /// captured [mrz] when [expected] is omitted.
  ///
  /// Returns `null` when there is nothing to compare: no front text, or
  /// neither [expected] nor an MRZ.
  DocumentCrossCheck? crossCheck({DocumentFields? expected, DateTime? now}) {
    final source = mrz;
    final fields =
        expected ??
        (source == null ? null : DocumentFields.fromMrz(source, now: now));
    if (fields == null || _frontText.isEmpty) return null;
    return DocumentCrossCheck.compare(
      printedText: _frontText,
      expected: fields,
    );
  }

  /// Overwrites the photos with zeros and forgets the recognized text.
  void wipe() {
    for (final bytes in images.values) {
      bytes.fillRange(0, bytes.length, 0);
    }
    _frontText.clear();
  }

  @override
  String toString() => 'DocumentCaptureResult(<redacted>)';
}
