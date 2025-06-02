import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tomapto/controllers/map/transit_map_controller.dart';
import 'package:tomapto/controllers/map/route_controller.dart';
import 'package:tomapto/services/korea_traffic_api_service.dart'; // 새로 추가

class NavigationController {
  // 모드 (자동차/도보)
  final TransitMode mode;

  // 네이버 맵 컨트롤러
  NaverMapController? _mapController;

  // 오버레이 객체들
  NPathOverlay? _routePathOverlay;
  NMarker? _destinationMarker;
  NMarker? _currentLocationMarker;

  // 도로명 정보 저장
  List<RoadSegment>? _roadSegments;
  Map<String, dynamic>? _currentRouteData;

  // 경로 좌표 리스트
  List<NLatLng> _pathCoordinates = [];

  // 출발지와 목적지 좌표
  final NLatLng _origin;
  final NLatLng _destination;

  // 경로 컨트롤러
  final RouteController _routeController = RouteController();

  // 🆕 한국 교통 정보 API 서비스 추가
  final KoreaTrafficApiService _koreaTrafficService = KoreaTrafficApiService();

  // 이탈 감지 관련 변수들
  int _deviationCounter = 0;
  DateTime? _lastRecalculationTime;

  // 위치 추적 스트림 구독 객체
  StreamSubscription<Position>? _positionStreamSubscription;

  // 마커 색상 설정
  late final Color _startMarkerColor;
  late final Color _destinationMarkerColor;
  late final Color _currentLocationColor;

  // 현재 위치 (GPS)
  NLatLng? _currentPosition;

  // 현재 속도 (km/h)
  double _currentSpeed = 0;

  // 🆕 현재 도로의 실제 속도 제한 (한국 교통 정보 API에서 가져옴)
  int _actualSpeedLimit = 30;

  // 🆕 속도 제한 업데이트 관련 변수
  DateTime? _lastSpeedLimitUpdate;
  NLatLng? _lastSpeedLimitPosition;

  // 턴바이턴 정보
  List<Map<String, dynamic>> _turnByTurnInstructions = [];
  Map<String, dynamic>? _currentInstruction;
  Map<String, dynamic>? _nextInstruction;

  // 현재 방향 정보 저장 변수
  double _currentHeading = 0.0;

  // 현재 방향 정보 getter
  double getCurrentHeading() {
    return _currentHeading;
  }

  double _lastHeading = 0.0;
  static const double _headingThreshold = 10.0;

  // 스트림 컨트롤러들
  final StreamController<Map<String, dynamic>> _navigationInfoController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<NLatLng> _locationController =
      StreamController<NLatLng>.broadcast();
  final StreamController<bool> _routeDeviationController =
      StreamController<bool>.broadcast();
  final StreamController<void> _arrivalController =
      StreamController<void>.broadcast();
  final StreamController<Map<String, dynamic>> _turnByTurnController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<int> _speedLimitController =
      StreamController<int>.broadcast();

  // 스트림 getter
  Stream<Map<String, dynamic>> get navigationInfoStream =>
      _navigationInfoController.stream;
  Stream<NLatLng> get locationStream => _locationController.stream;
  Stream<bool> get routeDeviationStream => _routeDeviationController.stream;
  Stream<void> get arrivalStream => _arrivalController.stream;
  Stream<Map<String, dynamic>> get turnByTurnStream =>
      _turnByTurnController.stream;
  Stream<int> get speedLimitStream => _speedLimitController.stream;

  // 경로 로딩 상태
  bool _isRouteLoading = false;
  bool get isRouteLoading => _isRouteLoading;

  // 경로 좌표가 로드되었는지 확인
  bool hasPathCoordinates() {
    return _pathCoordinates.isNotEmpty;
  }

  // 경로 오버레이가 생성되었는지 확인
  bool hasPathOverlay() {
    return _routePathOverlay != null;
  }

  // 현재 로딩된 경로를 다시 표시
  void displayCurrentPath() {
    if (_pathCoordinates.isNotEmpty) {
      displayPathOverlay(_pathCoordinates);
    }
  }

  // 생성자
  NavigationController(this.mode, this._origin, this._destination) {
    // 모드에 따른 마커 색상 설정
    if (mode == TransitMode.car) {
      _startMarkerColor = Color(0xFF00C73C);
      _destinationMarkerColor = Color(0xFFFF5F4A);
      _currentLocationColor = Color(0xFF4A82FF);
    } else {
      _startMarkerColor = Color(0xFF00C73C);
      _destinationMarkerColor = Color(0xFFFF5F4A);
      _currentLocationColor = Color(0xFF4A82FF);
    }

    // 현재 위치 초기화
    _currentPosition = _origin;

    // 경로 탐색 (비동기 호출)
    _fetchRouteAsync();
  }

  void _fetchRouteAsync() async {
    _isRouteLoading = true;
    try {
      await _fetchRoute();
    } finally {
      _isRouteLoading = false;
    }
  }

  // 🆕 한국 교통 정보 API를 사용한 실제 속도 제한 업데이트
  Future<void> _updateActualSpeedLimit(NLatLng position) async {
    // 너무 자주 호출하지 않도록 제한 (30초마다 한 번, 또는 200m 이상 이동했을 때)
    final now = DateTime.now();

    bool shouldUpdate = false;

    if (_lastSpeedLimitUpdate == null) {
      shouldUpdate = true;
    } else {
      // 시간 조건: 30초 경과
      final timeDiff = now.difference(_lastSpeedLimitUpdate!).inSeconds;

      // 거리 조건: 200m 이상 이동
      double distanceDiff = 0;
      if (_lastSpeedLimitPosition != null) {
        distanceDiff = _calculateDistance(_lastSpeedLimitPosition!, position);
      }

      if (timeDiff >= 30 || distanceDiff >= 200) {
        shouldUpdate = true;
      }
    }

    if (!shouldUpdate) return;

    try {
      print('🚦 실제 속도 제한 조회 시작: ${position.latitude}, ${position.longitude}');

      // 한국 교통 정보 API로 실제 속도 제한 조회
      final speedLimit = await _koreaTrafficService.getSpeedLimitAtPosition(
        position,
      );

      if (speedLimit != _actualSpeedLimit) {
        _actualSpeedLimit = speedLimit;
        _speedLimitController.add(_actualSpeedLimit);

        print('🚦 실제 속도 제한 업데이트: ${_actualSpeedLimit}km/h');
        print(
          '📍 위치: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
        );
      }

      // 마지막 업데이트 시간과 위치 저장
      _lastSpeedLimitUpdate = now;
      _lastSpeedLimitPosition = position;
    } catch (e) {
      print('❌ 실제 속도 제한 조회 오류: $e');
      // 오류 발생 시 기본값 사용
      if (_actualSpeedLimit == 30) {
        // 이미 기본값이면 변경하지 않음
      } else {
        _actualSpeedLimit = 30;
        _speedLimitController.add(_actualSpeedLimit);
      }
    }
  }

  Future<Map<String, dynamic>> _getRouteData() async {
    if (mode == TransitMode.car) {
      return await _routeController.searchCarRoute(_origin, _destination);
    } else {
      return await _routeController.searchWalkRoute(_origin, _destination);
    }
  }

  void _createStraightPathFast() {
    _pathCoordinates = [_origin, _destination];

    if (_mapController != null) {
      displayPathOverlay(_pathCoordinates);
    }

    _createBasicInstructions();
  }

  void _createBasicInstructions() {
    _turnByTurnInstructions = [
      {
        'direction': "목적지로 이동",
        'directionIcon': Icons.navigation,
        'point': _destination,
        'distance': _calculateDistance(_origin, _destination).round(),
        'nextDistance': 0,
        'roadName': "직선 경로",
        'index': 1,
      },
    ];

    if (_turnByTurnInstructions.isNotEmpty) {
      _currentInstruction = _turnByTurnInstructions.first;
      _turnByTurnController.add(_currentInstruction!);
    }
  }

  void _generateTurnByTurnInstructionsAsync() {
    Future.microtask(() {
      _generateTurnByTurnInstructions();
    });
  }

  void _generateSimpleWalkInstructions() {
    _turnByTurnInstructions = [];

    if (_pathCoordinates.length < 2) return;

    final distance = _calculateDistance(_origin, _destination);

    _turnByTurnInstructions.add({
      'direction': "목적지로 걸어가세요",
      'directionIcon': Icons.directions_walk,
      'point': _destination,
      'distance': distance.round(),
      'nextDistance': 0,
      'roadName': "도보 경로",
      'index': 0,
      'distanceToPoint': distance.round(),
    });

    if (_turnByTurnInstructions.isNotEmpty) {
      _currentInstruction = _turnByTurnInstructions.first;
      _turnByTurnController.add(_currentInstruction!);
    }
  }

  // API를 사용해 경로 가져오기
  Future<void> _fetchRoute() async {
    print('경로 요청 시작: ${DateTime.now()}');

    try {
      Map<String, dynamic> routeData;

      if (mode == TransitMode.walk) {
        routeData = await Future.any([
          _routeController.searchWalkRoute(_origin, _destination),
          Future.delayed(
            Duration(seconds: 5),
            () => throw TimeoutException('도보 경로 타임아웃'),
          ),
        ]);
      } else {
        routeData = await Future.any([
          _routeController.searchCarRoute(_origin, _destination),
          Future.delayed(
            Duration(seconds: 10),
            () => throw TimeoutException('자동차 경로 타임아웃'),
          ),
        ]);
      }

      _currentRouteData = routeData;

      if (mode == TransitMode.car && routeData['roadSegments'] != null) {
        _roadSegments = List<RoadSegment>.from(routeData['roadSegments']);
        print('도로명 정보 로딩 완료: ${_roadSegments!.length}개 구간');
      }

      if (routeData['routes'] != null && routeData['routes'].isNotEmpty) {
        final route = routeData['routes'][0];
        if (route['path'] != null) {
          _pathCoordinates = List<NLatLng>.from(route['path']);
          print('경로 로딩 완료: ${_pathCoordinates.length}개 좌표');

          if (mode == TransitMode.walk) {
            print('도보 모드: 턴바이턴 지시 생성 안 함');
          } else {
            _generateTurnByTurnInstructionsAsync();
          }

          if (_mapController != null) {
            displayPathOverlay(_pathCoordinates);
          }
        }
      }
    } catch (e) {
      print('경로 가져오기 오류: $e');
      _createStraightPathFast();
    }
  }

  void _generateTurnByTurnInstructions() {
    _turnByTurnInstructions = [];

    if (_pathCoordinates.length < 3) return;

    for (int i = 1; i < _pathCoordinates.length - 1; i++) {
      double angle = _calculateAngleBetweenThreePoints(
        _pathCoordinates[i - 1],
        _pathCoordinates[i],
        _pathCoordinates[i + 1],
      );

      String direction = "직진";
      IconData directionIcon = Icons.arrow_upward_rounded;

      if (angle > 60 && angle <= 120) {
        direction = "우회전";
        directionIcon = Icons.turn_right_rounded;
      } else if (angle > 120) {
        direction = "급우회전";
        directionIcon = Icons.turn_right_rounded;
      } else if (angle < -60 && angle >= -120) {
        direction = "좌회전";
        directionIcon = Icons.turn_left_rounded;
      } else if (angle < -120) {
        direction = "급좌회전";
        directionIcon = Icons.turn_left_rounded;
      } else if (angle > 30 && angle <= 60) {
        direction = "우측으로";
        directionIcon = Icons.turn_slight_right_rounded;
      } else if (angle < -30 && angle >= -60) {
        direction = "좌측으로";
        directionIcon = Icons.turn_slight_left_rounded;
      }

      if (direction != "직진" || _turnByTurnInstructions.isEmpty) {
        double distance =
            i > 0
                ? _calculateDistance(
                  _pathCoordinates[i - 1],
                  _pathCoordinates[i],
                )
                : 0;

        double nextDistance =
            i < _pathCoordinates.length - 1
                ? _calculateDistance(
                  _pathCoordinates[i],
                  _pathCoordinates[i + 1],
                )
                : 0;

        String roadName = _getRoadNameForPosition(_pathCoordinates[i]);

        _turnByTurnInstructions.add({
          'direction': direction,
          'directionIcon': directionIcon,
          'point': _pathCoordinates[i],
          'distance': distance.round(),
          'nextDistance': nextDistance.round(),
          'roadName': roadName,
          'index': i,
        });
      }
    }

    if (_turnByTurnInstructions.isNotEmpty) {
      final lastIndex = _turnByTurnInstructions.last['index'];

      if (lastIndex < _pathCoordinates.length - 2) {
        double distance = _calculateDistance(
          _pathCoordinates[lastIndex],
          _pathCoordinates.last,
        );

        _turnByTurnInstructions.add({
          'direction': "목적지",
          'directionIcon': Icons.location_on,
          'point': _pathCoordinates.last,
          'distance': distance.round(),
          'nextDistance': 0,
          'roadName': "도착",
          'index': _pathCoordinates.length - 1,
        });
      }
    }

    for (var instruction in _turnByTurnInstructions) {
      print(
        '턴바이턴 지시: ${instruction['direction']}, 거리: ${instruction['distance']}m, 도로: ${instruction['roadName']}',
      );
    }

    if (_turnByTurnInstructions.isNotEmpty) {
      _currentInstruction = _turnByTurnInstructions.first;

      if (_turnByTurnInstructions.length > 1) {
        _nextInstruction = _turnByTurnInstructions[1];
      }

      _turnByTurnController.add(_currentInstruction!);
    }
  }

  String _getRoadNameForPosition(NLatLng position) {
    if (mode == TransitMode.car &&
        _roadSegments != null &&
        _roadSegments!.isNotEmpty) {
      final segmentIndex = (_turnByTurnInstructions.length / 2).floor();
      if (segmentIndex < _roadSegments!.length) {
        return _roadSegments![segmentIndex].roadName;
      } else if (_roadSegments!.isNotEmpty) {
        return _roadSegments!.first.roadName;
      }
    }

    final defaultRoadNames = [
      "강남대로",
      "테헤란로",
      "",
      "세종대로",
      "종로",
      "을지로",
      "한강대로",
      "여의대로",
      "올림픽대로",
      "강변북로",
    ];

    final hash =
        (position.latitude * 1000000 + position.longitude * 1000000)
            .abs()
            .toInt();
    return defaultRoadNames[hash % defaultRoadNames.length];
  }

  String getCurrentRoadName(NLatLng position) {
    if (_currentRouteData != null) {
      return _routeController.getRoadNameAtPosition(
        position,
        _currentRouteData!,
      );
    }
    return _getRoadNameForPosition(position);
  }

  double _calculateAngleBetweenThreePoints(NLatLng p1, NLatLng p2, NLatLng p3) {
    double dx1 = p2.longitude - p1.longitude;
    double dy1 = p2.latitude - p1.latitude;

    double dx2 = p3.longitude - p2.longitude;
    double dy2 = p3.latitude - p2.latitude;

    double angle1 = atan2(dy1, dx1);
    double angle2 = atan2(dy2, dx2);

    double angle = (angle2 - angle1) * (180 / pi);

    if (angle > 180) {
      angle -= 360;
    } else if (angle < -180) {
      angle += 360;
    }

    return angle;
  }

  void _createStraightPath() {
    _pathCoordinates = [
      _origin,
      NLatLng(
        _origin.latitude + (_destination.latitude - _origin.latitude) * 0.3,
        _origin.longitude + (_destination.longitude - _origin.longitude) * 0.3,
      ),
      NLatLng(
        _origin.latitude + (_destination.latitude - _origin.latitude) * 0.7,
        _origin.longitude + (_destination.longitude - _origin.longitude) * 0.7,
      ),
      _destination,
    ];

    if (_mapController != null) {
      displayPathOverlay(_pathCoordinates);
    }

    _generateTurnByTurnInstructions();
  }

  void setMapController(NaverMapController controller) {
    _mapController = controller;

    try {
      final locationOverlay = controller.getLocationOverlay();
      locationOverlay.setIsVisible(true);

      if (_currentPosition != null) {
        locationOverlay.setPosition(_currentPosition!);
        if (_currentHeading != 0.0) {
          locationOverlay.setBearing(_currentHeading);
        }
      }
    } catch (e) {
      print('위치 오버레이 초기 설정 오류: $e');
    }

    if (_pathCoordinates.isNotEmpty) {
      displayPathOverlay(_pathCoordinates);
    }
  }

  // 🆕 실제 위치 추적 시작 - 한국 교통 정보 API 통합
  void startRealLocationTracking() {
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      final newPosition = NLatLng(position.latitude, position.longitude);
      _currentPosition = newPosition;

      _currentSpeed = (position.speed * 3.6).clamp(0, 200);
      _currentHeading = position.heading;

      _locationController.add(newPosition);

      updateCurrentLocationMarker(newPosition, position.heading);

      final remainingDistance = _calculateDistance(newPosition, _destination);

      if (remainingDistance < 20) {
        _navigationInfoController.add({
          'instruction': '목적지에 도착했습니다',
          'distance': '0m',
          'timeRemaining': '0분',
        });
        _arrivalController.add(null);
        return;
      }

      handleRouteDeviation(newPosition);

      // 🆕 자동차 모드에서 실제 속도 제한 업데이트
      if (mode == TransitMode.car) {
        _updateActualSpeedLimit(newPosition);
      }

      final avgSpeed = mode == TransitMode.car ? 10.0 : 1.4;
      final remainingTime = (remainingDistance / avgSpeed).round();

      final instruction = _getNavigationInstruction(newPosition);

      _navigationInfoController.add({
        'instruction': instruction,
        'distance': _formatDistance(remainingDistance.round()),
        'timeRemaining': _formatDuration(remainingTime),
      });

      if (mode == TransitMode.car) {
        _updateTurnByTurnInstruction(newPosition);
      }
    });
  }

  Future<String> getAddressFromCoordinates(NLatLng coordinates) async {
    try {
      final address = await _routeController.getAddressFromCoords(coordinates);
      return address;
    } catch (e) {
      print('주소 변환 오류: $e');
      return '알 수 없는 위치';
    }
  }

  void _updateTurnByTurnInstruction(NLatLng position) {
    if (_turnByTurnInstructions.isEmpty) return;

    int nearestIndex = -1;
    double minDistance = double.infinity;

    for (int i = 0; i < _turnByTurnInstructions.length; i++) {
      final instructionPoint = _turnByTurnInstructions[i]['point'] as NLatLng;
      final distance = _calculateDistance(position, instructionPoint);

      if (distance < minDistance) {
        nearestIndex = i;
        minDistance = distance;
      }
    }

    if (nearestIndex >= 0) {
      final newInstruction = _turnByTurnInstructions[nearestIndex];

      if (_currentInstruction == null ||
          _currentInstruction!['index'] != newInstruction['index']) {
        _currentInstruction = newInstruction;

        if (nearestIndex < _turnByTurnInstructions.length - 1) {
          _nextInstruction = _turnByTurnInstructions[nearestIndex + 1];
        } else {
          _nextInstruction = null;
        }

        if (_currentInstruction != null) {
          final instructionPoint = _currentInstruction!['point'] as NLatLng;
          final distanceToInstruction =
              _calculateDistance(position, instructionPoint).round();

          _currentInstruction!['distanceToPoint'] = distanceToInstruction;

          _turnByTurnController.add(_currentInstruction!);
        }
      } else if (_currentInstruction != null) {
        final instructionPoint = _currentInstruction!['point'] as NLatLng;
        final distanceToInstruction =
            _calculateDistance(position, instructionPoint).round();

        if (_currentInstruction!['distanceToPoint'] != distanceToInstruction) {
          _currentInstruction!['distanceToPoint'] = distanceToInstruction;
          _turnByTurnController.add(_currentInstruction!);
        }
      }
    }
  }

  Future<Map<String, dynamic>> recalculateRoute(NLatLng newOrigin) async {
    print('경로 재계산 시작: 출발지=${newOrigin}, 도착지=${_destination}');

    String originAddress = await getAddressFromCoordinates(newOrigin);
    print('새 출발지 주소: $originAddress');

    try {
      if (_mapController == null) {
        print('맵 컨트롤러가 없어 경로 재계산 불가');
        return {'success': false, 'newOriginAddress': originAddress};
      }

      if (_routePathOverlay != null) {
        try {
          _mapController!.deleteOverlay(_routePathOverlay!.info);
          _routePathOverlay = null;
          print('기존 경로선 제거 완료');
        } catch (e) {
          print('기존 경로선 제거 중 오류: $e');
        }
      }

      print('API 경로 검색 요청: ${newOrigin} → ${_destination}');
      Map<String, dynamic> routeData;

      if (mode == TransitMode.car) {
        routeData = await _routeController.searchCarRoute(
          newOrigin,
          _destination,
        );
        print('자동차 경로 검색 완료');
      } else {
        routeData = await _routeController.searchWalkRoute(
          newOrigin,
          _destination,
        );
        print('도보 경로 검색 완료');
      }

      if (routeData['routes'] == null || routeData['routes'].isEmpty) {
        print('API에서 반환된 경로가 없음');
        return {'success': false, 'newOriginAddress': originAddress};
      }

      final route = routeData['routes'][0];
      if (route['path'] == null || (route['path'] as List).isEmpty) {
        print('API에서 반환된 경로에 좌표가 없음');
        return {'success': false, 'newOriginAddress': originAddress};
      }

      List<NLatLng> pathCoordinates = List<NLatLng>.from(route['path']);
      print('새 경로 좌표 개수: ${pathCoordinates.length}');

      if (pathCoordinates.length >= 2) {
        double startToOrigin = _calculateDistance(
          pathCoordinates.first,
          newOrigin,
        );
        double endToDestination = _calculateDistance(
          pathCoordinates.last,
          _destination,
        );
        double startToDestination = _calculateDistance(
          pathCoordinates.first,
          _destination,
        );
        double endToOrigin = _calculateDistance(
          pathCoordinates.last,
          newOrigin,
        );

        if ((startToDestination < startToOrigin) &&
            (endToOrigin < endToDestination)) {
          print('경로 방향 조정: 좌표 역순 변경');
          pathCoordinates = List<NLatLng>.from(pathCoordinates.reversed);
        }
      }

      _pathCoordinates = pathCoordinates;

      if (mode == TransitMode.car && routeData['roadSegments'] != null) {
        _roadSegments = List<RoadSegment>.from(routeData['roadSegments']);
        print('도로명 정보 업데이트 완료: ${_roadSegments!.length}개 구간');
      }

      Color pathColor =
          mode == TransitMode.car ? Color(0xFFFB233B) : Color(0xFF0771EB);
      Color outlineColor =
          mode == TransitMode.car ? Color(0xFFB11829) : Color(0xFF0353AE);

      _routePathOverlay = NPathOverlay(
        id: 'navigation_route_${DateTime.now().millisecondsSinceEpoch}',
        coords: pathCoordinates,
        width: 12.0,
        color: pathColor,
        outlineWidth: 5.0,
        outlineColor: outlineColor,
        patternImage: NOverlayImage.fromAssetImage(
          'assets/icons/arrow_icon.png',
        ),
        patternInterval: 20,
        isHideCollidedCaptions: false,
        isHideCollidedMarkers: false,
        isHideCollidedSymbols: false,
      );

      try {
        print('새 경로선 맵에 추가 시도');
        _mapController!.addOverlay(_routePathOverlay!);
        print('새 경로선 맵에 추가 완료');
      } catch (e) {
        print('경로선 추가 중 오류: $e');
        return {'success': false, 'newOriginAddress': originAddress};
      }

      if (pathCoordinates.length >= 2) {
        final bounds = _calculateBounds(pathCoordinates);
        _mapController!.updateCamera(
          NCameraUpdate.fitBounds(bounds, padding: EdgeInsets.all(64)),
        );
      } else {
        _mapController!.updateCamera(
          NCameraUpdate.withParams(target: newOrigin, zoom: 17.0),
        );
      }

      if (mode == TransitMode.car) {
        _generateTurnByTurnInstructions();
      }

      return {'success': true, 'newOriginAddress': originAddress};
    } catch (e) {
      print('경로 재계산 중 오류 발생: $e');
      return {'success': false, 'newOriginAddress': originAddress};
    }
  }

  NLatLngBounds _calculateBounds(List<NLatLng> coordinates) {
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (var coord in coordinates) {
      if (coord.latitude < minLat) minLat = coord.latitude;
      if (coord.latitude > maxLat) maxLat = coord.latitude;
      if (coord.longitude < minLng) minLng = coord.longitude;
      if (coord.longitude > maxLng) maxLng = coord.longitude;
    }

    return NLatLngBounds(
      southWest: NLatLng(minLat, minLng),
      northEast: NLatLng(maxLat, maxLng),
    );
  }

  void clearAllOverlays() {
    if (_mapController == null) return;

    print('모든 오버레이 제거/숨김 시작');

    try {
      if (_routePathOverlay != null) {
        _mapController!.deleteOverlay(_routePathOverlay!.info);
        _routePathOverlay = null;
        print('경로선 제거 완료');
      }

      if (_destinationMarker != null) {
        _mapController!.deleteOverlay(_destinationMarker!.info);
        _destinationMarker = null;
        print('도착지 마커 제거 완료');
      }

      if (_currentLocationMarker != null) {
        _mapController!.deleteOverlay(_currentLocationMarker!.info);
        _currentLocationMarker = null;
        print('현재 위치 마커 제거 완료');
      }

      try {
        final locationOverlay = _mapController!.getLocationOverlay();
        locationOverlay.setIsVisible(false);
        print('위치 오버레이 숨김 완료');
      } catch (e) {
        print('위치 오버레이 숨김 중 오류: $e');
      }

      print('모든 오버레이 제거/숨김 완료');
    } catch (e) {
      print('오버레이 제거/숨김 중 오류: $e');
    }
  }

  void clearPathOverlays() {
    if (_mapController == null) return;

    print('경로선과 마커 제거 시작 (위치 오버레이는 유지)');

    try {
      if (_routePathOverlay != null) {
        _mapController!.deleteOverlay(_routePathOverlay!.info);
        _routePathOverlay = null;
        print('경로선 제거 완료');
      }

      if (_destinationMarker != null) {
        _mapController!.deleteOverlay(_destinationMarker!.info);
        _destinationMarker = null;
        print('도착지 마커 제거 완료');
      }

      if (_currentLocationMarker != null) {
        _mapController!.deleteOverlay(_currentLocationMarker!.info);
        _currentLocationMarker = null;
        print('현재 위치 마커 제거 완료');
      }

      print('경로선과 마커 제거 완료 (위치 오버레이는 유지)');
    } catch (e) {
      print('오버레이 제거 중 오류: $e');
    }
  }

  bool _isDeviated(NLatLng position) {
    if (_pathCoordinates.isEmpty) return false;

    if (_lastRecalculationTime != null) {
      final timeSinceLastRecalculation =
          DateTime.now().difference(_lastRecalculationTime!).inSeconds;
      if (timeSinceLastRecalculation < 10) {
        return false;
      }
    }

    double minDistance = double.infinity;
    int closestPointIndex = 0;

    for (int i = 0; i < _pathCoordinates.length; i += 5) {
      final distance = _calculateDistance(position, _pathCoordinates[i]);
      if (distance < minDistance) {
        minDistance = distance;
        closestPointIndex = i;
      }
    }

    int start = max(0, closestPointIndex - 10);
    int end = min(_pathCoordinates.length - 1, closestPointIndex + 10);

    for (int i = start; i <= end; i++) {
      final distance = _calculateDistance(position, _pathCoordinates[i]);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    final deviationThreshold = mode == TransitMode.car ? 100.0 : 50.0;

    if (minDistance > deviationThreshold) {
      _deviationCounter++;
      print(
        '경로 이탈 가능성 감지: 카운터($_deviationCounter/3), 거리: ${minDistance.toStringAsFixed(1)}m',
      );

      if (_deviationCounter >= 3) {
        _deviationCounter = 0;
        _lastRecalculationTime = DateTime.now();
        print('경로 이탈 확정: 경로에서 ${minDistance.toStringAsFixed(1)}m 떨어짐');
        return true;
      }
      return false;
    } else {
      _deviationCounter = 0;
      return false;
    }
  }

  void handleRouteDeviation(NLatLng currentPosition) {
    if (mode == TransitMode.walk) {
      return;
    }

    if (_isDeviated(currentPosition)) {
      print('경로 재계산 시작: 현재 위치에서 목적지까지');
      _routeDeviationController.add(true);

      recalculateRoute(currentPosition);
    }
  }

  String _getNavigationInstruction(NLatLng position) {
    if (_pathCoordinates.isEmpty) return '경로 안내 준비 중...';

    int closestPointIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < _pathCoordinates.length; i++) {
      final distance = _calculateDistance(position, _pathCoordinates[i]);
      if (distance < minDistance) {
        minDistance = distance;
        closestPointIndex = i;
      }
    }

    if (closestPointIndex >= _pathCoordinates.length - 1) {
      return '목적지가 가까워지고 있습니다';
    }

    final nextPoint = _pathCoordinates[closestPointIndex + 1];

    final heading = _calculateHeading(position, nextPoint);

    if (heading > 160 || heading < -160) {
      return 'U턴하세요';
    } else if (heading > 60) {
      return '우회전하세요';
    } else if (heading < -60) {
      return '좌회전하세요';
    } else if (heading > 30) {
      return '우측으로 진행하세요';
    } else if (heading < -30) {
      return '좌측으로 진행하세요';
    } else {
      return '직진하세요';
    }
  }

  double _calculateHeading(NLatLng from, NLatLng to) {
    final double lat1 = from.latitude * (pi / 180);
    final double lon1 = from.longitude * (pi / 180);
    final double lat2 = to.latitude * (pi / 180);
    final double lon2 = to.longitude * (pi / 180);

    final double dLon = lon2 - lon1;

    final double y = sin(dLon) * cos(lat2);
    final double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

    final double bearing = atan2(y, x) * (180 / pi);
    return bearing;
  }

  void updateCurrentLocationMarker(NLatLng position, double? heading) {
    if (_mapController == null) return;

    try {
      final locationOverlay = _mapController!.getLocationOverlay();
      locationOverlay.setPosition(position);

      if (heading != null && !heading.isNaN) {
        double headingDiff = (heading - _lastHeading).abs();

        if (headingDiff > 180) {
          headingDiff = 360 - headingDiff;
        }

        if (headingDiff > _headingThreshold) {
          locationOverlay.setBearing(heading);
          _currentHeading = heading;
          _lastHeading = heading;
          print('방향 업데이트: ${heading.toStringAsFixed(1)}도');
        }
      }

      locationOverlay.setIsVisible(true);

      _mapController!.setLocationTrackingMode(
        mode == TransitMode.car
            ? NLocationTrackingMode.face
            : NLocationTrackingMode.follow,
      );
    } catch (e) {
      print('위치 오버레이 업데이트 오류: $e');
    }
  }

  void displayPathOverlay(List<NLatLng> coordinates) {
    if (_mapController == null || coordinates.isEmpty) {
      print('경로선 표시 불가: 맵 컨트롤러 없거나 좌표 없음');
      return;
    }

    print('경로선 표시 시작: 좌표 개수=${coordinates.length}');

    clearPathOverlays();

    _pathCoordinates = coordinates;

    try {
      Color pathColor =
          mode == TransitMode.car ? Color(0xFFFB233B) : Color(0xFF0771EB);
      Color outlineColor =
          mode == TransitMode.car ? Color(0xFFB11829) : Color(0xFF0353AE);

      _routePathOverlay = NPathOverlay(
        id: 'navigation_route',
        coords: coordinates,
        width: 12.0,
        color: pathColor,
        outlineWidth: 5.0,
        outlineColor: outlineColor,
        patternImage: NOverlayImage.fromAssetImage(
          'assets/icons/arrow_icon.png',
        ),
        patternInterval: 20,
        isHideCollidedCaptions: false,
        isHideCollidedMarkers: false,
        isHideCollidedSymbols: false,
      );

      print('경로선 오버레이 생성 완료');

      _mapController!.addOverlay(_routePathOverlay!);
      print('경로선 맵에 추가 완료');

      if (_destination != null) {
        final markerImage = NOverlayImage.fromAssetImage(
          'assets/icons/end_marker.png',
        );

        _destinationMarker = NMarker(
          id: 'navigation_end_marker',
          position: _destination,
          icon: markerImage,
          size: const Size(40, 50),
          anchor: const NPoint(0.5, 1.0),
          iconTintColor:
              mode == TransitMode.car ? Color(0xFFFB233B) : Color(0xFF0771EB),
        );

        _mapController!.addOverlay(_destinationMarker!);
        print(
          '도착지 마커 추가 완료 - ${mode == TransitMode.car ? "자동차(빨간색)" : "도보(파란색)"}',
        );
      }

      if (_currentPosition != null) {
        final locationOverlay = _mapController!.getLocationOverlay();
        locationOverlay.setPosition(_currentPosition!);
        locationOverlay.setIsVisible(true);
      }
    } catch (e) {
      print('경로선 생성/추가 오류: $e');
    }
  }

  void fitBoundsToShowRoute(NLatLng origin, NLatLng destination) {
    if (_mapController == null) return;

    double minLat = min(origin.latitude, destination.latitude);
    double maxLat = max(origin.latitude, destination.latitude);
    double minLng = min(origin.longitude, destination.longitude);
    double maxLng = max(origin.longitude, destination.longitude);

    if (_pathCoordinates.isNotEmpty) {
      for (var coord in _pathCoordinates) {
        minLat = min(minLat, coord.latitude);
        maxLat = max(maxLat, coord.latitude);
        minLng = min(minLng, coord.longitude);
        maxLng = max(maxLng, coord.longitude);
      }
    }

    double padding = 0.002;
    minLat -= padding;
    maxLat += padding;
    minLng -= padding;
    maxLng += padding;

    final bounds = NLatLngBounds(
      southWest: NLatLng(minLat, minLng),
      northEast: NLatLng(maxLat, maxLng),
    );

    _mapController!.updateCamera(
      NCameraUpdate.fitBounds(bounds, padding: EdgeInsets.all(64)),
    );
  }

  // 🆕 실제 속도 제한 가져오기 (한국 교통 정보 API 사용)
  double getCurrentSpeed() {
    return _currentSpeed;
  }

  // 🆕 실제 속도 제한 가져오기 (한국 교통 정보 API에서 조회된 값)
  int getSpeedLimit() {
    return _actualSpeedLimit;
  }

  Map<String, dynamic>? getCurrentInstruction() {
    return _currentInstruction;
  }

  Map<String, dynamic>? getNextInstruction() {
    return _nextInstruction;
  }

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

  String _formatDistance(int meters) {
    if (meters < 1000) {
      return '${meters}m';
    } else {
      double km = meters / 1000.0;
      return '${km.toStringAsFixed(1)}km';
    }
  }

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
    _navigationInfoController.close();
    _locationController.close();
    _routeDeviationController.close();
    _arrivalController.close();
    _turnByTurnController.close();
    _speedLimitController.close();

    _positionStreamSubscription?.cancel();
  }
}
