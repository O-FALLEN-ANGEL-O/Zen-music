// ZenMusic Desktop — route stubs. /browse, /chip and /chart_details receive
// real Echo screens at R8; /player gets the real player page at R8.
// (Playback harness /smoke removed post-R6b — playback verified.)

import 'package:flutter/material.dart';

class _StubScaffold extends StatelessWidget {
  final String label;
  const _StubScaffold(this.label);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('$label — arriving in R8')),
    );
  }
}

class BrowseStub extends StatelessWidget {
  const BrowseStub({super.key});
  @override
  Widget build(BuildContext context) => const _StubScaffold('Artist/Album page');
}

class ChipStub extends StatelessWidget {
  const ChipStub({super.key});
  @override
  Widget build(BuildContext context) => const _StubScaffold('Chip page');
}

class ChartDetailsStub extends StatelessWidget {
  const ChartDetailsStub({super.key});
  @override
  Widget build(BuildContext context) => const _StubScaffold('Chart details');
}

class PlayerStub extends StatelessWidget {
  const PlayerStub({super.key});
  @override
  Widget build(BuildContext context) => const _StubScaffold('Player');
}

class SavedStub extends StatelessWidget {
  const SavedStub({super.key});
  @override
  Widget build(BuildContext context) => const _StubScaffold('Saved');
}

class SettingsStub extends StatelessWidget {
  const SettingsStub({super.key});
  @override
  Widget build(BuildContext context) => const _StubScaffold('Settings');
}