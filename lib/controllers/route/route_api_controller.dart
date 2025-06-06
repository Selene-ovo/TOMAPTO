import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'dart:convert';
import 'dart:math';

class RouteApiController {
  String? _cachedApiKey;
  String? _cachedSecretKey;
  String? _cachedApiUrl;
  String? _cachedTmapApiKey;
  String? _cachedClientId;
  String? _cachedClientSecret;

  Future<bool> initAllApiKeys() async {
    _cachedApiKey = dotenv.env['NAVER_API_KEY'];
    _cachedSecretKey = dotenv.env['NAVER_SECRET_KEY'];
    _cachedApiUrl = 'https://maps.apigw.ntruss.com/map-direction/v1';
    _cachedTmapApiKey = dotenv.env['TMAP_API_KEY'];
    _cachedClientId = dotenv.env['NAVER_DEV_KEY'];
    _cachedClientSecret = dotenv.env['NAVER_DEV_SECRET_KEY'];

    if (_cachedApiKey == null ||
        _cachedSecretKey == null ||
        _cachedTmapApiKey == null ||
        _cachedClientId == null ||
        _cachedClientSecret == null) {
      return false;
    }
    return true;
  }

  Future<Map<String, dynamic>> searchCarRouteFromApi(
    NLatLng start,
    NLatLng end,
  ) async {
    try {
      final url = Uri.parse(
        '$_cachedApiUrl/driving?'
        'start=${start.longitude},${start.latitude}&'
        'goal=${end.longitude},${end.latitude}&'
        'option=trafast',
      );

      final response = await http
          .get(
            url,
            headers: {
              'X-NCP-APIGW-API-KEY-ID': _cachedApiKey!,
              'X-NCP-APIGW-API-KEY': _cachedSecretKey!,
            },
          )
          .timeout(Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['route'] != null && data['route']['trafast'] != null) {
          return data;
        }
      }

      throw Exception('Invalid response');
    } catch (e) {
      throw Exception('Car route API error: $e');
    }
  }

  Future<Map<String, dynamic>> searchWalkRouteFromTmap(
    NLatLng start,
    NLatLng end,
  ) async {
    try {
      final url = Uri.parse(
        'https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1',
      );

      final requestBody = {
        'startX': start.longitude.toStringAsFixed(6),
        'startY': start.latitude.toStringAsFixed(6),
        'endX': end.longitude.toStringAsFixed(6),
        'endY': end.latitude.toStringAsFixed(6),
        'reqCoordType': 'WGS84GEO',
        'resCoordType': 'WGS84GEO',
        'startName': '출발지',
        'endName': '도착지',
      };

      final response = await http
          .post(
            url,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/x-www-form-urlencoded',
              'appKey': _cachedTmapApiKey!,
            },
            body: Uri(queryParameters: requestBody).query,
          )
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      }

      throw Exception('Invalid response');
    } catch (e) {
      throw Exception('Walk route API error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> searchAddressByKeyword(
    String keyword,
  ) async {
    final encodedKeyword = Uri.encodeComponent(keyword);
    final url = Uri.parse(
      'https://openapi.naver.com/v1/search/local.json?query=$encodedKeyword&display=5',
    );

    try {
      final response = await http
          .get(
            url,
            headers: {
              'X-Naver-Client-Id': _cachedClientId!,
              'X-Naver-Client-Secret': _cachedClientSecret!,
            },
          )
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);

        if (data['items'] != null && data['items'].isNotEmpty) {
          return data['items'].map<Map<String, dynamic>>((item) {
            String title = item['title'].replaceAll(RegExp(r'<[^>]*>'), '');

            return {
              'name': title,
              'address': item['roadAddress'] ?? item['address'] ?? '',
              'x': item['mapx'] ?? '0',
              'y': item['mapy'] ?? '0',
            };
          }).toList();
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  Future<String> getAddressFromCoords(NLatLng position) async {
    final url =
        'https://maps.apigw.ntruss.com/map-reversegeocode/v2/gc?'
        'coords=${position.longitude},${position.latitude}&output=json';

    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'X-NCP-APIGW-API-KEY-ID': _cachedApiKey!,
              'X-NCP-APIGW-API-KEY': _cachedSecretKey!,
              'Accept': 'application/json',
            },
          )
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);

        if (data['results'] != null && data['results'].isNotEmpty) {
          return _parseSimpleAddress(data);
        }
      }

      return '강원특별자치도 강릉시';
    } catch (e) {
      return '강원특별자치도 강릉시';
    }
  }

  String _parseSimpleAddress(Map<String, dynamic> response) {
    try {
      final results = response['results'];

      for (var result in results) {
        if (result['name'] == 'roadaddr' && result['region'] != null) {
          final region = result['region'];
          String address = '';

          if (region['area1'] != null) address += region['area1']['name'] + ' ';
          if (region['area2'] != null) address += region['area2']['name'] + ' ';
          if (region['area3'] != null) address += region['area3']['name'];

          return address.trim();
        }
      }

      for (var result in results) {
        if (result['name'] == 'legalcode' && result['region'] != null) {
          final region = result['region'];
          String address = '';

          if (region['area1'] != null) address += region['area1']['name'] + ' ';
          if (region['area2'] != null) address += region['area2']['name'] + ' ';
          if (region['area3'] != null) address += region['area3']['name'];

          return address.trim();
        }
      }

      return '주소 확인 불가';
    } catch (e) {
      return '주소 확인 불가';
    }
  }

  NLatLng convertAddressToCoords(Map<String, dynamic> searchResult) {
    try {
      double x = double.parse(searchResult['x']) / 10000000.0;
      double y = double.parse(searchResult['y']) / 10000000.0;

      return NLatLng(y, x);
    } catch (e) {
      return NLatLng(37.5666805, 126.9784147);
    }
  }

  double calculateDistance(NLatLng point1, NLatLng point2) {
    const double earthRadius = 6371000;
    final double lat1 = point1.latitude * (3.141592653589793 / 180);
    final double lat2 = point2.latitude * (3.141592653589793 / 180);
    final double dLat =
        (point2.latitude - point1.latitude) * (3.141592653589793 / 180);
    final double dLon =
        (point2.longitude - point1.longitude) * (3.141592653589793 / 180);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }
}
