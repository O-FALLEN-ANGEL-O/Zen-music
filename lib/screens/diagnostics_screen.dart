import 'package:flutter/material.dart';
import '../services/diagnostics_service.dart';
import '../theme/spotify_theme.dart';

/// Settings → Diagnostics: live log view (native logcat + Dart zone),
/// newest first. Whole-line coloring by level: errors red, warnings
/// orange, info green-tinted, debug dimmed — logcat-console style.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  String _sourceFilter = 'all'; // all | native | dart
  String _levelFilter = 'all'; // all | I+ | W+ (errors only)

  @override
  void initState() {
    super.initState();
    DiagnosticsService.instance.startLogcatCapture();
  }

  @override
  void dispose() {
    DiagnosticsService.instance.stopLogcatCapture();
    super.dispose();
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  /// Full-line palette by severity (logcat-console style).
  Color _lineColor(String level) {
    switch (level) {
      case 'E':
      case 'F':
        return Colors.redAccent; // errors — full red line
      case 'W':
        return Colors.orangeAccent; // warnings — full orange
      case 'I':
        return SpotifyColors.textPrimary; // info — normal bright
      default:
        return SpotifyColors.textTertiary; // V / D — dimmed
    }
  }

  /// Accent (slightly brighter) variant for the level letter + tag.
  Color _accentColor(String level) {
    switch (level) {
      case 'E':
      case 'F':
        return Colors.red;
      case 'W':
        return Colors.orange;
      case 'I':
        return SpotifyColors.highlight;
      default:
        return SpotifyColors.textTertiary;
    }
  }

  bool _passes(DiagLine l) {
    if (_sourceFilter == 'native' && l.source != 'native') return false;
    if (_sourceFilter == 'dart' && l.source != 'dart') return false;
    if (_levelFilter == 'W+' && 'WEF'.contains(l.level) == false) return false;
    if (_levelFilter == 'I+' && 'IWEF'.contains(l.level) == false) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final svc = DiagnosticsService.instance;
    return Scaffold(
      backgroundColor: SpotifyColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Diagnostics',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: SpotifyColors.textPrimary)),
        actions: [
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.delete_outline_rounded,
                color: SpotifyColors.textPrimary),
            onPressed: svc.clear,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters: source + level.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Row(
              children: [
                _filterChip('All', _sourceFilter == 'all',
                        () => setState(() => _sourceFilter = 'all')),
                const SizedBox(width: 6),
                _filterChip('Native', _sourceFilter == 'native',
                        () => setState(() => _sourceFilter = 'native')),
                const SizedBox(width: 6),
                _filterChip('Dart', _sourceFilter == 'dart',
                        () => setState(() => _sourceFilter = 'dart')),
                const Spacer(),
                _filterChip('Errors', _levelFilter == 'W+',
                        () => setState(() => _levelFilter =
                    _levelFilter == 'W+' ? 'all' : 'W+')),
              ],
            ),
          ),
          if (!svc.logcatActive)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text('native logcat stream unavailable on this device',
                  style: TextStyle(
                      color: SpotifyColors.textTertiary, fontSize: 11)),
            ),
          Expanded(
            child: StreamBuilder<void>(
              stream: svc.changes,
              builder: (context, _) {
                final lines =
                svc.lines.where(_passes).toList().reversed.toList();
                if (lines.isEmpty) {
                  return const Center(
                    child: Text('No log lines yet — play something.',
                        style:
                        TextStyle(color: SpotifyColors.textSecondary)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: lines.length,
                  itemBuilder: (context, i) {
                    final l = lines[i];
                    final t = '${_two(l.ts.hour)}:${_two(l.ts.minute)}:'
                        '${_two(l.ts.second)}';
                    final lineColor = _lineColor(l.level);
                    final accent = _accentColor(l.level);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: '$t ',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: SpotifyColors.textTertiary
                                      .withValues(alpha: 0.6))),
                          TextSpan(
                              text: '${l.level}/',
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: accent)),
                          TextSpan(
                              text: '${l.tag}: ',
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: accent.withValues(alpha: 0.85))),
                          TextSpan(
                              text: l.message,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: lineColor,
                                  height: 1.3,
                                  // Errors get a touch of weight so they
                                  // read first while scrolling.
                                  fontWeight:
                                  'EF'.contains(l.level)
                                      ? FontWeight.w600
                                      : FontWeight.w400)),
                        ]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: active
              ? SpotifyColors.green.withValues(alpha: 0.2)
              : SpotifyColors.surfaceLight,
          border: Border.all(
              color:
              active ? SpotifyColors.green : SpotifyColors.surfaceLighter),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active
                    ? SpotifyColors.highlight
                    : SpotifyColors.textSecondary)),
      ),
    );
  }
}