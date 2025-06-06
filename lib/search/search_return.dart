import 'package:flutter/material.dart';
import 'package:tomapto/controllers/search/search_main_controller.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:tomapto/pages/map/transit.dart';
import 'package:tomapto/search/search_main.dart';

class SearchResultPage extends StatefulWidget {
  final String searchTerm;
  final String currentOriginPlace;
  final String currentDestinationPlace;
  final bool isSearchingOrigin;
  final NLatLng? currentOriginCoords;
  final NLatLng? currentDestinationCoords;

  const SearchResultPage({
    super.key,
    required this.searchTerm,
    required this.currentOriginPlace,
    required this.currentDestinationPlace,
    required this.isSearchingOrigin,
    this.currentOriginCoords,
    this.currentDestinationCoords,
  });

  @override
  _SearchResultPageState createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> {
  late SearchMainController _controller;
  List<SearchResult> searchResults = [];
  String sortOption = '내 위치 중심';
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = SearchMainController();
    _initializeAndSearch();
  }

  bool _isDefaultText(String text) {
    return text == '출발지 입력' ||
        text == '도착지 입력' ||
        text == '위치 확인 중...' ||
        text == '위치 권한 없음' ||
        text == '위치 확인 실패';
  }

  Future<void> _initializeAndSearch() async {
    try {
      await _controller.initialize();

      if (!_isDefaultText(widget.searchTerm)) {
        await _performSearch(widget.searchTerm);
      } else {
        setState(() {
          isLoading = false;
          searchResults = [];
          errorMessage = null;
        });
      }
    } catch (e) {
      _handleError('검색 중 오류가 발생했습니다: $e');
    }
  }

  void _handleError(String message) {
    setState(() {
      errorMessage = message;
      isLoading = false;
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      _controller.searchController.text = query;
      _controller.onSearchChanged(query);
      _controller.addListener(_onControllerUpdate);
    } catch (e) {
      _handleError('검색 중 오류가 발생했습니다: $e');
    }
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {
        isLoading = _controller.isLoading;
        searchResults = _controller.searchResults;
        errorMessage = _controller.errorMessage;
      });
    }
  }

  void _sortByDistance() {
    setState(() {
      searchResults.sort((a, b) => a.distance.compareTo(b.distance));
    });
  }

  Future<void> _onCurrentLocationPressed() async {
    try {
      _showLoadingDialog();

      await _controller.updateUserLocation();
      final position = await _controller.getCurrentPosition();

      Navigator.pop(context);

      if (position != null) {
        String locationName = _getLocationDisplayName();
        final currentLocation = NLatLng(position.latitude, position.longitude);

        _navigateToTransitApp(locationName, currentLocation);
        _controller.addToRecentSearches(locationName);
      } else {
        _showErrorSnackBar('현재 위치를 가져올 수 없습니다. 위치 권한을 확인해주세요.');
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showErrorSnackBar('위치 정보를 가져오는 중 오류가 발생했습니다: $e');
    }
  }

  String _getLocationDisplayName() {
    String locationName = _controller.userLocationAddress ?? "현재 위치";

    if (locationName == "주소 확인 불가" ||
        locationName == "주소 변환 불가" ||
        locationName.isEmpty) {
      locationName = "현재 위치";
    }

    return locationName;
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: "Pretendard"),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _navigateToTransitApp(String locationName, NLatLng currentLocation) {
    if (widget.isSearchingOrigin) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder:
              (context) => TransitApp(
                initialOriginPlace: locationName,
                initialOriginCoords: currentLocation,
                initialDestinationPlace:
                    widget.currentDestinationPlace != '도착지 입력'
                        ? widget.currentDestinationPlace
                        : null,
                initialDestinationCoords: widget.currentDestinationCoords,
              ),
        ),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder:
              (context) => TransitApp(
                initialOriginPlace: _getValidOriginPlace(),
                initialOriginCoords: widget.currentOriginCoords,
                initialDestinationPlace: locationName,
                initialDestinationCoords: currentLocation,
              ),
        ),
        (route) => false,
      );
    }
  }

  String? _getValidOriginPlace() {
    return widget.currentOriginPlace != '위치 확인 중...' &&
            widget.currentOriginPlace != '위치 권한 없음' &&
            widget.currentOriginPlace != '위치 확인 실패' &&
            widget.currentOriginPlace != '출발지 입력'
        ? widget.currentOriginPlace
        : null;
  }

  void _setAsOrigin(SearchResult result) {
    final originCoords = NLatLng(result.mapy, result.mapx);

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder:
            (context) => TransitApp(
              initialOriginPlace: result.name,
              initialOriginCoords: originCoords,
              initialDestinationPlace:
                  widget.currentDestinationPlace != '도착지 입력'
                      ? widget.currentDestinationPlace
                      : null,
              initialDestinationCoords: widget.currentDestinationCoords,
            ),
      ),
      (route) => false,
    );
  }

  void _setAsDestination(SearchResult result) {
    final destinationCoords = NLatLng(result.mapy, result.mapx);

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder:
            (context) => TransitApp(
              initialOriginPlace: _getValidOriginPlace(),
              initialOriginCoords: widget.currentOriginCoords,
              initialDestinationPlace: result.name,
              initialDestinationCoords: destinationCoords,
            ),
      ),
      (route) => false,
    );
  }

  void _selectSearchResult(SearchResult result) {
    if (widget.isSearchingOrigin) {
      _setAsOrigin(result);
    } else {
      _setAsDestination(result);
    }
  }

  void _onClosePressed() {
    _controller.searchController.clear();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => SearchMainPage(
              initialSearchTerm: '',
              currentOriginPlace: widget.currentOriginPlace,
              currentDestinationPlace: widget.currentDestinationPlace,
              isSearchingOrigin: widget.isSearchingOrigin,
            ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        body: Column(
          children: [
            _buildAppBar(context),
            _buildSortOptions(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            errorMessage!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (searchResults.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 20),
          _buildCurrentLocationOption(),
          const Divider(height: 1, color: Color(0xFFE2E2E2)),
          const Expanded(
            child: Center(child: Text('검색 결과가 없습니다. 다른 검색어를 입력해보세요.')),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildCurrentLocationOption(),
        const Divider(height: 1, color: Color(0xFFE2E2E2)),
        Expanded(child: _buildSearchResultsList()),
      ],
    );
  }

  Widget _buildCurrentLocationOption() {
    return GestureDetector(
      onTap: _onCurrentLocationPressed,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            const SizedBox(width: 100),
            Text(
              '현재위치 ',
              style: const TextStyle(
                fontFamily: "Pretendard",
                color: Color(0xFF363636),
                fontWeight: FontWeight.w400,
                fontSize: 18,
              ),
            ),
            Expanded(
              child: Consumer<SearchMainController>(
                builder: (context, controller, child) {
                  String displayName = _getLocationDisplayName();
                  return Text(
                    displayName,
                    style: const TextStyle(
                      fontFamily: "Pretendard",
                      color: Color(0xFF363636),
                      fontWeight: FontWeight.w400,
                      fontSize: 18,
                    ),
                  );
                },
              ),
            ),
            Text(
              widget.isSearchingOrigin ? '출발' : '도착',
              style: const TextStyle(
                fontFamily: "Pretendard",
                color: Color(0xFF727272),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Column(
      children: [
        SafeArea(
          child: Container(
            decoration: const BoxDecoration(color: Colors.white),
            height: 50,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.keyboard_arrow_left_rounded,
                    size: 36,
                    color: Color(0xFF363636),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    widget.searchTerm,
                    style: const TextStyle(
                      color: Color(0xFF363636),
                      fontFamily: "Pretendard",
                      fontWeight: FontWeight.w500,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.grey,
                    size: 26,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  onPressed: _onClosePressed,
                ),
              ],
            ),
          ),
        ),
        Container(
          height: 0.6,
          width: double.infinity,
          color: Color(0xFFE2E2E2),
        ),
      ],
    );
  }

  Widget _buildSortOptions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [_buildSortButton('거리순', Icons.arrow_drop_down)]),
    );
  }

  Widget _buildSortButton(String text, IconData icon) {
    final isSelected = sortOption == text;
    return InkWell(
      onTap: () {
        setState(() {
          sortOption = text;
          if (text == '거리순') {
            _sortByDistance();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                fontFamily: "Pretendard",
                color: isSelected ? Color(0xFF0771EB) : Color(0xFF363636),
                fontWeight: FontWeight.w500,
              ),
            ),
            Icon(
              icon,
              color: isSelected ? Color(0xFF0771EB) : Color(0xFF363636),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsList() {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: searchResults.length,
      separatorBuilder:
          (context, index) =>
              const Divider(height: 1, color: Color(0xFFE2E2E2)),
      itemBuilder: (context, index) {
        final result = searchResults[index];
        return GestureDetector(
          onTap: () => _selectSearchResult(result),
          child: Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    result.name,
                                    style: const TextStyle(
                                      fontFamily: "Pretendard",
                                      color: Color(0xFF0771EB),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 18,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    result.category.isNotEmpty
                                        ? result.category
                                        : '기타',
                                    style: TextStyle(
                                      fontFamily: "Pretendard",
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F8FF),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF4C9EFC),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    '${result.distance.toStringAsFixed(1)}km',
                                    style: const TextStyle(
                                      fontFamily: "Pretendard",
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Color(0xFF4C9EFC),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    result.address,
                                    style: TextStyle(
                                      fontFamily: "Pretendard",
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      _buildActionButton(
                        '도착',
                        Color(0xFF0771EB),
                        Icons.directions,
                        onPressed: () => _setAsDestination(result),
                      ),
                      const SizedBox(width: 8),
                      _buildActionButton(
                        '출발',
                        Colors.white,
                        Icons.place_rounded,
                        borderColor: Color(0xFF0771EB),
                        textColor: Color(0xFF0771EB),
                        onPressed: () => _setAsOrigin(result),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(
    String text,
    Color color,
    IconData icon, {
    Color textColor = Colors.white,
    Color borderColor = Colors.transparent,
    VoidCallback? onPressed,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(32),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 0.6),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Text(
            text,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
