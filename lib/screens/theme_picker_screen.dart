import 'package:flutter/material.dart';

import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../theme/spotify_theme.dart';

/// Settings → Appearance → Theme. A grid of live swatches; tapping one
/// re-skins the app immediately.
class ThemePickerScreen extends StatelessWidget {
  const ThemePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyColors.background,
      appBar: AppBar(
        backgroundColor: SpotifyColors.background,
        title: const Text('Theme'),
      ),
      body: ValueListenableBuilder<String>(
        valueListenable: ZenThemeController.selectedId,
        builder: (context, selected, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          children: [
            _AlbumArtCard(selected: selected == ZenPalettes.albumId),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text('Presets',
                  style: TextStyle(
                      color: SpotifyColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                for (final p in ZenPalettes.all)
                  _PaletteTile(
                    palette: p,
                    selected: selected == p.id,
                    onTap: () => ZenThemeController.select(p.id),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            _sectionLabel('Community favourites'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                for (final p in ZenPalettes.community)
                  _PaletteTile(
                    palette: p,
                    selected: selected == p.id,
                    onTap: () => ZenThemeController.select(p.id),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            _sectionLabel('Your colour'),
            _CustomAccentCard(selected: selected == ZenPalettes.customId),
          ],
        ),
      ),
    );
  }
}

Widget _sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(text,
          style: TextStyle(
              color: SpotifyColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5)),
    );

class _CustomAccentCard extends StatelessWidget {
  const _CustomAccentCard({required this.selected});
  final bool selected;

  static const _swatches = <Color>[
    Color(0xFF1ED760), Color(0xFF00C2FF), Color(0xFF3D7BFF),
    Color(0xFF8B5CF6), Color(0xFFE63CFF), Color(0xFFFF4D8D),
    Color(0xFFFF5A36), Color(0xFFFFB020), Color(0xFFC6F432),
    Color(0xFF14B8A6), Color(0xFFF5F5F5), Color(0xFFB0835A),
  ];

  Future<void> _pick(BuildContext context) async {
    var color = ZenThemeController.customAccent.value;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Pick an accent'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: color,
            onColorChanged: (v) => color = v,
            enableAlpha: false,
            labelTypes: const [],
            pickerAreaHeightPercent: 0.7,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Use colour')),
        ],
      ),
    );
    if (ok == true) await ZenThemeController.setCustomAccent(color);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SpotifyColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? SpotifyColors.green : Colors.transparent,
            width: 2,
          ),
        ),
        child: ValueListenableBuilder<Color>(
          valueListenable: ZenThemeController.customAccent,
          builder: (context, current, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in _swatches)
                    GestureDetector(
                      onTap: () => ZenThemeController.setCustomAccent(c),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected && c == current
                                ? Colors.white
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => _pick(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: SpotifyColors.surfaceLighter,
                      ),
                      child: Icon(Icons.colorize_rounded,
                          size: 18, color: SpotifyColors.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                  'The whole app is built around the colour you pick.',
                  style: TextStyle(
                      color: SpotifyColors.textTertiary, fontSize: 12.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumArtCard extends StatelessWidget {
  const _AlbumArtCard({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SpotifyColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => ZenThemeController.select(ZenPalettes.albumId),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? SpotifyColors.green : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(colors: [
                        Color(0xFFFF5C8A),
                        Color(0xFFFFB347),
                        Color(0xFF1ED760),
                        Color(0xFF2EC4B6),
                        Color(0xFF6C8CFF),
                        Color(0xFFB57BFF),
                        Color(0xFFFF5C8A),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Match album art',
                            style: TextStyle(
                                color: SpotifyColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('Colours follow whatever is playing',
                            style: TextStyle(
                                color: SpotifyColors.textSecondary,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle_rounded,
                        color: SpotifyColors.green),
                ],
              ),
              if (selected) ...[
                const SizedBox(height: 10),
                ValueListenableBuilder<bool>(
                  valueListenable: ZenThemeController.albumAmoled,
                  builder: (context, amoled, _) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: amoled,
                    onChanged: ZenThemeController.setAlbumAmoled,
                    title: Text('Pure black background',
                        style: TextStyle(
                            color: SpotifyColors.textPrimary, fontSize: 14)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final ZenPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: p.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? p.highlight : p.surfaceLighter,
            width: selected ? 2.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mini mock: a card row + a play button in the accent.
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _bar(p.surfaceLight, 0.9),
                        const SizedBox(height: 6),
                        _bar(p.surfaceLighter, 0.6),
                        const SizedBox(height: 6),
                        _bar(p.surface, 0.75),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                        color: p.primary, shape: BoxShape.circle),
                    child: Icon(Icons.play_arrow_rounded,
                        color: p.onPrimary, size: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700)),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded,
                      color: p.highlight, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(Color c, double widthFactor) => FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: 8,
          decoration: BoxDecoration(
              color: c, borderRadius: BorderRadius.circular(4)),
        ),
      );
}
