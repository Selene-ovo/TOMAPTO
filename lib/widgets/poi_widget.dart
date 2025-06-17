import 'package:flutter/material.dart';
import 'package:tomapto/controllers/map/poi_controller.dart';
import 'package:provider/provider.dart';
import 'package:tomapto/controllers/map/transit_provider.dart';

class LocationInfoWidget extends StatelessWidget {
  final ClickedLocationInfo locationInfo;
  final VoidCallback onClose;
  final VoidCallback onDirections; // 도착지로 설정하는 길찾기 버튼
  final VoidCallback onDeparture; // 출발지로 설정하는 길찾기 버튼
  final VoidCallback? onSave; // 즐겨찾기 저장 (선택사항)

  const LocationInfoWidget({
    super.key,
    required this.locationInfo,
    required this.onClose,
    required this.onDirections,
    required this.onDeparture,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(0, 16, 0, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 헤더 영역
          Container(
            padding: EdgeInsets.fromLTRB(30, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 제목, 카테고리, 닫기 버튼을 한 줄에 배치
                Row(
                  children: [
                    // 제목
                    Expanded(
                      child: Text(
                        locationInfo.locationName,
                        style: TextStyle(
                          fontFamily: "Pretendard",
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0771EB),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    SizedBox(width: 8),
                    // 카테고리 태그
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        locationInfo.category,
                        style: TextStyle(
                          fontFamily: "Pretendard",
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          color: Colors.grey[900],
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    // 닫기 버튼
                    IconButton(
                      onPressed: onClose,
                      icon: Icon(Icons.close_rounded, size: 24),
                      color: Colors.grey[500],
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),

                SizedBox(height: 8),

                // 주소
                Text(
                  locationInfo.address,
                  style: TextStyle(
                    fontFamily: "Pretendard",
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    color: Colors.grey[800],
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                SizedBox(height: 12),

                // 거리 정보와 좌표 정보
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 거리 정보
                    Text(
                      _formatDistance(locationInfo.distanceFromUser),
                      style: TextStyle(
                        fontFamily: "Pretendard",
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF363636),
                      ),
                    ),
                    SizedBox(height: 4),
                  ],
                ),
              ],
            ),
          ),

          // 버튼 영역
          Container(
            padding: EdgeInsets.fromLTRB(20, 15, 20, 40),
            child: Row(
              children: [
                // 출발 버튼 (검은색) - 출발지로 설정
                Expanded(
                  child: Container(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        // Provider를 통해 POI를 출발지로 설정
                        final transitProvider = Provider.of<TransitProvider>(
                          context,
                          listen: false,
                        );
                        transitProvider.setPoiAsOrigin(
                          locationInfo.locationName,
                          locationInfo.position,
                        );

                        onDeparture();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        '출발',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 12),

                // 도착 버튼 (빨간색) - 정확한 좌표로 길찾기
                Expanded(
                  child: Container(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        // Provider를 통해 POI를 도착지로 설정
                        final transitProvider = Provider.of<TransitProvider>(
                          context,
                          listen: false,
                        );
                        transitProvider.setPoiAsDestination(
                          locationInfo.locationName,
                          locationInfo.position,
                        );

                        onDirections();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFFB233B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        '도착',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 거리를 읽기 쉬운 형태로 포맷
  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return "${distanceInMeters.round()}m";
    } else {
      double km = distanceInMeters / 1000;
      return "${km.toStringAsFixed(1)}km";
    }
  }
}
