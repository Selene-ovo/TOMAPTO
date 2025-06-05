import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

/// 한국 교통 정보 API 서비스
class KoreaTrafficApiService {
  // API 키 캐싱
  String? _itsApiKey;

  // ITS OpenAPI URL
  static const String _itsBaseUrl = 'https://openapi.its.go.kr:9443';

  /// API 키 초기화
  Future<bool> _initApiKeys() async {
    try {
      _itsApiKey = dotenv.env['ITS_API_KEY'];

      if (_itsApiKey == null) {
        print('ITS API 키가 설정되지 않았습니다.');
        return false;
      }
      return true;
    } catch (e) {
      print('API 키 초기화 오류: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getRoadInfoByCoordinates(
    NLatLng position,
  ) async {
    print('=== 🛣️ 도로 정보 조회 시작 ===');

    bool keysInitialized = await _initApiKeys();
    if (!keysInitialized) {
      print('❌ API 키 초기화 실패');
      return null;
    }

    print('✅ API 키 초기화 성공');

    try {
      // VSL(Variable Speed Limit) 정보 조회
      print('1️⃣ VSL 정보 조회 시도');
      final vslInfo = await _getVslInfo(position);
      if (vslInfo != null) {
        print('✅ VSL 정보 조회 성공');
        return vslInfo;
      } else {
        print('⚠️ VSL 정보 없음');
      }

      print('❌ 모든 API 조회 실패');
      return null;
    } catch (e) {
      print('❌ 도로 정보 조회 중 오류: $e');
      return null;
    }
  }

  /// VSL(Variable Speed Limit) 정보 조회
  Future<Map<String, dynamic>?> _getVslInfo(NLatLng position) async {
    try {
      print('=== 🚦 VSL API 호출 시작 ===');
      print('📍 요청 위치: ${position.latitude}, ${position.longitude}');

      // API 키 확인
      if (_itsApiKey == null || _itsApiKey!.isEmpty) {
        print('❌ ITS API 키가 없습니다');
        return null;
      }
      print('✅ API 키 존재: ${_itsApiKey!.substring(0, 10)}...');

      // API URL
      final url = Uri.parse(
        '$_itsBaseUrl/vslInfo'
        '?apiKey=$_itsApiKey'
        '&getType=json',
      );

      print('🌐 API 호출 URL: $url');

      final response = await http.get(url).timeout(Duration(seconds: 10));

      print('📡 HTTP 응답 상태: ${response.statusCode}');
      print('📏 응답 길이: ${response.body.length} bytes');

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          print(
            '✅ 응답 받음 - 처음 200자: ${response.body.substring(0, min(200, response.body.length))}',
          );

          try {
            final data = json.decode(response.body);
            print('✅ JSON 파싱 성공');
            print('📄 전체 API 응답: $data'); // 🆕 전체 응답 로깅 추가
            return _parseVslResponse(data, position);
          } catch (e) {
            print('❌ JSON 파싱 실패: $e');
            print('📄 전체 응답 내용: ${response.body}');
            return null;
          }
        } else {
          print('❌ 응답이 비어있음');
          return null;
        }
      } else {
        print('❌ HTTP 오류: ${response.statusCode}');
        print('📄 오류 응답 내용: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ API 호출 중 예외 발생: $e');
      print('📄 예외 타입: ${e.runtimeType}');
      return null;
    }
  }

  /// VSL API 응답 파싱 (API 응답 구조에 맞게 정밀 분석)
  Map<String, dynamic>? _parseVslResponse(
    Map<String, dynamic> data,
    NLatLng position,
  ) {
    try {
      print('🔍 VSL API 전체 응답 구조 분석:');
      print('📊 최상위 키들: ${data.keys.toList()}');

      // 1. header 확인
      final header = data['header'];
      if (header != null) {
        print('📋 Header 정보: $header');
        final resultCode = header['resultCode']?.toString();
        final resultMsg = header['resultMsg']?.toString();
        print('📋 결과 코드: $resultCode, 메시지: $resultMsg');

        if (resultCode != '0' && resultCode != '00') {
          print('❌ API 오류: $resultMsg');
          return null;
        }
      }

      // 2. body 확인
      final body = data['body'];
      if (body == null) {
        print('❌ API 응답에 body가 없음');
        return null;
      }

      print('📋 Body 정보: ${body.keys.toList()}');

      final totalCount =
          int.tryParse(body['totalCount']?.toString() ?? '0') ?? 0;
      print('📊 총 데이터 개수: $totalCount');

      if (totalCount == 0) {
        print('⚠️ VSL 데이터가 없습니다.');
        return null;
      }

      // 3. items 배열 처리
      final items = body['items'];
      if (items == null) {
        print('❌ items가 없습니다.');
        return null;
      }

      List<dynamic> vslItems = [];
      if (items is List) {
        vslItems = items;
      } else {
        vslItems = [items]; // 단일 객체인 경우
      }

      print('📊 VSL 아이템 개수: ${vslItems.length}');

      // 4. 각 아이템의 구조 분석
      for (int i = 0; i < min(3, vslItems.length); i++) {
        print('📋 아이템 $i 구조: ${vslItems[i].keys.toList()}');
        print('📋 아이템 $i 내용: ${vslItems[i]}');
      }

      // 5. 가장 가까운 VSL 정보 찾기
      Map<String, dynamic>? nearestVsl;
      double minDistance = double.infinity;

      List<Map<String, dynamic>> candidates = [];

      for (var item in vslItems) {
        // 🆕 좌표 필드명 확인 및 처리
        print('📋 처리 중인 아이템: $item');

        // 가능한 좌표 필드명들 시도
        var coordX =
            item['coordX'] ?? item['x'] ?? item['lng'] ?? item['longitude'];
        var coordY =
            item['coordY'] ?? item['y'] ?? item['lat'] ?? item['latitude'];

        print('📍 좌표 원시값: X=$coordX, Y=$coordY');

        if (coordX != null && coordY != null) {
          try {
            double? parsedX = double.tryParse(coordX.toString());
            double? parsedY = double.tryParse(coordY.toString());

            if (parsedX != null && parsedY != null) {
              // 좌표 순서 확인 (X=경도, Y=위도 가정)
              final vslPosition = NLatLng(parsedY, parsedX);
              final distance = _calculateDistance(position, vslPosition);

              print(
                '📍 VSL 위치: ${vslPosition.latitude}, ${vslPosition.longitude}',
              );
              print('📏 거리: ${distance.toInt()}m');

              // 🆕 속도 제한 값 추출 및 로깅
              var limitSpeed =
                  item['limitSpeed'] ?? item['speedLimit'] ?? item['maxSpeed'];
              var defLmtSpeed = item['defLmtSpeed'] ?? item['defaultSpeed'];

              print(
                '🚦 속도 제한 원시값: limitSpeed=$limitSpeed, defLmtSpeed=$defLmtSpeed',
              );

              // 10km 이내만 고려
              if (distance <= 10000) {
                candidates.add({
                  'item': item,
                  'distance': distance,
                  'position': vslPosition,
                });
              }
            }
          } catch (e) {
            print('❌ 좌표 파싱 오류: $e');
            continue;
          }
        }
      }

      print('🎯 10km 이내 후보 개수: ${candidates.length}');

      if (candidates.isNotEmpty) {
        // 거리순으로 정렬
        candidates.sort((a, b) => a['distance'].compareTo(b['distance']));

        // 가장 가까운 후보들 출력 (디버깅용)
        print('📍 가장 가까운 VSL 후보들:');
        for (int i = 0; i < min(5, candidates.length); i++) {
          final candidate = candidates[i];
          final item = candidate['item'];
          final distance = candidate['distance'];

          // 🆕 모든 가능한 속도 필드 출력
          print('   ${i + 1}. 거리: ${distance.toInt()}m');
          print('      limitSpeed: ${item['limitSpeed']}');
          print('      defLmtSpeed: ${item['defLmtSpeed']}');
          print('      speedLimit: ${item['speedLimit']}');
          print('      maxSpeed: ${item['maxSpeed']}');
          print('      전체 아이템: $item');
        }

        // 가장 가까운 것 선택
        final bestCandidate = candidates.first;
        nearestVsl = bestCandidate['item'];
        minDistance = bestCandidate['distance'];
      }

      if (nearestVsl != null) {
        // 🆕 정밀한 속도 제한 추출
        print('🔍 선택된 VSL 아이템 상세 분석:');
        print('📄 전체 내용: $nearestVsl');

        // 가능한 모든 속도 필드 시도
        int? speedLimit;

        // 우선순위: limitSpeed > speedLimit > maxSpeed > defLmtSpeed
        var limitSpeedRaw = nearestVsl['limitSpeed'];
        var speedLimitRaw = nearestVsl['speedLimit'];
        var maxSpeedRaw = nearestVsl['maxSpeed'];
        var defLmtSpeedRaw = nearestVsl['defLmtSpeed'];

        print('🚦 속도 필드들:');
        print('   limitSpeed: $limitSpeedRaw (${limitSpeedRaw.runtimeType})');
        print('   speedLimit: $speedLimitRaw (${speedLimitRaw.runtimeType})');
        print('   maxSpeed: $maxSpeedRaw (${maxSpeedRaw.runtimeType})');
        print(
          '   defLmtSpeed: $defLmtSpeedRaw (${defLmtSpeedRaw.runtimeType})',
        );

        if (limitSpeedRaw != null) {
          speedLimit = int.tryParse(limitSpeedRaw.toString());
          print('🎯 limitSpeed 파싱 결과: $speedLimit');
        }

        if (speedLimit == null && speedLimitRaw != null) {
          speedLimit = int.tryParse(speedLimitRaw.toString());
          print('🎯 speedLimit 파싱 결과: $speedLimit');
        }

        if (speedLimit == null && maxSpeedRaw != null) {
          speedLimit = int.tryParse(maxSpeedRaw.toString());
          print('🎯 maxSpeed 파싱 결과: $speedLimit');
        }

        if (speedLimit == null && defLmtSpeedRaw != null) {
          speedLimit = int.tryParse(defLmtSpeedRaw.toString());
          print('🎯 defLmtSpeed 파싱 결과: $speedLimit');
        }

        if (speedLimit == null || speedLimit <= 0) {
          print('❌ 유효한 속도 제한 값을 찾을 수 없음');
          return null;
        }

        print('✅ 최종 속도 제한: ${speedLimit}km/h');
        print('📏 거리: ${minDistance.toInt()}m');

        return {
          'roadType': 'vsl_controlled',
          'speedLimit': speedLimit,
          'roadName': nearestVsl['roadName']?.toString() ?? 'VSL 구간',
          'roadNo': nearestVsl['roadNo']?.toString() ?? '',
          'linkId': nearestVsl['linkId']?.toString() ?? '',
          'vslId': nearestVsl['vslId']?.toString() ?? '',
          'sectionCode': nearestVsl['sectionCode']?.toString() ?? '',
          'maxSpeed': speedLimit,
          'position': position,
          'source': 'its_vsl',
          'distance': minDistance,
          'rawData': nearestVsl, // 🆕 원시 데이터 보존
        };
      } else {
        print('⚠️ 10km 이내에 VSL 정보가 없습니다.');
        return null;
      }
    } catch (e) {
      print('❌ VSL 응답 파싱 오류: $e');
      print('📄 오류 스택 트레이스: ${StackTrace.current}');
      return null;
    }
  }

  /// 간단한 속도 제한 조회
  static final Map<String, Map<String, dynamic>> _speedLimitCache = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  Future<int> getSpeedLimitAtPosition(NLatLng position) async {
    print('=== 🎯 속도 제한 조회 ===');
    print(
      '📍 위치: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
    );

    // 캐시 키 생성
    final cacheKey =
        '${position.latitude.toStringAsFixed(4)}_${position.longitude.toStringAsFixed(4)}';

    print('🔑 캐시 키: $cacheKey');

    // 캐시 확인
    if (_speedLimitCache.containsKey(cacheKey)) {
      final cached = _speedLimitCache[cacheKey]!;
      final cacheTime = cached['cacheTime'] as DateTime;

      if (DateTime.now().difference(cacheTime) < _cacheExpiry) {
        final cachedSpeed = cached['speedLimit'] as int;
        print('💾 캐시에서 조회: ${cachedSpeed}km/h');
        return cachedSpeed;
      } else {
        print('⏰ 캐시 만료 - 새로 조회');
        _speedLimitCache.remove(cacheKey);
      }
    } else {
      print('🔍 캐시 없음 - 새로 조회');
    }

    // API 호출
    try {
      print('🌐 API 호출 시작');
      final roadInfo = await getRoadInfoByCoordinates(position);

      if (roadInfo != null && roadInfo['speedLimit'] != null) {
        final speedLimit = roadInfo['speedLimit'] as int;
        print('✅ API 조회 성공: ${speedLimit}km/h');
        print('📊 상세 정보: ${roadInfo['source']}, ${roadInfo['roadName']}');

        // 캐시에 저장
        _speedLimitCache[cacheKey] = {
          'speedLimit': speedLimit,
          'cacheTime': DateTime.now(),
        };

        // 캐시 크기 제한
        _limitCacheSize();

        return speedLimit;
      } else {
        print('⚠️ API에서 유효한 속도 제한 정보를 찾을 수 없음');
        return 50; // 🆕 API 실패 시에만 기본값 사용
      }
    } catch (e) {
      print('❌ 속도 제한 조회 오류: $e');
      return 50; // 🆕 오류 시에만 기본값 사용
    }
  }

  /// 두 좌표 간의 거리 계산 (미터) - Haversine 공식
  double _calculateDistance(NLatLng point1, NLatLng point2) {
    const double earthRadius = 6371000; // 지구 반지름 (미터)

    final double lat1Rad = point1.latitude * (3.141592653589793 / 180);
    final double lat2Rad = point2.latitude * (3.141592653589793 / 180);
    final double deltaLatRad =
        (point2.latitude - point1.latitude) * (3.141592653589793 / 180);
    final double deltaLngRad =
        (point2.longitude - point1.longitude) * (3.141592653589793 / 180);

    final double a =
        (deltaLatRad / 2) * (deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * (deltaLngRad / 2) * (deltaLngRad / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// 캐시 정리 (메모리 관리)
  void clearCache() {
    _speedLimitCache.clear();
    print('속도 제한 캐시가 정리되었습니다.');
  }

  /// 캐시 크기 제한 (최대 100개 항목)
  void _limitCacheSize() {
    if (_speedLimitCache.length > 100) {
      // 가장 오래된 항목들을 제거
      final sortedEntries =
          _speedLimitCache.entries.toList()..sort((a, b) {
            final aTime = a.value['cacheTime'] as DateTime;
            final bTime = b.value['cacheTime'] as DateTime;
            return aTime.compareTo(bTime);
          });

      // 절반 제거
      for (int i = 0; i < sortedEntries.length ~/ 2; i++) {
        _speedLimitCache.remove(sortedEntries[i].key);
      }
    }
  }
}
