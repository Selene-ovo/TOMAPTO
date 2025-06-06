import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'route_data_controller.dart';
import 'dart:math';

class RouteMockController {
  static List<RouteData> getMockPublicTransportData() {
    return [
      RouteData(
        totalTime: '14분',
        walkTime: '도보 4분',
        price: '카드 1,530원',
        busNumber: '225',
        stationName: '교보생명 정류장',
      ),
      RouteData(
        totalTime: '9분',
        walkTime: '도보 4분',
        price: '카드 1,530원',
        busNumber: '104, 104-1',
        stationName: '교보생명 정류장',
      ),
      RouteData(
        totalTime: '12분',
        walkTime: '도보 4분',
        price: '카드 1,530원',
        busNumber: '330, 302',
        stationName: '교보생명 정류장',
      ),
    ];
  }

  static Map<String, dynamic> getMockCarRouteData(NLatLng start, NLatLng end) {
    final mockRoadSegments = [
      RoadSegment(
        roadName: "강남대로",
        distance: 2000,
        duration: 360,
        coordinates: [],
      ),
      RoadSegment(
        roadName: "테헤란로",
        distance: 3000,
        duration: 540,
        coordinates: [],
      ),
    ];

    return {
      'distance': 5000,
      'duration': 900,
      'toll': 0,
      'routes': [
        {
          'path': [
            start,
            NLatLng(start.latitude + 0.005, start.longitude + 0.003),
            NLatLng(start.latitude + 0.010, start.longitude + 0.008),
            NLatLng(start.latitude + 0.015, start.longitude + 0.012),
            end,
          ],
          'segments': mockRoadSegments,
          'roadSegments': mockRoadSegments,
        },
      ],
      'roadSegments': mockRoadSegments,
    };
  }

  static Map<String, dynamic> getMockWalkRouteData(NLatLng start, NLatLng end) {
    final distance = _calculateDistance(start, end).round();
    final duration = (distance / 1.4).round();

    return {
      'distance': distance,
      'duration': duration,
      'routes': [
        {'path': _generateSimpleWalkPath(start, end)},
      ],
    };
  }

  static List<NLatLng> _generateSimpleWalkPath(NLatLng start, NLatLng end) {
    final distance = _calculateDistance(start, end);

    if (distance < 100) {
      return [start, end];
    }

    final points = <NLatLng>[start];
    final steps = (distance / 200).clamp(1, 4).round();

    for (int i = 1; i < steps; i++) {
      final ratio = i / steps;
      final lat = start.latitude + (end.latitude - start.latitude) * ratio;
      final lng = start.longitude + (end.longitude - start.longitude) * ratio;
      points.add(NLatLng(lat, lng));
    }

    points.add(end);
    return points;
  }

  static double _calculateDistance(NLatLng point1, NLatLng point2) {
    const double earthRadius = 6371000;
    final double lat1 = point1.latitude * (3.141592653589793 / 180);
    final double lat2 = point2.latitude * (3.141592653589793 / 180);
    final double dLat =
        (point2.latitude - point1.latitude) * (3.141592653589793 / 180);
    final double dLon =
        (point2.longitude - point1.longitude) * (3.141592653589793 / 180);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }
}
