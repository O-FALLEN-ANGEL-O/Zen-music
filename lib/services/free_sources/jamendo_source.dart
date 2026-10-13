import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/song.dart';
import 'free_source.dart';

/// Jamendo — 600k+ Creative Commons tracks. Needs a free client id
/// from https://devportal.jamendo.com (takes a minute to register).
class JamendoSource extends FreeMusicSource {
  JamendoSource({this.clientId});

  String? clientId;

  @override
  String get id => 'jamendo';
  @override
  String get name => 'Jamendo';
  @override
  String get blurb => 'Creative Commons music from independent artists';
  @override
  bool get needsKey => true;
  @override
  String? get keyUrl => 'https://devportal.jamendo.com/';

  bool get ready => clientId != null && clientId!.isNotEmpty;

  final Map<String, String> _audio = {};

  Future<List<Song>> _tracks(Map<String, String> q, int limit) async {
    if (!ready) return const [];
    final uri = Uri.parse('https://api.jamendo.com/v3.0/tracks/').replace(
      queryParameters: {
        'client_id': clientId!,
        'format': 'json',
        'limit': '$limit',
        'audioformat': 'mp32',
        'imagesize': '300',
        ...q,
      },
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) throw Exception('Jamendo ${res.statusCode}');
    final body = jsonDecode(res.body);
    final results = body is Map ? body['results'] : null;
    if (results is! List) return const [];
    final songs = <Song>[];
    for (final t in results) {
      if (t is! Map || t['id'] == null) continue;
      final tid = '${t['id']}';
      final audio = '${t['audio'] ?? ''}';
      if (audio.isNotEmpty) _audio[tid] = audio;
      songs.add(Song(
        id: songId(tid),
        title: '${t['name'] ?? 'Untitled'}',
        artist: '${t['artist_name'] ?? 'Jamendo artist'}',
        thumbnail: '${t['image'] ?? t['album_image'] ?? ''}',
        duration: Duration(seconds: (t['duration'] as num?)?.toInt() ?? 0),
        audioType: 'MP3',
        bitrateKbps: 320,
      ));
    }
    return songs;
  }

  @override
  Future<List<Song>> trending({int limit = 30}) =>
      _tracks({'order': 'popularity_week'}, limit);

  @override
  Future<List<Song>> search(String query, {int limit = 30}) =>
      _tracks({'search': query, 'order': 'relevance'}, limit);

  @override
  Future<FreeStream?> stream(Song song) async {
    final tid = nativeId(song);
    var url = _audio[tid];
    if (url == null && ready) {
      await _tracks({'id': tid}, 1);
      url = _audio[tid];
    }
    if (url == null) return null;
    return FreeStream(url, codec: 'MP3', kbps: 320);
  }
}
