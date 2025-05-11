import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:tomapto/controllers/map/transit_map_controller.dart';
import 'package:tomapto/controllers/map/route_controller.dart';
import 'package:tomapto/utils/route_renderer.dart';
import 'package:tomapto/pages/map/navigation_page.dart';

class WalkModal extends StatefulWidget {
  final NLatLng? initialPosition;
  final String originPlace;
  final String destinationPlace;
  final TransitMapController transitMapController;
  final Function(NLatLng) onLocationUpdated;

  const WalkModal({
    super.key,
    required this.initialPosition,
    required this.originPlace,
    required this.destinationPlace,
    required this.transitMapController,
    required this.onLocationUpdated,
  });

  @override
  State<WalkModal> createState() => _WalkModalState();
}

class _WalkModalState extends State<WalkModal> {
  bool _isLoading = true;
  bool _isRouteLoading = false;
  bool _hasRoute = false;
  bool _routeHasBeenSearched = false;

  int _estimatedTime = 0;
  int _totalDistance = 0;

  // 출발지/도착지 좌표 저장
  NLatLng? _destinationCoords;

  NPathOverlay? _routePathOverlay;
  NMarker? _startMarker;
  NMarker? _destinationMarker;

  final RouteController _routeController = RouteController();

  @override
  void initState() {
    super.initState();
    _isLoading = !widget.transitMapController.isWalkMapInitialized;
  }

  @override
  void didUpdateWidget(WalkModal oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 좌표나 주소가 변경된 경우 마커 및 경로 업데이트
    if (oldWidget.initialPosition != widget.initialPosition ||
        oldWidget.destinationPlace != widget.destinationPlace ||
        oldWidget.originPlace != widget.originPlace) {
      if (widget.transitMapController.isWalkMapInitialized) {
        // 기존 마커와 경로 제거
        _clearRouteAndMarkers();

        // 경로 검색 초기화
        _routeHasBeenSearched = false;
        _hasRoute = false;

        if (widget.initialPosition != null) {
          // 출발지 마커 추가 (캡션 없이)
          _addOriginMarker(widget.initialPosition!);
        }

        // 도착지가 설정된 경우에만 마커 추가 및 경로 검색
        if (widget.destinationPlace != '도착지 입력') {
          Future.delayed(Duration(milliseconds: 300), () {
            _searchAndDisplayRoute();
          });
        }
      }
    }
  }

  // 출발지 마커 추가 - 캡션 없이
  void _addOriginMarker(NLatLng position) {
    final controller = widget.transitMapController.walkMapController.controller;
    if (controller == null) return;
    if (_startMarker != null) {
      controller.deleteOverlay(_startMarker!.info);
    }
    final markerImage = NOverlayImage.fromAssetImage(
      'assets/icons/start_marker.png',
    );
    _startMarker = NMarker(
      id: 'walk_origin_marker',
      position: position,
      icon: markerImage,
      size: const Size(40, 50),
      anchor: const NPoint(0.5, 1.0),
    );
    controller.addOverlay(_startMarker!);
  }

  // 도착지 마커 추가 - 캡션 없이
  void _addDestinationMarker(NLatLng position) {
    final controller = widget.transitMapController.walkMapController.controller;
    if (controller == null) return;
    if (_destinationMarker != null) {
      controller.deleteOverlay(_destinationMarker!.info);
    }
    final markerImage = NOverlayImage.fromAssetImage(
      'assets/icons/end_marker.png',
    );
    _destinationMarker = NMarker(
      id: 'walk_destination_marker',
      position: position,
      icon: markerImage,
      size: const Size(40, 50),
      anchor: const NPoint(0.5, 1.0),
    );
    controller.addOverlay(_destinationMarker!);
  }

  Future<void> _searchAndDisplayRoute() async {
    if (widget.initialPosition == null) {
      print('출발지 위치 정보가 없습니다.');
      return;
    }

    if (widget.destinationPlace == '도착지 입력') {
      return;
    }

    // transit.dart로부터 좌표 전달 받기
    _destinationCoords =
        widget.transitMapController.getCurrentDestinationPosition();

    // 좌표가 없으면 경로 계산 불가
    if (_destinationCoords == null) {
      print('도착지 좌표가 없습니다. 경로를 계산할 수 없습니다.');
      return;
    }

    setState(() {
      _isRouteLoading = true;
    });

    try {
      final routeData = await _routeController.searchWalkRoute(
        widget.initialPosition!,
        _destinationCoords!,
      );

      setState(() {
        _estimatedTime = routeData['duration'] ?? 0;
        _totalDistance = routeData['distance'] ?? 0;
        _hasRoute = true;
      });

      _clearRouteAndMarkers();

      final List<NLatLng> pathCoordinates = [];
      if (routeData['routes'] != null && routeData['routes'].isNotEmpty) {
        final route = routeData['routes'][0];
        if (route['path'] != null) {
          pathCoordinates.addAll(List<NLatLng>.from(route['path']));
        }
      }

      final controller =
          widget.transitMapController.walkMapController.controller;
      if (controller == null) {
        print('맵 컨트롤러가 초기화되지 않았습니다.');
        return;
      }

      if (pathCoordinates.isNotEmpty) {
        _routePathOverlay = NPathOverlay(
          id: 'walk_route',
          coords: pathCoordinates,
          width: 12.0,
          color: Color(0xFF0771EB),
          outlineWidth: 5.0,
          outlineColor: Color(0xFF0353AE),
          patternImage: NOverlayImage.fromAssetImage(
            'assets/icons/arrow_icon.png',
          ),
          patternInterval: 20,
          isHideCollidedCaptions: false,
          isHideCollidedMarkers: false,
          isHideCollidedSymbols: false,
        );

        controller.addOverlay(_routePathOverlay!);

        // 출발지 마커 추가 (캡션 없이)
        _addOriginMarker(widget.initialPosition!);

        // 도착지 마커 추가 (캡션 없이)
        _addDestinationMarker(_destinationCoords!);

        // 경로가 모두 보이도록 카메라 이동
        final bounds = _calculateBounds(pathCoordinates);
        controller.updateCamera(
          NCameraUpdate.fitBounds(bounds, padding: EdgeInsets.all(64)),
        );
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

  // 좌표 목록의 경계 계산
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

  void _clearRouteAndMarkers() {
    final controller = widget.transitMapController.walkMapController.controller;
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

      final markers = widget.transitMapController.getMarkersByMode(
        TransitMode.walk,
      );
      for (var marker in markers) {
        controller.deleteOverlay(marker.info);
      }
      markers.clear();
    }
  }

  void _startNavigation() {
    if (!_hasRoute || _destinationCoords == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => NavigationPage(
              mode: TransitMode.walk,
              origin: widget.initialPosition!,
              destination: _destinationCoords!,
              originName: widget.originPlace,
              destinationName: widget.destinationPlace,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contentPadding = EdgeInsets.fromLTRB(0, 0, 0, 250.0);

    return Stack(
      children: [
        NaverMap(
          options: NaverMapViewOptions(
            logoClickEnable: false,
            initialCameraPosition: NCameraPosition(
              target:
                  widget.initialPosition ?? NLatLng(37.5666805, 126.9784147),
              zoom: widget.transitMapController.getDefaultZoomLevel(
                TransitMode.walk,
              ),
            ),
            mapType: NMapType.basic,
            contentPadding: contentPadding,
            locationButtonEnable: true,
          ),
          onMapReady: (controller) {
            print('도보 맵 컨트롤러 준비 완료');
            print('초기 위치: ${widget.initialPosition}');
            print('도착지: ${widget.destinationPlace}');
            setState(() {
              _isLoading = false;
              widget.transitMapController.walkMapController.setMapController(
                controller,
              );
              widget.transitMapController.setMapInitialized(
                TransitMode.walk,
                true,
              );
            });

            if (widget.initialPosition != null) {
              // 출발지 마커 추가 (캡션 없이)
              _addOriginMarker(widget.initialPosition!);

              // 카메라 이동
              controller.updateCamera(
                NCameraUpdate.withParams(
                  target: widget.initialPosition!,
                  zoom: 18,
                ),
              );

              // 도착지가 설정된 경우 경로 검색
              if (!_routeHasBeenSearched &&
                  widget.destinationPlace != '도착지 입력') {
                _routeHasBeenSearched = true;
                Future.delayed(Duration(milliseconds: 500), () {
                  _searchAndDisplayRoute();
                });
              }
            }
          },
          onCameraIdle: () {
            if (widget.transitMapController.walkMapController.controller !=
                null) {
              widget.transitMapController.walkMapController
                  .getCurrentCameraPosition()
                  .then((cameraPosition) {
                    if (cameraPosition != null) {
                      double zoom = cameraPosition.zoom;
                      widget.transitMapController.walkMapController
                          .setZoomLevel(zoom);
                    }
                  });
            }
          },
          onMapTapped: (point, latLng) {
            // 지도 터치 이벤트를 전달하지만, transit.dart에서 처리하지 않음
            widget.onLocationUpdated(latLng);
          },
        ),

        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFF0771EB)),
          ),

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
                        color: Color(0xFF0771EB),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('경로 계산 중...'),
                  ],
                ),
              ),
            ),
          ),

        if (_hasRoute)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /* Row(
                    children: [
                      const Icon(
                        Icons.arrow_circle_right_rounded,
                        color: Color(0xFFFB233B),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.originPlace,
                          style: const TextStyle(
                            fontFamily: "Pretendard",
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Color(0xFF363636),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.arrow_circle_left_rounded,
                        color: Color(0xFF0771EB),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.destinationPlace,
                          style: const TextStyle(
                            fontFamily: "Pretendard",
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Color(0xFF363636),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
*/
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          RouteRenderer.getArrivalTime(_estimatedTime),
                          style: const TextStyle(
                            fontFamily: "Pretendard",
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0771EB),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text(
                                  '예상 시간',
                                  style: TextStyle(
                                    fontFamily: "Pretendard",
                                    fontWeight: FontWeight.w400,
                                    fontSize: 18,
                                    color: Color(0xFF818181),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  RouteRenderer.formatDuration(_estimatedTime),
                                  style: const TextStyle(
                                    fontFamily: "Pretendard",
                                    fontWeight: FontWeight.w600,
                                    fontSize: 22,
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
                                    fontFamily: "Pretendard",
                                    fontWeight: FontWeight.w400,
                                    fontSize: 18,
                                    color: Color(0xFF818181),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  RouteRenderer.formatDistance(_totalDistance),
                                  style: const TextStyle(
                                    fontFamily: "Pretendard",
                                    fontWeight: FontWeight.w600,
                                    fontSize: 22,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _startNavigation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0771EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        '안내 시작',
                        style: TextStyle(
                          fontFamily: "Pretendard",
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: Colors.white,
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
