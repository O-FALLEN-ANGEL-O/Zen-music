import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// ExpressiveHeader port. Full-bleed surfaceContainer header, bottom
/// corners rounded 24 (top corners square — it IS the screen top),
/// two cached radial accent glows painted behind content (primary at
/// 58%/46% r1.08·max a0.23; tertiary at 38%/78% r0.72·max a0.13 —
/// exact constants from drawGlowBackground), content padded for the
/// status bar while the surface extends behind it.
class LwExpressiveHeader extends StatelessWidget {
  const LwExpressiveHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
    this.titleIsLarge,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;
  /// null = derive: large (headlineMedium-equivalent) when no back button.
  final bool? titleIsLarge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final large = titleIsLarge ?? (onBack == null);
    final isLwPalette = true; // glow accent sources; see LwTheme note
    final glow = isLwPalette ? scheme.primary : scheme.primary;
    final glow2 = scheme.tertiary;

    return RepaintBoundary(
      child: Material(
        color: scheme.surfaceContainer,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        child: CustomPaint(
          foregroundPainter: _GlowPainter(
            glow: glow,
            glow2: glow2,
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),
          child: Padding(
            // Content pads for the status bar; the surface extends
            // behind it (callers never add top safe-area padding).
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.paddingOf(context).top + 2, 20, 10),
            child: Row(
              children: [
                if (onBack != null) ...[
                  _HeaderCircleButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: onBack!,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: large ? 28 : 22,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        actions[i],
                      ],
                    ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cached radial glows (drawWithCache equivalent: constants precomputed
/// in the painter; two full-width radial gradients, no per-frame cost
/// beyond the paint itself).
class _GlowPainter extends CustomPainter {
  _GlowPainter({
    required this.glow,
    required this.glow2,
    required this.isDark,
  });

  final Color glow;
  final Color glow2;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final maxDim = size.width > size.height ? size.width : size.height;
    // Secondary glow first (under), then primary — same draw order.
    final secondary = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.38, size.height * 0.78),
        (maxDim * 0.72).clamp(1.0, double.infinity),
        [
          glow2.withValues(alpha: 0.13),
          glow2.withValues(alpha: 0.045),
          glow2.withValues(alpha: 0),
        ],
      );
    canvas.drawPaint(secondary);
    final primary = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.58, size.height * 0.46),
        (maxDim * 1.08).clamp(1.0, double.infinity),
        [
          glow.withValues(alpha: 0.23),
          glow.withValues(alpha: 0.07),
          glow.withValues(alpha: 0),
        ],
      );
    canvas.drawPaint(primary);
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.glow != glow || old.glow2 != glow2 || old.isDark != isDark;
}

/// HeaderActionIcon port — small filled-tonal circular button, one
/// family across every header.
class LwHeaderAction extends StatelessWidget {
  const LwHeaderAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.surfaceContainerHighest,
        ),
        child: Icon(icon, size: 22, color: scheme.onSurfaceVariant),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.surfaceContainerHighest,
        ),
        child: Icon(icon, size: 22, color: scheme.onSurface),
      ),
    );
  }
}