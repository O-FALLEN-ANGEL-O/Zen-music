import 'dart:async';

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';
import 'zen_palette.dart';

/// Owns the active [ZenPalette]. Screens never read this directly —
/// [SpotifyColors] forwards to [palette] — but the app root listens to
/// [notifier] and repaints the whole tree when it changes.
class ZenThemeController {
  ZenThemeController._();

  static const _kPaletteKey = 'zen_palette_id';
  static const _kAmoledAlbumKey = 'zen_album_amoled';
  static const _kCustomAccentKey = 'zen_custom_accent';

  /// The user's own accent colour for the "Custom" theme.
  static final customAccent = ValueNotifier<Color>(const Color(0xFF1ED760));

  /// The palette every colour lookup resolves against.
  static final notifier = ValueNotifier<ZenPalette>(ZenPalettes.classic);

  /// The id the user picked (may be [ZenPalettes.albumId]).
  static final selectedId = ValueNotifier<String>(ZenPalettes.classic.id);

  /// When following album art, use pure-black surfaces.
  static final albumAmoled = ValueNotifier<bool>(false);

  static ZenPalette get palette => notifier.value;

  static StreamSubscription<Song?>? _songSub;
  static String? _lastArtUrl;
  static ZenPalette? _lastAlbumPalette;

  /// Hydrate from storage. Call once before runApp.
  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    selectedId.value = p.getString(_kPaletteKey) ?? ZenPalettes.classic.id;
    albumAmoled.value = p.getBool(_kAmoledAlbumKey) ?? false;
    final c = p.getInt(_kCustomAccentKey);
    if (c != null) customAccent.value = Color(c);
    if (selectedId.value == ZenPalettes.customId) {
      notifier.value = _customPalette();
    } else if (selectedId.value != ZenPalettes.albumId) {
      notifier.value = ZenPalettes.byId(selectedId.value);
    }
  }

  /// Feeds the now-playing song so "Match album art" can re-tint.
  static void attachSongStream(Stream<Song?> songs) {
    _songSub?.cancel();
    _songSub = songs.listen((song) {
      if (song == null) return;
      _lastArtUrl = song.thumbnail;
      if (selectedId.value == ZenPalettes.albumId) {
        _applyAlbumArt(song.thumbnail);
      }
    });
  }

  static Future<void> select(String id) async {
    selectedId.value = id;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPaletteKey, id);
    if (id == ZenPalettes.customId) {
      notifier.value = _customPalette();
    } else if (id == ZenPalettes.albumId) {
      if (_lastAlbumPalette != null) notifier.value = _lastAlbumPalette!;
      final url = _lastArtUrl;
      if (url != null) await _applyAlbumArt(url);
    } else {
      notifier.value = ZenPalettes.byId(id);
    }
  }

  static ZenPalette _customPalette() => ZenPalette.fromAccent(
        customAccent.value,
        id: ZenPalettes.customId,
        name: 'Custom',
        amoled: albumAmoled.value,
      );

  static Future<void> setCustomAccent(Color c) async {
    customAccent.value = c;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kCustomAccentKey, c.toARGB32());
    await select(ZenPalettes.customId);
  }

  static Future<void> setAlbumAmoled(bool v) async {
    albumAmoled.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kAmoledAlbumKey, v);
    if (selectedId.value == ZenPalettes.customId) {
      notifier.value = _customPalette();
      return;
    }
    final url = _lastArtUrl;
    if (selectedId.value == ZenPalettes.albumId && url != null) {
      _lastAlbumPalette = null;
      await _applyAlbumArt(url, force: true);
    }
  }

  static String? _appliedUrl;

  static Future<void> _applyAlbumArt(String url, {bool force = false}) async {
    if (url.isEmpty) return;
    if (!force && url == _appliedUrl) return;
    _appliedUrl = url;
    try {
      final gen = await PaletteGenerator.fromImageProvider(
        NetworkImage(url),
        size: const Size(96, 96),
        maximumColorCount: 12,
      );
      // A newer track may have started while we were sampling.
      if (url != _appliedUrl) return;
      final accent = gen.vibrantColor?.color ??
          gen.lightVibrantColor?.color ??
          gen.dominantColor?.color ??
          ZenPalettes.classic.primary;
      final pal = ZenPalette.fromAccent(accent, amoled: albumAmoled.value);
      _lastAlbumPalette = pal;
      if (selectedId.value == ZenPalettes.albumId) notifier.value = pal;
    } catch (_) {
      // Artwork failed to load — keep the current palette.
    }
  }
}

/// Repaints every element under [child] when the palette changes, so
/// widgets that read SpotifyColors in build() pick up the new colours
/// without losing navigation or scroll state.
class ZenThemeScope extends StatefulWidget {
  const ZenThemeScope({super.key, required this.child});

  final Widget child;

  @override
  State<ZenThemeScope> createState() => _ZenThemeScopeState();
}

class _ZenThemeScopeState extends State<ZenThemeScope> {
  @override
  void initState() {
    super.initState();
    ZenThemeController.notifier.addListener(_onChange);
  }

  @override
  void dispose() {
    ZenThemeController.notifier.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    // Mark the entire subtree dirty: many widgets read colours straight
    // from SpotifyColors rather than Theme.of, so an inherited-widget
    // change alone would not reach them.
    void visit(Element e) {
      e.markNeedsBuild();
      e.visitChildren(visit);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) (context as Element).visitChildren(visit);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
