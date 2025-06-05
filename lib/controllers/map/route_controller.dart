import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';

class TurnByTurnInstruction {
  final int type; // 네이버 분기점 안내 코드 (0~29)
  final String instruction; // 안내 메시지
  final NLatLng position; // 분기점 위치
  final int distance; // 이전 분기점으로부터의 거리
  final int duration; // 이전 분기점으로부터의 시간
  final IconData iconData; // 화살표 아이콘
  final String directionText; // 방향 텍스트
  final String roadName; // 도로명
  final int pointIndex; // 경로상의 인덱스

  TurnByTurnInstruction({
    required this.type,
    required this.instruction,
    required this.position,
    required this.distance,
    required this.duration,
    required this.iconData,
    required this.directionText,
    required this.roadName,
    this.pointIndex = 0,
  });

  /// 🆕 네이버 API의 guide 데이터에서 TurnByTurnInstruction 생성
  static TurnByTurnInstruction? fromNaverGuide(
    Map<String, dynamic> guide,
    List<NLatLng> pathCoordinates,
  ) {
    try {
      // 기본 정보 추출
      final distance = (guide['distance'] as num?)?.toInt() ?? 0;
      final duration = (guide['duration'] as num?)?.toInt() ?? 0;
      final instructions = guide['instructions'] as String? ?? '';
      final roadName = guide['name'] as String? ?? '';
      final pointIndex = (guide['pointIndex'] as num?)?.toInt() ?? 0;
      final guideType = (guide['type'] as num?)?.toInt() ?? 0; // 🆕 분기점 안내 코드

      print(
        '🔍 네이버 가이드 파싱: type=$guideType, pointIndex=$pointIndex, instruction=$instructions',
      );

      // 🆕 pointIndex를 통해 정확한 위치 추출
      NLatLng position;
      if (pointIndex < pathCoordinates.length) {
        position = pathCoordinates[pointIndex];
      } else {
        // pointIndex가 범위를 벗어나면 마지막 좌표 사용
        position =
            pathCoordinates.isNotEmpty ? pathCoordinates.last : NLatLng(0, 0);
      }

      // 🆕 네이버 분기점 안내 코드에 따른 아이콘과 텍스트 결정
      final iconAndText = _getIconAndTextFromNaverGuideType(
        guideType,
        instructions,
      );

      return TurnByTurnInstruction(
        type: guideType,
        instruction: instructions,
        position: position,
        distance: distance,
        duration: duration,
        iconData: iconAndText['icon'],
        directionText: iconAndText['text'],
        roadName: roadName,
        pointIndex: pointIndex,
      );
    } catch (e) {
      print('❌ 가이드 데이터 파싱 오류: $e');
      return null;
    }
  }

  /// 🆕 네이버 분기점 안내 코드에 따른 아이콘과 텍스트 결정
  static Map<String, dynamic> _getIconAndTextFromNaverGuideType(
    int type,
    String instruction,
  ) {
    switch (type) {
      case 0:
        return {'icon': Icons.arrow_upward_rounded, 'text': '직진'};
      case 1:
        return {'icon': Icons.turn_left_rounded, 'text': '좌회전'};
      case 2:
        return {'icon': Icons.turn_right_rounded, 'text': '우회전'};
      case 3:
        return {'icon': Icons.u_turn_left_rounded, 'text': 'U턴'};
      case 4:
        return {'icon': Icons.turn_slight_left_rounded, 'text': '왼쪽 방향'};
      case 5:
        return {'icon': Icons.turn_slight_right_rounded, 'text': '오른쪽 방향'};
      case 6:
        return {'icon': Icons.merge_rounded, 'text': '고속도로 진입'};
      case 7:
        return {'icon': Icons.exit_to_app_rounded, 'text': '고속도로 나가기'};
      case 8:
        return {'icon': Icons.merge_rounded, 'text': '왼쪽 고속도로 진입'};
      case 9:
        return {'icon': Icons.merge_rounded, 'text': '오른쪽 고속도로 진입'};
      case 10:
        return {'icon': Icons.exit_to_app_rounded, 'text': '왼쪽 고속도로 나가기'};
      case 11:
        return {'icon': Icons.exit_to_app_rounded, 'text': '오른쪽 고속도로 나가기'};
      case 12:
        return {'icon': Icons.arrow_upward_rounded, 'text': '고속도로 계속'};
      case 14:
        return {'icon': Icons.traffic_rounded, 'text': '터널 진입'};
      case 15:
        return {'icon': Icons.location_city_rounded, 'text': '다리'};
      case 16:
        return {'icon': Icons.keyboard_arrow_down_rounded, 'text': '지하차도'};
      case 17:
      case 18:
      case 19:
      case 20:
      case 21:
      case 22:
      case 23:
      case 24:
      case 25:
      case 26:
      case 27:
      case 28:
        final clockPosition = type - 16;
        return {
          'icon': Icons.roundabout_right_rounded,
          'text': '로터리 ${clockPosition}시 방향',
        };
      case 29:
        return {'icon': Icons.location_on_rounded, 'text': '목적지 도착'};
      default:
        return _analyzeInstructionText(instruction);
    }
  }

  /// instruction 텍스트 분석으로 방향 결정 (fallback)
  static Map<String, dynamic> _analyzeInstructionText(String instruction) {
    final lowerInstruction = instruction.toLowerCase();

    if (lowerInstruction.contains('좌회전') || lowerInstruction.contains('왼쪽')) {
      return {'icon': Icons.turn_left_rounded, 'text': '좌회전'};
    }
    if (lowerInstruction.contains('우회전') || lowerInstruction.contains('오른쪽')) {
      return {'icon': Icons.turn_right_rounded, 'text': '우회전'};
    }
    if (lowerInstruction.contains('유턴') || lowerInstruction.contains('u턴')) {
      return {'icon': Icons.u_turn_left_rounded, 'text': 'U턴'};
    }

    return {'icon': Icons.arrow_upward_rounded, 'text': '직진'};
  }

  @override
  String toString() {
    return 'TurnByTurnInstruction(type: $type, directionText: $directionText, distance: ${distance}m, pointIndex: $pointIndex)';
  }
}

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

  // 경로 캐시 (기존 유지)
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

    _routeCache.removeWhere((key, value) {
      final cacheTime = value['cacheTime'] as DateTime;
      return now.difference(cacheTime) > _cacheExpiry;
    });

    _walkRouteCache.removeWhere((key, value) {
      final cacheTime = value['cacheTime'] as DateTime;
      return now.difference(cacheTime) > _walkCacheExpiry;
    });
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

  // 기존 메서드들 (TMAP 포함하여 모두 유지)
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
      print('🚗 네이버 자동차 경로 API 호출 (분기점 정보 포함)');

      final url = Uri.parse(
        '$_cachedApiUrl/driving?'
        'start=${start.longitude},${start.latitude}&'
        'goal=${end.longitude},${end.latitude}&'
        'option=trafast',
      );

      print('🌐 요청 URL: $url');

      final response = await http
          .get(
            url,
            headers: {
              'X-NCP-APIGW-API-KEY-ID': _cachedApiKey!,
              'X-NCP-APIGW-API-KEY': _cachedSecretKey!,
            },
          )
          .timeout(Duration(seconds: 8));

      print('📡 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📄 API 응답 구조: ${data.keys.toList()}');

        if (data['route'] != null && data['route']['trafast'] != null) {
          final route = data['route']['trafast'][0];
          print('📄 Route 구조: ${route.keys.toList()}');

          // 1. 경로 좌표 추출
          final pathCoordinates = _extractPathCoordinates(route);
          print('✅ 경로 좌표 추출 완료: ${pathCoordinates.length}개');

          // 2. 🆕 분기점 정보 추출 (네이버 API guide 사용)
          final turnInstructions = _extractTurnInstructions(
            route,
            pathCoordinates,
          );
          print('✅ 분기점 정보 추출 완료: ${turnInstructions.length}개');

          // 3. 도로 구간 정보 추출
          final roadSegments = _parseRoadSegments(data);
          print('✅ 도로 구간 정보 추출 완료: ${roadSegments.length}개');

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
            'turnInstructions': turnInstructions, // 🆕 네이버 분기점 정보
          };

          _saveToCache(cacheKey, routeData);
          _cachedCarRoute = routeData;

          print('🎉 네이버 분기점 API 적용 경로 완성!');
          print('   - 경로 좌표: ${pathCoordinates.length}개');
          print('   - 분기점: ${turnInstructions.length}개');
          print('   - 도로 구간: ${roadSegments.length}개');

          return routeData;
        }
      }

      print('⚠️ 네이버 API 응답 이상 - Mock 데이터 사용');
      return _getMockCarRouteData(start, end);
    } catch (e) {
      print('❌ 자동차 경로 검색 오류: $e');
      return _getMockCarRouteData(start, end);
    }
  }

  List<NLatLng> _extractPathCoordinates(Map<String, dynamic> route) {
    final List<NLatLng> pathCoordinates = [];

    if (route['path'] != null) {
      final path = route['path'] as List;

      if (path.isNotEmpty && path[0] is! List) {
        // 평면 배열: [lng1, lat1, lng2, lat2, ...]
        for (int i = 0; i < path.length; i += 2) {
          if (i + 1 < path.length) {
            double longitude = (path[i] as num).toDouble();
            double latitude = (path[i + 1] as num).toDouble();
            pathCoordinates.add(NLatLng(latitude, longitude));
          }
        }
      } else {
        // 중첩 배열: [[lng1, lat1], [lng2, lat2], ...]
        for (var point in path) {
          if (point is List && point.length >= 2) {
            double longitude = (point[0] as num).toDouble();
            double latitude = (point[1] as num).toDouble();
            pathCoordinates.add(NLatLng(latitude, longitude));
          }
        }
      }
    }

    return pathCoordinates;
  }

  /// 🆕 네이버 API guide에서 분기점 정보 추출
  List<TurnByTurnInstruction> _extractTurnInstructions(
    Map<String, dynamic> route,
    List<NLatLng> pathCoordinates,
  ) {
    List<TurnByTurnInstruction> instructions = [];

    try {
      if (route['guide'] != null) {
        final guides = route['guide'] as List;
        print('📋 Guide 정보 발견: ${guides.length}개');

        for (int i = 0; i < guides.length; i++) {
          final guide = guides[i];
          print('📋 Guide $i: ${guide.keys.toList()}');
          print('📋 Guide $i 내용: $guide');

          final instruction = TurnByTurnInstruction.fromNaverGuide(
            guide,
            pathCoordinates,
          );
          if (instruction != null) {
            instructions.add(instruction);
            print(
              '✅ 분기점 ${i + 1} 생성: ${instruction.directionText} (타입: ${instruction.type})',
            );
          }
        }
      } else {
        print('⚠️ Guide 정보 없음');
      }

      // guide가 없으면 section으로 기본 분기점 생성
      if (instructions.isEmpty && route['section'] != null) {
        print('📋 Section 기반으로 기본 분기점 생성');
        final sections = route['section'] as List;

        for (int i = 0; i < sections.length; i++) {
          final section = sections[i];
          final roadName = section['name']?.toString() ?? '도로';
          final distance = (section['distance'] as num?)?.toInt() ?? 0;

          if (distance > 100) {
            // 100m 이상인 구간만
            // 구간 시작점을 분기점으로 설정
            final pointIndex = i * (pathCoordinates.length ~/ sections.length);
            final position =
                pointIndex < pathCoordinates.length
                    ? pathCoordinates[pointIndex]
                    : pathCoordinates.last;

            instructions.add(
              TurnByTurnInstruction(
                type: 0, // 직진
                instruction: '${roadName}으로 계속 이동',
                position: position,
                distance: distance,
                duration: (section['duration'] as num?)?.toInt() ?? 0,
                iconData: Icons.arrow_upward_rounded,
                directionText: '직진',
                roadName: roadName,
                pointIndex: pointIndex,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('❌ 분기점 정보 추출 오류: $e');
    }

    return instructions;
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
