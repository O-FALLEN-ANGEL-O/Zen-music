// ZenMusic Desktop — ported from Echo Music (GPL-3.0), screens/settings/player/player_settings_page.dart.
// Echo Music is Copyright (C) the Echo Music authors; this port and ZenMusic
// remain GPL-3.0 (https://github.com/vorlon-dev/Zen-music).
// PORT: l10n -> literals. NOTE (verbatim): skip-silence is hidden on Windows
// upstream (ExoPlayer-only effect) — on desktop this page renders appbar-only
// until desktop EQ/effects land.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:zenmusic/desktop/screens/settings/player/cubit/player_settings_cubit.dart';
import 'package:zenmusic/desktop/screens/settings/widgets/setting_item.dart';

class PlayerSettingsPage extends StatelessWidget {
  const PlayerSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PlayerSettingsCubit(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Player"),
        ),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: BlocBuilder<PlayerSettingsCubit, PlayerSettingsState>(
              builder: (context, state) {
                final s = state as PlayerSettingsLoaded;

                return ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    /// Skip silence
                    if (!Platform.isWindows)
                      SettingSwitchTile(
                        title: 'Skip Silence',
                        leading: const Icon(
                          Icons.fast_forward,
                        ),
                        value: s.skipSilence,
                        onChanged: (value) {
                          context
                              .read<PlayerSettingsCubit>()
                              .setSkipSilence(value);
                        },
                        isFirst: !Platform.isAndroid,
                        isLast: true,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}