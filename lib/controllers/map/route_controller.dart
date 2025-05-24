import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

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

          final routeData = {
            'routes': [
              {'path': pathCoordinates, 'summary': route['summary']},
            ],
            'distance': route['summary']?['distance'] ?? 0,
            'duration': (route['summary']?['duration'] ?? 0) ~/ 1000,
            'toll': route['summary']?['tollFare'] ?? 0,
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
          'segments': [
            {'name': '강남대로', 'distance': 2000, 'duration': 360},
            {'name': '테헤란로', 'distance': 3000, 'duration': 540},
          ],
        },
      ],
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
}
