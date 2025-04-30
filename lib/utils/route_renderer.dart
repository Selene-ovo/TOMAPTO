// 경로 렌더링을 위한 유틸리티 클래스
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

class RouteRenderer {
  // 지도에 경로 그리기
  static NPathOverlay createPathOverlay(
    String id,
    List<NLatLng> coordinates, {
    Color color = Colors.blue,
    double width = 5.0,
    bool patternImage = false,
    bool isNavigationMode = false,
  }) {
    // 경로가 너무 짧으면 처리
    if (coordinates.length < 2) {
      print('경로 좌표가 너무 적습니다. 최소 2개 이상 필요합니다.');
      return NPathOverlay(
        id: id,
        coords: [
          coordinates.first,
          NLatLng(
            coordinates.first.latitude + 0.0001,
            coordinates.first.longitude + 0.0001,
          ),
        ],
        color: color,
        width: width,
        outlineColor: Colors.white.withOpacity(0.3),
        outlineWidth: width + 2.0,
      );
    }

    return NPathOverlay(
      id: id,
      coords: coordinates,
      color: color,
      width: width,
      patternImage:
          patternImage
              ? NOverlayImage.fromAssetImage('assets/icons/path_pattern.png')
              : null,
      outlineColor: Colors.white.withOpacity(0.3),
      outlineWidth: width + 2.0,
    );
  }

  // 출발지 마커 생성
  static NMarker createStartMarker(
    NLatLng position, {
    String title = '출발지',
    bool animated = false,
  }) {
    final marker = NMarker(id: 'start_marker', position: position);

    // 색상 변경
    marker.setIconTintColor(Color(0xFFFB233B));

    // 캡션 설정
    marker.setCaption(
      NOverlayCaption(
        text: title,
        textSize: 14,
        color: Colors.black,
        haloColor: Colors.white,
      ),
    );

    // animated 파라미터는 있지만 네이버 지도 API에서 지원하지 않을 수 있어서
    // 그냥 무시하고 마커 반환

    return marker;
  }

  // 도착지 마커 생성
  static NMarker createDestinationMarker(
    NLatLng position, {
    String title = '도착지',
    bool animated = false,
  }) {
    final marker = NMarker(id: 'destination_marker', position: position);

    // 색상 변경
    marker.setIconTintColor(Colors.blue);

    // 캡션 설정
    marker.setCaption(
      NOverlayCaption(
        text: title,
        textSize: 14,
        color: Colors.black,
        haloColor: Colors.white,
      ),
    );

    // animated 파라미터는 있지만 네이버 지도 API에서 지원하지 않을 수 있어서
    // 그냥 무시하고 마커 반환

    return marker;
  }

  // 현재 위치 마커 생성 (내비게이션에서 사용)
  static NMarker createCurrentLocationMarker(
    NLatLng position, {
    double heading = 0.0,
  }) {
    // 현재 위치 마커 생성
    final marker = NMarker(id: 'current_location_marker', position: position);

    // 마커 방향 설정 (나침반 방향으로)
    marker.setAngle(heading);

    // 마커 색상 설정 (파란색)
    marker.setIconTintColor(Colors.blue);

    return marker;
  }

  // 진행 경로 오버레이 생성 (내비게이션에서 사용)
  static List<NPathOverlay> createProgressPathOverlay(
    List<NLatLng> fullPath,
    int currentIndex,
  ) {
    if (fullPath.length < 2 || currentIndex >= fullPath.length) {
      return [];
    }

    // 이미 지나간 경로 (초록색)
    final List<NLatLng> passedCoords = fullPath.sublist(0, currentIndex + 1);
    final passedPath = NPathOverlay(
      id: 'passed_path',
      coords: passedCoords,
      color: Colors.green,
      width: 6.0,
      outlineColor: Colors.white.withOpacity(0.3),
      outlineWidth: 8.0,
    );

    // 아직 지나가지 않은 경로 (파란색/빨간색)
    if (currentIndex < fullPath.length - 1) {
      final List<NLatLng> remainingCoords = fullPath.sublist(currentIndex);
      final remainingPath = NPathOverlay(
        id: 'remaining_path',
        coords: remainingCoords,
        color: Colors.blue,
        width: 6.0,
        outlineColor: Colors.white.withOpacity(0.3),
        outlineWidth: 8.0,
      );

      return [passedPath, remainingPath];
    }

    return [passedPath];
  }

  // 시간을 사람이 읽기 쉬운 형태로 변환 (초 -> 분:초)
  static String formatDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds초';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '$minutes분 ${remainingSeconds > 0 ? '$remainingSeconds초' : ''}';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '$hours시간 ${minutes > 0 ? '$minutes분' : ''}';
    }
  }

  // 남은 시간 계산 (도착 예정 시간 포맷)
  static String getArrivalTime(int durationSeconds) {
    final now = DateTime.now();
    final arrival = now.add(Duration(seconds: durationSeconds));

    // 24시간 형식으로 시간 포맷팅
    final hour = arrival.hour.toString().padLeft(2, '0');
    final minute = arrival.minute.toString().padLeft(2, '0');

    return '$hour:$minute 도착 예정';
  }

  // 거리를 사람이 읽기 쉬운 형태로 변환 (미터 -> km 또는 m)
  static String formatDistance(int meters) {
    if (meters < 1000) {
      return '$meters m';
    } else {
      final km = (meters / 1000).toStringAsFixed(1);
      return '$km km';
    }
  }

  // 남은 거리에 따른 안내 메시지 생성
  static String getGuidanceMessage(int remainingMeters, String roadName) {
    if (remainingMeters <= 50) {
      return '곧 목적지에 도착합니다.';
    } else if (remainingMeters <= 100) {
      return '100m 앞에 목적지가 있습니다.';
    } else if (remainingMeters <= 300) {
      return '$roadName에서 ${formatDistance(remainingMeters)} 더 이동하세요.';
    } else {
      return '$roadName 진행 중 (${formatDistance(remainingMeters)} 남음)';
    }
  }

  // 요금 포맷팅
  static String formatFare(int fare) {
    // 천 단위 쉼표 추가
    final String formattedFare = fare.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    return '₩$formattedFare';
  }
}
