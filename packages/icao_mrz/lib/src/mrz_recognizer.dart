import 'package:icao_mrz/src/mrz.dart';

enum _Kind { digit, letter, any }

typedef _Span = (int line, int start, int end, _Kind kind);

/// Finds and repairs an MRZ in noisy OCR output.
///
/// OCR engines confuse similar glyphs (`0`/`O`, `1`/`I`, `5`/`S`, `8`/`B`)
/// and the `<` filler (`«`, `‹`, `＜`). The recognizer cleans each line,
/// looks for a block of lines with a known MRZ shape and corrects
/// characters according to what each position may contain. A result is
/// only returned when every check digit is correct, so a misread is
/// rejected rather than silently accepted.
abstract final class MrzRecognizer {
  /// Returns the first fully valid MRZ found in [ocrText], or `null`.
  static Mrz? recognize(String ocrText) {
    final lines = ocrText
        .split(RegExp(r'\r?\n'))
        .map(_clean)
        .where((l) => l.length >= 28)
        .toList();
    for (final format in [MrzFormat.td3, MrzFormat.td2, MrzFormat.td1]) {
      for (var i = 0; i + format.lineCount <= lines.length; i++) {
        final block = [
          for (var j = 0; j < format.lineCount; j++)
            _fit(lines[i + j], format.lineLength),
        ];
        if (block.contains(null)) continue;
        final repaired = _repair(block.cast<String>(), format);
        final mrz = Mrz.tryParse(repaired);
        if (mrz != null && mrz.isValid) return mrz;
      }
    }
    return null;
  }

  static String _clean(String line) => line
      .toUpperCase()
      .replaceAll(RegExp('[«‹<〈＜]'), '<')
      .replaceAll(RegExp(r'\s'), '')
      .replaceAll(RegExp('[^A-Z0-9<]'), '');

  /// Accepts lines that are up to two characters off, which happens when
  /// OCR drops or adds trailing fillers.
  static String? _fit(String line, int length) {
    if ((line.length - length).abs() > 2) return null;
    if (line.length > length) return line.substring(0, length);
    return line.padRight(length, '<');
  }

  static const _toDigit = {
    'O': '0',
    'Q': '0',
    'D': '0',
    'I': '1',
    'L': '1',
    'Z': '2',
    'S': '5',
    'G': '6',
    'T': '7',
    'B': '8',
  };
  static const _toLetter = {
    '0': 'O',
    '1': 'I',
    '2': 'Z',
    '5': 'S',
    '6': 'G',
    '8': 'B',
  };

  static List<String> _repair(List<String> lines, MrzFormat format) {
    final chars = [for (final l in lines) l.split('')];
    for (final (line, start, end, kind) in _schema[format]!) {
      for (var i = start; i < end; i++) {
        final c = chars[line][i];
        chars[line][i] = switch (kind) {
          _Kind.digit => _toDigit[c] ?? c,
          _Kind.letter => _toLetter[c] ?? c,
          _Kind.any => c,
        };
      }
    }
    return [for (final c in chars) c.join()];
  }

  // Positions whose content type is fixed by ICAO 9303 Parts 4-6. Document
  // numbers and optional data are alphanumeric and left untouched; check
  // digits catch errors there.
  static const Map<MrzFormat, List<_Span>> _schema = {
    MrzFormat.td3: [
      (0, 2, 5, _Kind.letter),
      (0, 5, 44, _Kind.letter),
      (1, 9, 10, _Kind.digit),
      (1, 10, 13, _Kind.letter),
      (1, 13, 20, _Kind.digit),
      (1, 21, 28, _Kind.digit),
      (1, 43, 44, _Kind.digit),
    ],
    MrzFormat.td2: [
      (0, 2, 5, _Kind.letter),
      (0, 5, 36, _Kind.letter),
      (1, 10, 13, _Kind.letter),
      (1, 13, 20, _Kind.digit),
      (1, 21, 28, _Kind.digit),
      (1, 35, 36, _Kind.digit),
    ],
    MrzFormat.td1: [
      (0, 2, 5, _Kind.letter),
      (1, 0, 7, _Kind.digit),
      (1, 8, 15, _Kind.digit),
      (1, 15, 18, _Kind.letter),
      (1, 29, 30, _Kind.digit),
      (2, 0, 30, _Kind.letter),
    ],
  };
}
