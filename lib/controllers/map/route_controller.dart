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

// 도로 정보를 담는 새로운 클래스 추가
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

  // TMAP API 키 캐싱
  String? _cachedTmapApiKey;

  // 주소 검색용 API 키 캐싱
  String? _cachedClientId;
  String? _cachedClientSecret;

  // 경로 캐시 개선
  static final Map<String, Map<String, dynamic>> _routeCache = {};
  static final Map<String, Map<String, dynamic>> _walkRouteCache = {};
  static const int _maxCacheSize = 50;
  static const Duration _cacheExpiry = Duration(minutes: 10);
  static const Duration _walkCacheExpiry = Duration(minutes: 15);

  // 마지막으로 계산된 경로 캐싱
  List<RouteData>? _cachedPublicTransportRoutes;
  Map<String, dynamic>? _cachedCarRoute;
  Map<String, dynamic>? _cachedWalkRoute;

  // 캐시 키 생성
  String _generateCacheKey(NLatLng start, NLatLng end, String mode) {
    return '${mode}_${start.latitude.toStringAsFixed(4)}_${start.longitude.toStringAsFixed(4)}_${end.latitude.toStringAsFixed(4)}_${end.longitude.toStringAsFixed(4)}';
  }

  // 주기적 캐시 정리
  static Timer? _cacheCleanupTimer;

  static void startCacheCleanup() {
    _cacheCleanupTimer?.cancel();
    _cacheCleanupTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      _cleanupExpiredCache();
    });
  }

  static void _cleanupExpiredCache() {
    final now = DateTime.now();

    // 자동차 경로 캐시 정리
    _routeCache.removeWhere((key, value) {
      final cacheTime = value['cacheTime'] as DateTime;
      return now.difference(cacheTime) > _cacheExpiry;
    });

    // 도보 경로 캐시 정리
    _walkRouteCache.removeWhere((key, value) {
      final cacheTime = value['cacheTime'] as DateTime;
      return now.difference(cacheTime) > _walkCacheExpiry;
    });

    print(
      '캐시 정리 완료: 자동차(${_routeCache.length}), 도보(${_walkRouteCache.length})',
    );
  }

  // 캐시에서 경로 가져오기
  Map<String, dynamic>? _getFromCache(String key) {
    final cached = _routeCache[key];
    if (cached != null) {
      final cacheTime = cached['cacheTime'] as DateTime;
      if (DateTime.now().difference(cacheTime) < _cacheExpiry) {
        print('캐시에서 경로 반환: $key');
        return cached['data'] as Map<String, dynamic>;
      } else {
        _routeCache.remove(key);
      }
    }
    return null;
  }

  // 도보 캐시에서 가져오기
  Map<String, dynamic>? _getWalkFromCache(String key) {
    final cached = _walkRouteCache[key];
    if (cached != null) {
      final cacheTime = cached['cacheTime'] as DateTime;
      if (DateTime.now().difference(cacheTime) < _walkCacheExpiry) {
        print('도보 캐시에서 경로 반환: $key');
        return cached['data'] as Map<String, dynamic>;
      } else {
        _walkRouteCache.remove(key);
      }
    }
    return null;
  }

  // 캐시에 경로 저장
  void _saveToCache(String key, Map<String, dynamic> data) {
    // 캐시 크기 제한
    if (_routeCache.length >= _maxCacheSize) {
      final oldestKey = _routeCache.keys.first;
      _routeCache.remove(oldestKey);
    }

    _routeCache[key] = {'data': data, 'cacheTime': DateTime.now()};
  }

  // 도보 캐시에 저장
  void _saveWalkToCache(String key, Map<String, dynamic> data) {
    if (_walkRouteCache.length >= 30) {
      final oldestKey = _walkRouteCache.keys.first;
      _walkRouteCache.remove(oldestKey);
    }

    _walkRouteCache[key] = {'data': data, 'cacheTime': DateTime.now()};
  }

  // 모든 API 키 초기화
  Future<bool> _initAllApiKeys() async {
    // 네이버 API 키
    _cachedApiKey = dotenv.env['NAVER_API_KEY'];
    _cachedSecretKey = dotenv.env['NAVER_SECRET_KEY'];
    _cachedApiUrl = 'https://maps.apigw.ntruss.com/map-direction/v1';

    // TMAP API 키
    _cachedTmapApiKey = dotenv.env['TMAP_API_KEY'];

    // 주소 검색용 API 키
    _cachedClientId = dotenv.env['NAVER_DEV_KEY'];
    _cachedClientSecret = dotenv.env['NAVER_DEV_SECRET_KEY'];

    if (_cachedApiKey == null ||
        _cachedSecretKey == null ||
        _cachedTmapApiKey == null ||
        _cachedClientId == null ||
        _cachedClientSecret == null) {
      print('필요한 API 키가 설정되지 않았습니다.');
      return false;
    }
    return true;
  }

  // 주소 검색 기능 (기존 유지)
  Future<List<Map<String, dynamic>>> searchAddressByKeyword(
    String keyword,
  ) async {
    // API 키 확인
    bool keysInitialized = await _initAllApiKeys();
    if (!keysInitialized) {
      return [];
    }

    // 한글 인코딩 처리
    final encodedKeyword = Uri.encodeComponent(keyword);
    final url = Uri.parse(
      'https://openapi.naver.com/v1/search/local.json?query=$encodedKeyword&display=5',
    );

    print('로컬 검색 API 호출: $url');

    try {
      final response = await http
          .get(
            url,
            headers: {
              'X-Naver-Client-Id': _cachedClientId!,
              'X-Naver-Client-Secret': _cachedClientSecret!,
            },
          )
          .timeout(Duration(seconds: 5)); // 타임아웃 추가

      print('로컬 검색 응답 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);

        if (data['items'] != null && data['items'].isNotEmpty) {
          print('로컬 검색 결과 수: ${data['items'].length}');

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
      print('로컬 검색 오류: $e');
      return [];
    }
  }

  // 주소-좌표 변환 (기존 유지)
  NLatLng convertAddressToCoords(Map<String, dynamic> searchResult) {
    try {
      double x = double.parse(searchResult['x']) / 10000000.0;
      double y = double.parse(searchResult['y']) / 10000000.0;

      return NLatLng(y, x);
    } catch (e) {
      print('좌표 변환 오류: $e');
      return NLatLng(37.5666805, 126.9784147);
    }
  }

  // 좌표-주소 변환 (기존 유지)
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
      print('주소 변환 오류: $e');
      return '강원특별자치도 강릉시';
    }
  }

  // 간단한 주소 파싱 (기존 유지)
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
      print('주소 파싱 오류: $e');
      return '주소 확인 불가';
    }
  }

  // TMAP API를 사용한 도보 경로 검색 메서드 (최적화)
  Future<Map<String, dynamic>> searchWalkRouteWithTmap(
    NLatLng start,
    NLatLng end,
  ) async {
    print('TMAP 도보 경로 요청 시작: ${DateTime.now()}');

    // 캐시 확인
    final cacheKey = _generateCacheKey(start, end, 'walk');
    final cached = _getWalkFromCache(cacheKey);
    if (cached != null) {
      print('도보 경로 캐시 히트!');
      return cached;
    }

    // TMAP API 키 확인
    bool keysInitialized = await _initAllApiKeys();
    if (!keysInitialized) {
      return _getMockWalkRouteData(start, end);
    }

    try {
      // TMAP 도보 경로 검색 API URL
      final url = Uri.parse(
        'https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1',
      );

      // 요청 바디 구성
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

      print('TMAP 도보 경로 요청 URL: $url');

      // API 호출 (타임아웃 설정)
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
          .timeout(Duration(seconds: 5)); // 도보는 5초 타임아웃

      print('TMAP 도보 경로 응답 상태 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routeData = _parseTmapWalkResponse(data, start, end);

        // 캐시에 저장
        _saveWalkToCache(cacheKey, routeData);

        print('TMAP 도보 경로 파싱 완료: ${DateTime.now()}');
        return routeData;
      }

      return _getMockWalkRouteData(start, end);
    } catch (e) {
      print('TMAP 도보 경로 검색 오류: $e');
      return _getMockWalkRouteData(start, end);
    }
  }

  // TMAP 응답 파싱 최적화
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

        // 총 시간/거리 추출
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

        // 좌표 추출
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

      // 좌표가 부족하면 간단한 경로 생성
      if (pathCoordinates.length < 2) {
        pathCoordinates.clear();
        pathCoordinates.addAll(_generateSimpleWalkPath(start, end));

        if (totalDistance == 0) {
          totalDistance = _calculateDistance(start, end).round();
        }
        if (totalTime == 0) {
          totalTime = (totalDistance / 1.4).round(); // 도보 속도 1.4m/s
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
      print('TMAP 응답 파싱 오류: $e');
      return _getMockWalkRouteData(start, end);
    }
  }

  // 간단한 도보 경로 생성
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

  // 거리 계산 메서드
  double _calculateDistance(NLatLng point1, NLatLng point2) {
    const double earthRadius = 6371000;
    final double lat1 = point1.latitude * (3.141592653589793 / 180);
    final double lat2 = point2.latitude * (3.141592653589793 / 180);
    final double dLat =
        (point2.latitude - point1.latitude) * (3.141592653589793 / 180);
    final double dLon =
        (point2.longitude - point1.longitude) * (3.141592653589793 / 180);

    final double a =
        (dLat / 2) * (dLat / 2) + lat1 * lat2 * (dLon / 2) * (dLon / 2);
    final double c = 2 * (a / (1 + a));

    return earthRadius * c;
  }

  // 기존 메서드들 유지
  Future<Map<String, dynamic>> searchWalkRoute(
    NLatLng start,
    NLatLng end,
  ) async {
    if (_cachedWalkRoute != null) {
      return _cachedWalkRoute!;
    }

    return await searchWalkRouteWithTmap(start, end);
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
      print('대중교통 경로 검색 오류: $e');
      return _getMockPublicTransportData();
    }
  }

  // 네이버 API 응답에서 도로명 정보를 추출하는 메서드 추가
  List<RoadSegment> _parseRoadSegments(Map<String, dynamic> routeData) {
    List<RoadSegment> segments = [];

    try {
      if (routeData['route'] != null && routeData['route']['trafast'] != null) {
        final route = routeData['route']['trafast'][0];

        // 네이버 API의 guides 정보에서 도로명 추출
        if (route['guide'] != null) {
          final guides = route['guide'] as List;

          for (var guide in guides) {
            if (guide['name'] != null && guide['distance'] != null) {
              String roadName = guide['name'].toString();
              int distance = (guide['distance'] as num).toInt();
              int duration = (guide['duration'] as num?)?.toInt() ?? 0;

              // 빈 도로명이나 의미없는 데이터 필터링
              if (roadName.isNotEmpty && roadName != '0' && distance > 0) {
                segments.add(
                  RoadSegment(
                    roadName: roadName,
                    distance: distance,
                    duration: duration,
                    coordinates: [], // 상세 좌표는 필요시 추가
                  ),
                );
              }
            }
          }
        }

        // guides가 없거나 부족한 경우 section 정보 활용
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

      print('추출된 도로 구간 수: ${segments.length}');
      for (var segment in segments) {
        print('도로명: ${segment.roadName}, 거리: ${segment.distance}m');
      }
    } catch (e) {
      print('도로 구간 파싱 오류: $e');
    }

    return segments;
  }

  // 자동차 경로 검색 메서드 수정 - 도로명 정보 포함
  Future<Map<String, dynamic>> searchCarRoute(
    NLatLng start,
    NLatLng end,
  ) async {
    // 캐시 확인
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

          // 도로명 정보 추출
          final roadSegments = _parseRoadSegments(data);

          final routeData = {
            'routes': [
              {
                'path': pathCoordinates,
                'summary': route['summary'],
                'roadSegments': roadSegments, // 도로명 정보 추가
              },
            ],
            'distance': route['summary']?['distance'] ?? 0,
            'duration': (route['summary']?['duration'] ?? 0) ~/ 1000,
            'toll': route['summary']?['tollFare'] ?? 0,
            'roadSegments': roadSegments, // 최상위에도 추가
          };

          // 캐시에 저장
          _saveToCache(cacheKey, routeData);
          _cachedCarRoute = routeData;

          return routeData;
        }
      }

      return _getMockCarRouteData(start, end);
    } catch (e) {
      print('경로 검색 오류: $e');
      return _getMockCarRouteData(start, end);
    }
  }

  // 특정 좌표에서 가장 가까운 도로명을 반환하는 메서드 추가
  String getRoadNameAtPosition(
    NLatLng position,
    Map<String, dynamic> routeData,
  ) {
    try {
      if (routeData['roadSegments'] != null) {
        final segments = routeData['roadSegments'] as List<RoadSegment>;

        if (segments.isNotEmpty) {
          // 현재는 간단하게 첫 번째 도로명을 반환
          // 추후 좌표 기반으로 더 정확한 매칭 로직 구현 가능
          return segments.first.roadName;
        }
      }

      // 기본값 반환
      return "도로";
    } catch (e) {
      print('도로명 조회 오류: $e');
      return "도로";
    }
  }

  // 캐시 무효화
  void invalidateCache() {
    _cachedPublicTransportRoutes = null;
    _cachedCarRoute = null;
    _cachedWalkRoute = null;
  }

  // 예시 데이터 생성 메서드들 (기존 유지)
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
    // Mock 데이터에도 도로명 정보 추가
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
    final duration = (distance / 1.4).round(); // 도보 속도 1.4m/s

    return {
      'distance': distance,
      'duration': duration,
      'routes': [
        {'path': _generateSimpleWalkPath(start, end)},
      ],
    };
  }

  Future<int> getSpeedLimitFromTmap(NLatLng position) async {
    bool keysInitialized = await _initAllApiKeys();
    if (!keysInitialized) {
      return 30; // 기본값
    }

    try {
      // TMAP 속도 제한 조회 API (실제 API 엔드포인트는 TMAP 문서 확인 필요)
      final url = Uri.parse(
        'https://apis.openapi.sk.com/tmap/road/speedlimit?version=1',
      );

      final requestBody = {
        'coordX': position.longitude.toStringAsFixed(6),
        'coordY': position.latitude.toStringAsFixed(6),
        'coordType': 'WGS84GEO',
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
          .timeout(Duration(seconds: 3)); // 빠른 타임아웃

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // TMAP 응답에서 속도 제한 추출 (실제 응답 구조에 따라 수정 필요)
        if (data['speedLimit'] != null) {
          return (data['speedLimit'] as num).toInt();
        }
      }

      // API 호출 실패 시 도로명 기반 추정
      return _estimateSpeedLimitByRoadType(position);
    } catch (e) {
      print('TMAP 속도 제한 조회 오류: $e');
      return _estimateSpeedLimitByRoadType(position);
    }
  }

  // 도로 유형별 속도 제한 추정
  int _estimateSpeedLimitByRoadType(NLatLng position) {
    // 현재 위치의 도로명을 알 수 있다면 그것을 기반으로 추정
    // 또는 지역별 일반적인 속도 제한 적용

    // 한국의 일반적인 도로별 속도 제한
    // - 고속도로: 100-110km/h
    // - 자동차전용도로: 80-90km/h
    // - 대로(간선도로): 60-70km/h
    // - 일반도로: 50km/h
    // - 주택가/이면도로: 30km/h

    // 간단한 지역 기반 추정 (실제로는 더 정교한 로직 필요)
    return 30; // 기본값
  }

  // 자동차 경로의 구간별 속도 제한 정보 가져오기
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

        // 경로를 구간으로 나누어 속도 제한 조회 (너무 많은 API 호출 방지)
        final sampleInterval = max(
          1,
          pathCoordinates.length ~/ 10,
        ); // 최대 10개 구간

        for (int i = 0; i < pathCoordinates.length; i += sampleInterval) {
          final position = pathCoordinates[i];
          final speedLimit = await getSpeedLimitFromTmap(position);

          speedLimitSegments.add({
            'position': position,
            'speedLimit': speedLimit,
            'index': i,
          });

          // API 호출 간격 조절 (너무 빠른 연속 호출 방지)
          await Future.delayed(Duration(milliseconds: 100));
        }

        // 속도 제한 정보를 경로 데이터에 추가
        routeData['speedLimitSegments'] = speedLimitSegments;
      }
    }

    return routeData;
  }

  // 특정 위치에서 가장 가까운 속도 제한 정보 찾기
  int getSpeedLimitAtPosition(
    NLatLng position,
    Map<String, dynamic> routeData,
  ) {
    if (routeData['speedLimitSegments'] == null) {
      return 50; // 기본값
    }

    final segments = routeData['speedLimitSegments'] as List;
    if (segments.isEmpty) return 50;

    // 현재 위치에서 가장 가까운 구간의 속도 제한 반환
    double minDistance = double.infinity;
    int nearestSpeedLimit = 50;

    for (var segment in segments) {
      final segmentPosition = segment['position'] as NLatLng;
      final distance = _calculateDistance(position, segmentPosition);

      if (distance < minDistance) {
        minDistance = distance;
        nearestSpeedLimit = segment['speedLimit'] as int;
      }
    }

    return nearestSpeedLimit;
  }
}
