// lib/controllers/map/route_controller.dart (업데이트)
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';

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

class RouteController {
  // 기존 네이버 API 키 캐싱
  String? _cachedApiKey;
  String? _cachedSecretKey;
  String? _cachedApiUrl;

  // TMAP API 키 캐싱 (기존 유지)
  String? _cachedTmapApiKey;

  // 주소 검색용 API 키 캐싱
  String? _cachedClientId;
  String? _cachedClientSecret;

  // 한국 교통 정보 API 키 추가
  String? _expresswayCctvApiKey;
  String? _nationalTrafficApiKey;

  // 경로 캐시 (기존 유지)
  static final Map<String, Map<String, dynamic>> _routeCache = {};
  static final Map<String, Map<String, dynamic>> _walkRouteCache = {};

  // 속도 제한 캐시 추가
  static final Map<String, Map<String, dynamic>> _speedLimitCache = {};

  static const int _maxCacheSize = 50;
  static const Duration _cacheExpiry = Duration(minutes: 10);
  static const Duration _walkCacheExpiry = Duration(minutes: 15);
  static const Duration _speedLimitCacheExpiry = Duration(minutes: 30);

  // 마지막으로 계산된 경로 캐싱
  List<RouteData>? _cachedPublicTransportRoutes;
  Map<String, dynamic>? _cachedCarRoute;
  Map<String, dynamic>? _cachedWalkRoute;

  // 캐시 키 생성
  String _generateCacheKey(NLatLng start, NLatLng end, String mode) {
    return '${mode}_${start.latitude.toStringAsFixed(4)}_${start.longitude.toStringAsFixed(4)}_${end.latitude.toStringAsFixed(4)}_${end.longitude.toStringAsFixed(4)}';
  }

  // 주기적 캐시 정리 (기존 유지)
  static Timer? _cacheCleanupTimer;

  static void startCacheCleanup() {
    _cacheCleanupTimer?.cancel();
    _cacheCleanupTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      _cleanupExpiredCache();
    });
  }

  static void _cleanupExpiredCache() {
    final now = DateTime.now();

    _routeCache.removeWhere((key, value) {
      final cacheTime = value['cacheTime'] as DateTime;
      return now.difference(cacheTime) > _cacheExpiry;
    });

    _walkRouteCache.removeWhere((key, value) {
      final cacheTime = value['cacheTime'] as DateTime;
      return now.difference(cacheTime) > _walkCacheExpiry;
    });

    // 속도 제한 캐시 정리 추가
    _speedLimitCache.removeWhere((key, value) {
      final cacheTime = value['cacheTime'] as DateTime;
      return now.difference(cacheTime) > _speedLimitCacheExpiry;
    });
  }

  // 모든 API 키 초기화 (한국 공공 API 키 추가)
  Future<bool> _initAllApiKeys() async {
    // 네이버 API 키
    _cachedApiKey = dotenv.env['NAVER_API_KEY'];
    _cachedSecretKey = dotenv.env['NAVER_SECRET_KEY'];
    _cachedApiUrl = 'https://maps.apigw.ntruss.com/map-direction/v1';

    // TMAP API 키 (기존 유지)
    _cachedTmapApiKey = dotenv.env['TMAP_API_KEY'];

    // 주소 검색용 API 키
    _cachedClientId = dotenv.env['NAVER_DEV_KEY'];
    _cachedClientSecret = dotenv.env['NAVER_DEV_SECRET_KEY'];

    // 한국 교통 정보 API 키 추가
    _expresswayCctvApiKey = dotenv.env['EXPRESSWAY_API_KEY'];
    _nationalTrafficApiKey = dotenv.env['NATIONAL_TRAFFIC_API_KEY'];

    if (_cachedApiKey == null ||
        _cachedSecretKey == null ||
        _cachedTmapApiKey == null ||
        _cachedClientId == null ||
        _cachedClientSecret == null) {
      return false;
    }
    return true;
  }

  // 기존 TMAP 도보 경로 검색 메서드 유지
  Future<Map<String, dynamic>> searchWalkRouteWithTmap(
    NLatLng start,
    NLatLng end,
  ) async {
    final cacheKey = _generateCacheKey(start, end, 'walk');
    final cached = _getWalkFromCache(cacheKey);
    if (cached != null) {
      return cached;
    }

    bool keysInitialized = await _initAllApiKeys();
    if (!keysInitialized) {
      return _getMockWalkRouteData(start, end);
    }

    try {
      final url = Uri.parse(
        'https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1',
      );

      final requestBody = {
        'startX': start.longitude.toStringAsFixed(6),
        'startY': start.latitude.toStringAsFixed(6),
        'endX': end.longitude.toStringAsFixed(6),
        'endY': end.latitude.toStringAsFixed(6),
        'reqCoordType': 'WGS84GEO',
        'resCoordType': 'WGS84GEO',
        'startName': '출발지',
        'endName': '도착지',
      };

      final response = await http
          .post(
            url,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/x-www-form-urlencoded',
              'appKey': _cachedTmapApiKey!,
            },
            body: Uri(queryParameters: requestBody).query,
          )
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routeData = _parseTmapWalkResponse(data, start, end);

        _saveWalkToCache(cacheKey, routeData);
        return routeData;
      }

      return _getMockWalkRouteData(start, end);
    } catch (e) {
      return _getMockWalkRouteData(start, end);
    }
  }

  // TMAP 응답 파싱 (기존 유지)
  Map<String, dynamic> _parseTmapWalkResponse(
    dynamic data,
    NLatLng start,
    NLatLng end,
  ) {
    final List<NLatLng> pathCoordinates = [];
    int totalTime = 0;
    int totalDistance = 0;

    try {
      if (data['features'] != null) {
        final features = data['features'] as List;

        for (var feature in features) {
          final properties = feature['properties'];
          if (properties != null) {
            if (properties['totalTime'] != null) {
              totalTime = (properties['totalTime'] as num).round();
            }
            if (properties['totalDistance'] != null) {
              totalDistance = (properties['totalDistance'] as num).round();
            }
            if (totalTime > 0 && totalDistance > 0) break;
          }
        }

        for (var feature in features) {
          final geometry = feature['geometry'];
          if (geometry == null) continue;

          if (geometry['type'] == 'LineString') {
            final coordinates = geometry['coordinates'] as List;
            for (var coord in coordinates) {
              if (coord is List && coord.length >= 2) {
                double longitude = (coord[0] as num).toDouble();
                double latitude = (coord[1] as num).toDouble();
                pathCoordinates.add(NLatLng(latitude, longitude));
              }
            }
          } else if (geometry['type'] == 'Point') {
            final coordinates = geometry['coordinates'] as List;
            if (coordinates.length >= 2) {
              double longitude = (coordinates[0] as num).toDouble();
              double latitude = (coordinates[1] as num).toDouble();
              pathCoordinates.add(NLatLng(latitude, longitude));
            }
          }
        }
      }

      if (pathCoordinates.length < 2) {
        pathCoordinates.clear();
        pathCoordinates.addAll(_generateSimpleWalkPath(start, end));

        if (totalDistance == 0) {
          totalDistance = _calculateDistance(start, end).round();
        }
        if (totalTime == 0) {
          totalTime = (totalDistance / 1.4).round();
        }
      }

      return {
        'routes': [
          {'path': pathCoordinates},
        ],
        'distance': totalDistance,
        'duration': totalTime,
      };
    } catch (e) {
      return _getMockWalkRouteData(start, end);
    }
  }

  // ===== 한국 공공 API 속도 제한 관련 메서드 추가 =====

  /// 한국 공공 API를 통한 속도 제한 조회
  Future<int> getKoreaSpeedLimit(NLatLng position) async {
    // 캐시 확인
    final cacheKey = _generateSpeedLimitCacheKey(position);
    final cached = _getSpeedLimitFromCache(cacheKey);
    if (cached != null) {
      return cached['speedLimit'] ?? 50;
    }

    // API 키 확인
    if (_expresswayCctvApiKey == null || _nationalTrafficApiKey == null) {
      await _initAllApiKeys();
      if (_expresswayCctvApiKey == null || _nationalTrafficApiKey == null) {
        return _estimateSpeedLimitByLocation(position);
      }
    }

    try {
      // 1. 국가교통정보센터 API로 도로 정보 조회
      final roadInfo = await _getNationalTrafficRoadInfo(position);

      if (roadInfo != null) {
        // 캐시에 저장
        _saveSpeedLimitToCache(cacheKey, roadInfo);

        // 고속도로인 경우 고속도로 공공데이터 API 추가 조회
        if (roadInfo['roadType'] == 'expressway') {
          final expresswayInfo = await _getExpresswaySpeedLimit(roadInfo);
          if (expresswayInfo != null) {
            _saveSpeedLimitToCache(cacheKey, expresswayInfo);
            return expresswayInfo['speedLimit'] ?? 100;
          }
        }

        return roadInfo['speedLimit'] ?? 50;
      }

      return _estimateSpeedLimitByLocation(position);
    } catch (e) {
      return _estimateSpeedLimitByLocation(position);
    }
  }

  /// 국가교통정보센터 API를 통한 도로 정보 조회
  Future<Map<String, dynamic>?> _getNationalTrafficRoadInfo(
    NLatLng position,
  ) async {
    try {
      final tmCoords = _convertWGS84ToTM(position);

      final url = Uri.parse(
        'http://openapi.its.go.kr:8082/api/LinkInfo'
        '?key=$_nationalTrafficApiKey'
        '&ReqType=2'
        '&x=${tmCoords['x']}'
        '&y=${tmCoords['y']}'
        '&type=json',
      );

      final response = await http.get(url).timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseNationalTrafficResponse(data, position);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 고속도로 공공데이터 API를 통한 속도 제한 조회
  Future<Map<String, dynamic>?> _getExpresswaySpeedLimit(
    Map<String, dynamic> roadInfo,
  ) async {
    try {
      final routeCode = roadInfo['routeCode'] ?? '';

      final url = Uri.parse(
        'http://data.ex.co.kr/openapi/restinfo/restSpeedInfo'
        '?key=$_expresswayCctvApiKey'
        '&type=json'
        '&routeCode=$routeCode',
      );

      final response = await http.get(url).timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseExpresswayResponse(data, roadInfo);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// WGS84 좌표를 TM 좌표로 변환
  Map<String, double> _convertWGS84ToTM(NLatLng wgs84) {
    final double lat = wgs84.latitude;
    final double lng = wgs84.longitude;

    final double x = (lng - 127.0) * 111320.0 * 0.92;
    final double y = (lat - 36.0) * 111320.0;

    return {'x': 200000 + x, 'y': 500000 + y};
  }

  /// 국가교통정보센터 API 응답 파싱
  Map<String, dynamic>? _parseNationalTrafficResponse(
    Map<String, dynamic> data,
    NLatLng position,
  ) {
    try {
      final response = data['response'];
      if (response == null) return null;

      final body = response['body'];
      if (body == null) return null;

      final items = body['items'];
      if (items == null || items['item'] == null) return null;

      final linkInfo = items['item'];

      String roadType = 'general';
      final linkType = linkInfo['linktype']?.toString() ?? '';

      if (linkType.contains('1') || linkType.contains('고속도로')) {
        roadType = 'expressway';
      } else if (linkType.contains('2') || linkType.contains('도시고속도로')) {
        roadType = 'urban_expressway';
      }

      int speedLimit = _determineSpeedLimitByRoadType(roadType, linkInfo);

      return {
        'roadType': roadType,
        'speedLimit': speedLimit,
        'roadName': linkInfo['linkname'] ?? '도로',
        'routeCode': linkInfo['routeid'] ?? '',
        'linkId': linkInfo['linkid'] ?? '',
        'maxSpeed': linkInfo['maxspd'] ?? speedLimit,
        'position': position,
        'source': 'national_traffic',
      };
    } catch (e) {
      return null;
    }
  }

  /// 고속도로 공공데이터 API 응답 파싱
  Map<String, dynamic>? _parseExpresswayResponse(
    Map<String, dynamic> data,
    Map<String, dynamic> roadInfo,
  ) {
    try {
      final list = data['list'];
      if (list == null || list.isEmpty) return roadInfo;

      final speedInfo = list[0];
      final speedLimit =
          int.tryParse(speedInfo['limitSpeed']?.toString() ?? '') ??
          roadInfo['speedLimit'];

      return {
        ...roadInfo,
        'speedLimit': speedLimit,
        'trafficSpeed': speedInfo['avgSpeed'] ?? 0,
        'congestionLevel': speedInfo['congest'] ?? 0,
        'source': 'expressway_data',
      };
    } catch (e) {
      return roadInfo;
    }
  }

  /// 도로 유형별 기본 속도 제한 결정
  int _determineSpeedLimitByRoadType(
    String roadType,
    Map<String, dynamic> linkInfo,
  ) {
    final maxSpeed = int.tryParse(linkInfo['maxspd']?.toString() ?? '');
    if (maxSpeed != null && maxSpeed > 0) {
      return maxSpeed;
    }

    switch (roadType) {
      case 'expressway':
        return 100;
      case 'urban_expressway':
        return 80;
      case 'arterial':
        return 60;
      case 'collector':
        return 50;
      case 'local':
        return 30;
      default:
        return 50;
    }
  }

  /// 위치 기반 속도 제한 추정 (API 실패 시 백업)
  int _estimateSpeedLimitByLocation(NLatLng position) {
    if (_isInMajorCity(position)) {
      return 50;
    }

    if (_isNearExpressway(position)) {
      return 100;
    }

    if (_isNearNationalRoad(position)) {
      return 80;
    }

    return 60;
  }

  /// 주요 도시 지역 확인
  bool _isInMajorCity(NLatLng position) {
    final majorCities = [
      {'lat': 37.5665, 'lng': 126.9780, 'radius': 0.3},
      {'lat': 35.1796, 'lng': 129.0756, 'radius': 0.2},
      {'lat': 35.8714, 'lng': 128.6014, 'radius': 0.15},
      {'lat': 37.4563, 'lng': 126.7052, 'radius': 0.2},
    ];

    for (var city in majorCities) {
      final distance = _calculateDistance(
        position,
        NLatLng(city['lat']! as double, city['lng']! as double),
      );
      if (distance < (city['radius']! as double) * 111000) {
        return true;
      }
    }
    return false;
  }

  bool _isNearExpressway(NLatLng position) {
    return false;
  }

  bool _isNearNationalRoad(NLatLng position) {
    return false;
  }

  /// 속도 제한 캐시 관련 메서드들
  String _generateSpeedLimitCacheKey(NLatLng position) {
    final lat = (position.latitude * 1000).round() / 1000;
    final lng = (position.longitude * 1000).round() / 1000;
    return 'speed_${lat}_${lng}';
  }

  Map<String, dynamic>? _getSpeedLimitFromCache(String key) {
    final cached = _speedLimitCache[key];
    if (cached != null) {
      final cacheTime = cached['cacheTime'] as DateTime;
      if (DateTime.now().difference(cacheTime) < _speedLimitCacheExpiry) {
        return cached['data'] as Map<String, dynamic>;
      } else {
        _speedLimitCache.remove(key);
      }
    }
    return null;
  }

  void _saveSpeedLimitToCache(String key, Map<String, dynamic> data) {
    _speedLimitCache[key] = {'data': data, 'cacheTime': DateTime.now()};
  }

  // ===== 기존 메서드들 유지 =====

  /// 자동차 경로 검색 (한국 공공 API 속도 제한 정보 포함 버전)
  Future<Map<String, dynamic>> getCarRouteWithSpeedLimits(
    NLatLng start,
    NLatLng end,
  ) async {
    // 1. 네이버 API로 경로 가져오기
    final routeData = await searchCarRoute(start, end);

    // 2. 경로상의 주요 지점들의 속도 제한 조회
    if (routeData['routes'] != null && routeData['routes'].isNotEmpty) {
      final route = routeData['routes'][0];
      final pathCoordinates = route['path'] as List<NLatLng>?;

      if (pathCoordinates != null && pathCoordinates.isNotEmpty) {
        List<Map<String, dynamic>> speedLimitSegments = [];

        final sampleInterval = max(1, pathCoordinates.length ~/ 10);

        for (int i = 0; i < pathCoordinates.length; i += sampleInterval) {
          final position = pathCoordinates[i];
          final speedLimit = await getKoreaSpeedLimit(position);

          speedLimitSegments.add({
            'position': position,
            'speedLimit': speedLimit,
            'index': i,
          });

          await Future.delayed(Duration(milliseconds: 100));
        }

        routeData['speedLimitSegments'] = speedLimitSegments;
      }
    }

    return routeData;
  }

  /// 기존 메서드들 (TMAP 포함하여 모두 유지)
  Future<Map<String, dynamic>> searchWalkRoute(
    NLatLng start,
    NLatLng end,
  ) async {
    if (_cachedWalkRoute != null) {
      return _cachedWalkRoute!;
    }
    return await searchWalkRouteWithTmap(start, end);
  }

  Future<Map<String, dynamic>> searchCarRoute(
    NLatLng start,
    NLatLng end,
  ) async {
    final cacheKey = _generateCacheKey(start, end, 'car');
    final cached = _getFromCache(cacheKey);
    if (cached != null) {
      return cached;
    }

    if (_cachedCarRoute != null) {
      return _cachedCarRoute!;
    }

    bool keysInitialized = await _initAllApiKeys();
    if (!keysInitialized) {
      return _getMockCarRouteData(start, end);
    }

    try {
      final url = Uri.parse(
        '$_cachedApiUrl/driving?'
        'start=${start.longitude},${start.latitude}&'
        'goal=${end.longitude},${end.latitude}&'
        'option=trafast',
      );

      final response = await http
          .get(
            url,
            headers: {
              'X-NCP-APIGW-API-KEY-ID': _cachedApiKey!,
              'X-NCP-APIGW-API-KEY': _cachedSecretKey!,
            },
          )
          .timeout(Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['route'] != null && data['route']['trafast'] != null) {
          final route = data['route']['trafast'][0];

          final List<NLatLng> pathCoordinates = [];
          if (route['path'] != null) {
            final path = route['path'] as List;
            if (path.isNotEmpty && path[0] is! List) {
              for (int i = 0; i < path.length; i += 2) {
                if (i + 1 < path.length) {
                  double longitude = (path[i] as num).toDouble();
                  double latitude = (path[i + 1] as num).toDouble();
                  pathCoordinates.add(NLatLng(latitude, longitude));
                }
              }
            } else {
              for (var point in path) {
                if (point is List && point.length >= 2) {
                  double longitude = (point[0] as num).toDouble();
                  double latitude = (point[1] as num).toDouble();
                  pathCoordinates.add(NLatLng(latitude, longitude));
                }
              }
            }
          }

          final roadSegments = _parseRoadSegments(data);

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
          };

          _saveToCache(cacheKey, routeData);
          _cachedCarRoute = routeData;

          return routeData;
        }
      }

      return _getMockCarRouteData(start, end);
    } catch (e) {
      return _getMockCarRouteData(start, end);
    }
  }

  // 기존 캐시 메서드들 유지
  Map<String, dynamic>? _getFromCache(String key) {
    final cached = _routeCache[key];
    if (cached != null) {
      final cacheTime = cached['cacheTime'] as DateTime;
      if (DateTime.now().difference(cacheTime) < _cacheExpiry) {
        return cached['data'] as Map<String, dynamic>;
      } else {
        _routeCache.remove(key);
      }
    }
    return null;
  }

  Map<String, dynamic>? _getWalkFromCache(String key) {
    final cached = _walkRouteCache[key];
    if (cached != null) {
      final cacheTime = cached['cacheTime'] as DateTime;
      if (DateTime.now().difference(cacheTime) < _walkCacheExpiry) {
        return cached['data'] as Map<String, dynamic>;
      } else {
        _walkRouteCache.remove(key);
      }
    }
    return null;
  }

  void _saveToCache(String key, Map<String, dynamic> data) {
    if (_routeCache.length >= _maxCacheSize) {
      final oldestKey = _routeCache.keys.first;
      _routeCache.remove(oldestKey);
    }
    _routeCache[key] = {'data': data, 'cacheTime': DateTime.now()};
  }

  void _saveWalkToCache(String key, Map<String, dynamic> data) {
    if (_walkRouteCache.length >= 30) {
      final oldestKey = _walkRouteCache.keys.first;
      _walkRouteCache.remove(oldestKey);
    }
    _walkRouteCache[key] = {'data': data, 'cacheTime': DateTime.now()};
  }

  // 기존 도로명 파싱 메서드 유지
  List<RoadSegment> _parseRoadSegments(Map<String, dynamic> routeData) {
    List<RoadSegment> segments = [];

    try {
      if (routeData['route'] != null && routeData['route']['trafast'] != null) {
        final route = routeData['route']['trafast'][0];

        if (route['guide'] != null) {
          final guides = route['guide'] as List;

          for (var guide in guides) {
            if (guide['name'] != null && guide['distance'] != null) {
              String roadName = guide['name'].toString();
              int distance = (guide['distance'] as num).toInt();
              int duration = (guide['duration'] as num?)?.toInt() ?? 0;

              if (roadName.isNotEmpty && roadName != '0' && distance > 0) {
                segments.add(
                  RoadSegment(
                    roadName: roadName,
                    distance: distance,
                    duration: duration,
                    coordinates: [],
                  ),
                );
              }
            }
          }
        }

        if (segments.isEmpty && route['section'] != null) {
          final sections = route['section'] as List;

          for (var section in sections) {
            if (section['name'] != null) {
              String roadName = section['name'].toString();
              int distance = (section['distance'] as num?)?.toInt() ?? 0;
              int duration = (section['duration'] as num?)?.toInt() ?? 0;

              if (roadName.isNotEmpty && distance > 0) {
                segments.add(
                  RoadSegment(
                    roadName: roadName,
                    distance: distance,
                    duration: duration,
                    coordinates: [],
                  ),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      // 오류 발생 시 빈 배열 반환
    }

    return segments;
  }

  // 기존 유틸리티 메서드들 유지
  List<NLatLng> _generateSimpleWalkPath(NLatLng start, NLatLng end) {
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

  double _calculateDistance(NLatLng point1, NLatLng point2) {
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

  // 기존 주소 검색 메서드들 유지
  Future<List<Map<String, dynamic>>> searchAddressByKeyword(
    String keyword,
  ) async {
    bool keysInitialized = await _initAllApiKeys();
    if (!keysInitialized) {
      return [];
    }

    final encodedKeyword = Uri.encodeComponent(keyword);
    final url = Uri.parse(
      'https://openapi.naver.com/v1/search/local.json?query=$encodedKeyword&display=5',
    );

    try {
      final response = await http
          .get(
            url,
            headers: {
              'X-Naver-Client-Id': _cachedClientId!,
              'X-Naver-Client-Secret': _cachedClientSecret!,
            },
          )
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);

        if (data['items'] != null && data['items'].isNotEmpty) {
          return data['items'].map<Map<String, dynamic>>((item) {
            String title = item['title'].replaceAll(RegExp(r'<[^>]*>'), '');

            return {
              'name': title,
              'address': item['roadAddress'] ?? item['address'] ?? '',
              'x': item['mapx'] ?? '0',
              'y': item['mapy'] ?? '0',
            };
          }).toList();
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  NLatLng convertAddressToCoords(Map<String, dynamic> searchResult) {
    try {
      double x = double.parse(searchResult['x']) / 10000000.0;
      double y = double.parse(searchResult['y']) / 10000000.0;

      return NLatLng(y, x);
    } catch (e) {
      return NLatLng(37.5666805, 126.9784147);
    }
  }

  Future<String> getAddressFromCoords(NLatLng position) async {
    bool keysInitialized = await _initAllApiKeys();
    if (!keysInitialized) {
      return '서울특별시 강남구';
    }

    final url =
        'https://maps.apigw.ntruss.com/map-reversegeocode/v2/gc?'
        'coords=${position.longitude},${position.latitude}&output=json';

    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'X-NCP-APIGW-API-KEY-ID': _cachedApiKey!,
              'X-NCP-APIGW-API-KEY': _cachedSecretKey!,
              'Accept': 'application/json',
            },
          )
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);

        if (data['results'] != null && data['results'].isNotEmpty) {
          return _parseSimpleAddress(data);
        }
      }

      return '강원특별자치도 강릉시';
    } catch (e) {
      return '강원특별자치도 강릉시';
    }
  }

  String _parseSimpleAddress(Map<String, dynamic> response) {
    try {
      final results = response['results'];

      for (var result in results) {
        if (result['name'] == 'roadaddr' && result['region'] != null) {
          final region = result['region'];
          String address = '';

          if (region['area1'] != null) address += region['area1']['name'] + ' ';
          if (region['area2'] != null) address += region['area2']['name'] + ' ';
          if (region['area3'] != null) address += region['area3']['name'];

          return address.trim();
        }
      }

      for (var result in results) {
        if (result['name'] == 'legalcode' && result['region'] != null) {
          final region = result['region'];
          String address = '';

          if (region['area1'] != null) address += region['area1']['name'] + ' ';
          if (region['area2'] != null) address += region['area2']['name'] + ' ';
          if (region['area3'] != null) address += region['area3']['name'];

          return address.trim();
        }
      }

      return '주소 확인 불가';
    } catch (e) {
      return '주소 확인 불가';
    }
  }

  Future<List<RouteData>> searchPublicTransportRoutes(
    String start,
    String end,
  ) async {
    if (_cachedPublicTransportRoutes != null) {
      return _cachedPublicTransportRoutes!;
    }

    try {
      _cachedPublicTransportRoutes = _getMockPublicTransportData();
      return _cachedPublicTransportRoutes!;
    } catch (e) {
      return _getMockPublicTransportData();
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

  /// 한국 공공 API를 통한 특정 위치의 속도 제한 조회 (NavigationController에서 사용)
  Future<int> getSpeedLimitAtPosition(
    NLatLng position,
    Map<String, dynamic>? routeData,
  ) async {
    // 1. 먼저 경로 데이터에 한국 공공 API 정보가 있는지 확인
    if (routeData != null && routeData['speedLimitSegments'] != null) {
      final speedLimitSegments = routeData['speedLimitSegments'] as List;

      // 현재 위치에서 가장 가까운 구간의 속도 제한 반환
      double minDistance = double.infinity;
      int nearestSpeedLimit = 50;

      for (var segment in speedLimitSegments) {
        final segmentPosition = segment['position'] as NLatLng;
        final distance = _calculateDistance(position, segmentPosition);

        if (distance < minDistance) {
          minDistance = distance;
          nearestSpeedLimit = segment['speedLimit'] as int;
        }
      }

      return nearestSpeedLimit;
    }

    // 2. 경로 데이터에 정보가 없으면 실시간 조회
    return await getKoreaSpeedLimit(position);
  }

  void invalidateCache() {
    _cachedPublicTransportRoutes = null;
    _cachedCarRoute = null;
    _cachedWalkRoute = null;
  }

  List<RouteData> _getMockPublicTransportData() {
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

  Map<String, dynamic> _getMockCarRouteData(NLatLng start, NLatLng end) {
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

  Map<String, dynamic> _getMockWalkRouteData(NLatLng start, NLatLng end) {
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
}
