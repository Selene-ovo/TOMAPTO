import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;

class KakaoMapService {
  static final String _baseUrl = 'https://dapi.kakao.com/v2/local';

  // 카카오 REST API 키 (환경변수에서 가져오기)
  static String get _apiKey => dotenv.env['KAKAO_REST_API_KEY'] ?? '';

  // 카테고리별 코드 매핑
  static const Map<String, String> categoryCodeMap = {
    '카페': 'CE7', // 카페
    '음식점': 'FD6', // 음식점
    '주유소': 'OL7', // 주유소, 충전소
    '편의점': 'CS2', // 편의점
    '영화관': 'CT1', // 문화시설 (영화관 포함)
    'PC방': 'AT4', // 관광명소 (오락시설 포함)
    '병원': 'HP8', // 병원
    '약국': 'PM9', // 약국
    '은행': 'BK9', // 은행
    '마트': 'MT1', // 대형마트
    '숙박': 'AD5', // 숙박
    '학교': 'SC4', // 학교
    '학원': 'AC5', // 학원
    '주차장': 'PK6', // 주차장
    '지하철': 'SW8', // 지하철역
    '공공기관': 'PO3', // 공공기관
    '중개업소': 'AG2', // 중개업소
    '어린이집': 'PS3', // 어린이집, 유치원
  };

  // 카테고리별 장소 검색
  static Future<List<KakaoPlace>> searchByCategory({
    required String category,
    required double latitude,
    required double longitude,
    int radius = 20000, // 20km 반경
    int page = 1,
    int size = 15,
  }) async {
    try {
      if (_apiKey.isEmpty) {
        throw Exception('카카오 REST API 키가 설정되지 않았습니다.');
      }

      final categoryCode = categoryCodeMap[category];
      if (categoryCode == null) {
        throw Exception('지원하지 않는 카테고리입니다: $category');
      }

      final uri = Uri.parse('$_baseUrl/search/category.json').replace(
        queryParameters: {
          'category_group_code': categoryCode,
          'x': longitude.toString(),
          'y': latitude.toString(),
          'radius': radius.toString(),
          'page': page.toString(),
          'size': size.toString(),
          'sort': 'distance',
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'KakaoAK $_apiKey',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final documents = data['documents'] as List;

        final places =
            documents.map((doc) => KakaoPlace.fromJson(doc)).toList();

        return places;
      } else {
        throw Exception('카카오맵 API 요청 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('카테고리 검색 중 오류 발생: $e');
    }
  }

  // 키워드 검색 (메인 검색에서 사용 가능)
  static Future<List<KakaoPlace>> searchByKeyword({
    required String query,
    required double latitude,
    required double longitude,
    int radius = 20000,
    int page = 1,
    int size = 15,
  }) async {
    try {
      if (_apiKey.isEmpty) {
        throw Exception('카카오 REST API 키가 설정되지 않았습니다.');
      }

      final uri = Uri.parse('$_baseUrl/search/keyword.json').replace(
        queryParameters: {
          'query': query,
          'x': longitude.toString(),
          'y': latitude.toString(),
          'radius': radius.toString(),
          'page': page.toString(),
          'size': size.toString(),
          'sort': 'distance',
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'KakaoAK $_apiKey',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final documents = data['documents'] as List;

        final places =
            documents.map((doc) => KakaoPlace.fromJson(doc)).toList();

        return places;
      } else {
        throw Exception('카카오맵 키워드 검색 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('키워드 검색 중 오류 발생: $e');
    }
  }

  // 거리 계산 (Haversine 공식)
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // 지구 반지름 (km)

    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degree) {
    return degree * (math.pi / 180);
  }
}

// 카카오맵 장소 정보 모델
class KakaoPlace {
  final String id;
  final String placeName;
  final String categoryName;
  final String? categoryGroupCode;
  final String? categoryGroupName;
  final String? phone;
  final String addressName;
  final String roadAddressName;
  final String x; // 경도
  final String y; // 위도
  final String? placeUrl;
  final String distance;

  KakaoPlace({
    required this.id,
    required this.placeName,
    required this.categoryName,
    this.categoryGroupCode,
    this.categoryGroupName,
    this.phone,
    required this.addressName,
    required this.roadAddressName,
    required this.x,
    required this.y,
    this.placeUrl,
    required this.distance,
  });

  factory KakaoPlace.fromJson(Map<String, dynamic> json) {
    return KakaoPlace(
      id: json['id'] ?? '',
      placeName: json['place_name'] ?? '',
      categoryName: json['category_name'] ?? '',
      categoryGroupCode: json['category_group_code'],
      categoryGroupName: json['category_group_name'],
      phone: json['phone'],
      addressName: json['address_name'] ?? '',
      roadAddressName: json['road_address_name'] ?? '',
      x: json['x'] ?? '0',
      y: json['y'] ?? '0',
      placeUrl: json['place_url'],
      distance: json['distance'] ?? '0',
    );
  }

  // 경도를 double로 변환
  double get longitude => double.tryParse(x) ?? 0.0;

  // 위도를 double로 변환
  double get latitude => double.tryParse(y) ?? 0.0;

  // 거리를 double로 변환 (미터 -> 킬로미터)
  double get distanceKm => (double.tryParse(distance) ?? 0.0) / 1000.0;

  // SearchResult로 변환 (기존 코드와 호환성을 위해)
  SearchResult toSearchResult() {
    return SearchResult(
      placeName,
      addressName,
      distanceKm,
      category: categoryGroupName ?? categoryName.split('>').last.trim(),
      mapx: longitude,
      mapy: latitude,
    );
  }
}

// 기존 SearchResult 클래스 (호환성을 위해 포함)
class SearchResult {
  final String name;
  final String address;
  final double distance;
  final String category;
  final double mapx;
  final double mapy;

  SearchResult(
    this.name,
    this.address,
    this.distance, {
    this.category = '',
    this.mapx = 0,
    this.mapy = 0,
  });
}
