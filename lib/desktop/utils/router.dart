// ZenMusic Desktop — ported from Echo Music (GPL-3.0). ZenMusic remains GPL-3.0.
// PORT: /browse, /chip and /chart_details are top-level stubs for R7e; Echo
// nests chip/browse/chart_details under the home branch — that nesting
// returns with the real pages at R8. Library/settings sub-routes at R8+.
// (Playback harness /smoke removed post-R6b.)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:zenmusic/desktop/screens/home/home_page.dart';
import 'package:zenmusic/desktop/screens/search/search_page.dart';
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
            return CustomTransitionPage(
              key: state.pageKey,
              child: const PlayerStub(),
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
          builder: (context, state) => const BrowseStub(),
        ),
        GoRoute(
          path: '/chip',
          builder: (context, state) => const ChipStub(),
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