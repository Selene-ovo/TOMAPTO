import 'package:flutter_naver_map/flutter_naver_map.dart';

class RouteData {
  final String totalTime;
  final String walkTime;
  final String price;
  final String busNumber;
  final String stationName;

  RouteData({
    required this.totalTime,
    required this.walkTime,
    required this.price,
    required this.busNumber,
    required this.stationName,
  });
}

class RoadSegment {
  final String roadName;
  final int distance;
  final int duration;
  final List<NLatLng> coordinates;

  RoadSegment({
    required this.roadName,
    required this.distance,
    required this.duration,
    required this.coordinates,
  });
}
