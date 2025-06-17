import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

/// 교통 관련 전역 상태를 관리하는 Provider 클래스
class TransitProvider extends ChangeNotifier {
  // 출발지 정보
  String _originPlace = '위치 확인 중...';
  NLatLng? _originCoords;

  // 도착지 정보
  String _destinationPlace = '도착지 입력';
  NLatLng? _destinationCoords;

  // 현재 사용자 위치
  NLatLng? _currentUserPosition;
  String? _currentUserAddress;

  // 상태 플래그
  bool _isOriginFromPoi = false;
  bool _isDestinationFromPoi = false;
  bool _hasInitialData = false;

  // Getters
  String get originPlace => _originPlace;
  NLatLng? get originCoords => _originCoords;
  String get destinationPlace => _destinationPlace;
  NLatLng? get destinationCoords => _destinationCoords;
  NLatLng? get currentUserPosition => _currentUserPosition;
  String? get currentUserAddress => _currentUserAddress;
  bool get isOriginFromPoi => _isOriginFromPoi;
  bool get isDestinationFromPoi => _isDestinationFromPoi;
  bool get hasInitialData => _hasInitialData;

  /// 초기 데이터 설정 (앱 시작시 또는 TransitApp 진입시)
  void setInitialData({
    String? initialOriginPlace,
    NLatLng? initialOriginCoords,
    String? initialDestinationPlace,
    NLatLng? initialDestinationCoords,
  }) {
    bool hasChanges = false;

    if (initialOriginPlace != null) {
      _originPlace = initialOriginPlace;
      _originCoords = initialOriginCoords;
      _isOriginFromPoi = initialOriginCoords != null;
      hasChanges = true;
    }

    if (initialDestinationPlace != null &&
        initialDestinationPlace != '도착지 입력') {
      _destinationPlace = initialDestinationPlace;
      _destinationCoords = initialDestinationCoords;
      _isDestinationFromPoi = initialDestinationCoords != null;
      hasChanges = true;
    }

    _hasInitialData = true;

    if (hasChanges) {
      notifyListeners();
    }
  }

  /// 출발지 설정 (POI 또는 검색에서 호출)
  void setOrigin(String place, NLatLng? coords, {bool fromPoi = false}) {
    _originPlace = place;
    _originCoords = coords;
    _isOriginFromPoi = fromPoi;
    notifyListeners();
  }

  /// 도착지 설정 (POI 또는 검색에서 호출)
  void setDestination(String place, NLatLng? coords, {bool fromPoi = false}) {
    _destinationPlace = place;
    _destinationCoords = coords;
    _isDestinationFromPoi = fromPoi;
    notifyListeners();
  }

  /// 현재 사용자 위치 업데이트
  void setCurrentUserLocation(NLatLng position, String? address) {
    _currentUserPosition = position;
    _currentUserAddress = address;

    // 출발지가 설정되지 않은 경우에만 현재 위치로 설정
    if (!_hasInitialData &&
        (_originPlace == '위치 확인 중...' || _originPlace == '출발지 입력')) {
      _originPlace = address ?? '현재 위치';
      _originCoords = position;
      _isOriginFromPoi = false;
    }

    notifyListeners();
  }

  /// 출발지와 도착지 위치 교환
  void swapLocations() {
    final tempPlace = _originPlace;
    final tempCoords = _originCoords;
    final tempFromPoi = _isOriginFromPoi;

    // 도착지가 설정되지 않은 경우 처리
    if (_destinationPlace == '도착지 입력') {
      _originPlace = '출발지 입력';
      _originCoords = null;
      _isOriginFromPoi = false;
    } else {
      _originPlace = _destinationPlace;
      _originCoords = _destinationCoords;
      _isOriginFromPoi = _isDestinationFromPoi;
    }

    // 출발지가 유효하지 않은 경우 처리
    if (_isInvalidLocationState(tempPlace)) {
      _destinationPlace = '도착지 입력';
      _destinationCoords = null;
      _isDestinationFromPoi = false;
    } else {
      _destinationPlace = tempPlace;
      _destinationCoords = tempCoords;
      _isDestinationFromPoi = tempFromPoi;
    }

    notifyListeners();
  }

  /// 현재 위치를 출발지로 설정
  void setCurrentLocationAsOrigin() {
    if (_currentUserPosition != null) {
      _originPlace = _currentUserAddress ?? '현재 위치';
      _originCoords = _currentUserPosition;
      _isOriginFromPoi = false;
      notifyListeners();
    }
  }

  /// 현재 위치를 도착지로 설정
  void setCurrentLocationAsDestination() {
    if (_currentUserPosition != null) {
      _destinationPlace = _currentUserAddress ?? '현재 위치';
      _destinationCoords = _currentUserPosition;
      _isDestinationFromPoi = false;
      notifyListeners();
    }
  }

  /// 출발지 초기화 (검색에서 새로운 출발지 설정시)
  void resetOrigin() {
    if (_currentUserPosition != null && !_isOriginFromPoi) {
      _originPlace = _currentUserAddress ?? '현재 위치';
      _originCoords = _currentUserPosition;
    } else if (!_isOriginFromPoi) {
      _originPlace = '위치 확인 중...';
      _originCoords = null;
    }
    // POI에서 설정된 출발지는 유지
    notifyListeners();
  }

  /// 도착지 초기화
  void resetDestination() {
    if (!_isDestinationFromPoi) {
      _destinationPlace = '도착지 입력';
      _destinationCoords = null;
      notifyListeners();
    }
    // POI에서 설정된 도착지는 유지
  }

  /// 모든 상태 초기화
  void reset() {
    _originPlace = '위치 확인 중...';
    _originCoords = null;
    _destinationPlace = '도착지 입력';
    _destinationCoords = null;
    _isOriginFromPoi = false;
    _isDestinationFromPoi = false;
    _hasInitialData = false;
    notifyListeners();
  }

  /// 검색 결과를 출발지로 설정
  void setSearchResultAsOrigin(String placeName, NLatLng coords) {
    _originPlace = placeName;
    _originCoords = coords;
    _isOriginFromPoi = false;
    notifyListeners();
  }

  /// 검색 결과를 도착지로 설정
  void setSearchResultAsDestination(String placeName, NLatLng coords) {
    _destinationPlace = placeName;
    _destinationCoords = coords;
    _isDestinationFromPoi = false;
    notifyListeners();
  }

  /// POI에서 출발지로 설정
  void setPoiAsOrigin(String placeName, NLatLng coords) {
    _originPlace = placeName;
    _originCoords = coords;
    _isOriginFromPoi = true;
    notifyListeners();
  }

  /// POI에서 도착지로 설정
  void setPoiAsDestination(String placeName, NLatLng coords) {
    _destinationPlace = placeName;
    _destinationCoords = coords;
    _isDestinationFromPoi = true;
    notifyListeners();
  }

  /// 출발지가 현재 위치인지 확인
  bool get isOriginCurrentLocation {
    return _originPlace == '현재 위치' ||
        (_currentUserAddress != null && _originPlace == _currentUserAddress);
  }

  /// 도착지가 현재 위치인지 확인
  bool get isDestinationCurrentLocation {
    return _destinationPlace == '현재 위치' ||
        (_currentUserAddress != null &&
            _destinationPlace == _currentUserAddress);
  }

  /// 출발지와 도착지가 모두 설정되었는지 확인
  bool get hasValidRoute {
    return _originCoords != null &&
        _destinationCoords != null &&
        !_isInvalidLocationState(_originPlace) &&
        _destinationPlace != '도착지 입력';
  }

  /// 현재 상태를 Map으로 반환 (디버깅용)
  Map<String, dynamic> getStateInfo() {
    return {
      'originPlace': _originPlace,
      'originCoords': _originCoords?.toString(),
      'destinationPlace': _destinationPlace,
      'destinationCoords': _destinationCoords?.toString(),
      'isOriginFromPoi': _isOriginFromPoi,
      'isDestinationFromPoi': _isDestinationFromPoi,
      'hasValidRoute': hasValidRoute,
      'currentUserPosition': _currentUserPosition?.toString(),
      'currentUserAddress': _currentUserAddress,
    };
  }

  /// 위치 상태가 유효하지 않은지 확인하는 헬퍼 메서드
  bool _isInvalidLocationState(String place) {
    return place == '위치 확인 중...' ||
        place == '위치 권한 없음' ||
        place == '위치 확인 실패' ||
        place == '출발지 입력';
  }

  /// TransitApp에서 사용할 유효한 출발지 반환
  String? getValidOriginPlace() {
    return !_isInvalidLocationState(_originPlace) ? _originPlace : null;
  }

  /// TransitApp에서 사용할 유효한 도착지 반환
  String? getValidDestinationPlace() {
    return _destinationPlace != '도착지 입력' ? _destinationPlace : null;
  }
}
