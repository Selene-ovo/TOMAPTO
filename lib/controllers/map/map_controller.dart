import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:tomapto/controllers/map/poi_controller.dart';
import 'package:tomapto/widgets/poi_widget.dart';

class MapController {
  NaverMapController? _mapController;
  double _currentZoom = 18.0;
  bool _firstLocationUpdate = true;
  double _currentBearing = 0.0;

  // 실시간 위치 추적 관련 추가
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isRealTimeTrackingEnabled = false;

  // POI 관련 컨트롤러
  final POIController _poiController = POIController();

  // 위치 관련 상태
  NLatLng? _currentPosition;
  String _currentLocationAddress = "현재 위치";

  // POI 관련 상태
  ClickedLocationInfo? _clickedLocationInfo;
  bool _showLocationInfo = false;
  bool _isLoadingLocation = false;
  final Set<NMarker> _locationMarkers = {};

  // 콜백 함수들
  Function(bool)? onLoadingChanged;
  Function(bool, ClickedLocationInfo?)? onLocationInfoChanged;
  Function(String)? onLocationAddressChanged;
  Function(NLatLng?)? onCurrentPositionChanged;
  Function(String)? onShowSnackBar;

  // Getters
  NaverMapController? get controller => _mapController;
  double get currentZoom => _currentZoom;
  NLatLng? get currentPosition => _currentPosition;
  String get currentLocationAddress => _currentLocationAddress;
  ClickedLocationInfo? get clickedLocationInfo => _clickedLocationInfo;
  bool get showLocationInfo => _showLocationInfo;
  bool get isLoadingLocation => _isLoadingLocation;
  bool get isRealTimeTrackingEnabled => _isRealTimeTrackingEnabled;

  // 맵 컨트롤러 설정
  void setMapController(NaverMapController controller) {
    _mapController = controller;

    if (_mapController != null) {
      try {
        _mapController!.setLocationTrackingMode(NLocationTrackingMode.noFollow);
        _configureLocationOverlay();
      } catch (e) {
        print('위치 추적 모드 설정 실패: $e');
      }
    }
  }

  // 위치 오버레이 스타일 설정
  void _configureLocationOverlay() {
    if (_mapController != null) {
      try {
        final locationOverlay = _mapController!.getLocationOverlay();
        locationOverlay.setIsVisible(true);
        locationOverlay.setCircleRadius(0);
        locationOverlay.setSubIcon(NLocationOverlay.defaultSubIcon);
      } catch (e) {
        print('위치 오버레이 설정 실패: $e');
      }
    }
  }

  // 실시간 위치 추적 시작
  Future<void> startRealTimeLocationTracking() async {
    // 권한 확인
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        onShowSnackBar?.call('위치 권한이 필요합니다.');
        return;
      }
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      onShowSnackBar?.call('위치 서비스를 활성화해주세요.');
      return;
    }

    try {
      // 기존 스트림이 있으면 정지
      await stopRealTimeLocationTracking();

      // 위치 스트림 설정
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5, // 5미터 이상 이동시 업데이트
      );

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _handleRealTimeLocationUpdate(position);
        },
        onError: (error) {
          print('실시간 위치 추적 오류: $error');
          onShowSnackBar?.call('위치 추적 중 오류가 발생했습니다: $error');
        },
      );

      _isRealTimeTrackingEnabled = true;
      print('실시간 위치 추적 시작됨');

      // 초기 위치도 한번 가져오기
      await getCurrentLocation();
    } catch (e) {
      print('실시간 위치 추적 시작 실패: $e');
      onShowSnackBar?.call('실시간 위치 추적을 시작할 수 없습니다: $e');
    }
  }

  // 실시간 위치 추적 정지
  Future<void> stopRealTimeLocationTracking() async {
    if (_positionStreamSubscription != null) {
      await _positionStreamSubscription!.cancel();
      _positionStreamSubscription = null;
    }
    _isRealTimeTrackingEnabled = false;
    print('실시간 위치 추적 정지됨');
  }

  // 실시간 위치 업데이트 처리
  void _handleRealTimeLocationUpdate(Position position) {
    final newPosition = NLatLng(position.latitude, position.longitude);

    print('실시간 위치 업데이트: ${position.latitude}, ${position.longitude}');

    _currentPosition = newPosition;
    onCurrentPositionChanged?.call(_currentPosition);

    // 지도의 위치 오버레이 업데이트
    if (_mapController != null) {
      try {
        final locationOverlay = _mapController!.getLocationOverlay();
        locationOverlay.setPosition(newPosition);

        // 첫 번째 위치 업데이트시에만 카메라 이동
        if (_firstLocationUpdate) {
          moveCamera(newPosition, _currentZoom);
          _firstLocationUpdate = false;
        }
      } catch (e) {
        print('위치 오버레이 업데이트 실패: $e');
      }
    }
  }

  // 현재 위치 가져오기 (일회성)
  Future<void> getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        onShowSnackBar?.call('위치 권한이 필요합니다.');
        return;
      }
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      onShowSnackBar?.call('위치 서비스를 활성화해주세요.');
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      _currentPosition = NLatLng(position.latitude, position.longitude);
      onCurrentPositionChanged?.call(_currentPosition);

      print('현재 위치: ${position.latitude}, ${position.longitude}');

      if (_mapController != null && _currentPosition != null) {
        final currentCameraPosition = await getCurrentCameraPosition();
        double currentZoom = currentCameraPosition?.zoom ?? _currentZoom;

        await moveCamera(_currentPosition!, currentZoom);

        try {
          _mapController!.setLocationTrackingMode(NLocationTrackingMode.follow);

          // 위치 오버레이도 업데이트
          final locationOverlay = _mapController!.getLocationOverlay();
          locationOverlay.setPosition(_currentPosition!);
          locationOverlay.setIsVisible(true);
          locationOverlay.setCircleRadius(0);
          locationOverlay.setSubIcon(NLocationOverlay.defaultSubIcon);

          print('위치 추적 모드 설정 완료 (줌 레벨 ${currentZoom} 유지)');
        } catch (e) {
          print('위치 추적 모드 설정 실패: $e');
        }
      }
    } catch (e) {
      print('위치 가져오기 실패: $e');
      onShowSnackBar?.call('위치 가져오기 실패: $e');
    }
  }

  // 위치 업데이트
  Future<void> updateLocation(NLatLng position) async {
    if (_mapController == null) return;

    try {
      if (_firstLocationUpdate) {
        await moveCamera(position, 17);
        _firstLocationUpdate = false;
      }
    } catch (e) {
      print('위치 업데이트 실패: $e');
    }
  }

  // 방향(베어링) 업데이트
  void updateBearing(double bearing) {
    if (_mapController == null) return;

    _currentBearing = bearing;

    try {
      while (_currentBearing < 0) {
        _currentBearing += 360;
      }
      while (_currentBearing >= 360) {
        _currentBearing -= 360;
      }
    } catch (e) {
      print('방향 업데이트 실패: $e');
    }
  }

  // 위치와 방향을 함께 업데이트
  Future<void> updateLocationAndBearing(
    NLatLng position,
    double bearing,
  ) async {
    if (_mapController == null) return;

    try {
      updateBearing(bearing);
      await updateLocation(position);
    } catch (e) {
      print('위치 및 방향 업데이트 실패: $e');
    }
  }

  // 줌 레벨 설정
  void setZoomLevel(double zoom) {
    _currentZoom = zoom;
  }

  // 카메라 이동
  Future<void> moveCamera(NLatLng target, double zoom) async {
    if (_mapController != null) {
      final cameraUpdate = NCameraUpdate.withParams(target: target, zoom: zoom);
      cameraUpdate.setAnimation(animation: NCameraAnimation.none);
      await _mapController!.updateCamera(cameraUpdate);
      _currentZoom = zoom;
    }
  }

  // 현재 카메라 위치 가져오기
  Future<NCameraPosition?> getCurrentCameraPosition() async {
    if (_mapController != null) {
      try {
        return await _mapController!.getCameraPosition();
      } catch (e) {
        print('카메라 위치 가져오기 실패: $e');
        return null;
      }
    }
    return null;
  }

  // 현재 위치로 이동
  Future<void> moveToCurrentLocation(NLatLng position) async {
    if (_mapController == null) return;

    try {
      await moveCamera(position, _currentZoom);
    } catch (e) {
      print('현재 위치로 이동 실패: $e');
    }
  }

  // 마커 추가
  void addMarker(NMarker marker) {
    if (_mapController != null) {
      try {
        _mapController!.addOverlay(marker);
      } catch (e) {
        print('마커 추가 실패: $e');
      }
    }
  }

  // 마커 제거
  void removeMarker(NMarker marker) {
    if (_mapController != null) {
      try {
        _mapController!.deleteOverlay(marker.info);
      } catch (e) {
        print('마커 제거 실패: $e');
      }
    }
  }

  // 마커 모두 제거
  void removeAllMarkers(Set<NMarker> markers) {
    if (_mapController != null) {
      for (final marker in markers) {
        try {
          _mapController!.deleteOverlay(marker.info);
        } catch (e) {
          print('마커 제거 실패: $e');
        }
      }
    }
  }

  // 위치 마커 추가
  void addLocationMarker(NLatLng position) {
    try {
      if (_mapController != null) {
        final marker = NMarker(
          id: 'location_marker_${DateTime.now().millisecondsSinceEpoch}',
          position: position,
        );

        marker.setIconTintColor(Color(0xFF000000));
        addMarker(marker);
        _locationMarkers.add(marker);
        print('위치 마커 추가 완료');
      }
    } catch (e) {
      print('위치 마커 추가 실패: $e');
    }
  }

  // 위치 마커들 제거
  void clearLocationMarkers() {
    try {
      if (_mapController != null && _locationMarkers.isNotEmpty) {
        removeAllMarkers(_locationMarkers);
        _locationMarkers.clear();
        print('위치 마커들 제거 완료');
      }
    } catch (e) {
      print('위치 마커들 제거 실패: $e');
    }
  }

  // 위치 정보 패널 닫기
  void closeLocationInfo() {
    _showLocationInfo = false;
    _clickedLocationInfo = null;
    onLocationInfoChanged?.call(false, null);
    clearLocationMarkers();
  }

  // 심볼에서 상가 정보 가져오기
  Future<void> getBusinessInfoFromSymbol(NSymbolInfo symbolInfo) async {
    print('상가 심볼 터치됨: ${symbolInfo.caption}');

    if (_isLoadingLocation) {
      print('이미 위치 정보 조회 중입니다.');
      return;
    }

    _isLoadingLocation = true;
    _showLocationInfo = false;
    onLoadingChanged?.call(true);
    onLocationInfoChanged?.call(false, null);

    try {
      clearLocationMarkers();
      print('심볼 정보로 상가 정보 생성 중...');

      final businessInfo = await _poiController.createBusinessInfoFromSymbol(
        symbolInfo.caption,
        symbolInfo.position,
        _currentPosition,
      );

      _clickedLocationInfo = businessInfo;
      _showLocationInfo = true;
      onLocationInfoChanged?.call(true, businessInfo);

      addLocationMarker(symbolInfo.position);
      print('상가 정보 표시 완료: ${businessInfo.locationName}');

      // 백그라운드에서 주소 정보 업데이트
      _updateAddressInBackground(symbolInfo.position);
    } catch (e) {
      print('상가 정보 조회 오류: $e');
      onShowSnackBar?.call('상가 정보를 가져오는 중 오류가 발생했습니다.');
    } finally {
      _isLoadingLocation = false;
      onLoadingChanged?.call(false);
    }
  }

  // 백그라운드에서 주소 업데이트
  Future<void> _updateAddressInBackground(NLatLng position) async {
    try {
      final addressInfo = await _poiController.getAddressFromCoords(position);

      if (_showLocationInfo && _clickedLocationInfo != null) {
        _clickedLocationInfo = ClickedLocationInfo(
          address: addressInfo,
          locationName: _clickedLocationInfo!.locationName,
          category: _clickedLocationInfo!.category,
          position: _clickedLocationInfo!.position,
          distanceFromUser: _clickedLocationInfo!.distanceFromUser,
          estimatedTime: _clickedLocationInfo!.estimatedTime,
          phoneNumber: _clickedLocationInfo!.phoneNumber,
          link: _clickedLocationInfo!.link,
          description: _clickedLocationInfo!.description,
        );
        onLocationInfoChanged?.call(true, _clickedLocationInfo);
        print('주소 정보 업데이트 완료: $addressInfo');
      }
    } catch (e) {
      print('주소 정보 업데이트 실패: $e');
    }
  }

  // 카메라 업데이트
  void updateCamera(NCameraUpdate nCameraUpdate) {
    if (_mapController != null) {
      _mapController!.updateCamera(nCameraUpdate);
    }
  }

  // 카메라 아이들 상태에서 줌 레벨 업데이트
  Future<void> handleCameraIdle() async {
    if (_mapController != null) {
      final cameraPosition = await getCurrentCameraPosition();
      if (cameraPosition != null) {
        double zoom = cameraPosition.zoom;
        setZoomLevel(zoom);
        print('줌 레벨 업데이트됨: $zoom');
      }
    }
  }

  // 컨트롤러 해제
  void dispose() {
    // 실시간 위치 추적 정지
    stopRealTimeLocationTracking();
    _mapController = null;
  }
}
