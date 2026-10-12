// ZenMusic Desktop — ported from Echo Music (GPL-3.0). ZenMusic remains GPL-3.0.
// PORT DEVIATIONS: unused imports dropped (dart:ui, bottom_modals, listtile);
// the two sequenceStateStream StreamBuilders are vestigial upstream — kept
// verbatim by port policy.

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';

import 'package:zenmusic/desktop/services/media_player.dart';
import 'package:zenmusic/desktop/utils/adaptive_widgets/buttons.dart';
import 'package:zenmusic/desktop/utils/adaptive_widgets/progress_ring.dart';
import 'package:zenmusic/desktop/utils/song_thumbnail.dart';

class BottomPlayer extends StatefulWidget {
  const BottomPlayer({super.key});

  @override
  State<BottomPlayer> createState() => _BottomPlayerState();
}

class _BottomPlayerState extends State<BottomPlayer> {
  Color? backgroundColor;

  void updateBackgroundColor(ImageProvider image) async {
    final palette = await PaletteGenerator.fromImageProvider(
      image,
      maximumColorCount: 20,
    );
    if (mounted) {
      if (palette.dominantColor != null &&
          backgroundColor != palette.dominantColor!.color) {
        setState(() {
          backgroundColor = palette.dominantColor!.color;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaPlayer = GetIt.I<MediaPlayer>();
    return StreamBuilder(
        stream: mediaPlayer.currentTrackStream,
        builder: (
            context,
            snapshot,
            ) {
          final data = snapshot.data;
          final currentSong = data?.currentItem;
          if (currentSong == null) {
            return const SizedBox();
          }
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: GestureDetector(
              onTap: () {
                context.push('/player');
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: (backgroundColor ?? const Color(0xFF202020)).withAlpha(255),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(50),
                                child: SongThumbnail(
                                  song: currentSong.extras!,
                                  dp: MediaQuery.of(context)
                                      .devicePixelRatio,
                                  height: 40,
                                  width: 40,
                                  fit: BoxFit.fill,
                                  onImageReady: updateBackgroundColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentSong.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (currentSong.artist != null ||
                                        currentSong.extras!['subtitle'] !=
                                            null)
                                      Text(
                                        currentSong.artist ??
                                            currentSong
                                                .extras!['subtitle'],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white
                                              .withValues(alpha: 0.8),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StreamBuilder(
                              stream: context
                                  .watch<MediaPlayer>()
                                  .player
                                  .sequenceStateStream,
                              builder: (context, snapshot) {
                                return AdaptiveIconButton(
                                  onPressed: () {
                                    GetIt.I<MediaPlayer>()
                                        .player
                                        .seekToPrevious();
                                  },
                                  icon: const Icon(
                                    Icons.skip_previous,
                                    size: 24,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 4),
                            ValueListenableBuilder(
                              valueListenable:
                              GetIt.I<MediaPlayer>().buttonState,
                              builder: (context, buttonState, child) {
                                return (buttonState == ButtonState.loading)
                                    ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: AdaptiveProgressRing(),
                                )
                                    : AdaptiveIconButton(
                                  onPressed: () {
                                    GetIt.I<MediaPlayer>()
                                        .player
                                        .playing
                                        ? GetIt.I<MediaPlayer>()
                                        .player
                                        .pause()
                                        : GetIt.I<MediaPlayer>()
                                        .player
                                        .play();
                                  },
                                  icon: Icon(
                                    buttonState ==
                                        ButtonState.playing
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    size: 30,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 4),
                            StreamBuilder(
                              stream: context
                                  .watch<MediaPlayer>()
                                  .player
                                  .sequenceStateStream,
                              builder: (context, snapshot) {
                                return AdaptiveIconButton(
                                  onPressed: () {
                                    GetIt.I<MediaPlayer>()
                                        .player
                                        .seekToNext();
                                  },
                                  icon: const Icon(
                                    Icons.skip_next,
                                    size: 24,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        });
  }
}