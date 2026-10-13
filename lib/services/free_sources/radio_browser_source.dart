import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/radio_station.dart';

/// Radio Browser — a free, community-maintained directory of ~50k
/// internet radio stations. No key; we pick a mirror and identify
/// ourselves with a User-Agent as the project asks.
class RadioBrowserSource {
  RadioBrowserSource._();
  static final instance = RadioBrowserSource._();

  static const _mirrors = [
    'https://de1.api.radio-browser.info',
    'https://de2.api.radio-browser.info',
    'https://fi1.api.radio-browser.info',
    'https://nl1.api.radio-browser.info',
  ];
  static const _headers = {'User-Agent': 'ZenMusic/1.0'};

  Future<List<RadioStation>> _get(String path, Map<String, String> q) async {
    Object? lastError;
    for (final m in _mirrors) {
      try {
        final uri = Uri.parse('$m$path').replace(queryParameters: {
          'hidebroken': 'true',
          ...q,
        });
        final res = await http
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) {
          lastError = 'HTTP ${res.statusCode}';
          continue;
        }
        final list = jsonDecode(res.body);
        if (list is! List) return const [];
        return [
          for (final s in list)
            if (s is Map &&
                (s['url_resolved'] ?? s['url'] ?? '').toString().isNotEmpty)
              RadioStation(
                id: 'rb:${s['stationuuid']}',
                name: '${s['name'] ?? 'Radio'}'.trim(),
                image: '${s['favicon'] ?? ''}',
                streamUrl: '${s['url_resolved'] ?? s['url']}',
                genre: _genre(s),
                description: '${s['country'] ?? ''}',
              ),
        ];
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception('Radio Browser unreachable: $lastError');
  }

  static String? _genre(Map s) {
    final tags = '${s['tags'] ?? ''}'.split(',').where((t) => t.isNotEmpty);
    if (tags.isEmpty) return null;
    final t = tags.first.trim();
    return t.isEmpty ? null : '${t[0].toUpperCase()}${t.substring(1)}';
  }

  Future<List<RadioStation>> top({int limit = 40, String? countryCode}) {
    if (countryCode != null && countryCode.isNotEmpty) {
      return _get('/json/stations/search', {
        'countrycode': countryCode,
        'order': 'clickcount',
        'reverse': 'true',
        'limit': '$limit',
      });
    }
    return _get('/json/stations/topclick/$limit', const {});
  }

  Future<List<RadioStation>> search(String query, {int limit = 40}) =>
      _get('/json/stations/search', {
        'name': query,
        'order': 'clickcount',
        'reverse': 'true',
        'limit': '$limit',
      });

  Future<List<RadioStation>> byTag(String tag, {int limit = 40}) =>
      _get('/json/stations/bytag/${Uri.encodeComponent(tag)}', {
        'order': 'clickcount',
        'reverse': 'true',
        'limit': '$limit',
      });
}
