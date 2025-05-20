import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomapto/services/socket_service.dart';
import 'package:tomapto/services/location_service.dart';
import 'package:tomapto/services/token_service.dart';
import 'package:tomapto/services/real_time_location_service.dart';

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
  bool _isLoading = true; // 초기 로딩 상태만 true로 설정
  bool _isInitialLoadComplete = false; // 초기 로딩 완료 여부 추적
  String _errorMessage = '';

  // 소켓 서비스 인스턴스
  late SocketService _socketService;
  // 위치 정보 자동 갱신을 위한 타이머
  Timer? _locationUpdateTimer;
  // 소켓 이벤트 구독자
  StreamSubscription? _locationUpdateSubscription;

  // 위치 공유 상태 추적 변수들
  bool _isLocationSharingActive = false; // 전체적인 공유 상태 (주로 내가 공유 중인지)
  bool _iAmSharingLocation = false; // 내가 상대방에게 위치 공유 중인지
  bool _friendIsSharingLocation = false; // 상대방이 나에게 위치 공유 중인지

  // 마지막 업데이트 시간
  DateTime? _lastUpdateTime;

  @override
  void initState() {
    super.initState();
    _socketService = SocketService();
    _initSocket();
    _loadLocations();

    // 1초마다 위치 정보 갱신 (API 호출) - 로딩 표시 없이 실시간 업데이트 유지
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // 마지막 업데이트 후 1초 이상 지났으면 API로 다시 로드
      final now = DateTime.now();
      if (_lastUpdateTime == null ||
          now.difference(_lastUpdateTime!).inSeconds > 1) {
        _refreshLocations(); // 로딩 표시 없이 새로고침하는 함수 사용
      }
    });
  }

  @override
  void dispose() {
    // 타이머 정리
    _locationUpdateTimer?.cancel();
    // 소켓 이벤트 구독 취소
    _locationUpdateSubscription?.cancel();
    super.dispose();
  }

  // 소켓 초기화 및 이벤트 리스너 설정
  Future<void> _initSocket() async {
    try {
      if (!_socketService.isConnected) {
        await _socketService.initSocket();
      }

      // 위치 업데이트 이벤트 구독
      _locationUpdateSubscription = _socketService.onLocationUpdate.listen((
        data,
      ) {
        // 친구 ID가 선택한 친구의 ID와 일치하고 친구가 위치 공유 중인 경우에만 업데이트
        if (data['user_id'] == widget.selectedFriend['id'] &&
            _friendIsSharingLocation) {
          setState(() {
            _friendPosition = NLatLng(data['latitude'], data['longitude']);
            _lastUpdateTime = DateTime.now();
          });
          _updateMapMarkers(); // 마커 업데이트
          print('소켓으로 친구 위치 업데이트: ${data['latitude']}, ${data['longitude']}');
        }
      });

      // 위치 공유 종료 이벤트 리스너
      _socketService.onLocationSharingStopped.listen((data) {
        if (data['user_id'] == widget.selectedFriend['id']) {
          setState(() {
            _friendIsSharingLocation = false; // 친구의 위치 공유 비활성화
            _friendPosition = null; // 중요: 친구 위치 정보 제거
          });
          _updateMapMarkers(); // 마커 업데이트
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.selectedFriend['name']}님이 위치 공유를 종료했습니다'),
            ),
          );
        }
      });

      // 위치 공유 시작 이벤트 리스너
      _socketService.onLocationSharingStarted.listen((data) {
        if (data['user_id'] == widget.selectedFriend['id']) {
          setState(() {
            _friendIsSharingLocation = true; // 친구의 위치 공유 활성화
          });
          // 위치 정보 새로고침 (로딩 표시 없이)
          _refreshLocations();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.selectedFriend['name']}님이 위치 공유를 시작했습니다'),
            ),
          );
        }
      });

      print('소켓 이벤트 리스너 설정 완료');
    } catch (e) {
      print('소켓 초기화 오류: $e');
    }
  }

  // 초기 로딩 시에만 로딩 표시와 함께 데이터 로드
  Future<void> _loadLocations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _fetchLocationData();

      setState(() {
        _isLoading = false;
        _isInitialLoadComplete = true;
      });
    } catch (e) {
      print('위치 정보 로드 오류: $e');
      setState(() {
        _errorMessage = '위치 정보를 불러오는데 실패했습니다. 나중에 다시 시도해주세요.';
        _isLoading = false;
      });
    }
  }

  // 로딩 표시 없이 위치 정보 갱신
  Future<void> _refreshLocations() async {
    if (!_isInitialLoadComplete) return;

    try {
      await _fetchLocationData();
    } catch (e) {
      print('위치 정보 새로고침 오류: $e');
      // 오류가 발생해도 UI에 표시하지 않음
    }
  }

  // 실제 위치 데이터를 가져오는 공통 로직
  Future<void> _fetchLocationData() async {
    // 토큰 유효성 확인
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('user_id');

    if (token == null || TokenService.isTokenExpired(token)) {
      setState(() {
        _errorMessage = '로그인이 필요하거나 세션이 만료되었습니다';
      });
      return;
    }

    print('위치 정보 로드 중... 내 ID: $userId, 친구 ID: ${widget.selectedFriend['id']}');

    // 1. 내 위치 가져오기
    final myLocationData = await LocationService.getCurrentLocation();
    if (myLocationData != null) {
      setState(() {
        _myPosition = NLatLng(
          myLocationData.latitude,
          myLocationData.longitude,
        );
      });

      // 내 위치를 가져온 후 바로 카메라 이동 (초기화 후)
      if (_mapController != null && !_isInitialCameraSet) {
        _mapController!.updateCamera(
          NCameraUpdate.withParams(target: _myPosition!, zoom: 15),
        );
        _isInitialCameraSet = true;
      }
    } else {
      print('내 위치 정보를 가져오는데 실패했습니다.');
    }

    // 2. 중요: 두 가지 위치 공유 상태를 별도로 확인
    final friendId = widget.selectedFriend['id'];

    // 2-1. 내가 위치 공유 중인지 확인 (내가 공유자, 친구가 수신자)
    final iAmSharing = await LocationService.checkIAmSharingWith(friendId);
    print('내가 위치 공유 중인지 확인 결과: $iAmSharing');

    // 2-2. 친구가 위치 공유 중인지 확인 (친구가 공유자, 내가 수신자)
    final friendIsSharing = await LocationService.checkFriendIsSharingWith(
      friendId,
    );
    print('친구가 위치 공유 중인지 확인 결과: $friendIsSharing');

    // 3. 위치 공유 상태 업데이트
    setState(() {
      // 내가 위치 공유 중인지 여부 (나 -> 친구)
      _iAmSharingLocation = iAmSharing;

      // 친구가 위치 공유 중인지 여부 (친구 -> 나)
      _friendIsSharingLocation = friendIsSharing;

      // 중요: 친구가 공유하지 않는 경우 친구 위치 정보 제거
      if (!friendIsSharing) {
        _friendPosition = null;
      }
    });

    print('위치 공유 상태: 내가 공유 중: $iAmSharing, 친구가 공유 중: $friendIsSharing');

    // 4. 친구 위치 정보 가져오기 - 친구가 공유 중인 경우에만
    if (friendIsSharing) {
      final friendLocationData = await LocationService.getFriendLocation(
        friendId,
      );

      if (friendLocationData != null) {
        // 문자열을 double로 변환하여 저장
        setState(() {
          _friendPosition = NLatLng(
            double.parse(friendLocationData['latitude'].toString()),
            double.parse(friendLocationData['longitude'].toString()),
          );
          _lastUpdateTime = DateTime.now();
        });
        print(
          '친구 위치 정보 로드 성공: ${friendLocationData['latitude']}, ${friendLocationData['longitude']}',
        );
      } else {
        print('친구 위치 정보를 가져오는데 실패했습니다.');
      }
    }

    // 위치 데이터를 얻은 후 마커 업데이트
    if (_mapController != null) {
      _updateMapMarkers();
    }
  }

  // 내 위치 마커 생성 함수
  NMarker _createMyLocationMarker() {
    final marker = NMarker(id: 'my_location', position: _myPosition!);

    // 에셋 이미지를 마커 아이콘으로 설정 - 경로 수정
    final overlayImage = NOverlayImage.fromAssetImage('assets/icons/me.png');
    marker.setIcon(overlayImage);

    // 마커 크기 설정 (이미지 크기에 맞게 조정)
    marker.setSize(NSize(48, 48));

    // 마커 앵커 포인트 설정 - 이미지의 하단 중앙이 좌표에 위치하도록
    marker.setAnchor(NPoint(0.5, 1.0));

    // 캡션 설정 (선택적)
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

  // 친구 위치 마커 생성 함수
  NMarker _createFriendLocationMarker() {
    final marker = NMarker(id: 'friend_location', position: _friendPosition!);

    // 에셋 이미지를 마커 아이콘으로 설정 - 경로 수정
    final overlayImage = NOverlayImage.fromAssetImage(
      'assets/icons/friends.png',
    );
    marker.setIcon(overlayImage);

    // 마커 크기 설정 (이미지 크기에 맞게 조정)
    marker.setSize(NSize(48, 48));

    // 마커 앵커 포인트 설정
    marker.setAnchor(NPoint(0.5, 1.0));

    // 캡션 설정 (친구 이름 표시)
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

    // 내 위치 마커 추가 - 항상 내 위치 마커는 표시
    if (_myPosition != null) {
      final myMarker = _createMyLocationMarker();

      myMarker.setOnTapListener((NMarker marker) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('내 현재 위치')));
      });

      _mapController!.addOverlay(myMarker);
      _markers.add(myMarker);
    }

    // 친구 위치 마커 추가 - 위치 공유가 활성화되고 친구 위치가 있는 경우에만
    if (_friendPosition != null && _friendIsSharingLocation) {
      // 추가 검증: 친구 위치 좌표가 유효한지 확인
      if (_friendPosition!.latitude != 0 && _friendPosition!.longitude != 0) {
        final friendMarker = _createFriendLocationMarker();

        friendMarker.setOnTapListener((NMarker marker) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.selectedFriend['name']}님의 위치')),
          );
        });

        _mapController!.addOverlay(friendMarker);
        _markers.add(friendMarker);
      }
    }

    // 최초 카메라 위치 조정
    if (!_isInitialCameraSet) {
      if (_myPosition != null &&
          _friendPosition != null &&
          _friendIsSharingLocation) {
        // 내 위치와 친구 위치 모두 있고 공유 활성화된 경우: 두 마커가 모두 보이도록
        _fitBoundsToShowBothMarkers();
      } else if (_myPosition != null) {
        // 내 위치만 있는 경우: 내 위치로 카메라 조정
        _mapController!.updateCamera(
          NCameraUpdate.withParams(target: _myPosition!, zoom: 15),
        );
      }
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

    // 경계 객체 생성
    final bounds = NLatLngBounds(
      southWest: NLatLng(minLat, minLng),
      northEast: NLatLng(maxLat, maxLng),
    );

    // 경계에 맞게 카메라 조정 - 패딩을 EdgeInsets 객체로 전달
    _mapController!.updateCamera(
      NCameraUpdate.fitBounds(bounds, padding: EdgeInsets.all(50.0)),
    );
  }

  // 위치 공유 시작 요청 - 내 위치만 공유 (상대방에게 보내는 것)
  Future<void> _startLocationSharing() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // 시작 확인 다이얼로그
      final result =
          await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text('위치 공유 시작'),
                  content: Text(
                    '${widget.selectedFriend['name']}님에게 내 위치를 공유하시겠습니까?\n\n상대방은 위치 공유를 시작해야 상대방의 위치를 볼 수 있습니다.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green,
                      ),
                      child: Text('시작'),
                    ),
                  ],
                ),
          ) ??
          false;

      if (!result) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 소켓을 통한 위치 공유 시작 요청
      if (!_socketService.isConnected) {
        await _socketService.initSocket();
      }
      _socketService.startLocationSharing(widget.selectedFriend['id'], null);

      // API를 통한 위치 공유 시작 요청
      final success = await LocationService.requestLocationSharing(
        widget.selectedFriend['id'],
      );

      // 위치 공유 활성화 - 추가된 부분
      if (success) {
        final realTimeLocationService = RealTimeLocationService();
        realTimeLocationService.enableSharing();
        print('위치 공유 기능 활성화됨');
      }

      setState(() {
        _isLoading = false;
        if (success) {
          _iAmSharingLocation = true; // 내 위치 공유 활성화 (중요: 내가 공유하는 것만 활성화)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('내 위치 공유가 활성화되었습니다')));

          // 위치 정보 새로고침 (로딩 표시 없음)
          _refreshLocations();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('위치 공유 시작 요청 실패. 나중에 다시 시도하세요.')),
          );
        }
      });
    } catch (e) {
      print('위치 공유 시작 오류: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('위치 공유 시작 중 오류가 발생했습니다.')));
    }
  }

  // 마지막 업데이트 시간 포맷팅
  String _formatLastUpdateTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}초 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else {
      return '${time.month}월 ${time.day}일 ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
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
          // 네이버 맵 - 초기 카메라 위치를 내 위치로 설정
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target:
                    _myPosition ?? NLatLng(37.5666805, 126.9784147), // 내 위치 우선
                zoom: 15,
              ),
              mapType: NMapType.basic,
              contentPadding: EdgeInsets.zero,
              locationButtonEnable: true, // 위치 버튼 활성화
            ),
            onMapReady: (controller) {
              setState(() {
                _mapController = controller;
              });
              _updateMapMarkers();

              // 맵이 준비되면 내 위치로 이동 (이미 위치가 있는 경우)
              if (_myPosition != null && !_isInitialCameraSet) {
                controller.updateCamera(
                  NCameraUpdate.withParams(target: _myPosition!, zoom: 15),
                );
                _isInitialCameraSet = true;
              }
            },
          ),

          // 현재 위치 버튼
          Positioned(
            bottom: 16,
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('내 위치 정보를 가져올 수 없습니다.')),
                  );
                }
              },
            ),
          ),

          // 로딩 표시 (초기 로딩 시에만 표시)
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

          // 위치 공유 상태 메시지 - 친구가 공유 중이 아니고, 로딩/에러 상태가 아니고, 내가 공유 중이 아닐 때만 표시
          if (!_friendIsSharingLocation &&
              !_isLoading &&
              _errorMessage.isEmpty &&
              !_iAmSharingLocation)
            Container(
              color: Colors.white.withOpacity(0.7),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_off, color: Colors.orange, size: 48),
                      SizedBox(height: 12),
                      Text(
                        '${widget.selectedFriend['name']}님과 위치 공유가 활성화되지 않았습니다.',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _startLocationSharing,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: Text('위치 공유 시작하기'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 위치 공유 시간 정보
          if (_friendIsSharingLocation && _lastUpdateTime != null)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '마지막 업데이트: ${_formatLastUpdateTime(_lastUpdateTime!)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              ),
            ),

          // 친구 위치 공유 상태 표시 - 내가 공유 중이지만 친구는 아닐 때
          if (!_friendIsSharingLocation && _iAmSharingLocation)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${widget.selectedFriend['name']}님은 아직 위치를 공유하고 있지 않습니다',
                    style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
