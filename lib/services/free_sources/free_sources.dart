import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/song.dart';
import 'audius_source.dart';
import 'free_source.dart';
import 'internet_archive_source.dart';
import 'jamendo_source.dart';

export 'free_source.dart';
export 'radio_browser_source.dart';

/// Registry of the free, legal catalogues ZenMusic can play from, plus
/// their on/off switches and (optional) API keys.
class FreeSources {
  FreeSources._();
  static final instance = FreeSources._();

  final audius = AudiusSource();
  final archive = InternetArchiveSource();
  final jamendo = JamendoSource();

  List<FreeMusicSource> get all => [audius, archive, jamendo];

  /// Source id → enabled.
  final enabled = ValueNotifier<Map<String, bool>>({
    'audius': true,
    'ia': true,
    'jamendo': true,
  });

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    audius.apiKey = p.getString('fs_audius_key');
    jamendo.clientId = p.getString('fs_jamendo_key');
    enabled.value = {
      for (final s in all) s.id: p.getBool('fs_on_${s.id}') ?? true,
    };
    _loaded = true;
  }

  Future<void> setEnabled(String id, bool on) async {
    enabled.value = {...enabled.value, id: on};
    final p = await SharedPreferences.getInstance();
    await p.setBool('fs_on_$id', on);
  }

  Future<void> setKey(String id, String key) async {
    final p = await SharedPreferences.getInstance();
    final v = key.trim();
    if (id == 'audius') {
      audius.apiKey = v;
      await p.setString('fs_audius_key', v);
    } else if (id == 'jamendo') {
      jamendo.clientId = v;
      await p.setString('fs_jamendo_key', v);
    }
    enabled.value = {...enabled.value};
  }

  String keyFor(String id) => switch (id) {
        'audius' => audius.apiKey ?? '',
        'jamendo' => jamendo.clientId ?? '',
        _ => '',
      };

  /// Sources that are switched on and usable right now.
  List<FreeMusicSource> get active => [
        for (final s in all)
          if ((enabled.value[s.id] ?? true) &&
              (!s.needsKey || keyFor(s.id).isNotEmpty))
            s,
      ];

  /// Which source a Song came from, if any.
  FreeMusicSource? sourceOf(Song song) {
    for (final s in all) {
      if (song.id.startsWith('${s.id}:')) return s;
    }
    return null;
  }

  static bool isFreeSong(Song song) => instance.sourceOf(song) != null;

  /// Searches every active source in parallel; a failing source just
  /// contributes nothing.
  Future<Map<FreeMusicSource, List<Song>>> searchAll(String query,
      {int perSource = 15}) async {
    await load();
    final sources = active;
    final results = await Future.wait(sources.map((s) => s
        .search(query, limit: perSource)
        .catchError((Object e) {
          debugPrint('FreeSources: ${s.name} search failed: $e');
          return <Song>[];
        })));
    return {
      for (var i = 0; i < sources.length; i++)
        if (results[i].isNotEmpty) sources[i]: results[i],
    };
  }

  Future<FreeStream?> streamFor(Song song) async {
    await load();
    return sourceOf(song)?.stream(song);
  }

  /// "More like this" for autoplay: same artist on the same source,
  /// falling back to that source's trending list.
  Future<List<Song>> related(Song seed, {int limit = 10}) async {
    final s = sourceOf(seed);
    if (s == null) return const [];
    try {
      final byArtist = await s.search(seed.artist, limit: limit + 5);
      final out = byArtist.where((x) => x.id != seed.id).toList();
      if (out.length >= 3) return out.take(limit).toList();
      final trend = await s.trending(limit: limit + 5);
      return [...out, ...trend.where((x) => x.id != seed.id)]
          .take(limit)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
