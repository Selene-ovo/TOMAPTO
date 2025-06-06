import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:tomapto/controllers/map/transit_map_controller.dart';
import 'package:tomapto/controllers/map/navigation_controller.dart';
import 'package:tomapto/pages/navi/navigation_modals.dart';
import 'package:tomapto/pages/navi/navigation_timer_manager.dart';
import 'package:tomapto/pages/navi/navigation_ui_widgets.dart';
import 'package:tomapto/pages/navi/navigation_permissions.dart';
import 'package:tomapto/pages/navi/navigation_map_utils.dart';

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
  late NavigationTimerManager _timerManager;

  NaverMapController? _mapController;

  // 상태 변수들
  bool _isLoading = true;
  bool _isPathDisplayed = false;
  bool _hasLocationPermission = false;
  bool _isInForeground = true;
  bool _showTemporaryRoute = false;
  bool _hasArrived = false;
  bool _autoRecalculateEnabled = true;
  bool _isRecalculateModalShown = false;

  // 위치 및 네비게이션 정보
  NLatLng? _currentPosition;
  String _remainingDistance = "계산 중...";
  String _remainingTime = "계산 중...";
  String _updatedOriginName = '';
  String _currentRoadName = "도로 확인 중...";
  Map<String, dynamic>? _currentTurnInstruction;
  double _currentSpeed = 0;
  int _speedLimit = 50;

  @override
  void initState() {
    super.initState();
    _initializeComponents();
    _handleInitialSetup();
  }

  void _initializeComponents() {
    WidgetsBinding.instance.addObserver(this);
    _timerManager = NavigationTimerManager();
    _currentPosition = widget.origin;
    _updatedOriginName = widget.originName;

    _navigationController = NavigationController(
      widget.mode,
      widget.origin,
      widget.destination,
    );
  }

  void _handleInitialSetup() async {
    if (widget.mode == TransitMode.walk) {
      _showTemporaryWalkRoute();
    }

    await _checkLocationPermission();
  }

  void _showTemporaryWalkRoute() {
    setState(() {
      _isPathDisplayed = true;
      _showTemporaryRoute = true;

      final distance = NavigationMapUtils.calculateSimpleDistance(
        widget.origin,
        widget.destination,
      );
      final time = (distance / 1.4 / 60).ceil();

      _remainingDistance =
          distance < 1000
              ? "${distance.round()}m"
              : "${(distance / 1000).toStringAsFixed(1)}km";
      _remainingTime = "${time}분";
    });

    _timerManager.createTemporaryRouteTimer(Duration(seconds: 5), () {
      if (mounted && _showTemporaryRoute) {
        setState(() {
          _showTemporaryRoute = false;
        });
      }
    });
  }

  Future<void> _checkLocationPermission() async {
    final hasPermission = await NavigationPermissions.checkLocationPermission(
      context,
      widget.mode,
    );

    setState(() {
      _hasLocationPermission = hasPermission;
      _isLoading = false;
    });

    if (hasPermission) {
      _initNavigation();
    }
  }

  Future<void> _initNavigation() async {
    _setupStreamListeners();
    _navigationController.startRealLocationTracking();
  }

  void _setupStreamListeners() {
    _navigationController.navigationInfoStream.listen(_handleNavigationInfo);
    _navigationController.locationStream.listen(_handleLocationUpdate);
    _navigationController.arrivalStream.listen((_) => _handleArrival());
    _navigationController.turnByTurnStream.listen(_handleTurnByTurnUpdate);
    _navigationController.speedLimitStream.listen(_handleSpeedLimitUpdate);

    if (widget.mode == TransitMode.car) {
      _navigationController.routeDeviationStream.listen(_handleRouteDeviation);
    }

    // 턴바이턴 초기 데이터 확인을 위한 지연된 체크
    _timerManager.createDelayTimer(Duration(seconds: 2), () {
      if (mounted) {
        final initialInstruction =
            _navigationController.getCurrentInstruction();
        if (initialInstruction != null) {
          _handleTurnByTurnUpdate(initialInstruction);
          print(
            '🎯 초기 턴바이턴 데이터 확인: ${initialInstruction['direction']} - ${initialInstruction['roadName']}',
          );
        } else {
          print('⚠️ 초기 턴바이턴 데이터 없음');
        }
      }
    });
  }

  void _handleNavigationInfo(Map<String, dynamic> info) {
    if (!_showTemporaryRoute) {
      setState(() {
        _isPathDisplayed = true;
        _remainingDistance = info['distance'] as String;
        _remainingTime = info['timeRemaining'] as String;
      });
    }
  }

  void _handleLocationUpdate(NLatLng position) {
    setState(() {
      _currentPosition = position;
      _currentSpeed = _navigationController.getCurrentSpeed();

      final newRoadName = _navigationController.getCurrentRoadName(position);
      if (newRoadName != _currentRoadName &&
          newRoadName != "도로" &&
          newRoadName.isNotEmpty &&
          !newRoadName.startsWith('도로 ') &&
          newRoadName != '도로 확인 중...') {
        _currentRoadName = newRoadName;
      }
    });

    final currentHeading = _navigationController.getCurrentHeading();
    if (_mapController != null) {
      NavigationMapUtils.updateLocationOverlay(
        _mapController!,
        position,
        widget.mode,
        heading: currentHeading,
      );
    }
  }

  void _handleTurnByTurnUpdate(Map<String, dynamic> instruction) {
    setState(() {
      _currentTurnInstruction = instruction;

      // 턴바이턴 정보에서 도로명 업데이트 로직 개선
      final instructionRoadName = instruction['roadName'] as String?;
      if (instructionRoadName != null &&
          instructionRoadName.isNotEmpty &&
          instructionRoadName != '도로' &&
          instructionRoadName != '도로 안내' &&
          !instructionRoadName.startsWith('도로 ') &&
          !instructionRoadName.endsWith('구간')) {
        _currentRoadName = instructionRoadName;
      }
    });
  }

  void _handleSpeedLimitUpdate(int limit) {
    if (mounted) {
      setState(() {
        _speedLimit = limit;
      });
    }
  }

  void _handleRouteDeviation(bool isDeviated) {
    if (_isLoading ||
        _hasArrived ||
        !isDeviated ||
        _isRecalculateModalShown ||
        !_autoRecalculateEnabled ||
        _currentPosition == null) {
      return;
    }

    _showRecalculateModal();
  }

  void _handleArrival() {
    if (!_hasArrived) {
      setState(() {
        _hasArrived = true;
      });

      if (_isInForeground) {
        Future.delayed(Duration(seconds: 1), () {
          NavigationModals.showArrivalDialog(
            context: context,
            mode: widget.mode,
            destinationName: widget.destinationName,
          );
        });
      }
    }
  }

  void _showRecalculateModal() {
    setState(() {
      _isRecalculateModalShown = true;
    });

    NavigationModals.showRecalculateModal(
      context: context,
      mode: widget.mode,
      onAccept: () => _handleRecalculateChoice(true),
      onDecline: () => _handleRecalculateChoice(false),
    );
  }

  void _handleRecalculateChoice(bool shouldRecalculate) {
    if (!mounted) return;

    setState(() {
      _isRecalculateModalShown = false;
    });

    if (shouldRecalculate) {
      _performRouteRecalculation();
    } else {
      setState(() {
        _autoRecalculateEnabled = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '경로 재갱신이 비활성화되었습니다',
            style: TextStyle(fontFamily: "Pretendard"),
          ),
          backgroundColor: Colors.grey[700],
          duration: Duration(seconds: 2),
          action: SnackBarAction(
            label: '다시 활성화',
            textColor: Colors.white,
            onPressed: () {
              if (mounted) {
                setState(() {
                  _autoRecalculateEnabled = true;
                });
              }
            },
          ),
        ),
      );
    }
  }

  void _performRouteRecalculation() {
    if (_currentPosition == null || !mounted) return;

    setState(() {
      _isLoading = true;
      _isPathDisplayed = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '현재 위치에서 새 경로를 검색합니다',
          style: TextStyle(fontFamily: "Pretendard"),
        ),
        backgroundColor: Color(0xFFFB233B),
        duration: Duration(seconds: 2),
      ),
    );

    _navigationController
        .recalculateRoute(_currentPosition!)
        .then((result) {
          final success = result['success'] as bool;
          final newOriginAddress = result['newOriginAddress'] as String;

          _timerManager.createDelayTimer(Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _isPathDisplayed = true;

                if (newOriginAddress.isNotEmpty) {
                  _updatedOriginName = newOriginAddress;
                }
              });

              if (!success) {
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
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isPathDisplayed = true;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('경로 계산 중 오류가 발생했습니다'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        });
  }

  void _showMenuModal() {
    NavigationModals.showMenuModal(
      context: context,
      mode: widget.mode,
      originName: widget.originName,
      destinationName: widget.destinationName,
      remainingDistance: _remainingDistance,
      remainingTime: _remainingTime,
      autoRecalculateEnabled: _autoRecalculateEnabled,
      onAutoRecalculateChanged: (value) {
        setState(() {
          _autoRecalculateEnabled = value;
        });
      },
      onExitPressed: _showExitConfirmationDialog,
    );
  }

  void _showExitConfirmationDialog() {
    NavigationModals.showExitConfirmationDialog(
      context: context,
      mode: widget.mode,
      onConfirm: () {
        Navigator.pop(context);
      },
    );
  }

  void _moveToCurrentLocation() {
    if (_mapController != null) {
      NavigationMapUtils.moveToCurrentLocation(
        _mapController!,
        widget.mode,
        _currentPosition,
      );
    }
  }

  void _setupMapController(NaverMapController controller) {
    _mapController = controller;
    _navigationController.setMapController(controller);

    try {
      NavigationMapUtils.setInitialCameraView(
        controller,
        widget.origin,
        widget.destination,
      );

      controller.setLocationTrackingMode(NLocationTrackingMode.none);

      final locationOverlay = controller.getLocationOverlay();
      locationOverlay.setIsVisible(true);

      if (_currentPosition != null) {
        final initialHeading = _navigationController.getCurrentHeading();
        NavigationMapUtils.updateLocationOverlay(
          controller,
          _currentPosition!,
          widget.mode,
          heading: initialHeading,
        );
      }

      NavigationMapUtils.addDestinationMarker(
        controller,
        widget.destination,
        widget.mode,
      );

      _waitForRouteAndAdjustCamera(controller);

      setState(() {
        _isPathDisplayed = true;
      });
    } catch (e) {
      print('맵 초기화 오류: $e');
    }
  }

  void _waitForRouteAndAdjustCamera(NaverMapController controller) {
    _timerManager.createRouteWaitTimer(Duration(milliseconds: 500), () {
      if (_navigationController.hasPathCoordinates() &&
          _navigationController.hasPathOverlay()) {
        _timerManager.cancelRouteWaitTimer();

        _timerManager.createDelayTimer(Duration(milliseconds: 1000), () {
          if (mounted) {
            NavigationMapUtils.setNavigationCamera(
              controller,
              widget.mode,
              _currentPosition,
              widget.origin,
              _navigationController.getCurrentHeading(),
            );
          }
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _isInForeground = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    _timerManager.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _navigationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color mainColor =
        widget.mode == TransitMode.car ? Color(0xFFFB233B) : Color(0xFF0771EB);

    return Scaffold(
      body: Stack(
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              logoClickEnable: false,
              locationButtonEnable: false,
              nightModeEnable: true,
              scaleBarEnable: false,
              initialCameraPosition: NCameraPosition(
                target: widget.origin,
                tilt: widget.mode == TransitMode.car ? 35.0 : 0.0,
                zoom: widget.mode == TransitMode.car ? 18 : 17,
              ),
              mapType:
                  widget.mode == TransitMode.car
                      ? NMapType.navi
                      : NMapType.basic,
              contentPadding: EdgeInsets.only(bottom: 80),
              zoomGesturesEnable: widget.mode != TransitMode.car,
              tiltGesturesEnable: widget.mode != TransitMode.car,
            ),
            onMapReady: _setupMapController,
          ),

          if (_isLoading)
            Center(child: CircularProgressIndicator(color: mainColor)),

          RouteHeaderWidget(
            originName: widget.originName,
            destinationName: widget.destinationName,
          ),

          if (_currentTurnInstruction != null &&
              !_hasArrived &&
              widget.mode == TransitMode.car)
            TurnByTurnWidget(
              currentInstruction: _currentTurnInstruction!,
              currentRoadName: _currentRoadName,
              mainColor: mainColor,
            ),

          if (_currentTurnInstruction != null &&
              !_hasArrived &&
              _navigationController.getNextInstruction() != null)
            NextTurnWidget(
              nextInstruction: _navigationController.getNextInstruction()!,
            ),

          NavigationControlButtons(
            mainColor: mainColor,
            onMenuPressed: _showMenuModal,
            onLocationPressed: _moveToCurrentLocation,
          ),

          if (widget.mode == TransitMode.car && !_hasArrived)
            SpeedLimitWidget(
              currentSpeed: _currentSpeed,
              speedLimit: _speedLimit,
              currentInstruction: _currentTurnInstruction,
            ),

          NavigationInfoWidget(
            isPathDisplayed: _isPathDisplayed,
            remainingDistance: _remainingDistance,
            remainingTime: _remainingTime,
            mainColor: mainColor,
          ),

          if (widget.mode == TransitMode.car &&
              !_autoRecalculateEnabled &&
              !_hasArrived)
            AutoRecalculateDisabledWidget(
              onRenable: () {
                setState(() {
                  _autoRecalculateEnabled = true;
                });
              },
            ),
        ],
      ),
    );
  }
}
