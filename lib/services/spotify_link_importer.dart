import 'dart:convert';

import 'package:http/http.dart' as http;

/// Reads the public track list (title + artist only) of a Spotify
/// playlist, album or track link from Spotify's embed page — the same
/// data the embeddable web player shows to anyone. No account, no audio:
/// the import then finds each song on YouTube Music / JioSaavn.
class SpotifyLinkImporter {
  SpotifyLinkImporter._();

  static final _linkRe = RegExp(
      r'(?:open\.spotify\.com/(?:intl-[a-z]{2}/)?|spotify:)(playlist|album|track)[/:]([A-Za-z0-9]{10,40})');

  /// Parses a link or URI into (type, id), or null.
  static ({String type, String id})? parse(String input) {
    final m = _linkRe.firstMatch(input.trim());
    if (m == null) return null;
    return (type: m.group(1)!, id: m.group(2)!);
  }

  static Future<({String name, List<({String title, String artist})> tracks})>
      fetch(String link) async {
    final ref = parse(link);
    if (ref == null) {
      throw const FormatException('That doesn\'t look like a Spotify link');
    }
    final res = await http.get(
      Uri.parse('https://open.spotify.com/embed/${ref.type}/${ref.id}'),
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Mobile Safari/537.36',
        'Accept-Language': 'en',
      },
    ).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Spotify returned ${res.statusCode}');
    }
    final m = RegExp(
            r'<script[^>]*id="__NEXT_DATA__"[^>]*>(.*?)</script>',
            dotAll: true)
        .firstMatch(res.body);
    if (m == null) throw Exception('Couldn\'t read that playlist');
    final data = jsonDecode(m.group(1)!);

    final entity = _find(data, (k, v) => k == 'entity' && v is Map) as Map?;
    final name = '${entity?['name'] ?? entity?['title'] ?? 'Spotify import'}';

    final tracks = <({String title, String artist})>[];
    final list = _find(data, (k, v) => k == 'trackList' && v is List) as List?;
    if (list != null) {
      for (final t in list) {
        if (t is! Map) continue;
        final title = '${t['title'] ?? t['name'] ?? ''}'.trim();
        final artist = '${t['subtitle'] ?? t['artist'] ?? ''}'
            .replaceAll(' ', ' ')
            .trim();
        if (title.isNotEmpty) tracks.add((title: title, artist: artist));
      }
    } else if (ref.type == 'track' && entity != null) {
      final artists = entity['artists'];
      final artist = artists is List
          ? artists
              .whereType<Map>()
              .map((a) => '${a['name'] ?? ''}')
              .where((s) => s.isNotEmpty)
              .join(', ')
          : '${entity['subtitle'] ?? ''}';
      tracks.add((title: name, artist: artist));
    }
    if (tracks.isEmpty) throw Exception('No tracks found at that link');
    return (name: name, tracks: tracks);
  }

  /// Depth-first search through decoded JSON for the first key/value
  /// pair matching [test].
  static Object? _find(Object? node, bool Function(String k, Object? v) test) {
    if (node is Map) {
      for (final e in node.entries) {
        if (test('${e.key}', e.value)) return e.value;
      }
      for (final v in node.values) {
        final r = _find(v, test);
        if (r != null) return r;
      }
    } else if (node is List) {
      for (final v in node) {
        final r = _find(v, test);
        if (r != null) return r;
      }
    }
    return null;
  }

  /// Builds a CSV the existing importer understands.
  static String toCsv(List<({String title, String artist})> tracks) {
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    final b = StringBuffer('Track Name,Artist Name(s)\n');
    for (final t in tracks) {
      b.writeln('${q(t.title)},${q(t.artist)}');
    }
    return b.toString();
  }
}
