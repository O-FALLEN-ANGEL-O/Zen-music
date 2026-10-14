import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../main.dart';
import '../models/song.dart';
import 'free_sources/free_sources.dart';
import 'youtube_service.dart';

/// Offline downloads: fetch a song's audio via the normal stream chain,
/// store it in app storage, play from file with zero network.
///
/// Files live in the app's support directory (survives cache clears,
/// unlike the old temp-dir location, which is migrated on first use).
/// Each `<id>.audio` has a `<id>.json` sidecar with the song metadata,
/// so the Downloads list works even for songs not in history/likes.
///
/// [queue] adds songs to a background queue (two at a time) and
/// [progress] reports per-song percentages for the UI.
class DownloadsService {
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36';

  final YoutubeService _yt = YoutubeService();

  static final DownloadsService _instance = DownloadsService._();
  factory DownloadsService() => _instance;
  DownloadsService._();

  /// songId → percent (0–100) for songs queued or in flight.
  final progress = ValueNotifier<Map<String, int>>({});

  /// Ids of songs that are fully downloaded (kept current).
  final downloadedIds = ValueNotifier<Set<String>>({});

  /// Bumped whenever the set of downloaded files changes.
  final revision = ValueNotifier<int>(0);

  Directory? _cachedDir;
  bool _migrated = false;

  Future<Directory> _dir() async {
    final hit = _cachedDir;
    if (hit != null) return hit;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/zen_downloads');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _cachedDir = dir;
    await _migrateFromTemp(dir);
    _refreshIds(dir);
    return dir;
  }

  /// Moves downloads made by older builds out of the temp directory.
  Future<void> _migrateFromTemp(Directory dir) async {
    if (_migrated) return;
    _migrated = true;
    try {
      final old = Directory('${Directory.systemTemp.path}/zen_downloads');
      if (!old.existsSync()) return;
      for (final f in old.listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        final dest = File('${dir.path}/$name');
        if (!dest.existsSync()) {
          try {
            await f.rename(dest.path);
          } catch (_) {
            await f.copy(dest.path);
            await f.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('Downloads migration skipped: $e');
    }
  }

  void _refreshIds(Directory dir) {
    try {
      downloadedIds.value = dir
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.endsWith('.audio'))
          .map((n) => n.substring(0, n.length - '.audio'.length))
          .toSet();
    } catch (_) {}
    revision.value++;
  }

  static String _safe(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  /// Warm the directory so [isDownloaded] works synchronously.
  Future<void> init() => _dir();

  bool isDownloaded(String songId) =>
      downloadedIds.value.contains(_safe(songId));

  Future<bool> isDownloadedAsync(String songId) async {
    final dir = await _dir();
    return File('${dir.path}/${_safe(songId)}.audio').existsSync();
  }

  Future<({String url, Map<String, String> headers})> _streamFor(
      Song song) async {
    if (FreeSources.isFreeSong(song)) {
      final s = await FreeSources.instance.streamFor(song);
      if (s == null) throw Exception('no free stream');
      return (url: s.url, headers: s.headers);
    }
    final s = await _yt.getAudioStreamUrl(song);
    return (url: s.url, headers: s.headers);
  }

  /// Download one song now. Reports progress via callback (0–100).
  Future<bool> download(Song song,
      {void Function(int percent)? onProgress}) async {
    File? part;
    try {
      final dir = await _dir();
      final safe = _safe(song.id);
      final target = File('${dir.path}/$safe.audio');
      if (target.existsSync()) return true;

      onProgress?.call(2);
      final stream = await _streamFor(song);
      onProgress?.call(8);

      final client = http.Client();
      try {
        final req = http.Request('GET', Uri.parse(stream.url));
        stream.headers.forEach((k, v) => req.headers[k] = v);
        req.headers.putIfAbsent('User-Agent', () => _ua);
        final resp =
            await client.send(req).timeout(const Duration(seconds: 30));
        if (resp.statusCode != 200 && resp.statusCode != 206) return false;

        final total = resp.contentLength ?? 0;
        // Write to a .part file so a half download never looks finished.
        part = File('${dir.path}/$safe.part');
        final sink = part.openWrite();
        var received = 0;
        var lastPct = -1;
        await for (final chunk in resp.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            final pct = 8 + (received / total * 90).round().clamp(0, 90);
            if (pct != lastPct) {
              lastPct = pct;
              onProgress?.call(pct);
            }
          }
        }
        await sink.flush();
        await sink.close();
      } finally {
        client.close();
      }
      await part!.rename(target.path);
      await File('${dir.path}/$safe.json')
          .writeAsString(jsonEncode(song.toJson()));
      onProgress?.call(100);
      _refreshIds(dir);
      return true;
    } catch (e) {
      debugPrint('Download failed for "${song.title}": $e');
      try {
        if (part != null && part.existsSync()) await part.delete();
      } catch (_) {}
      return false;
    }
  }

  // ── Queue ──

  final List<Song> _pending = [];
  int _running = 0;
  static const _parallel = 2;

  /// Adds songs to the background queue; returns how many were new.
  int queue(Iterable<Song> songs) {
    var added = 0;
    final inFlight = progress.value;
    for (final s in songs) {
      if (isDownloaded(s.id) || inFlight.containsKey(s.id)) continue;
      if (_pending.any((p) => p.id == s.id)) continue;
      _pending.add(s);
      added++;
    }
    if (added > 0) {
      progress.value = {
        ...progress.value,
        for (final s in _pending) s.id: progress.value[s.id] ?? 0,
      };
      _pump();
    }
    return added;
  }

  void cancelQueue() {
    final ids = _pending.map((s) => s.id).toSet();
    _pending.clear();
    progress.value = {
      for (final e in progress.value.entries)
        if (!ids.contains(e.key)) e.key: e.value,
    };
  }

  void _pump() {
    while (_running < _parallel && _pending.isNotEmpty) {
      final song = _pending.removeAt(0);
      _running++;
      download(song, onProgress: (p) {
        progress.value = {...progress.value, song.id: p};
      }).whenComplete(() {
        _running--;
        progress.value = {...progress.value}..remove(song.id);
        _pump();
      });
    }
  }

  /// Local file path for an already-downloaded song, or null.
  Future<String?> localPath(String songId) async {
    final dir = await _dir();
    final f = File('${dir.path}/${_safe(songId)}.audio');
    return f.existsSync() ? f.path : null;
  }

  Future<void> delete(String songId) async {
    final dir = await _dir();
    final safe = _safe(songId);
    for (final ext in const ['audio', 'json', 'part']) {
      final f = File('${dir.path}/$safe.$ext');
      if (f.existsSync()) await f.delete();
    }
    _refreshIds(dir);
  }

  Future<void> deleteAll() async {
    final dir = await _dir();
    if (dir.existsSync()) await dir.delete(recursive: true);
    dir.createSync(recursive: true);
    _refreshIds(dir);
  }

  /// Total size of downloads in bytes.
  Future<int> totalBytes() async {
    final dir = await _dir();
    var n = 0;
    for (final f in dir.listSync().whereType<File>()) {
      if (f.path.endsWith('.audio')) n += f.lengthSync();
    }
    return n;
  }

  /// All downloaded songs, newest first.
  Future<List<Song>> downloadedSongs() async {
    final dir = await _dir();
    if (!dir.existsSync()) return [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.audio'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    // Fallback catalogue for old downloads that have no sidecar.
    Map<String, Song>? byId;
    Map<String, Song> catalogue() {
      if (byId != null) return byId!;
      final m = <String, Song>{};
      for (final s in [
        ...storage.getPlayedHistory(),
        ...storage.getLikedSongs(),
        for (final p in storage.getUserPlaylists())
          ...storage.getUserPlaylistSongs(p.id),
      ]) {
        m[_safe(s.id)] ??= s;
      }
      return byId = m;
    }

    final out = <Song>[];
    for (final f in files) {
      final name = f.uri.pathSegments.last;
      final safe = name.substring(0, name.length - '.audio'.length);
      final meta = File('${dir.path}/$safe.json');
      Song? song;
      if (meta.existsSync()) {
        try {
          song = Song.fromJson(
              jsonDecode(meta.readAsStringSync()) as Map<String, dynamic>);
        } catch (_) {}
      }
      song ??= catalogue()[safe];
      if (song != null) out.add(song);
    }
    return out;
  }
}
