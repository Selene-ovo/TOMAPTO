import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomapto/widgets/bottom_nav_bar.dart';
import 'package:tomapto/services/location_service.dart'; // 위치 서비스 클래스 import

class RealTimeLocationSharingPage extends StatefulWidget {
  final Map<String, dynamic> selectedFriend;

  const RealTimeLocationSharingPage({Key? key, required this.selectedFriend})
    : super(key: key);

  @override
  _RealTimeLocationSharingPageState createState() =>
      _RealTimeLocationSharingPageState();
}

class _RealTimeLocationSharingPageState
    extends State<RealTimeLocationSharingPage> {
  NaverMapController? _mapController;
  NLatLng? _myPosition;
  NLatLng? _friendPosition;
  final Set<NMarker> _markers = {};
  Timer? _locationUpdateTimer;
  bool _isLoading = true;
  String _errorMessage = '';
  double _myHeading = 0.0; // 내 방향 (각도)
  bool _isSharingStarted = false;
  DateTime? _lastFriendUpdate;
  bool _isInitialCameraSet = false; // 초기 카메라 위치 설정 여부

  @override
  void initState() {
    super.initState();
    _initializeLocationSharing();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    // 화면을 나갈 때 별도로 위치 공유 종료 처리
    _endLocationSharing();
    super.dispose();
  }

  // 위치 공유 초기화
  Future<void> _initializeLocationSharing() async {
    try {
      setState(() => _isLoading = true);

      // 위치 권한 및 서비스 확인
      bool permissionGranted = await LocationService.checkLocationPermission();
      if (!permissionGranted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '위치 권한 또는 서비스가 활성화되지 않았습니다.';
        });
        return;
      }

      // 친구 ID 확인
      if (widget.selectedFriend['id'] == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = '친구 정보가 올바르지 않습니다.';
        });
        return;
      }

      print('위치 공유 초기화 - 친구 ID: ${widget.selectedFriend['id']}');

      // 위치 공유가 이미 시작되었는지 확인 - 위치 정보 조회 시도
      final friendLocation = await LocationService.getFriendLocation(
        widget.selectedFriend['id'],
      );

      // 이미 위치 공유 중이라면 설정만 하고 넘어감
      if (friendLocation != null) {
        print('기존 위치 공유 세션 발견: ${friendLocation}');
        _isSharingStarted = true;
      } else {
        // 위치 공유 새로 시작 (이 부분은 일반적으로 이전 화면에서 처리되지만 안전을 위해 추가)
        print('위치 공유 새로 시작');
        bool sharingSuccess = await LocationService.requestLocationSharing(
          widget.selectedFriend['id'],
        );

        if (!sharingSuccess) {
          setState(() {
            _isLoading = false;
            _errorMessage = '위치 공유를 시작할 수 없습니다.';
          });
          return;
        }

        _isSharingStarted = true;
      }

      // 내 위치 초기 설정
      await _updateMyLocation();

      // 친구 위치 가져오기
      await _updateFriendLocation();

      // 주기적으로 위치 업데이트 (10초마다)
      _locationUpdateTimer = Timer.periodic(Duration(seconds: 10), (
        timer,
      ) async {
        await _updateMyLocation();
        await _updateFriendLocation();
      });

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '위치 공유 초기화 실패: $e';
      });
      print('위치 공유 초기화 오류: $e');
    }
  }

  // 내 위치 업데이트
  Future<void> _updateMyLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();

      // 방향 정보 가져오기
      _myHeading = position.heading;

      // 위치 정보 상태 업데이트
      setState(() {
        _myPosition = NLatLng(position.latitude, position.longitude);
      });

      // 서버에 내 위치 정보 업데이트
      await LocationService.updateMyLocation(
        position.latitude,
        position.longitude,
        position.heading,
        position.accuracy,
      );

      // 지도에 마커 업데이트
      if (_mapController != null) {
        _updateMapMarkers();
      }
    } catch (e) {
      print('내 위치 업데이트 실패: $e');
    }
  }

  // 친구 위치 업데이트
  Future<void> _updateFriendLocation() async {
    try {
      final friendLocation = await LocationService.getFriendLocation(
        widget.selectedFriend['id'],
      );

      if (friendLocation != null) {
        setState(() {
          _friendPosition = NLatLng(
            friendLocation['latitude'],
            friendLocation['longitude'],
          );
          _lastFriendUpdate = DateTime.parse(friendLocation['updated_at']);
        });

        // 지도에 마커 업데이트
        if (_mapController != null) {
          _updateMapMarkers();
        }
      }
    } catch (e) {
      print('친구 위치 업데이트 실패: $e');
    }
  }

  // 마커 설정 - 내 위치용
  void _configureMyLocationMarker(NMarker marker) {
    // 내 마커 디자인 설정 - 빨간색으로 표시
    marker.setIconTintColor(Colors.red);

    // 캡션 설정
    marker.setCaption(
      NOverlayCaption(
        text: '내 위치',
        textSize: 14,
        color: Colors.black,
        haloColor: Colors.white,
      ),
    );
  }

  // 마커 설정 - 친구 위치용
  void _configureFriendLocationMarker(NMarker marker) {
    // 친구 마커 디자인 설정 - 파란색으로 표시
    marker.setIconTintColor(Colors.blue);

    marker.setCaption(
      NOverlayCaption(
        text: widget.selectedFriend['name'],
        textSize: 14,
        color: Colors.black,
        haloColor: Colors.white,
      ),
    );
  }

  // 지도 마커 업데이트
  void _updateMapMarkers() {
    if (_mapController == null) return;

    // 기존 마커 모두 제거
    if (_markers.isNotEmpty) {
      for (final marker in _markers) {
        _mapController!.deleteOverlay(marker.info);
      }
      _markers.clear();
    }

    // 내 위치 마커 추가
    if (_myPosition != null) {
      final myMarker = NMarker(id: 'my_location', position: _myPosition!);
      _configureMyLocationMarker(myMarker);

      myMarker.setOnTapListener((NMarker marker) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('내 현재 위치')));
      });

      _mapController!.addOverlay(myMarker);
      _markers.add(myMarker);
    }

    // 친구 위치 마커 추가
    if (_friendPosition != null) {
      final friendMarker = NMarker(
        id: 'friend_location',
        position: _friendPosition!,
      );

      _configureFriendLocationMarker(friendMarker);

      friendMarker.setOnTapListener((NMarker marker) {
        String updateInfo = '';
        if (_lastFriendUpdate != null) {
          final difference = DateTime.now().difference(_lastFriendUpdate!);
          if (difference.inMinutes < 1) {
            updateInfo = '방금 전 업데이트';
          } else if (difference.inHours < 1) {
            updateInfo = '${difference.inMinutes}분 전 업데이트';
          } else {
            updateInfo = '${difference.inHours}시간 전 업데이트';
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.selectedFriend['name']}님의 위치 ($updateInfo)',
            ),
          ),
        );
      });

      _mapController!.addOverlay(friendMarker);
      _markers.add(friendMarker);
    }

    // 카메라 위치 조정
    if (!_isInitialCameraSet &&
        _myPosition != null &&
        _friendPosition != null) {
      _fitBoundsToShowBothMarkers();
      _isInitialCameraSet = true;
    } else if (!_isInitialCameraSet && _myPosition != null) {
      _mapController!.updateCamera(
        NCameraUpdate.withParams(target: _myPosition!, zoom: 15),
      );
      _isInitialCameraSet = true;
    }
  }

  // 두 마커가 모두 보이도록 카메라 조정
  void _fitBoundsToShowBothMarkers() {
    if (_myPosition == null ||
        _friendPosition == null ||
        _mapController == null)
      return;

    // 두 위치의 경계 계산
    double minLat =
        _myPosition!.latitude < _friendPosition!.latitude
            ? _myPosition!.latitude
            : _friendPosition!.latitude;
    double maxLat =
        _myPosition!.latitude > _friendPosition!.latitude
            ? _myPosition!.latitude
            : _friendPosition!.latitude;
    double minLng =
        _myPosition!.longitude < _friendPosition!.longitude
            ? _myPosition!.longitude
            : _friendPosition!.longitude;
    double maxLng =
        _myPosition!.longitude > _friendPosition!.longitude
            ? _myPosition!.longitude
            : _friendPosition!.longitude;

    // 패딩 추가
    minLat -= 0.01;
    maxLat += 0.01;
    minLng -= 0.01;
    maxLng += 0.01;

    // 중심점 계산
    double centerLat = (minLat + maxLat) / 2;
    double centerLng = (minLng + maxLng) / 2;

    // 두 위치 사이의 거리에 따라 적절한 줌 레벨 결정
    double latDiff = maxLat - minLat;
    double lngDiff = maxLng - minLng;
    double maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    // 줌 레벨 계산 (거리에 반비례)
    double zoom = 13.0;
    if (maxDiff < 0.01)
      zoom = 15.0;
    else if (maxDiff < 0.05)
      zoom = 13.0;
    else if (maxDiff < 0.1)
      zoom = 12.0;
    else if (maxDiff < 0.5)
      zoom = 10.0;
    else
      zoom = 9.0;

    _mapController!.updateCamera(
      NCameraUpdate.withParams(
        target: NLatLng(centerLat, centerLng),
        zoom: zoom,
      ),
    );
  }

  // 위치 공유 종료
  Future<void> _endLocationSharing() async {
    if (_isSharingStarted) {
      try {
        await LocationService.endLocationSharing(widget.selectedFriend['id']);
        _isSharingStarted = false;
      } catch (e) {
        print('위치 공유 종료 오류: $e');
      }
    }
  }

  // 위치 공유 종료 확인 대화상자
  void _showEndSharingConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('위치 공유 종료'),
            content: Text(
              '${widget.selectedFriend['name']}님과의 위치 공유를 종료하시겠습니까?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('취소'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () async {
                  Navigator.pop(context); // 다이얼로그 닫기
                  await _endLocationSharing();
                  Navigator.pop(context); // 위치 공유 화면 나가기
                },
                child: Text('종료'),
              ),
            ],
          ),
    );
  }

  // 내비게이션 옵션 보여주기
  void _showNavigationOptions(BuildContext context) {
    if (_friendPosition == null) return;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => Container(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    '${widget.selectedFriend['name']}님의 위치로 이동',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.map, color: Colors.green),
                  title: Text('네이버 지도'),
                  onTap: () {
                    Navigator.pop(context);
                    _launchNaverMap();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.navigation, color: Colors.blue),
                  title: Text('카카오맵'),
                  onTap: () {
                    Navigator.pop(context);
                    _launchKakaoMap();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.directions_car, color: Colors.red),
                  title: Text('티맵'),
                  onTap: () {
                    Navigator.pop(context);
                    _launchTmap();
                  },
                ),
              ],
            ),
          ),
    );
  }

  // 외부 지도 앱 실행 함수들 (실제 구현시에는 URL 스키마로 연결)
  void _launchNaverMap() {
    if (_friendPosition == null) return;
    // 실제 구현: URL 스키마를 통해 네이버 지도 앱 실행
    print(
      '네이버 지도 앱으로 ${_friendPosition!.latitude}, ${_friendPosition!.longitude} 위치 안내',
    );
    // 외부 앱 연동은 url_launcher 패키지 필요
  }

  void _launchKakaoMap() {
    if (_friendPosition == null) return;
    // 실제 구현: URL 스키마를 통해 카카오맵 앱 실행
    print(
      '카카오맵 앱으로 ${_friendPosition!.latitude}, ${_friendPosition!.longitude} 위치 안내',
    );
  }

  void _launchTmap() {
    if (_friendPosition == null) return;
    // 실제 구현: URL 스키마를 통해 티맵 앱 실행
    print(
      '티맵 앱으로 ${_friendPosition!.latitude}, ${_friendPosition!.longitude} 위치 안내',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Text(
          '${widget.selectedFriend['name']}님과 위치 공유',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          // 위치 공유 종료 버튼
          IconButton(
            icon: Icon(Icons.close, color: Colors.red),
            onPressed: () {
              _showEndSharingConfirmation(context);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 네이버 맵
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target:
                    _myPosition ??
                    NLatLng(37.5666805, 126.9784147), // 기본값: 서울시청
                zoom: 15,
              ),
              mapType: NMapType.basic,
              contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
            ),
            onMapReady: (controller) {
              setState(() {
                _mapController = controller;
              });
              _updateMapMarkers();
            },
          ),

          // 로딩 표시
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: CircularProgressIndicator(color: Colors.red),
              ),
            ),

          // 오류 메시지
          if (_errorMessage.isNotEmpty)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: Colors.white, size: 48),
                      SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text('돌아가기'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 하단 정보 패널
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // 친구 정보
                  CircleAvatar(
                    backgroundColor: Colors.grey[200],
                    child: Icon(Icons.person, color: Colors.black),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.selectedFriend['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _lastFriendUpdate != null
                              ? '마지막 업데이트: ${_getTimeAgo(_lastFriendUpdate!)}'
                              : '위치 정보 수신 대기 중...',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // 내비게이션 버튼
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onPressed:
                        _friendPosition != null
                            ? () {
                              _showNavigationOptions(context);
                            }
                            : null,
                    icon: Icon(Icons.directions),
                    label: Text('길 안내'),
                  ),
                ],
              ),
            ),
          ),

          // 현재 위치 버튼
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              mini: true,
              child: Icon(Icons.my_location, color: Colors.black),
              onPressed: () {
                if (_myPosition != null && _mapController != null) {
                  _mapController!.updateCamera(
                    NCameraUpdate.withParams(target: _myPosition!, zoom: 15),
                  );
                } else {
                  _updateMyLocation();
                }
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 2, // 중앙 버튼
        onTap: (index) {
          // 탭 처리 로직 (필요시 구현)
          if (index != 2) {
            // 위치 공유 종료 후 해당 탭으로 이동
            _endLocationSharing().then((_) {
              Navigator.pop(context);
              // 여기에 해당 탭으로 이동하는 네비게이션 로직 추가
            });
          }
        },
      ),
    );
  }

  // 마지막 업데이트 시간 표시 헬퍼 함수
  String _getTimeAgo(DateTime dateTime) {
    final Duration difference = DateTime.now().difference(dateTime);

    if (difference.inSeconds < 60) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else {
      return '${difference.inDays}일 전';
    }
  }
}
