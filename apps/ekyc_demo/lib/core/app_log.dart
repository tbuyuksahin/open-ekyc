import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Privacy-safe event logging.
///
/// Only event names and non-personal fields (enums, booleans, counts) may
/// be logged. Never pass names, document numbers, dates, MRZ text, images
/// or keys. Release builds log nothing.
abstract final class AppLog {
  /// Receives events in addition to the debug console; set by tests or an
  /// analytics adapter.
  static void Function(String event, Map<String, Object> fields)? sink;

  static void event(String name, [Map<String, Object> fields = const {}]) {
    assert(
      fields.values.every((v) => v is bool || v is num || v is String),
      'Only primitive, non-personal values may be logged',
    );
    sink?.call(name, fields);
    if (kDebugMode) developer.log('$name $fields', name: 'ekyc');
  }
}
