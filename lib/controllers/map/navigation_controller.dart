import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:tomapto/controllers/map/transit_map_controller.dart';
import 'package:tomapto/controllers/route/route_main_controller.dart';
import 'package:tomapto/controllers/map/navigation_location_controller.dart';
import 'package:tomapto/controllers/map/navigation_route_controller.dart';
import 'package:tomapto/controllers/map/navigation_turn_controller.dart';

class NavigationController {
  final TransitMode mode;
  final NLatLng _origin;
  final NLatLng _destination;

  late final NavigationLocationController _locationController;
  late final NavigationRouteController _routeController;
  late final NavigationTurnController _turnController;

  NaverMapController? _mapController;

  NPathOverlay? _routePathOverlay;
  NMarker? _destinationMarker;

  final StreamController<Map<String, dynamic>> _navigationInfoController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<void> _arrivalController =
      StreamController<void>.broadcast();

  bool _isRouteDataReady = false;
  bool _isTurnDataInitialized = false;

  Stream<Map<String, dynamic>> get navigationInfoStream =>
      _navigationInfoController.stream;
  Stream<NLatLng> get locationStream => _locationController.locationStream;
  Stream<bool> get routeDeviationStream =>
      _routeController.routeDeviationStream;
  Stream<void> get arrivalStream => _arrivalController.stream;
  Stream<Map<String, dynamic>> get turnByTurnStream =>
      _turnController.turnByTurnStream;
  Stream<int> get speedLimitStream => _locationController.speedLimitStream;

  NavigationController(this.mode, this._origin, this._destination) {
    _initializeControllers();
  }

  void _initializeControllers() {
    _locationController = NavigationLocationController(mode);
    _routeController = NavigationRouteController(mode, _origin, _destination);
    _turnController = NavigationTurnController(mode);

    _locationController.setCurrentPosition(_origin);
    _setupStreamListeners();
    _waitForRouteDataAndInitializeTurns();
  }

  void _waitForRouteDataAndInitializeTurns() {
    Timer.periodic(Duration(milliseconds: 200), (timer) {
      if (_routeController.hasPathCoordinates && !_isRouteDataReady) {
        _isRouteDataReady = true;
        timer.cancel();

        _initializeTurnByTurnData();
      }

      if (timer.tick > 75) {
        timer.cancel();
        _initializeTurnByTurnData();
      }
    });
  }

  void _initializeTurnByTurnData() {
    if (_isTurnDataInitialized) return;
    _isTurnDataInitialized = true;

    if (mode == TransitMode.car) {
      final turnInstructions = _routeController.getTurnInstructions();

      if (turnInstructions.isNotEmpty) {
        _turnController.setApiTurnInstructions(
          turnInstructions,
          _routeController.pathCoordinates,
        );
      }
    }
  }

  void _setupStreamListeners() {
    _locationController.locationStream.listen((position) {
      _handleLocationUpdate(position);
    });

    _routeController.routeDeviationStream.listen((isDeviated) {
      // UI에서 처리하도록 그대로 전달
    });

    _turnController.turnByTurnStream.listen((instruction) {
      // 턴바이턴 정보 업데이트 처리
    });
  }

  void _handleLocationUpdate(NLatLng position) {
    _routeController.updateCurrentSection(position);
    _routeController.handleRouteDeviation(position);
    _turnController.updateTurnByTurnInstruction(position);

    final remainingDistance = _calculateDistance(position, _destination);

    if (remainingDistance < 100) {
      _navigationInfoController.add({
        'instruction': '목적지에 도착했습니다',
        'distance': '0m',
        'timeRemaining': '0분',
      });
      _arrivalController.add(null);
      return;
    }

    final instruction = _getNavigationInstruction(position);
    final accurateRemainingTime = _routeController.getAccurateRemainingTime(
      position,
    );

    _navigationInfoController.add({
      'instruction': instruction,
      'distance': _formatDistance(remainingDistance.round()),
      'timeRemaining': accurateRemainingTime,
    });

    updateCurrentLocationMarker(position, _locationController.currentHeading);
  }

  String _getNavigationInstruction(NLatLng position) {
    if (_routeController.pathCoordinates.isEmpty) return '경로 안내 준비 중...';

    final currentInstruction = _turnController.currentInstruction;
    if (currentInstruction != null) {
      final instructionPoint = currentInstruction['point'] as NLatLng;
      final distance = _calculateDistance(position, instructionPoint);

      if (distance <= 500) {
        return currentInstruction['direction'] as String;
      }
    }

    return '직진하세요';
  }

  void setMapController(NaverMapController controller) {
    _mapController = controller;

    try {
      final locationOverlay = controller.getLocationOverlay();
      locationOverlay.setIsVisible(true);

      if (_locationController.currentPosition != null) {
        locationOverlay.setPosition(_locationController.currentPosition!);
        if (_locationController.currentHeading != 0.0) {
          locationOverlay.setBearing(_locationController.currentHeading);
        }
      }
    } catch (e) {
      print('위치 오버레이 초기 설정 오류: $e');
    }

    if (_routeController.hasPathCoordinates) {
      displayPathOverlay(_routeController.pathCoordinates);
    }
  }

  void startRealLocationTracking() {
    _locationController.startRealLocationTracking(
      onLocationUpdate: (position) {
        // 이미 스트림 리스너에서 처리됨
      },
      onArrival: () {
        _arrivalController.add(null);
      },
    );
  }

  Future<Map<String, dynamic>> recalculateRoute(NLatLng newOrigin) async {
    if (_mapController == null) {
      return {'success': false, 'newOriginAddress': ''};
    }

    if (_routePathOverlay != null) {
      try {
        _mapController!.deleteOverlay(_routePathOverlay!.info);
        _routePathOverlay = null;
      } catch (e) {
        print('기존 경로선 제거 중 오류: $e');
      }
    }

    final result = await _routeController.recalculateRoute(newOrigin);

    if (result['success'] == true) {
      displayPathOverlay(_routeController.pathCoordinates);

      if (mode == TransitMode.car) {
        final turnInstructions = _routeController.getTurnInstructions();
        if (turnInstructions.isNotEmpty) {
          _turnController.setApiTurnInstructions(
            turnInstructions,
            _routeController.pathCoordinates,
          );
        }
      }

      if (_routeController.pathCoordinates.length >= 2) {
        final bounds = _calculateBounds(_routeController.pathCoordinates);
        _mapController!.updateCamera(
          NCameraUpdate.fitBounds(bounds, padding: EdgeInsets.all(64)),
        );
      }
    }

    return result;
  }

  void displayPathOverlay(List<NLatLng> coordinates) {
    if (_mapController == null || coordinates.isEmpty) return;

    clearPathOverlays();

    try {
      Color pathColor =
          mode == TransitMode.car ? Color(0xFFFB233B) : Color(0xFF0771EB);
      Color outlineColor =
          mode == TransitMode.car ? Color(0xFFB11829) : Color(0xFF0353AE);

      _routePathOverlay = NPathOverlay(
        id: 'navigation_route_${DateTime.now().millisecondsSinceEpoch}',
        coords: coordinates,
        width: 12.0,
        color: pathColor,
        outlineWidth: 5.0,
        outlineColor: outlineColor,
        patternImage: NOverlayImage.fromAssetImage(
          'assets/icons/arrow_icon.png',
        ),
        patternInterval: 20,
        isHideCollidedCaptions: false,
        isHideCollidedMarkers: false,
        isHideCollidedSymbols: false,
      );

      _mapController!.addOverlay(_routePathOverlay!);

      final markerImage = NOverlayImage.fromAssetImage(
        'assets/icons/end_marker.png',
      );
      _destinationMarker = NMarker(
        id: 'navigation_end_marker',
        position: _destination,
        icon: markerImage,
        size: const Size(40, 50),
        anchor: const NPoint(0.5, 1.0),
        iconTintColor:
            mode == TransitMode.car ? Color(0xFFFB233B) : Color(0xFF0771EB),
      );

      _mapController!.addOverlay(_destinationMarker!);
    } catch (e) {
      print('경로선 생성/추가 오류: $e');
    }
  }

  void clearPathOverlays() {
    if (_mapController == null) return;

    try {
      if (_routePathOverlay != null) {
        _mapController!.deleteOverlay(_routePathOverlay!.info);
        _routePathOverlay = null;
      }

      if (_destinationMarker != null) {
        _mapController!.deleteOverlay(_destinationMarker!.info);
        _destinationMarker = null;
      }
    } catch (e) {
      print('오버레이 제거 중 오류: $e');
    }
  }

  void updateCurrentLocationMarker(NLatLng position, double? heading) {
    if (_mapController == null) return;

    try {
      final locationOverlay = _mapController!.getLocationOverlay();
      locationOverlay.setPosition(position);

      if (heading != null && !heading.isNaN) {
        locationOverlay.setBearing(heading);
      }

      locationOverlay.setIsVisible(true);

      _mapController!.setLocationTrackingMode(
        mode == TransitMode.car
            ? NLocationTrackingMode.face
            : NLocationTrackingMode.follow,
      );
    } catch (e) {
      print('위치 오버레이 업데이트 오류: $e');
    }
  }

  bool hasPathCoordinates() => _routeController.hasPathCoordinates;
  bool hasPathOverlay() => _routePathOverlay != null;

  double getCurrentSpeed() => _locationController.currentSpeed;
  int getSpeedLimit() => _locationController.speedLimit;
  double getCurrentHeading() => _locationController.currentHeading;
  Map<String, dynamic>? getCurrentInstruction() =>
      _turnController.currentInstruction;
  Map<String, dynamic>? getNextInstruction() => _turnController.nextInstruction;
  String getCurrentRoadName(NLatLng position) =>
      _routeController.getCurrentRoadName(position);

  NLatLngBounds _calculateBounds(List<NLatLng> coordinates) {
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (var coord in coordinates) {
      if (coord.latitude < minLat) minLat = coord.latitude;
      if (coord.latitude > maxLat) maxLat = coord.latitude;
      if (coord.longitude < minLng) minLng = coord.longitude;
      if (coord.longitude > maxLng) maxLng = coord.longitude;
    }

    return NLatLngBounds(
      southWest: NLatLng(minLat, minLng),
      northEast: NLatLng(maxLat, maxLng),
    );
  }

  double _calculateDistance(NLatLng point1, NLatLng point2) {
    const double earthRadius = 6371000;
    final double lat1 = point1.latitude * (pi / 180);
    final double lat2 = point2.latitude * (pi / 180);
    final double dLat = (point2.latitude - point1.latitude) * (pi / 180);
    final double dLon = (point2.longitude - point1.longitude) * (pi / 180);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  String _formatDistance(int meters) {
    if (meters < 1000) {
      return '${meters}m';
    } else {
      double km = meters / 1000.0;
      return '${km.toStringAsFixed(1)}km';
    }
  }

  void dispose() {
    _navigationInfoController.close();
    _arrivalController.close();
    _locationController.dispose();
    _routeController.dispose();
    _turnController.dispose();
  }
}
