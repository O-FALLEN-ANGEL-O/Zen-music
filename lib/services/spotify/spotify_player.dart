import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../main.dart';
import '../../models/song.dart';
import '../song_source_resolver.dart';
import '../yt_music_service.dart';
import 'spotify_client.dart';

/// Turns Spotify tracks into playable songs by finding the same
/// recording on JioSaavn (320 kbps) or YouTube Music.
class SpotifyMatcher {
  SpotifyMatcher._();
  static final instance = SpotifyMatcher._();

  final _cache = <String, Song?>{};
  final _ytm = YtMusicService();

  /// Placeholder Song carrying the Spotify metadata — the resolver
  /// scores candidates against its title, artist and duration.
  static Song _seed(SpotifyTrack t) => Song(
        id: 'spotify:${t.id}',
        title: t.title,
        artist: t.artist,
        thumbnail: t.imageUrl,
        duration: t.duration,
      );

  Future<Song?> match(SpotifyTrack t) async {
    if (_cache.containsKey(t.id)) return _cache[t.id];
    Song? found;
    try {
      found = await SongSourceResolver.instance
          .resolve(_seed(t))
          .timeout(const Duration(seconds: 15));
    } catch (_) {}
    if (found == null) {
      // Looser fallback: first YouTube Music song result.
      try {
        final r = await _ytm
            .searchSongs('${t.title} ${t.artists.isEmpty ? '' : t.artists.first}',
                limit: 3)
            .timeout(const Duration(seconds: 10));
        if (r.isNotEmpty) found = r.first;
      } catch (_) {}
    }
    // Keep Spotify's square album art — it's usually the nicest.
    if (found != null && t.imageUrl.isNotEmpty && !found.isFromJiosaavn) {
      found = Song(
        id: found.id,
        title: found.title,
        artist: found.artist,
        thumbnail: t.imageUrl,
        duration: found.duration,
        jiosaavnId: found.jiosaavnId,
        jiosaavnStreamUrl: found.jiosaavnStreamUrl,
        audioType: found.audioType,
        bitrateKbps: found.bitrateKbps,
        extRaw: found.extRaw,
      );
    }
    _cache[t.id] = found;
    return found;
  }

  /// Matches many tracks, a few at a time. [onProgress] gets (done, total).
  Future<List<Song>> matchAll(List<SpotifyTrack> tracks,
      {void Function(int done, int total)? onProgress,
      bool Function()? cancelled}) async {
    final out = List<Song?>.filled(tracks.length, null);
    var next = 0;
    var done = 0;
    Future<void> worker() async {
      while (true) {
        if (cancelled?.call() ?? false) return;
        final i = next++;
        if (i >= tracks.length) return;
        out[i] = await match(tracks[i]);
        done++;
        onProgress?.call(done, tracks.length);
      }
    }

    await Future.wait(List.generate(4, (_) => worker()));
    return out.whereType<Song>().toList();
  }
}

/// Plays a Spotify list: starts the tapped track as soon as it's
/// matched, then keeps matching the rest in the background and
/// appending them to the queue in order.
class SpotifyPlayer {
  SpotifyPlayer._();
  static final instance = SpotifyPlayer._();

  /// Shown in the UI while the first track is being matched.
  final busy = ValueNotifier<bool>(false);

  int _session = 0;

  Future<bool> play(List<SpotifyTrack> tracks, int start,
      {bool shuffle = false}) async {
    if (tracks.isEmpty) return false;
    final session = ++_session;
    final order = shuffle
        ? (List<SpotifyTrack>.from(tracks)..shuffle())
        : tracks.sublist(start.clamp(0, tracks.length - 1));
    busy.value = true;
    Song? first;
    var idx = 0;
    try {
      // Skip tracks that can't be matched until one plays.
      while (first == null && idx < order.length && idx < 6) {
        first = await SpotifyMatcher.instance.match(order[idx]);
        idx++;
      }
    } finally {
      busy.value = false;
    }
    if (first == null || session != _session) return first != null;
    await audioHandler.setQueue([first]);
    unawaited(_fill(order.sublist(idx), session));
    return true;
  }

  Future<void> _fill(List<SpotifyTrack> rest, int session) async {
    for (final t in rest.take(150)) {
      if (session != _session) return;
      final s = await SpotifyMatcher.instance.match(t);
      if (session != _session) return;
      if (s != null) await audioHandler.addToQueue(s);
    }
  }
}
