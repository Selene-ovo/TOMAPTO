import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:tomapto/widgets/navbar.dart';
import 'package:tomapto/controllers/map/map_controller.dart';
import 'package:tomapto/widgets/poi_widget.dart';
import 'package:tomapto/controllers/map/poi_controller.dart';
import 'package:tomapto/search/search_main.dart';
import 'package:tomapto/pages/map/transit.dart';

class NaverMapPage extends StatefulWidget {
  const NaverMapPage({super.key});

  @override
  _NaverMapPageState createState() => _NaverMapPageState();
}

class _NaverMapPageState extends State<NaverMapPage>
    with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupMapController();
    _initializeLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // 앱 라이프사이클 변화 감지
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // 앱이 다시 활성화될 때 실시간 추적 재시작
        if (!_mapController.isRealTimeTrackingEnabled) {
          _mapController.startRealTimeLocationTracking();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // 앱이 백그라운드로 갈 때 실시간 추적 정지 (배터리 절약)
        _mapController.stopRealTimeLocationTracking();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// 초기 위치 설정 및 실시간 추적 시작
  void _initializeLocation() {
    // 앱 시작시 실시간 위치 추적 시작
    _mapController.startRealTimeLocationTracking().catchError((error) {
      _showErrorSnackBar('실시간 위치 추적을 시작할 수 없습니다: $error');
    });
  }

  /// 맵 컨트롤러 콜백 설정
  void _setupMapController() {
    _mapController.onLoadingChanged = (isLoading) => setState(() {});
    _mapController.onLocationInfoChanged =
        (showInfo, locationInfo) => setState(() {});
    _mapController.onCurrentPositionChanged = (position) => setState(() {});
    _mapController.onLocationAddressChanged = (address) => setState(() {});
    _mapController.onShowSnackBar = _showErrorSnackBar;
  }

  /// 에러 스낵바 표시
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)),
        backgroundColor: Colors.red[400],
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 80, // 네비게이션 바 높이만큼 여백 추가
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 성공 스낵바 표시
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)),
        backgroundColor: Colors.green[400],
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 80, // 네비게이션 바 높이만큼 여백 추가
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 길찾기 페이지로 이동 (도착지로 설정)
  void _navigateToDestination() {
    final locationInfo = _mapController.clickedLocationInfo;
    if (locationInfo == null) {
      _showErrorSnackBar('위치 정보를 가져올 수 없습니다.');
      return;
    }

    _navigateToTransitPage(
      originPlace: _mapController.currentLocationAddress,
      destinationPlace: locationInfo.locationName,
      originCoords: _mapController.currentPosition,
      destinationCoords: locationInfo.position,
    );
  }

  /// 길찾기 페이지로 이동 (출발지로 설정)
  void _navigateFromOrigin() {
    final locationInfo = _mapController.clickedLocationInfo;
    if (locationInfo == null) {
      _showErrorSnackBar('위치 정보를 가져올 수 없습니다.');
      return;
    }

    _navigateToTransitPage(
      originPlace: locationInfo.locationName,
      destinationPlace: "도착지 입력",
      originCoords: locationInfo.position,
      destinationCoords: null,
    );
  }

  /// 길찾기 페이지로 이동하는 공통 메소드
  void _navigateToTransitPage({
    required String originPlace,
    required String destinationPlace,
    required NLatLng? originCoords,
    required NLatLng? destinationCoords,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => TransitApp(
              initialOriginPlace: originPlace,
              initialDestinationPlace: destinationPlace,
              initialOriginCoords: originCoords,
              initialDestinationCoords: destinationCoords,
            ),
      ),
    );
  }

  /// 검색 페이지로 이동
  void _navigateToSearch() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => const SearchMainPage(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  /// GPS 버튼
  Future<void> _handleGpsButtonTap() async {
    try {
      await _mapController.getCurrentLocation();
    } catch (error) {
      _showErrorSnackBar('현재 위치를 가져올 수 없습니다: $error');
    }
  }

  /// 네비게이션 인덱스 변경 처리
  void _handleNavIndexChanged(int index) {
    setState(() {
      _currentNavIndex = index;
    });
  }

  /// 맵 준비 완료 처리
  void _onMapReady(NaverMapController controller) {
    _mapController.setMapController(controller);
    if (_mapController.currentPosition != null) {
      _mapController
          .moveCamera(
            _mapController.currentPosition!,
            _mapController.currentZoom,
          )
          .catchError((error) {
            _showErrorSnackBar('카메라 이동 실패: $error');
          });
    }
  }

  /// 심볼 터치 처리
  void _onSymbolTapped(NSymbolInfo symbolInfo) {
    _mapController.getBusinessInfoFromSymbol(symbolInfo).catchError((error) {
      _showErrorSnackBar('상가 정보를 가져올 수 없습니다: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final responsiveValues = ResponsiveValues(screenSize);

    return Scaffold(
      body: Stack(
        children: [
          _buildNaverMap(responsiveValues),
          _buildMapLoadingIndicator(),
          _buildSearchBar(responsiveValues),
          _buildGpsButton(responsiveValues),
          _buildBottomNavigation(),
          _buildLocationLoadingOverlay(),
          _buildLocationInfoModal(),
        ],
      ),
    );
  }

  /// 네이버 맵 위젯
  Widget _buildNaverMap(ResponsiveValues responsiveValues) {
    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(
          target: const NLatLng(37.5666805, 126.9784147),
          zoom: _mapController.currentZoom,
        ),
        mapType: NMapType.basic,
        contentPadding: EdgeInsets.only(bottom: responsiveValues.bottomPadding),
        locationButtonEnable: false,
        logoClickEnable: false,
        scaleBarEnable: true,
      ),
      onMapReady: _onMapReady,
      onCameraIdle: _mapController.handleCameraIdle,
      onSymbolTapped: _onSymbolTapped,
    );
  }

  /// 맵 로딩 인디케이터
  Widget _buildMapLoadingIndicator() {
    if (_mapController.controller != null || _mapController.isLoadingLocation) {
      return const SizedBox.shrink();
    }
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFFFB233B)),
    );
  }

  /// 검색바
  Widget _buildSearchBar(ResponsiveValues responsiveValues) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: responsiveValues.horizontalPadding,
          vertical: responsiveValues.verticalPadding,
        ),
        child: GestureDetector(
          onTap: _navigateToSearch,
          child: Container(
            height: responsiveValues.searchBarHeight,
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
              style: const TextStyle(fontSize: 16),
              enabled: false,
              decoration: InputDecoration(
                hintText: '검색어를 입력해주세요.',
                hintStyle: TextStyle(fontSize: 18, color: Colors.grey[600]),
                prefixIcon: Icon(
                  Icons.search,
                  size: responsiveValues.searchIconSize,
                  color: Colors.grey[600],
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: responsiveValues.searchContentPadding,
                  vertical: responsiveValues.searchContentPadding,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// GPS 버튼
  Widget _buildGpsButton(ResponsiveValues responsiveValues) {
    return Positioned(
      bottom: responsiveValues.gpsButtonBottom,
      right: responsiveValues.gpsButtonRight,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleGpsButtonTap,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: const Icon(
                Icons.my_location_rounded,
                color: Color(0xFFFB233B),
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 하단 네비게이션
  Widget _buildBottomNavigation() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: BottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: _handleNavIndexChanged,
      ),
    );
  }

  /// 위치 정보 로딩 오버레이
  Widget _buildLocationLoadingOverlay() {
    if (!_mapController.isLoadingLocation) return const SizedBox.shrink();

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
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
    );
  }

  /// 위치 정보 모달
  Widget _buildLocationInfoModal() {
    if (!_mapController.showLocationInfo ||
        _mapController.clickedLocationInfo == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: LocationInfoWidget(
        locationInfo: _mapController.clickedLocationInfo!,
        onClose: _mapController.closeLocationInfo,
        onDirections: _navigateToDestination,
        onDeparture: _navigateFromOrigin,
      ),
    );
  }
}

/// 반응형 값들을 관리하는 클래스
class ResponsiveValues {
  final Size screenSize;

  ResponsiveValues(this.screenSize);

  double get horizontalPadding => _scaleWidth(16.0);
  double get verticalPadding => _scaleHeight(8.0);
  double get bottomPadding => _scaleHeight(80.0);
  double get searchBarHeight => _scaleHeight(45.0);
  double get searchIconSize => _scaleWidth(20.0);
  double get searchContentPadding => _scaleWidth(11.0);
  double get gpsButtonBottom => _scaleHeight(85.0);
  double get gpsButtonRight => _scaleWidth(7.0);

  double _scaleWidth(double base) => base * (screenSize.width / 375);
  double _scaleHeight(double base) => base * (screenSize.height / 812);
}

/// 기존 ResponsiveValue 클래스 (하위 호환성을 위해 유지)
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
