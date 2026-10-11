import 'package:flutter/material.dart';

/// LaunchGate port: 88dp rounded-28 logo tile, name, loading line.
class LwSplash extends StatelessWidget {
  const LwSplash({super.key, this.appName = 'ZenMusic'});
  final String appName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0A08),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFF201C15),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(blurRadius: 10, color: Colors.black54),
                ],
              ),
              child: const Icon(Icons.music_note,
                  size: 44, color: Color(0xFFD6AD5B)),
            ),
            const SizedBox(height: 18),
            Text(appName,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF5F0E5))),
            const SizedBox(height: 20),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFB8A34C)),
            ),
          ],
        ),
      ),
    );
  }
}