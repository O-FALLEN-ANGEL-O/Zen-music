import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../audio/zen_audio_handler.dart';
import '../main.dart';
import '../services/dsp_service.dart';
import '../services/lossless_dsp_service.dart';
import '../theme/spotify_theme.dart';

/// LastWave-style EQ: all 15 bands as vertical sliders in a swipeable
/// page-snapping row (no overflow at any screen width), curve preview
/// above, presets + AutoEq import below. Native engine first (15 fixed
/// ISO bands, ±8 dB), session-EQ fallback.
class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  ZenEqParameters? _params;
  List<double> _gains = [];
  bool _enabled = false;
  bool _isLoading = true;
  String? _activePreset;
  int? _dragBand;

  static const Map<String, List<double>> _presets = {
    'Balanced': [],
    'Bass Boost': [8.0, 3.0, -2.0],
    'Treble Boost': [-2.0, 2.0, 8.0],
    'Vocal': [2.0, 6.0, 4.0, 1.0],
    'Rock': [7.0, 2.0, 4.0, 6.0],
    'Pop': [3.0, 4.0, 2.0],
    'Electronic': [9.0, -1.0, 3.0, 7.0],
  };

  List<double> _gainsForPreset(List<double> stops, int bandCount) {
    if (stops.isEmpty) return List<double>.filled(bandCount, 0);
    return List<double>.generate(bandCount, (i) {
      final position = bandCount > 1 ? i / (bandCount - 1) : 0.0;
      final segment = (position * (stops.length - 1)).floor();
      final clamped = segment.clamp(0, stops.length - 1);
      return stops[clamped];
    });
  }

  Future<void> _applyPreset(String name) async {
    final gains = _gainsForPreset(_presets[name]!, _params!.bands.length);
    for (var i = 0; i < gains.length; i++) {
      await audioHandler.setEqBandGain(i, gains[i]);
    }
    if (!mounted) return;
    setState(() {
      _gains = gains;
      _activePreset = name;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final params = await audioHandler.getEqParameters();
    if (!mounted) return;
    setState(() {
      _params = params;
      _gains = params?.bands.map((b) => b.gain).toList() ?? [];
      _isLoading = false;
    });
  }

  String _formatFrequency(double hz) {
    if (hz >= 1000) {
      return hz >= 10000
          ? '${(hz / 1000).toStringAsFixed(0)}k'
          : '${(hz / 1000).toStringAsFixed(1)}k';
    }
    return '${hz.round()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Equalizer',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: SpotifyColors.textPrimary,
            )),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded,
                color: SpotifyColors.textPrimary),
            tooltip: 'Reset bands',
            onPressed: () async {
              await audioHandler.resetEqBands();
              if (!mounted || _params == null) return;
              setState(() {
                _gains = List<double>.filled(_params!.bands.length, 0);
                _activePreset = null;
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(color: SpotifyColors.green))
          : _params == null
          ? const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Equalizer is not available on this device',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SpotifyColors.textSecondary,
              fontSize: 15,
            ),
          ),
        ),
      )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final native = _params!.isNative;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Enable switch
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: SpotifyColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SwitchListTile.adaptive(
            value: _enabled,
            activeColor: SpotifyColors.green,
            contentPadding: EdgeInsets.zero,
            title: Text(
              native ? 'Native equalizer' : 'Enable equalizer',
              style: const TextStyle(
                color: SpotifyColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            subtitle: native
                ? const Text('15-band DSP on the audio engine',
                style: TextStyle(
                    color: SpotifyColors.textTertiary, fontSize: 12))
                : null,
            onChanged: (value) async {
              await audioHandler.setEqEnabled(value);
              if (!mounted) return;
              setState(() => _enabled = value);
            },
          ),
        ),
        const SizedBox(height: 20),

        // Curve preview
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SpotifyColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            height: 120,
            width: double.infinity,
            child: CustomPaint(painter: _EqCurvePainter(_gains)),
          ),
        ),
        const SizedBox(height: 20),

        // Vertical band sliders — 15 fixed-width bands in a
        // horizontally scrollable, page-snapping row: ~7 bands per
        // screen, swipe for the rest. No overflow at any width.
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: SpotifyColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: _params!.bands.isEmpty
              ? const SizedBox(height: 200)
              : SizedBox(
            height: 240,
            child: PageView(
              controller: PageController(viewportFraction: 0.13),
              physics: const PageScrollPhysics(),
              padEnds: false,
              children: [
                for (var i = 0; i < _params!.bands.length; i++)
                  _BandSlider(
                    label: _formatFrequency(
                        _params!.bands[i].centerFrequency),
                    gain: _gains[i],
                    min: _params!.minDecibels,
                    max: _params!.maxDecibels,
                    isDragging: _dragBand == i,
                    onChanged: (v) {
                      setState(() {
                        _gains[i] = v;
                        _dragBand = i;
                        _activePreset = null;
                      });
                    },
                    onEnd: (v) async {
                      await audioHandler.setEqBandGain(i, v);
                      if (mounted) setState(() => _dragBand = null);
                    },
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Presets
        const Text('Presets',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: SpotifyColors.textPrimary,
            )),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presets.keys.map((name) {
            final isActive = _activePreset == name;
            return ChoiceChip(
              label: Text(name),
              selected: isActive,
              onSelected: (_) => _applyPreset(name),
              selectedColor: SpotifyColors.green,
              labelStyle: TextStyle(
                color: isActive ? Colors.black : SpotifyColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: SpotifyColors.surface,
              side: BorderSide(
                color: SpotifyColors.textTertiary.withOpacity(0.25),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Import AutoEq text → projected onto the band centers.
        TextButton.icon(
          onPressed: _importAutoEq,
          icon: const Icon(Icons.upload_file_rounded,
              size: 16, color: SpotifyColors.green),
          label: const Text('Import AutoEq preset',
              style: TextStyle(fontSize: 13, color: SpotifyColors.green)),
        ),
        if (!native) ...[
          const SizedBox(height: 6),
          const Text(
            'System equalizer fallback — an approximation. The native '
                'engine path applies exact 15-band filtering.',
            style: TextStyle(
                color: SpotifyColors.textTertiary,
                fontSize: 11.5,
                height: 1.35),
          ),
        ],
      ],
    );
  }

  Future<void> _importAutoEq() async {
    final textCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SpotifyColors.surface,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Import AutoEq preset',
            style: TextStyle(
                color: SpotifyColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        content: TextField(
          controller: textCtrl,
          maxLines: 6,
          style: const TextStyle(
              color: SpotifyColors.textPrimary, fontSize: 12.5),
          decoration: const InputDecoration(
            hintText: 'Paste AutoEq text — Preamp / Filter lines',
            hintStyle: TextStyle(color: SpotifyColors.textTertiary),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: SpotifyColors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apply',
                  style: TextStyle(
                      color: SpotifyColors.green,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
    textCtrl.dispose();
    if (saved != true) return;

    final preset = await DspService.instance.parsePresetText(textCtrl.text);
    if (!mounted || preset == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not read that preset — check the text')));
      return;
    }

    // Project the parametric response onto the current band centers.
    final freqs =
    _params!.bands.map((b) => b.centerFrequency.toDouble()).toList();
    final db = await DspService.instance.responseAtFrequencies(
      bands: preset.bands,
      preamp: preset.preamp,
      frequencies: freqs,
    );
    if (!mounted || db == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not compute the EQ response')));
      return;
    }
    final min = _params!.minDecibels;
    final max = _params!.maxDecibels;
    final gains = db.map((d) => d.clamp(min, max).toDouble()).toList();
    for (var i = 0; i < gains.length; i++) {
      await audioHandler.setEqBandGain(i, gains[i]);
    }
    await audioHandler.setEqEnabled(true);
    if (!mounted) return;
    setState(() {
      _gains = gains;
      _enabled = true;
      _activePreset = 'AutoEq';
    });
  }
}

/// One vertical band: drag anywhere on the track to set gain. The thumb
/// renders at the current value; the readout sits above, the label below.
class _BandSlider extends StatelessWidget {
  const _BandSlider({
    required this.label,
    required this.gain,
    required this.min,
    required this.max,
    required this.isDragging,
    required this.onChanged,
    required this.onEnd,
  });

  final String label;
  final double gain;
  final double min;
  final double max;
  final bool isDragging;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onEnd;

  @override
  Widget build(BuildContext context) {
    final active = isDragging;
    final color = active ? SpotifyColors.highlight : SpotifyColors.green;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: active
                  ? SpotifyColors.highlight
                  : SpotifyColors.textTertiary,
            )),
        const SizedBox(height: 6),
        SizedBox(
          width: 40,
          height: 170,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (d) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final local = box.globalToLocal(d.globalPosition);
              // Track area excludes the label rows above/below.
              const trackTop = 28.0;
              const trackBottom = 170.0 - 14.0;
              final t =
                  1 - ((local.dy - trackTop) / (trackBottom - trackTop))
                      .clamp(0.0, 1.0);
              onChanged(min + (max - min) * t);
            },
            onVerticalDragEnd: (_) => onEnd(gain),
            onTapUp: (d) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final local = box.globalToLocal(d.globalPosition);
              const trackTop = 28.0;
              const trackBottom = 170.0 - 14.0;
              final t =
                  1 - ((local.dy - trackTop) / (trackBottom - trackTop))
                      .clamp(0.0, 1.0);
              final v = min + (max - min) * t;
              onChanged(v);
              onEnd(v);
            },
            child: CustomPaint(
              painter: _BandPainter(
                  fraction: ((gain - min) / (max - min)).clamp(0.0, 1.0),
                  color: color),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: active
                  ? SpotifyColors.highlight
                  : SpotifyColors.textTertiary,
            )),
      ],
    );
  }
}

class _BandPainter extends CustomPainter {
  const _BandPainter({required this.fraction, required this.color});
  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(centerX, 4), Offset(centerX, size.height - 4),
        trackPaint);

    final thumbY = size.height - 4 - (size.height - 8) * fraction;
    final activePaint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(centerX, thumbY), Offset(centerX, size.height - 4),
        activePaint);
    canvas.drawCircle(Offset(centerX, thumbY), 7, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BandPainter old) =>
      old.fraction != fraction || old.color != color;
}

/// Curve preview across the current gains (log-frequency x-axis,
/// mirroring DspService.frequencyGrid).
class _EqCurvePainter extends CustomPainter {
  const _EqCurvePainter(this.gains);
  final List<double> gains;

  @override
  void paint(Canvas canvas, Size size) {
    if (gains.isEmpty) return;
    final n = gains.length;
    // Band centers 25Hz..16kHz log-spaced; x = log position.
    final logMin = math.log(25.0);
    final logMax = math.log(16000.0);
    final lo = -8.0, hi = 8.0, span = 16.0;

    // 0 dB reference.
    final zeroY = size.height * (1 - (0 - lo) / span);
    canvas.drawLine(
        Offset(0, zeroY),
        Offset(size.width, zeroY),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..strokeWidth = 1);

    final path = Path();
    for (var i = 0; i < n; i++) {
      final f = 25.0 * math.pow(16000.0 / 25.0, n <= 1 ? 0.0 : i / (n - 1));
      final x = size.width * (math.log(f) - logMin) / (logMax - logMin);
      final y = size.height * (1 - (gains[i].clamp(-12.0, 12.0) - lo) / span);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = SpotifyColors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_EqCurvePainter old) => true;
}