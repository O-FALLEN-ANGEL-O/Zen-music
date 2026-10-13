// ZenMusic Desktop — ported from Echo Music (GPL-3.0), screens/settings/settings_page.dart.
// Echo Music is Copyright (C) the Echo Music authors; this port and ZenMusic
// remain GPL-3.0 (https://github.com/vorlon-dev/Zen-music).
// PORT DEVIATIONS: l10n -> literals; "Support" tile DROPPED (Echo donation
// URL — restore with a Zen-owned link if desired); "Check for update" ->
// opens the ZenMusic GitHub releases page (UpdateService not ported);
// battery tile verbatim (Android-gated — auto-hidden on Windows).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:zenmusic/desktop/screens/settings/cubit/settings_system_cubit.dart';
import 'package:zenmusic/desktop/screens/settings/widgets/color_icon.dart';
import 'package:zenmusic/desktop/screens/settings/widgets/setting_item.dart';
import 'package:zenmusic/desktop/themes/text_styles.dart';
import 'package:zenmusic/desktop/utils/adaptive_widgets/adaptive_widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SettingsSystemCubit()..load(),
      child: AdaptiveScaffold(
        appBar: AdaptiveAppBar(
          title: Text(
            'Settings',
            style: appBarTitleStyle(),
          ),
          automaticallyImplyLeading: false,
        ),
        body: BlocBuilder<SettingsSystemCubit, SettingsSystemState>(
          builder: (context, state) {
            final bool? batteryDisabled = state is SettingsSystemLoaded
                ? state.isBatteryOptimizationDisabled
                : null;

            return Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    if (Platform.isAndroid && batteryDisabled != true)
                      _BatteryWarningTile(),
                    const GroupTitle(title: "General"),
                    SettingTile(
                      title: "Player",
                      leading: const Icon(Icons.play_arrow_rounded),
                      isFirst: true,
                      isLast: true,
                      onTap: () => context.go('/settings/player'),
                    ),
                    const GroupTitle(title: "Services"),
                    SettingTile(
                      title: "Youtube Music",
                      leading: const Icon(Icons.play_circle_fill),
                      isFirst: true,
                      isLast: true,
                      onTap: () => context.go('/settings/services/ytmusic'),
                    ),
                    const GroupTitle(title: "Storage & Privacy"),
                    SettingTile(
                      title: "Backup and storage",
                      leading: const Icon(
                        Icons.cloud_upload_rounded,
                      ),
                      isFirst: true,
                      onTap: () => context.go(
                        '/settings/backup_storage',
                      ),
                    ),
                    SettingTile(
                      title: "Privacy",
                      leading: const Icon(Icons.privacy_tip),
                      isLast: true,
                      onTap: () => context.go('/settings/privacy'),
                    ),
                    const GroupTitle(title: "Updates & About"),
                    SettingTile(
                      title: 'About',
                      leading: const Icon(Icons.info_rounded),
                      isFirst: true,
                      onTap: () => context.go('/settings/about'),
                    ),
                    SettingTile(
                      title: 'Check For Update',
                      leading: const Icon(Icons.update_rounded),
                      onTap: () async {
                        // PORT: UpdateService not ported — releases page is
                        // where desktop builds live.
                        final uri = Uri.parse(
                            'https://github.com/vorlon-dev/Zen-music/releases');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                    const SizedBox(height: 100), // Extra padding for miniplayer
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BatteryWarningTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: Theme.of(context).colorScheme.errorContainer.withAlpha(200),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
      ),
      leading: const ColorIcon(
        icon: Icons.battery_alert,
        color: Colors.red,
      ),
      title: Text(
        'Battery Optimisation',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      subtitle: Text(
        'Disable battery optimisation so playback continues in the background.',
        style: tinyTextStyle(context).copyWith(
          color: Theme.of(context)
              .colorScheme
              .onErrorContainer
              .withValues(alpha: 0.7),
        ),
      ),
      onTap: () {
        context.read<SettingsSystemCubit>().requestBatteryOptimizationIgnore();
      },
    );
  }
}