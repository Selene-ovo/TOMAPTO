import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'widgets/bottom_nav_bar.dart'; // 네비게이션바 임포트

// 기존 friendPage 클래스 유지 (FriendScreen 대신 사용)
class friendPage extends StatelessWidget {
  const friendPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('친구 위치')),
      body: Column(
        children: [
          // 내 위치 공유 상태 카드
          _buildMyLocationCard(context),

          // 구분선
          Divider(thickness: 1),

          // 친구 위치 목록 헤더
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '내 근처 친구',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text('3명 온라인'),
              ],
            ),
          ),

          // 친구 목록
          Expanded(
            child: ListView(
              children: [
                _buildFriendItem(context, {
                  'name': '하수용',
                  'distance': '0.5km',
                  'lastUpdated': '1분 전',
                  'isSharing': true,
                }),
                _buildFriendItem(context, {
                  'name': '심종완',
                  'distance': '1.2km',
                  'lastUpdated': '5분 전',
                  'isSharing': true,
                }),
                _buildFriendItem(context, {
                  'name': '황중혁',
                  'distance': '3.7km',
                  'lastUpdated': '30분 전',
                  'isSharing': true,
                }),
                _buildFriendItem(context, {
                  'name': '원종호',
                  'distance': '오프라인',
                  'lastUpdated': '1시간 전',
                  'isSharing': false,
                }),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 지도 전체 화면으로 보기
          _showMapFullScreen(context);
        },
        child: Icon(Icons.map),
        tooltip: '지도로 보기',
      ),
    );
  }

  // 위젯 메서드들을 static으로 변경
  static Widget _buildMyLocationCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.person, color: Colors.white, size: 30),
                ),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '나의 위치',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '서울시 강남구 테헤란로',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
                Spacer(),
                Switch(
                  value: true,
                  onChanged: (value) {
                    // 위치 공유 토글 로직
                  },
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(Icons.map, size: 50, color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildFriendItem(
    BuildContext context,
    Map<String, dynamic> friend,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: friend['isSharing'] ? Colors.green : Colors.grey,
        child: Text(friend['name'].substring(0, 1)),
      ),
      title: Text(friend['name']),
      subtitle: Text('${friend['distance']} • ${friend['lastUpdated']}'),
      trailing: IconButton(
        icon: Icon(Icons.navigation),
        onPressed:
            friend['isSharing']
                ? () {
                  // 길찾기 로직
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${friend['name']}님에게 가는 길을 안내합니다')),
                  );
                }
                : null,
        color: friend['isSharing'] ? Colors.blue : Colors.grey,
      ),
      onTap: () {
        // 친구 상세 정보 화면으로 이동
        if (friend['isSharing']) {
          _showFriendDetail(context, friend);
        }
      },
    );
  }

  static void _showFriendDetail(
    BuildContext context,
    Map<String, dynamic> friend,
  ) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    child: Text(friend['name'].substring(0, 1)),
                  ),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend['name'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${friend['distance']} 떨어져 있음',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(Icons.map, size: 50, color: Colors.grey[700]),
                ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.message),
                    label: Text('메시지 보내기'),
                    onPressed: () {
                      Navigator.pop(context);
                      // 메시지 보내기 로직
                    },
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.navigation),
                    label: Text('길찾기'),
                    onPressed: () {
                      Navigator.pop(context);
                      // 길찾기 로직
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static void _showMapFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              appBar: AppBar(title: Text('친구 위치 지도')),
              body: Stack(
                children: [
                  // 지도가 들어갈 자리 (실제로는 Google Maps 또는 다른 지도 API 사용)
                  Container(
                    color: Colors.grey[300],
                    child: Center(
                      child: Icon(
                        Icons.map,
                        size: 100,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),

                  // 친구 목록 패널
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 120,
                      padding: EdgeInsets.symmetric(vertical: 8),
                      color: Colors.white,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _buildFriendCard('하수용', '0.5km'),
                          _buildFriendCard('심종완', '1.2km'),
                          _buildFriendCard('황중혁', '3.7km'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  static Widget _buildFriendCard(String name, String distance) {
    return Container(
      width: 100,
      margin: EdgeInsets.only(right: 12),
      child: Column(
        children: [
          CircleAvatar(child: Text(name.substring(0, 1))),
          SizedBox(height: 4),
          Text(name, overflow: TextOverflow.ellipsis),
          Text(
            distance,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env 파일 경로
  await dotenv.load(fileName: '.env');

  await NaverMapSdk.instance.initialize(
    clientId: dotenv.env['NAVER_API_KEY'] ?? '',
    onAuthFailed: (error) {
      print('네이버 맵 인증 실패: $error');
    },
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TOMAPTO',
      theme: ThemeData(
        primarySwatch: Colors.red, // 네비게이션바의 테마색상과 맞춤
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MainPage(),
    );
  }
}

// 메인 페이지 생성 (네비게이션바를 관리할 부모 위젯)
class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0; // 현재 선택된 탭 인덱스

  // 각 탭에 해당하는 페이지 목록
  final List<Widget> _pages = [
    const NaverMapPage(), // 메인 페이지 (지도)
    const friendPage(), // 기존 친구 페이지 유지 (수정된 코드 포함)
    const NavigatePage(), // 네비게이션 페이지
    const FavoritesPage(), // 즐겨찾기 페이지
    const ProfilePage(), // 프로필 페이지
  ];

  // 탭 변경 핸들러
  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex], // 현재 선택된 페이지 표시
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}

// 기존 네이버 맵 페이지 (일부 수정)
class NaverMapPage extends StatefulWidget {
  const NaverMapPage({Key? key}) : super(key: key);

  @override
  _NaverMapPageState createState() => _NaverMapPageState();
}

class _NaverMapPageState extends State<NaverMapPage> {
  NaverMapController? _mapController;
  NLatLng? _currentPosition;
  final Set<NMarker> _markers = {};

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    // 위치 권한 요청
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    // 현재 위치 가져오기
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = NLatLng(position.latitude, position.longitude);
      });

      // 카메라 이동
      if (_mapController != null && _currentPosition != null) {
        _mapController!.updateCamera(
          NCameraUpdate.withParams(target: _currentPosition, zoom: 15),
        );

        // 마커 업데이트
        _updateMarkers();
      }
    } catch (e) {
      print('위치 가져오기 실패: $e');
    }
  }

  void _updateMarkers() {
    if (_mapController != null && _currentPosition != null) {
      setState(() {
        // 새로운 마커 세트 생성
        _markers.clear();

        final marker = NMarker(id: '현재위치', position: _currentPosition!);

        _markers.add(marker);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TOMAPTO')),
      body: Stack(
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target:
                    _currentPosition ??
                    NLatLng(37.5666805, 126.9784147), // 서울 시청 (기본값)
                zoom: 15,
              ),
              mapType: NMapType.basic,
              locationButtonEnable: true,
            ),
            onMapReady: (controller) {
              _mapController = controller;
              if (_currentPosition != null) {
                _mapController!.updateCamera(
                  NCameraUpdate.withParams(target: _currentPosition, zoom: 15),
                );
                _updateMarkers();
              }
            },
            onMapTapped: (point, latLng) {
              print('지도가 탭되었습니다: $latLng');
            },
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _getCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}

// 기타 페이지들
class NavigatePage extends StatelessWidget {
  const NavigatePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('네비게이션')),
      body: const Center(child: Text('네비게이션 페이지')),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('즐겨찾기')),
      body: const Center(child: Text('즐겨찾기 페이지')),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('프로필')),
      body: const Center(child: Text('프로필 페이지')),
    );
  }
}
