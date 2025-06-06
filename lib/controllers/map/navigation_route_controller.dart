import 'dart:async';
import 'dart:math';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:tomapto/controllers/map/transit_map_controller.dart';
import 'package:tomapto/controllers/route/route_main_controller.dart';
import 'package:tomapto/controllers/route/route_instruction_controller.dart';
import 'package:tomapto/controllers/route/route_data_controller.dart';

/// 경로 관리 및 이탈 감지를 담당하는 컨트롤러
class NavigationRouteController {
  final TransitMode mode;
  final NLatLng origin;
  final NLatLng destination;
  final RouteController _routeController = RouteController();

  // 경로 관련 변수
  List<NLatLng> _pathCoordinates = [];
  Map<String, dynamic>? _currentRouteData;
  List<RoadSegment>? _roadSegments;
  List<Map<String, dynamic>> _sectionInfo = [];
  Map<String, dynamic>? _currentSection;

  // 턴바이턴 정보 저장
  List<TurnByTurnInstruction> _turnInstructions = [];

  // 이탈 감지 관련 변수
  int _deviationCounter = 0;
  DateTime? _lastRecalculationTime;
  DateTime? _lastDeviationCheckTime;

  // 스트림 컨트롤러
  final StreamController<bool> _routeDeviationController =
      StreamController<bool>.broadcast();

  // 스트림 getter
  Stream<bool> get routeDeviationStream => _routeDeviationController.stream;

  // 경로 정보 getter
  List<NLatLng> get pathCoordinates => _pathCoordinates;
  List<Map<String, dynamic>> get sectionInfo => _sectionInfo;
  Map<String, dynamic>? get currentSection => _currentSection;
  bool get hasPathCoordinates => _pathCoordinates.isNotEmpty;

  // 턴바이턴 정보 getter
  List<TurnByTurnInstruction> getTurnInstructions() => _turnInstructions;

  NavigationRouteController(this.mode, this.origin, this.destination) {
    _fetchRouteAsync();
  }

  // 경로 비동기 로딩
  void _fetchRouteAsync() async {
    try {
      await _fetchRoute();
    } catch (e) {
      _createStraightPath();
    }
  }

  // API를 통한 경로 가져오기
  Future<void> _fetchRoute() async {
    Map<String, dynamic> routeData;

    if (mode == TransitMode.walk) {
      routeData = await Future.any([
        _routeController.searchWalkRoute(origin, destination),
        Future.delayed(
          Duration(seconds: 5),
          () => throw TimeoutException('도보 경로 타임아웃'),
        ),
      ]);
    } else {
      routeData = await Future.any([
        _routeController.searchCarRoute(origin, destination),
        Future.delayed(
          Duration(seconds: 10),
          () => throw TimeoutException('자동차 경로 타임아웃'),
        ),
      ]);
    }

    _currentRouteData = routeData;
    _processSectionInfo(routeData);
    _processRoadSegments(routeData);
    _processPathCoordinates(routeData);
    _processTurnInstructions(routeData);
  }

  // 턴바이턴 정보 처리
  void _processTurnInstructions(Map<String, dynamic> routeData) {
    if (mode == TransitMode.car && routeData['turnInstructions'] != null) {
      _turnInstructions = List<TurnByTurnInstruction>.from(
        routeData['turnInstructions'],
      );
    }
  }

  // Section 정보 처리
  void _processSectionInfo(Map<String, dynamic> routeData) {
    if (routeData['sectionInfo'] != null) {
      _sectionInfo = List<Map<String, dynamic>>.from(routeData['sectionInfo']);
    }
  }

  // 도로 구간 정보 처리
  void _processRoadSegments(Map<String, dynamic> routeData) {
    if (mode == TransitMode.car && routeData['roadSegments'] != null) {
      _roadSegments = List<RoadSegment>.from(routeData['roadSegments']);
    }
  }

  // 경로 좌표 처리
  void _processPathCoordinates(Map<String, dynamic> routeData) {
    if (routeData['routes'] != null && routeData['routes'].isNotEmpty) {
      final route = routeData['routes'][0];
      if (route['path'] != null) {
        _pathCoordinates = List<NLatLng>.from(route['path']);
      }
    }
  }

  // 직선 경로 생성
  void _createStraightPath() {
    _pathCoordinates = [origin, destination];
  }

  // 현재 Section 업데이트
  void updateCurrentSection(NLatLng position) {
    final newSection = _findCurrentSection(position);
    if (newSection != null && newSection != _currentSection) {
      _currentSection = newSection;
    }
  }

  // 현재 위치의 Section 찾기
  Map<String, dynamic>? _findCurrentSection(NLatLng currentPosition) {
    if (_sectionInfo.isEmpty) return null;

    try {
      double minDistance = double.infinity;
      Map<String, dynamic>? closestSection;

      for (var section in _sectionInfo) {
        final sectionStart = section['startPosition'] as NLatLng?;
        if (sectionStart != null) {
          final distance = _calculateDistance(currentPosition, sectionStart);
          if (distance < minDistance) {
            minDistance = distance;
            closestSection = section;
          }
        }
      }

      return closestSection;
    } catch (e) {
      return null;
    }
  }

  // 도로명 가져오기
  String getCurrentRoadName(NLatLng position) {
    final currentSection = _findCurrentSection(position);
    if (currentSection != null && currentSection['name'] != null) {
      final roadName = currentSection['name'] as String;

      // 도로명 정제
      String cleanedName = _cleanSectionRoadName(roadName);
      if (cleanedName.isNotEmpty) {
        return cleanedName;
      }
    }

    if (_currentRouteData != null) {
      return _routeController.getRoadNameAtPosition(
        position,
        _currentRouteData!,
      );
    }

    return '현재 도로';
  }

  String _cleanSectionRoadName(String rawName) {
    if (rawName.isEmpty || rawName == '0') return '';

    // 숫자만 있는 경우
    if (RegExp(r'^\d+$').hasMatch(rawName)) {
      return '${rawName}번 도로';
    }

    String cleanName =
        rawName
            .replaceAll(RegExp(r'\([^)]*\)'), '')
            .replaceAll('고속도로', '')
            .replaceAll('국도', '')
            .replaceAll('지방도', '')
            .trim();

    if (cleanName.length >= 2) {
      return cleanName;
    }

    return '';
  }

  // 정확한 남은 시간 계산
  String getAccurateRemainingTime(NLatLng currentPosition) {
    if (_sectionInfo.isEmpty || _pathCoordinates.isEmpty) {
      final remainingDistance = _calculateDistance(
        currentPosition,
        destination,
      );
      final avgSpeed = mode == TransitMode.car ? 10.0 : 1.4;
      final remainingTime = (remainingDistance / avgSpeed).round();
      return _formatDuration(remainingTime);
    }

    try {
      final currentSection = _findCurrentSection(currentPosition);
      if (currentSection == null) {
        return _formatDuration(300);
      }

      int totalRemainingTime = 0;
      bool foundCurrentSection = false;

      for (var section in _sectionInfo) {
        if (section == currentSection) {
          foundCurrentSection = true;
          final currentSectionProgress = _getCurrentSectionProgress(
            currentPosition,
            section,
          );
          final sectionDistance =
              (section['distance'] as num?)?.toDouble() ?? 0.0;
          final remainingDistanceInSection =
              sectionDistance - currentSectionProgress;
          final sectionSpeedRaw = section['speed'];

          double sectionSpeed;
          if (sectionSpeedRaw is num) {
            sectionSpeed = sectionSpeedRaw.toDouble();
          } else {
            sectionSpeed = mode == TransitMode.car ? 30.0 : 4.0;
          }

          if (sectionSpeed > 0 && remainingDistanceInSection > 0) {
            final remainingTimeInSection =
                (remainingDistanceInSection / 1000.0 / sectionSpeed * 3600)
                    .round();
            totalRemainingTime += remainingTimeInSection;
          }
        } else if (foundCurrentSection) {
          final sectionDuration = (section['duration'] as num?)?.toInt() ?? 0;
          totalRemainingTime += sectionDuration;
        }
      }

      if (totalRemainingTime <= 0) {
        totalRemainingTime = 60;
      }

      return _formatDuration(totalRemainingTime);
    } catch (e) {
      final remainingDistance = _calculateDistance(
        currentPosition,
        destination,
      );
      final avgSpeed = mode == TransitMode.car ? 10.0 : 1.4;
      final remainingTime = (remainingDistance / avgSpeed).round();
      return _formatDuration(remainingTime);
    }
  }

  // Section 진행률 계산
  double _getCurrentSectionProgress(
    NLatLng currentPosition,
    Map<String, dynamic> section,
  ) {
    try {
      final sectionStart = section['startPosition'] as NLatLng?;
      if (sectionStart == null) return 0.0;

      final progressDistance = _calculateDistance(
        sectionStart,
        currentPosition,
      );
      return progressDistance * 1000;
    } catch (e) {
      return 0.0;
    }
  }

  // 경로 이탈 감지
  void handleRouteDeviation(NLatLng currentPosition) {
    if (mode == TransitMode.walk) return;

    if (_isDeviated(currentPosition)) {
      _routeDeviationController.add(true);
    }
  }

  // 이탈 여부 확인
  bool _isDeviated(NLatLng position) {
    if (_pathCoordinates.isEmpty) return false;

    if (_lastRecalculationTime != null) {
      final timeSinceLastRecalculation =
          DateTime.now().difference(_lastRecalculationTime!).inSeconds;
      if (timeSinceLastRecalculation < 15) {
        return false;
      }
    }

    final now = DateTime.now();
    if (_lastDeviationCheckTime != null) {
      final timeSinceLastCheck =
          now.difference(_lastDeviationCheckTime!).inSeconds;
      if (timeSinceLastCheck < 3) {
        return false;
      }
    }
    _lastDeviationCheckTime = now;

    double minDistance = double.infinity;
    for (int i = 0; i < _pathCoordinates.length; i++) {
      final distance = _calculateDistance(position, _pathCoordinates[i]);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    double baseThreshold = mode == TransitMode.car ? 80.0 : 30.0;
    final deviationThreshold = baseThreshold;

    if (minDistance > deviationThreshold) {
      _deviationCounter++;
      if (_deviationCounter >= 2) {
        _deviationCounter = 0;
        _lastRecalculationTime = DateTime.now();
        return true;
      }
      return false;
    } else {
      _deviationCounter = 0;
      return false;
    }
  }

  // 경로 재계산
  Future<Map<String, dynamic>> recalculateRoute(NLatLng newOrigin) async {
    String originAddress = await getAddressFromCoordinates(newOrigin);

    try {
      Map<String, dynamic> routeData;

      if (mode == TransitMode.car) {
        routeData = await _routeController.searchCarRoute(
          newOrigin,
          destination,
        );
      } else {
        routeData = await _routeController.searchWalkRoute(
          newOrigin,
          destination,
        );
      }

      if (routeData['routes'] == null || routeData['routes'].isEmpty) {
        return {'success': false, 'newOriginAddress': originAddress};
      }

      final route = routeData['routes'][0];
      if (route['path'] == null || (route['path'] as List).isEmpty) {
        return {'success': false, 'newOriginAddress': originAddress};
      }

      List<NLatLng> pathCoordinates = List<NLatLng>.from(route['path']);
      _pathCoordinates = pathCoordinates;
      _currentRouteData = routeData;

      _processTurnInstructions(routeData);

      if (mode == TransitMode.car && routeData['roadSegments'] != null) {
        _roadSegments = List<RoadSegment>.from(routeData['roadSegments']);
      }

      return {'success': true, 'newOriginAddress': originAddress};
    } catch (e) {
      return {'success': false, 'newOriginAddress': originAddress};
    }
  }

  // 주소 변환
  Future<String> getAddressFromCoordinates(NLatLng coordinates) async {
    try {
      final address = await _routeController.getAddressFromCoords(coordinates);
      return address;
    } catch (e) {
      return '알 수 없는 위치';
    }
  }

  // 거리 계산
  double _calculateDistance(NLatLng point1, NLatLng point2) {
    const double earthRadius = 6371000;
    final double lat1 = point1.latitude * (pi / 180);
    final double lat2 = point2.latitude * (pi / 180);
    final double dLat = (point2.latitude - point1.latitude) * (pi / 180);
    final double dLon = (point2.longitude - point1.longitude) * (pi / 180);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // 시간 포맷팅
  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}초';
    } else if (seconds < 3600) {
      int minutes = (seconds / 60).ceil();
      return '${minutes}분';
    } else {
      int hours = seconds ~/ 3600;
      int minutes = ((seconds % 3600) / 60).ceil();
      return '${hours}시간 ${minutes}분';
    }
  }

  void dispose() {
    _routeDeviationController.close();
  }
}
