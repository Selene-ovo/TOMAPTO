import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tomapto/controllers/map_controller.dart';
import 'package:tomapto/styles/app_styles.dart';
import 'package:tomapto/widgets/bottom_nav_bar.dart';
import 'package:tomapto/widgets/ad_placeholder.dart'; // 광고 플레이스홀더 위젯 import
import 'package:tomapto/pages/friends_list_screen.dart'; // 경로 수정 - screens → pages

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
      title: 'Tomapto',
      theme: ThemeData(
        primarySwatch: Colors.red,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MainScreen(),
    );
  }
}

// 메인 화면 클래스 추가 - 네비게이션 및 화면 전환 관리
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentNavIndex = 0;

  // 각 탭에 해당하는 화면들
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const NaverMapPage(), // 메인 탭 (지도)
      FriendScreen(), // 친구 탭
      const NaverMapPage(), // 카테고리 탭 (임시로 지도 재사용)
      const PlaceholderScreen(title: '즐겨찾기'), // 즐겨찾기 탭
      const PlaceholderScreen(title: '마이페이지'), // 마이 프로필 탭
    ];
  }

  void _handleNavIndexChanged(int index) {
    setState(() {
      _currentNavIndex = index;
    });

    // 현재 위치 버튼 처리 (중앙 버튼 - 인덱스 2)
    if (index == 2 && _screens[0] is NaverMapPage) {
      // NaverMapPage의 현재 위치 메서드 호출하기 (이 예제에서는 단순화)
      print('중앙 버튼 - 현재 위치 요청');
    }

    print('네비게이션 탭 변경: $index');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentNavIndex, children: _screens),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: _handleNavIndexChanged,
      ),
    );
  }
}

// 임시 플레이스홀더 화면
class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          title,
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // 광고 배너
          AdPlaceholder(),

          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.construction, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '준비 중입니다',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '곧 만나볼 수 있어요!',
                    style: TextStyle(color: Colors.grey[600]),
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

// 기존 NaverMapPage 클래스
class NaverMapPage extends StatefulWidget {
  const NaverMapPage({super.key});

  @override
  _NaverMapPageState createState() => _NaverMapPageState();
}

class _NaverMapPageState extends State<NaverMapPage> {
  // 맵 컨트롤러
  MapController _mapController = MapController();

  NLatLng? _currentPosition;
  final Set<NMarker> _markers = {};
  final TextEditingController _searchController = TextEditingController();

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
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('위치 권한이 필요합니다.')));
        }
        return;
      }
    }

    // 위치 서비스가 활성화 되어있는지 확인
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('위치 서비스를 활성화해주세요.')));
      }
      return;
    }

    // 현재 위치 가져오기
    try {
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = NLatLng(position.latitude, position.longitude);
        });
      }
      print('현재 위치: ${position.latitude}, ${position.longitude}');

      // 카메라 이동
      if (_mapController != null && _currentPosition != null && mounted) {
        _mapController!.updateCamera(
          NCameraUpdate.withParams(target: _currentPosition!, zoom: 15),
        );

        // 마커 업데이트
        _updateMarkers();
      }
    } catch (e) {
      print('위치 가져오기 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('위치 가져오기 실패: $e')));
      }
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '현재 위치: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}',
              ),
            ),
          );
        }
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 맵 뷰
        NaverMap(
          options: NaverMapViewOptions(
            initialCameraPosition: NCameraPosition(
              target:
                  _currentPosition ??
                  NLatLng(37.5666805, 126.9784147), // 서울 시청 (기본값)
              zoom: 15,
            ),
            mapType: NMapType.basic,
            contentPadding: const EdgeInsets.fromLTRB(0, 70, 0, 80),
          ),
          onMapReady: (controller) {
            print('맵 컨트롤러 준비 완료');
            if (mounted) {
              setState(() {
                _mapController = controller as MapController;
              });
            }

            if (_currentPosition != null) {
              print('현재 위치로 카메라 이동: $_currentPosition');
              _mapController!.updateCamera(
                NCameraUpdate.withParams(target: _currentPosition!, zoom: 15),
              );
              _updateMarkers();
            }
          },
          onCameraChange: (position, reason) {
            print('카메라 변경: $position, 이유: $reason');
          },
          onMapTapped: (point, latLng) {
            print('지도가 탭되었습니다: $latLng');
          },
        ),

        // 로딩 표시
        if (_mapController == null)
          const Center(child: CircularProgressIndicator(color: Colors.red)),

        // 상단 검색바 및 길찾기 버튼
        Positioned(
          top: 40,
          left: 16,
          right: 16,
          child: Row(
            children: [
              // 검색 텍스트 필드
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: '장소, 주소 검색하기',
                      prefixIcon: Icon(Icons.search),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),

              // 길찾기 버튼
              Container(
                margin: const EdgeInsets.only(left: 8),
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.directions),
                  color: Colors.red,
                  onPressed: () {
                    // 길찾기 기능 구현
                    print('길찾기 버튼 클릭됨');
                  },
                ),
              ),
            ],
          ),
        ),

        // 거리 표시
        Positioned(
          top: 100,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                Container(width: 40, height: 2, color: Colors.black54),
                const SizedBox(width: 4),
                const Text(
                  '100m',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),

        // 현재 위치 버튼 (하단 우측)
        Positioned(
          bottom: 90,
          right: 16,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.my_location, size: 20),
              onPressed: _getCurrentLocation,
            ),
          ),
        ),
      ],
    );
  }
}
