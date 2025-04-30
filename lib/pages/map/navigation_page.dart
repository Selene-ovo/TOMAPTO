import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:tomapto/controllers/map/transit_map_controller.dart';
import 'package:tomapto/controllers/map/route_controller.dart';
import 'package:tomapto/utils/route_renderer.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

class NavigationPage extends StatefulWidget {
  final TransitMode mode;
  final NLatLng origin;
  final NLatLng destination;
  final String originName;
  final String destinationName;

  const NavigationPage({
    super.key,
    required this.mode,
    required this.origin,
    required this.destination,
    required this.originName,
    required this.destinationName,
  });

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  NaverMapController? _mapController;
  bool _isNavigating = false;
  String _currentInstruction = '안내를 시작합니다.';
  int _remainingDistance = 0;
  int _remainingTime = 0;
  double _currentHeading = 0.0;
  NLatLng _currentPosition = NLatLng(0, 0);

  // 네비게이션 마커와 경로
  NMarker? _currentLocationMarker;
  NPathOverlay? _routePathOverlay;
  List<NPathOverlay> _progressPathOverlays = [];
  NMarker? _startMarker;
  NMarker? _destinationMarker;

  // 경로 좌표 리스트
  List<NLatLng> _routeCoordinates = [];
  int _currentRouteIndex = 0;

  // 시뮬레이션 모드 (실제 이동이 아닌 가상 이동)
  final bool _isSimulationMode = true;
  Timer? _simulationTimer;

  // 위치 및 방향 구독
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<CompassEvent>? _compassStreamSubscription;

  // 경로 컨트롤러
  final RouteController _routeController = RouteController();

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.origin;
    _setupCompassListener();
    _fetchRouteData();
  }

  @override
  void dispose() {
    _stopNavigation();
    _compassStreamSubscription?.cancel();
    _positionStreamSubscription?.cancel();
    _simulationTimer?.cancel();
    super.dispose();
  }

  // 나침반 업데이트 리스너 설정
  void _setupCompassListener() {
    if (FlutterCompass.events != null) {
      _compassStreamSubscription = FlutterCompass.events!.listen((event) {
        if (mounted && event.heading != null) {
          setState(() {
            _currentHeading = event.heading!;
            _updateCurrentLocationMarker();
          });
        }
      });
    }
  }

  // 경로 데이터 가져오기
  Future<void> _fetchRouteData() async {
    try {
      Map<String, dynamic> routeData;

      if (widget.mode == TransitMode.car) {
        routeData = await _routeController.searchCarRoute(
          widget.origin,
          widget.destination,
        );
      } else {
        routeData = await _routeController.searchWalkRoute(
          widget.origin,
          widget.destination,
        );
      }

      setState(() {
        _remainingDistance = routeData['distance'] ?? 0;
        _remainingTime = routeData['duration'] ?? 0;

        // 경로 좌표 가져오기
        if (routeData['routes'] != null && routeData['routes'].isNotEmpty) {
          final route = routeData['routes'][0];
          if (route['path'] != null) {
            _routeCoordinates = List<NLatLng>.from(route['path']);
          }
        }
      });

      // 기본 안내 메시지 설정
      _updateNavigationInstruction();
    } catch (e) {
      print('경로 데이터 가져오기 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('경로 정보를 불러오는데 실패했습니다.')));
      }
    }
  }

  void _startNavigation() {
    if (_isNavigating) return;

    setState(() {
      _isNavigating = true;
      _currentInstruction =
          '${widget.mode == TransitMode.car ? '자동차' : '도보'} 경로 안내를 시작합니다.';
    });

    if (_isSimulationMode) {
      _startSimulation();
    } else {
      _startRealNavigation();
    }

    // 경로 그리기
    _drawRoute();
  }

  void _stopNavigation() {
    if (!_isNavigating) return;

    _simulationTimer?.cancel();
    _positionStreamSubscription?.cancel();

    setState(() {
      _isNavigating = false;
      _currentInstruction = '안내가 종료되었습니다.';
    });

    // 경로와 마커 제거
    _clearRouteAndMarkers();
  }

  // 실제 내비게이션 시작 (실제 위치 추적)
  void _startRealNavigation() {
    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // 5m마다 위치 업데이트
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      setState(() {
        _currentPosition = NLatLng(position.latitude, position.longitude);
        _updateProgress();
        _updateCurrentLocationMarker();
      });
    });
  }

  // 시뮬레이션 모드 시작 (가상 이동)
  void _startSimulation() {
    if (_routeCoordinates.isEmpty) return;

    _currentRouteIndex = 0;
    const updateIntervalMs = 1000; // 1초마다 업데이트

    _simulationTimer = Timer.periodic(
      const Duration(milliseconds: updateIntervalMs),
      (timer) {
        if (_currentRouteIndex < _routeCoordinates.length) {
          setState(() {
            _currentPosition = _routeCoordinates[_currentRouteIndex];
            _updateProgress();
            _updateCurrentLocationMarker();
            _updateProgressPath();
            _currentRouteIndex++;
          });
        } else {
          // 목적지 도착
          _simulationTimer?.cancel();
          setState(() {
            _currentInstruction = '목적지에 도착했습니다.';
            _remainingDistance = 0;
            _remainingTime = 0;
          });
        }
      },
    );
  }

  // 현재 위치 마커 업데이트
  void _updateCurrentLocationMarker() {
    if (_mapController == null) return;

    // 기존 마커 제거
    if (_currentLocationMarker != null) {
      _mapController!.deleteOverlay(_currentLocationMarker!.info);
    }

    // 새 마커 생성
    _currentLocationMarker = RouteRenderer.createCurrentLocationMarker(
      _currentPosition,
      heading: _currentHeading,
    );

    // 마커 추가
    _mapController!.addOverlay(_currentLocationMarker!);

    // 카메라 업데이트 - 현재 위치 중심으로
    _mapController!.updateCamera(
      NCameraUpdate.withParams(
        target: _currentPosition,
        zoom: 17,
        bearing: _currentHeading, // 카메라 방향을 현재 방향과 일치시킴
        tilt: 50, // 3D 효과를 위한 틸트
      ),
    );
  }

  // 경로 그리기
  void _drawRoute() {
    if (_mapController == null || _routeCoordinates.isEmpty) return;

    // 기존 경로 제거
    _clearRouteAndMarkers();

    // 경로 생성 및 추가
    _routePathOverlay = RouteRenderer.createPathOverlay(
      'navigation_route',
      _routeCoordinates,
      color: widget.mode == TransitMode.car ? Color(0xFFFB233B) : Colors.blue,
      width: 6.0,
    );

    _mapController!.addOverlay(_routePathOverlay!);

    // 출발지와 도착지 마커 추가
    _startMarker = RouteRenderer.createStartMarker(
      widget.origin,
      title: widget.originName,
    );

    _destinationMarker = RouteRenderer.createDestinationMarker(
      widget.destination,
      title: widget.destinationName,
    );

    _mapController!.addOverlay(_startMarker!);
    _mapController!.addOverlay(_destinationMarker!);
  }

  // 진행상황 경로 업데이트
  void _updateProgressPath() {
    if (_mapController == null || _routeCoordinates.isEmpty) return;

    // 기존 진행 경로 제거
    for (var overlay in _progressPathOverlays) {
      _mapController!.deleteOverlay(overlay.info);
    }
    _progressPathOverlays.clear();

    // 새 진행 경로 생성
    _progressPathOverlays = RouteRenderer.createProgressPathOverlay(
      _routeCoordinates,
      _currentRouteIndex,
    );

    // 진행 경로 추가
    for (var overlay in _progressPathOverlays) {
      _mapController!.addOverlay(overlay);
    }
  }

  // 진행상황 업데이트
  void _updateProgress() {
    if (_routeCoordinates.isEmpty) return;

    // 현재 위치와 가장 가까운 경로 포인트 찾기
    int closestPointIndex = 0;
    double minDistance = double.maxFinite;

    for (int i = 0; i < _routeCoordinates.length; i++) {
      final distance = Geolocator.distanceBetween(
        _currentPosition.latitude,
        _currentPosition.longitude,
        _routeCoordinates[i].latitude,
        _routeCoordinates[i].longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestPointIndex = i;
      }
    }

    // 남은 거리 계산
    _remainingDistance = 0;
    for (int i = closestPointIndex; i < _routeCoordinates.length - 1; i++) {
      _remainingDistance +=
          Geolocator.distanceBetween(
            _routeCoordinates[i].latitude,
            _routeCoordinates[i].longitude,
            _routeCoordinates[i + 1].latitude,
            _routeCoordinates[i + 1].longitude,
          ).toInt();
    }

    // 남은 시간 계산 (거리에 비례하여 간단하게 계산)
    if (widget.mode == TransitMode.car) {
      // 자동차: 평균 속도 40km/h (=11.1m/s) 가정
      _remainingTime = (_remainingDistance / 11.1).round();
    } else {
      // 도보: 평균 속도 4km/h (=1.1m/s) 가정
      _remainingTime = (_remainingDistance / 1.1).round();
    }

    // 안내 메시지 업데이트
    _updateNavigationInstruction();

    // 목적지 근처에 도착했는지 확인
    if (_remainingDistance <= 20) {
      setState(() {
        _currentInstruction = '목적지 주변에 도착했습니다.';
      });

      if (_isSimulationMode) {
        _simulationTimer?.cancel();
      }
    }
  }

  // 안내 메시지 업데이트
  void _updateNavigationInstruction() {
    String roadName = '현재 도로';

    // 남은 거리에 따른 안내 메시지
    setState(() {
      _currentInstruction = RouteRenderer.getGuidanceMessage(
        _remainingDistance,
        roadName,
      );
    });
  }

  // 경로와 마커 제거
  void _clearRouteAndMarkers() {
    if (_mapController == null) return;

    if (_routePathOverlay != null) {
      _mapController!.deleteOverlay(_routePathOverlay!.info);
      _routePathOverlay = null;
    }

    for (var overlay in _progressPathOverlays) {
      _mapController!.deleteOverlay(overlay.info);
    }
    _progressPathOverlays.clear();

    if (_currentLocationMarker != null) {
      _mapController!.deleteOverlay(_currentLocationMarker!.info);
      _currentLocationMarker = null;
    }

    if (_startMarker != null) {
      _mapController!.deleteOverlay(_startMarker!.info);
      _startMarker = null;
    }

    if (_destinationMarker != null) {
      _mapController!.deleteOverlay(_destinationMarker!.info);
      _destinationMarker = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 네이버 맵
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: widget.origin,
                zoom: 17,
                bearing: 0,
                tilt: 50,
              ),
              mapType: NMapType.basic,
              nightModeEnable: false,
              locationButtonEnable: true,
            ),
            onMapReady: (controller) {
              _mapController = controller;

              // 출발지-도착지 마커 추가
              final startMarker = RouteRenderer.createStartMarker(
                widget.origin,
                title: widget.originName,
              );

              final destinationMarker = RouteRenderer.createDestinationMarker(
                widget.destination,
                title: widget.destinationName,
              );

              startMarker.setIconTintColor(
                widget.mode == TransitMode.car
                    ? Color(0xFFFB233B)
                    : Colors.blue,
              );

              controller.addOverlay(startMarker);
              controller.addOverlay(destinationMarker);

              // 경로가 모두 보이도록 카메라 위치 조정
              final minLat = [
                widget.origin.latitude,
                widget.destination.latitude,
              ].reduce((a, b) => a < b ? a : b);
              final minLng = [
                widget.origin.longitude,
                widget.destination.longitude,
              ].reduce((a, b) => a < b ? a : b);
              final maxLat = [
                widget.origin.latitude,
                widget.destination.latitude,
              ].reduce((a, b) => a > b ? a : b);
              final maxLng = [
                widget.origin.longitude,
                widget.destination.longitude,
              ].reduce((a, b) => a > b ? a : b);

              final bounds = NLatLngBounds(
                southWest: NLatLng(minLat, minLng),
                northEast: NLatLng(maxLat, maxLng),
              );

              controller.updateCamera(
                NCameraUpdate.fitBounds(bounds, padding: EdgeInsets.all(100)),
              );
            },
          ),

          // 상단 바
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.destinationName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${widget.mode == TransitMode.car ? '자동차' : '도보'} 경로 안내',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(_isNavigating ? Icons.stop : Icons.play_arrow),
                      onPressed:
                          _isNavigating ? _stopNavigation : _startNavigation,
                      color:
                          widget.mode == TransitMode.car
                              ? Color(0xFFFB233B)
                              : Colors.blue,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 안내 상자
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 안내 텍스트
                  Row(
                    children: [
                      Icon(
                        Icons.directions,
                        size: 24,
                        color:
                            widget.mode == TransitMode.car
                                ? Color(0xFFFB233B)
                                : Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _currentInstruction,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 남은 거리 및 시간
                  if (_isNavigating)
                    Column(
                      children: [
                        // 도착 예정 시간 추가
                        Text(
                          RouteRenderer.getArrivalTime(_remainingTime),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                widget.mode == TransitMode.car
                                    ? Color(0xFFFB233B)
                                    : Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text(
                                  '남은 거리',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  RouteRenderer.formatDistance(
                                    _remainingDistance,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const Text(
                                  '남은 시간',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  RouteRenderer.formatDuration(_remainingTime),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // 모드에 따른 추가 정보
                        if (widget.mode == TransitMode.car &&
                            _remainingDistance > 1000) ...[
                          const SizedBox(height: 12),
                          Text(
                            '예상 연료 소모량: ${(_remainingDistance / 1000 * 0.08).toStringAsFixed(1)}L',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],

                        if (widget.mode == TransitMode.walk &&
                            _remainingDistance > 100) ...[
                          const SizedBox(height: 12),
                          Text(
                            '소모 칼로리: 약 ${(_remainingDistance * 0.05).toInt()}kcal',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ],
                    ),

                  // 안내 시작/종료 버튼
                  if (!_isNavigating) const SizedBox(height: 16),

                  if (!_isNavigating)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _startNavigation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              widget.mode == TransitMode.car
                                  ? Color(0xFFFB233B)
                                  : Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '안내 시작',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
