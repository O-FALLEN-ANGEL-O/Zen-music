import 'package:flutter/material.dart';
import 'lw_glass.dart';

/// The floating glass dock + companion FAB, geometry-faithful to
/// MainShell.kt: dock r32, inner pad 8h/8v, items h48 spacing 6,
/// icon 24, pill pad 18/12, FAB 56 with 10 gap, scale 0.6 morphs,
/// fades 180/120/90ms, clip-free expands. All pill content is
/// center-aligned both axes — the label can never drop below the
/// glass clip.
class LwNavDock extends StatelessWidget {
  const LwNavDock({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
    this.showCompanion = false,
    this.onCompanion,
  });

  final List<LwNavItemSpec> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool showCompanion;
  final VoidCallback? onCompanion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LwGlass.surface(
          radius: const BorderRadius.all(Radius.circular(32)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < tabs.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                _LwDockPill(
                  spec: tabs[i],
                  selected: selectedIndex == i,
                  onTap: () => onSelect(i),
                ),
              ],
            ],
          ),
        ),
        _LwCompanionFab(
          visible: showCompanion,
          color: scheme.primaryContainer,
          iconColor: scheme.onPrimaryContainer,
          onTap: onCompanion,
        ),
      ],
    );

    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 12 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Center(child: items),
      ),
    );
  }
}

class LwNavItemSpec {
  const LwNavItemSpec({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

class _LwDockPill extends StatelessWidget {
  const _LwDockPill({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final LwNavItemSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected
        ? (LwGlass.active
        ? scheme.primaryContainer.withValues(alpha: 0.28)
        : scheme.primaryContainer)
        : Colors.transparent;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    final padH = selected ? 18.0 : 12.0;

    return Semantics(
      button: true,
      selected: selected,
      label: spec.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 48,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: padH),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(spec.icon, size: 24, color: fg),
              // Label expands from the icon's side; AnimatedSize is
              // center-aligned by the parent container + Row, so the
              // text always sits on the pill's vertical midline and
              // can never paint below the glass clip.
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                child: selected
                    ? Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    spec.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: fg,
                      height: 1.0,
                    ),
                  ),
                )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LwCompanionFab extends StatelessWidget {
  const _LwCompanionFab({
    required this.visible,
    required this.color,
    required this.iconColor,
    this.onTap,
  });

  final bool visible;
  final Color color;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      alignment: Alignment.centerRight,
      child: visible
          ? Padding(
        padding: const EdgeInsets.only(left: 10),
        child: AnimatedScale(
          scale: visible ? 1 : 0.6,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          child: GestureDetector(
            onTap: onTap,
            child: LwGlass.surface(
              radius: const BorderRadius.all(Radius.circular(28)),
              fallbackColor: color,
              child: SizedBox(
                width: 56,
                height: 56,
                child: Icon(Icons.auto_awesome,
                    size: 24, color: iconColor),
              ),
            ),
          ),
        ),
      )
          : const SizedBox.shrink(),
    );
  }
}