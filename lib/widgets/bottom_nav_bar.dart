import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    // 고정된 높이 설정
    const double navBarHeight = 75.0;

    return SizedBox(
      width: screenWidth,
      height: navBarHeight + 40, // 중앙 버튼을 위한 추가 공간
      child: Stack(
        children: [
          // 기본 네비게이션 바 (둥근 모서리)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              width: screenWidth,
              height: navBarHeight,
              decoration: ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                    bottomLeft: Radius.circular(26),
                    bottomRight: Radius.circular(26),
                  ),
                ),
                shadows: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                  // 중앙 버튼을 위한 공간 - 고정 너비 사용
                  Container(width: 60, height: 50),
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

          // 중앙 원형 배경 (중앙 버튼 아래 깔리는 원)
          Positioned(
            bottom: navBarHeight - 40, // 네비게이션 바 위로 절반 올라옴
            left: screenWidth / 2 - 40, // 중앙 정렬 (72의 절반은 36)
            child: Container(
              width: 80,
              height: 80,
              decoration: const ShapeDecoration(
                color: Colors.white,
                shape: OvalBorder(),
                shadows: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),

          // 중앙 둥근 버튼 (빨간색)
          Positioned(
            bottom: navBarHeight - 28, // 위치 조정
            left: screenWidth / 2 - 28, // 중앙 위치 (56의 절반은 28)
            child: GestureDetector(
              onTap: () => onTap(2),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFB233B),
                      const Color(0xFFFB233B).withOpacity(0.7),
                    ],
                    stops: const [0.7, 1.0],
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
                    width: 21,
                    height: 21,
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
    final bool isSelected = currentIndex == index;

    // 모든 아이템에 고정된 높이와 너비를 부여하여 움직임 방지
    return GestureDetector(
      onTap: () => onTap(index),
      child: SizedBox(
        width: 60,
        height: 50,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              isSelected ? selectedSvgPath : unselectedSvgPath,
              width: 24,
              height: 24,
            ),
            const SizedBox(height: 2),
            // 선택 여부와 관계없이 항상 Text 위젯 표시 (선택되지 않았을 때는 투명하게)
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.transparent,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
