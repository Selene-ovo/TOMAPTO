// lib/services/korea_traffic_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

/// 한국 교통 정보 API 서비스
/// 고속도로 공공데이터포털과 국가교통정보센터 API를 활용하여
/// 실시간 도로 속도 제한 정보를 제공합니다
class KoreaTrafficApiService {
  // API 키 캐싱
  String? _expresswayCctvApiKey;
  String? _nationalTrafficApiKey;

  // API URL
  static const String _expresswayBaseUrl = 'http://data.ex.co.kr/openapi';
  static const String _nationalTrafficBaseUrl = 'http://openapi.its.go.kr:9443';

  /// API 키 초기화
  Future<bool> _initApiKeys() async {
    try {
      _expresswayCctvApiKey = dotenv.env['DATA_GO_KR_API_KEY'];
      _nationalTrafficApiKey = dotenv.env['ITS_API_KEY'];

      if (_expresswayCctvApiKey == null || _nationalTrafficApiKey == null) {
        print('한국 교통 정보 API 키가 설정되지 않았습니다.');
        return false;
      }
      return true;
    } catch (e) {
      print('API 키 초기화 오류: $e');
      return false;
    }
  }

  /// 좌표 기반 도로 정보 조회
  /// [position] - 조회할 좌표
  /// 반환값: 해당 좌표의 도로 정보
  Future<Map<String, dynamic>?> getRoadInfoByCoordinates(
    NLatLng position,
  ) async {
    bool keysInitialized = await _initApiKeys();
    if (!keysInitialized) {
      // API 키가 없으면 기본값 반환
      return _getDefaultSpeedLimitInfo(position);
    }

    try {
      // 1. 국가교통정보센터 API로 도로 정보 조회
      final roadInfo = await _getNationalTrafficRoadInfo(position);

      if (roadInfo != null && roadInfo['roadType'] == 'expressway') {
        // 2. 고속도로인 경우 고속도로 공공데이터 API 사용
        final expresswayInfo = await _getExpresswaySpeedLimit(roadInfo);
        if (expresswayInfo != null) {
          return expresswayInfo;
        }
      }

      // 3. 일반도로인 경우 국가교통정보센터 API 사용
      return roadInfo ?? _getDefaultSpeedLimitInfo(position);
    } catch (e) {
      print('도로 정보 조회 오류: $e');
      return _getDefaultSpeedLimitInfo(position);
    }
  }

  /// 기본 속도 제한 정보 생성 (API 호출 실패 시 사용)
  Map<String, dynamic> _getDefaultSpeedLimitInfo(NLatLng position) {
    return {
      'roadType': 'general',
      'speedLimit': 50, // 일반도로 기본 속도
      'roadName': '일반도로',
      'routeCode': '',
      'linkId': '',
      'maxSpeed': 50,
      'position': position,
      'source': 'default',
    };
  }

  /// 국가교통정보센터 API를 통한 도로 정보 조회
  Future<Map<String, dynamic>?> _getNationalTrafficRoadInfo(
    NLatLng position,
  ) async {
    try {
      // 좌표를 TM 좌표계로 변환
      final tmCoords = _convertWGS84ToTM(position);

      final url = Uri.parse(
        '$_nationalTrafficBaseUrl/api/LinkInfo'
        '?key=$_nationalTrafficApiKey'
        '&ReqType=2'
        '&x=${tmCoords['x']}'
        '&y=${tmCoords['y']}'
        '&type=json',
      );

      print('국가교통정보센터 API 호출: $url');

      final response = await http.get(url).timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseNationalTrafficResponse(data, position);
      } else {
        print('국가교통정보센터 API 오류: ${response.statusCode}');
      }

      return null;
    } catch (e) {
      print('국가교통정보센터 API 호출 오류: $e');
      return null;
    }
  }

  /// 고속도로 공공데이터 API를 통한 속도 제한 조회
  Future<Map<String, dynamic>?> _getExpresswaySpeedLimit(
    Map<String, dynamic> roadInfo,
  ) async {
    try {
      // 고속도로 코드나 IC 정보를 이용하여 속도 제한 조회
      final routeCode = roadInfo['routeCode'] ?? '';

      final url = Uri.parse(
        '$_expresswayBaseUrl/restinfo/restSpeedInfo'
        '?key=$_expresswayCctvApiKey'
        '&type=json'
        '&routeCode=$routeCode',
      );

      print('고속도로 공공데이터 API 호출: $url');

      final response = await http.get(url).timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseExpresswayResponse(data, roadInfo);
      } else {
        print('고속도로 공공데이터 API 오류: ${response.statusCode}');
      }

      return null;
    } catch (e) {
      print('고속도로 공공데이터 API 호출 오류: $e');
      return null;
    }
  }

  /// WGS84 좌표를 TM 좌표로 변환
  /// 국가교통정보센터 API에서 요구하는 좌표계
  Map<String, double> _convertWGS84ToTM(NLatLng wgs84) {
    // 간단한 근사 변환 공식 사용
    // 실제 프로젝트에서는 정확한 좌표 변환 라이브러리 사용 권장

    final double lat = wgs84.latitude;
    final double lng = wgs84.longitude;

    // 한국 지역에 최적화된 근사 변환
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

      // 도로 유형 판별
      String roadType = 'general';
      final linkType = linkInfo['linktype']?.toString() ?? '';

      if (linkType.contains('1') || linkType.contains('고속도로')) {
        roadType = 'expressway';
      } else if (linkType.contains('2') || linkType.contains('도시고속도로')) {
        roadType = 'urban_expressway';
      }

      // 속도 제한 정보 추출
      int speedLimit = _determineSpeedLimitByRoadType(roadType, linkInfo);

      print('도로 정보 파싱 완료: $roadType, 속도제한: ${speedLimit}km/h');

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
      print('국가교통정보센터 응답 파싱 오류: $e');
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

      print('고속도로 속도 제한 파싱 완료: ${speedLimit}km/h');

      return {
        ...roadInfo,
        'speedLimit': speedLimit,
        'trafficSpeed': speedInfo['avgSpeed'] ?? 0,
        'congestionLevel': speedInfo['congest'] ?? 0,
        'source': 'expressway_data',
      };
    } catch (e) {
      print('고속도로 공공데이터 응답 파싱 오류: $e');
      return roadInfo;
    }
  }

  /// 도로 유형별 기본 속도 제한 결정
  int _determineSpeedLimitByRoadType(
    String roadType,
    Map<String, dynamic> linkInfo,
  ) {
    // API에서 직접 제공하는 속도 제한이 있는 경우 우선 사용
    final maxSpeed = int.tryParse(linkInfo['maxspd']?.toString() ?? '');
    if (maxSpeed != null && maxSpeed > 0) {
      return maxSpeed;
    }

    // 도로 유형별 기본 속도 제한
    switch (roadType) {
      case 'expressway':
        return 100; // 고속도로
      case 'urban_expressway':
        return 80; // 도시고속도로
      case 'arterial':
        return 60; // 간선도로
      case 'collector':
        return 50; // 집산도로
      case 'local':
        return 30; // 이면도로
      default:
        return 50; // 일반도로
    }
  }

  /// 간단한 속도 제한 조회 (캐싱과 함께)
  static final Map<String, Map<String, dynamic>> _speedLimitCache = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  Future<int> getSpeedLimitAtPosition(NLatLng position) async {
    // 캐시 키 생성
    final cacheKey =
        '${position.latitude.toStringAsFixed(3)}_${position.longitude.toStringAsFixed(3)}';

    // 캐시 확인
    if (_speedLimitCache.containsKey(cacheKey)) {
      final cached = _speedLimitCache[cacheKey]!;
      final cacheTime = cached['cacheTime'] as DateTime;

      if (DateTime.now().difference(cacheTime) < _cacheExpiry) {
        return cached['speedLimit'] as int;
      } else {
        _speedLimitCache.remove(cacheKey);
      }
    }

    // API 호출
    try {
      final roadInfo = await getRoadInfoByCoordinates(position);
      final speedLimit = roadInfo?['speedLimit'] ?? 50;

      // 캐시에 저장
      _speedLimitCache[cacheKey] = {
        'speedLimit': speedLimit,
        'cacheTime': DateTime.now(),
      };

      return speedLimit;
    } catch (e) {
      print('속도 제한 조회 오류: $e');
      return 50; // 기본값
    }
  }

  /// 두 좌표 간의 거리 계산 (미터)
  double _calculateDistance(NLatLng point1, NLatLng point2) {
    const double earthRadius = 6371000;
    final double lat1Rad = point1.latitude * (3.141592653589793 / 180);
    final double lat2Rad = point2.latitude * (3.141592653589793 / 180);
    final double deltaLatRad =
        (point2.latitude - point1.latitude) * (3.141592653589793 / 180);
    final double deltaLngRad =
        (point2.longitude - point1.longitude) * (3.141592653589793 / 180);

    final double a =
        (deltaLatRad / 2) * (deltaLatRad / 2) +
        (lat1Rad) * (lat2Rad) * (deltaLngRad / 2) * (deltaLngRad / 2);
    final double c = 2 * (a / (1 + a));

    return earthRadius * c;
  }
}

/// 도로 속도 제한 정보를 담는 데이터 클래스
class SpeedLimitInfo {
  final int speedLimit;
  final String roadName;
  final String roadType;
  final NLatLng position;
  final String source;
  final int? trafficSpeed;
  final int? congestionLevel;

  SpeedLimitInfo({
    required this.speedLimit,
    required this.roadName,
    required this.roadType,
    required this.position,
    required this.source,
    this.trafficSpeed,
    this.congestionLevel,
  });

  factory SpeedLimitInfo.fromMap(Map<String, dynamic> map) {
    return SpeedLimitInfo(
      speedLimit: map['speedLimit'] ?? 50,
      roadName: map['roadName'] ?? '도로',
      roadType: map['roadType'] ?? 'general',
      position: map['position'] ?? NLatLng(37.5666805, 126.9784147),
      source: map['source'] ?? 'unknown',
      trafficSpeed: map['trafficSpeed'],
      congestionLevel: map['congestionLevel'],
    );
  }
}
