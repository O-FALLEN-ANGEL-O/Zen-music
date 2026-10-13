import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/spotify_theme.dart';

class SpotifyNavItem {
  const SpotifyNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Full-width bottom bar in the Spotify style: content fades into a
/// solid band behind the icons, selected item is filled + bright,
/// others outlined + dimmed. No pill, no glass.
class SpotifyNavBar extends StatelessWidget {
  const SpotifyNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<SpotifyNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bg = SpotifyColors.background;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            bg.withValues(alpha: 0.0),
            bg.withValues(alpha: 0.92),
            bg,
          ],
          stops: const [0.0, 0.35, 1.0],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: 18, bottom: bottomInset + 6),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _NavButton(
                  item: items[i],
                  selected: i == selectedIndex,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(i);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final SpotifyNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? SpotifyColors.textPrimary : SpotifyColors.textSecondary;
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: SizedBox(
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 160),
                child: Icon(
                  selected ? item.selectedIcon : item.icon,
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
