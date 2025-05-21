import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:tomapto/controllers/map/transit_map_controller.dart';
import 'package:tomapto/controllers/map/navigation_controller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NavigationPage extends StatefulWidget {
  final TransitMode mode;
  final NLatLng origin;
  final NLatLng destination;
  final String originName;
  final String destinationName;

  const NavigationPage({
    Key? key,
    required this.mode,
    required this.origin,
    required this.destination,
    required this.originName,
    required this.destinationName,
  }) : super(key: key);

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage>
    with WidgetsBindingObserver {
  late NavigationController _navigationController;
  NaverMapController? _mapController;
  bool _isLoading = true;
  bool _isPathDisplayed = false;
  bool _hasLocationPermission = false;
  bool _isInForeground = true;

  // 도착 감지
  bool _hasArrived = false;

  // 음성 안내 기능
  bool _isVoiceGuidanceEnabled = true;
  String _lastInstruction = "";
  String _prevInstruction = ""; // 이전 지시 저장 변수

  // 현재 위치 변수
  NLatLng? _currentPosition;

  // 네비게이션 정보
  String _remainingDistance = "계산 중...";
  String _remainingTime = "계산 중...";

  // 출발지 이름 업데이트
  String _updatedOriginName = '';

  // 턴바이턴 네비게이션 정보
  Map<String, dynamic>? _currentTurnInstruction;

  // 속도 및 속도 제한
  double _currentSpeed = 0;
  int _speedLimit = 50;

  // 알림
  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 초기 위치는 출발지로 설정
    _currentPosition = widget.origin;

    // 초기 출발지 이름 설정
    _updatedOriginName = widget.originName;

    // NavigationController 초기화
    _navigationController = NavigationController(
      widget.mode,
      widget.origin,
      widget.destination,
    );

    _initializeNotifications();
    _checkLocationPermission();
  }

  // 알림 초기화
  Future<void> _initializeNotifications() async {
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    final AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 앱이 백그라운드로 갔을 때 처리
    _isInForeground = state == AppLifecycleState.resumed;

    // 백그라운드에서 포그라운드로 돌아왔을 때 지도 상태 복구
    if (state == AppLifecycleState.resumed) {
      _updateMapState();
    }
  }

  void _updateMapState() {
    if (_isPathDisplayed && !_hasArrived) {
      // 지도 상태 업데이트 필요 시 수행
    }
  }

  // 위치 권한 확인 및 초기화
  Future<void> _checkLocationPermission() async {
    // 위치 권한 요청
    final status = await Permission.location.request();

    if (status.isGranted) {
      setState(() {
        _hasLocationPermission = true;
        _isLoading = false;
      });

      // 위치 서비스 활성화 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServiceDialog();
        return;
      }

      // 네비게이션 시작
      _initNavigation();
    } else {
      setState(() {
        _hasLocationPermission = false;
        _isLoading = false;
      });
      _showPermissionDeniedDialog();
    }
  }

  // 위치 서비스 비활성화 시 다이얼로그
  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '위치 서비스 비활성화',
            style: TextStyle(
              fontFamily: "Pretendard",
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '네비게이션을 사용하려면 위치 서비스를 활성화해야 합니다.',
            style: TextStyle(fontFamily: "Pretendard"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text(
                '취소',
                style: TextStyle(
                  fontFamily: "Pretendard",
                  color: Colors.grey[700],
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Geolocator.openLocationSettings();
              },
              child: Text(
                '설정으로 이동',
                style: TextStyle(
                  fontFamily: "Pretendard",
                  color:
                      widget.mode == TransitMode.car
                          ? Color(0xFFFB233B)
                          : Color(0xFF0771EB),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 권한 거부 시 다이얼로그
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '위치 권한 필요',
            style: TextStyle(
              fontFamily: "Pretendard",
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '네비게이션을 사용하려면 위치 권한이 필요합니다.',
            style: TextStyle(fontFamily: "Pretendard"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text(
                '취소',
                style: TextStyle(
                  fontFamily: "Pretendard",
                  color: Colors.grey[700],
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: Text(
                '설정으로 이동',
                style: TextStyle(
                  fontFamily: "Pretendard",
                  color:
                      widget.mode == TransitMode.car
                          ? Color(0xFFFB233B)
                          : Color(0xFF0771EB),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 네비게이션 초기화
  Future<void> _initNavigation() async {
    // 각종 스트림 구독

    // 1. 네비게이션 정보 스트림 구독 (방향 지시, 거리, 시간)
    _navigationController.navigationInfoStream.listen(_handleNavigationInfo);

    // 2. 위치 업데이트 스트림 구독 (현재 위치)
    _navigationController.locationStream.listen(_handleLocationUpdate);

    // 3. 경로 이탈 스트림 구독 (경로 이탈 감지)
    _navigationController.routeDeviationStream.listen(_handleRouteDeviation);

    // 4. 도착 이벤트 스트림 구독 (목적지 도착)
    _navigationController.arrivalStream.listen((_) => _handleArrival());

    // 5. 턴바이턴 정보 스트림 구독
    _navigationController.turnByTurnStream.listen(_handleTurnByTurnUpdate);

    // 6. 속도 제한 스트림 구독
    _navigationController.speedLimitStream.listen(_handleSpeedLimitUpdate);

    // 실제 위치 추적 시작
    _navigationController.startRealLocationTracking();
  }

  // 네비게이션 정보 처리
  void _handleNavigationInfo(Map<String, dynamic> info) {
    setState(() {
      _isPathDisplayed = true;
      _lastInstruction = info['instruction'] as String;
      _remainingDistance = info['distance'] as String;
      _remainingTime = info['timeRemaining'] as String;
    });

    // 새로운 지시가 나타났을 때 음성 안내
    if (_isVoiceGuidanceEnabled && _lastInstruction != _prevInstruction) {
      _prevInstruction = _lastInstruction;

      // 음성 안내 (앱이 백그라운드일 때는 알림으로 대체)
      if (!_isInForeground) {
        _showNavigationNotification(_lastInstruction);
      } else {
        // 여기에 TTS(Text-to-Speech) 구현을 추가할 수 있음
      }
    }
  }

  // 위치 업데이트 처리
  void _handleLocationUpdate(NLatLng position) {
    // 현재 위치 저장
    setState(() {
      _currentPosition = position;
      // 현재 속도 업데이트 (시뮬레이션)
      _currentSpeed = _navigationController.getCurrentSpeed();
    });
  }

  // 턴바이턴 정보 업데이트 처리
  void _handleTurnByTurnUpdate(Map<String, dynamic> instruction) {
    setState(() {
      _currentTurnInstruction = instruction;
    });
  }

  // 속도 제한 업데이트 처리
  void _handleSpeedLimitUpdate(int limit) {
    setState(() {
      _speedLimit = limit;
    });
  }

  // 경로 이탈 처리
  void _handleRouteDeviation(bool isDeviated) {
    // 이미 처리 중이거나, 도착했거나, 이탈이 아니면 무시
    if (_isLoading || _hasArrived || !isDeviated) {
      return;
    }

    // 현재 위치가 없으면 무시
    if (_currentPosition == null) {
      print('경로 이탈 감지되었으나 현재 위치 정보가 없음');
      return;
    }

    print('경로 이탈 감지: 현재 위치에서 재계산 시작');

    // 로딩 상태로 전환
    setState(() {
      _isLoading = true;
      _isPathDisplayed = false; // 경로 표시 상태 리셋
    });

    // 사용자에게 알림
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '경로 이탈 감지: 새 경로를 검색합니다',
          style: TextStyle(fontFamily: "Pretendard"),
        ),
        backgroundColor:
            widget.mode == TransitMode.car
                ? Color(0xFFFB233B)
                : Color(0xFF0771EB),
        duration: Duration(seconds: 2),
      ),
    );

    // 약간의 지연 후 경로 재계산 (UI 업데이트 시간 확보)
    Future.delayed(Duration(milliseconds: 300), () {
      // 현재 위치에서 목적지까지 경로 재계산 - 결과에 주소 정보 포함하도록 수정
      _navigationController
          .recalculateRoute(_currentPosition!)
          .then((result) {
            // 새로운 출발지 주소 받아오기
            final success = result['success'] as bool;
            final newOriginAddress = result['newOriginAddress'] as String;

            // 약간의 지연 후 UI 상태 업데이트
            Future.delayed(Duration(milliseconds: 500), () {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _isPathDisplayed = true;

                  // 출발지 주소 업데이트 추가
                  if (newOriginAddress.isNotEmpty) {
                    _updatedOriginName = newOriginAddress;
                  }
                });

                if (success) {
                  print('경로 재계산 성공 - UI 업데이트 완료');
                } else {
                  // 실패 시 사용자에게 알림
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('경로 재계산 실패. 다시 시도합니다.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            });
          })
          .catchError((error) {
            print('경로 재계산 중 오류: $error');

            if (mounted) {
              setState(() {
                _isLoading = false;
                _isPathDisplayed = true;
              });

              // 오류 알림
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('경로 계산 중 오류가 발생했습니다'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          });
    });
  }

  // 도착 처리
  void _handleArrival() {
    if (!_hasArrived) {
      setState(() {
        _hasArrived = true;
      });

      // 도착 알림
      _showArrivalNotification();

      // 도착 축하 다이얼로그
      if (_isInForeground) {
        Future.delayed(Duration(seconds: 1), () {
          _showArrivalDialog();
        });
      }
    }
  }

  // 도착 다이얼로그
  void _showArrivalDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              '목적지 도착',
              style: TextStyle(
                fontFamily: "Pretendard",
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              '목적지에 도착했습니다!',
              style: TextStyle(fontFamily: "Pretendard"),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(
                  '확인',
                  style: TextStyle(
                    fontFamily: "Pretendard",
                    color:
                        widget.mode == TransitMode.car
                            ? Color(0xFFFB233B)
                            : Color(0xFF0771EB),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  // 네비게이션 알림 표시
  Future<void> _showNavigationNotification(String message) async {
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'navigation_channel',
          '네비게이션',
          channelDescription: '네비게이션 알림 채널',
          importance: Importance.high,
          priority: Priority.high,
          ongoing: true,
        );

    DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();

    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      0,
      '${widget.mode == TransitMode.car ? '운전' : '도보'} 네비게이션',
      message,
      platformChannelSpecifics,
    );
  }

  // 도착 알림 표시
  Future<void> _showArrivalNotification() async {
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'arrival_channel',
          '도착 알림',
          channelDescription: '도착 알림 채널',
          importance: Importance.high,
          priority: Priority.high,
        );

    DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();

    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      1,
      '목적지 도착',
      '${widget.destinationName}에 도착했습니다!',
      platformChannelSpecifics,
    );
  }

  // 음성 안내 토글
  void _toggleVoiceGuidance() {
    setState(() {
      _isVoiceGuidanceEnabled = !_isVoiceGuidanceEnabled;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isVoiceGuidanceEnabled ? '음성 안내가 켜졌습니다.' : '음성 안내가 꺼졌습니다.',
          style: TextStyle(fontFamily: "Pretendard"),
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _navigationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 메인 컬러 설정 (자동차/도보 모드에 따라)
    final Color mainColor =
        widget.mode == TransitMode.car ? Color(0xFFFB233B) : Color(0xFF0771EB);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: mainColor,
        title: Text(
          '${widget.originName} → ${widget.destinationName}',
          style: TextStyle(
            fontFamily: "Pretendard",
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // 음성 안내 토글 버튼
          IconButton(
            icon: Icon(
              _isVoiceGuidanceEnabled ? Icons.volume_up : Icons.volume_off,
              color: Colors.white,
            ),
            onPressed: _toggleVoiceGuidance,
          ),
        ],
        elevation: 0,
      ),
      body: Stack(
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              logoClickEnable: false,
              locationButtonEnable: false,
              nightModeEnable: true,
              initialCameraPosition: NCameraPosition(
                target: widget.origin,
                zoom: 16,
              ),
              // 자동차 모드에서는 네비게이션 지도 사용, 도보 모드에서는 기본 지도 사용
              mapType:
                  widget.mode == TransitMode.car
                      ? NMapType.navi
                      : NMapType.basic,
              contentPadding: EdgeInsets.only(bottom: 150),
            ),
            onMapReady: (controller) {
              print('맵 컨트롤러 준비 완료');
              _mapController = controller;

              // 맵 컨트롤러 설정
              _navigationController.setMapController(controller);

              // 도착지 마커 추가
              final markerImage = NOverlayImage.fromAssetImage(
                'assets/icons/end_marker.png',
              );
              final destinationMarker = NMarker(
                id: 'destination_marker',
                position: widget.destination,
                icon: markerImage,
                size: const Size(40, 50),
                anchor: const NPoint(0.5, 1.0),
              );
              controller.addOverlay(destinationMarker);

              // 전체 경로가 보이도록 카메라 이동
              _navigationController.fitBoundsToShowRoute(
                widget.origin,
                widget.destination,
              );

              setState(() {
                _isPathDisplayed = true;
              });
            },
          ),

          if (_isLoading)
            Center(child: CircularProgressIndicator(color: mainColor)),

          // 턴바이턴 방향 안내 (상단)
          if (_currentTurnInstruction != null && !_hasArrived)
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: mainColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(10),
                child: Row(
                  children: [
                    Icon(
                      _currentTurnInstruction!['directionIcon'] as IconData? ??
                          Icons.arrow_upward,
                      color: Colors.white,
                      size: 40,
                    ),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_currentTurnInstruction!['distanceToPoint'] ?? 0}m',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${_currentTurnInstruction!['roadName'] ?? ''}',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // 다음 방향 안내 (2번째 파란색 박스)
          if (_currentTurnInstruction != null &&
              !_hasArrived &&
              _navigationController.getNextInstruction() != null)
            Positioned(
              top: 110,
              left: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Color(0xFF2F80ED),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.all(10),
                child: Row(
                  children: [
                    Icon(
                      _navigationController
                                  .getNextInstruction()!['directionIcon']
                              as IconData? ??
                          Icons.arrow_forward,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_navigationController.getNextInstruction()!['distance'] ?? 0}m',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${_navigationController.getNextInstruction()!['roadName'] ?? ''}',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // 속도 제한 표시 (좌측 하단)
          if (widget.mode == TransitMode.car && !_hasArrived)
            Positioned(
              bottom: 170,
              left: 20,
              child: Column(
                children: [
                  // 속도 표시
                  Container(
                    width: 80,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${_currentSpeed.toInt()} km/h',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  // 속도 제한 표시
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.red, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 10,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(width: 4, height: 4, color: Colors.red),
                              SizedBox(width: 2),
                              Container(
                                width: 4,
                                height: 4,
                                color: Colors.yellow,
                              ),
                              SizedBox(width: 2),
                              Container(
                                width: 4,
                                height: 4,
                                color: Colors.green,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$_speedLimit',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 거리 정보 표시 (빨간색 박스)
                  SizedBox(height: 10),
                  Container(
                    width: 80,
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${_currentTurnInstruction != null ? _currentTurnInstruction!['distanceToPoint'] ?? 497 : 497}m',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 하단 정보 패널 (축소된 버전)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 슬라이더 표시 (짧은 회색 선)
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                    margin: EdgeInsets.only(bottom: 10),
                  ),

                  // 실시간 방향 및 거리 정보 (한 줄로 축소)
                  if (_isPathDisplayed)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 방향 지시
                        Expanded(
                          flex: 2,
                          child: Text(
                            _lastInstruction.isEmpty
                                ? '안내 준비 중...'
                                : _lastInstruction,
                            style: TextStyle(
                              fontFamily: "Pretendard",
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // 남은 거리 및 시간
                        Expanded(
                          flex: 1,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                _remainingDistance,
                                style: TextStyle(
                                  fontFamily: "Pretendard",
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: mainColor,
                                ),
                              ),
                              Text(
                                ' • ',
                                style: TextStyle(
                                  fontFamily: "Pretendard",
                                  fontSize: 15,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                _remainingTime,
                                style: TextStyle(
                                  fontFamily: "Pretendard",
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                  if (!_isPathDisplayed)
                    Text(
                      '경로 로딩 중...',
                      style: TextStyle(fontFamily: "Pretendard", fontSize: 14),
                    ),

                  SizedBox(height: 10),

                  // 안내 종료 버튼 (작게 수정)
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '안내 종료',
                        style: TextStyle(
                          fontFamily: "Pretendard",
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
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
