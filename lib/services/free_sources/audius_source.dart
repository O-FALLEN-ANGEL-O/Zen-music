import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/song.dart';
import 'free_source.dart';

/// Audius — a decentralised streaming platform where artists publish
/// full tracks for free listening. REST API at api.audius.co/v1.
///
/// Requests carry `app_name` and, when the user has added one, their
/// free API key as a Bearer token (keys come from the Audius API Plans
/// page and are documented as safe for client apps).
class AudiusSource extends FreeMusicSource {
  AudiusSource({this.apiKey});

  /// Optional user API key.
  String? apiKey;

  static const _base = 'https://api.audius.co/v1';
  static const _app = 'ZenMusic';

  @override
  String get id => 'audius';
  @override
  String get name => 'Audius';
  @override
  String get blurb => 'Full tracks published free by independent artists';
  @override
  String? get keyUrl => 'https://audius.co/settings';

  Map<String, String> get _auth => {
        if (apiKey != null && apiKey!.isNotEmpty)
          'Authorization': 'Bearer $apiKey',
      };

  Map<String, String> get _headers => {'Accept': 'application/json', ..._auth};

  Uri _uri(String path, [Map<String, String> q = const {}]) =>
      Uri.parse('$_base$path').replace(queryParameters: {
        ...q,
        'app_name': _app,
      });

  Future<List<Song>> _tracks(Uri uri, int limit) async {
    final res = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('Audius ${res.statusCode}');
    }
    final body = jsonDecode(res.body);
    final data = body is Map ? body['data'] : null;
    if (data is! List) return const [];
    final songs = <Song>[];
    for (final t in data) {
      if (t is! Map) continue;
      // Skip gated / non-streamable uploads.
      if (t['is_streamable'] == false) continue;
      if (t['is_stream_gated'] == true) continue;
      final tid = '${t['id'] ?? ''}';
      if (tid.isEmpty) continue;
      final art = t['artwork'];
      final user = t['user'];
      songs.add(Song(
        id: songId(tid),
        title: '${t['title'] ?? 'Untitled'}',
        artist: user is Map ? '${user['name'] ?? 'Audius artist'}' : 'Audius artist',
        thumbnail: art is Map
            ? '${art['480x480'] ?? art['1000x1000'] ?? art['150x150'] ?? ''}'
            : '',
        duration: Duration(seconds: (t['duration'] as num?)?.toInt() ?? 0),
        audioType: 'MP3',
        bitrateKbps: 320,
      ));
      if (songs.length >= limit) break;
    }
    return songs;
  }

  @override
  Future<List<Song>> trending({int limit = 30}) =>
      _tracks(_uri('/tracks/trending', {'limit': '$limit'}), limit);

  @override
  Future<List<Song>> search(String query, {int limit = 30}) => _tracks(
      _uri('/tracks/search', {'query': query, 'limit': '$limit'}), limit);

  @override
  Future<FreeStream?> stream(Song song) async {
    final url = _uri('/tracks/${nativeId(song)}/stream').toString();
    return FreeStream(url, headers: _auth, codec: 'MP3', kbps: 320);
  }
}
