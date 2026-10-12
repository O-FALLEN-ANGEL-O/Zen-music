// ZenMusic Desktop — ported from Echo Music (GPL-3.0), ytmusic/modals/user.dart.
// Echo Music is Copyright (C) the Echo Music authors; this port and ZenMusic
// remain GPL-3.0 (https://github.com/vorlon-dev/Zen-music).

class User {
  String name;
  List photos;
  String channelHandle;
  User({required this.name, required this.photos, required this.channelHandle});
}