import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:tomapto/controllers/map/location_controller.dart';
import 'package:tomapto/controllers/map/address_controller.dart';
import 'package:tomapto/controllers/map/transit_map_controller.dart';
import 'package:tomapto/controllers/map/route_controller.dart';
import 'package:tomapto/widgets/search_bar_widget.dart';
import 'package:tomapto/widgets/transit_option_widget.dart';
import 'package:tomapto/modal/car_modal.dart';
import 'package:tomapto/modal/walk_modal.dart';

class TransitApp extends StatefulWidget {
  const TransitApp({super.key});

  @override
  State<TransitApp> createState() => _TransitAppState();
}

class _TransitAppState extends State<TransitApp> {
  // 선택된 탭 인덱스 (0: 자동차, 1: 도보)
  int _selectedIndex = 0;

  // 출발지와 도착지를 저장할 변수
  String _originPlace = '위치 확인 중...';
  String _destinationPlace = '도착지 입력';

  // 컨트롤러 인스턴스 생성
  final LocationController _locationController = LocationController();
  final AddressController _addressController = AddressController();
  final TransitMapController _transitMapController = TransitMapController();
  final RouteController _routeController = RouteController();

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _transitMapController.dispose();
    super.dispose();
  }

  // 위치 초기화 및 주소 변환
  Future<void> _initializeLocation() async {
    // 권한 체크
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
      // 위치 정보를 TransitMapController에 설정
      _transitMapController.setCurrentPosition(position);

      // 위치 기반 주소 가져오기
      final address = await _addressController.getAddressFromLatLng(position);
      setState(() {
        _originPlace = address;
      });

      // 이미 초기화된 맵이 있으면 현재 위치로 카메라 이동
      if (_transitMapController.isCarMapInitialized) {
        _transitMapController.moveCamera(
          TransitMode.car,
          position,
          _transitMapController.getDefaultZoomLevel(TransitMode.car),
        );
      }

      if (_transitMapController.isWalkMapInitialized) {
        _transitMapController.moveCamera(
          TransitMode.walk,
          position,
          _transitMapController.getDefaultZoomLevel(TransitMode.walk),
        );
      }
    } else {
      setState(() {
        _originPlace = '위치 확인 실패';
      });
    }
  }

  // 네비게이션 탭 변경 처리
  void _handleNavIndexChanged(int index) {
    // 현재 선택된 인덱스와 동일한 인덱스가 선택되었는지 확인 (같은 탭 다시 누름)
    final isSameTab = _selectedIndex == index;

    setState(() {
      _selectedIndex = index;
    });

    // 같은 탭을 다시 눌렀거나 처음 선택한 경우 카메라 이동
    if (index == 0) {
      // 자동차 탭
      if (_transitMapController.isCarMapInitialized) {
        final position = _transitMapController.getCurrentPosition();
        if (position != null) {
          _transitMapController.moveCamera(
            TransitMode.car,
            position,
            _transitMapController.getDefaultZoomLevel(TransitMode.car),
          );

          // 같은 탭을 다시 눌렀을 때는 마커도 업데이트 (현재 위치 재확인)
          if (isSameTab) {
            _refreshCurrentLocation(TransitMode.car);
          }
        }
      }
    } else if (index == 1) {
      // 도보 탭
      if (_transitMapController.isWalkMapInitialized) {
        final position = _transitMapController.getCurrentPosition();
        if (position != null) {
          _transitMapController.moveCamera(
            TransitMode.walk,
            position,
            _transitMapController.getDefaultZoomLevel(TransitMode.walk),
          );

          // 같은 탭을 다시 눌렀을 때는 마커도 업데이트 (현재 위치 재확인)
          if (isSameTab) {
            _refreshCurrentLocation(TransitMode.walk);
          }
        }
      }
    }

    print('네비게이션 탭 변경: $index, 같은 탭 다시 선택: $isSameTab');
  }

  // 현재 위치를 새로고침하고 해당 맵의 카메라와 마커를 업데이트하는 메서드
  void _refreshCurrentLocation(TransitMode mode) async {
    // 현재 위치 다시 가져오기
    final position = await _locationController.getCurrentLocation();
    if (position != null) {
      // TransitMapController에 위치 업데이트
      _transitMapController.setCurrentPosition(position);

      // 해당 모드의 지도 카메라 이동
      _transitMapController.moveCamera(
        mode,
        position,
        _transitMapController.getDefaultZoomLevel(mode),
      );

      // 마커 업데이트
      _transitMapController.updateMarkers(mode, position, _originPlace);

      // 위치 기반 주소 갱신
      final address = await _addressController.getAddressFromLatLng(position);
      setState(() {
        _originPlace = address;
      });

      // 출발지가 변경되었으므로 경로 다시 로드
      _routeController.invalidateCache();
    } else {
      // 위치 가져오기 실패 시 스낵바 표시
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('현재 위치를 가져오는 데 실패했습니다.')));
    }
  }

  // 출발지/도착지 변경 처리
  void _handleOriginChanged(String value) {
    setState(() {
      _originPlace = value;
    });
    _routeController.invalidateCache();
  }

  void _handleDestinationChanged(String value) {
    setState(() {
      _destinationPlace = value;
    });
    _routeController.invalidateCache();
  }

  // 출발지/도착지 교환
  void _handleSwapLocations() {
    setState(() {
      final temp = _originPlace;
      _originPlace = _destinationPlace;
      _destinationPlace = temp;
    });
    _routeController.invalidateCache();
  }

  // 위치 탭 처리
  void _handleLocationUpdated(NLatLng latLng) async {
    final address = await _addressController.getAddressFromLatLng(latLng);
    setState(() {
      _originPlace = address;
    });
    _routeController.invalidateCache();
  }

  @override
  Widget build(BuildContext context) {
    // 화면 크기 가져오기
    final Size screenSize = MediaQuery.of(context).size;
    final double width = screenSize.width;
    final bool isSmallScreen = width < 360;
    final double iconSize = isSmallScreen ? 22.0 : 28.0; // 작은 화면에서는 작은 아이콘

    return Scaffold(
      backgroundColor: Colors.white, // 배경색을 흰색으로 설정
      body: Column(
        children: [
          // 상단 빨간색 배경의 검색창
          SearchBarWidget(
            originPlace: _originPlace,
            destinationPlace: _destinationPlace,
            onOriginChanged: _handleOriginChanged,
            onDestinationChanged: _handleDestinationChanged,
            onSwapLocations: _handleSwapLocations,
            onClosePressed: () {
              Navigator.pop(context);
              print('이전 화면으로 돌아가기');
            },
          ),

          // 대중교통 옵션 선택 바 - 그림자 추가
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
                // 자동차 탭
                TransitOptionWidget(
                  index: 0,
                  selectedIndex: _selectedIndex,
                  icon: Icons.directions_car,
                  label: '자동차',
                  onTap: _handleNavIndexChanged,
                  iconSize: iconSize,
                ),

                // 도보 탭
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

          // 콘텐츠 영역 - 탭에 따라 다른 내용 표시
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                // 자동차 모달
                CarModal(
                  initialPosition: _transitMapController.getCurrentPosition(),
                  originPlace: _originPlace,
                  destinationPlace: _destinationPlace,
                  transitMapController: _transitMapController,
                  onLocationUpdated: _handleLocationUpdated,
                ),

                // 도보 모달
                WalkModal(
                  initialPosition: _transitMapController.getCurrentPosition(),
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
