import 'package:flutter/material.dart';

/// Seek-overlay chip port: r32 outer on the screen edge / r72 inner,
/// 58% black, 52dp white@0.22 icon circle, ExtraBold seconds label.
class LwSeekChip extends StatelessWidget {
  const LwSeekChip({
    super.key,
    required this.seconds,
    required this.forward,
  });

  final int seconds;
  final bool forward;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      decoration: ShapeDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        shape: forward
            ? const RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(
                left: Radius.circular(72), right: Radius.circular(32)))
            : const RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(
                left: Radius.circular(32), right: Radius.circular(72))),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.22),
            ),
            child: Icon(
              forward
                  ? Icons.fast_forward_rounded
                  : Icons.fast_rewind_rounded,
              size: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${forward ? '+' : '-'}$seconds s',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}