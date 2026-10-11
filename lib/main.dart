import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'audio/zen_audio_handler.dart';
import 'models/song.dart';
import 'screens/home_screen.dart';
import 'services/diagnostics_service.dart';
import 'services/share_intent_service.dart';
import 'services/storage_service.dart';
import 'services/youtube_service.dart';
import 'theme/spotify_theme.dart';
import 'ui/lw/lw_nav_dock.dart';
import 'ui/lw/lw_shell.dart';
import 'ui/lw/lw_theme.dart';

late ZenAudioHandler audioHandler;
late StorageService storage;

/// Global navigator key — used by the share-intent service to push the
/// video watch page when a YouTube link is shared into the app.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// UI-arc experiment flag: mounts the LastWave-port shell (floating glass
/// dock + swipeable pages) instead of the stock home container. Compile-
/// time on purpose — flip, rebuild, compare. false = untouched app.
const bool kUseLwShell = false;

/// UI-arc theme flag: swaps the hardcoded Spotify palette for the
/// LastWave hue-seeded dynamic scheme (seeded with the brass hex).
const bool kUseLwTheme = false;

void main() {
  // Diagnostics capture: run the app inside a zone whose print handler
  // feeds the in-app log viewer (print AND debugPrint both funnel here)
  // while still forwarding to logcat. CRITICAL ORDER: the ENTIRE body —
  // including WidgetsFlutterBinding.ensureInitialized() — must run
  // INSIDE the zone; the binding caches the zone at init time, so a
  // root-zone init makes every later print() escape the interceptor.
  // runZonedGuarded's onError additionally captures uncaught crashes.
  final spec = ZoneSpecification(
    print: (self, parent, zone, line) {
      DiagnosticsService.instance.capture(line);
      parent.print(zone, line);
    },
  );
  runZonedGuarded(
        () => _runApp(),
        (error, stack) => DiagnosticsService.instance.log('crash', '$error'),
    zoneSpecification: spec,
  );
}

Future<void> _runApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive storage
  storage = StorageService();
  await storage.init();

  // yt_downloader needs no initialization — video mode is always
  // available.
  YoutubeService.videoEnabled = true;

  // Full-screen app: hide the status bar and the 3-button nav bar
  // globally. Immersive-sticky re-hides them automatically after the
  // user swipes the edge, like the YouTube app.
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    // DARK THEME: light (white) icons on the dark background.
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Initialize audio service
  audioHandler = await AudioService.init(
    builder: () => ZenAudioHandler(storage: storage),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.zenmusic.audio',
      androidNotificationChannelName: 'ZenMusic Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(const ZenMusicApp());
}

class ZenMusicApp extends StatefulWidget {
  const ZenMusicApp({super.key});

  @override
  State<ZenMusicApp> createState() => _ZenMusicAppState();
}

class _ZenMusicAppState extends State<ZenMusicApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Share-target: YouTube links shared from other apps open the video
    // watch page directly. Registered after the first frame so the
    // navigator exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = navigatorKey.currentState;
      if (nav != null) {
        ShareIntentService.instance.init(nav);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ShareIntentService.instance.dispose();
    super.dispose();
  }

  // Re-assert immersive mode whenever the app resumes — the system can
  // restore system bars after dialogs, permission prompts, or the
  // in-app APK installer opens over us.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PlayerController(),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'ZenMusic',
        debugShowCheckedModeBanner: false,
        theme: kUseLwTheme ? LwThemes.dark() : SpotifyTheme.dark(),
        home: kUseLwShell ? const _LwShellHome() : const HomeScreen(),
      ),
    );
  }
}

/// Flag-gated shell preview: three placeholder pages so the dock's pill
/// morph, tab selection sync and page swipes can be felt in isolation.
/// (HomeScreen docking into page 0 is a later wiring round — it brings
/// its own Scaffold/nav and needs the padding contract checked first.)
class _LwShellHome extends StatelessWidget {
  const _LwShellHome();

  @override
  Widget build(BuildContext context) {
    return LwShell(
      tabs: const [
        LwNavItemSpec(label: 'Home', icon: Icons.home_rounded),
        LwNavItemSpec(label: 'Stats', icon: Icons.leaderboard_rounded),
        LwNavItemSpec(label: 'Playlists', icon: Icons.queue_music_rounded),
      ],
      pages: const [
        _PlaceholderShellPage(title: 'Home'),
        _PlaceholderShellPage(title: 'Stats'),
        _PlaceholderShellPage(title: 'Playlists'),
      ],
    );
  }
}

class _PlaceholderShellPage extends StatelessWidget {
  const _PlaceholderShellPage({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class PlayerController extends ChangeNotifier {
  Song? currentSong;
  bool isPlaying = false;

  PlayerController() {
    audioHandler.currentSongStream.listen((song) {
      currentSong = song;
      notifyListeners();
    });
    audioHandler.playingStream.listen((playing) {
      isPlaying = playing;
      notifyListeners();
    });
  }
}