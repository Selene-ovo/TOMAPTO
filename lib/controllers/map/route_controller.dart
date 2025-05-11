import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  // 주소 검색용 API 키 캐싱 (address_controller에서 이동)
  String? _cachedClientId;
  String? _cachedClientSecret;

  // 마지막으로 계산된 경로 캐싱
  List<RouteData>? _cachedPublicTransportRoutes;
  Map<String, dynamic>? _cachedCarRoute;
  Map<String, dynamic>? _cachedWalkRoute;

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

  // 주소 검색 기능 (address_controller에서 이동)
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
      final response = await http.get(
        url,
        headers: {
          'X-Naver-Client-Id': _cachedClientId!,
          'X-Naver-Client-Secret': _cachedClientSecret!,
        },
      );

      print('로컬 검색 응답 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);

        if (data['items'] != null && data['items'].isNotEmpty) {
          print('로컬 검색 결과 수: ${data['items'].length}');

          // 로컬 검색 결과를 간단한 형식으로 변환
          return data['items'].map<Map<String, dynamic>>((item) {
            // HTML 태그 제거
            String title = item['title'].replaceAll(RegExp(r'<[^>]*>'), '');

            return {
              'name': title,
              'address': item['roadAddress'] ?? item['address'] ?? '',
              'x': item['mapx'] ?? '0', // 경도
              'y': item['mapy'] ?? '0', // 위도
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

  // 주소-좌표 변환 (address_controller에서 이동)
  NLatLng convertAddressToCoords(Map<String, dynamic> searchResult) {
    try {
      // 네이버 지도 API의 좌표는 경위도에 10^7을 곱한 값을 사용
      double x = double.parse(searchResult['x']) / 10000000.0;
      double y = double.parse(searchResult['y']) / 10000000.0;

      return NLatLng(y, x); // NLatLng는 (위도, 경도) 순서
    } catch (e) {
      print('좌표 변환 오류: $e');
      // 기본값으로 서울시청 좌표 반환
      return NLatLng(37.5666805, 126.9784147);
    }
  }

  // 좌표-주소 변환 (간단 버전)
  Future<String> getAddressFromCoords(NLatLng position) async {
    // API 키 확인
    bool keysInitialized = await _initAllApiKeys();
    if (!keysInitialized) {
      return '서울특별시 강남구'; // 기본 주소
    }

    final url =
        'https://maps.apigw.ntruss.com/map-reversegeocode/v2/gc?'
        'coords=${position.longitude},${position.latitude}&output=json';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-NCP-APIGW-API-KEY-ID': _cachedApiKey!,
          'X-NCP-APIGW-API-KEY': _cachedSecretKey!,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);

        if (data['results'] != null && data['results'].isNotEmpty) {
          // 간단한 주소 파싱
          return _parseSimpleAddress(data);
        }
      }

      return '강원특별자치도 강릉시'; // 기본 주소
    } catch (e) {
      print('주소 변환 오류: $e');
      return '강원특별자치도 강릉시';
    }
  }

  // 간단한 주소 파싱
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

      // 도로명 주소가 없으면 법정동 주소 사용
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

  // TMAP API를 사용한 도보 경로 검색 메서드
  Future<Map<String, dynamic>> searchWalkRouteWithTmap(
    NLatLng start,
    NLatLng end,
  ) async {
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
        'startX': start.longitude.toString(),
        'startY': start.latitude.toString(),
        'endX': end.longitude.toString(),
        'endY': end.latitude.toString(),
        'reqCoordType': 'WGS84GEO',
        'resCoordType': 'WGS84GEO',
        'startName': '출발지',
        'endName': '도착지',
      };

      print('TMAP 도보 경로 요청 URL: $url');
      print('요청 파라미터: $requestBody');

      // API 호출
      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
          'appKey': _cachedTmapApiKey!,
        },
        body: Uri(queryParameters: requestBody).query,
      );

      print('TMAP 도보 경로 응답 상태 코드: ${response.statusCode}');
      print('TMAP 도보 경로 응답 내용: ${response.body}');

      if (response.statusCode == 200) {
        // JSON 응답 처리
        final data = json.decode(response.body);

        // TMAP 응답 파싱
        if (data['features'] != null) {
          final features = data['features'] as List;
          final List<NLatLng> pathCoordinates = [];
          int totalTime = 0;
          int totalDistance = 0;

          // 모든 feature를 순회하며 경로 좌표 추출
          for (var feature in features) {
            final geometry = feature['geometry'];
            final properties = feature['properties'];

            // 시간과 거리 정보 추출
            if (properties != null) {
              if (properties['totalTime'] != null) {
                final totalTimeValue = properties['totalTime'] as num;
                totalTime = totalTimeValue.round();
              }

              if (properties['totalDistance'] != null) {
                totalDistance = (properties['totalDistance'] as num).round();
              }
            }

            // LineString 타입일 때 좌표 추출
            if (geometry['type'] == 'LineString') {
              final coordinates = geometry['coordinates'] as List;
              for (var coord in coordinates) {
                if (coord is List && coord.length >= 2) {
                  double longitude = (coord[0] as num).toDouble();
                  double latitude = (coord[1] as num).toDouble();
                  pathCoordinates.add(NLatLng(latitude, longitude));
                }
              }
            }
            // Point 타입일 때는 단일 좌표
            else if (geometry['type'] == 'Point') {
              final coordinates = geometry['coordinates'] as List;
              if (coordinates.length >= 2) {
                double longitude = (coordinates[0] as num).toDouble();
                double latitude = (coordinates[1] as num).toDouble();
                pathCoordinates.add(NLatLng(latitude, longitude));
              }
            }
          }

          // 캐시에 저장
          _cachedWalkRoute = {
            'routes': [
              {'path': pathCoordinates},
            ],
            'distance': totalDistance,
            'duration': totalTime,
          };

          return _cachedWalkRoute!;
        }
      }

      return _getMockWalkRouteData(start, end);
    } catch (e) {
      print('TMAP 도보 경로 검색 오류: $e');
      return _getMockWalkRouteData(start, end);
    }
  }

  // 기존 메서드들은 그대로 유지
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

      final response = await http.get(
        url,
        headers: {
          'X-NCP-APIGW-API-KEY-ID': _cachedApiKey!,
          'X-NCP-APIGW-API-KEY': _cachedSecretKey!,
        },
      );

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

          _cachedCarRoute = {
            'routes': [
              {'path': pathCoordinates, 'summary': route['summary']},
            ],
            'distance': route['summary']?['distance'] ?? 0,
            'duration': (route['summary']?['duration'] ?? 0) ~/ 1000,
            'toll': route['summary']?['tollFare'] ?? 0,
          };

          return _cachedCarRoute!;
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

  // 예시 데이터 생성 메서드들
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
    return {
      'distance': 1200,
      'duration': 840,
      'routes': [
        {
          'path': [
            start,
            NLatLng(start.latitude + 0.001, start.longitude + 0.002),
            NLatLng(start.latitude + 0.002, start.longitude + 0.003),
            NLatLng(start.latitude + 0.003, start.longitude + 0.004),
            end,
          ],
          'segments': [
            {'name': '강남대로', 'distance': 500, 'duration': 350},
            {'name': '역삼로', 'distance': 700, 'duration': 490},
          ],
        },
      ],
    };
  }
}
