import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final double curveHeight;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.curveHeight = 30.0, // 기본값 설정
  });

  @override
  Widget build(BuildContext context) {
    // 표준 Flutter 하단 네비게이션 바 높이
    const double kBottomNavigationBarHeight = 80.0;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: screenWidth,
      height: kBottomNavigationBarHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 기본 네비게이션 바 배경 (전체 너비)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: kBottomNavigationBarHeight,
            child: Container(
              color: Colors.white,
              width: screenWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    0,
                    '메인',
                    'assets/icons/main_B.svg',
                    'assets/icons/main_W.svg',
                  ),
                  _buildNavItem(
                    1,
                    '친구',
                    'assets/icons/friend_B.svg',
                    'assets/icons/friend_W.svg',
                  ),
                  // 중앙 버튼을 위한 공간
                  SizedBox(width: 50),
                  _buildNavItem(
                    3,
                    '즐겨찾기',
                    'assets/icons/favorites_B.svg',
                    'assets/icons/favorites_W.svg',
                  ),
                  _buildNavItem(
                    4,
                    '마이',
                    'assets/icons/user_B.svg',
                    'assets/icons/user_W.svg',
                  ),
                ],
              ),
            ),
          ),

          // 중앙 볼록 부분 (하단 바 위에 추가) - 곡선 개선 및 크기 조정
          Positioned(
            bottom: kBottomNavigationBarHeight - 1,
            left: screenWidth / 2 - 60, // 좌측 위치 더 넓게 조정 (52 -> 60)
            child: ClipPath(
              clipper: CenterCurveClipper(iconRadius: 30), // 아이콘 반지름 조정
              child: Container(
                width: 120, // 너비 더 넓게 조정 (105 -> 120)
                height: curveHeight * 1.2, // 높이 조정
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      spreadRadius: 1,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 중앙 둥근 버튼 (Stack의 맨 마지막에 배치하여 항상 최상위에 표시)
          Positioned(
            bottom: kBottomNavigationBarHeight - 45, // 위치 조정
            left: screenWidth / 2 - 28, // 중앙 위치 원래대로 조정
            child: GestureDetector(
              onTap: () => onTap(2),
              child: Container(
                width: 57, // 크기 원래대로 복원
                height: 57, // 크기 원래대로 복원
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFB233B),
                      const Color(0xFFFB233B).withOpacity(0.7),
                    ],
                    stops: [0.7, 1.0],
                    radius: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFB233B).withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/icons/category_Bf.svg',
                    width: 21, // 아이콘 크기 원래대로
                    height: 21, // 아이콘 크기 원래대로
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    String label,
    String selectedSvgPath,
    String unselectedSvgPath,
  ) {
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            isSelected ? selectedSvgPath : unselectedSvgPath,
            width: 24,
            height: 24,
          ),
          SizedBox(height: 2),
          if (isSelected)
            Text(
              label,
              style: TextStyle(
                color: Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

// 종형 곡선 모양의 클리퍼 구현 - 곡선 더 넓게 수정
class CenterCurveClipper extends CustomClipper<Path> {
  final double iconRadius;

  CenterCurveClipper({this.iconRadius = 25.0});

  @override
  Path getClip(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;

    // 좌측 하단에서 시작
    path.moveTo(0, height);

    // 왼쪽 하단 직선 부분 (더 넓게 조정)
    path.lineTo(width * 0.05, height); // 0.08 -> 0.05로 줄여서 곡선 시작점을 더 왼쪽으로

    // 왼쪽에서 중앙으로 올라가는 곡선 (더 넓게 조정)
    path.cubicTo(
      width * 0.10, // 첫 번째 제어점 (0.13 -> 0.10으로 왼쪽으로 이동)
      height,
      width * 0.15, // 두 번째 제어점 (0.18 -> 0.15로 왼쪽으로 이동)
      height * 0.55,
      width * 0.30, // 끝점 (0.33 -> 0.30으로 왼쪽으로 이동)
      height * 0.35,
    );

    // 중앙 상단 부분 (더 넓게 조정)
    path.cubicTo(
      width * 0.38, // 첫 번째 제어점 (0.4 -> 0.38로 왼쪽으로 약간 이동)
      height * 0.15,
      width * 0.62, // 두 번째 제어점 (0.6 -> 0.62로 오른쪽으로 이동)
      height * 0.15,
      width * 0.70, // 끝점 (0.67 -> 0.70으로 오른쪽으로 이동)
      height * 0.35,
    );

    // 중앙에서 오른쪽으로 내려가는 곡선 (더 넓게 조정)
    path.cubicTo(
      width * 0.85, // 첫 번째 제어점 (0.82 -> 0.85로 오른쪽으로 이동)
      height * 0.55,
      width * 0.90, // 두 번째 제어점 (0.87 -> 0.90으로 오른쪽으로 이동)
      height,
      width * 0.95, // 끝점 (0.92 -> 0.95로 오른쪽으로 이동)
      height,
    );

    // 오른쪽 하단 직선 부분
    path.lineTo(width, height);

    // 경로 닫기
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}
