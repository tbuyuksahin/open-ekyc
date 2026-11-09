import 'package:meta/meta.dart';

/// A `YYMMDD` date from an MRZ.
///
/// MRZ dates carry only two year digits, so the century is resolved
/// relative to a reference date: birth dates are never in the future and
/// expiry dates are assumed to be at most 50 years ahead.
@immutable
class MrzDate {
  /// Creates a date from its six-character MRZ form.
  const MrzDate(this.raw);

  /// Creates the MRZ form of [date].
  factory MrzDate.fromDateTime(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return MrzDate('${two(date.year % 100)}${two(date.month)}${two(date.day)}');
  }

  /// The six characters as printed, for example `740812`.
  final String raw;

  /// Whether [raw] is six digits forming a real calendar date.
  bool get isWellFormed => _parts() != null;

  /// Resolves the date as a date of birth relative to [now].
  DateTime? asBirthDate({DateTime? now}) {
    final p = _parts();
    if (p == null) return null;
    final today = now ?? DateTime.now();
    var year = 2000 + p.$1;
    if (DateTime(year, p.$2, p.$3).isAfter(today)) year -= 100;
    return _date(year, p.$2, p.$3);
  }

  /// Resolves the date as an expiry date relative to [now].
  DateTime? asExpiryDate({DateTime? now}) {
    final p = _parts();
    if (p == null) return null;
    final today = now ?? DateTime.now();
    var year = 2000 + p.$1;
    if (year > today.year + 50) year -= 100;
    return _date(year, p.$2, p.$3);
  }

  // Rejects dates such as 29 February in a non-leap century.
  static DateTime? _date(int year, int month, int day) {
    final date = DateTime(year, month, day);
    return date.day == day ? date : null;
  }

  (int, int, int)? _parts() {
    if (raw.length != 6 || int.tryParse(raw) == null) return null;
    final y = int.parse(raw.substring(0, 2));
    final m = int.parse(raw.substring(2, 4));
    final d = int.parse(raw.substring(4, 6));
    if (m < 1 || m > 12 || d < 1) return null;
    final lastDay = DateTime(2000 + y, m + 1, 0).day;
    if (d > lastDay) return null;
    return (y, m, d);
  }

  @override
  bool operator ==(Object other) => other is MrzDate && other.raw == raw;

  @override
  int get hashCode => raw.hashCode;

  @override
  String toString() => raw;
}
