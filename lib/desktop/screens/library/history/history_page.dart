import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_swipe_action_cell/core/cell.dart';

import 'package:zenmusic/desktop/core/widgets/section_item.dart';
import 'package:zenmusic/desktop/screens/library/history/cubit/history_cubit.dart';
import 'package:zenmusic/desktop/utils/adaptive_widgets/adaptive_widgets.dart';
import 'package:zenmusic/desktop/utils/bottom_modals.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HistoryCubit()..load(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('History'),
          centerTitle: true,
        ),
        body: BlocBuilder<HistoryCubit, HistoryState>(
          builder: (context, state) {
            return switch (state) {
              HistoryLoading() => const Center(child: AdaptiveProgressRing()),
              HistoryError(:final message) => Center(child: Text(message)),
              HistoryLoaded(:final songs) => _HistoryBody(songs: songs),
            };
          },
        ),
      ),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({required this.songs});

  final List songs;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return const Center(
        child: Text("No History Found"),
      );
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1000),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ListView.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];

            return SwipeActionCell(
              backgroundColor: Colors.transparent,
              key: ObjectKey(song['videoId']),
              trailingActions: [
                SwipeAction(
                  title: 'Remove',
                  color: Colors.red,
                  onTap: (handler) async {
                    final confirm = await Modals.showConfirmBottomModal(
                      context,
                      message: 'Remove this song from your history?',
                      isDanger: true,
                    );

                    if (confirm && context.mounted) {
                      context.read<HistoryCubit>().remove(song['videoId']);
                    }
                  },
                ),
              ],
              child: SongTile(song: song),
            );
          },
        ),
      ),
    );
  }
}