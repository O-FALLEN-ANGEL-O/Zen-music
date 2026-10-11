import 'package:flutter/services.dart';

/// Bridge to the native DSP engine (:lossless module) — zen/lossless.
///
/// Channel contract:
/// - available    → bool (native library loaded; one engine per player)
/// - bandCenters  → [double Hz ×15] — fixed ISO centers mirrored from
///                  DspProcessor.cpp (kEqFrequenciesHz)
/// - setEqualizer {enabled, gains} → broadcast to all engine instances
///
/// The engine processes 16-bit decoded streams (streaming AAC/Opus and
/// 16-bit FLAC). Hi-res sources (24/32-bit) bypass the engine by design,
/// so the equalizer has no effect on them.
class ZenEqBand {
  const ZenEqBand({required this.centerFrequency, this.gain = 0.0});
  final double centerFrequency;

  /// Current band gain in dB, as reported by the handler that built
  /// this parameter object (native gains for the engine path, the
  /// session band level for the fallback).
  final double gain;
}

class ZenEqParameters {
  const ZenEqParameters({
    required this.minDecibels,
    required this.maxDecibels,
    required this.bands,
    required this.isNative,
  });

  final double minDecibels;
  final double maxDecibels;
  final List<ZenEqBand> bands;
  final bool isNative;
}

class LosslessDspService {
  LosslessDspService._();
  static final LosslessDspService instance = LosslessDspService._();

  static const _channel = MethodChannel('zen/lossless');
  static const bandCount = 15;
  static const minDb = -8.0;
  static const maxDb = 8.0;

  bool? _availableCache;

  Future<bool> get available async {
    if (_availableCache != null) return _availableCache!;
    try {
      _availableCache = await _channel.invokeMethod<bool>('available') ?? false;
    } on PlatformException {
      _availableCache = false;
    } on MissingPluginException {
      _availableCache = false;
    }
    return _availableCache!;
  }

  Future<List<double>> get bandCenters async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('bandCenters');
      final centers =
          raw?.map((e) => (e as num).toDouble()).toList() ?? const <double>[];
      if (centers.length == bandCount) return centers;
    } on PlatformException {
      // fall through to the mirrored constants
    } on MissingPluginException {
      // fall through to the mirrored constants
    }
    return const [
      25, 40, 63, 100, 160, 250, 400, 630, 1000, 1600,
      2500, 4000, 6300, 10000, 16000,
    ];
  }

  Future<void> setEqualizer({
    required bool enabled,
    required List<double> gains,
  }) async {
    try {
      await _channel.invokeMethod<void>('setEqualizer', {
        'enabled': enabled,
        'gains': [for (final g in gains) g.toDouble()],
      });
    } on PlatformException {
      // Native stays at its previous state; never throws into the UI.
    } on MissingPluginException {
      // ignore
    }
  }
}