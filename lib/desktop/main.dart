// ZenMusic Desktop — entry point. ALWAYS run/build with an explicit target:
//   flutter run -d windows -t lib/desktop/main.dart
//   flutter build windows -t lib/desktop/main.dart
// NEVER use the default entry on Windows: lib/main.dart is the MOBILE entry
// and crashes by design (audio_service has no Windows implementation).
//
// Ported from Echo Music (GPL-3.0). Echo Music is Copyright (C) its authors;
// this port and ZenMusic remain GPL-3.0.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:zenmusic/desktop/core/app_theme.dart';
import 'package:zenmusic/desktop/services/download_manager.dart';
import 'package:zenmusic/desktop/services/file_storage.dart';
import 'package:zenmusic/desktop/services/library.dart';
import 'package:zenmusic/desktop/services/lyrics.dart';
import 'package:zenmusic/desktop/services/media_player.dart';
import 'package:zenmusic/desktop/services/settings_manager.dart';
import 'package:zenmusic/desktop/services/yt_audio_stream.dart';
import 'package:zenmusic/desktop/utils/router.dart';
import 'package:zenmusic/desktop/ytmusic/ytmusic.dart';
import 'package:zenmusic/desktop/ytmusic/modals/yt_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initialiseHive();

  // PORT: Echo's desktop media_kit init, verbatim (title rebranded).
  // JustAudioBackground.init is intentionally NOT called — recorded crash path.
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    JustAudioMediaKit.ensureInitialized();
    JustAudioMediaKit.bufferSize = 8 * 1024 * 1024;
    JustAudioMediaKit.title = 'ZenMusic';
    JustAudioMediaKit.prefetchPlaylist = true;
    JustAudioMediaKit.pitch = true;
  }

  // PORT: Echo calls FileStorage.initialise() here — creates the
  // Downloads/ZenMusic tree (Music + Back Up dirs) before any consumer.
  await FileStorage.initialise();

  // PORT: Echo's YTMusic construction, verbatim — Hive-backed visitorData.
  // First sendRequest with empty visitorData triggers resetVisitorId(), which
  // fetches a real VISITOR_DATA from music.youtube.com and persists it here
  // via onIdUpdate.
  String? visitorId = await Hive.box('SETTINGS').get('VISITOR_ID');
  YTMusic ytMusic = YTMusic(
    config: YTConfig(
        visitorData: visitorId ?? '', language: 'en', location: 'IN'),
    onIdUpdate: (visitorId) async {
      await Hive.box('SETTINGS').put('VISITOR_ID', visitorId);
    },
  );

  final settingsManager = SettingsManager();
  GetIt.I.registerSingleton<SettingsManager>(settingsManager);

  // PORT: local audio stream server.
  final String audioStreamUrl = await createAudioStreamServer();
  GetIt.I.registerSingleton<String>(audioStreamUrl,
      instanceName: 'audioStreamUrl');

  final MediaPlayer mediaPlayer = MediaPlayer();
  GetIt.I.registerSingleton<MediaPlayer>(mediaPlayer);

  final libraryService = LibraryService();
  GetIt.I.registerSingleton<LibraryService>(libraryService);

  final fileStorage = FileStorage();
  GetIt.I.registerSingleton<FileStorage>(fileStorage);

  GetIt.I.registerSingleton<DownloadManager>(DownloadManager());

  GetIt.I.registerSingleton<LyricsService>(LyricsService());

  GetIt.I.registerSingleton<YTMusic>(ytMusic);

  // PORT: Echo's panelKey GlobalKey is deferred with the screens that
  // consume it. ImportService is constructed on-demand in the import modal
  // (Echo pattern, unchanged).

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => settingsManager),
        ChangeNotifierProvider(create: (_) => mediaPlayer),
        ChangeNotifierProvider(create: (_) => libraryService),
      ],
      child: const ZenDesktopApp(),
    ),
  );
}

class ZenDesktopApp extends StatelessWidget {
  const ZenDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
      },
      child: MaterialApp.router(
        title: 'ZenMusic Desktop',
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        themeMode: context.watch<SettingsManager>().themeMode,
        theme: AppTheme.light(primary: Colors.black),
        darkTheme: AppTheme.dark(primary: Colors.white),
      ),
    );
  }
}

Future<void> initialiseHive() async {
  String? applicationDataDirectoryPath;
  if (Platform.isWindows || Platform.isLinux) {
    applicationDataDirectoryPath =
    "${(await getApplicationSupportDirectory()).path}/database";
  }
  await Hive.initFlutter(applicationDataDirectoryPath);
  await Hive.openBox('SETTINGS');
  await Hive.openBox('LIBRARY');
  await Hive.openBox('SEARCH_HISTORY');
  await Hive.openBox('SONG_HISTORY');
  await Hive.openBox('FAVOURITES');
  await Hive.openBox('DOWNLOADS');
}