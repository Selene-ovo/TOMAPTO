import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:tomapto/controllers/map/location_controller.dart';
import 'package:tomapto/controllers/map/transit_map_controller.dart';
import 'package:tomapto/controllers/route/route_main_controller.dart';
import 'package:tomapto/widgets/search_bar_widget.dart';
import 'package:tomapto/widgets/transit_option_widget.dart';
import 'package:tomapto/modal/car_modal.dart';
import 'package:tomapto/modal/walk_modal.dart';
import 'package:tomapto/pages/map/naver_map.dart';
import 'package:tomapto/controllers/map/transit_provider.dart';
import 'package:provider/provider.dart';

class TransitApp extends StatefulWidget {
  final String? initialOriginPlace;
  final String? initialDestinationPlace;
  final NLatLng? initialOriginCoords;
  final NLatLng? initialDestinationCoords;

  const TransitApp({
    super.key,
    this.initialOriginPlace,
    this.initialDestinationPlace,
    this.initialOriginCoords,
    this.initialDestinationCoords,
  });

  @override
  State<TransitApp> createState() => _TransitAppState();
}

class _TransitAppState extends State<TransitApp> {
  int _selectedIndex = 0;
  String _originPlace = '위치 확인 중...';
  String _destinationPlace = '도착지 입력';
  NLatLng? _originCoords;
  NLatLng? _destinationCoords;

  final LocationController _locationController = LocationController();
  final TransitMapController _transitMapController = TransitMapController();
  final RouteController _routeController = RouteController();

  @override
  void initState() {
    super.initState();

    // Provider에 초기 데이터 설정 후 로컬 상태 동기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final transitProvider = Provider.of<TransitProvider>(
        context,
        listen: false,
      );

      // Provider에 초기 데이터 설정
      transitProvider.setInitialData(
        initialOriginPlace: widget.initialOriginPlace,
        initialOriginCoords: widget.initialOriginCoords,
        initialDestinationPlace: widget.initialDestinationPlace,
        initialDestinationCoords: widget.initialDestinationCoords,
      );

      // Provider 상태를 로컬 상태와 동기화
      _syncWithProvider();
    });

    _initializeLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyInitialPlaces();
    });
  }

  void _syncWithProvider() {
    final transitProvider = Provider.of<TransitProvider>(
      context,
      listen: false,
    );

    setState(() {
      _originPlace = transitProvider.originPlace;
      _destinationPlace = transitProvider.destinationPlace;
      _originCoords = transitProvider.originCoords;
      _destinationCoords = transitProvider.destinationCoords;
    });
  }

  @override
  void dispose() {
    _transitMapController.dispose();
    super.dispose();
  }

  /// 초기 출발지/도착지 설정
  void _applyInitialPlaces() async {
    _transitMapController.clearAllMarkersAndRoutes();
    bool shouldUpdateState = false;

    // 출발지 처리
    if (widget.initialOriginPlace != null) {
      if (widget.initialOriginCoords != null) {
        // 좌표가 직접 전달된 경우
        _originPlace = widget.initialOriginPlace!;
        _originCoords = widget.initialOriginCoords!;
        _transitMapController.setCurrentPosition(_originCoords!);
        shouldUpdateState = true;
      } else if (widget.initialOriginPlace == "현재 위치") {
        // 현재 위치인 경우
        _originPlace = "현재 위치";
        _routeController.invalidateCache();
        await _getOriginCoordinates();
        shouldUpdateState = true;
      } else {
        // 일반 주소 검색
        _originPlace = widget.initialOriginPlace!;
        _routeController.invalidateCache();
        await _getOriginCoordinates();
        shouldUpdateState = true;
      }
    }

    // 도착지 처리
    if (widget.initialDestinationPlace != null &&
        widget.initialDestinationPlace != '도착지 입력') {
      if (widget.initialDestinationCoords != null) {
        // 좌표가 직접 전달된 경우
        _destinationPlace = widget.initialDestinationPlace!;
        _destinationCoords = widget.initialDestinationCoords!;
        _transitMapController.setDestinationPosition(_destinationCoords!);
        shouldUpdateState = true;
      } else {
        // 일반 주소 검색
        _destinationPlace = widget.initialDestinationPlace!;
        _routeController.invalidateCache();
        await _getDestinationCoordinates();
        shouldUpdateState = true;
      }
    }

    if (shouldUpdateState) {
      setState(() {});
    }
  }

  /// 출발지 주소를 좌표로 변환
  Future<void> _getOriginCoordinates() async {
    // 좌표가 이미 설정되어 있으면 기존 좌표 사용
    if (_originCoords != null) {
      _transitMapController.setCurrentPosition(_originCoords!);
      if (_destinationPlace == '도착지 입력' || _destinationCoords == null) {
        _transitMapController.moveCamera(
          _selectedIndex == 0 ? TransitMode.car : TransitMode.walk,
          _originCoords!,
          17,
        );
      }
      return;
    }

    // 위치 상태 체크
    if (_isInvalidLocationState(_originPlace)) {
      return;
    }

    // 현재 위치인 경우 GPS 좌표 사용
    if (_originPlace == "현재 위치") {
      await _setCurrentLocationAsOrigin();
      return;
    }

    // 주소 검색으로 좌표 찾기
    await _searchOriginCoordinates();
  }

  /// 도착지 주소를 좌표로 변환
  Future<void> _getDestinationCoordinates() async {
    if (_destinationPlace == '도착지 입력') {
      setState(() {
        _destinationCoords = null;
      });
      _transitMapController.setDestinationPosition(null);
      return;
    }

    // 현재 위치인 경우
    if (_destinationPlace == "현재 위치") {
      await _setCurrentLocationAsDestination();
      return;
    }

    // 주소 검색으로 좌표 찾기
    await _searchDestinationCoordinates();
  }

  /// 초기 위치 설정
  Future<void> _initializeLocation() async {
    final hasPermission = await _locationController.checkLocationPermission(
      context,
    );
    if (!hasPermission) {
      setState(() {
        _originPlace = '위치 권한 없음';
      });
      return;
    }

    final position = await _locationController.getCurrentLocation();
    if (position != null) {
      setState(() {
        _originCoords = position;
      });
      _transitMapController.setCurrentPosition(position);

      // 초기 출발지가 설정되지 않은 경우에만 현재 위치를 출발지로 설정
      if (widget.initialOriginPlace == null) {
        final address = await _routeController.getAddressFromCoords(position);
        setState(() {
          _originPlace = address;
        });
      }
    } else {
      if (widget.initialOriginPlace == null) {
        setState(() {
          _originPlace = '위치 확인 실패';
        });
      }
    }
  }

  /// 경로를 표시하기 위한 카메라 범위 조정
  void _fitBoundsToShowRoute(NLatLng origin, NLatLng destination) {
    double distance = _calculateDistance(origin, destination);

    if (distance < 0.5) {
      _transitMapController.moveCamera(
        _selectedIndex == 0 ? TransitMode.car : TransitMode.walk,
        origin,
        18,
      );
      return;
    }

    double minLat =
        origin.latitude < destination.latitude
            ? origin.latitude
            : destination.latitude;
    double maxLat =
        origin.latitude > destination.latitude
            ? origin.latitude
            : destination.latitude;
    double minLng =
        origin.longitude < destination.longitude
            ? origin.longitude
            : destination.longitude;
    double maxLng =
        origin.longitude > destination.longitude
            ? origin.longitude
            : destination.longitude;

    double padding = distance < 2.0 ? 0.005 : 0.015;
    minLat -= padding;
    maxLat += padding;
    minLng -= padding;
    maxLng += padding;

    final bounds = NLatLngBounds(
      southWest: NLatLng(minLat, minLng),
      northEast: NLatLng(maxLat, maxLng),
    );

    final controller =
        _selectedIndex == 0
            ? _transitMapController.carMapController.controller
            : _transitMapController.walkMapController.controller;

    if (controller != null) {
      double cameraPadding = distance < 2.0 ? 15.0 : 30.0;
      controller.updateCamera(
        NCameraUpdate.fitBounds(bounds, padding: EdgeInsets.all(cameraPadding)),
      );
    }
  }

  /// 현재 위치 새로고침
  void _refreshCurrentLocation(TransitMode mode) async {
    try {
      final position = await _locationController.getCurrentLocation();
      if (position != null) {
        setState(() {
          _originCoords = position;
        });
        _transitMapController.setCurrentPosition(position);
        _transitMapController.moveCamera(mode, position, 17);

        final address = await _routeController.getAddressFromCoords(position);
        setState(() {
          _originPlace = address;
        });

        _routeController.invalidateCache();
      } else {
        _showErrorMessage('현재 위치를 가져오는 데 실패했습니다.');
      }
    } catch (e) {
      _showErrorMessage('위치 정보를 가져오는 중 오류가 발생했습니다.');
    }
  }

  /// 두 좌표 간의 거리 계산 (킬로미터)
  double _calculateDistance(NLatLng point1, NLatLng point2) {
    const double earthRadius = 6371;
    const double pi = 3.1415926535897932;

    double lat1Rad = point1.latitude * (pi / 180);
    double lat2Rad = point2.latitude * (pi / 180);
    double dLat = (point2.latitude - point1.latitude) * (pi / 180);
    double dLon = (point2.longitude - point1.longitude) * (pi / 180);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// 네비게이션 탭 변경 처리
  void _handleNavIndexChanged(int index) {
    final isSameTab = _selectedIndex == index;

    setState(() {
      _selectedIndex = index;
    });

    final mode = index == 0 ? TransitMode.car : TransitMode.walk;
    final isMapInitialized =
        index == 0
            ? _transitMapController.isCarMapInitialized
            : _transitMapController.isWalkMapInitialized;

    if (isMapInitialized) {
      final position = _transitMapController.getCurrentPosition();
      if (position != null) {
        final destinationPosition =
            _transitMapController.getCurrentDestinationPosition();
        if (destinationPosition != null && _destinationPlace != '도착지 입력') {
          _fitBoundsToShowRoute(position, destinationPosition);
        } else {
          _transitMapController.moveCamera(mode, position, 17);
          if (isSameTab) {
            _refreshCurrentLocation(mode);
          }
        }
      }
    }
  }

  /// 출발지 변경 처리
  void _handleOriginChanged(String value) async {
    final transitProvider = Provider.of<TransitProvider>(
      context,
      listen: false,
    );

    _transitMapController.clearAllMarkersAndRoutes();
    setState(() {
      _originPlace = value;
    });
    _routeController.invalidateCache();

    await _getOriginCoordinates();

    // Provider 업데이트
    transitProvider.setOrigin(value, _originCoords);

    await Future.delayed(Duration(milliseconds: 100));
    setState(() {});
  }

  /// 도착지 변경 처리
  void _handleDestinationChanged(String value) async {
    final transitProvider = Provider.of<TransitProvider>(
      context,
      listen: false,
    );

    _transitMapController.clearAllMarkersAndRoutes();
    setState(() {
      _destinationPlace = value;
    });
    _routeController.invalidateCache();

    await _getDestinationCoordinates();

    // Provider 업데이트
    transitProvider.setDestination(value, _destinationCoords);

    await Future.delayed(Duration(milliseconds: 100));
    setState(() {});
  }

  /// 출발지/도착지 위치 교환
  void _handleSwapLocations() async {
    final transitProvider = Provider.of<TransitProvider>(
      context,
      listen: false,
    );

    _transitMapController.clearAllMarkersAndRoutes();

    // Provider에서 교환 수행
    transitProvider.swapLocations();

    // 로컬 상태를 Provider와 동기화
    setState(() {
      _originPlace = transitProvider.originPlace;
      _destinationPlace = transitProvider.destinationPlace;
      _originCoords = transitProvider.originCoords;
      _destinationCoords = transitProvider.destinationCoords;
    });

    _routeController.invalidateCache();

    // TransitMapController에 새 위치 설정
    if (_originCoords != null) {
      _transitMapController.setCurrentPosition(_originCoords!);
    }
    _transitMapController.setDestinationPosition(_destinationCoords);

    // 모달 강제 갱신
    if (_originCoords != null &&
        _destinationCoords != null &&
        _destinationPlace != '도착지 입력') {
      await _forceModalRefresh();
    }
  }

  /// 지도 터치 처리 (현재는 비활성화)
  void _handleLocationUpdated(NLatLng latLng) {
    // 현재는 아무 작업도 수행하지 않음
  }

  // Private helper methods

  /// 위치 상태가 유효하지 않은지 확인
  bool _isInvalidLocationState(String place) {
    return place == '위치 확인 중...' ||
        place == '위치 권한 없음' ||
        place == '위치 확인 실패' ||
        place == '출발지 입력';
  }

  /// 현재 위치를 출발지로 설정
  Future<void> _setCurrentLocationAsOrigin() async {
    try {
      final position = await _locationController.getCurrentLocation();
      if (position != null) {
        setState(() {
          _originCoords = position;
        });
        _transitMapController.setCurrentPosition(_originCoords!);
      }
    } catch (e) {
      _showErrorMessage('현재 위치를 가져올 수 없습니다.');
    }
  }

  /// 현재 위치를 도착지로 설정
  Future<void> _setCurrentLocationAsDestination() async {
    try {
      final position = await _locationController.getCurrentLocation();
      if (position != null) {
        setState(() {
          _destinationCoords = position;
        });
        _transitMapController.setDestinationPosition(_destinationCoords!);
      }
    } catch (e) {
      _showErrorMessage('현재 위치를 가져올 수 없습니다.');
    }
  }

  /// 출발지 좌표 검색
  Future<void> _searchOriginCoordinates() async {
    try {
      final results = await _routeController.searchAddressByKeyword(
        _originPlace,
      );

      if (results.isNotEmpty) {
        final firstResult = results[0];
        if (firstResult['x'] != null && firstResult['y'] != null) {
          final coords = _routeController.convertAddressToCoords(firstResult);

          setState(() {
            _originCoords = coords;
          });

          _transitMapController.setCurrentPosition(_originCoords!);

          if (_destinationPlace == '도착지 입력' || _destinationCoords == null) {
            _transitMapController.moveCamera(
              _selectedIndex == 0 ? TransitMode.car : TransitMode.walk,
              coords,
              17,
            );
          }
        }
      }
    } catch (e) {
      _showErrorMessage('출발지 좌표를 찾을 수 없습니다.');
    }
  }

  /// 도착지 좌표 검색
  Future<void> _searchDestinationCoordinates() async {
    try {
      final results = await _routeController.searchAddressByKeyword(
        _destinationPlace,
      );

      if (results.isNotEmpty) {
        final firstResult = results[0];
        if (firstResult['x'] != null && firstResult['y'] != null) {
          final coords = _routeController.convertAddressToCoords(firstResult);

          setState(() {
            _destinationCoords = coords;
          });

          _transitMapController.setDestinationPosition(_destinationCoords!);
        }
      }
    } catch (e) {
      _showErrorMessage('도착지 좌표를 찾을 수 없습니다.');
    }
  }

  /// 모달 강제 새로고침
  Future<void> _forceModalRefresh() async {
    await Future.delayed(Duration(milliseconds: 200));

    int originalIndex = _selectedIndex;
    setState(() {
      _selectedIndex = (_selectedIndex == 0) ? 1 : 0;
    });

    await Future.delayed(Duration(milliseconds: 100));

    setState(() {
      _selectedIndex = originalIndex;
    });
  }

  /// 에러 메시지 표시
  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double width = screenSize.width;
    final bool isSmallScreen = width < 360;
    final double iconSize = isSmallScreen ? 22.0 : 28.0;

    return Consumer<TransitProvider>(
      builder: (context, transitProvider, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              SearchBarWidget(
                originPlace: transitProvider.originPlace,
                destinationPlace: transitProvider.destinationPlace,
                onOriginChanged: _handleOriginChanged,
                onDestinationChanged: _handleDestinationChanged,
                onSwapLocations: _handleSwapLocations,
                onClosePressed: () {
                  // Provider 상태 초기화
                  final transitProvider = Provider.of<TransitProvider>(
                    context,
                    listen: false,
                  );
                  transitProvider.reset();

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NaverMapPage(),
                    ),
                    (route) => false,
                  );
                },
                currentOriginCoords: transitProvider.originCoords,
                currentDestinationCoords: transitProvider.destinationCoords,
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TransitOptionWidget(
                      index: 0,
                      selectedIndex: _selectedIndex,
                      icon: Icons.directions_car,
                      label: '자동차',
                      onTap: _handleNavIndexChanged,
                      iconSize: iconSize,
                    ),
                    TransitOptionWidget(
                      index: 1,
                      selectedIndex: _selectedIndex,
                      icon: Icons.directions_walk,
                      label: '도보',
                      onTap: _handleNavIndexChanged,
                      iconSize: iconSize,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    CarModal(
                      initialPosition: transitProvider.originCoords,
                      originPlace: transitProvider.originPlace,
                      destinationPlace: transitProvider.destinationPlace,
                      transitMapController: _transitMapController,
                      onLocationUpdated: _handleLocationUpdated,
                    ),
                    WalkModal(
                      initialPosition: transitProvider.originCoords,
                      originPlace: transitProvider.originPlace,
                      destinationPlace: transitProvider.destinationPlace,
                      transitMapController: _transitMapController,
                      onLocationUpdated: _handleLocationUpdated,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
