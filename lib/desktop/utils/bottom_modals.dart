// ZenMusic Desktop — R7c STUB.
// Echo's full bottom_modals.dart ships at R8, together with LibraryService,
// DownloadManager, ImportService/ImportDialog and the equalizer page it
// depends on. Until then this stub carries the exact API surface used by
// shipped screens; every call is a visible no-op so nothing fails silently.

import 'package:flutter/material.dart';

class Modals {
  static void showSongBottomModal(BuildContext context, Map song) =>
      _todo(context, 'Song options');

  static void showPlaylistBottomModal(BuildContext context, Map playlist) =>
      _todo(context, 'Playlist options');

  static Future<T?> showGlassWindow<T>({
    required BuildContext context,
    required Widget child,
  }) {
    return showDialog<T>(
      context: context,
      builder: (context) => AlertDialog(content: child),
    );
  }

  static void _todo(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what - available in a later update')),
    );
  }
}