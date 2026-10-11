import 'package:flutter/material.dart';
import 'lw_nav_dock.dart';

/// FloatingNavDefaults port: the dock overlays content (not a Scaffold
/// bottomBar), so scrollable pages must reserve this much bottom room.
class LwShellDefaults {
  LwShellDefaults._();
  static const double contentBottomPadding = 112;
}

/// MainShell port: swipeable PageView + overlay floating dock. Selection
/// updates immediately on tap (no mid-scroll flicker), syncs from the
/// settled page on swipe — same contract as MainShell.kt's comment block.
class LwShell extends StatefulWidget {
  const LwShell({super.key, required this.tabs, required this.pages});
  final List<LwNavItemSpec> tabs;
  final List<Widget> pages;

  @override
  State<LwShell> createState() => _LwShellState();
}

class _LwShellState extends State<LwShell> {
  late final PageController _pager;
  late int _selected;

  @override
  void initState() {
    super.initState();
    _pager = PageController();
    _selected = _pager.initialPage.clamp(0, widget.tabs.length - 1);
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == _selected) return;
    setState(() => _selected = index);
    _pager.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.tabs.length == widget.pages.length);
    return Scaffold(
      backgroundColor: const Color(0xFF0B0A08),
      body: Stack(
        children: [
          PageView(
            controller: _pager,
            onPageChanged: (i) {
              if (i != _selected) setState(() => _selected = i);
            },
            children: [
              for (final page in widget.pages)
                MediaQuery.removePadding(
                  context: context,
                  removeBottom: true,
                  child: page,
                ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: LwNavDock(
              tabs: widget.tabs,
              selectedIndex: _selected,
              onSelect: _select,
            ),
          ),
        ],
      ),
    );
  }
}