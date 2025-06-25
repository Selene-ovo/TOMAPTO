import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tomapto/controllers/category/category_controller.dart';
import 'package:tomapto/controllers/category/category_kakao_rest_api.dart';
import 'package:tomapto/pages/map/transit.dart';

class CategoryStorePage extends StatefulWidget {
  const CategoryStorePage({super.key});

  @override
  State<CategoryStorePage> createState() => _CategoryStorePageState();
}

class _CategoryStorePageState extends State<CategoryStorePage> {
  final CategoryController _categoryController = CategoryController();

  bool _isLoading = true;
  String? _errorMessage;
  List<KakaoPlace> _storeResults = [];
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
        await _searchNearbyStores();
      } else {
        setState(() {
          _errorMessage = '현재 위치를 가져올 수 없습니다.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '편의점 검색 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _searchNearbyStores() async {
    try {
      final results = await KakaoMapService.searchByCategory(
        category: '편의점',
        latitude: _userPosition!.latitude,
        longitude: _userPosition!.longitude,
        radius: 15000, // 15km 반경
        size: 15,
      );

      print('편의점 검색 결과: ${results.length}개');

      setState(() {
        _storeResults = results;
        _isLoading = false;
      });

      if (results.isNotEmpty) {
        print(
          '가장 가까운 편의점: ${results.first.placeName} (${results.first.distanceKm.toStringAsFixed(1)}km)',
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = '편의점 검색 실패: $e';
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
          '주변 편의점',
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

    if (_storeResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '주변에 편의점이 없습니다.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontFamily: 'Pretendard',
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16 * (screenWidth / 375)),
      itemCount: _storeResults.length,
      itemBuilder: (context, index) {
        final store = _storeResults[index];
        return _buildStoreCard(store, screenWidth, screenHeight);
      },
    );
  }

  Widget _buildStoreCard(
    KakaoPlace store,
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
              store.placeName,
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
                    store.roadAddressName.isNotEmpty
                        ? store.roadAddressName
                        : store.addressName,
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
                  '${store.distanceKm.toStringAsFixed(1)}km',
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
                    onPressed: () => _navigateToPlace(store),
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

                // 24시간 운영 여부 표시 (임시)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20 * (screenWidth / 375),
                    vertical: 10 * (screenHeight / 812),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '24시간',
                    style: TextStyle(
                      fontSize: 12 * (screenWidth / 375),
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Pretendard',
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
