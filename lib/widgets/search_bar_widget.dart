import 'package:flutter/material.dart';
import 'package:tomapto/search/search_main.dart';
import 'package:tomapto/search/search_return.dart';
import 'package:tomapto/controllers/search/search_main_controller.dart';
import 'package:tomapto/pages/map/naver_map.dart';

class SearchBarWidget extends StatelessWidget {
  final String originPlace;
  final String destinationPlace;
  final Function(String) onOriginChanged;
  final Function(String) onDestinationChanged;
  final VoidCallback onSwapLocations;
  final VoidCallback onClosePressed; // 이 콜백을 그대로 유지
  final Function(Map<String, dynamic>?)? onSearchResultSelected;

  const SearchBarWidget({
    super.key,
    required this.originPlace,
    required this.destinationPlace,
    required this.onOriginChanged,
    required this.onDestinationChanged,
    required this.onSwapLocations,
    required this.onClosePressed,
    this.onSearchResultSelected, // 이 매개변수를 그대로 사용
  });

  // 🔥 기본 텍스트인지 확인하는 메서드 추가
  bool _isDefaultOriginText(String text) {
    return text == '출발지 입력' ||
        text == '위치 확인 중...' ||
        text == '위치 권한 없음' ||
        text == '위치 확인 실패';
  }

  bool _isDefaultDestinationText(String text) {
    return text == '도착지 입력';
  }

  @override
  Widget build(BuildContext context) {
    // 화면 크기 가져오기
    final Size screenSize = MediaQuery.of(context).size;
    final double width = screenSize.width;
    final bool isSmallScreen = width < 360;
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    // 반응형 크기 계산
    final double searchAreaPadding = width * 0.04; // 화면 너비의 4%
    final double iconSize = isSmallScreen ? 22.0 : 28.0; // 작은 화면에서는 작은 아이콘

    return Container(
      color: Color(0xFFFB233B),
      padding: EdgeInsets.only(
        top: statusBarHeight + 8, // 상태바 높이 + 추가 패딩
        bottom: width * 0.035, // 화면 너비에 따른 패딩
        left: width * 0.02,
        right: width * 0.02,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 최대 너비 계산
          final maxWidth = constraints.maxWidth;

          return Stack(
            children: [
              // 검색바 영역
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 화살표 위아래 아이콘
                  Container(
                    margin: EdgeInsets.only(left: maxWidth * 0.000001),
                    child: IconButton(
                      icon: const Icon(
                        Icons.swap_vert_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: onSwapLocations,
                      iconSize: iconSize,
                    ),
                  ),

                  // 검색바 컨테이너
                  Expanded(
                    child: Column(
                      children: [
                        // 출발지 검색창
                        GestureDetector(
                          onTap: () async {
                            // 🔥 기본 텍스트인 경우 빈 문자열로 시작
                            final initialSearchTerm =
                                _isDefaultOriginText(originPlace)
                                    ? '' // 기본 텍스트면 빈 문자열로 시작
                                    : originPlace; // 실제 장소명이면 그대로 사용

                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => SearchMainPage(
                                      initialSearchTerm: initialSearchTerm,
                                      currentOriginPlace: originPlace,
                                      currentDestinationPlace: destinationPlace,
                                      isSearchingOrigin: true, // 출발지 검색 모드
                                    ),
                              ),
                            );

                            // 검색 결과 처리
                            if (result != null) {
                              // 맵 형태인 경우 (출발 또는 도착 버튼에서 넘어온 경우)
                              if (result is Map) {
                                String? type = result['type'];
                                String? place = result['place'];

                                if (type == 'origin' && place != null) {
                                  onOriginChanged(place);
                                } else if (type == 'destination' &&
                                    place != null) {
                                  onDestinationChanged(place);
                                }
                              }
                              // SearchResult 객체인 경우 (검색 결과에서 직접 선택한 경우)
                              else if (result is SearchResult) {
                                onOriginChanged(result.name);
                              }
                              // 문자열인 경우
                              else if (result is String) {
                                onOriginChanged(result);
                              }
                            }
                          },
                          child: Container(
                            margin: EdgeInsets.only(
                              top: maxWidth * 0.0001,
                              bottom: 0,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFFFB5063),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: searchAreaPadding,
                                vertical: maxWidth * 0.035,
                              ),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      originPlace,
                                      style: TextStyle(
                                        fontFamily: "Pretendard",
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        // 🔥 기본 텍스트인 경우 투명도 적용으로 연하게 표시
                                        color:
                                            _isDefaultOriginText(originPlace)
                                                ? Color(0xFFFFFFFF).withOpacity(
                                                  0.7,
                                                ) // 기본 텍스트는 연하게
                                                : Color(
                                                  0xFFFFFFFF,
                                                ), // 실제 값은 선명하게
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // 목적지 검색창
                        GestureDetector(
                          onTap: () async {
                            // 🔥 기본 텍스트인 경우 빈 문자열로 시작
                            final initialSearchTerm =
                                _isDefaultDestinationText(destinationPlace)
                                    ? '' // 기본 텍스트면 빈 문자열로 시작
                                    : destinationPlace; // 실제 장소명이면 그대로 사용

                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => SearchMainPage(
                                      initialSearchTerm: initialSearchTerm,
                                      currentOriginPlace: originPlace,
                                      currentDestinationPlace: destinationPlace,
                                      isSearchingOrigin: false, // 도착지 검색 모드
                                    ),
                              ),
                            );

                            // 검색 결과 처리
                            if (result != null) {
                              // 맵 형태인 경우 (출발 또는 도착 버튼에서 넘어온 경우)
                              if (result is Map) {
                                String? type = result['type'];
                                String? place = result['place'];

                                if (type == 'origin' && place != null) {
                                  onOriginChanged(place);
                                } else if (type == 'destination' &&
                                    place != null) {
                                  onDestinationChanged(place);
                                }
                              }
                              // SearchResult 객체인 경우 (검색 결과에서 직접 선택한 경우)
                              else if (result is SearchResult) {
                                onDestinationChanged(result.name);
                              }
                              // 문자열인 경우
                              else if (result is String) {
                                onDestinationChanged(result);
                              }
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(top: 1, bottom: 0),
                            decoration: BoxDecoration(
                              color: Color(0xFFFB5063),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: searchAreaPadding,
                                vertical: maxWidth * 0.035,
                              ),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      destinationPlace,
                                      style: TextStyle(
                                        fontFamily: "Pretendard",
                                        fontWeight: FontWeight.w500,
                                        fontSize: 18,
                                        // 🔥 기본 텍스트인 경우 투명도 적용으로 연하게 표시
                                        color:
                                            _isDefaultDestinationText(
                                                  destinationPlace,
                                                )
                                                ? Color(0xFFFFFFFF).withOpacity(
                                                  0.7,
                                                ) // 기본 텍스트는 연하게
                                                : Color(
                                                  0xFFFFFFFF,
                                                ), // 실제 값은 선명하게
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // X 버튼 자리 공간 확보
                  SizedBox(width: iconSize + 20),
                ],
              ),

              // X 버튼을 절대 위치로 배치
              Positioned(
                top: maxWidth * 0.0000009,
                right: -5,
                child: IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  // onClosePressed 콜백 그대로 사용
                  // 이제 transit.dart에서 이 콜백은 NaverMapPage로 이동하는 로직을 가지고 있음
                  onPressed: onClosePressed,
                  iconSize: iconSize,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
