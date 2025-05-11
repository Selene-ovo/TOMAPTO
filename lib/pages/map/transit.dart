import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:tomapto/controllers/map/location_controller.dart';
import 'package:tomapto/controllers/map/transit_map_controller.dart';
import 'package:tomapto/controllers/map/route_controller.dart';
import 'package:tomapto/widgets/search_bar_widget.dart';
import 'package:tomapto/widgets/transit_option_widget.dart';
import 'package:tomapto/modal/car_modal.dart';
import 'package:tomapto/modal/walk_modal.dart';
import 'package:tomapto/pages/map/naver_map.dart';

class TransitApp extends StatefulWidget {
  final String? initialOriginPlace;
  final String? initialDestinationPlace;

  const TransitApp({
    super.key,
    this.initialOriginPlace,
    this.initialDestinationPlace,
  });

  @override
  State<TransitApp> createState() => _TransitAppState();
}

class _TransitAppState extends State<TransitApp> {
  int _selectedIndex = 0;

  String _originPlace = '위치 확인 중...';
  String _destinationPlace = '도착지 입력';

  // 출발지와 도착지의 좌표 저장
  NLatLng? _originCoords;
  NLatLng? _destinationCoords;

  final LocationController _locationController = LocationController();
  // final AddressController _addressController = AddressController(); // 제거
  final TransitMapController _transitMapController = TransitMapController();
  final RouteController _routeController = RouteController();

  @override
  void initState() {
    super.initState();
    _initializeLocation();

    // 초기 출발지/도착지 설정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyInitialPlaces();
    });
  }

  // 초기 출발지/도착지 설정 메서드
  void _applyInitialPlaces() async {
    // 기존 마커 초기화
    _transitMapController.clearAllMarkersAndRoutes();

    bool shouldUpdateState = false;

    if (widget.initialOriginPlace != null) {
      _originPlace = widget.initialOriginPlace!;
      _routeController.invalidateCache();
      await _getOriginCoordinates();
      shouldUpdateState = true;
    }

    if (widget.initialDestinationPlace != null &&
        widget.initialDestinationPlace != '도착지 입력') {
      _destinationPlace = widget.initialDestinationPlace!;
      _routeController.invalidateCache();
      await _getDestinationCoordinates();
      shouldUpdateState = true;
    }

    // 변경사항이 있을 때만 setState 호출
    if (shouldUpdateState) {
      setState(() {
        print('초기값 설정 완료 - 출발지: $_originPlace, 도착지: $_destinationPlace');
      });
    }
  }

  // 출발지 주소를 좌표로 변환하는 메서드 - route_controller 사용
  Future<void> _getOriginCoordinates() async {
    print('_getOriginCoordinates 시작: $_originPlace');

    if (_originPlace == '위치 확인 중...' ||
        _originPlace == '위치 권한 없음' ||
        _originPlace == '위치 확인 실패') {
      return;
    }

    try {
      print('출발지 주소 검색: $_originPlace');
      final results = await _routeController.searchAddressByKeyword(
        _originPlace,
      );

      print('검색 결과 수: ${results.length}');

      if (results.isNotEmpty) {
        final firstResult = results[0];

        // 검색 결과 상세 로그
        print('첫 번째 검색 결과:');
        print('  name: ${firstResult['name']}');
        print('  address: ${firstResult['address']}');
        print('  x (mapx): ${firstResult['x']}');
        print('  y (mapy): ${firstResult['y']}');

        if (firstResult['x'] != null && firstResult['y'] != null) {
          final coords = _routeController.convertAddressToCoords(firstResult);

          print('변환된 좌표: $coords');

          setState(() {
            _originCoords = coords;
          });

          print('출발지 좌표 설정 완료: $_originCoords');
          _transitMapController.setCurrentPosition(_originCoords!);

          // 도착지가 설정되어 있지 않은 경우 출발지로 카메라 이동
          if (_destinationPlace == '도착지 입력' || _destinationCoords == null) {
            print('도착지가 없으므로 출발지로 카메라 이동');
            _transitMapController.moveCamera(
              _selectedIndex == 0 ? TransitMode.car : TransitMode.walk,
              coords,
              17,
            );
          }
        } else {
          print('좌표값이 null입니다. x: ${firstResult['x']}, y: ${firstResult['y']}');
        }
      } else {
        print('검색 결과가 없습니다.');
      }
    } catch (e) {
      print('출발지 좌표 변환 오류: $e');
      print('에러 스택 트레이스: $e');
    }
  }

  // 도착지 주소를 좌표로 변환하는 메서드 - route_controller 사용
  Future<void> _getDestinationCoordinates() async {
    print('_getDestinationCoordinates 시작: $_destinationPlace');

    if (_destinationPlace == '도착지 입력') {
      setState(() {
        _destinationCoords = null;
      });

      _transitMapController.setDestinationPosition(null);
      print('도착지 초기화 완료');
      return;
    }

    try {
      print('도착지 주소 검색: $_destinationPlace');
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

          print('도착지 좌표 설정 완료: $_destinationCoords');
          _transitMapController.setDestinationPosition(_destinationCoords!);
        }
      } else {
        print('도착지 검색 결과 없음: $_destinationPlace');
      }
    } catch (e) {
      print('도착지 좌표 변환 오류: $e');
    }
  }

  @override
  void dispose() {
    _transitMapController.dispose();
    super.dispose();
  }

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

    // 현재 위치 가져오기
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
      // 현재 위치를 가져올 수 없는 경우에도 초기 출발지 설정
      if (widget.initialOriginPlace == null) {
        setState(() {
          _originPlace = '위치 확인 실패';
        });
      }
    }
  }

  void _fitBoundsToShowRoute(NLatLng origin, NLatLng destination) {
    // 두 지점이 너무 가까이 있는지 확인
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

  void _refreshCurrentLocation(TransitMode mode) async {
    final position = await _locationController.getCurrentLocation();
    if (position != null) {
      setState(() {
        _originCoords = position;
      });
      _transitMapController.setCurrentPosition(position);

      // 자동차 모드와 도보 모드 둘 다 더 확대된 줌 레벨 사용
      _transitMapController.moveCamera(mode, position, 17);

      final address = await _routeController.getAddressFromCoords(position);
      setState(() {
        _originPlace = address;
      });

      _routeController.invalidateCache();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('현재 위치를 가져오는 데 실패했습니다.')));
    }
  }

  double _calculateDistance(NLatLng point1, NLatLng point2) {
    const double earthRadius = 6371; // 지구 반지름 (km)
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

  void _handleNavIndexChanged(int index) {
    final isSameTab = _selectedIndex == index;

    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      // 자동차 탭 선택
      if (_transitMapController.isCarMapInitialized) {
        final position = _transitMapController.getCurrentPosition();
        if (position != null) {
          // 도착지가 설정되어 있고 경로가 있는 경우
          final destinationPosition =
              _transitMapController.getCurrentDestinationPosition();
          if (destinationPosition != null && _destinationPlace != '도착지 입력') {
            _fitBoundsToShowRoute(position, destinationPosition);
          } else {
            _transitMapController.moveCamera(TransitMode.car, position, 17);

            if (isSameTab) {
              _refreshCurrentLocation(TransitMode.car);
            }
          }
        }
      }
    } else if (index == 1) {
      // 도보 탭 선택
      if (_transitMapController.isWalkMapInitialized) {
        final position = _transitMapController.getCurrentPosition();
        if (position != null) {
          // 도착지가 설정되어 있고 경로가 있는 경우
          final destinationPosition =
              _transitMapController.getCurrentDestinationPosition();
          if (destinationPosition != null && _destinationPlace != '도착지 입력') {
            _fitBoundsToShowRoute(position, destinationPosition);
          } else {
            _transitMapController.moveCamera(TransitMode.walk, position, 17);

            if (isSameTab) {
              _refreshCurrentLocation(TransitMode.walk);
            }
          }
        }
      }
    }
  }

  void _handleOriginChanged(String value) async {
    print('출발지 변경 시작: $value');
    _transitMapController.clearAllMarkersAndRoutes();
    setState(() {
      _originPlace = value;
    });
    _routeController.invalidateCache();

    await _getOriginCoordinates();

    await Future.delayed(Duration(milliseconds: 100));

    setState(() {});

    print('출발지 변경 완료 - 모달 업데이트 대기 중');
  }

  void _handleDestinationChanged(String value) async {
    print('도착지 변경 시작: $value');
    _transitMapController.clearAllMarkersAndRoutes();
    setState(() {
      _destinationPlace = value;
    });
    _routeController.invalidateCache();

    await _getDestinationCoordinates();

    await Future.delayed(Duration(milliseconds: 100));

    setState(() {});

    print('도착지 변경 완료 - 모달 업데이트 대기 중');
  }

  void _handleSwapLocations() async {
    print('출발지/도착지 스왑 시작');

    // 기존 마커와 경로 제거
    _transitMapController.clearAllMarkersAndRoutes();

    // 출발지와 도착지 정보 교환
    final tempPlace = _originPlace;
    final tempCoords = _originCoords;

    setState(() {
      _originPlace = _destinationPlace;
      _originCoords = _destinationCoords;

      _destinationPlace = tempPlace;
      _destinationCoords = tempCoords;
    });

    // 중요: 반드시 캐시를 무효화하여 새 경로를 강제로 계산하도록 함
    _routeController.invalidateCache();
    print('경로 캐시 무효화됨');

    // TransitMapController에 새 위치 설정
    if (_originCoords != null) {
      _transitMapController.setCurrentPosition(_originCoords!);
    }
    _transitMapController.setDestinationPosition(_destinationCoords);

    print('스왑 후 좌표 - 출발지: $_originCoords, 도착지: $_destinationCoords');

    // 이제 해당 모달의 업데이트를 강제
    if (_originCoords != null &&
        _destinationCoords != null &&
        _destinationPlace != '도착지 입력') {
      // 약간의 지연 후 setState를 호출하여 해당 모달의 didUpdateWidget을 트리거
      await Future.delayed(Duration(milliseconds: 200));

      // 명시적으로 currentIndex를 변경했다가 다시 원래 값으로 돌려서 재구축 강제
      int originalIndex = _selectedIndex;
      setState(() {
        _selectedIndex = (_selectedIndex == 0) ? 1 : 0; // 다른 값으로 변경
      });

      await Future.delayed(Duration(milliseconds: 100));

      setState(() {
        _selectedIndex = originalIndex; // 원래 값으로 복구
      });

      print('모달 강제 갱신 완료');
    }
  }

  // 지도 터치 핸들러 - 이제 아무 작업도 수행하지 않음
  void _handleLocationUpdated(NLatLng latLng) {
    // 지도 터치시 아무런 작업도 수행하지 않음
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double width = screenSize.width;
    final bool isSmallScreen = width < 360;
    final double iconSize = isSmallScreen ? 22.0 : 28.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SearchBarWidget(
            originPlace: _originPlace,
            destinationPlace: _destinationPlace,
            onOriginChanged: _handleOriginChanged,
            onDestinationChanged: _handleDestinationChanged,
            onSwapLocations: _handleSwapLocations,
            onClosePressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const NaverMapPage()),
                (route) => false,
              );
            },
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
                  initialPosition: _originCoords,
                  originPlace: _originPlace,
                  destinationPlace: _destinationPlace,
                  transitMapController: _transitMapController,
                  onLocationUpdated: _handleLocationUpdated,
                ),

                WalkModal(
                  initialPosition: _originCoords,
                  originPlace: _originPlace,
                  destinationPlace: _destinationPlace,
                  transitMapController: _transitMapController,
                  onLocationUpdated: _handleLocationUpdated,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
