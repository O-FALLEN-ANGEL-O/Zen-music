// ZenMusic Desktop — ported from Echo Music (GPL-3.0), ytmusic/modals/yt_config.dart.
// Echo Music is Copyright (C) the Echo Music authors; this port and ZenMusic
// remain GPL-3.0 (https://github.com/vorlon-dev/Zen-music).

class YTConfig {
  YTConfig({
    required this.visitorData,
    required this.language,
    required this.location,
  });
  String visitorData;
  String language;
  String location;

  YTConfig copyWith({
    String? visitorData,
    String? language,
    String? location,
  }) =>
      YTConfig(
        visitorData: visitorData ?? this.visitorData,
        language: language ?? this.language,
        location: location ?? this.location,
      );
}