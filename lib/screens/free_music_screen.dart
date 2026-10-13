import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../models/radio_station.dart';
import '../models/song.dart';
import '../services/free_sources/free_sources.dart';
import '../services/free_sources/free_sources_settings.dart';
import '../theme/spotify_theme.dart';

/// Browse + search the free catalogues (Audius, Internet Archive,
/// Jamendo) and Radio Browser.
class FreeMusicScreen extends StatefulWidget {
  const FreeMusicScreen({super.key, this.initialQuery});

  /// Pre-fills the search box (e.g. coming from the main Search tab).
  final String? initialQuery;

  @override
  State<FreeMusicScreen> createState() => _FreeMusicScreenState();
}

class _FreeMusicScreenState extends State<FreeMusicScreen> {
  final _fs = FreeSources.instance;
  final _query = TextEditingController();
  Timer? _debounce;
  bool _loaded = false;
  String _tab = 'all';

  // Memoised requests so rebuilds (theme changes, typing) don't refetch.
  final _songFutures = <String, Future<List<Song>>>{};
  final _radioFutures = <String, Future<List<RadioStation>>>{};

  @override
  void initState() {
    super.initState();
    _query.text = widget.initialQuery ?? '';
    _fs.load().then((_) {
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  List<(String, String)> get _tabs => [
        ('all', 'All'),
        for (final s in _fs.active) (s.id, s.name),
        ('radio', 'Radio'),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyColors.background,
      appBar: AppBar(
        title: const Text('Free Music'),
        actions: [
          IconButton(
            tooltip: 'Sources',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const FreeSourcesSettingsScreen()));
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TextField(
                    controller: _query,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(color: SpotifyColors.textPrimary),
                    onChanged: (_) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 450),
                          () => setState(() {}));
                    },
                    onSubmitted: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search free music and radio',
                      hintStyle: TextStyle(color: SpotifyColors.textTertiary),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: SpotifyColors.textSecondary),
                      filled: true,
                      fillColor: SpotifyColors.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final t in _tabs)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(t.$2),
                            selected: _tab == t.$1,
                            selectedColor: SpotifyColors.green,
                            labelStyle: TextStyle(
                              color: _tab == t.$1
                                  ? SpotifyColors.onAccent
                                  : SpotifyColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _tab = t.$1),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(child: _body()),
              ],
            ),
    );
  }

  Widget _body() {
    final q = _query.text.trim();
    if (_tab == 'radio') {
      return _RadioList(
        key: ValueKey('radio|$q'),
        future: _radioFutures.putIfAbsent(
            q,
            () => q.isEmpty
                ? RadioBrowserSource.instance.top()
                : RadioBrowserSource.instance.search(q)),
      );
    }
    final sources = _tab == 'all'
        ? _fs.active
        : _fs.active.where((s) => s.id == _tab).toList();
    if (sources.isEmpty) {
      return _empty('Turn on a source to start listening',
          action: 'Open sources');
    }
    return ListView(
      key: ValueKey('$_tab|$q'),
      padding: const EdgeInsets.only(bottom: 140),
      children: [
        for (final s in sources)
          _SourceSection(
            source: s,
            future: _songFutures.putIfAbsent(
                '${s.id}|$q',
                () => q.isEmpty
                    ? s.trending(limit: 25)
                    : s.search(q, limit: 25)),
            title: q.isEmpty ? 'Trending on ${s.name}' : s.name,
          ),
      ],
    );
  }

  Widget _empty(String msg, {String? action}) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(msg, style: TextStyle(color: SpotifyColors.textSecondary)),
            if (action != null)
              TextButton(
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const FreeSourcesSettingsScreen()));
                  if (mounted) setState(() {});
                },
                child: Text(action),
              ),
          ],
        ),
      );
}

class _SourceSection extends StatelessWidget {
  const _SourceSection({
    required this.source,
    required this.future,
    required this.title,
  });

  final FreeMusicSource source;
  final Future<List<Song>> future;
  final String title;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Song>>(
      future: future,
      builder: (context, snap) {
        final songs = snap.data ?? const <Song>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: TextStyle(
                            color: SpotifyColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                  ),
                  if (songs.isNotEmpty)
                    IconButton(
                      tooltip: 'Play all',
                      onPressed: () => audioHandler.setQueue(songs),
                      icon: Icon(Icons.play_circle_fill_rounded,
                          color: SpotifyColors.green, size: 40),
                    ),
                ],
              ),
            ),
            if (snap.connectionState != ConnectionState.done)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snap.hasError)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Couldn\'t reach ${source.name} right now.',
                    style: TextStyle(color: SpotifyColors.textTertiary)),
              )
            else if (songs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('No results',
                    style: TextStyle(color: SpotifyColors.textTertiary)),
              )
            else
              for (var i = 0; i < songs.length; i++)
                FreeSongTile(
                  song: songs[i],
                  onTap: () => audioHandler.setQueue(songs, startIndex: i),
                ),
          ],
        );
      },
    );
  }
}

/// Compact Spotify-style row: art, title, artist, overflow.
class FreeSongTile extends StatelessWidget {
  const FreeSongTile({super.key, required this.song, required this.onTap});

  final Song song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 52,
                height: 52,
                child: song.thumbnail.isEmpty
                    ? Container(
                        color: SpotifyColors.surfaceLight,
                        child: Icon(Icons.music_note_rounded,
                            color: SpotifyColors.textTertiary),
                      )
                    : CachedNetworkImage(
                        imageUrl: song.thumbnail,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Container(color: SpotifyColors.surfaceLight),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: SpotifyColors.textPrimary,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: SpotifyColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Add to queue',
              icon: Icon(Icons.playlist_add_rounded,
                  color: SpotifyColors.textSecondary),
              onPressed: () {
                audioHandler.addToQueue(song);
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(content: Text('Added "${song.title}" to queue')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioList extends StatelessWidget {
  const _RadioList({super.key, required this.future});
  final Future<List<RadioStation>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RadioStation>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? const <RadioStation>[];
        if (snap.hasError || list.isEmpty) {
          return Center(
            child: Text(
                snap.hasError ? 'Radio directory unreachable' : 'No stations',
                style: TextStyle(color: SpotifyColors.textSecondary)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 140, top: 8),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final s = list[i];
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: s.image.isEmpty
                      ? Container(
                          color: SpotifyColors.surfaceLight,
                          child: Icon(Icons.radio_rounded,
                              color: SpotifyColors.textTertiary))
                      : CachedNetworkImage(
                          imageUrl: s.image,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: SpotifyColors.surfaceLight,
                            child: Icon(Icons.radio_rounded,
                                color: SpotifyColors.textTertiary),
                          ),
                        ),
                ),
              ),
              title: Text(s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: SpotifyColors.textPrimary,
                      fontWeight: FontWeight.w600)),
              subtitle: Text(
                  [s.genre, s.description]
                      .where((x) => x != null && x.isNotEmpty)
                      .join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: SpotifyColors.textSecondary)),
              onTap: () => audioHandler.playRadioStream(
                id: s.id,
                name: s.name,
                streamUrl: s.streamUrl,
                image: s.image,
                genre: s.genre,
              ),
            );
          },
        );
      },
    );
  }
}
