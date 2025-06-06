import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

/// 한국 교통 정보 API 서비스
class KoreaTrafficApiService {
  // API 키 캐싱
  String? _utisApiKey;

  // API URL
  static const String _utisBaseUrl = 'https://openapi.its.go.kr:9443';

  /// API 키 초기화
  Future<bool> _initApiKeys() async {
    try {
      _utisApiKey = dotenv.env['UTIS_API_KEY'];

      if (_utisApiKey == null) {
        print('UTIS API 키가 설정되지 않았습니다.');
        return false;
      }
      return true;
    } catch (e) {
      print('API 키 초기화 오류: $e');
      return false;
    }
  }

  /// UTIS API로 도로 정보 조회
  Future<Map<String, dynamic>?> _getUtisRoadInfo(NLatLng position) async {
    try {
      if (_utisApiKey == null || _utisApiKey!.isEmpty) {
        return null;
      }

      final url = Uri.parse(
        '$_utisBaseUrl/speedInfo'
        '?apiKey=$_utisApiKey'
        '&getType=json'
        '&lat=${position.latitude}'
        '&lng=${position.longitude}'
        '&radius=1000',
      );

      final response = await http.get(url).timeout(Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseUtisResponse(data, position);
      }

      return null;
    } catch (e) {
      print('UTIS API 호출 오류: $e');
      return null;
    }
  }

  /// UTIS API 응답 파싱
  Map<String, dynamic>? _parseUtisResponse(
    Map<String, dynamic> data,
    NLatLng position,
  ) {
    try {
      final header = data['header'];
      if (header != null) {
        final resultCode = header['resultCode']?.toString();
        if (resultCode != '0' && resultCode != '00') {
          return null;
        }
      }

      final body = data['body'];
      if (body == null) return null;

      final totalCount =
          int.tryParse(body['totalCount']?.toString() ?? '0') ?? 0;
      if (totalCount == 0) return null;

      final items = body['items'];
      if (items == null) return null;

      List<dynamic> roadItems = items is List ? items : [items];

      // 가장 가까운 도로 정보 찾기
      Map<String, dynamic>? nearestRoad;
      double minDistance = double.infinity;

      for (var item in roadItems) {
        var coordX =
            item['coordX'] ?? item['x'] ?? item['lng'] ?? item['longitude'];
        var coordY =
            item['coordY'] ?? item['y'] ?? item['lat'] ?? item['latitude'];

        if (coordX != null && coordY != null) {
          try {
            double? parsedX = double.tryParse(coordX.toString());
            double? parsedY = double.tryParse(coordY.toString());

            if (parsedX != null && parsedY != null) {
              final roadPosition = NLatLng(parsedY, parsedX);
              final distance = _calculateDistance(position, roadPosition);

              if (distance < minDistance && distance <= 2000) {
                minDistance = distance;
                nearestRoad = item;
              }
            }
          } catch (e) {
            continue;
          }
        }
      }

      if (nearestRoad != null) {
        // 속도 제한 값 추출
        int? speedLimit;

        var limitSpeedRaw =
            nearestRoad['limitSpeed'] ??
            nearestRoad['speedLimit'] ??
            nearestRoad['maxSpeed'] ??
            nearestRoad['defLmtSpeed'];

        if (limitSpeedRaw != null) {
          speedLimit = int.tryParse(limitSpeedRaw.toString());
        }

        if (speedLimit != null && speedLimit > 0) {
          return {
            'speedLimit': speedLimit,
            'roadName': nearestRoad['roadName']?.toString() ?? '도로',
            'source': 'utis',
            'distance': minDistance,
          };
        }
      }

      return null;
    } catch (e) {
      print('UTIS 응답 파싱 오류: $e');
      return null;
    }
  }

  /// 속도 제한 조회 메인 메서드
  static final Map<String, Map<String, dynamic>> _speedLimitCache = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  Future<int> getSpeedLimitAtPosition(NLatLng position) async {
    // 캐시 확인
    final cacheKey =
        '${position.latitude.toStringAsFixed(4)}_${position.longitude.toStringAsFixed(4)}';

    if (_speedLimitCache.containsKey(cacheKey)) {
      final cached = _speedLimitCache[cacheKey]!;
      final cacheTime = cached['cacheTime'] as DateTime;

      if (DateTime.now().difference(cacheTime) < _cacheExpiry) {
        return cached['speedLimit'] as int;
      } else {
        _speedLimitCache.remove(cacheKey);
      }
    }

    // API 키 초기화
    bool keysInitialized = await _initApiKeys();
    if (!keysInitialized) {
      return 50; // 기본값
    }

    try {
      // UTIS API로 속도 제한 정보 조회
      final utisInfo = await _getUtisRoadInfo(position);
      if (utisInfo != null && utisInfo['speedLimit'] != null) {
        final speedLimit = utisInfo['speedLimit'] as int;

        // 캐시에 저장
        _speedLimitCache[cacheKey] = {
          'speedLimit': speedLimit,
          'cacheTime': DateTime.now(),
        };
        _limitCacheSize();

        return speedLimit;
      }

      // UTIS API에서 정보를 찾지 못한 경우 기본값 반환
      _speedLimitCache[cacheKey] = {
        'speedLimit': 50,
        'cacheTime': DateTime.now(),
      };
      _limitCacheSize();

      return 50;
    } catch (e) {
      print('속도 제한 조회 오류: $e');
      return 50;
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
        sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// 캐시 크기 제한
  void _limitCacheSize() {
    if (_speedLimitCache.length > 100) {
      final sortedEntries =
          _speedLimitCache.entries.toList()..sort((a, b) {
            final aTime = a.value['cacheTime'] as DateTime;
            final bTime = b.value['cacheTime'] as DateTime;
            return aTime.compareTo(bTime);
          });

      for (int i = 0; i < sortedEntries.length ~/ 2; i++) {
        _speedLimitCache.remove(sortedEntries[i].key);
      }
    }
  }

  /// 캐시 정리
  void clearCache() {
    _speedLimitCache.clear();
  }
}
