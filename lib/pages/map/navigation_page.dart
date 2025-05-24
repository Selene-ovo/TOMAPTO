import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
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
  bool _showTemporaryRoute = false;

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

    // 도보 모드일 때 즉시 임시 경로 표시
    if (widget.mode == TransitMode.walk) {
      _showTemporaryRoute = true;
      _showTemporaryWalkRoute();
    }

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

  // 임시 도보 경로 표시
  void _showTemporaryWalkRoute() {
    setState(() {
      _isPathDisplayed = true;
      _lastInstruction = "목적지로 걸어가는 중...";

      final distance = _calculateSimpleDistance(
        widget.origin,
        widget.destination,
      );
      final time = (distance / 1.4 / 60).ceil(); // 분 단위

      _remainingDistance =
          distance < 1000
              ? "${distance.round()}m"
              : "${(distance / 1000).toStringAsFixed(1)}km";
      _remainingTime = "${time}분";
    });

    // 5초 후에 실제 경로로 교체 (백그라운드에서 로딩 완료 시)
    Timer(Duration(seconds: 5), () {
      if (_showTemporaryRoute) {
        setState(() {
          _showTemporaryRoute = false;
        });
      }
    });
  }

  double _calculateSimpleDistance(NLatLng start, NLatLng end) {
    const double earthRadius = 6371000;
    final double lat1 = start.latitude * (pi / 180);
    final double lat2 = end.latitude * (pi / 180);
    final double dLat = (end.latitude - start.latitude) * (pi / 180);
    final double dLon = (end.longitude - start.longitude) * (pi / 180);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
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

    // 3. 경로 이탈 스트림 구독 (경로 이탈 감지) - 자동차 모드에서만
    if (widget.mode == TransitMode.car) {
      _navigationController.routeDeviationStream.listen(_handleRouteDeviation);
    }

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
    // 임시 경로 모드가 아닐 때만 업데이트
    if (!_showTemporaryRoute) {
      setState(() {
        _isPathDisplayed = true;
        _lastInstruction = info['instruction'] as String;
        _remainingDistance = info['distance'] as String;
        _remainingTime = info['timeRemaining'] as String;
      });
    }

    // 음성 안내...
    if (_isVoiceGuidanceEnabled && _lastInstruction != _prevInstruction) {
      _prevInstruction = _lastInstruction;

      if (!_isInForeground) {
        _showNavigationNotification(_lastInstruction);
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

    // NavigationController에서 현재 heading 정보 가져오기
    final currentHeading = _navigationController.getCurrentHeading();

    // 현재 위치 오버레이 업데이트 (heading 포함)
    _updateLocationOverlay(position, heading: currentHeading);
  }

  // 현재 위치 오버레이 업데이트 메서드 추가
  void _updateLocationOverlay(NLatLng position, {double? heading}) {
    if (_mapController == null) return;

    try {
      // 위치 오버레이 가져오기
      final locationOverlay = _mapController!.getLocationOverlay();

      // 위치 설정
      locationOverlay.setPosition(position);

      // === 색상 커스터마이징 ===
      // 모드에 따른 색상 설정
      if (widget.mode == TransitMode.car) {
        // 자동차 모드: 빨간색 계열
        locationOverlay.setCircleColor(Color(0x10FB233B)); // 반투명 빨간색 원
      } else {
        // 도보 모드: 파란색 계열
        locationOverlay.setCircleColor(Color(0x100771EB)); // 반투명 파란색 원
      }

      // === 원 크기 설정 ===
      locationOverlay.setCircleRadius(10.0); // 기본값보다 크게

      // === 아이콘 커스터마이징 ===
      // 모드에 따른 아이콘 설정
      /*if (widget.mode == TransitMode.car) {
        // 자동차 아이콘 사용
        locationOverlay.setIcon(
          NOverlayImage.fromAssetImage(
            'assets/icons/car_location_icon.png', // 자동차 아이콘 (없으면 기본 아이콘 사용)
          ),
        );
      } else {
        // 도보 아이콘 사용 (기본 아이콘 또는 커스텀)
        locationOverlay.setIcon(
          NOverlayImage.fromAssetImage(
            'assets/icons/walk_location_icon.png', // 도보 아이콘 (없으면 기본 아이콘 사용)
          ),
        );
      }*/

      // === 아이콘 크기 설정 ===
      locationOverlay.setIconSize(Size(100, 100)); // 아이콘 크기

      // === 앵커 포인트 설정 ===
      locationOverlay.setAnchor(NPoint(0.5, 0.5)); // 중심점 기준

      // 방향 설정 (heading 정보가 있을 때)
      if (heading != null) {
        locationOverlay.setBearing(heading);
        print('위치 오버레이 방향 설정: ${heading.toStringAsFixed(1)}도');
      }

      // 오버레이가 보이도록 설정
      locationOverlay.setIsVisible(true);

      // 위치 추적 모드 설정
      _mapController!.setLocationTrackingMode(
        widget.mode == TransitMode.car
            ? NLocationTrackingMode
                .face // 자동차: 방향도 따라감
            : NLocationTrackingMode.follow, // 도보: 위치만 따라감
      );
    } catch (e) {
      print('위치 오버레이 업데이트 오류: $e');
    }
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

  // 경로 이탈 처리 (자동차 모드에서만)
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

  // 내 위치로 이동하는 메서드
  void _moveToCurrentLocation() async {
    if (_mapController == null) return;

    try {
      // NaverMap 초기 옵션과 동일한 값 사용
      double targetZoom =
          widget.mode == TransitMode.car ? 18.0 : 16.0; // 초기 옵션과 동일
      double targetTilt =
          widget.mode == TransitMode.car ? 35.0 : 0.0; // 초기 옵션과 동일

      // 현재 위치가 있으면 해당 위치로 이동
      if (_currentPosition != null) {
        await _mapController!.updateCamera(
          NCameraUpdate.withParams(
            target: _currentPosition!,
            zoom: targetZoom, // 21 (자동차) / 16 (도보)
            tilt: targetTilt, // 35도 (자동차) / 0도 (도보)
          ),
        );

        // 위치 추적 모드 재설정
        await _mapController!.setLocationTrackingMode(
          widget.mode == TransitMode.car
              ? NLocationTrackingMode.face
              : NLocationTrackingMode.follow,
        );

        print(
          '기존 위치로 이동 - ${widget.mode == TransitMode.car ? "자동차" : "도보"} 모드',
        );
        print('줌: $targetZoom, 틸트: $targetTilt도');
      } else {
        // 현재 위치를 새로 가져오기
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final currentLocation = NLatLng(position.latitude, position.longitude);

        await _mapController!.updateCamera(
          NCameraUpdate.withParams(
            target: currentLocation,
            zoom: targetZoom, // 21 (자동차) / 16 (도보)
            tilt: targetTilt, // 35도 (자동차) / 0도 (도보)
          ),
        );

        setState(() {
          _currentPosition = currentLocation;
        });

        print('새 위치로 이동 - ${widget.mode == TransitMode.car ? "자동차" : "도보"} 모드');
        print('줌: $targetZoom, 틸트: $targetTilt도');
      }
    } catch (e) {
      print('현재 위치 이동 오류: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _navigationController.dispose();
    super.dispose();
  }

  void _setInitialCameraView(NaverMapController controller) {
    // 출발지와 도착지를 모두 포함하는 초기 뷰 설정
    final bounds = _calculateRouteBounds(widget.origin, widget.destination);

    controller.updateCamera(
      NCameraUpdate.fitBounds(
        bounds,
        padding: EdgeInsets.all(80), // 넉넉한 패딩
      ),
    );

    print('초기 카메라 뷰 설정 완료');
  }

  void _addDestinationMarker(NaverMapController controller) {
    final markerImage = NOverlayImage.fromAssetImage(
      'assets/icons/end_marker.png',
    );

    final destinationMarker = NMarker(
      id: 'destination_marker',
      position: widget.destination,
      icon: markerImage,
      size: const Size(40, 50),
      anchor: const NPoint(0.5, 1.0),
      iconTintColor:
          widget.mode == TransitMode.car
              ? Color(0xFFFF001C)
              : Color(0xFF0077FF),
    );

    controller.addOverlay(destinationMarker);
    print('도착지 마커 추가 완료');
  }

  void _waitForRouteAndAdjustCamera(NaverMapController controller) {
    // 경로 로딩 완료까지 대기 후 카메라 조정
    Timer.periodic(Duration(milliseconds: 500), (timer) {
      // 경로가 로드되었는지 확인
      if (_navigationController.hasPathCoordinates() &&
          _navigationController.hasPathOverlay()) {
        timer.cancel();
        print('경로 로딩 완료 - 카메라 최종 조정 시작');

        // 잠시 후 적절한 네비게이션 카메라로 전환
        Future.delayed(Duration(milliseconds: 1000), () {
          _setNavigationCamera(controller);
        });
      }

      // 최대 10초 대기
      if (timer.tick > 20) {
        timer.cancel();
        print('경로 로딩 타임아웃 - 기본 카메라 설정');
        _setNavigationCamera(controller);
      }
    });
  }

  void _setNavigationCamera(NaverMapController controller) async {
    try {
      if (widget.mode == TransitMode.car) {
        // 자동차 모드: 현재 위치 중심, 높은 줌, 틸트 적용
        await controller.updateCamera(
          NCameraUpdate.withParams(
            target: _currentPosition ?? widget.origin,
            zoom: 18.0, // 네비게이션에 적합한 줌 레벨
            tilt: 35.0, // 3D 시점
            bearing: _navigationController.getCurrentHeading(), // 현재 방향
          ),
        );

        // 위치 추적 모드: 방향도 따라감
        await controller.setLocationTrackingMode(NLocationTrackingMode.face);
      } else {
        // 도보 모드: 약간 넓은 시야, 틸트 없음
        await controller.updateCamera(
          NCameraUpdate.withParams(
            target: _currentPosition ?? widget.origin,
            zoom: 16.0, // 도보에 적합한 줌 레벨
            tilt: 0.0, // 평면 시점
          ),
        );

        // 위치 추적 모드: 위치만 따라감
        await controller.setLocationTrackingMode(NLocationTrackingMode.follow);
      }

      print(
        '네비게이션 카메라 설정 완료 - ${widget.mode == TransitMode.car ? "자동차" : "도보"} 모드',
      );
    } catch (e) {
      print('네비게이션 카메라 설정 오류: $e');
    }
  }

  NLatLngBounds _calculateRouteBounds(NLatLng start, NLatLng end) {
    double minLat = min(start.latitude, end.latitude);
    double maxLat = max(start.latitude, end.latitude);
    double minLng = min(start.longitude, end.longitude);
    double maxLng = max(start.longitude, end.longitude);

    // 최소 영역 보장 (너무 작은 경우 확장)
    double latPadding = max(0.001, (maxLat - minLat) * 0.1);
    double lngPadding = max(0.001, (maxLng - minLng) * 0.1);

    return NLatLngBounds(
      southWest: NLatLng(minLat - latPadding, minLng - lngPadding),
      northEast: NLatLng(maxLat + latPadding, maxLng + lngPadding),
    );
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
              locationButtonEnable: false, // API 위치 버튼 비활성화
              nightModeEnable: true,
              initialCameraPosition: NCameraPosition(
                target: widget.origin,
                tilt: widget.mode == TransitMode.car ? 35.0 : 0.0,
                zoom: widget.mode == TransitMode.car ? 21 : 16,
              ),
              // 자동차 모드에서는 네비게이션 지도 사용, 도보 모드에서는 기본 지도 사용
              mapType:
                  widget.mode == TransitMode.car
                      ? NMapType.navi
                      : NMapType.basic,
              contentPadding: EdgeInsets.only(bottom: 150),
              zoomGesturesEnable: widget.mode != TransitMode.car, // 줌 제스처 제한
              tiltGesturesEnable: widget.mode != TransitMode.car, // 틸트 제스처 제한
            ),
            onMapReady: (controller) async {
              print('맵 컨트롤러 준비 완료');
              _mapController = controller;

              // 맵 컨트롤러 설정
              _navigationController.setMapController(controller);

              try {
                // 1. 먼저 전체 경로가 보이도록 카메라 설정 (넉넉한 줌 아웃)
                _setInitialCameraView(controller);

                // 2. 위치 추적 모드 초기 설정 (일시적으로 none으로 설정)
                await controller.setLocationTrackingMode(
                  NLocationTrackingMode.none,
                );

                // 3. 현재 위치 오버레이 설정
                final locationOverlay = controller.getLocationOverlay();
                locationOverlay.setIsVisible(true);

                // 4. 초기 위치가 있으면 현재 위치 오버레이 업데이트
                if (_currentPosition != null) {
                  final initialHeading =
                      _navigationController.getCurrentHeading();
                  _updateLocationOverlay(
                    _currentPosition!,
                    heading: initialHeading,
                  );
                }

                // 5. 도착지 마커 추가
                _addDestinationMarker(controller);

                // 6. 경로 로딩 대기 및 카메라 최종 조정
                _waitForRouteAndAdjustCamera(controller);

                setState(() {
                  _isPathDisplayed = true;
                });
              } catch (e) {
                print('맵 초기화 오류: $e');
              }
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

          // 커스텀 현재 위치 버튼 (우측 하단) - 새로 추가
          Positioned(
            bottom: 170,
            right: 20,
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
                  onTap: _moveToCurrentLocation,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(shape: BoxShape.circle),
                    child: Icon(Icons.my_location, color: mainColor, size: 24),
                  ),
                ),
              ),
            ),
          ),

          // 속도 제한 표시 (좌측 하단) - 자동차 모드에서만
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

          // 도보 모드일 때 위치 버튼 위치 조정
          if (widget.mode == TransitMode.walk && !_hasArrived)
            Positioned(
              bottom: 170,
              right: 20,
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
                    onTap: _moveToCurrentLocation,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(shape: BoxShape.circle),
                      child: Icon(
                        Icons.my_location,
                        color: mainColor,
                        size: 24,
                      ),
                    ),
                  ),
                ),
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
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: mainColor,
                                ),
                              ),
                              Text(
                                ' • ',
                                style: TextStyle(
                                  fontFamily: "Pretendard",
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                _remainingTime,
                                style: TextStyle(
                                  fontFamily: "Pretendard",
                                  fontSize: 14,
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
