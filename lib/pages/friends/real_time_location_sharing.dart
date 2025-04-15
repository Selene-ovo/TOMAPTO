import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

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

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // 기본 위치 설정 (서울시청)
      _myPosition = NLatLng(37.5666805, 126.9760);
      _friendPosition = NLatLng(37.5665, 126.9783); // 친구 기본 위치
    } catch (e) {
      print('초기화 오류: $e');
    }
  }

  // 내 위치 마커 생성 함수 (빨간색) - 비동기로 변경
  Future<NMarker> _createMyLocationMarker() async {
    final marker = NMarker(id: 'my_location', position: _myPosition!);

    // 마커 이미지 비트맵 생성 대신 프로그래매틱하게 설정 (await 추가)
    marker.setIcon(await _createLocationMarkerIcon(Colors.red));

    // 앵커 포인트 조정 (마커 이미지의 중앙 하단이 위치 좌표를 가리키도록)
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

  // 친구 위치 마커 생성 함수 (초록색) - 비동기로 변경
  Future<NMarker> _createFriendLocationMarker() async {
    final marker = NMarker(id: 'friend_location', position: _friendPosition!);

    // 마커 이미지 프로그래매틱하게 설정 (await 추가)
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

  // 마커 아이콘 생성 함수 (색상을 파라미터로 받음) - context 추가
  Future<NOverlayImage> _createLocationMarkerIcon(Color primaryColor) async {
    // 네이버 맵의 NOverlayImage.fromWidget 사용 (context 필수)
    return await NOverlayImage.fromWidget(
      widget: _LocationMarkerWidget(color: primaryColor),
      size: Size(40, 60), // 마커 크기 통일
      context: context, // BuildContext 추가
    );
  }

  // 지도 마커 업데이트 - 비동기로 변경
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
        ],
      ),
    );
  }
}

// 커스텀 마커 위젯 (원+삼각형 디자인)
class _LocationMarkerWidget extends StatelessWidget {
  final Color color;

  const _LocationMarkerWidget({Key? key, required this.color})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 원형 마커
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
          ),
        ),
        // 삼각형
        CustomPaint(size: Size(16, 14), painter: TrianglePainter(color: color)),
      ],
    );
  }
}

// 삼각형 그리기 위한 CustomPainter
class TrianglePainter extends CustomPainter {
  final Color color;

  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    final path =
        Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width / 2, size.height)
          ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(TrianglePainter oldDelegate) => color != oldDelegate.color;
}
