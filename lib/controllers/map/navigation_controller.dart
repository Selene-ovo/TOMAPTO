import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tomapto/controllers/map/transit_map_controller.dart';
import 'package:tomapto/controllers/map/route_controller.dart';

class NavigationController {
  // 모드 (자동차/도보)
  final TransitMode mode;

  // 네이버 맵 컨트롤러
  NaverMapController? _mapController;

  // 오버레이 객체들
  NPathOverlay? _routePathOverlay;
  NMarker? _destinationMarker;
  NMarker? _currentLocationMarker;

  // 경로 좌표 리스트
  List<NLatLng> _pathCoordinates = [];

  // 출발지와 목적지 좌표
  final NLatLng _origin;
  final NLatLng _destination;

  // 경로 컨트롤러 추가
  final RouteController _routeController = RouteController();

  // 이탈 감지 관련 변수들 - 여기에 추가
  int _deviationCounter = 0; // 연속 이탈 감지 카운터
  DateTime? _lastRecalculationTime; // 마지막 경로 재계산 시간

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

  // 현재 도로의 속도 제한 (API에서 가져와야 하지만 기본값 설정)
  int _speedLimit = 50;

  // 턴바이턴 정보
  List<Map<String, dynamic>> _turnByTurnInstructions = [];
  Map<String, dynamic>? _currentInstruction;
  Map<String, dynamic>? _nextInstruction;

  // 현재 방향 정보 저장 변수 추가
  double _currentHeading = 0.0;

  // 현재 방향 정보 getter 추가
  double getCurrentHeading() {
    return _currentHeading;
  }

  double _lastHeading = 0.0; // 이전 방향 저장
  static const double _headingThreshold = 10.0; // 10도 이상 변화시에만 업데이트

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
  // ===== StreamController 부분 끝 =====

  // 경로 로딩 상태 추가
  bool _isRouteLoading = false;
  bool get isRouteLoading => _isRouteLoading;

  // 생성자
  NavigationController(this.mode, this._origin, this._destination) {
    // 모드에 따른 마커 색상 설정
    if (mode == TransitMode.car) {
      _startMarkerColor = Color(0xFF00C73C); // 네이버 녹색
      _destinationMarkerColor = Color(0xFFFF5F4A); // 네이버 빨간색
      _currentLocationColor = Color(0xFF4A82FF); // 네이버 파란색
    } else {
      _startMarkerColor = Color(0xFF00C73C); // 네이버 녹색
      _destinationMarkerColor = Color(0xFFFF5F4A); // 네이버 빨간색
      _currentLocationColor = Color(0xFF4A82FF); // 네이버 파란색
    }

    // 현재 위치 초기화
    _currentPosition = _origin;

    // 경로 탐색 (비동기 호출이므로 생성자에서 직접 await 불가)
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

    // 기본 지시사항만 생성
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

  // 도보용 간단한 지시사항 생성
  void _generateSimpleWalkInstructions() {
    _turnByTurnInstructions = [];

    if (_pathCoordinates.length < 2) return;

    final distance = _calculateDistance(_origin, _destination);

    // 간단한 지시사항만 생성
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
        // 도보는 더 짧은 타임아웃
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
            Duration(seconds: 8),
            () => throw TimeoutException('자동차 경로 타임아웃'),
          ),
        ]);
      }

      if (routeData['routes'] != null && routeData['routes'].isNotEmpty) {
        final route = routeData['routes'][0];
        if (route['path'] != null) {
          _pathCoordinates = List<NLatLng>.from(route['path']);
          print('경로 로딩 완료: ${_pathCoordinates.length}개 좌표');

          // 도보 모드는 간단한 턴바이턴만 생성
          if (mode == TransitMode.walk) {
            _generateSimpleWalkInstructions();
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

  bool hasPathCoordinates() {
    return _pathCoordinates.isNotEmpty;
  }

  bool hasPathOverlay() {
    return _routePathOverlay != null;
  }

  void displayCurrentPath() {
    if (_pathCoordinates.isNotEmpty) {
      displayPathOverlay(_pathCoordinates);
    }
  }

  // 턴바이턴 지시 사항 생성
  void _generateTurnByTurnInstructions() {
    _turnByTurnInstructions = [];

    if (_pathCoordinates.length < 3) return;

    // 주요 방향 전환 지점 찾기
    for (int i = 1; i < _pathCoordinates.length - 1; i++) {
      // 3개의 연속된 점으로 방향 변화 계산
      double angle = _calculateAngleBetweenThreePoints(
        _pathCoordinates[i - 1],
        _pathCoordinates[i],
        _pathCoordinates[i + 1],
      );

      String direction = "직진";
      IconData directionIcon = Icons.arrow_upward;

      // 각도에 따른 방향 결정
      if (angle > 60 && angle <= 120) {
        direction = "우회전";
        directionIcon = Icons.turn_right;
      } else if (angle > 120) {
        direction = "급우회전";
        directionIcon = Icons.turn_right;
      } else if (angle < -60 && angle >= -120) {
        direction = "좌회전";
        directionIcon = Icons.turn_left;
      } else if (angle < -120) {
        direction = "급좌회전";
        directionIcon = Icons.turn_left;
      } else if (angle > 30 && angle <= 60) {
        direction = "우측으로";
        directionIcon = Icons.turn_slight_right;
      } else if (angle < -30 && angle >= -60) {
        direction = "좌측으로";
        directionIcon = Icons.turn_slight_left;
      }

      // 방향 변화가 큰 경우만 지시 추가
      if (direction != "직진" || _turnByTurnInstructions.isEmpty) {
        // 이전 지점과의 거리 계산
        double distance =
            i > 0
                ? _calculateDistance(
                  _pathCoordinates[i - 1],
                  _pathCoordinates[i],
                )
                : 0;

        // 다음 지점까지의 거리
        double nextDistance =
            i < _pathCoordinates.length - 1
                ? _calculateDistance(
                  _pathCoordinates[i],
                  _pathCoordinates[i + 1],
                )
                : 0;

        // 가상 도로명 (실제로는 API에서 가져와야 함)
        String roadName = "경강로";

        if (i > 2 && i % 2 == 0) {
          roadName = "테헤란로";
        } else if (i > 3 && i % 3 == 0) {
          roadName = "강남대로";
        }

        // 지시 추가
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

    // 마지막 직진 지시 추가 (목적지까지)
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

    // 지시 정보 로그
    for (var instruction in _turnByTurnInstructions) {
      print(
        '턴바이턴 지시: ${instruction['direction']}, 거리: ${instruction['distance']}m, 도로: ${instruction['roadName']}',
      );
    }

    // 첫 지시사항 설정
    if (_turnByTurnInstructions.isNotEmpty) {
      _currentInstruction = _turnByTurnInstructions.first;

      // 다음 지시사항 설정
      if (_turnByTurnInstructions.length > 1) {
        _nextInstruction = _turnByTurnInstructions[1];
      }

      // 스트림에 첫 지시사항 전송
      _turnByTurnController.add(_currentInstruction!);
    }
  }

  // 세 점 사이의 회전 각도 계산 (음수: 좌회전, 양수: 우회전)
  double _calculateAngleBetweenThreePoints(NLatLng p1, NLatLng p2, NLatLng p3) {
    // 첫 번째 선분의 방향 벡터
    double dx1 = p2.longitude - p1.longitude;
    double dy1 = p2.latitude - p1.latitude;

    // 두 번째 선분의 방향 벡터
    double dx2 = p3.longitude - p2.longitude;
    double dy2 = p3.latitude - p2.latitude;

    // 두 벡터 사이의 각도 계산 (라디안)
    double angle1 = atan2(dy1, dx1);
    double angle2 = atan2(dy2, dx2);

    // 각도 차이 계산 (-180 ~ 180도로 조정)
    double angle = (angle2 - angle1) * (180 / pi);

    // 각도 범위 조정
    if (angle > 180) {
      angle -= 360;
    } else if (angle < -180) {
      angle += 360;
    }

    return angle;
  }

  // 직선 경로 생성 (API 호출 실패 시 대체용)
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

    // 맵 컨트롤러가 이미 설정되어 있다면 경로 표시
    if (_mapController != null) {
      displayPathOverlay(_pathCoordinates);
    }

    // 기본 턴바이턴 지시 생성
    _generateTurnByTurnInstructions();
  }

  // 맵 컨트롤러 설정
  void setMapController(NaverMapController controller) {
    _mapController = controller;

    // 위치 오버레이 초기 설정
    try {
      final locationOverlay = controller.getLocationOverlay();
      locationOverlay.setIsVisible(true);

      // 현재 위치와 방향이 있으면 설정
      if (_currentPosition != null) {
        locationOverlay.setPosition(_currentPosition!);
        if (_currentHeading != 0.0) {
          locationOverlay.setBearing(_currentHeading);
        }
      }
    } catch (e) {
      print('위치 오버레이 초기 설정 오류: $e');
    }

    // 경로가 이미 로드되어 있다면 경로 표시
    if (_pathCoordinates.isNotEmpty) {
      displayPathOverlay(_pathCoordinates);
    }
  }

  // 실제 위치 추적 시작
  void startRealLocationTracking() {
    // 위치 설정
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // 5미터마다 업데이트
    );

    // 위치 스트림 구독
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      // 현재 위치 업데이트
      final newPosition = NLatLng(position.latitude, position.longitude);
      _currentPosition = newPosition;

      // 현재 속도 업데이트 (m/s에서 km/h로 변환)
      _currentSpeed = (position.speed * 3.6).clamp(0, 200);

      // 현재 방향 업데이트 (heading 정보 저장)
      _currentHeading = position.heading;
      print('현재 방향: ${_currentHeading.toStringAsFixed(1)}도');

      // 위치 스트림에 알림
      _locationController.add(newPosition);

      // 마커 업데이트
      updateCurrentLocationMarker(newPosition, position.heading);

      // 남은 거리 계산
      final remainingDistance = _calculateDistance(newPosition, _destination);

      // 도착 확인 (20m 이내)
      if (remainingDistance < 20) {
        _navigationInfoController.add({
          'instruction': '목적지에 도착했습니다',
          'distance': '0m',
          'timeRemaining': '0분',
        });
        _arrivalController.add(null);
        return;
      }

      // 경로 이탈 확인 및 처리 - 자동 재계산
      handleRouteDeviation(newPosition);

      // 남은 시간 계산 (평균 속도 기반)
      final avgSpeed =
          mode == TransitMode.car ? 10.0 : 1.4; // m/s (자동차: 36km/h, 도보: 5km/h)
      final remainingTime = (remainingDistance / avgSpeed).round();

      // 방향 지시 결정
      final instruction = _getNavigationInstruction(newPosition);

      // 네비게이션 정보 업데이트 (스트림으로 전송)
      _navigationInfoController.add({
        'instruction': instruction,
        'distance': _formatDistance(remainingDistance.round()),
        'timeRemaining': _formatDuration(remainingTime),
      });

      // 턴바이턴 지시 업데이트
      _updateTurnByTurnInstruction(newPosition);

      // 랜덤으로 속도 제한 변경 (실제로는 API에서 가져와야 함)
      if (Random().nextInt(100) < 2) {
        // 2% 확률로 변경
        _speedLimit = [30, 50, 60, 70, 80][Random().nextInt(5)];
        _speedLimitController.add(_speedLimit);
      }
    });
  }

  Future<String> getAddressFromCoordinates(NLatLng coordinates) async {
    try {
      // RouteController를 사용하여 좌표에서 주소 가져오기
      final address = await _routeController.getAddressFromCoords(coordinates);
      return address;
    } catch (e) {
      print('주소 변환 오류: $e');
      return '알 수 없는 위치';
    }
  }

  // 현재 위치에 따른 턴바이턴 지시 업데이트
  void _updateTurnByTurnInstruction(NLatLng position) {
    if (_turnByTurnInstructions.isEmpty) return;

    // 현재 위치에서 가장 가까운 다음 지시 찾기
    int nearestIndex = -1;
    double minDistance = double.infinity;

    for (int i = 0; i < _turnByTurnInstructions.length; i++) {
      final instructionPoint = _turnByTurnInstructions[i]['point'] as NLatLng;
      final distance = _calculateDistance(position, instructionPoint);

      // 아직 지나지 않은 지시 중 가장 가까운 것 선택
      if (distance < minDistance) {
        nearestIndex = i;
        minDistance = distance;
      }
    }

    if (nearestIndex >= 0) {
      // 현재 지시사항이 변경되었는지 확인
      final newInstruction = _turnByTurnInstructions[nearestIndex];

      if (_currentInstruction == null ||
          _currentInstruction!['index'] != newInstruction['index']) {
        // 현재 지시사항 업데이트
        _currentInstruction = newInstruction;

        // 다음 지시사항 업데이트
        if (nearestIndex < _turnByTurnInstructions.length - 1) {
          _nextInstruction = _turnByTurnInstructions[nearestIndex + 1];
        } else {
          _nextInstruction = null;
        }

        // 지시 거리 업데이트 (현재 위치에서 지시 지점까지)
        if (_currentInstruction != null) {
          final instructionPoint = _currentInstruction!['point'] as NLatLng;
          final distanceToInstruction =
              _calculateDistance(position, instructionPoint).round();

          // 거리 업데이트
          _currentInstruction!['distanceToPoint'] = distanceToInstruction;

          // 스트림에 업데이트된 지시 전송
          _turnByTurnController.add(_currentInstruction!);
        }
      } else if (_currentInstruction != null) {
        // 거리만 업데이트
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

  // 경로 재계산
  Future<Map<String, dynamic>> recalculateRoute(NLatLng newOrigin) async {
    print('경로 재계산 시작: 출발지=${newOrigin}, 도착지=${_destination}');

    // 출발지 주소 가져오기
    String originAddress = await getAddressFromCoordinates(newOrigin);
    print('새 출발지 주소: $originAddress');

    try {
      // 1. 맵 컨트롤러 확인
      if (_mapController == null) {
        print('맵 컨트롤러가 없어 경로 재계산 불가');
        return {'success': false, 'newOriginAddress': originAddress};
      }

      // 2. 기존 오버레이 모두 제거 (깨끗하게 시작)
      if (_routePathOverlay != null) {
        try {
          _mapController!.deleteOverlay(_routePathOverlay!.info);
          _routePathOverlay = null;
          print('기존 경로선 제거 완료');
        } catch (e) {
          print('기존 경로선 제거 중 오류: $e');
        }
      }

      // 3. API로 새 경로 데이터 요청
      print('API 경로 검색 요청: ${newOrigin} → ${_destination}');
      Map<String, dynamic> routeData;

      // 모드에 따라 다른 API 호출
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

      // 4. 경로 데이터 확인 및 좌표 추출
      if (routeData['routes'] == null || routeData['routes'].isEmpty) {
        print('API에서 반환된 경로가 없음');
        return {'success': false, 'newOriginAddress': originAddress};
      }

      final route = routeData['routes'][0];
      if (route['path'] == null || (route['path'] as List).isEmpty) {
        print('API에서 반환된 경로에 좌표가 없음');
        return {'success': false, 'newOriginAddress': originAddress};
      }

      // 5. 경로 좌표 가져오기
      List<NLatLng> pathCoordinates = List<NLatLng>.from(route['path']);
      print('새 경로 좌표 개수: ${pathCoordinates.length}');

      // 6. 경로 방향 확인 및 필요시 조정
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

      // 7. 경로 좌표 저장
      _pathCoordinates = pathCoordinates;

      // 8. 새 경로선 생성
      Color pathColor =
          mode == TransitMode.car ? Color(0xFFFB233B) : Color(0xFF0771EB);
      Color outlineColor =
          mode == TransitMode.car ? Color(0xFFB11829) : Color(0xFF0353AE);

      _routePathOverlay = NPathOverlay(
        id: 'navigation_route_${DateTime.now().millisecondsSinceEpoch}', // 고유 ID 생성
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

      // 9. 맵에 경로선 추가
      try {
        print('새 경로선 맵에 추가 시도');
        _mapController!.addOverlay(_routePathOverlay!);
        print('새 경로선 맵에 추가 완료');
      } catch (e) {
        print('경로선 추가 중 오류: $e');
        return {'success': false, 'newOriginAddress': originAddress};
      }

      // 10. 카메라 위치 업데이트 (전체 경로 또는 현재 위치 중심)
      if (pathCoordinates.length >= 2) {
        // 전체 경로가 보이도록 카메라 이동
        final bounds = _calculateBounds(pathCoordinates);
        _mapController!.updateCamera(
          NCameraUpdate.fitBounds(bounds, padding: EdgeInsets.all(64)),
        );
      } else {
        // 현재 위치로 카메라 이동
        _mapController!.updateCamera(
          NCameraUpdate.withParams(target: newOrigin, zoom: 17.0),
        );
      }

      // 11. 턴바이턴 지시 업데이트
      _generateTurnByTurnInstructions();

      // 반환값 수정
      return {'success': true, 'newOriginAddress': originAddress};
    } catch (e) {
      print('경로 재계산 중 오류 발생: $e');
      return {'success': false, 'newOriginAddress': originAddress};
    }
  }

  // car_modal.dart에서 가져온 경계 계산 메서드
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

  // 모든 경로선과 마커 제거 메서드 추가
  void clearAllOverlays() {
    if (_mapController == null) return;

    print('모든 오버레이 제거/숨김 시작');

    try {
      // 경로선 제거
      if (_routePathOverlay != null) {
        _mapController!.deleteOverlay(_routePathOverlay!.info);
        _routePathOverlay = null;
        print('경로선 제거 완료');
      }

      // 도착지 마커 제거
      if (_destinationMarker != null) {
        _mapController!.deleteOverlay(_destinationMarker!.info);
        _destinationMarker = null;
        print('도착지 마커 제거 완료');
      }

      // 현재 위치 마커 제거 (위치 오버레이로 대체)
      if (_currentLocationMarker != null) {
        _mapController!.deleteOverlay(_currentLocationMarker!.info);
        _currentLocationMarker = null;
        print('현재 위치 마커 제거 완료');
      }

      // 위치 오버레이는 숨기기만 함 (완전 제거하지 않음)
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

  // 경로선과 마커 제거 (위치 오버레이는 유지)
  void clearPathOverlays() {
    if (_mapController == null) return;

    print('경로선과 마커 제거 시작 (위치 오버레이는 유지)');

    try {
      // 경로선 제거
      if (_routePathOverlay != null) {
        _mapController!.deleteOverlay(_routePathOverlay!.info);
        _routePathOverlay = null;
        print('경로선 제거 완료');
      }

      // 도착지 마커 제거
      if (_destinationMarker != null) {
        _mapController!.deleteOverlay(_destinationMarker!.info);
        _destinationMarker = null;
        print('도착지 마커 제거 완료');
      }

      // 현재 위치 마커가 있다면 제거 (위치 오버레이로 대체되므로)
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

  // 경로 이탈 확인
  bool _isDeviated(NLatLng position) {
    if (_pathCoordinates.isEmpty) return false;

    // 마지막 경로 재계산 시점부터 최소 시간/거리 확인
    // 경로 재계산 후 일정 시간 동안 이탈 감지 비활성화
    if (_lastRecalculationTime != null) {
      final timeSinceLastRecalculation =
          DateTime.now().difference(_lastRecalculationTime!).inSeconds;
      if (timeSinceLastRecalculation < 10) {
        // 10초 동안 추가 이탈 감지 방지
        return false;
      }
    }

    // 현재 위치에서 가장 가까운 경로 지점 찾기
    double minDistance = double.infinity;
    int closestPointIndex = 0;

    // 모든 점을 검사하는 대신, 점프하면서 대략적인 가까운 지점 찾기
    // 이렇게 하면 성능도 향상되고 GPS 튐 현상도 줄일 수 있음
    for (int i = 0; i < _pathCoordinates.length; i += 5) {
      // 5개 점마다 검사
      final distance = _calculateDistance(position, _pathCoordinates[i]);
      if (distance < minDistance) {
        minDistance = distance;
        closestPointIndex = i;
      }
    }

    // 가장 가까운 점 주변의 점들 더 정밀하게 검사
    int start = max(0, closestPointIndex - 10);
    int end = min(_pathCoordinates.length - 1, closestPointIndex + 10);

    for (int i = start; i <= end; i++) {
      final distance = _calculateDistance(position, _pathCoordinates[i]);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    // 이동 수단에 따른 허용 이탈 거리 (값 증가)
    final deviationThreshold =
        mode == TransitMode.car ? 100.0 : 50.0; // 더 큰 임계값으로 변경

    // 이탈 카운터 증가 로직 - 연속으로 N번 이탈 감지 시에만 실제 이탈로 처리
    if (minDistance > deviationThreshold) {
      _deviationCounter++;
      print(
        '경로 이탈 가능성 감지: 카운터($_deviationCounter/3), 거리: ${minDistance.toStringAsFixed(1)}m',
      );

      // 3번 연속 이탈 감지 시에만 실제 이탈로 처리
      if (_deviationCounter >= 3) {
        _deviationCounter = 0;
        _lastRecalculationTime = DateTime.now();
        print('경로 이탈 확정: 경로에서 ${minDistance.toStringAsFixed(1)}m 떨어짐');
        return true;
      }
      return false;
    } else {
      // 이탈 아닌 경우 카운터 리셋
      _deviationCounter = 0;
      return false;
    }
  }

  // 경로 이탈 시 자동 재계산 처리
  void handleRouteDeviation(NLatLng currentPosition) {
    // 도보 모드에서는 경로 이탈 감지 및 재계산 비활성화
    if (mode == TransitMode.walk) {
      return;
    }

    if (_isDeviated(currentPosition)) {
      print('경로 재계산 시작: 현재 위치에서 목적지까지');
      _routeDeviationController.add(true);

      // 재계산 수행
      recalculateRoute(currentPosition);
    }
  }

  // 방향 지시 결정
  String _getNavigationInstruction(NLatLng position) {
    if (_pathCoordinates.isEmpty) return '경로 안내 준비 중...';

    // 현재 위치에서 가장 가까운 경로 지점 찾기
    int closestPointIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < _pathCoordinates.length; i++) {
      final distance = _calculateDistance(position, _pathCoordinates[i]);
      if (distance < minDistance) {
        minDistance = distance;
        closestPointIndex = i;
      }
    }

    // 다음 지점이 없으면 도착 임박
    if (closestPointIndex >= _pathCoordinates.length - 1) {
      return '목적지가 가까워지고 있습니다';
    }

    // 다음 방향 변경 지점 찾기
    final nextPoint = _pathCoordinates[closestPointIndex + 1];

    // 현재 지점과 다음 지점 사이의 방향 계산
    final heading = _calculateHeading(position, nextPoint);

    // 방향에 따른 지시 결정
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

  // 두 지점 사이의 방향 계산 (각도)
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

  // 현재 위치 마커
  void updateCurrentLocationMarker(NLatLng position, double? heading) {
    if (_mapController == null) return;

    try {
      final locationOverlay = _mapController!.getLocationOverlay();
      locationOverlay.setPosition(position);

      // 방향 변화가 임계값 이상일 때만 업데이트
      if (heading != null && !heading.isNaN) {
        double headingDiff = (heading - _lastHeading).abs();

        // 360도 경계 처리 (예: 350도 -> 10도)
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

      // 오버레이가 보이도록 설정
      locationOverlay.setIsVisible(true);

      // 위치 추적 모드 설정
      _mapController!.setLocationTrackingMode(
        mode == TransitMode.car
            ? NLocationTrackingMode.face
            : NLocationTrackingMode.follow,
      );
    } catch (e) {
      print('위치 오버레이 업데이트 오류: $e');
    }
  }

  // 경로선 표시
  void displayPathOverlay(List<NLatLng> coordinates) {
    if (_mapController == null || coordinates.isEmpty) {
      print('경로선 표시 불가: 맵 컨트롤러 없거나 좌표 없음');
      return;
    }

    print('경로선 표시 시작: 좌표 개수=${coordinates.length}');

    // 기존 오버레이 제거 (현재 위치 마커는 제외)
    clearPathOverlays();

    // 경로 좌표 저장
    _pathCoordinates = coordinates;

    try {
      // 색상 설정
      Color pathColor =
          mode == TransitMode.car ? Color(0xFFFB233B) : Color(0xFF0771EB);
      Color outlineColor =
          mode == TransitMode.car ? Color(0xFFB11829) : Color(0xFF0353AE);

      // 경로선 생성
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

      // 경로선 추가
      _mapController!.addOverlay(_routePathOverlay!);
      print('경로선 맵에 추가 완료');

      // 도착지 마커 추가
      if (_destination != null) {
        // 확실히 존재하는 기본 아이콘 사용
        final markerImage = NOverlayImage.fromAssetImage(
          'assets/icons/end_marker.png',
        );

        _destinationMarker = NMarker(
          id: 'navigation_end_marker',
          position: _destination,
          icon: markerImage,
          size: const Size(40, 50),
          anchor: const NPoint(0.5, 1.0),
          // 모드에 따라 색상으로 구분
          iconTintColor:
              mode == TransitMode.car
                  ? Color(0xFFFB233B) // 자동차: 빨간색 계열
                  : Color(0xFF0771EB), // 도보: 파란색 계열
        );

        _mapController!.addOverlay(_destinationMarker!);
        print(
          '도착지 마커 추가 완료 - ${mode == TransitMode.car ? "자동차(빨간색)" : "도보(파란색)"}',
        );
      }

      // 위치 오버레이 활성화 (현재 위치가 있는 경우)
      if (_currentPosition != null) {
        final locationOverlay = _mapController!.getLocationOverlay();
        locationOverlay.setPosition(_currentPosition!);
        locationOverlay.setIsVisible(true);
      }
    } catch (e) {
      print('경로선 생성/추가 오류: $e');
    }
  }

  // 경로가 모두 보이도록 카메라 이동
  void fitBoundsToShowRoute(NLatLng origin, NLatLng destination) {
    if (_mapController == null) return;

    // 기본 경계 계산
    double minLat = min(origin.latitude, destination.latitude);
    double maxLat = max(origin.latitude, destination.latitude);
    double minLng = min(origin.longitude, destination.longitude);
    double maxLng = max(origin.longitude, destination.longitude);

    // 경로가 있으면 경로 기반 경계 계산
    if (_pathCoordinates.isNotEmpty) {
      for (var coord in _pathCoordinates) {
        minLat = min(minLat, coord.latitude);
        maxLat = max(maxLat, coord.latitude);
        minLng = min(minLng, coord.longitude);
        maxLng = max(maxLng, coord.longitude);
      }
    }

    // 패딩 추가
    double padding = 0.002; // 약 200m
    minLat -= padding;
    maxLat += padding;
    minLng -= padding;
    maxLng += padding;

    // 경계 설정 및 카메라 이동
    final bounds = NLatLngBounds(
      southWest: NLatLng(minLat, minLng),
      northEast: NLatLng(maxLat, maxLng),
    );

    _mapController!.updateCamera(
      NCameraUpdate.fitBounds(bounds, padding: EdgeInsets.all(64)),
    );
  }

  // 현재 속도 가져오기
  double getCurrentSpeed() {
    return _currentSpeed;
  }

  // 현재 속도 제한 가져오기
  int getSpeedLimit() {
    return _speedLimit;
  }

  // 현재 턴바이턴 지시 가져오기
  Map<String, dynamic>? getCurrentInstruction() {
    return _currentInstruction;
  }

  // 다음 턴바이턴 지시 가져오기
  Map<String, dynamic>? getNextInstruction() {
    return _nextInstruction;
  }

  // 두 좌표 간 거리 계산 (미터)
  double _calculateDistance(NLatLng point1, NLatLng point2) {
    const double earthRadius = 6371000; // 지구 반지름 (미터)
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

  // 거리 포맷팅
  String _formatDistance(int meters) {
    if (meters < 1000) {
      return '${meters}m';
    } else {
      double km = meters / 1000.0;
      return '${km.toStringAsFixed(1)}km';
    }
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

  // 리소스 해제
  void dispose() {
    // 모든 스트림 컨트롤러 닫기
    _navigationInfoController.close();
    _locationController.close();
    _routeDeviationController.close();
    _arrivalController.close();
    _turnByTurnController.close();
    _speedLimitController.close();

    // 위치 스트림 구독 취소
    _positionStreamSubscription?.cancel();
  }
}
