import 'dart:async';

import 'package:flutter/services.dart';

/// In-memory ring buffer of app logs, two sources:
///  1. Dart zone print capture (main.dart zone) — Dart-side lines.
///  2. Native logcat stream ("zen/diag_logs" EventChannel) — every
///     native/framework line (ExoPlayer, AudioTrack, MediaCodec,
///     ZenNative, ZenLossless, AudioEffect, ...), the app's own PID
///     only. Flutter-tag lines are skipped natively to avoid
///     duplicates with source 1.
class DiagnosticsService {
  DiagnosticsService._();
  static final DiagnosticsService instance = DiagnosticsService._();

  static const int maxLines = 4000;
  static const _logcatChannel = EventChannel('zen/diag_logs');

  final List<DiagLine> _lines = [];
  final _controller = StreamController<void>.broadcast();
  StreamSubscription? _logcatSub;
  bool _logcatActive = false;

  Stream<void> get changes => _controller.stream;
  List<DiagLine> get lines => List.unmodifiable(_lines);
  bool get logcatActive => _logcatActive;

  /// Starts the native logcat stream. Call when the viewer opens; the
  /// native side stops the reader on cancel (leaving the screen).
  void startLogcatCapture() {
    if (_logcatSub != null) return;
    _logcatSub = _logcatChannel.receiveBroadcastStream().listen(
          (event) {
        if (event is Map) {
          _add(DiagLine(
            ts: DateTime.now(),
            level: (event['level'] ?? 'I').toString(),
            tag: (event['tag'] ?? 'logcat').toString(),
            message: (event['message'] ?? '').toString(),
            source: 'native',
          ));
        }
      },
      onError: (_) {},
      cancelOnError: false,
      onDone: () => _logcatActive = false,
    );
    _logcatActive = true;
  }

  void stopLogcatCapture() {
    _logcatSub?.cancel();
    _logcatSub = null;
    _logcatActive = false;
  }

  /// Zone print handler (main.dart) — Dart-side lines.
  void capture(String line) {
    var msg = line;
    if (msg.startsWith('flutter: ')) msg = msg.substring(8);
    _add(DiagLine(
      ts: DateTime.now(),
      level: 'I',
      tag: 'dart',
      message: msg,
      source: 'dart',
    ));
  }

  /// Explicit log entry (crash handler).
  void log(String tag, String message) {
    _add(DiagLine(
      ts: DateTime.now(),
      level: 'E',
      tag: tag,
      message: message,
      source: 'dart',
    ));
  }

  void _add(DiagLine line) {
    _lines.add(line);
    if (_lines.length > maxLines) {
      _lines.removeRange(0, _lines.length - maxLines);
    }
    if (!_controller.isClosed) _controller.add(null);
  }

  void clear() {
    _lines.clear();
    if (!_controller.isClosed) _controller.add(null);
  }
}

class DiagLine {
  const DiagLine({
    required this.ts,
    required this.level,
    required this.tag,
    required this.message,
    required this.source,
  });

  final DateTime ts;
  final String level; // V D I W E F
  final String tag;
  final String message;
  final String source; // 'dart' | 'native'
}