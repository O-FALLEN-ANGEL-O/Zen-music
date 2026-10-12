// ZenMusic Desktop — ported from Echo Music (GPL-3.0). ZenMusic remains GPL-3.0.

class ChartItemModel {
  String? name;
  String? subtitle;
  String? imageUrl;
  String? id;
  String? type;

  ChartItemModel({this.name, this.subtitle, this.imageUrl, this.id, this.type});
}

class ChartModel {
  String? chartName;
  List<ChartItemModel>? chartItems;
  String? url;
  DateTime? lastUpdated;

  ChartModel({this.chartName, this.chartItems, this.url, this.lastUpdated});
}

class ChartURL {
  String title;
  String url;
  String? coverArt;
  ChartURL({required this.title, required this.url, this.coverArt});
}