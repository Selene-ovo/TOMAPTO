import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  bool _isInitialCameraSet = false;
  bool _isLoading = true;
  String _errorMessage = '';

  // 위치 정보 자동 갱신을 위한 타이머
  Timer? _locationUpdateTimer;

  @override
  void initState() {
    super.initState();
    _loadLocations();

    // 10초마다 위치 정보 갱신
    _locationUpdateTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadLocations(),
    );
  }

  @override
  void dispose() {
    // 타이머 정리
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  // API 서버 기본 URL 가져오기
  String getApiBaseUrl() {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/api';
    String? localIp = dotenv.env['LOCAL_IP'];

    // 안드로이드 에뮬레이터에서 실행 중인 경우
    if (Platform.isAndroid) {
      // localhost를 사용 중이고 LOCAL_IP가 설정되어 있다면
      if (baseUrl.contains('localhost') &&
          localIp != null &&
          localIp.isNotEmpty) {
        // localhost를 LOCAL_IP로 대체
        return baseUrl.replaceAll('localhost', localIp);
      }

      // 에뮬레이터 특정 주소 처리
      if (baseUrl.contains('localhost')) {
        return baseUrl.replaceAll('localhost', '10.0.2.2');
      }
    }

    // 그 외의 경우 원래 URL 반환
    return baseUrl;
  }

  // DB에서 내 위치와 친구 위치 정보 로드
  Future<void> _loadLocations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final userId = prefs.getString('user_id'); // 현재 사용자 ID

      if (token == null) {
        setState(() {
          _errorMessage = '로그인이 필요합니다';
          _isLoading = false;
        });
        return;
      }

      final apiBaseUrl = getApiBaseUrl();
      final friendId = widget.selectedFriend['id'];

      // 서버에서 직접 위치 데이터 가져오는 대신, 데이터베이스에서 직접 가져오기
      // 이 부분은 개발용 임시 코드입니다
      setState(() {
        // 데이터베이스에서 찾은 위치 정보로 설정
        // 내 위치 (예: tomapto1의 위치)
        _myPosition = NLatLng(37.7418735, 128.8923122);

        // 선택한 친구 ID에 해당하는 위치 찾기
        if (friendId == '1' || friendId.contains('tomapto1')) {
          _friendPosition = NLatLng(37.7418735, 128.8923122); // tomapto1 위치
        } else if (friendId == '2' || friendId.contains('tomapto2')) {
          _friendPosition = NLatLng(37.7418693, 128.8923195); // tomapto2 위치
        } else if (friendId == '3' || friendId.contains('tomapto3')) {
          _friendPosition = NLatLng(37.7418649, 128.8923197); // tomapto3 위치
        } else if (friendId == '4' || friendId.contains('tomapto4')) {
          _friendPosition = NLatLng(37.7418725, 128.8923159); // tomapto4 위치
        } else if (friendId == '5' || friendId.contains('tomapto5')) {
          _friendPosition = NLatLng(37.7418295, 128.8923304); // tomapto5 위치
        } else {
          // 기본값 또는 다른 ID의 경우
          _friendPosition = NLatLng(37.7418693, 128.8923195); // 기본값
        }

        _isLoading = false;
      });

      // 위치 데이터를 얻은 후 마커 업데이트
      if (_mapController != null) {
        _updateMapMarkers();
      }
    } catch (e) {
      print('위치 정보 로드 오류: $e');
      setState(() {
        _errorMessage = '위치 정보를 불러오는데 실패했습니다. 나중에 다시 시도해주세요.';
        _isLoading = false;
      });

      // 오류 발생 시 기본 위치 설정
      if (_myPosition == null) {
        _myPosition = NLatLng(37.7418735, 128.8923122); // 기본값
      }
      if (_friendPosition == null) {
        _friendPosition = NLatLng(37.7418693, 128.8923195); // 기본값
      }
    }
  }

  // 내 위치 마커 생성 함수 (빨간색)
  Future<NMarker> _createMyLocationMarker() async {
    final marker = NMarker(id: 'my_location', position: _myPosition!);

    // 마커 이미지 설정
    marker.setIcon(await _createLocationMarkerIcon(Colors.red));

    // 앵커 포인트 조정
    marker.setAnchor(NPoint(0.5, 1.0));

    // 캡션 설정
    marker.setCaption(
      NOverlayCaption(
        text: '내 위치',
        textSize: 14,
        color: Colors.black,
        haloColor: Colors.white,
      ),
    );

    return marker;
  }

  // 친구 위치 마커 생성 함수 (초록색)
  Future<NMarker> _createFriendLocationMarker() async {
    final marker = NMarker(id: 'friend_location', position: _friendPosition!);

    // 마커 이미지 설정
    marker.setIcon(await _createLocationMarkerIcon(Colors.green));

    // 앵커 포인트 조정
    marker.setAnchor(NPoint(0.5, 1.0));

    // 캡션 설정
    marker.setCaption(
      NOverlayCaption(
        text: widget.selectedFriend['name'],
        textSize: 14,
        color: Colors.black,
        haloColor: Colors.white,
      ),
    );

    return marker;
  }

  // 마커 아이콘 생성 함수 (색상을 파라미터로 받음)
  Future<NOverlayImage> _createLocationMarkerIcon(Color primaryColor) async {
    // 네이버 맵의 NOverlayImage.fromWidget 사용
    return await NOverlayImage.fromWidget(
      widget: _LocationMarkerWidget(color: primaryColor),
      size: Size(20, 30), // 마커 크기
      context: context,
    );
  }

  // 지도 마커 업데이트
  Future<void> _updateMapMarkers() async {
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
      final myMarker = await _createMyLocationMarker();

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
      final friendMarker = await _createFriendLocationMarker();

      friendMarker.setOnTapListener((NMarker marker) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.selectedFriend['name']}님의 위치')),
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
    } else if (!_isInitialCameraSet && _friendPosition != null) {
      _mapController!.updateCamera(
        NCameraUpdate.withParams(target: _friendPosition!, zoom: 15),
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

    // 줌 레벨 계산 (거리에 반비례)
    double zoom = 13.0;
    if (maxLat - minLat < 0.01 && maxLng - minLng < 0.01)
      zoom = 15.0;
    else if (maxLat - minLat < 0.05 && maxLng - minLng < 0.05)
      zoom = 13.0;
    else if (maxLat - minLat < 0.1 && maxLng - minLng < 0.1)
      zoom = 12.0;
    else if (maxLat - minLat < 0.5 && maxLng - minLng < 0.5)
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
              contentPadding: EdgeInsets.zero,
            ),
            onMapReady: (controller) {
              setState(() {
                _mapController = controller;
              });
              _updateMapMarkers(); // 비동기 함수지만 여기서는 await 없이 호출
            },
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
                }
              },
            ),
          ),

          // 로딩 표시
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.7),
              child: Center(
                child: CircularProgressIndicator(
                  color: const Color(0xFFFB233B),
                ),
              ),
            ),

          // 오류 메시지
          if (_errorMessage.isNotEmpty)
            Container(
              color: Colors.white.withOpacity(0.7),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 48),
                      SizedBox(height: 12),
                      Text(
                        _errorMessage,
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadLocations,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFB233B),
                        ),
                        child: Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// 커스텀 마커 위젯
class _LocationMarkerWidget extends StatelessWidget {
  final Color color;

  const _LocationMarkerWidget({Key? key, required this.color})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 핀 머리 부분 (원형)
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [],
          ),
        ),
      ],
    );
  }
}
