// ZenMusic Desktop — ported from Echo Music (GPL-3.0), utils/add_history.dart.
// Echo Music is Copyright (C) the Echo Music authors; this port and ZenMusic
// remain GPL-3.0 (https://github.com/vorlon-dev/Zen-music).

import 'package:hive_flutter/hive_flutter.dart';

// PORT: upstream also calls GetIt.I<YTMusic>().addYoutubeHistory here.
// The YTMusic client is vendored at R5; that branch is commented until then.

Box _box = Hive.box('SETTINGS');

Future<void> addHistory(Map song) async {
  if (_box.get('PLAYBACK_HISTORY', defaultValue: true)) {
    await addLocalHistory(song);
  }
  // TODO(R5): personalised YouTube history — YTMusic client not vendored yet.
  // if (_box.get('PERSONALISED_CONTENT', defaultValue: true) &&
  //     song['status'] != 'DOWNLOADED') {
  //   GetIt.I<YTMusic>().addYoutubeHistory(song['videoId']);
  // }
}

Future<void> addLocalHistory(Map song) async {
  Box box = Hive.box('SONG_HISTORY');
  Map? oldState = box.get(song['videoId']);
  int timestamp = DateTime.now().millisecondsSinceEpoch;
  if (oldState != null) {
    await box.put(song['videoId'],
        {...oldState, 'plays': oldState['plays'] + 1, 'updatedAt': timestamp});
  } else {
    await box.put(song['videoId'],
        {...song, 'plays': 1, 'CreatedAt': timestamp, 'updatedAt': timestamp});
  }
}