// ZenMusic Desktop — ported from Echo Music (GPL-3.0). ZenMusic remains GPL-3.0.
// PORT: /browse and /chip are TOP-LEVEL (Echo nests them under home — marked
// deviation, matches the R4 router shape). /chart_details stays stubbed until
// its screen is pasted. Library/settings sub-routes at R8e. /player = real
// page (R8d).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:zenmusic/desktop/screens/home/home_page.dart';
import 'package:zenmusic/desktop/screens/search/search_page.dart';
import 'package:zenmusic/desktop/screens/player/player_page.dart';
import 'package:zenmusic/desktop/screens/browse/browse_page.dart';
import 'package:zenmusic/desktop/screens/chip/chip_page.dart';
import 'package:zenmusic/desktop/screens/stubs.dart';
import 'package:zenmusic/desktop/screens/shell/app_shell.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => child,
      routes: [
        StatefulShellRoute(
          branches: branches,
          builder: (context, state, navigationShell) => AppShell(
            navigationShell: navigationShell,
          ),
          navigatorContainerBuilder: (context, navigationShell, children) =>
              MyPageView(
                currentIndex: navigationShell.currentIndex,
                children: children,
              ),
        ),
        GoRoute(
          path: '/player',
          pageBuilder: (context, state) {
            final videoId = state.extra as String?;
            return CustomTransitionPage(
              key: state.pageKey,
              child: PlayerPage(videoId: videoId),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(0.0, 1.0);
                const end = Offset.zero;
                final curve = Curves.ease;
                final tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));
                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
            );
          },
        ),
        GoRoute(
          path: '/browse',
          builder: (context, state) {
            final args = state.extra as Map<String, dynamic>? ?? {};
            return BrowsePage(
              endpoint: args['endpoint'] as Map<String, dynamic> ?? {},
              isMore: args['isMore'] as bool? ?? false,
            );
          },
        ),
        GoRoute(
          path: '/chip',
          builder: (context, state) {
            final args = state.extra as Map<String, dynamic>? ?? {};
            return ChipPage(
              title: args['title'] ?? '',
              endpoint: args['endpoint'] as Map<String, dynamic>? ?? {},
            );
          },
        ),
        GoRoute(
          path: '/chart_details',
          builder: (context, state) => const ChartDetailsStub(),
        ),
      ],
    ),
  ],
);

List<StatefulShellBranch> branches = [
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchPage(),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/saved',
        builder: (context, state) => const SavedStub(),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsStub(),
      ),
    ],
  ),
];

class MyPageView extends StatefulWidget {
  final int currentIndex;
  final List<Widget> children;

  const MyPageView(
      {super.key, required this.currentIndex, required this.children});

  @override
  MyPageViewViewState createState() => MyPageViewViewState();
}

class MyPageViewViewState extends State<MyPageView> {
  final PageController controller = PageController(initialPage: 0);

  @override
  void didUpdateWidget(covariant MyPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      controller.animateToPage(widget.currentIndex,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      scrollDirection: Axis.vertical,
      physics: const NeverScrollableScrollPhysics(),
      controller: controller,
      children: widget.children,
    );
  }
}