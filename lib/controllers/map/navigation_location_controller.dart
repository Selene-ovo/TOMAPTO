import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tomapto/controllers/map/transit_map_controller.dart';
import 'package:tomapto/services/korea_traffic_api_service.dart';

/// 위치 추적 및 속도 관련 기능을 담당하는 컨트롤러
class NavigationLocationController {
  final TransitMode mode;
  final KoreaTrafficApiService _koreaTrafficService = KoreaTrafficApiService();

  // 위치 추적 관련 변수
  StreamSubscription<Position>? _positionStreamSubscription;
  NLatLng? _currentPosition;
  double _currentSpeed = 0;
  double _currentHeading = 0.0;
  double _lastHeading = 0.0;
  static const double _headingThreshold = 10.0;

  // 속도 제한 관련 변수
  int _actualSpeedLimit = 50;
  DateTime? _lastSpeedLimitUpdate;
  NLatLng? _lastSpeedLimitPosition;

  // 스트림 컨트롤러
  final StreamController<NLatLng> _locationController =
      StreamController<NLatLng>.broadcast();
  final StreamController<int> _speedLimitController =
      StreamController<int>.broadcast();

  // 스트림 getter
  Stream<NLatLng> get locationStream => _locationController.stream;
  Stream<int> get speedLimitStream => _speedLimitController.stream;

  NavigationLocationController(this.mode);

  // 현재 위치 관련 getter
  NLatLng? get currentPosition => _currentPosition;
  double get currentSpeed => _currentSpeed;
  double get currentHeading => _currentHeading;
  int get speedLimit => _actualSpeedLimit;

  // 위치 설정
  void setCurrentPosition(NLatLng position) {
    _currentPosition = position;
  }

  // 실제 위치 추적 시작
  void startRealLocationTracking({
    required Function(NLatLng) onLocationUpdate,
    required Function() onArrival,
  }) {
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      final newPosition = NLatLng(position.latitude, position.longitude);

      _currentPosition = newPosition;
      _currentSpeed = (position.speed * 3.6).clamp(0, 200);
      _updateHeading(position.heading);

      _locationController.add(newPosition);
      onLocationUpdate(newPosition);

      if (mode == TransitMode.car) {
        _updateActualSpeedLimit(newPosition);
      }
    });
  }

  // 방향 업데이트
  void _updateHeading(double heading) {
    if (!heading.isNaN) {
      double headingDiff = (heading - _lastHeading).abs();
      if (headingDiff > 180) {
        headingDiff = 360 - headingDiff;
      }

      if (headingDiff > _headingThreshold) {
        _currentHeading = heading;
        _lastHeading = heading;
      }
    }
  }

  // 속도 제한 업데이트
  Future<void> _updateActualSpeedLimit(NLatLng position) async {
    final now = DateTime.now();
    bool shouldUpdate = false;

    if (_lastSpeedLimitUpdate == null) {
      shouldUpdate = true;
    } else {
      final timeDiff = now.difference(_lastSpeedLimitUpdate!).inSeconds;
      double distanceDiff = 0;

      if (_lastSpeedLimitPosition != null) {
        distanceDiff = _calculateDistance(_lastSpeedLimitPosition!, position);
      }

      if (timeDiff >= 30 || distanceDiff >= 200) {
        shouldUpdate = true;
      }
    }

    if (!shouldUpdate) return;

    try {
      final speedLimit = await _koreaTrafficService.getSpeedLimitAtPosition(
        position,
      );

      if (speedLimit != _actualSpeedLimit) {
        _actualSpeedLimit = speedLimit;
        _speedLimitController.add(_actualSpeedLimit);
      }

      _lastSpeedLimitUpdate = now;
      _lastSpeedLimitPosition = position;
    } catch (e) {
      print('속도 제한 조회 오류: $e');
    }
  }

  // 거리 계산 헬퍼 메서드
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

  void dispose() {
    _positionStreamSubscription?.cancel();
    _locationController.close();
    _speedLimitController.close();
  }
}
