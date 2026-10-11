import 'package:flutter/material.dart';
import 'lw_artwork.dart';
import 'lw_motion.dart';

/// FeedSectionHeader port: 20sp ExtraBold title, 12sp subtitle, optional
/// stadium action pill (13h padding, 15dp icon, 34dp height) + shuffle
/// circle. All pill/circle shapes use stadium or fixed-size circles so
/// the content always centers.
class LwFeedSectionHeader extends StatelessWidget {
  const LwFeedSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionText,
    this.actionIcon,
    this.onAction,
    this.onShuffle,
  });

  final String title;
  final String? subtitle;
  final String? actionText;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: scheme.onSurface,
                        )),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                            scheme.onSurfaceVariant.withValues(alpha: 0.8),
                          )),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (onShuffle != null)
            GestureDetector(
              onTap: onShuffle,
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                  scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                ),
                child: Icon(Icons.shuffle_rounded,
                    size: 16, color: scheme.onSurfaceVariant),
              ),
            ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onAction,
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  color: scheme.primaryContainer.withValues(alpha: 0.55),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (actionIcon != null) ...[
                    Icon(actionIcon, size: 15, color: scheme.primary),
                    const SizedBox(width: 5),
                  ],
                  Text(actionText!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      )),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The section container every feed shelf sits in:
/// r24 surfaceContainerHigh@0.5, 16h/8v outer, 12v inner.
class LwSectionCard extends StatelessWidget {
  const LwSectionCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHigh
              .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: child,
      ),
    );
  }
}

/// FeedMediaCard port: 148dp square, r18, badge circle (NEW/ago) top-left,
/// 38dp play circle bottom-right, bold 14 title + 12 subtitle below.
/// Artwork renders through LwArtwork (squareArt upgrade ladder).
class LwMediaCard extends StatelessWidget {
  const LwMediaCard({
    super.key,
    required this.artworkUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onPlay,
    this.badgeText,
    this.fallbackIcon = Icons.music_note_rounded,
    this.size = 148,
    this.songId = '',
  });

  final String songId;
  final String artworkUrl;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final String? badgeText;
  final IconData fallbackIcon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LwPressScale(
      targetScale: 0.96,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: size,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: Stack(
                  children: [
                    LwArtwork(
                      songId: songId,
                      artworkUrl: artworkUrl,
                      fallbackIcon: fallbackIcon,
                      size: size,
                      radius: 18,
                    ),
                    if (badgeText != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.primary,
                          ),
                          child: Text(badgeText!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: scheme.onPrimary,
                              )),
                        ),
                      ),
                    if (onPlay != null)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: onPlay,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.primaryContainer,
                              boxShadow: const [
                                BoxShadow(blurRadius: 6, color: Colors.black45)
                              ],
                            ),
                            child: Icon(Icons.play_arrow_rounded,
                                size: 20, color: scheme.onPrimaryContainer),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface)),
              ),
              const SizedBox(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color:
                        scheme.onSurfaceVariant.withValues(alpha: 0.8))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}