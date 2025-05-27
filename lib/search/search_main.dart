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
  final String currentOriginPlace; // 현재 출발지
  final String currentDestinationPlace; // 현재 도착지
  final bool isSearchingOrigin; // 출발지 검색인지 도착지 검색인지 구분

  const SearchMainPage({
    super.key,
    this.initialSearchTerm = '',
    this.currentOriginPlace = '위치 확인 중...',
    this.currentDestinationPlace = '도착지 입력',
    this.isSearchingOrigin = true,
  });

  @override
  _SearchMainPageState createState() => _SearchMainPageState();
}

class _SearchMainPageState extends State<SearchMainPage>
    with SingleTickerProviderStateMixin {
  late SearchMainController _controller;
  bool _isSearching = false;

  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _controller = SearchMainController();

    // 위치 정보를 먼저 초기화하고 검색 수행
    _initializeController();

    _tabController = TabController(length: 2, vsync: this);

    _controller.searchController.addListener(_onSearchChanged);

    // 엔터 키 입력 처리 추가
    _controller.searchFocusNode.onKey = (node, event) {
      if (event.isKeyPressed(LogicalKeyboardKey.enter)) {
        _onSubmitted(_controller.searchController.text);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.requestFocus(context);
    });
  }

  // 컨트롤러 초기화 및 초기 검색어 처리
  Future<void> _initializeController() async {
    // 위치 정보 초기화 (중요: 검색 전에 반드시 실행)
    await _controller.initialize();

    // 초기 검색어가 있는 경우 검색 수행
    if (widget.initialSearchTerm.isNotEmpty) {
      _controller.searchController.text = widget.initialSearchTerm;
      _controller.onSearchChanged(widget.initialSearchTerm);
      setState(() {
        _isSearching = true;
      });
    }
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

  // 검색어 입력 후 Enter 키 처리
  void _onSubmitted(String query) {
    if (query.isNotEmpty) {
      // 최근 검색어에 추가
      _controller.addToRecentSearches(query);

      // 검색 결과 페이지로 이동 (현재 출발지/도착지 정보도 함께 전달)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => SearchResultPage(
                searchTerm: query,
                currentOriginPlace: widget.currentOriginPlace,
                currentDestinationPlace: widget.currentDestinationPlace,
                isSearchingOrigin: widget.isSearchingOrigin,
              ),
        ),
      );
    }
  }

  // 현재 내 위치 버튼 클릭 처리 - 위치 갱신 추가
  void _onCurrentLocationPressed() async {
    try {
      // 로딩 상태 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // 최신 위치 정보로 업데이트
      await _controller.updateUserLocation();

      // 현재 위치 가져오기
      final position = await _controller.getCurrentPosition();

      // 로딩 다이얼로그 닫기
      Navigator.pop(context);

      if (position != null) {
        // 좌표값을 직접 사용하여 길찾기 페이지로 이동
        final currentLocation = NLatLng(position.latitude, position.longitude);

        if (widget.isSearchingOrigin) {
          // 출발지로 설정 - 좌표와 함께 전달
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder:
                  (context) => TransitApp(
                    initialOriginPlace: "현재 위치", // 표시용 텍스트
                    initialOriginCoords: currentLocation, // 실제 좌표 전달
                    initialDestinationPlace:
                        widget.currentDestinationPlace != '도착지 입력'
                            ? widget.currentDestinationPlace
                            : null,
                  ),
            ),
            (route) => false,
          );
        } else {
          // 도착지로 설정 - 좌표와 함께 전달
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
                    initialDestinationPlace: "현재 위치", // 표시용 텍스트
                    initialDestinationCoords: currentLocation, // 실제 좌표 전달
                  ),
            ),
            (route) => false,
          );
        }

        // 최근 검색어에 추가
        _controller.addToRecentSearches("현재 위치");
      } else {
        // 위치 정보를 가져올 수 없는 경우
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '현재 위치를 가져올 수 없습니다. 위치 권한을 확인해주세요.',
              style: TextStyle(fontFamily: "Pretendard"),
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // 로딩 다이얼로그가 열려있으면 닫기
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '위치 정보를 가져오는 중 오류가 발생했습니다: $e',
            style: const TextStyle(fontFamily: "Pretendard"),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ChangeNotifier를 사용하기 위해 _controller를 Provider로 감싸기
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        body: Column(
          children: [
            _buildAppBar(),
            // 현재 내 위치 버튼 추가
            _buildCurrentLocationButton(),
            SizedBox(
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
                      decoration: BoxDecoration(color: const Color(0xFFF0F0F0)),
                    ),
                  ),
                  Positioned(
                    left: 64,
                    top: 0,
                    child: Container(
                      width: 272,
                      height: 71,
                      decoration: BoxDecoration(
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
                      child: Center(
                        child: Text(
                          'AD',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF297DDD),
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
            ),
            if (!_isSearching) _buildTabBar(),
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

  // 현재 내 위치 버튼 위젯
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E2E2), width: 1),
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
                    Text(
                      '현재 내 위치',
                      style: TextStyle(
                        fontFamily: "Pretendard",
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF363636),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Consumer<SearchMainController>(
                      builder: (context, controller, child) {
                        String locationText = '';
                        if (controller.userPosition != null) {
                          if (controller.userLocationAddress != null &&
                              controller.userLocationAddress!.isNotEmpty &&
                              controller.userLocationAddress != '주소 확인 불가') {
                            locationText =
                                '${widget.isSearchingOrigin ? '출발지로 설정' : '도착지로 설정'} (${controller.userLocationAddress})';
                          } else {
                            locationText =
                                '${widget.isSearchingOrigin ? '출발지로 설정' : '도착지로 설정'} (${controller.userPosition!.latitude.toStringAsFixed(4)}, ${controller.userPosition!.longitude.toStringAsFixed(4)})';
                          }
                        } else {
                          locationText =
                              '${widget.isSearchingOrigin ? '출발지로 설정' : '도착지로 설정'} (위치 정보 없음)';
                        }

                        return Text(
                          locationText,
                          style: TextStyle(
                            fontFamily: "Pretendard",
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF727272),
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

  // Widget _buildAppBar()를 수정합니다
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
                  padding: EdgeInsets.zero, // 패딩 제거하여 정확한 터치 영역 설정
                  constraints: BoxConstraints(),
                  onPressed: () => _controller.onBackPressed(context),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller.searchController,
                    focusNode: _controller.searchFocusNode,
                    cursorColor: Color(0xFF4C9EFC),
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
                    // 엔터 키 이벤트 추가
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
                    onPressed: () {
                      _controller.searchController.clear();
                      _controller.onSearchChanged("");
                      setState(() {
                        _isSearching = false;
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
        Container(
          height: 0.6,
          width: double.infinity,
          color: Color(0xFFE2E2E2), // 테마 색상 사용 또는 직접 색상 지정
        ),
      ],
    );
  }

  // 탭바 구현 (최근 기록 / 즐겨찾기)
  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      padding: EdgeInsets.zero,
      labelColor: Color(0xFF363636),
      unselectedLabelColor: Colors.grey,
      indicatorColor: Color(0xFFFB233B),
      // 선택된 탭의 텍스트 스타일 지정
      labelStyle: TextStyle(
        fontFamily: "Pretendard",
        fontWeight: FontWeight.w700,
        fontSize: 18,
      ),
      // 선택되지 않은 탭의 텍스트 스타일 지정
      unselectedLabelStyle: TextStyle(
        fontFamily: "Pretendard",
        fontWeight: FontWeight.w500,
        fontSize: 18,
      ),
      // insets를 조절하여 인디케이터 가로 크기 변경
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(width: 3.0, color: Color(0xFFFB233B)),
        // 가로 여백을 조절하여 인디케이터 길이 조절
        insets: EdgeInsets.symmetric(horizontal: 138.0), // 값이 클수록 인디케이터가 짧아짐
      ),
      overlayColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.hovered))
          return Color(0xFFE2E2E2).withOpacity(0.5);
        if (states.contains(WidgetState.focused) ||
            states.contains(WidgetState.pressed))
          return Color(0xFFE2E2E2).withOpacity(0.5);
        return null;
      }),
      tabs: const [Tab(text: '최근 기록'), Tab(text: '즐겨찾기')],
    );
  }

  // 최근 검색 기록 목록 구현
  Widget _buildRecentSearches() {
    return TabBarView(
      controller: _tabController,
      children: [
        // 최근 기록 탭
        Consumer<SearchMainController>(
          builder: (context, controller, child) {
            return ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: controller.recentSearches.length,
              separatorBuilder:
                  (context, index) =>
                      const Divider(height: 0, color: Color(0xFFE2E2E2)),
              itemBuilder: (context, index) {
                final item = controller.recentSearches[index];
                return InkWell(
                  onTap: () {
                    // 최근 검색어 탭
                    controller.searchController.text = item.name;
                    controller.onSearchChanged(item.name);
                    _onSubmitted(item.name); // 검색 결과 페이지로 바로 이동
                  },
                  child: Container(
                    height: 55, // 원하는 높이로 직접 지정 가능 (더 줄이려면 이 값을 줄이세요)
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFF727272),
                          size: 22,
                        ),
                        SizedBox(width: 18),
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              fontFamily: "Pretendard",
                              fontWeight: FontWeight.w400,
                              fontSize: 18,
                              color: Color(0xFF363636),
                            ),
                          ),
                        ),
                        Text(
                          item.date,
                          style: TextStyle(
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
              },
            );
          },
        ),

        // 즐겨찾기 탭 (비어있음)
        const Center(child: Text('즐겨찾기가 없습니다')),
      ],
    );
  }

  // 검색 결과 표시 - 사용자 위치 기준으로 정렬됨
  // 검색 결과 표시 - 사용자 위치 기준으로 정렬됨
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

        // 텍스트 강조 표시 helper 함수를 Consumer 내부에 정의
        Widget buildHighlightedText(String text, String searchTerm) {
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
            // 검색어가 텍스트에 없는 경우 일반 텍스트로 반환
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

          // 검색어의 시작 및 끝 위치 찾기
          final start = lowerText.indexOf(searchTerm);
          final end = start + searchTerm.length;

          return RichText(
            text: TextSpan(
              children: [
                // 검색어 앞 부분
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
                // 검색어 부분
                TextSpan(
                  text: text.substring(start, end),
                  style: const TextStyle(
                    color: Color(0xFF4C9EFC), // 파란색으로 강조
                    fontFamily: "Pretendard",
                    fontWeight: FontWeight.w500,
                    fontSize: 18,
                  ),
                ),
                // 검색어 뒷 부분
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

        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: controller.searchResults.length,
          separatorBuilder:
              (context, index) =>
                  const Divider(height: 0, color: Color(0xFFE2E2E2)),
          itemBuilder: (context, index) {
            final result = controller.searchResults[index];
            return ListTile(
              leading: const Icon(
                Icons.location_on_rounded,
                color: Color(0xFF727272),
              ),
              title: buildHighlightedText(result.name, searchTerm),
              subtitle: Text(
                result.address,
                style: TextStyle(
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
                    style: TextStyle(
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
                      color: Color(0xFF727272), // 거리는 파란색으로 강조
                      fontFamily: "Pretendard",
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              onTap: () {
                // 검색어를 선택하면 최근 검색어에 추가
                controller.addToRecentSearches(result.name);

                // 검색 결과 페이지로 이동 (현재 출발지/도착지 정보 전달)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => SearchResultPage(
                          searchTerm: result.name,
                          currentOriginPlace: widget.currentOriginPlace,
                          currentDestinationPlace:
                              widget.currentDestinationPlace,
                          isSearchingOrigin: widget.isSearchingOrigin,
                        ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
