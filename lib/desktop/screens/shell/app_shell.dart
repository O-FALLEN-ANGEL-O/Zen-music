// ZenMusic Desktop — ported from Echo Music (GPL-3.0). ZenMusic remains GPL-3.0.
// PORT DEVIATIONS: S.of(...) l10n -> English literals (v1); UpdateService
// auto-check deferred (no desktop update service yet); unused blur import
// dropped (no Blur usage in upstream build method).

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'widgets/bottom_player.dart';
class AppShell extends StatefulWidget {
  const AppShell({
    Key? key,
    required this.navigationShell,
  }) : super(key: key ?? const ValueKey('AppShell'));
  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // PORT: Echo calls UpdateService.autoCheck(context) here. Deferred — the
  // desktop update service is a later arc.
  // void initState() { ... } removed with it; state class kept for parity.

  void _goBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Row(
            children: [
              if (screenWidth >= 450)
                NavigationRail(
                  extended: true,
                  backgroundColor: Colors.transparent,
                  groupAlignment: 0.0,
                  destinations: [
                    NavigationRailDestination(
                      selectedIcon: const Icon(CupertinoIcons.music_house_fill,
                          color: Colors.black),
                      icon: const Icon(CupertinoIcons.music_house),
                      label: const Text('Home'),
                    ),
                    NavigationRailDestination(
                      selectedIcon:
                      const Icon(CupertinoIcons.search, color: Colors.black),
                      icon: const Icon(CupertinoIcons.search),
                      label: const Text('Search'),
                    ),
                    NavigationRailDestination(
                        selectedIcon: const Icon(Icons.library_music_outlined,
                            color: Colors.black),
                        icon: const Icon(Icons.library_music_outlined),
                        label: const Text('Saved')),
                    NavigationRailDestination(
                      selectedIcon: const Icon(CupertinoIcons.gear_alt_fill,
                          color: Colors.black),
                      icon: const Icon(CupertinoIcons.gear_alt),
                      label: const Text('Settings'),
                    )
                  ],
                  selectedIndex: widget.navigationShell.currentIndex,
                  onDestinationSelected: _goBranch,
                ),
              Expanded(
                child: widget.navigationShell,
              ),
            ],
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: BottomPlayer(),
          ),
        ],
      ),
      bottomNavigationBar: screenWidth < 450
          ? NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        destinations: const [
          NavigationDestination(
            selectedIcon:
            Icon(CupertinoIcons.music_house_fill, color: Colors.black),
            icon: Icon(CupertinoIcons.music_house),
            label: 'Home',
          ),
          NavigationDestination(
            selectedIcon: Icon(CupertinoIcons.search, color: Colors.black),
            icon: Icon(CupertinoIcons.search),
            label: 'Search',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.library_music, color: Colors.black),
            icon: Icon(Icons.library_music_outlined),
            label: 'Saved',
          ),
          NavigationDestination(
            selectedIcon:
            Icon(CupertinoIcons.settings_solid, color: Colors.black),
            icon: Icon(CupertinoIcons.settings),
            label: 'Settings',
          ),
        ],
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        onDestinationSelected: _goBranch,
      )
          : null,
    );
  }
}