import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'category_kakao_rest_api.dart'; // 위에서 만든 서비스 import

class CategoryController extends ChangeNotifier {
  // 로딩 상태
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  set isLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // 에러 메시지
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  set errorMessage(String? value) {
    _errorMessage = value;
    notifyListeners();
  }

  // 검색 결과
  List<KakaoPlace> _places = [];
  List<KakaoPlace> get places => _places;
  set places(List<KakaoPlace> value) {
    _places = value;
    notifyListeners();
  }

  // 사용자 현재 위치
  Position? userPosition;

  // 선택된 카테고리
  String? _selectedCategory;
  String? get selectedCategory => _selectedCategory;

  // 초기화 - 사용자 위치 가져오기
  Future<void> initialize() async {
    try {
      userPosition = await _getCurrentPosition();
      print(
        '사용자 위치 초기화 완료: ${userPosition?.latitude}, ${userPosition?.longitude}',
      );
    } catch (e) {
      print('위치 정보를 가져오는데 실패했습니다: $e');
      errorMessage = '위치 정보를 가져올 수 없습니다. GPS를 확인해주세요.';
    }
  }

  // 카테고리별 장소 검색
  Future<void> searchByCategory(String category) async {
    if (userPosition == null) {
      errorMessage = '위치 정보가 없습니다. GPS를 확인해주세요.';
      return;
    }

    isLoading = true;
    errorMessage = null;
    _selectedCategory = category;

    try {
      final results = await KakaoMapService.searchByCategory(
        category: category,
        latitude: userPosition!.latitude,
        longitude: userPosition!.longitude,
        radius: 20000, // 20km 반경
        size: 15,
      );

      places = results;

      print('$category 검색 결과: ${results.length}개');
      if (results.isNotEmpty) {
        print(
          '가장 가까운 결과: ${results.first.placeName} (${results.first.distanceKm.toStringAsFixed(1)}km)',
        );
      }
    } catch (e) {
      errorMessage = '검색 중 오류가 발생했습니다: $e';
      places = [];
      print('카테고리 검색 오류: $e');
    } finally {
      isLoading = false;
    }
  }

  // 현재 위치 가져오기
  Future<Position> _getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('위치 서비스가 비활성화되어 있습니다.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('위치 권한이 거부되었습니다.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // 장소 상세 정보로 이동
  void goToPlaceDetail(KakaoPlace place) {
    // 지도에서 해당 위치로 이동하거나 상세 페이지로 이동
    print('장소 상세로 이동: ${place.placeName}');
  }

  // 전화걸기
  void callPlace(String? phoneNumber) {
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      // url_launcher 사용해서 전화걸기
      print('전화걸기: $phoneNumber');
    }
  }

  // 길찾기
  void navigateToPlace(KakaoPlace place) {
    // 지도 앱으로 길찾기 또는 내부 네비게이션
    print('길찾기: ${place.placeName} (${place.latitude}, ${place.longitude})');
  }

  @override
  void dispose() {
    super.dispose();
  }
}

// 카테고리 아이템 클래스
class CategoryItem {
  final String title;
  final String imagePath;
  final VoidCallback onTap;

  CategoryItem({
    required this.title,
    required this.imagePath,
    required this.onTap,
  });
}
