import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:tomapto/controllers/map/transit_map_controller.dart';

class NavigationMapUtils {
  static void setInitialCameraView(
    NaverMapController controller,
    NLatLng origin,
    NLatLng destination,
  ) {
    final bounds = calculateRouteBounds(origin, destination);
    controller.updateCamera(
      NCameraUpdate.fitBounds(bounds, padding: EdgeInsets.all(80)),
    );
  }

  static void addDestinationMarker(
    NaverMapController controller,
    NLatLng destination,
    TransitMode mode,
  ) {
    final markerImage = NOverlayImage.fromAssetImage(
      'assets/icons/end_marker.png',
    );

    final destinationMarker = NMarker(
      id: 'destination_marker',
      position: destination,
      icon: markerImage,
      size: const Size(40, 50),
      anchor: const NPoint(0.5, 1.0),
      iconTintColor:
          mode == TransitMode.car ? Color(0xFFFF001C) : Color(0xFF0077FF),
    );

    controller.addOverlay(destinationMarker);
  }

  static Future<void> setNavigationCamera(
    NaverMapController controller,
    TransitMode mode,
    NLatLng? currentPosition,
    NLatLng origin,
    double currentHeading,
  ) async {
    try {
      if (mode == TransitMode.car) {
        await controller.updateCamera(
          NCameraUpdate.withParams(
            target: currentPosition ?? origin,
            zoom: 18.0,
            tilt: 35.0,
            bearing: currentHeading,
          ),
        );
        await controller.setLocationTrackingMode(NLocationTrackingMode.face);
      } else {
        await controller.updateCamera(
          NCameraUpdate.withParams(
            target: currentPosition ?? origin,
            zoom: 16.0,
            tilt: 0.0,
          ),
        );
        await controller.setLocationTrackingMode(NLocationTrackingMode.follow);
      }
    } catch (e) {
      print('네비게이션 카메라 설정 오류: $e');
    }
  }

  static void updateLocationOverlay(
    NaverMapController controller,
    NLatLng position,
    TransitMode mode, {
    double? heading,
  }) {
    try {
      final locationOverlay = controller.getLocationOverlay();
      locationOverlay.setPosition(position);

      if (mode == TransitMode.car) {
        locationOverlay.setCircleColor(Color(0x10FB233B));
      } else {
        locationOverlay.setCircleColor(Color(0x100771EB));
      }

      locationOverlay.setCircleRadius(10.0);
      locationOverlay.setIconSize(Size(100, 100));
      locationOverlay.setAnchor(NPoint(0.5, 0.5));

      if (heading != null && mode == TransitMode.car) {
        locationOverlay.setBearing(heading);
      }

      locationOverlay.setIsVisible(true);

      controller.setLocationTrackingMode(
        mode == TransitMode.car
            ? NLocationTrackingMode.face
            : NLocationTrackingMode.follow,
      );
    } catch (e) {
      print('위치 오버레이 업데이트 오류: $e');
    }
  }

  static Future<void> moveToCurrentLocation(
    NaverMapController controller,
    TransitMode mode,
    NLatLng? currentPosition,
  ) async {
    try {
      double targetZoom = mode == TransitMode.car ? 18.0 : 17.0;
      double targetTilt = mode == TransitMode.car ? 35.0 : 0.0;

      if (currentPosition != null) {
        await controller.updateCamera(
          NCameraUpdate.withParams(
            target: currentPosition,
            zoom: targetZoom,
            tilt: targetTilt,
          ),
        );

        await controller.setLocationTrackingMode(
          mode == TransitMode.car
              ? NLocationTrackingMode.face
              : NLocationTrackingMode.follow,
        );
      }
    } catch (e) {
      print('현재 위치 이동 오류: $e');
    }
  }

  static NLatLngBounds calculateRouteBounds(NLatLng start, NLatLng end) {
    double minLat = min(start.latitude, end.latitude);
    double maxLat = max(start.latitude, end.latitude);
    double minLng = min(start.longitude, end.longitude);
    double maxLng = max(start.longitude, end.longitude);

    double latPadding = max(0.001, (maxLat - minLat) * 0.1);
    double lngPadding = max(0.001, (maxLng - minLng) * 0.1);

    return NLatLngBounds(
      southWest: NLatLng(minLat - latPadding, minLng - lngPadding),
      northEast: NLatLng(maxLat + latPadding, maxLng + lngPadding),
    );
  }

  static double calculateSimpleDistance(NLatLng start, NLatLng end) {
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
}
