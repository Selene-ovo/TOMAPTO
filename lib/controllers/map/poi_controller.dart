import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

class ClickedLocationInfo {
  final String address;
  final String locationName;
  final String category;
  final NLatLng position;
  final double distanceFromUser;
  final String estimatedTime;
  final String? roadAddress;
  final String? phoneNumber;
  final String? link;
  final String? description;

  ClickedLocationInfo({
    required this.address,
    required this.locationName,
    required this.category,
    required this.position,
    required this.distanceFromUser,
    required this.estimatedTime,
    this.roadAddress,
    this.phoneNumber,
    this.link,
    this.description,
  });
}

class POIController {
  String? _cachedClientId;
  String? _cachedClientSecret;
  String? _cachedApiKey;
  String? _cachedSecretKey;

  // API 키 초기화
  Future<bool> _initApiKeys() async {
    try {
      _cachedClientId = dotenv.env['NAVER_DEV_KEY'];
      _cachedClientSecret = dotenv.env['NAVER_DEV_SECRET_KEY'];
      _cachedApiKey = dotenv.env['NAVER_API_KEY'];
      _cachedSecretKey = dotenv.env['NAVER_SECRET_KEY'];

      if (_cachedClientId == null ||
          _cachedClientSecret == null ||
          _cachedApiKey == null ||
          _cachedSecretKey == null) {
        print('네이버 API 키가 설정되지 않았습니다.');
        return false;
      }
      return true;
    } catch (e) {
      print('API 키 초기화 오류: $e');
      return false;
    }
  }

  // 심볼 정보로부터 상가 정보 생성 (메인 메서드)
  Future<ClickedLocationInfo> createBusinessInfoFromSymbol(
    String businessName,
    NLatLng position,
    NLatLng? currentPosition,
  ) async {
    print('심볼 정보로 상가 정보 생성: $businessName');

    // 거리 및 시간 계산
    double distance = 0;
    String estimatedTime = "정보 없음";

    if (currentPosition != null) {
      distance = _calculateDistance(currentPosition, position);
      estimatedTime = _calculateWalkingTime(distance);
    }

    // 상가명으로 카테고리 추측
    final category = _guessCategory(businessName);

    // 정확한 주소 정보 가져오기
    final addressInfo = await _getAccurateAddress(position);

    // 기본 정보로 ClickedLocationInfo 생성
    final locationInfo = ClickedLocationInfo(
      address: addressInfo['address'] ?? "주소 정보 조회 중...",
      locationName: businessName,
      category: category,
      position: position,
      distanceFromUser: distance,
      estimatedTime: estimatedTime,
      roadAddress: addressInfo['roadAddress'],
    );

    return locationInfo;
  }

  // 개선된 정확한 주소 정보 가져오기
  Future<Map<String, String>> _getAccurateAddress(NLatLng position) async {
    bool keysInitialized = await _initApiKeys();
    if (!keysInitialized) {
      return {'address': '강원특별자치도 강릉시', 'roadAddress': ''};
    }

    try {
      // ✅ 공식 문서에 맞춘 올바른 URL 구성
      final coords = Uri.encodeComponent(
        '${position.longitude},${position.latitude}',
      );
      final url =
          'https://maps.apigw.ntruss.com/map-reversegeocode/v2/gc?'
          'coords=$coords&output=json&orders=legalcode%2Cadmcode%2Caddr%2Croadaddr';

      print('정확한 주소 조회 API 호출: $url');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              // ✅ 공식 문서와 동일한 헤더명 (소문자)
              'x-ncp-apigw-api-key-id': _cachedApiKey!,
              'x-ncp-apigw-api-key': _cachedSecretKey!,
              'Accept': 'application/json',
            },
          )
          .timeout(Duration(seconds: 8));

      print('주소 조회 응답 상태 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);

        print('주소 조회 응답 데이터: ${data.toString()}');

        if (data['results'] != null && data['results'].isNotEmpty) {
          return _parseAccurateAddressResponse(data);
        }
      } else {
        print('주소 조회 API 오류: ${response.statusCode}');
        print('응답 내용: ${response.body}');
      }

      return {'address': '강원특별자치도 강릉시', 'roadAddress': ''};
    } catch (e) {
      print('정확한 주소 조회 오류: $e');
      return {'address': '강원특별자치도 강릉시', 'roadAddress': ''};
    }
  }

  // 개선된 주소 응답 파싱
  Map<String, String> _parseAccurateAddressResponse(
    Map<String, dynamic> response,
  ) {
    try {
      final results = response['results'] as List;
      String address = '주소 정보 없음';
      String roadAddress = '';

      // 1순위: 도로명주소 찾기
      for (var result in results) {
        if (result['name'] == 'roadaddr' && result['region'] != null) {
          final region = result['region'];
          final land = result['land'];

          List<String> addressParts = [];

          // 시도 (area1)
          if (region['area1'] != null && region['area1']['name'] != null) {
            addressParts.add(region['area1']['name']);
          }

          // 시군구 (area2)
          if (region['area2'] != null && region['area2']['name'] != null) {
            addressParts.add(region['area2']['name']);
          }

          // 읍면동 (area3)
          if (region['area3'] != null && region['area3']['name'] != null) {
            addressParts.add(region['area3']['name']);
          }

          // 도로명 정보
          if (land != null) {
            if (land['name'] != null &&
                land['name'].toString().trim().isNotEmpty) {
              addressParts.add(land['name'].toString().trim());
            }

            // ✅ 개선된 건물번호 처리
            String buildingNumber = _buildAddressNumber(
              land['number1'],
              land['number2'],
            );
            if (buildingNumber.isNotEmpty) {
              addressParts.add(buildingNumber);
            }
          }

          roadAddress = addressParts.join(' ').trim();
          address = roadAddress;

          print('도로명주소 파싱 완료: $roadAddress');
          break;
        }
      }

      // 2순위: 지번주소 찾기 (도로명주소가 없는 경우)
      if (address == '주소 정보 없음') {
        for (var result in results) {
          if (result['name'] == 'addr' && result['region'] != null) {
            final region = result['region'];
            final land = result['land'];

            List<String> addressParts = [];

            // 시도
            if (region['area1'] != null && region['area1']['name'] != null) {
              addressParts.add(region['area1']['name']);
            }

            // 시군구
            if (region['area2'] != null && region['area2']['name'] != null) {
              addressParts.add(region['area2']['name']);
            }

            // 읍면동
            if (region['area3'] != null && region['area3']['name'] != null) {
              addressParts.add(region['area3']['name']);
            }

            // ✅ 개선된 지번 정보 처리
            if (land != null) {
              String landNumber = _buildAddressNumber(
                land['number1'],
                land['number2'],
              );
              if (landNumber.isNotEmpty) {
                addressParts.add(landNumber);
              }
            }

            address = addressParts.join(' ').trim();

            print('지번주소 파싱 완료: $address');
            break;
          }
        }
      }

      // 3순위: 법정동코드 기반 주소
      if (address == '주소 정보 없음') {
        for (var result in results) {
          if (result['name'] == 'legalcode' && result['region'] != null) {
            final region = result['region'];
            List<String> addressParts = [];

            if (region['area1'] != null && region['area1']['name'] != null) {
              addressParts.add(region['area1']['name']);
            }
            if (region['area2'] != null && region['area2']['name'] != null) {
              addressParts.add(region['area2']['name']);
            }
            if (region['area3'] != null && region['area3']['name'] != null) {
              addressParts.add(region['area3']['name']);
            }

            if (addressParts.isNotEmpty) {
              address = addressParts.join(' ').trim();
              print('법정동코드 파싱 완료: $address');
              break;
            }
          }
        }
      }

      return {
        'address': address != '주소 정보 없음' ? address : '강원특별자치도 강릉시',
        'roadAddress': roadAddress,
      };
    } catch (e) {
      print('정확한 주소 파싱 오류: $e');
      return {'address': '주소 확인 불가', 'roadAddress': ''};
    }
  }

  String _buildAddressNumber(dynamic number1, dynamic number2) {
    if (number1 == null) return '';

    String num1 = number1.toString().trim();
    if (num1.isEmpty || num1 == '0') return '';

    String result = num1;

    if (number2 != null) {
      String num2 = number2.toString().trim();
      // number2가 유효한 값인 경우에만 추가
      if (num2.isNotEmpty &&
          num2 != '0' &&
          num2 != 'null' &&
          num2 != '""' &&
          num2 != 'undefined') {
        result += '-$num2';
      }
    }

    return result;
  }

  // 상가명으로 카테고리 추측
  String _guessCategory(String businessName) {
    final name = businessName.toLowerCase();

    // 카페 관련 키워드
    if (name.contains('카페') ||
        name.contains('커피') ||
        name.contains('coffee') ||
        name.contains('스타벅스') ||
        name.contains('이디야') ||
        name.contains('투썸플레이스') ||
        name.contains('할리스') ||
        name.contains('빈스') ||
        name.contains('콩카페')) {
      return '카페';
    }

    // 음식점 관련 키워드
    if (name.contains('치킨') ||
        name.contains('피자') ||
        name.contains('족발') ||
        name.contains('보쌈') ||
        name.contains('찜닭') ||
        name.contains('국밥') ||
        name.contains('식당') ||
        name.contains('맛집') ||
        name.contains('음식점') ||
        name.contains('한식') ||
        name.contains('중식') ||
        name.contains('일식') ||
        name.contains('양식') ||
        name.contains('분식') ||
        name.contains('도시락') ||
        name.contains('김밥') ||
        name.contains('라면') ||
        name.contains('갈비') ||
        name.contains('떡볶이') ||
        name.contains('햄버거') ||
        name.contains('맥도날드') ||
        name.contains('버거킹') ||
        name.contains('롯데리아') ||
        name.contains('kfc') ||
        name.contains('bbq') ||
        name.contains('굽네치킨') ||
        name.contains('네네치킨')) {
      return '음식점';
    }

    // 편의점 관련 키워드
    if (name.contains('편의점') ||
        name.contains('gs25') ||
        name.contains('cu') ||
        name.contains('세븐일레븐') ||
        name.contains('이마트24') ||
        name.contains('7-eleven') ||
        name.contains('미니스톱')) {
      return '편의점';
    }

    // 마트 관련 키워드
    if (name.contains('마트') ||
        name.contains('슈퍼') ||
        name.contains('이마트') ||
        name.contains('홈플러스') ||
        name.contains('롯데마트') ||
        name.contains('하나로마트')) {
      return '마트';
    }

    // 병원 관련 키워드
    if (name.contains('병원') ||
        name.contains('의원') ||
        name.contains('클리닉') ||
        name.contains('한의원') ||
        name.contains('치과') ||
        name.contains('안과') ||
        name.contains('산부인과') ||
        name.contains('소아과') ||
        name.contains('내과') ||
        name.contains('외과')) {
      return '병원';
    }

    // 약국 관련 키워드
    if (name.contains('약국') ||
        name.contains('팜시') ||
        name.contains('pharmacy')) {
      return '약국';
    }

    // 은행 관련 키워드
    if (name.contains('은행') ||
        name.contains('농협') ||
        name.contains('신한') ||
        name.contains('우리') ||
        name.contains('하나') ||
        name.contains('국민') ||
        name.contains('기업') ||
        name.contains('씨티') ||
        name.contains('sc제일') ||
        name.contains('atm')) {
      return '은행';
    }

    // 주유소 관련 키워드
    if (name.contains('주유소') ||
        name.contains('gs칼텍스') ||
        name.contains('sk에너지') ||
        name.contains('현대오일뱅크') ||
        name.contains('s-oil')) {
      return '주유소';
    }

    // 숙박 관련 키워드
    if (name.contains('호텔') ||
        name.contains('모텔') ||
        name.contains('펜션') ||
        name.contains('리조트') ||
        name.contains('게스트하우스')) {
      return '숙박';
    }

    // 기본값
    return '상가';
  }

  // 클릭한 위치의 기본 정보 가져오기 (지도 터치용) - 이제 사용되지 않음
  Future<ClickedLocationInfo?> getLocationInfo(
    NLatLng clickedPosition,
    NLatLng? currentPosition,
  ) async {
    print(
      '일반 위치 정보 조회 시작: ${clickedPosition.latitude}, ${clickedPosition.longitude}',
    );

    try {
      // 정확한 주소 정보 가져오기
      final addressInfo = await _getAccurateAddress(clickedPosition);

      // 현재 위치에서의 거리 계산
      double distance = 0;
      String estimatedTime = "정보 없음";

      if (currentPosition != null) {
        distance = _calculateDistance(currentPosition, clickedPosition);
        estimatedTime = _calculateWalkingTime(distance);
      }

      return ClickedLocationInfo(
        address: addressInfo['address'] ?? '주소 정보 없음',
        locationName: '선택한 위치',
        category: '일반 위치',
        position: clickedPosition,
        distanceFromUser: distance,
        estimatedTime: estimatedTime,
        roadAddress: addressInfo['roadAddress'],
      );
    } catch (e) {
      print('위치 정보 조회 오류: $e');
      return _getMockLocationInfo(clickedPosition, currentPosition);
    }
  }

  // 상가 정보 조회 (심볼 기반)
  Future<ClickedLocationInfo?> getBusinessInfo(
    String businessName,
    NLatLng position,
    NLatLng? currentPosition,
  ) async {
    print('상가 정보 조회: $businessName');
    return await createBusinessInfoFromSymbol(
      businessName,
      position,
      currentPosition,
    );
  }

  // 좌표-주소 변환 (간단한 버전 - 호환성 유지)
  Future<String> getAddressFromCoords(NLatLng position) async {
    final addressInfo = await _getAccurateAddress(position);
    return addressInfo['address'] ?? '강원특별자치도 강릉시';
  }

  // 두 지점 간 거리 계산 (미터 단위)
  double _calculateDistance(NLatLng point1, NLatLng point2) {
    try {
      const double earthRadius = 6371000;
      final double lat1Rad = point1.latitude * (math.pi / 180);
      final double lat2Rad = point2.latitude * (math.pi / 180);
      final double dLat = (point2.latitude - point1.latitude) * (math.pi / 180);
      final double dLon =
          (point2.longitude - point1.longitude) * (math.pi / 180);

      final double a =
          math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(lat1Rad) *
              math.cos(lat2Rad) *
              math.sin(dLon / 2) *
              math.sin(dLon / 2);
      final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

      return earthRadius * c;
    } catch (e) {
      print('거리 계산 오류: $e');
      return 0;
    }
  }

  // 도보 시간 계산
  String _calculateWalkingTime(double distanceInMeters) {
    try {
      if (distanceInMeters < 1) return "0분";

      const double walkingSpeedMps = 1.4;
      final int timeInSeconds = (distanceInMeters / walkingSpeedMps).round();

      if (timeInSeconds < 60) {
        return "1분 미만";
      } else if (timeInSeconds < 3600) {
        final int minutes = (timeInSeconds / 60).round();
        return "도보 ${minutes}분";
      } else {
        final int hours = (timeInSeconds / 3600).floor();
        final int minutes = ((timeInSeconds % 3600) / 60).round();
        return "도보 ${hours}시간 ${minutes}분";
      }
    } catch (e) {
      print('도보 시간 계산 오류: $e');
      return "시간 정보 없음";
    }
  }

  // 거리를 읽기 쉬운 형태로 변환
  String formatDistance(double distanceInMeters) {
    try {
      if (distanceInMeters < 1000) {
        return "${distanceInMeters.round()}m";
      } else {
        double km = distanceInMeters / 1000;
        return "${km.toStringAsFixed(1)}km";
      }
    } catch (e) {
      return "거리 정보 없음";
    }
  }

  // 외부에서 사용할 수 있는 거리 계산 메서드
  double calculateDistance(NLatLng point1, NLatLng point2) {
    return _calculateDistance(point1, point2);
  }

  // 외부에서 사용할 수 있는 도보 시간 계산 메서드
  String calculateWalkingTime(double distanceInMeters) {
    return _calculateWalkingTime(distanceInMeters);
  }

  // 목업 데이터 생성
  ClickedLocationInfo _getMockLocationInfo(
    NLatLng clickedPosition,
    NLatLng? currentPosition,
  ) {
    double distance = 0;
    String estimatedTime = "정보 없음";

    if (currentPosition != null) {
      distance = _calculateDistance(currentPosition, clickedPosition);
      estimatedTime = _calculateWalkingTime(distance);
    }

    return ClickedLocationInfo(
      address: '강원특별자치도 강릉시 구정면',
      locationName: '선택한 위치',
      category: '일반 위치',
      position: clickedPosition,
      distanceFromUser: distance,
      estimatedTime: estimatedTime,
    );
  }
}
