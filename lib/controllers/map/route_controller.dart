import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  // API 키 캐싱
  String? _cachedApiKey;
  String? _cachedSecretKey;

  // 마지막으로 계산된 경로 캐싱
  List<RouteData>? _cachedPublicTransportRoutes;
  Map<String, dynamic>? _cachedCarRoute;
  Map<String, dynamic>? _cachedWalkRoute;

  // API 키 초기화
  Future<bool> _initApiKeys() async {
    if (_cachedApiKey != null && _cachedSecretKey != null) {
      return true;
    }

    _cachedApiKey = dotenv.env['NAVER_API_KEY'];
    _cachedSecretKey = dotenv.env['NAVER_SECRET_KEY'];

    if (_cachedApiKey == null || _cachedSecretKey == null) {
      print('네이버 API 키가 설정되지 않았습니다.');
      return false;
    }
    return true;
  }

  // 대중교통 경로 검색
  Future<List<RouteData>> searchPublicTransportRoutes(
    String start,
    String end,
  ) async {
    // 이미 캐시된 결과가 있으면 반환
    if (_cachedPublicTransportRoutes != null) {
      return _cachedPublicTransportRoutes!;
    }

    // API 키 확인
    bool keysInitialized = await _initApiKeys();
    if (!keysInitialized) {
      // 실제 API 호출 실패 시, 예시 데이터 반환
      return _getMockPublicTransportData();
    }

    try {
      // 실제로는 네이버 경로 검색 API 호출 필요
      // 여기서는 예시 코드만 작성
      /*
      final url = Uri.parse(
        'https://naveropenapi.apigw.ntruss.com/map-direction/v1/transit?'
        'start=${Uri.encodeComponent(start)}&goal=${Uri.encodeComponent(end)}'
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
        // 응답 파싱 로직 필요
      }
      */

      // 지금은 예시 데이터 반환
      _cachedPublicTransportRoutes = _getMockPublicTransportData();
      return _cachedPublicTransportRoutes!;
    } catch (e) {
      print('대중교통 경로 검색 오류: $e');
      return _getMockPublicTransportData();
    }
  }

  // 자동차 경로 검색
  Future<Map<String, dynamic>> searchCarRoute(
    NLatLng start,
    NLatLng end,
  ) async {
    // 이미 캐시된 결과가 있으면 반환
    if (_cachedCarRoute != null) {
      return _cachedCarRoute!;
    }

    // API 키 확인
    bool keysInitialized = await _initApiKeys();
    if (!keysInitialized) {
      return _getMockCarRouteData(start, end);
    }

    try {
      // 실제로는 네이버 자동차 경로 검색 API 호출
      // 여기서는 예시 코드만 작성
      /*
      final url = Uri.parse(
        'https://naveropenapi.apigw.ntruss.com/map-direction/v1/driving?'
        'start=${start.longitude},${start.latitude}&goal=${end.longitude},${end.latitude}'
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
        // 응답 파싱 로직 필요
      }
      */

      // 지금은 예시 데이터 반환
      _cachedCarRoute = _getMockCarRouteData(start, end);
      return _cachedCarRoute!;
    } catch (e) {
      print('자동차 경로 검색 오류: $e');
      return _getMockCarRouteData(start, end);
    }
  }

  // 도보 경로 검색
  Future<Map<String, dynamic>> searchWalkRoute(
    NLatLng start,
    NLatLng end,
  ) async {
    // 이미 캐시된 결과가 있으면 반환
    if (_cachedWalkRoute != null) {
      return _cachedWalkRoute!;
    }

    // API 키 확인
    bool keysInitialized = await _initApiKeys();
    if (!keysInitialized) {
      return _getMockWalkRouteData(start, end);
    }

    try {
      // 실제로는 네이버 도보 경로 검색 API 호출
      // 여기서는 예시 코드만 작성
      /*
      final url = Uri.parse(
        'https://naveropenapi.apigw.ntruss.com/map-direction/v1/pedestrian?'
        'start=${start.longitude},${start.latitude}&goal=${end.longitude},${end.latitude}'
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
        // 응답 파싱 로직 필요
      }
      */

      // 지금은 예시 데이터 반환
      _cachedWalkRoute = _getMockWalkRouteData(start, end);
      return _cachedWalkRoute!;
    } catch (e) {
      print('도보 경로 검색 오류: $e');
      return _getMockWalkRouteData(start, end);
    }
  }

  // 캐시 무효화 (출발지/도착지 변경 시 호출)
  void invalidateCache() {
    _cachedPublicTransportRoutes = null;
    _cachedCarRoute = null;
    _cachedWalkRoute = null;
  }

  // 예시 대중교통 데이터
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

  // 예시 자동차 경로 데이터
  Map<String, dynamic> _getMockCarRouteData(NLatLng start, NLatLng end) {
    return {
      'distance': 5000, // 미터 단위
      'duration': 900, // 초 단위 (15분)
      'toll': 0, // 통행료
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

  // 예시 도보 경로 데이터
  Map<String, dynamic> _getMockWalkRouteData(NLatLng start, NLatLng end) {
    return {
      'distance': 1200, // 미터 단위
      'duration': 840, // 초 단위 (14분)
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
