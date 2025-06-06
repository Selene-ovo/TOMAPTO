import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SearchMainController extends ChangeNotifier {
  // 검색어 컨트롤러
  final TextEditingController searchController = TextEditingController();
  // 포커스 노드
  final FocusNode searchFocusNode = FocusNode();

  // 검색 딜레이 타이머 (API 호출 최적화)
  Timer? _debounce;

  // 최근 검색 기록 (실제로는 DB나 SharedPreferences에서 가져옴)
  List<SearchItem> recentSearches = [
    SearchItem('가톨릭관동대학교', '25.05.11'),
    SearchItem('강릉의료원', '25.05.10'),
    SearchItem('강릉시외버스터미널', '25.05.09'),
  ];

  // 검색 결과
  List<SearchResult> searchResults = [];

  // 검색 진행 중 상태
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  set isLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // 검색 오류 메시지
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  set errorMessage(String? value) {
    _errorMessage = value;
    notifyListeners();
  }

  // 사용자 현재 위치
  Position? userPosition;

  // 사용자 현재 위치의 주소
  String? userLocationAddress;

  // 네이버 API 키 설정 (dotenv 사용)
  String get _clientId => dotenv.env['NAVER_DEV_KEY'] ?? '';
  String get _clientSecret => dotenv.env['NAVER_DEV_SECRET_KEY'] ?? '';

  // 네이버 Maps API 키 설정 (dotenv 사용)
  String get _mapClientId => dotenv.env['NAVER_API_KEY'] ?? '';
  String get _mapClientSecret => dotenv.env['NAVER_SECRET_KEY'] ?? '';

  // 네이버 지역 검색 API URL
  final String _baseUrl = 'https://openapi.naver.com/v1/search/local.json';

  // 초기화 메서드
  Future<void> initialize() async {
    try {
      userPosition = await getCurrentPosition();
      if (userPosition != null) {
        userLocationAddress = await getAddressFromCoords(
          userPosition!.latitude,
          userPosition!.longitude,
        );
        print(
          '사용자 위치 초기화 완료: ${userPosition?.latitude}, ${userPosition?.longitude}',
        );
        print('사용자 주소: $userLocationAddress');
      }
    } catch (e) {
      print('위치 정보를 가져오는데 실패했습니다: $e');
    }
  }

  // 키보드 포커스 요청 메서드
  void requestFocus(BuildContext context) {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (searchFocusNode.canRequestFocus) {
        FocusScope.of(context).requestFocus(searchFocusNode);
      }
    });
  }

  // 검색어 변경 시 처리할 메서드 (개선된 위치 기반 필터링)
  void onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.isEmpty) {
      searchResults = [];
      errorMessage = null;
      notifyListeners();
      return;
    }

    isLoading = true;

    _debounce = Timer(const Duration(milliseconds: 200), () async {
      try {
        errorMessage = null;

        // 네이버 API로 검색 수행 (더 많은 결과 요청)
        final naverResults = await searchPlaces(query, display: 5);

        // 검색 결과 변환 및 거리 계산
        final updatedResults = <SearchResult>[];

        for (final naverResult in naverResults) {
          try {
            // KATECH 좌표를 GPS 좌표로 변환
            final gpsCoords = await convertKatechToGps(
              naverResult.mapx,
              naverResult.mapy,
            );

            if (gpsCoords != null && userPosition != null) {
              // 거리 계산
              final distance = calculateDistance(
                userPosition!.latitude,
                userPosition!.longitude,
                gpsCoords['lat']!,
                gpsCoords['lng']!,
              );

              // 거리 기준 필터링 (1000km 이내만 포함)
              if (distance <= 1000.0) {
                // 1000km 이내
                updatedResults.add(
                  SearchResult(
                    naverResult.title,
                    naverResult.address,
                    distance,
                    category: _extractCategory(naverResult.category),
                    mapx: gpsCoords['lng']!,
                    mapy: gpsCoords['lat']!,
                  ),
                );
              } else {
                print(
                  '거리가 멀어서 제외: ${naverResult.title} (${distance.toStringAsFixed(1)}km)',
                );
              }
            } else {
              // 위치 정보가 없는 경우 기본값으로 추가
              updatedResults.add(
                SearchResult(
                  naverResult.title,
                  naverResult.address,
                  0.0,
                  category: _extractCategory(naverResult.category),
                  mapx: naverResult.mapx / 10000000.0,
                  mapy: naverResult.mapy / 10000000.0,
                ),
              );
            }
          } catch (e) {
            print('결과 처리 중 오류: $e');
            // 오류가 발생한 항목은 건너뛰기
            continue;
          }
        }

        // 거리순으로 정렬
        updatedResults.sort((a, b) => a.distance.compareTo(b.distance));

        // 상위 15개만 표시
        searchResults = updatedResults.take(15).toList();

        print('검색 완료: ${searchResults.length}개 결과 (30km 이내)');
        if (searchResults.isNotEmpty) {
          print(
            '가장 가까운 결과: ${searchResults.first.name} (${searchResults.first.distance.toStringAsFixed(1)}km)',
          );
        }

        isLoading = false;
      } catch (e) {
        searchResults = [];
        isLoading = false;
        errorMessage = '검색 중 오류가 발생했습니다: $e';
        print('검색 오류: $e');
      }
    });
  }

  // 단순화된 검색 메서드 (위치 필터링은 클라이언트에서 처리)
  Future<List<NaverSearchResult>> searchPlaces(
    String query, {
    int display = 50, // 기본 50개로 증가
  }) async {
    try {
      if (_clientId.isEmpty || _clientSecret.isEmpty) {
        throw Exception('네이버 API 키가 설정되지 않았습니다. .env 파일을 확인해주세요.');
      }

      final encodedQuery = Uri.encodeComponent(query);

      // 기본 검색 URL (위치 파라미터 제거)
      String urlString =
          '$_baseUrl?query=$encodedQuery&display=$display&sort=random';

      final url = Uri.parse(urlString);
      print('검색 요청 URL: $url');

      final response = await http.get(
        url,
        headers: {
          'X-Naver-Client-Id': _clientId,
          'X-Naver-Client-Secret': _clientSecret,
        },
      );

      print('응답 상태 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> data = json.decode(responseBody);

        if (data['total'] == 0 ||
            !data.containsKey('items') ||
            data['items'].isEmpty) {
          print('검색 결과가 없습니다.');
          return [];
        }

        final List<dynamic> items = data['items'];
        print('원본 검색 결과 수: ${items.length}');

        final results =
            items
                .map<NaverSearchResult>(
                  (item) => NaverSearchResult.fromJson(item),
                )
                .toList();

        print('파싱된 결과 수: ${results.length}');
        return results;
      } else {
        print('API 요청 실패: ${response.statusCode}');
        print('응답 내용: ${response.body}');
        throw Exception('API 요청 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('검색 중 오류 발생: $e');
      throw Exception('검색 중 오류 발생: $e');
    }
  }

  // KATECH 좌표를 GPS 좌표로 변환하는 메서드
  Future<Map<String, double>?> convertKatechToGps(
    double katechX,
    double katechY,
  ) async {
    try {
      print('🔍 좌표 변환 시작: KATECH($katechX, $katechY) → GPS');

      if (_mapClientId.isEmpty || _mapClientSecret.isEmpty) {
        print('❌ 네이버 Maps API 키가 설정되지 않았습니다.');
        return _improvedKatechToGps(katechX, katechY);
      }

      print('💡 API 대신 수학적 변환 사용');
      return _improvedKatechToGps(katechX, katechY);
    } catch (e) {
      print('❌ 좌표 변환 오류: $e');
      return _improvedKatechToGps(katechX, katechY);
    }
  }

  // 한국 좌표 유효성 검사
  bool _isValidKoreanCoordinate(double lat, double lng) {
    return lat >= 33.0 && lat <= 38.5 && lng >= 124.0 && lng <= 132.0;
  }

  // 개선된 KATECH → GPS 변환 메서드 추가
  Map<String, double> _improvedKatechToGps(double katechX, double katechY) {
    try {
      double lat, lng;

      // 네이버 API에서 받는 좌표 처리
      if (katechX > 1000000 && katechY > 1000000) {
        // 네이버 API 특수 형태 (10^7 배수)
        lat = katechY / 10000000.0;
        lng = katechX / 10000000.0;
        print('📍 네이버 API 형태 좌표 변환: ($lat, $lng)');
      } else if (katechX > 100000 && katechY > 100000) {
        // 일반적인 KATECH 좌표계
        // KATECH → WGS84 근사 변환 공식
        lng = katechX / 1000000.0 + 124.0;
        lat = katechY / 1000000.0 + 33.0;
        print('📍 KATECH 좌표계 변환: ($lat, $lng)');
      } else {
        // 이미 GPS 좌표인 경우
        lat = katechY;
        lng = katechX;
        print('📍 이미 GPS 좌표: ($lat, $lng)');
      }

      // 한국 영역 검증
      if (!_isValidKoreanCoordinate(lat, lng)) {
        print('⚠️ 좌표가 한국 영역을 벗어남, 보정 필요');

        // 강릉 지역 기본 좌표로 보정
        if (katechX.toString().contains('37') ||
            katechY.toString().contains('128')) {
          lat = 37.7519;
          lng = 128.8761;
          print('📍 강릉 지역으로 보정: ($lat, $lng)');
        } else {
          // 서울 기본 좌표
          lat = 37.5666805;
          lng = 126.9784147;
          print('📍 서울로 보정: ($lat, $lng)');
        }
      }

      print('✅ 최종 변환 결과: $lat, $lng');
      return {'lat': lat, 'lng': lng};
    } catch (e) {
      print('❌ 좌표 변환 중 오류: $e');
      return {'lat': 37.5666805, 'lng': 126.9784147};
    }
  }

  // 카테고리 문자열에서 주요 카테고리 추출
  String _extractCategory(String fullCategory) {
    final categories = fullCategory.split('>');
    if (categories.length > 1) {
      return categories[1].trim();
    }
    return categories.isNotEmpty ? categories[0].trim() : '';
  }

  // 위치 권한 요청 및 확인
  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('위치 서비스가 비활성화되어 있습니다.');
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('위치 권한이 거부되었습니다.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('위치 권한이 영구적으로 거부되었습니다.');
      return false;
    }

    return true;
  }

  // 현재 위치 가져오기
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await _handleLocationPermission();

    if (!hasPermission) {
      print('위치 권한이 없어 현재 위치를 가져올 수 없습니다.');
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );

      print('현재 위치 획득 성공: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('현재 위치 가져오기 실패: $e');
      return null;
    }
  }

  // 두 지점 간의 거리 계산
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (pi / 180);
  }

  // 좌표를 주소로 변환하는 메서드
  Future<String> getAddressFromCoords(double latitude, double longitude) async {
    if (_mapClientId.isEmpty || _mapClientSecret.isEmpty) {
      print('네이버 Maps API 키가 설정되지 않았습니다.');
      return '주소 변환 불가';
    }

    // 공식 문서에 맞춘 올바른 URL 구성
    final coords = Uri.encodeComponent('$longitude,$latitude'); // URL 인코딩 적용
    final url =
        'https://maps.apigw.ntruss.com/map-reversegeocode/v2/gc?'
        'coords=$coords&output=json&orders=legalcode%2Cadmcode%2Caddr%2Croadaddr';

    try {
      print('🌐 Reverse Geocoding API 요청: $url');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              // 공식 문서와 동일한 헤더명 (소문자)
              'x-ncp-apigw-api-key-id': _mapClientId,
              'x-ncp-apigw-api-key': _mapClientSecret,
              'Accept': 'application/json',
            },
          )
          .timeout(Duration(seconds: 5));

      print('📥 응답 상태 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);

        print('✅ API 호출 성공');

        if (data['results'] != null && data['results'].isNotEmpty) {
          final address = _parseAddressFromResponse(data);
          print('📍 변환된 주소: $address');
          return address;
        } else {
          print('⚠️ 응답에 결과가 없음');
          return '주소 확인 불가';
        }
      } else if (response.statusCode == 401) {
        print('❌ 401 Unauthorized');
        print('📋 응답 내용: ${response.body}');
        return '주소 확인 불가 (API 인증 실패)';
      } else {
        print('⚠️ 예상치 못한 응답 코드: ${response.statusCode}');
        print('응답 내용: ${response.body}');
        return '주소 확인 불가';
      }
    } catch (e) {
      print('❌ API 호출 오류: $e');
      return '주소 확인 불가';
    }
  }

  // 주소 응답 파싱
  String _parseAddressFromResponse(Map<String, dynamic> response) {
    try {
      final results = response['results'];

      // 1순위: 도로명주소 (roadaddr)
      for (var result in results) {
        if (result['name'] == 'roadaddr' && result['land'] != null) {
          final land = result['land'];
          String address = '';

          if (land['area1'] != null && land['area1']['name'] != null) {
            String area1 = land['area1']['name'];
            // 긴 도명을 줄여서 표시
            if (area1.contains('강원특별자치도')) {
              address += '강원도 ';
            } else if (area1.contains('특별시') ||
                area1.contains('광역시') ||
                area1.contains('특별자치시')) {
              // 서울특별시 → 서울시, 부산광역시 → 부산시
              address +=
                  '${area1.replaceAll('특별시', '시').replaceAll('광역시', '시').replaceAll('특별자치시', '시')} ';
            } else {
              address += '${area1} ';
            }
          }
          if (land['area2'] != null && land['area2']['name'] != null) {
            address += '${land['area2']['name']} ';
          }
          if (land['area3'] != null && land['area3']['name'] != null) {
            address += '${land['area3']['name']} ';
          }
          if (land['name'] != null) {
            address += land['name'];
          }

          if (address.trim().isNotEmpty) {
            print('✅ 도로명주소 파싱: $address');
            return address.trim();
          }
        }
      }

      // 2순위: 지번주소 (addr)
      for (var result in results) {
        if (result['name'] == 'addr' && result['region'] != null) {
          final region = result['region'];
          String address = '';

          if (region['area1'] != null && region['area1']['name'] != null) {
            String area1 = region['area1']['name'];
            if (area1.contains('강원특별자치도')) {
              address += '강원도 ';
            } else if (area1.contains('특별시') ||
                area1.contains('광역시') ||
                area1.contains('특별자치시')) {
              address +=
                  '${area1.replaceAll('특별시', '시').replaceAll('광역시', '시').replaceAll('특별자치시', '시')} ';
            } else {
              address += '${area1} ';
            }
          }
          if (region['area2'] != null && region['area2']['name'] != null) {
            address += '${region['area2']['name']} ';
          }
          if (region['area3'] != null && region['area3']['name'] != null) {
            address += '${region['area3']['name']}';
          }

          if (address.trim().isNotEmpty) {
            print('✅ 지번주소 파싱: $address');
            return address.trim();
          }
        }
      }

      // 3순위: 법정동코드 (legalcode)
      for (var result in results) {
        if (result['name'] == 'legalcode' && result['region'] != null) {
          final region = result['region'];
          String address = '';

          if (region['area1'] != null && region['area1']['name'] != null) {
            String area1 = region['area1']['name'];
            if (area1.contains('강원특별자치도')) {
              address += '강원도 ';
            } else if (area1.contains('특별시') ||
                area1.contains('광역시') ||
                area1.contains('특별자치시')) {
              address +=
                  '${area1.replaceAll('특별시', '시').replaceAll('광역시', '시').replaceAll('특별자치시', '시')} ';
            } else {
              address += '${area1} ';
            }
          }
          if (region['area2'] != null && region['area2']['name'] != null) {
            address += '${region['area2']['name']} ';
          }
          if (region['area3'] != null && region['area3']['name'] != null) {
            address += '${region['area3']['name']}';
          }

          if (address.trim().isNotEmpty) {
            print('✅ 법정동코드 파싱: $address');
            return address.trim();
          }
        }
      }

      // 4순위: 행정동코드 (admcode)
      for (var result in results) {
        if (result['name'] == 'admcode' && result['region'] != null) {
          final region = result['region'];
          String address = '';

          if (region['area1'] != null && region['area1']['name'] != null) {
            String area1 = region['area1']['name'];
            if (area1.contains('강원특별자치도')) {
              address += '강원도 ';
            } else if (area1.contains('특별시') ||
                area1.contains('광역시') ||
                area1.contains('특별자치시')) {
              address +=
                  '${area1.replaceAll('특별시', '시').replaceAll('광역시', '시').replaceAll('특별자치시', '시')} ';
            } else {
              address += '${area1} ';
            }
          }
          if (region['area2'] != null && region['area2']['name'] != null) {
            address += '${region['area2']['name']} ';
          }
          if (region['area3'] != null && region['area3']['name'] != null) {
            address += '${region['area3']['name']}';
          }

          if (address.trim().isNotEmpty) {
            print('✅ 행정동코드 파싱: $address');
            return address.trim();
          }
        }
      }

      print('⚠️ 모든 파싱 시도 실패');
      return '주소 확인 불가';
    } catch (e) {
      print('❌ 주소 파싱 오류: $e');
      return '주소 확인 불가';
    }
  }

  // 최근 검색어에 추가
  void addToRecentSearches(String name) {
    final now = DateTime.now();
    final dateStr =
        '${now.year.toString().substring(2)}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';

    final existingIndex = recentSearches.indexWhere(
      (item) => item.name == name,
    );
    if (existingIndex != -1) {
      recentSearches.removeAt(existingIndex);
    }

    recentSearches.insert(0, SearchItem(name, dateStr));
    notifyListeners();
  }

  // 최근 검색어 삭제
  void removeRecentSearch(int index) {
    if (index >= 0 && index < recentSearches.length) {
      recentSearches.removeAt(index);
      notifyListeners();
    }
  }

  // 항목 클릭 시 처리할 메서드
  void onItemSelected(BuildContext context, SearchResult result) {
    addToRecentSearches(result.name);
    Navigator.pop(context, result);
  }

  // 뒤로가기 처리
  void onBackPressed(BuildContext context) {
    Navigator.pop(context);
  }

  // 사용자 위치 업데이트
  Future<void> updateUserLocation() async {
    try {
      final newPosition = await getCurrentPosition();
      if (newPosition != null) {
        userPosition = newPosition;
        userLocationAddress = await getAddressFromCoords(
          newPosition.latitude,
          newPosition.longitude,
        );
        print(
          '사용자 위치 업데이트 완료: ${userPosition!.latitude}, ${userPosition!.longitude}',
        );
        print('업데이트된 주소: $userLocationAddress');
        notifyListeners();
      }
    } catch (e) {
      print('사용자 위치 업데이트 실패: $e');
    }
  }

  // 리소스 해제
  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}

// ===== 여기서부터 클래스들을 최상위 레벨에 선언 =====

// 최근 검색 항목 클래스
class SearchItem {
  final String name;
  final String date;

  SearchItem(this.name, this.date);
}

// 검색 결과 항목 클래스
class SearchResult {
  final String name;
  final String address;
  final double distance; // km 단위
  final String category; // 카테고리 정보
  final double mapx; // X 좌표 (경도)
  final double mapy; // Y 좌표 (위도)

  SearchResult(
    this.name,
    this.address,
    this.distance, {
    this.category = '',
    this.mapx = 0,
    this.mapy = 0,
  });
}

class NaverSearchResult {
  final String title; // 장소명
  final String address; // 주소
  final String roadAddress; // 도로명 주소
  final double mapx; // X 좌표 (경도)
  final double mapy; // Y 좌표 (위도)
  final String category; // 카테고리

  NaverSearchResult({
    required this.title,
    required this.address,
    required this.roadAddress,
    required this.mapx,
    required this.mapy,
    required this.category,
  });

  factory NaverSearchResult.fromJson(Map<String, dynamic> json) {
    try {
      String titleText = json['title'] ?? '';
      titleText = titleText.replaceAll(RegExp(r'<[^>]*>'), '');

      double mapxValue;
      double mapyValue;

      try {
        mapxValue = double.parse(json['mapx'] ?? '0');
      } catch (e) {
        print('mapx 파싱 오류: ${json['mapx']}');
        mapxValue = 0;
      }

      try {
        mapyValue = double.parse(json['mapy'] ?? '0');
      } catch (e) {
        print('mapy 파싱 오류: ${json['mapy']}');
        mapyValue = 0;
      }

      return NaverSearchResult(
        title: titleText,
        address: json['address'] ?? '',
        roadAddress: json['roadAddress'] ?? '',
        mapx: mapxValue,
        mapy: mapyValue,
        category: json['category'] ?? '',
      );
    } catch (e) {
      print('NaverSearchResult 생성 중 오류: $e');
      print('원본 데이터: $json');
      return NaverSearchResult(
        title: '오류 발생',
        address: '',
        roadAddress: '',
        mapx: 0,
        mapy: 0,
        category: '',
      );
    }
  }
}
