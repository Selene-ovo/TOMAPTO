import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:tomapto/styles/app_styles.dart';
import 'package:tomapto/search/search_transit.dart';
import 'package:tomapto/controllers/map/location_controller.dart';
import 'package:tomapto/controllers/map/address_controller.dart';
import 'package:tomapto/controllers/map/transit_map_controller.dart';
import 'package:tomapto/controllers/map/route_controller.dart';

class TransitApp extends StatefulWidget {
  const TransitApp({super.key});

  @override
  State<TransitApp> createState() => _TransitAppState();
}

class _TransitAppState extends State<TransitApp> {
  // 선택된 탭 인덱스
  int _selectedIndex = 0;

  // 출발지와 도착지를 저장할 변수
  String _originPlace = '위치 확인 중...';
  String _destinationPlace = '도착지 입력';

  // 컨트롤러 인스턴스 생성
  final LocationController _locationController = LocationController();
  final AddressController _addressController = AddressController();
  final TransitMapController _transitMapController = TransitMapController();
  final RouteController _routeController = RouteController();

  // 로딩 상태 추적
  bool _isCarMapLoading = false;
  bool _isWalkMapLoading = false;

  // 대중교통 경로 데이터
  List<RouteData>? _transitRoutes;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _transitMapController.dispose();
    super.dispose();
  }

  // 위치 초기화 및 주소 변환
  Future<void> _initializeLocation() async {
    // 권한 체크
    final hasPermission = await _locationController.checkLocationPermission(
      context,
    );
    if (!hasPermission) {
      setState(() {
        _originPlace = '위치 권한 없음';
      });
      return;
    }

    // 현재 위치 가져오기
    final position = await _locationController.getCurrentLocation();
    if (position != null) {
      // 위치 정보를 TransitMapController에 설정
      _transitMapController.setCurrentPosition(position);

      // 위치 기반 주소 가져오기
      final address = await _addressController.getAddressFromLatLng(position);
      setState(() {
        _originPlace = address;
      });

      // 대중교통 경로 가져오기
      _loadTransitRoutes();

      // 이미 초기화된 맵이 있으면 현재 위치로 카메라 이동
      if (_transitMapController.isCarMapInitialized) {
        _transitMapController.moveCamera(
          TransitMode.car,
          position,
          _transitMapController.getDefaultZoomLevel(TransitMode.car),
        );
      }

      if (_transitMapController.isWalkMapInitialized) {
        _transitMapController.moveCamera(
          TransitMode.walk,
          position,
          _transitMapController.getDefaultZoomLevel(TransitMode.walk),
        );
      }
    } else {
      setState(() {
        _originPlace = '위치 확인 실패';
      });
    }
  }

  // 대중교통 경로 로드
  Future<void> _loadTransitRoutes() async {
    final routes = await _routeController.searchPublicTransportRoutes(
      _originPlace,
      _destinationPlace != '도착지 입력' ? _destinationPlace : '서울역',
    );

    setState(() {
      _transitRoutes = routes;
    });
  }

  // 네비게이션 탭 변경 처리
  void _handleNavIndexChanged(int index) {
    // 현재 선택된 인덱스와 동일한 인덱스가 선택되었는지 확인 (같은 탭 다시 누름)
    final isSameTab = _selectedIndex == index;

    // 이전 인덱스 저장
    final prevIndex = _selectedIndex;

    setState(() {
      _selectedIndex = index;

      // 자동차 탭으로 변경 시 지도 로딩 표시 (처음 선택 시에만)
      if (prevIndex != 1 &&
          index == 1 &&
          !_transitMapController.isCarMapInitialized) {
        _isCarMapLoading = true;
      }

      // 도보 탭으로 변경 시 지도 로딩 표시 (처음 선택 시에만)
      if (prevIndex != 2 &&
          index == 2 &&
          !_transitMapController.isWalkMapInitialized) {
        _isWalkMapLoading = true;
      }
    });

    // 같은 탭을 다시 눌렀거나 처음 선택한 경우 카메라 이동
    if (index == 1) {
      // 자동차 탭
      if (_transitMapController.isCarMapInitialized) {
        final position = _transitMapController.getCurrentPosition();
        if (position != null) {
          _transitMapController.moveCamera(
            TransitMode.car,
            position,
            _transitMapController.getDefaultZoomLevel(TransitMode.car),
          );

          // 같은 탭을 다시 눌렀을 때는 마커도 업데이트 (현재 위치 재확인)
          if (isSameTab) {
            _refreshCurrentLocation(TransitMode.car);
          }
        }
      }
    } else if (index == 2) {
      // 도보 탭
      if (_transitMapController.isWalkMapInitialized) {
        final position = _transitMapController.getCurrentPosition();
        if (position != null) {
          _transitMapController.moveCamera(
            TransitMode.walk,
            position,
            _transitMapController.getDefaultZoomLevel(TransitMode.walk),
          );

          // 같은 탭을 다시 눌렀을 때는 마커도 업데이트 (현재 위치 재확인)
          if (isSameTab) {
            _refreshCurrentLocation(TransitMode.walk);
          }
        }
      }
    }

    print('네비게이션 탭 변경: $index, 같은 탭 다시 선택: $isSameTab');
  }

  // 현재 위치를 새로고침하고 해당 맵의 카메라와 마커를 업데이트하는 메서드
  void _refreshCurrentLocation(TransitMode mode) async {
    // 현재 위치 다시 가져오기
    final position = await _locationController.getCurrentLocation();
    if (position != null) {
      // TransitMapController에 위치 업데이트
      _transitMapController.setCurrentPosition(position);

      // 해당 모드의 지도 카메라 이동
      _transitMapController.moveCamera(
        mode,
        position,
        _transitMapController.getDefaultZoomLevel(mode),
      );

      // 마커 업데이트
      _transitMapController.updateMarkers(mode, position, _originPlace);

      // 위치 기반 주소 갱신
      final address = await _addressController.getAddressFromLatLng(position);
      setState(() {
        _originPlace = address;
      });

      // 출발지가 변경되었으므로 경로 다시 로드
      _routeController.invalidateCache();
      _loadTransitRoutes();
    } else {
      // 위치 가져오기 실패 시 스낵바 표시
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('현재 위치를 가져오는 데 실패했습니다.')));
    }
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
    final double routeItemPadding = width * 0.035; // 화면 너비의 3.5%
    final double fontSize = isSmallScreen ? 12.0 : 14.0; // 작은 화면에서는 작은 폰트

    // 컨텐츠 패딩 (지도 사용 시 필요)
    final contentPadding = EdgeInsets.fromLTRB(
      0,
      0,
      0,
      ResponsiveValue.height(context, base: 80.0),
    );

    return Scaffold(
      backgroundColor: Colors.white, // 배경색을 흰색으로 설정
      body: Column(
        children: [
          // 상단 빨간색 배경의 검색창
          Container(
            color: AppStyles.primaryColor,
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
                              Icons.swap_vert,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              // 출발지와 도착지 교환
                              setState(() {
                                final temp = _originPlace;
                                _originPlace = _destinationPlace;
                                _destinationPlace = temp;
                              });

                              // 캐시 무효화 및 경로 다시 로드
                              _routeController.invalidateCache();
                              _loadTransitRoutes();
                            },
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
                                  // 출발지 검색 페이지로 이동
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => const SearchPage(
                                            mode: SearchMode.origin,
                                          ),
                                    ),
                                  );

                                  // 검색 결과가 있으면 출발지 업데이트
                                  if (result != null) {
                                    setState(() {
                                      _originPlace = result as String;
                                    });

                                    // 캐시 무효화 및 경로 다시 로드
                                    _routeController.invalidateCache();
                                    _loadTransitRoutes();
                                  }
                                },
                                child: Container(
                                  margin: EdgeInsets.only(
                                    top: maxWidth * 0.0001,
                                    bottom: 0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppStyles.searchBarColor,
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
                                            _originPlace,
                                            style: AppStyles.searchTextStyle,
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
                                  // 도착지 검색 페이지로 이동
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => const SearchPage(
                                            mode: SearchMode.destination,
                                          ),
                                    ),
                                  );

                                  // 검색 결과가 있으면 도착지 업데이트
                                  if (result != null) {
                                    setState(() {
                                      _destinationPlace = result as String;
                                    });

                                    // 캐시 무효화 및 경로 다시 로드
                                    _routeController.invalidateCache();
                                    _loadTransitRoutes();
                                  }
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(
                                    top: 1,
                                    bottom: 0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppStyles.searchBarColor,
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
                                            _destinationPlace,
                                            style: AppStyles.searchTextStyle,
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

                    // X 버튼을 절대 위치로 배치 - main.dart로 이동하도록 수정
                    Positioned(
                      top: maxWidth * 0.0000009,
                      right: -5,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          // main.dart 화면으로 돌아가기
                          Navigator.pop(context);
                          print('이전 화면으로 돌아가기');
                        },
                        iconSize: iconSize,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 대중교통 옵션 선택 바 - 그림자 추가
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTransitOption(
                  0,
                  Icons.directions_subway,
                  '대중교통',
                  iconSize: iconSize,
                ),
                _buildTransitOption(
                  1,
                  Icons.directions_car,
                  '자동차',
                  iconSize: iconSize,
                ),
                _buildTransitOption(
                  2,
                  Icons.directions_walk,
                  '도보',
                  iconSize: iconSize,
                ),
              ],
            ),
          ),

          // 시간 및 날짜 선택 바 - 대중교통 탭에서만 표시
          _selectedIndex == 0
              ? Container(
                padding: EdgeInsets.symmetric(
                  horizontal: width * 0.04,
                  vertical: width * 0.025,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: const Border(bottom: BorderSide(color: Colors.white)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 2,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '오늘 오후 9:41 출발',
                          style: TextStyle(fontSize: fontSize),
                        ),
                        Icon(Icons.keyboard_arrow_down, size: fontSize + 4),
                      ],
                    ),
                    Row(
                      children: [
                        Text('추천순', style: TextStyle(fontSize: fontSize)),
                        Icon(Icons.keyboard_arrow_down, size: fontSize + 4),
                      ],
                    ),
                  ],
                ),
              )
              : const SizedBox.shrink(),

          // 콘텐츠 영역 - 탭에 따라 다른 내용 표시
          Expanded(
            child: Stack(
              children: [
                // 대중교통 목록 - 대중교통 탭에서만 표시
                Visibility(
                  visible: _selectedIndex == 0,
                  child: Container(
                    color: Colors.white,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // 경로 데이터가 없으면 로딩 표시
                        if (_transitRoutes == null) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: AppStyles.primaryColor,
                            ),
                          );
                        }

                        // 경로 목록 표시
                        return ListView.builder(
                          padding: EdgeInsets.only(top: width * 0.02),
                          itemCount: _transitRoutes!.length,
                          itemBuilder: (context, index) {
                            final route = _transitRoutes![index];
                            return _buildRouteItem(
                              route.totalTime,
                              route.walkTime,
                              route.price,
                              route.busNumber,
                              route.stationName,
                              constraints.maxWidth,
                              fontSize,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),

                // 자동차 네이버 맵
                Visibility(
                  visible: _selectedIndex == 1,
                  child: NaverMap(
                    options: NaverMapViewOptions(
                      initialCameraPosition: NCameraPosition(
                        target:
                            _transitMapController.getCurrentPosition() ??
                            NLatLng(
                              37.5666805,
                              126.9784147,
                            ), // 현재 위치 또는 서울 시청 (기본값)
                        zoom: _transitMapController.getDefaultZoomLevel(
                          TransitMode.car,
                        ),
                      ),
                      mapType: NMapType.basic,
                      contentPadding: contentPadding,
                    ),
                    onMapReady: (controller) {
                      print('자동차 맵 컨트롤러 준비 완료');
                      setState(() {
                        _isCarMapLoading = false; // 맵 로딩 완료
                        _transitMapController.carMapController.setMapController(
                          controller,
                        );
                        _transitMapController.setMapInitialized(
                          TransitMode.car,
                          true,
                        );
                      });

                      // 현재 위치가 있으면 카메라 이동 및 마커 표시
                      final currentPosition =
                          _transitMapController.getCurrentPosition();
                      if (currentPosition != null) {
                        _transitMapController.moveCamera(
                          TransitMode.car,
                          currentPosition,
                          _transitMapController.getDefaultZoomLevel(
                            TransitMode.car,
                          ),
                        );
                        // 출발지 마커 자동 추가
                        _transitMapController.updateMarkers(
                          TransitMode.car,
                          currentPosition,
                          _originPlace,
                        );
                      }
                    },
                    onCameraIdle: () {
                      // 카메라 움직임이 멈추었을 때 줌 레벨 업데이트
                      if (_transitMapController.carMapController.controller !=
                          null) {
                        _transitMapController.carMapController
                            .getCurrentCameraPosition()
                            .then((cameraPosition) {
                              if (cameraPosition != null) {
                                double zoom = cameraPosition.zoom;
                                _transitMapController.carMapController
                                    .setZoomLevel(zoom);
                                print('자동차 탭 줌 레벨 업데이트됨: $zoom');
                              }
                            });
                      }
                    },
                    onMapTapped: (point, latLng) {
                      print('자동차 지도가 탭되었습니다: $latLng');
                      // 자동차 탭 전용 추가 기능 구현 가능
                    },
                  ),
                ),

                // 도보 네이버 맵
                Visibility(
                  visible: _selectedIndex == 2,
                  child: NaverMap(
                    options: NaverMapViewOptions(
                      initialCameraPosition: NCameraPosition(
                        target:
                            _transitMapController.getCurrentPosition() ??
                            NLatLng(
                              37.5666805,
                              126.9784147,
                            ), // 현재 위치 또는 서울 시청 (기본값)
                        zoom: _transitMapController.getDefaultZoomLevel(
                          TransitMode.walk,
                        ),
                      ),
                      mapType: NMapType.basic,
                      contentPadding: contentPadding,
                    ),
                    onMapReady: (controller) {
                      print('도보 맵 컨트롤러 준비 완료');
                      setState(() {
                        _isWalkMapLoading = false; // 맵 로딩 완료
                        _transitMapController.walkMapController
                            .setMapController(controller);
                        _transitMapController.setMapInitialized(
                          TransitMode.walk,
                          true,
                        );
                      });

                      // 현재 위치가 있으면 카메라 이동 및 마커 표시
                      final currentPosition =
                          _transitMapController.getCurrentPosition();
                      if (currentPosition != null) {
                        _transitMapController.moveCamera(
                          TransitMode.walk,
                          currentPosition,
                          _transitMapController.getDefaultZoomLevel(
                            TransitMode.walk,
                          ),
                        );
                        // 출발지 마커 자동 추가
                        _transitMapController.updateMarkers(
                          TransitMode.walk,
                          currentPosition,
                          _originPlace,
                        );
                      }
                    },
                    onCameraIdle: () {
                      // 카메라 움직임이 멈추었을 때 줌 레벨 업데이트
                      if (_transitMapController.walkMapController.controller !=
                          null) {
                        _transitMapController.walkMapController
                            .getCurrentCameraPosition()
                            .then((cameraPosition) {
                              if (cameraPosition != null) {
                                double zoom = cameraPosition.zoom;
                                _transitMapController.walkMapController
                                    .setZoomLevel(zoom);
                                print('도보 탭 줌 레벨 업데이트됨: $zoom');
                              }
                            });
                      }
                    },
                    onMapTapped: (point, latLng) {
                      print('도보 지도가 탭되었습니다: $latLng');
                      // 도보 탭 전용 추가 기능 구현 가능
                    },
                  ),
                ),

                // 맵 로딩 표시 - 자동차 탭이 선택되었고 초기화 중일 때
                if (_selectedIndex == 1 && _isCarMapLoading)
                  Center(
                    child: CircularProgressIndicator(
                      color: AppStyles.primaryColor,
                    ),
                  ),

                // 맵 로딩 표시 - 도보 탭이 선택되었고 초기화 중일 때
                if (_selectedIndex == 2 && _isWalkMapLoading)
                  Center(
                    child: CircularProgressIndicator(
                      color: AppStyles.primaryColor, // 도보 탭도 빨간색으로 변경
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransitOption(
    int index,
    IconData icon,
    String label, {
    double iconSize = 28.0,
  }) {
    // 텍스트 크기는 아이콘 크기에 비례하게 조정
    final double textSize = iconSize * 0.42;

    // 선택된 탭에 따라 색상 설정 - 모든 탭이 동일한 색상(AppStyles.primaryColor) 사용
    Color iconColor;
    if (_selectedIndex == index) {
      iconColor = AppStyles.primaryColor; // 모든 탭에 동일한 색상 적용
    } else {
      iconColor = Colors.grey;
    }

    return Expanded(
      child: InkWell(
        onTap: () {
          // 탭 변경 핸들러 호출
          _handleNavIndexChanged(index);
        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: iconSize * 0.42),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: iconSize),
              SizedBox(height: iconSize * 0.14),
              Text(
                label,
                style: TextStyle(color: iconColor, fontSize: textSize),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteItem(
    String time,
    String walkTime,
    String price,
    String busNumber,
    String stationName,
    double maxWidth,
    double fontSize,
  ) {
    // 화면 너비에 따라 마진과 패딩 계산
    final double horizontalMargin = maxWidth * 0.04;
    final double verticalMargin = maxWidth * 0.02;
    final double containerPadding = maxWidth * 0.035;

    // 아이콘과 텍스트 크기 계산
    final double iconSize = maxWidth < 360 ? 14.0 : 16.0;
    final double timeTextSize = AppStyles.routeTimeStyle.fontSize ?? 24.0;
    final double adjustedTimeTextSize =
        maxWidth < 360 ? timeTextSize * 0.8 : timeTextSize;

    return Container(
      margin: EdgeInsets.symmetric(
        vertical: verticalMargin,
        horizontal: horizontalMargin,
      ),
      padding: EdgeInsets.all(containerPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08), // 그림자 진하게 설정
            blurRadius: 12, // 블러 증가
            spreadRadius: 1, // 그림자 확산
            offset: const Offset(0, 3), // 약간 더 아래로
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                time,
                style: AppStyles.routeTimeStyle.copyWith(
                  fontSize: adjustedTimeTextSize,
                ),
              ),
              const Spacer(),
            ],
          ),
          SizedBox(height: verticalMargin * 0.5),
          Row(
            children: [
              Text(
                walkTime,
                style: TextStyle(fontSize: fontSize, color: Colors.black54),
              ),
              SizedBox(width: horizontalMargin * 0.25),
              Text(
                price,
                style: TextStyle(fontSize: fontSize, color: Colors.black54),
              ),
            ],
          ),
          SizedBox(height: verticalMargin * 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 버스 아이
              // 버스 아이콘
              Container(
                padding: EdgeInsets.all(maxWidth * 0.015),
                decoration: BoxDecoration(
                  color: AppStyles.primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.directions_bus,
                  color: Colors.white,
                  size: iconSize,
                ),
              ),
              SizedBox(width: horizontalMargin * 0.4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '버스시장',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: fontSize + 1,
                          ),
                        ),
                        SizedBox(width: horizontalMargin * 0.2),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: maxWidth * 0.02,
                            vertical: maxWidth * 0.008,
                          ),
                          decoration: BoxDecoration(
                            color: AppStyles.busNumberColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            busNumber,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: fontSize - 2,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: verticalMargin * 3),
                    // 직선
                    Container(
                      width: 1,
                      height: maxWidth * 0.07,
                      color: Colors.grey.withOpacity(0.3),
                      margin: EdgeInsets.only(left: maxWidth * 0.02),
                    ),
                    SizedBox(height: verticalMargin),
                    // 도착지
                    Row(
                      children: [
                        Container(
                          width: iconSize,
                          height: iconSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.red, width: 2),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.circle,
                              size: iconSize * 0.5,
                              color: Colors.red,
                            ),
                          ),
                        ),
                        SizedBox(width: horizontalMargin * 0.4),
                        Expanded(
                          child: Text(
                            stationName,
                            style: TextStyle(fontSize: fontSize + 1),
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
        ],
      ),
    );
  }
}
