import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:tomapto/controllers/map/transit_map_controller.dart';
import 'package:tomapto/controllers/map/route_controller.dart';
import 'package:tomapto/utils/route_renderer.dart';
import 'package:tomapto/pages/map/navigation_page.dart';

class CarModal extends StatefulWidget {
  final NLatLng? initialPosition;
  final String originPlace;
  final String destinationPlace;
  final TransitMapController transitMapController;
  final Function(NLatLng) onLocationUpdated;

  const CarModal({
    super.key,
    required this.initialPosition,
    required this.originPlace,
    required this.destinationPlace,
    required this.transitMapController,
    required this.onLocationUpdated,
  });

  @override
  State<CarModal> createState() => _CarModalState();
}

class _CarModalState extends State<CarModal> {
  bool _isLoading = true;
  bool _isRouteLoading = false;
  bool _hasRoute = false;

  // 경로 정보
  int _estimatedTime = 0; // 예상 시간(초)
  int _totalDistance = 0; // 총 거리(m)
  int _tollFee = 0; // 통행료

  // 도착지 고정값 설정 (위도: 37.5573946, 경도: 126.9560973)
  final NLatLng _fixedDestination = NLatLng(37.2978858, 127.0692787);

  // 도착지 주소 (고정)
  final String _fixedDestinationName = '안양시 동안구';

  // 경로 오버레이 및 마커
  NPathOverlay? _routePathOverlay;
  NMarker? _startMarker;
  NMarker? _destinationMarker;

  // 경로 컨트롤러
  final RouteController _routeController = RouteController();

  @override
  void initState() {
    super.initState();
    _isLoading = !widget.transitMapController.isCarMapInitialized;
  }

  // 경로 검색 및 표시
  Future<void> _searchAndDisplayRoute() async {
    if (widget.initialPosition == null) {
      print('출발지 위치 정보가 없습니다.');
      return;
    }

    setState(() {
      _isRouteLoading = true;
    });

    try {
      // 경로 계산 요청
      final routeData = await _routeController.searchCarRoute(
        widget.initialPosition!,
        _fixedDestination,
      );

      // 경로 정보 설정
      setState(() {
        _estimatedTime = routeData['duration'] ?? 0;
        _totalDistance = routeData['distance'] ?? 0;
        _tollFee = routeData['toll'] ?? 0;
        _hasRoute = true;
      });

      // 기존 경로 및 마커 제거
      _clearRouteAndMarkers();

      // 경로 좌표 가져오기
      final List<NLatLng> pathCoordinates = [];
      if (routeData['routes'] != null && routeData['routes'].isNotEmpty) {
        final route = routeData['routes'][0];
        if (route['path'] != null) {
          pathCoordinates.addAll(List<NLatLng>.from(route['path']));
        }
      }

      // 경로가 있으면 지도에 표시
      if (pathCoordinates.isNotEmpty) {
        // 경로 오버레이 생성 - 개선된 RouteRenderer 사용
        _routePathOverlay = RouteRenderer.createPathOverlay(
          'car_route',
          pathCoordinates,
          color: Color(0xFFFB233B),
          width: 6.0, // 약간 더 두껍게
        );

        // 출발지와 도착지 마커 생성 - 개선된 RouteRenderer 사용
        _startMarker = RouteRenderer.createStartMarker(
          widget.initialPosition!,
          title: '출발',
          animated: true, // 애니메이션 추가
        );

        _destinationMarker = RouteRenderer.createDestinationMarker(
          _fixedDestination,
          title: '도착',
          animated: true, // 애니메이션 추가
        );

        // 경로와 마커를 지도에 추가
        final controller =
            widget.transitMapController.carMapController.controller;
        if (controller != null) {
          controller.addOverlay(_routePathOverlay!);
          controller.addOverlay(_startMarker!);
          controller.addOverlay(_destinationMarker!);

          // 경로가 모두 보이도록 카메라 이동
          final minLat = pathCoordinates
              .map((p) => p.latitude)
              .reduce((a, b) => a < b ? a : b);
          final minLng = pathCoordinates
              .map((p) => p.longitude)
              .reduce((a, b) => a < b ? a : b);
          final maxLat = pathCoordinates
              .map((p) => p.latitude)
              .reduce((a, b) => a > b ? a : b);
          final maxLng = pathCoordinates
              .map((p) => p.longitude)
              .reduce((a, b) => a > b ? a : b);

          final bounds = NLatLngBounds(
            southWest: NLatLng(minLat, minLng),
            northEast: NLatLng(maxLat, maxLng),
          );

          controller.updateCamera(
            NCameraUpdate.fitBounds(bounds, padding: EdgeInsets.all(64)),
          );
        }
      }
    } catch (e) {
      print('경로 검색 오류: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('경로를 검색하는 중 오류가 발생했습니다.')));
    } finally {
      setState(() {
        _isRouteLoading = false;
      });
    }
  }

  // 경로와 마커 제거
  void _clearRouteAndMarkers() {
    final controller = widget.transitMapController.carMapController.controller;
    if (controller != null) {
      if (_routePathOverlay != null) {
        controller.deleteOverlay(_routePathOverlay!.info);
        _routePathOverlay = null;
      }

      if (_startMarker != null) {
        controller.deleteOverlay(_startMarker!.info);
        _startMarker = null;
      }

      if (_destinationMarker != null) {
        controller.deleteOverlay(_destinationMarker!.info);
        _destinationMarker = null;
      }
    }
  }

  // 내비게이션 페이지로 이동
  void _startNavigation() {
    if (!_hasRoute) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => NavigationPage(
              mode: TransitMode.car,
              origin: widget.initialPosition!,
              destination: _fixedDestination,
              originName: widget.originPlace,
              destinationName: _fixedDestinationName,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 컨텐츠 패딩 (지도 사용 시 필요)
    final contentPadding = EdgeInsets.fromLTRB(0, 0, 0, 160.0); // 모달을 위한 공간 확보

    return Stack(
      children: [
        // 자동차 네이버 맵
        NaverMap(
          options: NaverMapViewOptions(
            initialCameraPosition: NCameraPosition(
              target:
                  widget.initialPosition ??
                  NLatLng(37.5666805, 126.9784147), // 현재 위치 또는 서울 시청 (기본값)
              zoom: widget.transitMapController.getDefaultZoomLevel(
                TransitMode.car,
              ),
            ),
            mapType: NMapType.basic,
            contentPadding: contentPadding,
            locationButtonEnable: true, // 현재 위치 버튼 활성화
          ),
          onMapReady: (controller) {
            print('자동차 맵 컨트롤러 준비 완료');
            setState(() {
              _isLoading = false; // 맵 로딩 완료
              widget.transitMapController.carMapController.setMapController(
                controller,
              );
              widget.transitMapController.setMapInitialized(
                TransitMode.car,
                true,
              );
            });

            // 현재 위치가 있으면 경로 검색 및 표시
            if (widget.initialPosition != null) {
              _searchAndDisplayRoute();
            }
          },
          onCameraIdle: () {
            // 카메라 움직임이 멈추었을 때 줌 레벨 업데이트
            if (widget.transitMapController.carMapController.controller !=
                null) {
              widget.transitMapController.carMapController
                  .getCurrentCameraPosition()
                  .then((cameraPosition) {
                    if (cameraPosition != null) {
                      double zoom = cameraPosition.zoom;
                      widget.transitMapController.carMapController.setZoomLevel(
                        zoom,
                      );
                      print('자동차 탭 줌 레벨 업데이트됨: $zoom');
                    }
                  });
            }
          },
          onMapTapped: (point, latLng) {
            print('자동차 지도가 탭되었습니다: $latLng');
            // 위치 업데이트 콜백 호출
            widget.onLocationUpdated(latLng);

            // 경로 재계산
            _searchAndDisplayRoute();
          },
        ),

        // 맵 로딩 표시
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFFFB233B)),
          ),

        // 경로 로딩 표시
        if (_isRouteLoading)
          Positioned(
            bottom: 180,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFB233B),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('경로 계산 중...'),
                  ],
                ),
              ),
            ),
          ),

        // 경로 정보 모달
        if (_hasRoute)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 출발지-도착지 정보
                  Row(
                    children: [
                      const Icon(
                        Icons.circle,
                        color: Color(0xFFFB233B),
                        size: 12,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.originPlace,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 5),
                    height: 20,
                    width: 1,
                    color: Colors.grey[300],
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.blue,
                        size: 12,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _fixedDestinationName, // 고정된 도착지 주소
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 경로 요약 정보
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        // 도착 예정 시간 추가
                        Text(
                          RouteRenderer.getArrivalTime(_estimatedTime),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFB233B),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 시간, 거리 표시
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text(
                                  '예상 시간',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  RouteRenderer.formatDuration(_estimatedTime),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              height: 30,
                              width: 1,
                              color: Colors.grey[300],
                            ),
                            Column(
                              children: [
                                const Text(
                                  '총 거리',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  RouteRenderer.formatDistance(_totalDistance),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // 통행료 표시 (있는 경우에만)
                        if (_tollFee > 0) ...[
                          const SizedBox(height: 12),
                          Text(
                            '통행료: ${RouteRenderer.formatFare(_tollFee)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 안내 시작 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _startNavigation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFFB233B),
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
    );
  }
}
