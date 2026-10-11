/// Route constants — Screen.kt port (ZenMusic-relevant subset; the
/// Last.fm / module routes have no Zen counterpart).
class LwRoutes {
  LwRoutes._();
  static const splash = 'splash';
  static const login = 'login';
  static const mainShell = 'main_shell';
  static const search = 'search';
  static const settings = 'settings';
  static const discover = 'discover';
  static const downloads = 'downloads';
  static const artistDetail = 'artist_detail';
  static const albumDetail = 'album_detail';
  static const playlistDetail = 'playlist_detail';

  static String artist(String name, {String? browseId}) =>
      '$artistDetail/${encodeArg(name)}${browseId == null ? '' : '?browseId=${encodeArg(browseId)}'}';
  static String album(String title, {String artist = '', String? browseId}) =>
      '$albumDetail/${encodeArg(title)}?artistName=${encodeArg(artist)}';
  static String playlist(Object id) => '$playlistDetail/$id';

  /// Screen.encodeArg port: names like "AC/DC" can never split a route.
  static String encodeArg(String raw) => Uri.encodeComponent(raw)
      .replaceAll('/', '%2F')
      .replaceAll('?', '%3F')
      .replaceAll('&', '%26')
      .replaceAll('#', '%23');
}