// ZenMusic Desktop — ported from Echo Music (GPL-3.0). ZenMusic remains GPL-3.0.

import 'package:flutter/material.dart';

class AdaptiveScaffold extends StatelessWidget {
  /// Creates a new [AdaptiveScaffold].
  const AdaptiveScaffold({this.body, this.appBar, super.key});

  /// The primary content of the [AdaptiveScaffold].
  final Widget? body;

  /// An app bar to display at the top of the [AdaptiveScaffold].
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: key,
      appBar: appBar,
      body: body,
    );
  }
}