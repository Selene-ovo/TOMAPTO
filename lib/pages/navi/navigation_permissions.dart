import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tomapto/controllers/map/transit_map_controller.dart';
import 'package:tomapto/pages/navi/navigation_modals.dart';

class NavigationPermissions {
  static Future<bool> checkLocationPermission(
    BuildContext context,
    TransitMode mode,
  ) async {
    final status = await Permission.location.request();

    if (status.isGranted) {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServiceDialog(context, mode);
        return false;
      }
      return true;
    } else {
      _showPermissionDeniedDialog(context, mode);
      return false;
    }
  }

  static void _showLocationServiceDialog(
    BuildContext context,
    TransitMode mode,
  ) {
    NavigationModals.showLocationServiceDialog(
      context: context,
      onCancel: () {
        Navigator.pop(context);
        Navigator.pop(context);
      },
      onOpenSettings: () {
        Navigator.pop(context);
        Geolocator.openLocationSettings();
      },
    );
  }

  static void _showPermissionDeniedDialog(
    BuildContext context,
    TransitMode mode,
  ) {
    NavigationModals.showPermissionDeniedDialog(
      context: context,
      mode: mode,
      onCancel: () {
        Navigator.pop(context);
        Navigator.pop(context);
      },
      onOpenSettings: () {
        Navigator.pop(context);
        openAppSettings();
      },
    );
  }
}
