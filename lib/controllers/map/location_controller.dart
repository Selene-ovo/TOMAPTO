import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

class LocationController {
  // 현재 위치를 저장할 변수
  NLatLng? _currentPosition;

  // 현재 위치 getter
  NLatLng? get currentPosition => _currentPosition;

  // 위치 권한 확인 및 요청 메서드
  Future<bool> checkLocationPermission(BuildContext context) async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        // 권한 거부된 경우 처리
        return false;
      }
    }

    // 위치 서비스가 활성화 되어있는지 확인
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // 위치 서비스 비활성화된 경우 처리
      return false;
    }

    return true;
  }

  // 현재 위치 가져오기
  Future<NLatLng?> getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      _currentPosition = NLatLng(position.latitude, position.longitude);
      print('현재 위치: ${position.latitude}, ${position.longitude}');
      return _currentPosition;
    } catch (e) {
      print('위치 가져오기 실패: $e');
      return null;
    }
  }

  // 서울 시청 좌표 (기본값)
  NLatLng getDefaultLocation() {
    return NLatLng(37.5666805, 126.9784147);
  }

  // 두 좌표 간의 거리 계산 (미터 단위)
  double calculateDistance(NLatLng point1, NLatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }
}
