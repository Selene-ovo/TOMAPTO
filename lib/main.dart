import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tomapto/widgets/bottom_nav_bar.dart';
import 'package:tomapto/pages/map/transit.dart';
import 'package:tomapto/styles/app_styles.dart';
import 'package:tomapto/controllers/map_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 환경 변수 로드
  await dotenv.load(fileName: ".env");

  // 네이버 맵 초기화
  await NaverMapSdk.instance.initialize(
    clientId: dotenv.env['NAVER_API_KEY'] ?? '',
    onAuthFailed: (error) {
      print('네이버 맵 인증 실패: $error');
    },
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '네이버 맵',
      theme: AppStyles.theme, // AppStyles에서 정의된 테마 사용
      home: const NaverMapPage(),
    );
  }
}

class NaverMapPage extends StatefulWidget {
  const NaverMapPage({super.key});

  @override
  _NaverMapPageState createState() => _NaverMapPageState();
}

class _NaverMapPageState extends State<NaverMapPage> {
  // 맵 컨트롤러
  final MapController _mapController = MapController();

  NLatLng? _currentPosition;
  final Set<NMarker> _markers = {};
  final TextEditingController _searchController = TextEditingController();

  // 현재 선택된 네비게이션 탭 인덱스
  int _currentNavIndex = 0;

  // 거리 스케일 정보
  String _distanceText = '100m';
  double _distanceWidth = 40.0;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _updateDistanceScaleFromZoom(_mapController.currentZoom);
    print("NaverMapPage 초기화 완료");
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // 줌 레벨에 따른 거리 스케일 업데이트
  void _updateDistanceScaleFromZoom(double zoom) {
    // MapController에서 거리 스케일 계산 결과 가져오기
    final distanceScale = _mapController.getDistanceScale(zoom);

    setState(() {
      _distanceText = distanceScale.text;
      _distanceWidth = distanceScale.width;
    });
  }

  Future<void> _getCurrentLocation() async {
    // 위치 권한 요청
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('위치 권한이 필요합니다.', style: AppTextStyle.mediumRegular),
          ),
        );
        return;
      }
    }

    // 위치 서비스가 활성화 되어있는지 확인
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('위치 서비스를 활성화해주세요.', style: AppTextStyle.mediumRegular),
        ),
      );
      return;
    }

    // 현재 위치 가져오기
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = NLatLng(position.latitude, position.longitude);
      });
      print('현재 위치: ${position.latitude}, ${position.longitude}');

      // 카메라 이동
      if (_mapController.controller != null && _currentPosition != null) {
        // 기본 줌 레벨 15로 설정
        await _mapController.moveCamera(_currentPosition!, 15);
        _updateDistanceScaleFromZoom(15);

        // 마커 업데이트
        _updateMarkers();
      }
    } catch (e) {
      print('위치 가져오기 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('위치 가져오기 실패: $e', style: AppTextStyle.mediumRegular),
        ),
      );
    }
  }

  void _updateMarkers() {
    print('마커 업데이트 시작');
    if (_mapController.controller != null && _currentPosition != null) {
      // 기존 마커 제거
      if (_markers.isNotEmpty) {
        _mapController.removeAllMarkers(_markers);
        _markers.clear();
      }

      // 새 마커 생성
      final marker = NMarker(id: '현재위치', position: _currentPosition!);

      // 마커 색상 설정 (빨간색)
      marker.setIconTintColor(AppStyles.primaryColor);

      // 마커 탭 이벤트 설정
      marker.setOnTapListener((NMarker marker) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '현재 위치: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}',
              style: AppTextStyle.mediumRegular,
            ),
          ),
        );
      });

      try {
        // 마커를 맵에 추가
        _mapController.addMarker(marker);
        _markers.add(marker);
        print('마커 추가 성공');
      } catch (e) {
        print('마커 추가 실패: $e');
      }

      print(
        '마커 추가됨: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}',
      );
    }
  }

  // 네비게이션 탭 변경 처리
  void _handleNavIndexChanged(int index) {
    setState(() {
      _currentNavIndex = index;
    });

    // 현재 위치 버튼 처리 (중앙 버튼 - 인덱스 2)
    if (index == 2) {
      _getCurrentLocation();
    }

    // 여기에 각 탭에 따른 추가 동작 구현
    print('네비게이션 탭 변경: $index');
  }

  @override
  Widget build(BuildContext context) {
    // 반응형 사이즈 계산을 위한 값들
    final horizontalPadding = ResponsiveValue.padding(context, base: 16.0);
    final verticalPadding = ResponsiveValue.padding(context, base: 8.0);
    final iconSize = ResponsiveValue.width(context, base: 45.0);
    final bottomPadding = ResponsiveValue.height(context, base: 85.0);
    final rightPadding = ResponsiveValue.width(context, base: 7.0);
    final distanceRightPadding = ResponsiveValue.width(context, base: 50.0);
    final distanceBottomPadding = ResponsiveValue.height(context, base: 90.0);
    final contentPadding = EdgeInsets.fromLTRB(
      0,
      0,
      0,
      ResponsiveValue.height(context, base: 80.0),
    );

    return Scaffold(
      // AppBar 제거하고 전체 화면을 지도로 채움
      body: Stack(
        children: [
          // 맵 뷰 - 전체 화면 차지
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target:
                    _currentPosition ??
                    NLatLng(37.5666805, 126.9784147), // 서울 시청 (기본값)
                zoom: _mapController.currentZoom,
              ),
              mapType: NMapType.basic,
              contentPadding: contentPadding,
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
                _updateMarkers();
              }

              // 맵이 준비되면 초기 줌 레벨에 따른 거리 스케일 설정
              _mapController.getCurrentCameraPosition().then((cameraPosition) {
                if (cameraPosition != null) {
                  double zoom = cameraPosition.zoom;
                  _mapController.setZoomLevel(zoom);
                  _updateDistanceScaleFromZoom(zoom);
                }
              });
            },
            onCameraIdle: () {
              // 카메라 움직임이 멈추었을 때 줌 레벨 업데이트
              if (_mapController.controller != null) {
                _mapController.getCurrentCameraPosition().then((
                  cameraPosition,
                ) {
                  if (cameraPosition != null) {
                    double zoom = cameraPosition.zoom;
                    _mapController.setZoomLevel(zoom);
                    _updateDistanceScaleFromZoom(zoom);
                    print('줌 레벨 업데이트됨: $zoom');
                  }
                });
              }
            },
            onMapTapped: (point, latLng) {
              print('지도가 탭되었습니다: $latLng');
            },
          ),

          // 로딩 표시
          if (_mapController.controller == null)
            Center(
              child: CircularProgressIndicator(color: AppStyles.primaryColor),
            ),

          // 상단 검색바와 길찾기 버튼
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Row(
                children: [
                  // 검색 텍스트 필드
                  Expanded(
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
                        style: AppTextStyle.regularRegular,
                        decoration: InputDecoration(
                          hintText: '검색어를 입력해주세요.',
                          hintStyle: AppTextStyle.mediumRegular.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: ResponsiveValue.width(context, base: 20.0),
                            color: AppColors.textSecondary,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: ResponsiveValue.padding(
                              context,
                              base: 13.0,
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

                  // 길찾기 버튼
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TransitApp(),
                        ),
                      );
                      print('길찾기 페이지로 이동');
                    },
                    child: Container(
                      margin: EdgeInsets.only(
                        left: ResponsiveValue.padding(context, base: 8.0),
                      ),
                      child: SvgPicture.asset(
                        'assets/icons/transit_B.svg',
                        width: iconSize,
                        height: iconSize,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 현재 위치 버튼
          Positioned(
            bottom: bottomPadding,
            right: rightPadding,
            child: GestureDetector(
              onTap: _getCurrentLocation,
              child: SvgPicture.asset(
                'assets/icons/gps_B.svg',
                width: iconSize,
                height: iconSize,
              ),
            ),
          ),

          // 거리 표시 - 동적으로 크기와 텍스트가 변경됨
          Positioned(
            bottom: distanceBottomPadding,
            right: distanceRightPadding,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveValue.padding(context, base: 8.0),
                vertical: ResponsiveValue.padding(context, base: 4.0),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: ResponsiveValue.width(context, base: _distanceWidth),
                    height: ResponsiveValue.height(context, base: 2.0),
                    color: Colors.black54,
                  ),
                  SizedBox(width: ResponsiveValue.width(context, base: 4.0)),
                  Text(
                    _distanceText,
                    style: AppTextStyle.smallRegular.copyWith(
                      fontWeight: AppFontWeight.medium,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 하단 네비게이션 바
          Align(
            alignment: Alignment.bottomCenter,
            child: BottomNavBar(
              currentIndex: _currentNavIndex,
              onTap: _handleNavIndexChanged,
            ),
          ),
        ],
      ),
    );
  }
}
