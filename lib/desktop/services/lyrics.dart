// ZenMusic Desktop — ported from Echo Music (GPL-3.0), services/lyrics.dart.
// Echo Music is Copyright (C) the Echo Music authors; this port and ZenMusic
// remain GPL-3.0 (https://github.com/vorlon-dev/Zen-music).

import '../models/lyrics_model.dart';
import 'lrcnet_api.dart';

class LyricsService {
  Future<Lyrics> getLyrics({
    required String title,
    String? artist,
    String? album,
    String? duration,
  }) async {
    // Basic caching could be added here if needed, but for now delegating to API
    // which has some internal logic or just fetches.
    return await getLRCNetAPILyrics(
      title,
      artist: artist,
      album: album,
      duration: duration,
    );
  }
}