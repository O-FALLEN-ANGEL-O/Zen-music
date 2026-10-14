import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// A Spotify track — metadata only. Playback happens by matching it to
/// the same song on JioSaavn / YouTube Music (see SpotifyMatcher).
class SpotifyTrack {
  const SpotifyTrack({
    required this.id,
    required this.title,
    required this.artists,
    required this.album,
    required this.imageUrl,
    required this.duration,
    this.isrc,
  });

  final String id;
  final String title;
  final List<String> artists;
  final String album;
  final String imageUrl;
  final Duration duration;
  final String? isrc;

  String get artist => artists.join(', ');

  static SpotifyTrack? fromJson(Object? j) {
    if (j is! Map) return null;
    if (j['type'] != null && j['type'] != 'track') return null;
    final id = j['id'];
    if (id == null) return null;
    final album = j['album'];
    final images = album is Map ? album['images'] : null;
    String img = '';
    if (images is List && images.isNotEmpty) {
      // Spotify lists images largest first; take the ~300px one.
      final mid = images.length > 1 ? images[1] : images.first;
      img = '${(mid as Map)['url'] ?? ''}';
    }
    final ext = j['external_ids'];
    return SpotifyTrack(
      id: '$id',
      title: '${j['name'] ?? ''}',
      artists: [
        for (final a in (j['artists'] as List? ?? const []))
          if (a is Map && a['name'] != null) '${a['name']}',
      ],
      album: album is Map ? '${album['name'] ?? ''}' : '',
      imageUrl: img,
      duration: Duration(milliseconds: (j['duration_ms'] as num?)?.toInt() ?? 0),
      isrc: ext is Map ? ext['isrc'] as String? : null,
    );
  }
}

class SpotifyPlaylist {
  const SpotifyPlaylist({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.total,
    required this.owner,
  });

  final String id;
  final String name;
  final String imageUrl;
  final int total;
  final String owner;
}

class SpotifyAuthException implements Exception {
  const SpotifyAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Spotify Web API client using the Authorization Code + PKCE flow, so
/// only the user's own Client ID is needed (no secret in the app).
///
/// Note (Spotify, Feb 2026): Development-mode apps need the owner to have
/// Premium, allow up to 5 users, cap search at 10 results per request,
/// and only let you read playlists you own or collaborate on.
class SpotifyClient {
  SpotifyClient._();
  static final instance = SpotifyClient._();

  /// Must be added, exactly, to the app's Redirect URIs on
  /// developer.spotify.com. The login WebView intercepts it, so nothing
  /// needs to listen on this port.
  static const redirectUri = 'http://127.0.0.1:43821/callback';

  static const _scopes = [
    'user-read-private',
    'playlist-read-private',
    'playlist-read-collaborative',
    'user-library-read',
  ];

  static const _kClientId = 'sp_client_id';
  static const _kRefresh = 'sp_refresh_token';
  static const _kName = 'sp_display_name';

  final clientId = ValueNotifier<String>('');

  /// Display name of the signed-in user, or null when signed out.
  final user = ValueNotifier<String?>(null);

  String? _refreshToken;
  String? _accessToken;
  DateTime _expiry = DateTime.fromMillisecondsSinceEpoch(0);
  String? _verifier;
  String? _state;
  bool _loaded = false;

  bool get isConfigured => clientId.value.isNotEmpty;
  bool get isSignedIn => _refreshToken != null;

  Future<void> load() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    clientId.value = p.getString(_kClientId) ?? '';
    _refreshToken = p.getString(_kRefresh);
    if (_refreshToken != null) user.value = p.getString(_kName) ?? 'Spotify';
    _loaded = true;
  }

  Future<void> setClientId(String id) async {
    final v = id.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kClientId, v);
    if (v != clientId.value) await signOut();
    clientId.value = v;
  }

  Future<void> signOut() async {
    _refreshToken = null;
    _accessToken = null;
    user.value = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kRefresh);
    await p.remove(_kName);
  }

  // ── PKCE ──

  static String _random(int len) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static String _b64url(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  /// URL to load in the login WebView.
  Uri authorizeUrl() {
    _verifier = _random(64);
    _state = _random(16);
    final challenge = _b64url(sha256.convert(utf8.encode(_verifier!)).bytes);
    return Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': clientId.value,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
      'state': _state!,
      'scope': _scopes.join(' '),
    });
  }

  /// Called with the redirect URL the WebView intercepted.
  Future<void> completeLogin(Uri redirect) async {
    final err = redirect.queryParameters['error'];
    if (err != null) throw SpotifyAuthException('Spotify said: $err');
    if (redirect.queryParameters['state'] != _state) {
      throw const SpotifyAuthException('Login expired — try again');
    }
    final code = redirect.queryParameters['code'];
    if (code == null || _verifier == null) {
      throw const SpotifyAuthException('No authorization code returned');
    }
    await _token({
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': redirectUri,
      'client_id': clientId.value,
      'code_verifier': _verifier!,
    });
    _verifier = null;
    try {
      final me = await _get('/me');
      final name = '${me['display_name'] ?? me['id'] ?? 'Spotify'}';
      user.value = name;
      final p = await SharedPreferences.getInstance();
      await p.setString(_kName, name);
    } catch (_) {
      user.value = 'Spotify';
    }
  }

  Future<void> _token(Map<String, String> body) async {
    final res = await http
        .post(Uri.parse('https://accounts.spotify.com/api/token'),
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: body)
        .timeout(const Duration(seconds: 15));
    final j = jsonDecode(res.body);
    if (res.statusCode != 200 || j is! Map || j['access_token'] == null) {
      final msg = j is Map ? (j['error_description'] ?? j['error']) : null;
      throw SpotifyAuthException('Spotify login failed: ${msg ?? res.statusCode}');
    }
    _accessToken = j['access_token'] as String;
    _expiry = DateTime.now()
        .add(Duration(seconds: ((j['expires_in'] as num?) ?? 3600).toInt() - 60));
    final rt = j['refresh_token'] as String?;
    if (rt != null) {
      _refreshToken = rt;
      final p = await SharedPreferences.getInstance();
      await p.setString(_kRefresh, rt);
    }
  }

  Future<String> _access() async {
    await load();
    if (_accessToken != null && DateTime.now().isBefore(_expiry)) {
      return _accessToken!;
    }
    final rt = _refreshToken;
    if (rt == null) throw const SpotifyAuthException('Not signed in');
    try {
      await _token({
        'grant_type': 'refresh_token',
        'refresh_token': rt,
        'client_id': clientId.value,
      });
    } on SpotifyAuthException {
      await signOut();
      rethrow;
    }
    return _accessToken!;
  }

  Future<Map<String, dynamic>> _get(String path,
      [Map<String, String>? q]) async {
    final token = await _access();
    final uri = path.startsWith('http')
        ? Uri.parse(path)
        : Uri.https('api.spotify.com', '/v1$path', q);
    final res = await http.get(uri, headers: {
      'Authorization': 'Bearer $token'
    }).timeout(const Duration(seconds: 15));
    if (res.statusCode == 401) {
      _accessToken = null;
      throw const SpotifyAuthException('Session expired — sign in again');
    }
    if (res.statusCode == 403) {
      throw const SpotifyAuthException(
          'Spotify refused this request. The developer app owner needs '
          'Premium, and your account must be added under "Users" in the '
          'developer dashboard.');
    }
    if (res.statusCode == 429) {
      throw const SpotifyAuthException('Spotify rate limit — wait a minute');
    }
    if (res.statusCode != 200) {
      throw SpotifyAuthException('Spotify error ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Endpoints ──

  /// Track search. Spotify caps dev-mode apps at 10 per request, so we
  /// page through [pages] offsets.
  Future<List<SpotifyTrack>> searchTracks(String q, {int pages = 3}) async {
    final out = <SpotifyTrack>[];
    for (var i = 0; i < pages; i++) {
      final j = await _get('/search', {
        'q': q,
        'type': 'track',
        'limit': '10',
        'offset': '${i * 10}',
      });
      final items = (j['tracks'] as Map?)?['items'] as List? ?? const [];
      for (final t in items) {
        final tr = SpotifyTrack.fromJson(t);
        if (tr != null) out.add(tr);
      }
      if (items.length < 10) break;
    }
    return out;
  }

  Future<List<SpotifyPlaylist>> myPlaylists() async {
    final out = <SpotifyPlaylist>[];
    String? next = '/me/playlists';
    Map<String, String>? q = {'limit': '50'};
    while (next != null && out.length < 500) {
      final j = await _get(next, q);
      q = null;
      for (final p in (j['items'] as List? ?? const [])) {
        if (p is! Map || p['id'] == null) continue;
        final imgs = p['images'];
        final counts = p['items'] ?? p['tracks'];
        out.add(SpotifyPlaylist(
          id: '${p['id']}',
          name: '${p['name'] ?? 'Playlist'}',
          imageUrl: imgs is List && imgs.isNotEmpty
              ? '${(imgs.first as Map)['url'] ?? ''}'
              : '',
          total: counts is Map ? ((counts['total'] as num?)?.toInt() ?? 0) : 0,
          owner: '${(p['owner'] as Map?)?['display_name'] ?? ''}',
        ));
      }
      next = j['next'] as String?;
    }
    return out;
  }

  /// Tracks of a playlist you own or collaborate on.
  Future<List<SpotifyTrack>> playlistTracks(String id, {int max = 500}) =>
      _pagedTracks('/playlists/$id/items', max);

  /// Your Liked Songs.
  Future<List<SpotifyTrack>> likedTracks({int max = 500}) =>
      _pagedTracks('/me/tracks', max);

  Future<List<SpotifyTrack>> _pagedTracks(String path, int max) async {
    final out = <SpotifyTrack>[];
    String? next = path;
    Map<String, String>? q = {'limit': '50'};
    while (next != null && out.length < max) {
      final j = await _get(next, q);
      q = null;
      for (final it in (j['items'] as List? ?? const [])) {
        if (it is! Map) continue;
        // Feb 2026 renamed the nested field from `track` to `item`.
        final tr = SpotifyTrack.fromJson(it['item'] ?? it['track']);
        if (tr != null) out.add(tr);
      }
      next = j['next'] as String?;
    }
    return out;
  }

  /// Album tracks (album art comes from the album itself).
  Future<({String name, List<SpotifyTrack> tracks})> album(String id) async {
    final j = await _get('/albums/$id');
    final imgs = j['images'];
    final img = imgs is List && imgs.isNotEmpty
        ? '${(imgs.length > 1 ? imgs[1] : imgs.first)['url']}'
        : '';
    final tracks = <SpotifyTrack>[];
    for (final t in ((j['tracks'] as Map?)?['items'] as List? ?? const [])) {
      if (t is! Map) continue;
      final tr = SpotifyTrack.fromJson({
        ...t,
        'album': {
          'name': j['name'],
          'images': [
            {'url': img}
          ]
        },
      });
      if (tr != null) tracks.add(tr);
    }
    return (name: '${j['name'] ?? 'Album'}', tracks: tracks);
  }
}
