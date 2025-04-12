import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tomapto/widgets/bottom_nav_bar.dart';

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
      theme: ThemeData(
        primarySwatch: Colors.red,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
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
  NaverMapController? _mapController;
  NLatLng? _currentPosition;
  final Set<NMarker> _markers = {};
  final TextEditingController _searchController = TextEditingController();

  // 현재 선택된 네비게이션 탭 인덱스
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    print("NaverMapPage 초기화 완료");
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    // 위치 권한 요청
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('위치 권한이 필요합니다.')));
        return;
      }
    }

    // 위치 서비스가 활성화 되어있는지 확인
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('위치 서비스를 활성화해주세요.')));
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
      if (_mapController != null && _currentPosition != null) {
        _mapController!.updateCamera(
          NCameraUpdate.withParams(target: _currentPosition!, zoom: 15),
        );

        // 마커 업데이트
        _updateMarkers();
      }
    } catch (e) {
      print('위치 가져오기 실패: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('위치 가져오기 실패: $e')));
    }
  }

  void _updateMarkers() {
    print('마커 업데이트 시작');
    if (_mapController != null && _currentPosition != null) {
      // 기존 마커 제거
      if (_markers.isNotEmpty) {
        for (final marker in _markers) {
          _mapController!.deleteOverlay(marker.info);
        }
        _markers.clear();
      }

      // 새 마커 생성
      final marker = NMarker(id: '현재위치', position: _currentPosition!);

      // 마커 색상 설정 (빨간색)
      marker.setIconTintColor(Colors.red);

      // 마커 탭 이벤트 설정
      marker.setOnTapListener((NMarker marker) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '현재 위치: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}',
            ),
          ),
        );
      });

      try {
        // 마커를 맵에 추가
        _mapController!.addOverlay(marker);
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
    return Scaffold(
      body: Stack(
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
              setState(() {
                _mapController = controller;
              });

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
