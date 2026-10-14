import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../models/collection.dart';
import '../models/song.dart';
import '../services/jiosaavn_service.dart';
import '../theme/spotify_theme.dart';
import '../widgets/download_widgets.dart';
import 'collection_screen.dart';

/// JioSaavn browse + search: language picker, top playlists and new
/// albums per language, and search across songs / albums / playlists /
/// artists. Everything plays straight from JioSaavn (320 kbps).
class JioSaavnScreen extends StatefulWidget {
  const JioSaavnScreen({super.key});

  @override
  State<JioSaavnScreen> createState() => _JioSaavnScreenState();
}

class _JioSaavnScreenState extends State<JioSaavnScreen> {
  static const _languages = [
    'Hindi', 'Kannada', 'Tamil', 'Telugu', 'Malayalam', 'Punjabi',
    'Marathi', 'Bengali', 'English', 'Bhojpuri', 'Gujarati',
  ];

  final _api = JiosaavnService();
  final _query = TextEditingController();
  Timer? _debounce;
  String _lang = 'Hindi';
  String _q = '';

  // Memoised network futures keyed by request.
  final _songF = <String, Future<List<Song>>>{};
  final _colF = <String, Future<List<Collection>>>{};
  final _artF = <String, Future<List<SaavnArtist>>>{};

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _open(Collection c) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CollectionScreen(collection: c)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyColors.background,
      appBar: AppBar(title: const Text('JioSaavn')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              style: TextStyle(color: SpotifyColors.textPrimary),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 450),
                    () => setState(() => _q = v.trim()));
              },
              onSubmitted: (v) => setState(() => _q = v.trim()),
              decoration: InputDecoration(
                hintText: 'Songs, albums, artists on JioSaavn',
                hintStyle: TextStyle(color: SpotifyColors.textTertiary),
                prefixIcon: Icon(Icons.search_rounded,
                    color: SpotifyColors.textSecondary),
                suffixIcon: _q.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: SpotifyColors.textSecondary),
                        onPressed: () {
                          _query.clear();
                          setState(() => _q = '');
                        },
                      ),
                filled: true,
                fillColor: SpotifyColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(child: _q.isEmpty ? _browse() : _search()),
        ],
      ),
    );
  }

  // ── Browse by language ──

  Widget _browse() {
    final l = _lang;
    return ListView(
      key: ValueKey('browse|$l'),
      padding: const EdgeInsets.only(bottom: 150),
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final lang in _languages)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(lang),
                    selected: lang == _lang,
                    showCheckmark: false,
                    selectedColor: SpotifyColors.green,
                    labelStyle: TextStyle(
                      color: lang == _lang
                          ? SpotifyColors.onAccent
                          : SpotifyColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _lang = lang),
                  ),
                ),
            ],
          ),
        ),
        _SongShelf(
          title: 'Trending $l songs',
          future: _songF.putIfAbsent(
              't|$l', () => _api.search('trending $l songs', limit: 20)),
        ),
        _CollectionShelf(
          title: 'Top $l playlists',
          future: _colF.putIfAbsent(
              'p|$l', () => _api.searchPlaylists('top $l', limit: 12)),
          onOpen: _open,
        ),
        _CollectionShelf(
          title: 'New $l releases',
          future: _colF.putIfAbsent('a|$l',
              () => _api.searchAlbums('new $l ${DateTime.now().year}', limit: 12)),
          onOpen: _open,
        ),
        _CollectionShelf(
          title: '$l romance',
          future: _colF.putIfAbsent(
              'r|$l', () => _api.searchPlaylists('$l romantic', limit: 10)),
          onOpen: _open,
        ),
        _CollectionShelf(
          title: '$l party & workout',
          future: _colF.putIfAbsent(
              'w|$l', () => _api.searchPlaylists('$l party', limit: 10)),
          onOpen: _open,
        ),
      ],
    );
  }

  // ── Search ──

  Widget _search() {
    final q = _q;
    return ListView(
      key: ValueKey('search|$q'),
      padding: const EdgeInsets.only(bottom: 150),
      children: [
        _ArtistShelf(
          future: _artF.putIfAbsent(q, () => _api.searchArtists(q, limit: 10)),
        ),
        _SongShelf(
          title: 'Songs',
          future: _songF.putIfAbsent('s|$q', () => _api.search(q, limit: 20)),
          asList: true,
        ),
        _CollectionShelf(
          title: 'Albums',
          future: _colF.putIfAbsent('sa|$q', () => _api.searchAlbums(q)),
          onOpen: _open,
        ),
        _CollectionShelf(
          title: 'Playlists',
          future: _colF.putIfAbsent('sp|$q', () => _api.searchPlaylists(q)),
          onOpen: _open,
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════
// Shelves
// ═════════════════════════════════════════════

Widget _header(String title, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: TextStyle(
                    color: SpotifyColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );

Widget _art(String url, double size, {bool circle = false}) {
  final img = url.isEmpty
      ? Container(
          color: SpotifyColors.surfaceLight,
          child: Icon(Icons.music_note_rounded,
              color: SpotifyColors.textTertiary))
      : CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) =>
              Container(color: SpotifyColors.surfaceLight),
        );
  return SizedBox(
    width: size,
    height: size,
    child: circle
        ? ClipOval(child: img)
        : ClipRRect(borderRadius: BorderRadius.circular(8), child: img),
  );
}

class _SongShelf extends StatelessWidget {
  const _SongShelf(
      {required this.title, required this.future, this.asList = false});

  final String title;
  final Future<List<Song>> future;
  final bool asList;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Song>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final songs = snap.data ?? const <Song>[];
        if (songs.isEmpty) return const SizedBox.shrink();
        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DownloadAllButton(songs: songs, size: 26),
            IconButton(
              tooltip: 'Play all',
              iconSize: 40,
              icon: Icon(Icons.play_circle_fill_rounded,
                  color: SpotifyColors.green),
              onPressed: () => audioHandler.setQueue(songs),
            ),
          ],
        );
        if (asList) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(title, trailing: actions),
              for (var i = 0; i < songs.length && i < 12; i++)
                ListTile(
                  leading: _art(songs[i].thumbnail, 48),
                  title: Text(songs[i].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: SpotifyColors.textPrimary,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(songs[i].artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: SpotifyColors.textSecondary)),
                  trailing: DownloadedBadge(songId: songs[i].id),
                  onTap: () => audioHandler.setQueue(songs, startIndex: i),
                ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(title, trailing: actions),
            SizedBox(
              height: 196,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: songs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => audioHandler.setQueue(songs, startIndex: i),
                  child: SizedBox(
                    width: 140,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _art(songs[i].thumbnail, 140),
                        const SizedBox(height: 8),
                        Text(songs[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: SpotifyColors.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600)),
                        Text(songs[i].artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: SpotifyColors.textSecondary,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CollectionShelf extends StatelessWidget {
  const _CollectionShelf(
      {required this.title, required this.future, required this.onOpen});

  final String title;
  final Future<List<Collection>> future;
  final ValueChanged<Collection> onOpen;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Collection>>(
      future: future,
      builder: (context, snap) {
        final list = snap.data ?? const <Collection>[];
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(title),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final c = list[i];
                  return GestureDetector(
                    onTap: () => onOpen(c),
                    child: SizedBox(
                      width: 140,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _art(c.imageUrl, 140),
                          const SizedBox(height: 8),
                          Text(c.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: SpotifyColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2)),
                          Text(c.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: SpotifyColors.textSecondary,
                                  fontSize: 11.5)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ArtistShelf extends StatelessWidget {
  const _ArtistShelf({required this.future});
  final Future<List<SaavnArtist>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SaavnArtist>>(
      future: future,
      builder: (context, snap) {
        final list = snap.data ?? const <SaavnArtist>[];
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header('Artists'),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, i) {
                  final a = list[i];
                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SaavnArtistScreen(artist: a))),
                    child: SizedBox(
                      width: 110,
                      child: Column(
                        children: [
                          _art(a.imageUrl, 110, circle: true),
                          const SizedBox(height: 8),
                          Text(a.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: SpotifyColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A JioSaavn artist: popular songs and latest songs.
class SaavnArtistScreen extends StatefulWidget {
  const SaavnArtistScreen({super.key, required this.artist});
  final SaavnArtist artist;

  @override
  State<SaavnArtistScreen> createState() => _SaavnArtistScreenState();
}

class _SaavnArtistScreenState extends State<SaavnArtistScreen> {
  final _api = JiosaavnService();
  late final Future<List<Song>> _popular = _api.artistSongs(widget.artist.id);
  late final Future<List<Song>> _latest =
      _api.artistSongs(widget.artist.id, sortBy: 'latest');

  @override
  Widget build(BuildContext context) {
    final a = widget.artist;
    return Scaffold(
      backgroundColor: SpotifyColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 280,
            backgroundColor: SpotifyColors.background,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(a.name,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (a.imageUrl.isNotEmpty)
                    CachedNetworkImage(
                        imageUrl: a.imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const SizedBox.shrink()),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          SpotifyColors.background,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _SongShelf(title: 'Popular', future: _popular, asList: true),
                _SongShelf(title: 'Latest', future: _latest),
                const SizedBox(height: 150),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
