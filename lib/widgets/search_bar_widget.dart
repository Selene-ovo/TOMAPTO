import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:provider/provider.dart';
import 'package:tomapto/search/search_main.dart';
import 'package:tomapto/search/search_return.dart';
import 'package:tomapto/controllers/search/search_main_controller.dart';
import 'package:tomapto/controllers/map/transit_provider.dart';
import 'package:tomapto/pages/map/naver_map.dart';

class SearchBarWidget extends StatelessWidget {
  final String originPlace;
  final String destinationPlace;
  final Function(String) onOriginChanged;
  final Function(String) onDestinationChanged;
  final VoidCallback onSwapLocations;
  final VoidCallback onClosePressed;
  final Function(Map<String, dynamic>?)? onSearchResultSelected;

  final NLatLng? currentOriginCoords;
  final NLatLng? currentDestinationCoords;

  const SearchBarWidget({
    super.key,
    required this.originPlace,
    required this.destinationPlace,
    required this.onOriginChanged,
    required this.onDestinationChanged,
    required this.onSwapLocations,
    required this.onClosePressed,
    this.onSearchResultSelected,
    this.currentOriginCoords,
    this.currentDestinationCoords,
  });

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
    final Size screenSize = MediaQuery.of(context).size;
    final double width = screenSize.width;
    final bool isSmallScreen = width < 360;
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    final double searchAreaPadding = width * 0.04;
    final double iconSize = isSmallScreen ? 22.0 : 28.0;

    return Container(
      color: Color(0xFFFB233B),
      padding: EdgeInsets.only(
        top: statusBarHeight + 8,
        bottom: width * 0.035,
        left: width * 0.02,
        right: width * 0.02,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;

          return Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
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

                  Expanded(
                    child: Column(
                      children: [
                        // 출발지 검색창
                        GestureDetector(
                          onTap: () async {
                            final transitProvider =
                                Provider.of<TransitProvider>(
                                  context,
                                  listen: false,
                                );

                            final initialSearchTerm =
                                _isDefaultOriginText(originPlace)
                                    ? ''
                                    : originPlace;

                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => SearchMainPage(
                                      initialSearchTerm: initialSearchTerm,
                                      currentOriginPlace: originPlace,
                                      currentDestinationPlace: destinationPlace,
                                      isSearchingOrigin: true,
                                      currentOriginCoords: currentOriginCoords,
                                      currentDestinationCoords:
                                          currentDestinationCoords,
                                    ),
                              ),
                            );

                            if (result != null) {
                              if (result is Map) {
                                String? type = result['type'];
                                String? place = result['place'];
                                NLatLng? coords = result['coords'];

                                if (type == 'origin' && place != null) {
                                  transitProvider.setOrigin(place, coords);
                                  onOriginChanged(place);
                                } else if (type == 'destination' &&
                                    place != null) {
                                  transitProvider.setDestination(place, coords);
                                  onDestinationChanged(place);
                                }
                              } else if (result is SearchResult) {
                                final coords = NLatLng(
                                  result.mapy,
                                  result.mapx,
                                );
                                transitProvider.setSearchResultAsOrigin(
                                  result.name,
                                  coords,
                                );
                                onOriginChanged(result.name);
                              } else if (result is String) {
                                transitProvider.setOrigin(result, null);
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
                                        color:
                                            _isDefaultOriginText(originPlace)
                                                ? Color(
                                                  0xFFFFFFFF,
                                                ).withOpacity(0.7)
                                                : Color(0xFFFFFFFF),
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
                            final transitProvider =
                                Provider.of<TransitProvider>(
                                  context,
                                  listen: false,
                                );

                            final initialSearchTerm =
                                _isDefaultDestinationText(destinationPlace)
                                    ? ''
                                    : destinationPlace;

                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) {
                                  return SearchMainPage(
                                    initialSearchTerm: initialSearchTerm,
                                    currentOriginPlace: originPlace,
                                    currentDestinationPlace: destinationPlace,
                                    isSearchingOrigin: false,
                                    currentOriginCoords: currentOriginCoords,
                                    currentDestinationCoords:
                                        currentDestinationCoords,
                                  );
                                },
                              ),
                            );

                            if (result != null) {
                              if (result is Map) {
                                String? type = result['type'];
                                String? place = result['place'];
                                NLatLng? coords = result['coords'];

                                if (type == 'origin' && place != null) {
                                  transitProvider.setOrigin(place, coords);
                                  onOriginChanged(place);
                                } else if (type == 'destination' &&
                                    place != null) {
                                  transitProvider.setDestination(place, coords);
                                  onDestinationChanged(place);
                                }
                              } else if (result is SearchResult) {
                                final coords = NLatLng(
                                  result.mapy,
                                  result.mapx,
                                );
                                transitProvider.setSearchResultAsDestination(
                                  result.name,
                                  coords,
                                );
                                onDestinationChanged(result.name);
                              } else if (result is String) {
                                transitProvider.setDestination(result, null);
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
                                        color:
                                            _isDefaultDestinationText(
                                                  destinationPlace,
                                                )
                                                ? Color(
                                                  0xFFFFFFFF,
                                                ).withOpacity(0.7)
                                                : Color(0xFFFFFFFF),
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

                  SizedBox(width: iconSize + 20),
                ],
              ),

              Positioned(
                top: maxWidth * 0.0000009,
                right: -5,
                child: IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () {
                    // Provider 상태 초기화
                    final transitProvider = Provider.of<TransitProvider>(
                      context,
                      listen: false,
                    );
                    transitProvider.reset(); // 모든 상태를 기본값으로 초기화

                    // 기존 onClosePressed 콜백 호출
                    onClosePressed();
                  },
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
