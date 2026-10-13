import '../../models/song.dart';

/// A resolved, directly playable audio URL.
class FreeStream {
  const FreeStream(this.url, {this.headers = const {}, this.codec, this.kbps});

  final String url;
  final Map<String, String> headers;
  final String? codec;
  final int? kbps;
}

/// A catalogue of music that is free and legal to stream (artists have
/// published it for free listening, or it is public domain / Creative
/// Commons). Songs from these sources carry an id of the form
/// `<sourceId>:<nativeId>` so the player can route them back here.
abstract class FreeMusicSource {
  /// Short stable prefix used in Song ids, e.g. `audius`.
  String get id;

  /// Display name.
  String get name;

  /// One-line description for the settings screen.
  String get blurb;

  /// True when the source needs a (free) developer key to work.
  bool get needsKey => false;

  /// Where to get that key.
  String? get keyUrl => null;

  /// Popular / trending tracks for the browse page.
  Future<List<Song>> trending({int limit = 30});

  /// Free-text search.
  Future<List<Song>> search(String query, {int limit = 30});

  /// Resolves the playable stream for one of this source's songs.
  Future<FreeStream?> stream(Song song);

  /// Builds the Song id for a native id.
  String songId(String nativeId) => '$id:$nativeId';

  /// Strips the prefix from a Song id.
  String nativeId(Song song) => song.id.substring(id.length + 1);
}
