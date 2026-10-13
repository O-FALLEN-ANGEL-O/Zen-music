import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/radio_stations_db.dart';
import '../main.dart';
import '../models/radio_station.dart';
import '../models/song.dart';
import '../services/car_mode_service.dart';
import '../services/free_sources/free_sources.dart';
import '../theme/spotify_theme.dart';

/// Distraction-free driving screen: huge targets, no scrolling needed
/// for the basics, screen stays on, works in portrait or landscape.
class CarModeScreen extends StatefulWidget {
  const CarModeScreen({super.key});

  /// True while the screen is on the navigator (avoid double pushes).
  static bool isOpen = false;

  @override
  State<CarModeScreen> createState() => _CarModeScreenState();
}

class _CarModeScreenState extends State<CarModeScreen> {
  @override
  void initState() {
    super.initState();
    CarModeScreen.isOpen = true;
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    CarModeScreen.isOpen = false;
    WakelockPlus.disable();
    super.dispose();
  }

  void _haptic() => HapticFeedback.mediumImpact();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, o) => o == Orientation.landscape
              ? Row(
                  children: [
                    Expanded(flex: 5, child: _nowPlaying(context, landscape: true)),
                    Expanded(flex: 4, child: _shortcuts(context)),
                  ],
                )
              : Column(
                  children: [
                    Expanded(flex: 6, child: _nowPlaying(context)),
                    Expanded(flex: 4, child: _shortcuts(context)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _nowPlaying(BuildContext context, {bool landscape = false}) {
    return StreamBuilder<Song?>(
      stream: audioHandler.currentSongStream,
      initialData: audioHandler.currentSong,
      builder: (context, snap) {
        final song = snap.data;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            children: [
              Row(
                children: [
                  ValueListenableBuilder<CarSignal?>(
                    valueListenable: CarModeService.instance.signal,
                    builder: (_, s, __) => Row(children: [
                      Icon(Icons.directions_car_filled_rounded,
                          color: SpotifyColors.green, size: 26),
                      const SizedBox(width: 8),
                      Text(
                        switch (s) {
                          CarSignal.bluetooth => 'Connected to car',
                          CarSignal.androidAuto => 'Android Auto',
                          CarSignal.automotive => 'In-car system',
                          CarSignal.carMode => 'Car mode',
                          null => 'Car Mode',
                        },
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ),
                  const Spacer(),
                  _bigIconButton(Icons.close_rounded, 'Exit Car Mode',
                      () => Navigator.of(context).maybePop(),
                      size: 30, pad: 10),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: song == null || song.thumbnail.isEmpty
                        ? Container(
                            color: SpotifyColors.surfaceLight,
                            child: const Icon(Icons.music_note_rounded,
                                color: Colors.white38, size: 96),
                          )
                        : CachedNetworkImage(
                            imageUrl: song.thumbnail,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: SpotifyColors.surfaceLight,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                song?.title ?? 'Nothing playing',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                song?.artist ?? 'Pick something below',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 18),
              ),
              const SizedBox(height: 10),
              _progress(),
              const SizedBox(height: 6),
              _transport(),
            ],
          ),
        );
      },
    );
  }

  Widget _progress() {
    return StreamBuilder<Duration>(
      stream: audioHandler.positionStream,
      builder: (context, pos) => StreamBuilder<Duration?>(
        stream: audioHandler.durationStream,
        builder: (context, dur) {
          final total = dur.data?.inMilliseconds ?? 0;
          final at = pos.data?.inMilliseconds ?? 0;
          final v = total <= 0 ? 0.0 : (at / total).clamp(0.0, 1.0);
          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 6,
              backgroundColor: Colors.white12,
              color: SpotifyColors.green,
            ),
          );
        },
      ),
    );
  }

  Widget _transport() {
    return StreamBuilder<bool>(
      stream: audioHandler.playingStream,
      initialData: audioHandler.playbackState.value.playing,
      builder: (context, snap) {
        final playing = snap.data ?? false;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _bigIconButton(Icons.skip_previous_rounded, 'Previous', () {
              _haptic();
              audioHandler.skipToPrevious();
            }),
            Semantics(
              button: true,
              label: playing ? 'Pause' : 'Play',
              child: GestureDetector(
                onTap: () {
                  _haptic();
                  playing ? audioHandler.pause() : audioHandler.play();
                },
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: SpotifyColors.green,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: SpotifyColors.onAccent,
                    size: 64,
                  ),
                ),
              ),
            ),
            _bigIconButton(Icons.skip_next_rounded, 'Next', () {
              _haptic();
              audioHandler.skipToNext();
            }),
          ],
        );
      },
    );
  }

  Widget _bigIconButton(IconData icon, String label, VoidCallback onTap,
      {double size = 52, double pad = 14}) {
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: size,
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );
  }

  Widget _shortcuts(BuildContext context) {
    final tiles = <(IconData, String, Future<void> Function())>[
      (Icons.favorite_rounded, 'Liked', () => _playList(storage.getLikedSongs(), shuffle: true)),
      (Icons.history_rounded, 'Recent', () => _playList(storage.getPlayedHistory().take(50).toList())),
      (Icons.radio_rounded, 'Radio', () => _openRadio(context)),
      (Icons.public_rounded, 'Free music', () => _playFree()),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.1,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final t in tiles)
            Material(
              color: const Color(0xFF1C1C1C),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  _haptic();
                  t.$3();
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(t.$1, color: SpotifyColors.green, size: 34),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(t.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _playList(List<Song> songs, {bool shuffle = false}) async {
    if (songs.isEmpty) {
      _toast('Nothing here yet');
      return;
    }
    final list = List<Song>.from(songs);
    if (shuffle) list.shuffle();
    await audioHandler.setQueue(list);
  }

  Future<void> _playFree() async {
    _toast('Loading free music…');
    try {
      await FreeSources.instance.load();
      final active = FreeSources.instance.active;
      if (active.isEmpty) {
        _toast('Turn on a free source in Settings');
        return;
      }
      final songs = await active.first.trending(limit: 40);
      await _playList(songs);
    } catch (_) {
      _toast('Couldn\'t reach the free catalogue');
    }
  }

  Future<void> _openRadio(BuildContext context) async {
    var stations = List<RadioStation>.from(radioStationsDB);
    try {
      final top = await RadioBrowserSource.instance
          .top(limit: 30)
          .timeout(const Duration(seconds: 8));
      stations = [...stations, ...top];
    } catch (_) {}
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _CarRadioList(stations: stations),
    ));
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 18)),
      duration: const Duration(seconds: 2),
    ));
  }
}

class _CarRadioList extends StatelessWidget {
  const _CarRadioList({required this.stations});
  final List<RadioStation> stations;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        toolbarHeight: 72,
        iconTheme: const IconThemeData(size: 34, color: Colors.white),
        title: const Text('Radio',
            style: TextStyle(fontSize: 26, color: Colors.white)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: stations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final s = stations[i];
          return Material(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                HapticFeedback.mediumImpact();
                await audioHandler.playRadioStream(
                  id: s.id,
                  name: s.name,
                  streamUrl: s.streamUrl,
                  image: s.image,
                  genre: s.genre,
                );
                if (context.mounted) Navigator.of(context).pop();
              },
              child: SizedBox(
                height: 76,
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(Icons.radio_rounded,
                        color: SpotifyColors.green, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(s.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w600)),
                    ),
                    if (s.genre != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Text(s.genre!,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 16)),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Sits above the navigator (MaterialApp.builder) and reacts to car
/// connection events: opens Car Mode, or asks whether a newly seen
/// Bluetooth device is the user's car.
class CarModeLauncher extends StatefulWidget {
  const CarModeLauncher({super.key, required this.child});
  final Widget child;

  @override
  State<CarModeLauncher> createState() => _CarModeLauncherState();
}

class _CarModeLauncherState extends State<CarModeLauncher> {
  StreamSubscription<CarSignal>? _open;
  StreamSubscription<String>? _ask;

  @override
  void initState() {
    super.initState();
    final car = CarModeService.instance;
    _open = car.openRequests.listen((_) => _openCarMode());
    _ask = car.askRequests.listen(_askAboutDevice);
  }

  @override
  void dispose() {
    _open?.cancel();
    _ask?.cancel();
    super.dispose();
  }

  void _openCarMode() {
    if (CarModeScreen.isOpen) return;
    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => const CarModeScreen(),
    ));
  }

  Future<void> _askAboutDevice(String name) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    final yes = await showModalBottomSheet<bool>(
      context: ctx,
      backgroundColor: SpotifyColors.surface,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.directions_car_filled_rounded,
                  color: SpotifyColors.green, size: 36),
              const SizedBox(height: 12),
              Text('Is "$name" your car?',
                  style: TextStyle(
                      color: SpotifyColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                  'ZenMusic will switch to Car Mode whenever it connects.',
                  style: TextStyle(
                      color: SpotifyColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(c).pop(false),
                      child: const Text('No'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(c).pop(true),
                      child: const Text('Yes, it\'s my car'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (yes == null) return;
    await CarModeService.instance.markAsCar(name, yes);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
