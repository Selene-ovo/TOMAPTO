// services/location_service.dart - 완전 수정된 버전
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomapto/services/token_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LocationService {
  // API 서버 기본 URL 가져오기
  static String getApiBaseUrl() {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://172.30.1.42:8080';
    if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
      baseUrl = 'http://$baseUrl';
    }
    return baseUrl;
  }

  // 내 위치 업데이트
  static Future<bool> updateMyLocation(
    double latitude,
    double longitude,
    double? heading,
    double? accuracy,
  ) async {
    try {
      // 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('로그인이 필요합니다');
        return false;
      }

      // 토큰 유효성 검사
      if (TokenService.isTokenExpired(token)) {
        print('토큰이 만료되었습니다. 다시 로그인해주세요.');
        return false;
      }

      final apiBaseUrl = getApiBaseUrl();
      print('위치 업데이트 요청: $latitude, $longitude, API: $apiBaseUrl');

      // 요청 데이터 구성
      Map<String, dynamic> requestData = {
        'latitude': latitude,
        'longitude': longitude,
      };

      // 선택적 필드는 null이 아닐 때만 추가
      if (heading != null) requestData['heading'] = heading;
      if (accuracy != null) requestData['accuracy'] = accuracy;

      final response = await http.post(
        Uri.parse('$apiBaseUrl/location/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestData),
      );

      // 응답 로깅 추가
      print('위치 업데이트 응답 코드: ${response.statusCode}');
      print('위치 업데이트 응답 데이터: ${response.body}');

      if (response.statusCode == 200) {
        print('위치 업데이트 성공: $latitude, $longitude');
        return true;
      } else if (response.statusCode == 401) {
        print('위치 업데이트 실패: 인증 오류 - 다시 로그인이 필요합니다');
        return false;
      } else {
        print('위치 업데이트 실패: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('위치 업데이트 오류: $e');
      return false;
    }
  }

  // 현재 위치 가져오기
  static Future<Position?> getCurrentLocation() async {
    try {
      // 위치 권한 확인
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          print('위치 권한이 거부되었습니다.');
          return null;
        }
      }

      // 위치 서비스가 활성화되어 있는지 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('위치 서비스가 비활성화되어 있습니다.');
        return null;
      }

      // 현재 위치 가져오기
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return position;
    } catch (e) {
      print('현재 위치 가져오기 오류: $e');
      return null;
    }
  }

  // 친구 위치 조회 - 안전한 파싱 버전
  static Future<Map<String, dynamic>?> getFriendLocation(
    String friendId,
  ) async {
    try {
      // 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final userId = prefs.getString('user_id');

      if (token == null || userId == null) {
        print('로그인이 필요합니다');
        return null;
      }

      // 토큰 유효성 검사
      if (TokenService.isTokenExpired(token)) {
        print('토큰이 만료되었습니다. 다시 로그인해주세요.');
        return null;
      }

      final apiBaseUrl = getApiBaseUrl();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/location/friend/$friendId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('친구 위치 조회 성공: $data');

        // 안전한 데이터 검증
        if (data['latitude'] != null && data['longitude'] != null) {
          // 위도/경도 데이터 타입 검증
          final lat = data['latitude'];
          final lng = data['longitude'];

          if ((lat is double ||
                  lat is int ||
                  (lat is String && lat.isNotEmpty)) &&
              (lng is double ||
                  lng is int ||
                  (lng is String && lng.isNotEmpty))) {
            return data;
          } else {
            print('친구 위치 데이터가 유효하지 않습니다: lat=$lat, lng=$lng');
            return null;
          }
        } else {
          print('친구 위치 데이터가 누락되었습니다');
          return null;
        }
      } else if (response.statusCode == 403) {
        print('친구 위치 조회 실패: 위치 공유 관계가 없습니다');
        return null;
      } else if (response.statusCode == 404) {
        print('친구 위치 정보가 없습니다.');
        return null;
      } else {
        print('친구 위치 조회 실패: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('친구 위치 조회 오류: $e');
      return null;
    }
  }

  // 위치 공유 요청
  static Future<bool> requestLocationSharing(
    String friendId, {
    int? durationMinutes,
  }) async {
    try {
      // 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('로그인이 필요합니다');
        return false;
      }

      // 토큰 유효성 검사
      if (TokenService.isTokenExpired(token)) {
        print('토큰이 만료되었습니다. 다시 로그인해주세요.');
        return false;
      }

      final apiBaseUrl = getApiBaseUrl();
      final requestData = <String, dynamic>{'friend_id': friendId};

      if (durationMinutes != null) {
        requestData['duration_minutes'] = durationMinutes;
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/location/share'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('위치 공유 요청 성공: ${data['message']}');
        return true;
      } else {
        print('위치 공유 요청 실패: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('위치 공유 요청 오류: $e');
      return false;
    }
  }

  // 위치 공유 종료
  static Future<bool> endLocationSharing(String friendId) async {
    try {
      // 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('로그인이 필요합니다');
        return false;
      }

      // 토큰 유효성 검사
      if (TokenService.isTokenExpired(token)) {
        print('토큰이 만료되었습니다. 다시 로그인해주세요.');
        return false;
      }

      final apiBaseUrl = getApiBaseUrl();
      final response = await http.post(
        Uri.parse('$apiBaseUrl/location/end-sharing'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'friend_id': friendId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('위치 공유 종료 성공: ${data['message']}');
        return true;
      } else {
        print('위치 공유 종료 실패: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('위치 공유 종료 오류: $e');
      return false;
    }
  }

  // 내가 특정 친구에게 위치 공유 중인지 확인
  static Future<bool> checkIAmSharingWith(String friendId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final myUserId = prefs.getString('user_id');

      if (token == null || myUserId == null) {
        print('로그인이 필요합니다');
        return false;
      }

      if (TokenService.isTokenExpired(token)) {
        print('토큰이 만료되었습니다');
        return false;
      }

      final apiBaseUrl = getApiBaseUrl();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/location/active-sharings'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> sharings = json.decode(response.body);

        // 내가 해당 친구에게 공유하고 있는지 확인
        for (var sharing in sharings) {
          if (sharing['sharer_id'] == myUserId &&
              sharing['sharee_id'] == friendId) {
            print('내가 $friendId에게 위치 공유 중입니다.');
            return true;
          }
        }

        print('내가 $friendId에게 위치 공유 중이 아닙니다.');
        return false;
      } else {
        print('위치 공유 상태 조회 실패: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('위치 공유 상태 확인 오류: $e');
      return false;
    }
  }

  // 특정 친구가 나에게 위치 공유 중인지 확인
  static Future<bool> checkFriendIsSharingWith(String friendId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final myUserId = prefs.getString('user_id');

      if (token == null || myUserId == null) {
        print('로그인이 필요합니다');
        return false;
      }

      if (TokenService.isTokenExpired(token)) {
        print('토큰이 만료되었습니다');
        return false;
      }

      final apiBaseUrl = getApiBaseUrl();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/location/active-sharings'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> sharings = json.decode(response.body);

        // 친구가 나에게 공유하고 있는지 확인
        for (var sharing in sharings) {
          if (sharing['sharer_id'] == friendId &&
              sharing['sharee_id'] == myUserId) {
            print('$friendId님이 나에게 위치 공유 중입니다.');
            return true;
          }
        }

        print('$friendId님이 나에게 위치 공유 중이 아닙니다.');
        return false;
      } else {
        print('위치 공유 상태 조회 실패: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('위치 공유 상태 확인 오류: $e');
      return false;
    }
  }

  // 활성 위치 공유 목록 조회
  static Future<List<Map<String, dynamic>>?> getActiveSharings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('로그인이 필요합니다');
        return null;
      }

      if (TokenService.isTokenExpired(token)) {
        print('토큰이 만료되었습니다. 다시 로그인해주세요.');
        return null;
      }

      final apiBaseUrl = getApiBaseUrl();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/location/active-sharings'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('위치 공유 목록 조회 성공: 총 ${data.length}개');
        return data.cast<Map<String, dynamic>>();
      } else {
        print('위치 공유 목록 조회 실패: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('위치 공유 목록 조회 오류: $e');
      return null;
    }
  }

  // 위치 접근 권한 및 서비스 상태 확인
  static Future<bool> checkLocationPermission() async {
    try {
      // 권한 체크
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return false;
        }
      }

      // 위치 서비스 활성화 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      return serviceEnabled;
    } catch (e) {
      print('위치 권한 확인 오류: $e');
      return false;
    }
  }

  // 위치 히스토리 조회
  static Future<List<Map<String, dynamic>>?> getLocationHistory(
    String friendId, {
    int limit = 20,
  }) async {
    try {
      // 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('로그인이 필요합니다');
        return null;
      }

      // 토큰 유효성 검사
      if (TokenService.isTokenExpired(token)) {
        print('토큰이 만료되었습니다. 다시 로그인해주세요.');
        return null;
      }

      final apiBaseUrl = getApiBaseUrl();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/location/history/$friendId?limit=$limit'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('위치 히스토리 조회 성공: ${data['history'].length}개');
        return (data['history'] as List).cast<Map<String, dynamic>>();
      } else {
        print('위치 히스토리 조회 실패: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('위치 히스토리 조회 오류: $e');
      return null;
    }
  }
}
