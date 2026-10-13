import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/song.dart';
import 'free_source.dart';

/// Internet Archive audio — live concert recordings (etree), netlabel
/// releases and public-domain / Creative Commons audio. No key needed.
///
/// Search returns archive *items* (an album or a show); each becomes one
/// Song whose stream is the item's first MP3 file.
class InternetArchiveSource extends FreeMusicSource {
  @override
  String get id => 'ia';
  @override
  String get name => 'Internet Archive';
  @override
  String get blurb => 'Live recordings, netlabels and public-domain music';

  static const _collections =
      'collection:(etree OR netlabels OR opensource_audio OR audio_music)';

  Future<List<Song>> _search(String q, int limit, {String sort = ''}) async {
    final uri = Uri.parse('https://archive.org/advancedsearch.php').replace(
      queryParameters: {
        'q': '($q) AND mediatype:(audio) AND $_collections',
        'fl[]': ['identifier', 'title', 'creator'].join(','),
        'rows': '$limit',
        'page': '1',
        'output': 'json',
        if (sort.isNotEmpty) 'sort[]': sort,
      },
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw Exception('Archive ${res.statusCode}');
    final body = jsonDecode(res.body);
    final docs = (body is Map && body['response'] is Map)
        ? body['response']['docs']
        : null;
    if (docs is! List) return const [];
    return [
      for (final d in docs)
        if (d is Map && d['identifier'] != null)
          Song(
            id: songId('${d['identifier']}'),
            title: _first(d['title']) ?? '${d['identifier']}',
            artist: _first(d['creator']) ?? 'Internet Archive',
            thumbnail: 'https://archive.org/services/img/${d['identifier']}',
            duration: Duration.zero,
            audioType: 'MP3',
          ),
    ];
  }

  static String? _first(Object? v) {
    if (v is String) return v;
    if (v is List && v.isNotEmpty) return '${v.first}';
    return null;
  }

  @override
  Future<List<Song>> trending({int limit = 30}) =>
      _search('*', limit, sort: 'downloads desc');

  @override
  Future<List<Song>> search(String query, {int limit = 30}) {
    // Escape Lucene specials the user is unlikely to mean literally.
    final safe = query.replaceAll(RegExp(r'[():"\\]'), ' ').trim();
    if (safe.isEmpty) return trending(limit: limit);
    return _search(safe, limit);
  }

  final Map<String, FreeStream> _cache = {};

  @override
  Future<FreeStream?> stream(Song song) async {
    final item = nativeId(song);
    final hit = _cache[item];
    if (hit != null) return hit;
    final res = await http
        .get(Uri.parse('https://archive.org/metadata/$item/files'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body);
    final files = body is Map ? body['result'] : null;
    if (files is! List) return null;
    // Prefer the derived VBR MP3s (smallest, always streamable), else
    // any MP3, else Ogg.
    Map? pick;
    for (final want in const ['VBR MP3', '128Kbps MP3', 'MP3', 'Ogg Vorbis']) {
      for (final f in files) {
        if (f is Map && f['format'] == want && f['name'] != null) {
          pick = f;
          break;
        }
      }
      if (pick != null) break;
    }
    if (pick == null) return null;
    final name = Uri.encodeComponent('${pick['name']}')
        .replaceAll('%2F', '/');
    final out = FreeStream('https://archive.org/download/$item/$name',
        codec: '${pick['format']}'.contains('Ogg') ? 'OGG' : 'MP3');
    _cache[item] = out;
    return out;
  }
}
