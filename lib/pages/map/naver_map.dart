import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:tomapto/widgets/navbar.dart';
import 'package:tomapto/controllers/map/map_controller.dart';
import 'package:tomapto/controllers/map/poi_controller.dart';
import 'package:tomapto/widgets/poi_widget.dart';
import 'package:tomapto/search/search_main.dart';
import 'package:tomapto/pages/map/transit.dart';

class NaverMapPage extends StatefulWidget {
  const NaverMapPage({super.key});

  @override
  _NaverMapPageState createState() => _NaverMapPageState();
}

class _NaverMapPageState extends State<NaverMapPage> {
  final MapController _mapController = MapController();
  final POIController _poiController = POIController();

  NLatLng? _currentPosition;
  final TextEditingController _searchController = TextEditingController();

  int _currentNavIndex = 0;

  // POI 관련 상태 - LocationInfoWidget 사용으로 변경
  ClickedLocationInfo? _clickedLocationInfo;
  bool _showLocationInfo = false;
  bool _isLoadingLocation = false;
  final Set<NMarker> _locationMarkers = {}; // 위치 마커들

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    print("NaverMapPage 초기화 완료");
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('위치 권한이 필요합니다.', style: TextStyle(fontSize: 14)),
          ),
        );
        return;
      }
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('위치 서비스를 활성화해주세요.', style: TextStyle(fontSize: 14)),
        ),
      );
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      setState(() {
        _currentPosition = NLatLng(position.latitude, position.longitude);
      });

      print('현재 위치: ${position.latitude}, ${position.longitude}');

      if (_mapController.controller != null && _currentPosition != null) {
        await _mapController.moveCamera(_currentPosition!, 17);

        try {
          _mapController.controller!.setLocationTrackingMode(
            NLocationTrackingMode.follow,
          );

          print('위치 추적 모드 설정 완료');
        } catch (e) {
          print('위치 추적 모드 설정 실패: $e');
        }
      }
    } catch (e) {
      print('위치 가져오기 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('위치 가져오기 실패: $e', style: TextStyle(fontSize: 14)),
        ),
      );
    }
  }

  // 위치 마커들 제거 (새로운 메서드)
  void _clearLocationMarkers() {
    try {
      if (_mapController.controller != null && _locationMarkers.isNotEmpty) {
        _mapController.removeAllMarkers(_locationMarkers);
        _locationMarkers.clear();
        print('위치 마커들 제거 완료');
      }
    } catch (e) {
      print('위치 마커들 제거 실패: $e');
    }
  }

  // 위치 정보 패널 닫기 (새로운 메서드)
  void _closeLocationInfo() {
    setState(() {
      _showLocationInfo = false;
      _clickedLocationInfo = null;
    });
    _clearLocationMarkers();
  }

  // 길찾기 버튼 탭 처리 (도착지로 설정)
  void _onDirectionsTap() {
    if (_clickedLocationInfo != null) {
      print('🎯🎯🎯 도착지로 길찾기 시작 🎯🎯🎯');
      print('상가명: ${_clickedLocationInfo!.locationName}');
      print(
        '정확한 좌표: ${_clickedLocationInfo!.position.latitude}, ${_clickedLocationInfo!.position.longitude}',
      );
      print('주소: ${_clickedLocationInfo!.address}');

      _navigateToTransitAsDestination(_clickedLocationInfo!);
    }
  }

  // 출발지로 설정하는 길찾기 버튼 탭 처리
  void _onDepartureTap() {
    if (_clickedLocationInfo != null) {
      // 정확한 좌표를 직접 전달
      _navigateToTransitAsOrigin(_clickedLocationInfo!);
    } else {
      print('❌ _clickedLocationInfo가 null입니다!');
    }
  }

  // 도착지로 설정하는 길찾기 페이지로 이동
  void _navigateToTransitAsDestination(ClickedLocationInfo locationInfo) {
    print('🎯 도착지로 길찾기 페이지 이동');
    print('전달할 데이터:');
    print('  - 상가명: ${locationInfo.locationName}');
    print('  - 위도: ${locationInfo.position.latitude}');
    print('  - 경도: ${locationInfo.position.longitude}');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => TransitApp(
              initialOriginPlace: "현재 위치",
              initialDestinationPlace: locationInfo.locationName, // 표시용 상가명
              initialOriginCoords: _currentPosition, // 현재 위치 좌표
              initialDestinationCoords: locationInfo.position, // ✨ 정확한 좌표 직접 전달
            ),
      ),
    );

    print('✅ 도착지로 길찾기 페이지 이동 완료');
  }

  // 출발지로 설정하는 길찾기 페이지로 이동
  // 출발지로 설정하는 길찾기 페이지로 이동 (완전 수정)
  void _navigateToTransitAsOrigin(ClickedLocationInfo locationInfo) {
    print('🎯🎯🎯 출발지로 길찾기 페이지 이동 🎯🎯🎯');
    print('전달할 데이터:');
    print('  - 상가명: ${locationInfo.locationName}');
    print('  - 위도: ${locationInfo.position.latitude}');
    print('  - 경도: ${locationInfo.position.longitude}');
    print('  - 주소: ${locationInfo.address}');

    // 🎯 핵심: 반드시 좌표를 initialOriginCoords에 전달
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          print('🔥 TransitApp 생성 중...');
          print('  initialOriginPlace: ${locationInfo.locationName}');
          print('  initialOriginCoords: ${locationInfo.position}');
          print('  initialDestinationPlace: "도착지 입력"');
          print('  initialDestinationCoords: null');

          return TransitApp(
            initialOriginPlace: locationInfo.locationName, // 표시용 상가명
            initialOriginCoords: locationInfo.position, // ✨ 정확한 좌표 반드시 전달!
            initialDestinationPlace: "도착지 입력", // 도착지는 사용자가 입력
            initialDestinationCoords: null, // 도착지 좌표는 없음
          );
        },
      ),
    );

    print('✅ TransitApp으로 이동 완료');
    print('💡 TransitApp에서 좌표가 제대로 전달되었는지 확인하세요!');
  }

  // 즐겨찾기 저장 (옵션 - 필요시 구현)
  void _onSaveLocation() {
    // 즐겨찾기 저장 로직 구현
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('즐겨찾기에 저장되었습니다.'), duration: Duration(seconds: 2)),
    );
  }

  // 위치 마커 추가 (새로운 메서드)
  void _addLocationMarker(NLatLng position) {
    try {
      if (_mapController.controller != null) {
        final marker = NMarker(
          id: 'location_marker_${DateTime.now().millisecondsSinceEpoch}', // 고유 ID 생성
          position: position,
        );

        marker.setIconTintColor(Color(0xFF000000)); // 빨간색으로 설정

        _mapController.addMarker(marker);
        _locationMarkers.add(marker);
        print('위치 마커 추가 완료');
      }
    } catch (e) {
      print('위치 마커 추가 실패: $e');
    }
  }

  Future<void> _getBusinessInfoFromSymbol(NSymbolInfo symbolInfo) async {
    print('상가 심볼 터치됨: ${symbolInfo.caption}');

    // 이미 로딩 중이면 중복 요청 방지
    if (_isLoadingLocation) {
      print('이미 위치 정보 조회 중입니다.');
      return;
    }

    setState(() {
      _isLoadingLocation = true;
      _showLocationInfo = false;
    });

    try {
      // 기존 위치 마커들 제거
      _clearLocationMarkers();

      print('심볼 정보로 상가 정보 생성 중...');

      // 심볼 정보로 즉시 상가 정보 생성
      final businessInfo = await _poiController.createBusinessInfoFromSymbol(
        symbolInfo.caption,
        symbolInfo.position,
        _currentPosition,
      );

      if (mounted) {
        setState(() {
          _clickedLocationInfo = businessInfo;
          _showLocationInfo = true;
        });

        // 터치한 위치에 마커 추가
        _addLocationMarker(symbolInfo.position);

        print('상가 정보 표시 완료: ${businessInfo.locationName}');

        // 백그라운드에서 주소 정보 업데이트
        _updateAddressInBackground(symbolInfo.position);
      }
    } catch (e) {
      print('상가 정보 조회 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('상가 정보를 가져오는 중 오류가 발생했습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _updateAddressInBackground(NLatLng position) async {
    try {
      final addressInfo = await _poiController.getAddressFromCoords(position);

      if (mounted && _showLocationInfo && _clickedLocationInfo != null) {
        setState(() {
          _clickedLocationInfo = ClickedLocationInfo(
            address: addressInfo,
            locationName: _clickedLocationInfo!.locationName,
            category: _clickedLocationInfo!.category,
            position: _clickedLocationInfo!.position,
            distanceFromUser: _clickedLocationInfo!.distanceFromUser,
            estimatedTime: _clickedLocationInfo!.estimatedTime,
            phoneNumber: _clickedLocationInfo!.phoneNumber,
            link: _clickedLocationInfo!.link,
            description: _clickedLocationInfo!.description,
          );
        });
        print('주소 정보 업데이트 완료: $addressInfo');
      }
    } catch (e) {
      print('주소 정보 업데이트 실패: $e');
    }
  }

  void _handleNavIndexChanged(int index) {
    setState(() {
      _currentNavIndex = index;
    });
  }

  // Transit 페이지로 이동하는 함수
  void _navigateToTransitPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TransitApp()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = ResponsiveValue.padding(context, base: 16.0);
    final verticalPadding = ResponsiveValue.padding(context, base: 8.0);
    final iconSize = ResponsiveValue.width(context, base: 45.0);
    final bottomPadding = ResponsiveValue.height(context, base: 85.0);
    final rightPadding = ResponsiveValue.width(context, base: 7.0);
    final contentPadding = EdgeInsets.fromLTRB(
      0,
      0,
      0,
      ResponsiveValue.height(context, base: 80.0),
    );

    return Scaffold(
      body: Stack(
        children: [
          // 1. 네이버 맵 (가장 아래)
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: NLatLng(37.5666805, 126.9784147),
                zoom: _mapController.currentZoom,
              ),
              mapType: NMapType.basic,
              contentPadding: contentPadding,
              locationButtonEnable: false,
              logoClickEnable: false,
              scaleBarEnable: true,
            ),
            onMapReady: (controller) {
              print('맵 컨트롤러 준비 완료');
              _mapController.setMapController(controller);
              if (_currentPosition != null) {
                print('현재 위치로 카메라 이동: $_currentPosition');
                _mapController.moveCamera(
                  _currentPosition!,
                  _mapController.currentZoom,
                );
              }
            },
            onCameraIdle: () {
              if (_mapController.controller != null) {
                _mapController.getCurrentCameraPosition().then((
                  cameraPosition,
                ) {
                  if (cameraPosition != null) {
                    double zoom = cameraPosition.zoom;
                    _mapController.setZoomLevel(zoom);
                    print('줌 레벨 업데이트됨: $zoom');
                  }
                });
              }
            },
            onSymbolTapped: (NSymbolInfo symbolInfo) {
              print('상가 심볼 터치됨: ${symbolInfo.caption}');
              _getBusinessInfoFromSymbol(symbolInfo);
            },
            // onMapTapped 이벤트 핸들러를 제거했습니다
          ),

          // 2. 맵 컨트롤러 로딩 인디케이터
          if (_mapController.controller == null && !_isLoadingLocation)
            Center(
              child: CircularProgressIndicator(color: const Color(0xFFFB233B)),
            ),

          // 3. 검색바 (상단)
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    const SearchMainPage(),
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                          ),
                        );
                      },
                      child: Container(
                        height: ResponsiveValue.height(context, base: 45.0),
                        decoration: ShapeDecoration(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          shadows: const [
                            BoxShadow(
                              color: Color(0x19000000),
                              blurRadius: 5,
                              offset: Offset(0, 2),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(fontSize: 16),
                          enabled: false,
                          decoration: InputDecoration(
                            hintText: '검색어를 입력해주세요.',
                            hintStyle: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              size: ResponsiveValue.width(context, base: 20.0),
                              color: Colors.grey[600],
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: ResponsiveValue.padding(
                                context,
                                base: 11.0,
                              ),
                              vertical: ResponsiveValue.padding(
                                context,
                                base: 11.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. GPS 버튼 (우측 하단)
          Positioned(
            bottom: bottomPadding,
            right: rightPadding,
            child: GestureDetector(
              onTap: () {
                _getCurrentLocation();
              },
              child: SvgPicture.asset(
                'assets/icons/gps_B.svg',
                width: 60,
                height: 60,
              ),
            ),
          ),

          // 6. 네비게이션 바 (하단) - POI 모달보다 먼저 배치
          Align(
            alignment: Alignment.bottomCenter,
            child: BottomNavBar(
              currentIndex: _currentNavIndex,
              onTap: _handleNavIndexChanged,
            ),
          ),

          // 7. 위치 정보 로딩 인디케이터 (POI 모달보다 위)
          if (_isLoadingLocation)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFFFB233B)),
                        SizedBox(height: 16),
                        Text('위치 정보를 가져오고 있습니다...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 8. POI 모달 (가장 위) - 네비게이션 바 위에 표시됨
          if (_showLocationInfo && _clickedLocationInfo != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LocationInfoWidget(
                locationInfo: _clickedLocationInfo!,
                onClose: _closeLocationInfo,
                onDirections: _onDirectionsTap, // 도착지로 설정
                onDeparture: _onDepartureTap, // 출발지로 설정
                onSave: _onSaveLocation,
              ),
            ),
        ],
      ),
    );
  }
}

class ResponsiveValue {
  static double width(BuildContext context, {required double base}) {
    final screenWidth = MediaQuery.of(context).size.width;
    return base * (screenWidth / 375);
  }

  static double height(BuildContext context, {required double base}) {
    final screenHeight = MediaQuery.of(context).size.height;
    return base * (screenHeight / 812);
  }

  static double padding(BuildContext context, {required double base}) {
    final screenWidth = MediaQuery.of(context).size.width;
    return base * (screenWidth / 375);
  }
}
