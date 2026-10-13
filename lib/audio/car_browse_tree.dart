import 'dart:async';

import 'package:audio_service/audio_service.dart';

import '../data/radio_stations_db.dart';
import '../models/radio_station.dart';
import '../models/song.dart';
import '../services/free_sources/free_sources.dart';
import '../services/home_service.dart';
import '../services/storage_service.dart';
import '../services/youtube_service.dart';

/// The menu Android Auto (and other MediaBrowser clients — Wear OS,
/// car head units, Assistant) shows for ZenMusic.
///
/// Folder ids are plain strings; playable ids are
/// `play|<folderId>|<index>` so tapping a song queues the whole folder
/// from that point, the way you'd expect in a car. Radio items are
/// `radio|<index>` into the last radio list served.
class CarBrowseTree {
  CarBrowseTree({
    required this.storage,
    required this.playQueue,
    required this.playRadio,
  });

  final StorageService storage;
  final Future<void> Function(List<Song> songs, int startIndex) playQueue;
  final Future<bool> Function(RadioStation station) playRadio;

  // Android Auto content-style hints.
  static const _styleKey = 'android.media.browse.CONTENT_STYLE_SUPPORTED';
  static const _browsableStyle =
      'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT';
  static const _playableStyle =
      'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT';
  static const _list = 1;
  static const _grid = 2;

  static const rootExtras = <String, dynamic>{
    _styleKey: true,
    _browsableStyle: _grid,
    _playableStyle: _list,
    'android.media.browse.SEARCH_SUPPORTED': true,
  };

  static const _recent = 'recent';
  static const _liked = 'liked';
  static const _playlists = 'playlists';
  static const _trending = 'trending';
  static const _free = 'free';
  static const _radio = 'radio';
  static const _search = 'search';

  final Map<String, List<Song>> _folders = {};
  List<RadioStation> _stations = const [];
  late final _home = HomeService();
  late final _yt = YoutubeService();

  MediaItem _folder(String id, String title, {String? subtitle, String? art}) =>
      MediaItem(
        id: id,
        title: title,
        displaySubtitle: subtitle,
        playable: false,
        artUri: art == null ? null : Uri.tryParse(art),
      );

  MediaItem _songItem(String folder, int i, Song s) => MediaItem(
        id: 'play|$folder|$i',
        title: s.title,
        artist: s.artist,
        duration: s.duration == Duration.zero ? null : s.duration,
        artUri: s.thumbnail.isEmpty ? null : Uri.tryParse(s.thumbnail),
        playable: true,
      );

  List<MediaItem> _songs(String folder, List<Song> songs) {
    _folders[folder] = songs;
    return [
      for (var i = 0; i < songs.length; i++) _songItem(folder, i, songs[i]),
    ];
  }

  Future<List<MediaItem>> children(String parentId) async {
    switch (parentId) {
      case AudioService.browsableRootId:
        return [
          _folder(_recent, 'Recently played'),
          _folder(_liked, 'Liked songs'),
          _folder(_playlists, 'Your playlists'),
          _folder(_trending, 'Trending now'),
          _folder(_free, 'Free music', subtitle: 'Audius · Archive · Jamendo'),
          _folder(_radio, 'Radio'),
        ];
      // Android Auto asks for this to fill its "recent" slot on connect.
      case AudioService.recentRootId:
        final recent = storage.getPlayedHistory().take(1).toList();
        return _songs(_recent, recent);
      case _recent:
        return _songs(_recent, storage.getPlayedHistory().take(50).toList());
      case _liked:
        return _songs(_liked, storage.getLikedSongs());
      case _playlists:
        return [
          for (final p in storage.getUserPlaylists())
            _folder('pl:${p.id}', p.name, subtitle: '${p.count} songs'),
        ];
      case _trending:
        try {
          final songs = await _home
              .getYtTrendingSongs()
              .timeout(const Duration(seconds: 12));
          return _songs(_trending, songs.take(40).toList());
        } catch (_) {
          return _songs(_trending, _folders[_trending] ?? const []);
        }
      case _free:
        return [
          for (final s in FreeSources.instance.active)
            _folder('free:${s.id}', s.name, subtitle: s.blurb),
        ];
      case _radio:
        try {
          final top = await RadioBrowserSource.instance
              .top(limit: 40)
              .timeout(const Duration(seconds: 10));
          _stations = [...radioStationsDB, ...top];
        } catch (_) {
          _stations = radioStationsDB;
        }
        return [
          for (var i = 0; i < _stations.length; i++)
            MediaItem(
              id: 'radio|$i',
              title: _stations[i].name,
              artist: _stations[i].genre ?? 'Radio',
              artUri: _stations[i].image.isEmpty
                  ? null
                  : Uri.tryParse(_stations[i].image),
              playable: true,
            ),
        ];
    }
    if (parentId.startsWith('pl:')) {
      final id = parentId.substring(3);
      return _songs(parentId, storage.getUserPlaylistSongs(id));
    }
    if (parentId.startsWith('free:')) {
      await FreeSources.instance.load();
      final sid = parentId.substring(5);
      final src = FreeSources.instance.all.where((s) => s.id == sid);
      if (src.isEmpty) return const [];
      try {
        final songs = await src.first
            .trending(limit: 40)
            .timeout(const Duration(seconds: 12));
        return _songs(parentId, songs);
      } catch (_) {
        return const [];
      }
    }
    return const [];
  }

  Future<MediaItem?> item(String mediaId) async {
    final parts = mediaId.split('|');
    if (parts.length == 3 && parts[0] == 'play') {
      final list = _folders[parts[1]];
      final i = int.tryParse(parts[2]) ?? -1;
      if (list != null && i >= 0 && i < list.length) {
        return _songItem(parts[1], i, list[i]);
      }
    }
    return null;
  }

  Future<void> play(String mediaId) async {
    final parts = mediaId.split('|');
    if (parts.length == 3 && parts[0] == 'play') {
      var list = _folders[parts[1]];
      // The car may replay an id from a previous session (resume).
      list ??= _folderFromStorage(parts[1]);
      final i = int.tryParse(parts[2]) ?? 0;
      if (list != null && list.isNotEmpty) {
        await playQueue(list, i.clamp(0, list.length - 1));
      }
      return;
    }
    if (parts.length == 2 && parts[0] == 'radio') {
      final i = int.tryParse(parts[1]) ?? -1;
      if (i >= 0 && i < _stations.length) await playRadio(_stations[i]);
    }
  }

  List<Song>? _folderFromStorage(String folder) {
    if (folder == _recent) return storage.getPlayedHistory().take(50).toList();
    if (folder == _liked) return storage.getLikedSongs();
    if (folder.startsWith('pl:')) {
      return storage.getUserPlaylistSongs(folder.substring(3));
    }
    return null;
  }

  /// Search from the car screen or by voice.
  Future<List<MediaItem>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final songs = await _searchSongs(q);
    return _songs(_search, songs);
  }

  Future<List<Song>> _searchSongs(String q) async {
    try {
      final main = await _yt.search(q).timeout(const Duration(seconds: 12));
      if (main.isNotEmpty) return main.take(30).toList();
    } catch (_) {}
    // Fall back to the free catalogues (e.g. no YouTube in region).
    final free = await FreeSources.instance.searchAll(q, perSource: 10);
    return [for (final l in free.values) ...l];
  }

  /// "Hey Google, play <query> on ZenMusic".
  Future<void> playFromSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      // Generic "play music": resume recents, else liked, else trending.
      final recent = storage.getPlayedHistory();
      if (recent.isNotEmpty) return playQueue(recent.take(50).toList(), 0);
      final liked = storage.getLikedSongs();
      if (liked.isNotEmpty) return playQueue(liked, 0);
      final items = await children(_trending);
      if (items.isNotEmpty) await play(items.first.id);
      return;
    }
    final songs = await _searchSongs(q);
    if (songs.isNotEmpty) {
      _folders[_search] = songs;
      await playQueue(songs, 0);
    }
  }
}
