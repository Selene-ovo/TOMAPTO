import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tomapto/controllers/search/search_main_controller.dart';
import 'package:tomapto/search/search_return.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:tomapto/pages/map/transit.dart';

class SearchMainPage extends StatefulWidget {
  final String initialSearchTerm;
  final String currentOriginPlace;
  final String currentDestinationPlace;
  final bool isSearchingOrigin;
  final NLatLng? currentOriginCoords;
  final NLatLng? currentDestinationCoords;

  const SearchMainPage({
    super.key,
    this.initialSearchTerm = '',
    this.currentOriginPlace = '위치 확인 중...',
    this.currentDestinationPlace = '도착지 입력',
    this.isSearchingOrigin = true,
    this.currentOriginCoords,
    this.currentDestinationCoords,
  });

  @override
  _SearchMainPageState createState() => _SearchMainPageState();
}

class _SearchMainPageState extends State<SearchMainPage>
    with SingleTickerProviderStateMixin {
  late SearchMainController _controller;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _controller = SearchMainController();

    _initializeController();
    _controller.searchController.addListener(_onSearchChanged);
    _setupEnterKeyHandler();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.requestFocus(context);
    });
  }

  void _setupEnterKeyHandler() {
    _controller.searchFocusNode.onKey = (node, event) {
      if (event.isKeyPressed(LogicalKeyboardKey.enter)) {
        _onSubmitted(_controller.searchController.text);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  Future<void> _initializeController() async {
    try {
      await _controller.initialize();

      if (widget.initialSearchTerm.isNotEmpty &&
          !_isDefaultText(widget.initialSearchTerm)) {
        _controller.searchController.text = widget.initialSearchTerm;
        _controller.onSearchChanged(widget.initialSearchTerm);
        setState(() {
          _isSearching = true;
        });
      } else {
        _controller.searchController.text = '';
        setState(() {
          _isSearching = false;
        });
      }
    } catch (e) {
      _showErrorSnackBar('초기화 중 오류가 발생했습니다: $e');
    }
  }

  bool _isDefaultText(String text) {
    return text == '출발지 입력' ||
        text == '도착지 입력' ||
        text == '위치 확인 중...' ||
        text == '위치 권한 없음' ||
        text == '위치 확인 실패';
  }

  void _onSearchChanged() {
    final query = _controller.searchController.text;
    setState(() {
      _isSearching = query.isNotEmpty;
    });

    if (query.isNotEmpty) {
      _controller.onSearchChanged(query);
    }
  }

  void _onSubmitted(String query) {
    if (query.isNotEmpty) {
      _controller.addToRecentSearches(query);
      _navigateToSearchResult(query);
    }
  }

  void _navigateToSearchResult(String query) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => SearchResultPage(
              searchTerm: query,
              currentOriginPlace: widget.currentOriginPlace,
              currentDestinationPlace: widget.currentDestinationPlace,
              isSearchingOrigin: widget.isSearchingOrigin,
              currentOriginCoords: widget.currentOriginCoords,
              currentDestinationCoords: widget.currentDestinationCoords,
            ),
      ),
    );
  }

  void _onCurrentLocationPressed() async {
    await _handleLocationRequest();
  }

  Future<void> _handleLocationRequest() async {
    try {
      _showLoadingDialog();
      await _controller.updateUserLocation();
      final position = await _controller.getCurrentPosition();

      if (!mounted) return;
      Navigator.pop(context);

      if (position != null) {
        await _processLocationSelection(position);
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

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }

  Future<void> _processLocationSelection(position) async {
    String locationName = _getLocationName();
    final currentLocation = NLatLng(position.latitude, position.longitude);

    if (widget.isSearchingOrigin) {
      _navigateToTransitAsOrigin(locationName, currentLocation);
    } else {
      _navigateToTransitAsDestination(locationName, currentLocation);
    }

    _controller.addToRecentSearches(locationName);
  }

  String _getLocationName() {
    String locationName = _controller.userLocationAddress ?? "현재 위치";

    if (locationName == "주소 확인 불가" ||
        locationName == "주소 변환 불가" ||
        locationName.isEmpty) {
      locationName = "현재 위치";
    }

    return locationName;
  }

  void _navigateToTransitAsOrigin(
    String locationName,
    NLatLng currentLocation,
  ) {
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
            ),
      ),
      (route) => false,
    );
  }

  void _navigateToTransitAsDestination(
    String locationName,
    NLatLng currentLocation,
  ) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder:
            (context) => TransitApp(
              initialOriginPlace:
                  widget.currentOriginPlace != '위치 확인 중...' &&
                          widget.currentOriginPlace != '위치 권한 없음' &&
                          widget.currentOriginPlace != '위치 확인 실패'
                      ? widget.currentOriginPlace
                      : null,
              initialDestinationPlace: locationName,
              initialDestinationCoords: currentLocation,
            ),
      ),
      (route) => false,
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

  @override
  void dispose() {
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
            _buildAppBar(),
            _buildCurrentLocationButton(),
            _buildAdvertisementBanner(),
            const Divider(height: 0, thickness: 1, color: Color(0xFFE2E2E2)),
            Expanded(
              child:
                  _isSearching ? _buildSearchResults() : _buildRecentSearches(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentLocationButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E2E2), width: 1)),
      ),
      child: InkWell(
        onTap: _onCurrentLocationPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.my_location_rounded,
                  color: Color(0xFF4C9EFC),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Consumer<SearchMainController>(
                      builder: (context, controller, child) {
                        String displayName = _getDisplayLocationName(
                          controller,
                        );
                        return Text(
                          displayName,
                          style: const TextStyle(
                            fontFamily: "Pretendard",
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF363636),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 2),
                    Consumer<SearchMainController>(
                      builder: (context, controller, child) {
                        String locationText = _getLocationStatusText(
                          controller,
                        );
                        return Text(
                          locationText,
                          style: const TextStyle(
                            fontFamily: "Pretendard",
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF727272),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF727272),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDisplayLocationName(SearchMainController controller) {
    String displayName = "현재 내 위치";

    if (controller.userLocationAddress != null &&
        controller.userLocationAddress!.isNotEmpty &&
        controller.userLocationAddress != '주소 확인 불가' &&
        controller.userLocationAddress != '주소 변환 불가') {
      displayName = controller.userLocationAddress!;
    }

    return displayName;
  }

  String _getLocationStatusText(SearchMainController controller) {
    String baseText = widget.isSearchingOrigin ? '출발지로 설정' : '도착지로 설정';

    if (controller.userPosition != null) {
      return baseText;
    } else {
      return '$baseText (위치 정보 없음)';
    }
  }

  Widget _buildAdvertisementBanner() {
    return SizedBox(
      width: double.infinity,
      height: 71,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: MediaQuery.of(context).size.width,
              height: 71,
              decoration: const BoxDecoration(color: Color(0xFFF0F0F0)),
            ),
          ),
          Positioned(
            left: 64,
            top: 0,
            child: Container(
              width: 272,
              height: 71,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/icons/adsense_banner.png"),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned(
            right: 11,
            top: 5,
            child: Container(
              width: 24,
              height: 18,
              decoration: ShapeDecoration(
                color: const Color(0xFFE2E2E2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              child: const Center(
                child: Text(
                  'AD',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF297DDD),
                    fontSize: 10,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
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
                  constraints: const BoxConstraints(),
                  onPressed: () => _controller.onBackPressed(context),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller.searchController,
                    focusNode: _controller.searchFocusNode,
                    cursorColor: const Color(0xFF4C9EFC),
                    cursorWidth: 2.0,
                    cursorHeight: 22.0,
                    decoration: InputDecoration(
                      hintText: '장소, 주소, 버스 검색',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontFamily: "Pretendard",
                        fontWeight: FontWeight.w500,
                        fontSize: 18,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                    style: const TextStyle(
                      color: Color(0xFF363636),
                      fontFamily: "Pretendard",
                      fontWeight: FontWeight.w500,
                      fontSize: 18,
                    ),
                    onSubmitted: _onSubmitted,
                  ),
                ),
                if (_controller.searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.grey,
                      size: 26,
                    ),
                    onPressed: _clearSearch,
                  ),
              ],
            ),
          ),
        ),
        Container(
          height: 0.6,
          width: double.infinity,
          color: const Color(0xFFE2E2E2),
        ),
      ],
    );
  }

  void _clearSearch() {
    _controller.searchController.clear();
    _controller.onSearchChanged("");
    setState(() {
      _isSearching = false;
    });
  }

  Widget _buildRecentSearches() {
    return Consumer<SearchMainController>(
      builder: (context, controller, child) {
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: controller.recentSearches.length,
          separatorBuilder:
              (context, index) =>
                  const Divider(height: 0, color: Color(0xFFE2E2E2)),
          itemBuilder: (context, index) {
            final item = controller.recentSearches[index];
            return _buildRecentSearchItem(item, index, controller);
          },
        );
      },
    );
  }

  Widget _buildRecentSearchItem(
    item,
    int index,
    SearchMainController controller,
  ) {
    return InkWell(
      onTap: () {
        controller.searchController.text = item.name;
        controller.onSearchChanged(item.name);
        _onSubmitted(item.name);
      },
      child: Container(
        height: 55,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Icon(
              Icons.location_on_rounded,
              color: Color(0xFF727272),
              size: 22,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(
                  fontFamily: "Pretendard",
                  fontWeight: FontWeight.w400,
                  fontSize: 18,
                  color: Color(0xFF363636),
                ),
              ),
            ),
            Text(
              item.date,
              style: const TextStyle(
                fontFamily: "Pretendard",
                color: Color(0xFF727272),
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                controller.removeRecentSearch(index);
              },
              child: const Icon(
                Icons.close_rounded,
                size: 18,
                color: Color(0xFF727272),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Consumer<SearchMainController>(
      builder: (context, controller, child) {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.errorMessage != null) {
          return Center(
            child: Text(
              controller.errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (controller.searchResults.isEmpty) {
          return const Center(child: Text('검색 결과가 없습니다'));
        }

        final searchTerm = controller.searchController.text.toLowerCase();

        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: controller.searchResults.length,
          separatorBuilder:
              (context, index) =>
                  const Divider(height: 0, color: Color(0xFFE2E2E2)),
          itemBuilder: (context, index) {
            final result = controller.searchResults[index];
            return _buildSearchResultItem(result, searchTerm);
          },
        );
      },
    );
  }

  Widget _buildSearchResultItem(result, String searchTerm) {
    return ListTile(
      leading: const Icon(Icons.location_on_rounded, color: Color(0xFF727272)),
      title: _buildHighlightedText(result.name, searchTerm),
      subtitle: Text(
        result.address,
        style: const TextStyle(
          color: Color(0xFF727272),
          fontFamily: "Pretendard",
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            result.category.isNotEmpty ? result.category : '기타',
            style: const TextStyle(
              color: Color(0xFF727272),
              fontFamily: "Pretendard",
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${result.distance.toStringAsFixed(1)}km',
            style: const TextStyle(
              color: Color(0xFF727272),
              fontFamily: "Pretendard",
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
      onTap: () => _navigateToSearchResult(result.name),
    );
  }

  Widget _buildHighlightedText(String text, String searchTerm) {
    if (searchTerm.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          color: Color(0xFF363636),
          fontFamily: "Pretendard",
          fontWeight: FontWeight.w500,
          fontSize: 18,
        ),
      );
    }

    final lowerText = text.toLowerCase();

    if (!lowerText.contains(searchTerm)) {
      return Text(
        text,
        style: const TextStyle(
          color: Color(0xFF363636),
          fontFamily: "Pretendard",
          fontWeight: FontWeight.w500,
          fontSize: 18,
        ),
      );
    }

    final start = lowerText.indexOf(searchTerm);
    final end = start + searchTerm.length;

    return RichText(
      text: TextSpan(
        children: [
          if (start > 0)
            TextSpan(
              text: text.substring(0, start),
              style: const TextStyle(
                color: Color(0xFF363636),
                fontFamily: "Pretendard",
                fontWeight: FontWeight.w500,
                fontSize: 18,
              ),
            ),
          TextSpan(
            text: text.substring(start, end),
            style: const TextStyle(
              color: Color(0xFF4C9EFC),
              fontFamily: "Pretendard",
              fontWeight: FontWeight.w500,
              fontSize: 18,
            ),
          ),
          if (end < text.length)
            TextSpan(
              text: text.substring(end),
              style: const TextStyle(
                color: Color(0xFF363636),
                fontFamily: "Pretendard",
                fontWeight: FontWeight.w500,
                fontSize: 18,
              ),
            ),
        ],
      ),
    );
  }
}
