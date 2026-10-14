import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/spotify/spotify_client.dart';
import '../services/spotify/spotify_player.dart';
import '../services/spotify_link_importer.dart';
import '../theme/spotify_theme.dart';
import 'import_spotify_screen.dart';

const _spotifyGreen = Color(0xFF1ED760);

/// Spotify hub: one-time setup → sign in → search Spotify, browse your
/// playlists and Liked Songs. Tracks play via matching on JioSaavn /
/// YouTube Music (Spotify's API never provides audio).
class SpotifyScreen extends StatefulWidget {
  const SpotifyScreen({super.key});

  @override
  State<SpotifyScreen> createState() => _SpotifyScreenState();
}

class _SpotifyScreenState extends State<SpotifyScreen> {
  final _sp = SpotifyClient.instance;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _sp.load().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyColors.background,
      appBar: AppBar(
        title: const Text('Spotify'),
        actions: [
          ValueListenableBuilder<String?>(
            valueListenable: _sp.user,
            builder: (context, u, _) => u == null
                ? const SizedBox.shrink()
                : PopupMenuButton<String>(
                    icon: const Icon(Icons.account_circle_rounded),
                    onSelected: (v) async {
                      if (v == 'out') await _sp.signOut();
                      if (v == 'setup') {
                        await _sp.signOut();
                        await _sp.setClientId('');
                      }
                      if (mounted) setState(() {});
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(enabled: false, child: Text('Signed in as $u')),
                      const PopupMenuItem(value: 'out', child: Text('Sign out')),
                      const PopupMenuItem(
                          value: 'setup', child: Text('Change Client ID')),
                    ],
                  ),
          ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder<String?>(
              valueListenable: _sp.user,
              builder: (context, user, _) {
                if (!_sp.isConfigured) {
                  return _Setup(onDone: () => setState(() {}));
                }
                if (user == null) {
                  return _SignIn(onChanged: () => setState(() {}));
                }
                return const _SpotifyHome();
              },
            ),
    );
  }
}

// ═════════════════════════════════════════════
// Setup (Client ID)
// ═════════════════════════════════════════════

class _Setup extends StatefulWidget {
  const _Setup({required this.onDone});
  final VoidCallback onDone;

  @override
  State<_Setup> createState() => _SetupState();
}

class _SetupState extends State<_Setup> {
  final _id = TextEditingController();

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  Widget _step(int n, String text, {Widget? extra}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: _spotifyGreen,
              child: Text('$n',
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text,
                      style: TextStyle(
                          color: SpotifyColors.textPrimary, height: 1.4)),
                  if (extra != null) ...[const SizedBox(height: 6), extra],
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
      children: [
        const _LinkImportCard(),
        const SizedBox(height: 24),
        Text('Connect your Spotify account',
            style: TextStyle(
                color: SpotifyColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          'For your own playlists, Liked Songs and Spotify search, Spotify '
          'requires a free developer key. It takes about two minutes, once.',
          style: TextStyle(color: SpotifyColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 18),
        _step(1, 'Open the Spotify developer dashboard and log in.',
            extra: OutlinedButton.icon(
              onPressed: () => launchUrl(
                  Uri.parse('https://developer.spotify.com/dashboard'),
                  mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('developer.spotify.com'),
            )),
        _step(2,
            'Tap "Create app". Any name and description. Tick "Web API".'),
        _step(3, 'Add this exact Redirect URI, then Save:',
            extra: Material(
              color: SpotifyColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Clipboard.setData(
                      const ClipboardData(text: SpotifyClient.redirectUri));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied')));
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(SpotifyClient.redirectUri,
                            style: TextStyle(
                                color: SpotifyColors.textPrimary,
                                fontFamily: 'monospace',
                                fontSize: 13)),
                      ),
                      Icon(Icons.copy_rounded,
                          size: 18, color: SpotifyColors.textSecondary),
                    ],
                  ),
                ),
              ),
            )),
        _step(4,
            'If someone else will sign in, add their Spotify email under '
            'Settings → User Management (up to 5 people).'),
        _step(5, 'Copy the app\'s Client ID and paste it here:',
            extra: TextField(
              controller: _id,
              style: TextStyle(color: SpotifyColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Client ID (32 characters)',
                hintStyle: TextStyle(color: SpotifyColors.textTertiary),
                filled: true,
                fillColor: SpotifyColors.surfaceLight,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            )),
        const SizedBox(height: 4),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: _spotifyGreen, foregroundColor: Colors.black),
          onPressed: () async {
            final v = _id.text.trim();
            if (!RegExp(r'^[A-Za-z0-9]{20,40}$').hasMatch(v)) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('That doesn\'t look like a Client ID')));
              return;
            }
            await SpotifyClient.instance.setClientId(v);
            widget.onDone();
          },
          child: const Text('Save and continue'),
        ),
        const SizedBox(height: 14),
        Text(
          'Spotify\'s rule (since Feb 2026): the account that creates the '
          'developer app must have Spotify Premium.',
          style: TextStyle(
              color: SpotifyColors.textTertiary, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}

/// No-setup option: paste any public playlist/album link.
class _LinkImportCard extends StatelessWidget {
  const _LinkImportCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SpotifyColors.surfaceLight,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        leading: const Icon(Icons.link_rounded, color: _spotifyGreen),
        title: Text('No setup: import a playlist link',
            style: TextStyle(
                color: SpotifyColors.textPrimary, fontWeight: FontWeight.w700)),
        subtitle: Text('Paste any public Spotify playlist or album link',
            style: TextStyle(color: SpotifyColors.textSecondary)),
        trailing: Icon(Icons.chevron_right_rounded,
            color: SpotifyColors.textTertiary),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const ImportSpotifyScreen())),
      ),
    );
  }
}

// ═════════════════════════════════════════════
// Sign in (WebView, PKCE)
// ═════════════════════════════════════════════

class _SignIn extends StatelessWidget {
  const _SignIn({required this.onChanged});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 140),
      children: [
        const Icon(Icons.graphic_eq_rounded, color: _spotifyGreen, size: 64),
        const SizedBox(height: 16),
        Text('Sign in with Spotify',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: SpotifyColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          'ZenMusic only reads your playlists and Liked Songs. Use your '
          'Spotify email and password — "Continue with Google" may not '
          'work inside apps.',
          textAlign: TextAlign.center,
          style: TextStyle(color: SpotifyColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: _spotifyGreen,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(50)),
          onPressed: () async {
            final ok = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const _LoginWebView()));
            if (ok == true) onChanged();
          },
          child: const Text('Sign in',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () async {
            await SpotifyClient.instance.setClientId('');
            onChanged();
          },
          child: const Text('Use a different Client ID'),
        ),
        const SizedBox(height: 20),
        const _LinkImportCard(),
      ],
    );
  }
}

class _LoginWebView extends StatefulWidget {
  const _LoginWebView();

  @override
  State<_LoginWebView> createState() => _LoginWebViewState();
}

class _LoginWebViewState extends State<_LoginWebView> {
  late final WebViewController _web;
  bool _finishing = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onNavigationRequest: (req) {
          if (req.url.startsWith(SpotifyClient.redirectUri)) {
            _finish(Uri.parse(req.url));
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(SpotifyClient.instance.authorizeUrl());
  }

  Future<void> _finish(Uri redirect) async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await SpotifyClient.instance.completeLogin(redirect);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spotify sign-in'),
        bottom: _progress < 100 || _finishing
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      body: _finishing
          ? const Center(child: CircularProgressIndicator())
          : WebViewWidget(controller: _web),
    );
  }
}

// ═════════════════════════════════════════════
// Signed-in home
// ═════════════════════════════════════════════

class _SpotifyHome extends StatefulWidget {
  const _SpotifyHome();

  @override
  State<_SpotifyHome> createState() => _SpotifyHomeState();
}

class _SpotifyHomeState extends State<_SpotifyHome> {
  final _sp = SpotifyClient.instance;
  final _q = TextEditingController();
  Timer? _debounce;
  String _query = '';
  late Future<List<SpotifyPlaylist>> _playlists = _sp.myPlaylists();
  final _searches = <String, Future<List<SpotifyTrack>>>{};

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _openList(String title, String image, Future<List<SpotifyTrack>> f) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              SpotifyTracksScreen(title: title, imageUrl: image, tracks: f)));

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _playlists = _sp.myPlaylists());
        await _playlists.catchError((_) => <SpotifyPlaylist>[]);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 150),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _q,
              textInputAction: TextInputAction.search,
              style: TextStyle(color: SpotifyColors.textPrimary),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 500),
                    () => setState(() => _query = v.trim()));
              },
              onSubmitted: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search Spotify',
                hintStyle: TextStyle(color: SpotifyColors.textTertiary),
                prefixIcon: Icon(Icons.search_rounded,
                    color: SpotifyColors.textSecondary),
                filled: true,
                fillColor: SpotifyColors.surfaceLight,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          const _BusyBar(),
          if (_query.isNotEmpty)
            _TrackList(
              future: _searches.putIfAbsent(
                  _query, () => _sp.searchTracks(_query)),
              showActions: false,
            )
          else ...[
            _bigTile(
              icon: Icons.favorite_rounded,
              title: 'Liked Songs',
              subtitle: 'From your Spotify library',
              onTap: () => _openList('Liked Songs', '', _sp.likedTracks()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Text('Your playlists',
                  style: TextStyle(
                      color: SpotifyColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ),
            FutureBuilder<List<SpotifyPlaylist>>(
              future: _playlists,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()));
                }
                if (snap.hasError) return _error('${snap.error}');
                final list = snap.data ?? const <SpotifyPlaylist>[];
                if (list.isEmpty) {
                  return _error('No playlists in this account yet');
                }
                return Column(
                  children: [
                    for (final p in list)
                      ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: p.imageUrl.isEmpty
                                ? Container(color: SpotifyColors.surfaceLight)
                                : CachedNetworkImage(
                                    imageUrl: p.imageUrl, fit: BoxFit.cover),
                          ),
                        ),
                        title: Text(p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: SpotifyColors.textPrimary,
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            'Playlist · ${p.owner}${p.total > 0 ? ' · ${p.total} songs' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(color: SpotifyColors.textSecondary)),
                        onTap: () => _openList(
                            p.name, p.imageUrl, _sp.playlistTracks(p.id)),
                      ),
                  ],
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'Spotify only lets apps read playlists you own or collaborate '
                'on. For anyone else\'s playlist, paste its link in Import.',
                style: TextStyle(
                    color: SpotifyColors.textTertiary,
                    fontSize: 12,
                    height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bigTile(
          {required IconData icon,
          required String title,
          required String subtitle,
          required VoidCallback onTap}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Material(
          color: SpotifyColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4A1FB8), Color(0xFF8FB3E8)],
                    ),
                  ),
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              color: SpotifyColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                      Text(subtitle,
                          style: TextStyle(
                              color: SpotifyColors.textSecondary,
                              fontSize: 12.5)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: SpotifyColors.textTertiary),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      );
}

Widget _error(String msg) => Padding(
      padding: const EdgeInsets.all(24),
      child: Text(msg,
          textAlign: TextAlign.center,
          style: TextStyle(color: SpotifyColors.textSecondary, height: 1.4)),
    );

class _BusyBar extends StatelessWidget {
  const _BusyBar();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SpotifyPlayer.instance.busy,
      builder: (context, busy, _) => busy
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 10),
                  Text('Finding this song on JioSaavn / YouTube Music…',
                      style: TextStyle(
                          color: SpotifyColors.textSecondary, fontSize: 13)),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

// ═════════════════════════════════════════════
// Track list (playlist / liked / search / album)
// ═════════════════════════════════════════════

class SpotifyTracksScreen extends StatelessWidget {
  const SpotifyTracksScreen({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.tracks,
  });

  final String title;
  final String imageUrl;
  final Future<List<SpotifyTrack>> tracks;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyColors.background,
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 150),
        children: [
          if (imageUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(60, 8, 60, 8),
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child:
                      CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
                ),
              ),
            ),
          const _BusyBar(),
          _TrackList(future: tracks, listName: title),
        ],
      ),
    );
  }
}

class _TrackList extends StatelessWidget {
  const _TrackList(
      {required this.future, this.showActions = true, this.listName});

  final Future<List<SpotifyTrack>> future;
  final bool showActions;
  final String? listName;

  Future<void> _play(BuildContext context, List<SpotifyTrack> t, int i,
      {bool shuffle = false}) async {
    final ok = await SpotifyPlayer.instance.play(t, i, shuffle: shuffle);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Couldn\'t find that song on JioSaavn or YouTube')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SpotifyTrack>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) return _error('${snap.error}');
        final tracks = snap.data ?? const <SpotifyTrack>[];
        if (tracks.isEmpty) return _error('Nothing here');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showActions)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${tracks.length} songs',
                          style: TextStyle(
                              color: SpotifyColors.textSecondary)),
                    ),
                    IconButton(
                      tooltip: 'Save to your ZenMusic library',
                      icon: Icon(Icons.library_add_rounded,
                          color: SpotifyColors.textPrimary),
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => ImportSpotifyScreen(
                                    initialCsv: SpotifyLinkImporter.toCsv([
                                      for (final t in tracks)
                                        (title: t.title, artist: t.artist)
                                    ]),
                                    initialName: listName,
                                  ))),
                    ),
                    IconButton(
                      tooltip: 'Shuffle',
                      icon: Icon(Icons.shuffle_rounded,
                          color: SpotifyColors.textPrimary),
                      onPressed: () =>
                          _play(context, tracks, 0, shuffle: true),
                    ),
                    IconButton(
                      tooltip: 'Play',
                      iconSize: 48,
                      icon: const Icon(Icons.play_circle_fill_rounded,
                          color: _spotifyGreen),
                      onPressed: () => _play(context, tracks, 0),
                    ),
                  ],
                ),
              ),
            for (var i = 0; i < tracks.length; i++)
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: tracks[i].imageUrl.isEmpty
                        ? Container(color: SpotifyColors.surfaceLight)
                        : CachedNetworkImage(
                            imageUrl: tracks[i].imageUrl, fit: BoxFit.cover),
                  ),
                ),
                title: Text(tracks[i].title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: SpotifyColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                subtitle: Text(tracks[i].artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: SpotifyColors.textSecondary)),
                onTap: () => _play(context, tracks, i),
              ),
          ],
        );
      },
    );
  }
}
