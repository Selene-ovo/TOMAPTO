import 'dart:async';
import 'package:flutter_naver_map/flutter_naver_map.dart';

class RouteCacheController {
  static final Map<String, Map<String, dynamic>> _routeCache = {};
  static final Map<String, Map<String, dynamic>> _walkRouteCache = {};
  static const int _maxCacheSize = 50;
  static const Duration _cacheExpiry = Duration(minutes: 10);
  static const Duration _walkCacheExpiry = Duration(minutes: 15);
  static Timer? _cacheCleanupTimer;

  static String generateCacheKey(NLatLng start, NLatLng end, String mode) {
    return '${mode}_${start.latitude.toStringAsFixed(4)}_${start.longitude.toStringAsFixed(4)}_${end.latitude.toStringAsFixed(4)}_${end.longitude.toStringAsFixed(4)}';
  }

  static void startCacheCleanup() {
    _cacheCleanupTimer?.cancel();
    _cacheCleanupTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      _cleanupExpiredCache();
    });
  }

  static void _cleanupExpiredCache() {
    final now = DateTime.now();

    _routeCache.removeWhere((key, value) {
      final cacheTime = value['cacheTime'] as DateTime;
      return now.difference(cacheTime) > _cacheExpiry;
    });

    _walkRouteCache.removeWhere((key, value) {
      final cacheTime = value['cacheTime'] as DateTime;
      return now.difference(cacheTime) > _walkCacheExpiry;
    });
  }

  static Map<String, dynamic>? getFromCache(String key) {
    final cached = _routeCache[key];
    if (cached != null) {
      final cacheTime = cached['cacheTime'] as DateTime;
      if (DateTime.now().difference(cacheTime) < _cacheExpiry) {
        return cached['data'] as Map<String, dynamic>;
      } else {
        _routeCache.remove(key);
      }
    }
    return null;
  }

  static Map<String, dynamic>? getWalkFromCache(String key) {
    final cached = _walkRouteCache[key];
    if (cached != null) {
      final cacheTime = cached['cacheTime'] as DateTime;
      if (DateTime.now().difference(cacheTime) < _walkCacheExpiry) {
        return cached['data'] as Map<String, dynamic>;
      } else {
        _walkRouteCache.remove(key);
      }
    }
    return null;
  }

  static void saveToCache(String key, Map<String, dynamic> data) {
    if (_routeCache.length >= _maxCacheSize) {
      final oldestKey = _routeCache.keys.first;
      _routeCache.remove(oldestKey);
    }
    _routeCache[key] = {'data': data, 'cacheTime': DateTime.now()};
  }

  static void saveWalkToCache(String key, Map<String, dynamic> data) {
    if (_walkRouteCache.length >= 30) {
      final oldestKey = _walkRouteCache.keys.first;
      _walkRouteCache.remove(oldestKey);
    }
    _walkRouteCache[key] = {'data': data, 'cacheTime': DateTime.now()};
  }

  static void dispose() {
    _cacheCleanupTimer?.cancel();
  }
}
