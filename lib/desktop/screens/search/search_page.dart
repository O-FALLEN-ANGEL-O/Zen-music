// ZenMusic Desktop — ported from Echo Music (GPL-3.0), screens/search/search_page.dart.
// Echo Music is Copyright (C) the Echo Music authors; this port and ZenMusic
// remain GPL-3.0 (https://github.com/vorlon-dev/Zen-music).
// PORT DEVIATIONS: sl() -> GetIt.I<YTMusic>(); l10n -> 'Search'; TypeAheadField
// REPLACED with in-tree SearchSuggestField — flutter_typeahead transitively
// pulls flutter_keyboard_visibility (android-31, breaks the mobile AAR check
// on modern compileSdk). Behavior matched: suggestions overlay under the
// field (targetAnchor/followerAnchor), history icon for TEXT entries, tap =
// submit. Upstream VisualDensity unchanged elsewhere.

import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:zenmusic/desktop/screens/search/cubit/search_cubit.dart';
import 'package:zenmusic/desktop/ytmusic/ytmusic.dart';
import 'package:zenmusic/desktop/services/media_player.dart';
import 'package:zenmusic/desktop/utils/internet_guard.dart';
import 'package:zenmusic/desktop/utils/adaptive_widgets/adaptive_widgets.dart';
import 'package:zenmusic/desktop/utils/bottom_modals.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key, this.endpoint, this.isMore = false});
  final Map<String, dynamic>? endpoint;
  final bool isMore;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SearchCubit(GetIt.I<YTMusic>(), endpoint: endpoint),
      child: _SearchPage(
        title: endpoint?['query'],
        isMore: isMore,
      ),
    );
  }
}

class _SearchPage extends StatefulWidget {
  const _SearchPage({this.title, this.isMore = false});
  final String? title;
  final bool isMore;

  @override
  State<_SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<_SearchPage> {
  late ScrollController _scrollController;
  TextEditingController? _textEditingController;
  FocusNode? _focusNode;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    _focusNode?.requestFocus();
  }

  Future<void> _scrollListener() async {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      await context.read<SearchCubit>().fetchNext();
    }
  }

  Future<void> onSubmit(String query) async {
    if (query.trim() == '') return;
    _focusNode?.unfocus();
    await context.read<SearchCubit>().search(query);
  }

  @override
  Widget build(BuildContext context) {
    return InternetGuard(
      onInternetLost: () {
        _focusNode?.unfocus();
      },
      onInternetRestored: () {
        if (widget.title != null) {
          context.read<SearchCubit>().search('');
        } else {
          _focusNode?.requestFocus();
        }
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const AdaptiveAppBar().preferredSize,
          child: LayoutBuilder(builder: (context, constraints) {
            return AdaptiveAppBar(
              title: widget.title != null
                  ? Text(widget.title!)
                  : Material(
                color: Colors.transparent,
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints:
                          const BoxConstraints(maxWidth: 350),
                          child: SearchSuggestField(
                            onSubmit: onSubmit,
                            onPick: (query) {
                              setState(() {
                                _textEditingController?.text = query;
                              });
                              onSubmit(query);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              automaticallyImplyLeading:
              (constraints.maxWidth <= 400) ? false : true,
            );
          }),
        ),
        body: BlocBuilder<SearchCubit, SearchState>(
          builder: (context, state) {
            switch (state) {
              case SearchLoading():
                return const SizedBox();
              case SearchError():
                return Center(
                  child: Text(state.message ?? ''),
                );
              case SearchSuccess():
                return SingleChildScrollView(
                  controller: _scrollController,
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          ...state.sections.map((section) {
                            if (Platform.isWindows) {
                              return Center(
                                child: Adaptivecard(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _SearchSectionItem(
                                      section: section, isMore: widget.isMore),
                                ),
                              );
                            }
                            return _SearchSectionItem(
                                section: section, isMore: widget.isMore);
                          }),
                          if (state.loadingMore)
                            const Center(child: ExpressiveLoadingIndicator())
                        ],
                      ),
                    ),
                  ),
                );
            }
          },
        ),
      ),
    );
  }
}

class _SearchSectionItem extends StatelessWidget {
  const _SearchSectionItem({required this.section, this.isMore = false});
  final Map<String, dynamic> section;
  final bool isMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (section['title'] != null && !isMore)
          AdaptiveListTile(
            contentPadding:
            const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            title: Text(
              section['title'],
              style:
              const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            trailing: section['trailing']?['text'] != null
                ? Padding(
              padding: EdgeInsets.symmetric(
                  vertical: Platform.isAndroid ? 12 : 0),
              child: AdaptiveOutlinedButton(
                  onPressed: () {
                    context.push(
                      '/search',
                      extra: {
                        'endpoint': section['trailing']['endpoint'],
                        'isMore': true,
                      },
                    );
                  },
                  child: Text(
                    section['trailing']['text'],
                    style: const TextStyle(fontSize: 12),
                  )),
            )
                : null,
          ),
        ...section['contents'].map((item) {
          return _SearchListTile(item: item);
        })
      ],
    );
  }
}

class _SearchListTile extends StatelessWidget {
  const _SearchListTile({
    required this.item,
  });
  final Map item;
  @override
  Widget build(BuildContext context) {
    return AdaptiveListTile(
      onSecondaryTap: () {
        if (item['videoId'] != null) {
          Modals.showSongBottomModal(context, item);
        } else if (item['endpoint'] != null) {
          Modals.showPlaylistBottomModal(context, item);
        }
      },
      onTap: () async {
        if (item['videoId'] != null) {
          await GetIt.I<MediaPlayer>().playSong(Map.from(item));
        } else if (item['endpoint'] != null && item['videoId'] == null) {
          context.push(
            '/browse',
            extra: {
              'endpoint': item['endpoint'],
            },
          );
        }
      },
      onLongPress: () {
        if (item['videoId'] != null) {
          Modals.showSongBottomModal(context, item);
        } else if (item['endpoint'] != null) {
          Modals.showPlaylistBottomModal(context, item);
        }
      },
      dense: false,
      title: Text(
        item['title'],
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: item['subtitle'] != null
          ? Text(
        item['subtitle'],
        maxLines: 1,
        style: TextStyle(color: Colors.grey.withValues(alpha: 0.9)),
        overflow: TextOverflow.ellipsis,
      )
          : null,
      leading: item['thumbnails'] != null && item['thumbnails'].isNotEmpty
          ? ClipRRect(
          borderRadius: BorderRadius.circular(
              ['ARTIST', 'PROFILE'].contains(item['type']) ? 30 : 3),
          child: Image.network(
            item['thumbnails'].first['url'],
            width: 50,
          ))
          : null,
      trailing: item['videoId'] == null && item['endpoint'] != null
          ? const Icon(CupertinoIcons.chevron_right)
          : null,
    );
  }
}

/// In-tree replacement for flutter_typeahead (deviation, see header).
/// Overlay suggestions under a rounded AdaptiveTextField; fetches via the
/// SearchCubit that owns this page (passed through a builder scope).
class SearchSuggestField extends StatefulWidget {
  const SearchSuggestField({
    super.key,
    required this.onSubmit,
    required this.onPick,
  });

  final ValueChanged<String> onSubmit;
  final ValueChanged<String> onPick;

  @override
  State<SearchSuggestField> createState() => _SearchSuggestFieldState();
}

class _SearchSuggestFieldState extends State<SearchSuggestField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  final ScrollController _scrollController = ScrollController();
  OverlayEntry? _overlay;
  List<Map<String, dynamic>> _suggestions = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _hideOverlay();
      } else {
        _showOverlay();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _hideOverlay();
    super.dispose();
  }

  void _hideOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _showOverlay() {
    if (_overlay != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    _overlay = OverlayEntry(builder: (context) {
      return Stack(
        children: [
          // Tap-catcher to dismiss
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _hideOverlay,
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomCenter,
            followerAnchor: Alignment.topCenter,
            offset: const Offset(0, 8),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints:
                const BoxConstraints(maxWidth: 350, maxHeight: 320),
                child: _buildSuggestionsList(),
              ),
            ),
          ),
        ],
      );
    });
    overlay.insert(_overlay!);
  }

  Future<void> _fetch(String query) async {
    final cubit = context.read<SearchCubit>();
    setState(() => _loading = true);
    try {
      final results = await cubit.getSuggestions(query);
      if (!mounted || !_focusNode.hasFocus) return;
      setState(() {
        _suggestions = results;
        _loading = false;
      });
      _overlay?.markNeedsBuild();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _overlay?.markNeedsBuild();
    }
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _fetch(query);
    });
  }

  Widget _buildSuggestionsList() {
    if (_loading && _suggestions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_suggestions.isEmpty) {
      return const SizedBox(height: 8, width: 350);
    }
    return ListView.builder(
      controller: _scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final item = _suggestions[index];
        if (item['type'] == 'TEXT') {
          return AdaptiveListTile(
            dense: true,
            leading: item['isHistory'] != null
                ? const Icon(Icons.history, size: 20)
                : null,
            title: Text(item['query'] ?? ''),
            onTap: () {
              _hideOverlay();
              _focusNode.unfocus();
              widget.onPick(item['query'] ?? '');
            },
          );
        }
        return AdaptiveListTile(
          dense: true,
          leading: (item['thumbnails'] as List?)?.isNotEmpty == true
              ? ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Image.network(
              item['thumbnails'].first['url'],
              width: 40,
              errorBuilder: (_, __, ___) =>
              const SizedBox(width: 40, height: 40),
            ),
          )
              : null,
          title: Text(item['title'] ?? '',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: item['subtitle'] != null
              ? Text(item['subtitle'],
              maxLines: 1, overflow: TextOverflow.ellipsis)
              : null,
          onTap: () {
            _hideOverlay();
            _focusNode.unfocus();
            if (item['videoId'] != null) {
              GetIt.I<MediaPlayer>().playSong(Map.from(item));
            } else if (item['endpoint'] != null) {
              context.push('/browse', extra: {'endpoint': item['endpoint']});
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: AdaptiveTextField(
        focusNode: _focusNode,
        controller: _controller,
        onChanged: _onChanged,
        onSubmitted: (q) {
          _hideOverlay();
          _focusNode.unfocus();
          widget.onSubmit(q);
        },
        keyboardType: TextInputType.text,
        maxLines: 1,
        autofocus: true,
        textInputAction: TextInputAction.search,
        fillColor: Colors.grey.withValues(alpha: 0.3),
        contentPadding:
        const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        borderRadius: BorderRadius.circular(35),
        hintText: 'Search',
        suffix: GestureDetector(
          onTap: () {
            setState(() {
              _controller.clear();
              _suggestions = [];
              _overlay?.markNeedsBuild();
            });
          },
          child: const Icon(CupertinoIcons.clear),
        ),
      ),
    );
  }
}