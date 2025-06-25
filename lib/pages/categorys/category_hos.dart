import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tomapto/controllers/category/category_controller.dart';
import 'package:tomapto/controllers/category/category_kakao_rest_api.dart';
import 'package:tomapto/pages/map/transit.dart';

class CategoryHosPage extends StatefulWidget {
  const CategoryHosPage({super.key});

  @override
  State<CategoryHosPage> createState() => _CategoryHosPageState();
}

class _CategoryHosPageState extends State<CategoryHosPage> {
  final CategoryController _categoryController = CategoryController();

  bool _isLoading = true;
  String? _errorMessage;
  List<KakaoPlace> _hospitalResults = [];
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _initializeAndSearch();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _initializeAndSearch() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      await _categoryController.initialize();
      _userPosition = _categoryController.userPosition;

      if (_userPosition != null) {
        await _searchNearbyHospitals();
      } else {
        setState(() {
          _errorMessage = '현재 위치를 가져올 수 없습니다.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '병원 검색 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _searchNearbyHospitals() async {
    try {
      final results = await KakaoMapService.searchByCategory(
        category: '병원',
        latitude: _userPosition!.latitude,
        longitude: _userPosition!.longitude,
        radius: 20000,
        size: 15,
      );

      print('병원 검색 결과: ${results.length}개');

      setState(() {
        _hospitalResults = results;
        _isLoading = false;
      });

      if (results.isNotEmpty) {
        print(
          '가장 가까운 병원: ${results.first.placeName} (${results.first.distanceKm.toStringAsFixed(1)}km)',
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = '병원 검색 실패: $e';
        _isLoading = false;
      });
    }
  }

  void _navigateToPlace(KakaoPlace place) async {
    if (_userPosition == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('현재 위치 정보가 없습니다.')));
      return;
    }

    try {
      final originCoords = NLatLng(
        _userPosition!.latitude,
        _userPosition!.longitude,
      );
      final destinationCoords = NLatLng(place.latitude, place.longitude);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => TransitApp(
                initialOriginPlace: '현재 위치',
                initialDestinationPlace: place.placeName,
                initialOriginCoords: originCoords,
                initialDestinationCoords: destinationCoords,
              ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('길찾기 중 오류가 발생했습니다: $e')));
    }
  }

  void _callPlace(String? phoneNumber) {
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      print('전화걸기: $phoneNumber');
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('전화번호 정보가 없습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black,
            size: 20 * (screenWidth / 375),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '주변 병원',
          style: TextStyle(
            fontSize: 20 * (screenWidth / 375),
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontFamily: 'Pretendard',
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(screenWidth, screenHeight),
    );
  }

  Widget _buildBody(double screenWidth, double screenHeight) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontFamily: 'Pretendard',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeAndSearch,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_hospitalResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_hospital_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '주변에 병원이 없습니다.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontFamily: 'Pretendard',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeAndSearch,
              child: const Text('다시 검색'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _initializeAndSearch,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16 * (screenWidth / 375)),
        itemCount: _hospitalResults.length,
        itemBuilder: (context, index) {
          final place = _hospitalResults[index];
          return _buildHospitalCard(place, screenWidth, screenHeight);
        },
      ),
    );
  }

  Widget _buildHospitalCard(
    KakaoPlace place,
    double screenWidth,
    double screenHeight,
  ) {
    return Card(
      margin: EdgeInsets.only(bottom: 12 * (screenHeight / 812)),
      elevation: 0.3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: Padding(
        padding: EdgeInsets.all(16 * (screenWidth / 375)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              place.placeName,
              style: TextStyle(
                fontSize: 18 * (screenWidth / 375),
                fontWeight: FontWeight.w600,
                color: Color(0xFF363636),
                fontFamily: 'Pretendard',
              ),
            ),
            SizedBox(height: 8 * (screenHeight / 812)),
            Row(
              children: [
                Expanded(
                  child: Text(
                    place.roadAddressName.isNotEmpty
                        ? place.roadAddressName
                        : place.addressName,
                    style: TextStyle(
                      fontSize: 14 * (screenWidth / 375),
                      color: Colors.grey[600],
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4 * (screenHeight / 812)),
            Row(
              children: [
                Text(
                  '${place.distanceKm.toStringAsFixed(1)}km',
                  style: TextStyle(
                    fontSize: 14 * (screenWidth / 375),
                    color: Color(0xFF363636),
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Pretendard',
                  ),
                ),
              ],
            ),
            SizedBox(height: 12 * (screenHeight / 812)),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToPlace(place),
                    icon: Icon(
                      Icons.directions,
                      size: 18 * (screenWidth / 375),
                    ),
                    label: Text(
                      '길찾기',
                      style: TextStyle(
                        fontSize: 14 * (screenWidth / 375),
                        fontFamily: 'Pretendard',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF02A76A),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: 8 * (screenHeight / 812),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8 * (screenWidth / 375)),
                if (place.phone != null && place.phone!.isNotEmpty)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _callPlace(place.phone),
                      icon: Icon(
                        Icons.phone,
                        size: 18 * (screenWidth / 375),
                        color: Colors.green,
                      ),
                      label: Text(
                        '전화',
                        style: TextStyle(
                          fontSize: 14 * (screenWidth / 375),
                          color: Colors.green,
                          fontFamily: 'Pretendard',
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green),
                        padding: EdgeInsets.symmetric(
                          vertical: 8 * (screenHeight / 812),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
