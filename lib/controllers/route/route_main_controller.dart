import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'route_api_controller.dart';
import 'route_cache_controller.dart';
import 'route_parser_controller.dart';
import 'route_mock_controller.dart';
import 'route_data_controller.dart';
import 'route_instruction_controller.dart';

class RouteController {
  final RouteApiController _apiController = RouteApiController();
  final RouteParserController _parserController = RouteParserController();

  List<RouteData>? _cachedPublicTransportRoutes;
  Map<String, dynamic>? _cachedCarRoute;
  Map<String, dynamic>? _cachedWalkRoute;

  Future<Map<String, dynamic>> searchCarRoute(
    NLatLng start,
    NLatLng end,
  ) async {
    final cacheKey = RouteCacheController.generateCacheKey(start, end, 'car');
    final cached = RouteCacheController.getFromCache(cacheKey);
    if (cached != null) {
      return cached;
    }

    if (_cachedCarRoute != null) {
      return _cachedCarRoute!;
    }

    bool keysInitialized = await _apiController.initAllApiKeys();
    if (!keysInitialized) {
      return RouteMockController.getMockCarRouteData(start, end);
    }

    try {
      final data = await _apiController.searchCarRouteFromApi(start, end);

      if (data['route'] != null && data['route']['trafast'] != null) {
        final route = data['route']['trafast'][0];

        final pathCoordinates = _parserController.extractPathCoordinates(route);
        final turnInstructions = _parserController.extractTurnInstructions(
          route,
          pathCoordinates,
        );
        final sectionInfo = _parserController.extractSectionInfo(route);
        final roadSegments = _parserController.parseRoadSegments(data);

        final routeData = {
          'routes': [
            {
              'path': pathCoordinates,
              'summary': route['summary'],
              'roadSegments': roadSegments,
            },
          ],
          'distance': route['summary']?['distance'] ?? 0,
          'duration': (route['summary']?['duration'] ?? 0) ~/ 1000,
          'toll': route['summary']?['tollFare'] ?? 0,
          'roadSegments': roadSegments,
          'turnInstructions': turnInstructions,
          'sectionInfo': sectionInfo,
        };

        RouteCacheController.saveToCache(cacheKey, routeData);
        _cachedCarRoute = routeData;

        return routeData;
      }

      return RouteMockController.getMockCarRouteData(start, end);
    } catch (e) {
      return RouteMockController.getMockCarRouteData(start, end);
    }
  }

  Future<Map<String, dynamic>> searchWalkRoute(
    NLatLng start,
    NLatLng end,
  ) async {
    if (_cachedWalkRoute != null) {
      return _cachedWalkRoute!;
    }
    return await searchWalkRouteWithTmap(start, end);
  }

  Future<Map<String, dynamic>> searchWalkRouteWithTmap(
    NLatLng start,
    NLatLng end,
  ) async {
    final cacheKey = RouteCacheController.generateCacheKey(start, end, 'walk');
    final cached = RouteCacheController.getWalkFromCache(cacheKey);
    if (cached != null) {
      return cached;
    }

    bool keysInitialized = await _apiController.initAllApiKeys();
    if (!keysInitialized) {
      return RouteMockController.getMockWalkRouteData(start, end);
    }

    try {
      final data = await _apiController.searchWalkRouteFromTmap(start, end);
      final routeData = _parserController.parseTmapWalkResponse(
        data,
        start,
        end,
      );

      RouteCacheController.saveWalkToCache(cacheKey, routeData);
      return routeData;
    } catch (e) {
      return RouteMockController.getMockWalkRouteData(start, end);
    }
  }

  Future<List<Map<String, dynamic>>> searchAddressByKeyword(
    String keyword,
  ) async {
    bool keysInitialized = await _apiController.initAllApiKeys();
    if (!keysInitialized) {
      return [];
    }

    return await _apiController.searchAddressByKeyword(keyword);
  }

  Future<String> getAddressFromCoords(NLatLng position) async {
    bool keysInitialized = await _apiController.initAllApiKeys();
    if (!keysInitialized) {
      return '서울특별시 강남구';
    }

    return await _apiController.getAddressFromCoords(position);
  }

  NLatLng convertAddressToCoords(Map<String, dynamic> searchResult) {
    return _apiController.convertAddressToCoords(searchResult);
  }

  Future<List<RouteData>> searchPublicTransportRoutes(
    String start,
    String end,
  ) async {
    if (_cachedPublicTransportRoutes != null) {
      return _cachedPublicTransportRoutes!;
    }

    try {
      _cachedPublicTransportRoutes =
          RouteMockController.getMockPublicTransportData();
      return _cachedPublicTransportRoutes!;
    } catch (e) {
      return RouteMockController.getMockPublicTransportData();
    }
  }

  String getRoadNameAtPosition(
    NLatLng position,
    Map<String, dynamic> routeData,
  ) {
    try {
      if (routeData['roadSegments'] != null) {
        final segments = routeData['roadSegments'] as List<RoadSegment>;

        if (segments.isNotEmpty) {
          return segments.first.roadName;
        }
      }

      return "도로";
    } catch (e) {
      return "도로";
    }
  }

  void invalidateCache() {
    _cachedPublicTransportRoutes = null;
    _cachedCarRoute = null;
    _cachedWalkRoute = null;
  }
}
