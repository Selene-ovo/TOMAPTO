import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tomapto/widgets/navbar.dart';
import 'package:tomapto/controllers/account/profile_controller.dart';
import 'package:tomapto/pages/profile/login.dart';
import 'package:tomapto/setting/setting.dart';
import 'package:tomapto/pages/profile/profile_edit.dart'; // 프로필 편집 페이지 import 추가
import 'package:shared_preferences/shared_preferences.dart'; // SharedPreferences import 추가

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

// 원호를 그리기 위한 CustomPainter
class ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  ArcPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 6.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    // 원의 시작은 맨 위(-90도)에서부터, 그리고 진행도에 따라 원호를 그림
    canvas.drawArc(
      rect,
      -90 * (3.14159 / 180), // 시작 각도 (라디안)
      progress * 2 * 3.14159, // 진행도에 따른 각도 (라디안)
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class _ProfilePageState extends State<ProfilePage> {
  // 컨트롤러 인스턴스
  final ProfileController _controller = ProfileController();
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    // 사용자 데이터 로드 및 토큰 유효성 검사
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 화면이 완전히 빌드된 후 토큰 검사 및 데이터 로드
      _validateTokenAndLoadData();
    });
  }

  // 토큰 유효성 검사 및 데이터 로드
  Future<void> _validateTokenAndLoadData() async {
    await _controller.loadUserData(context, setState);
  }

  // 새로고침 처리
  Future<void> _refreshData() async {
    await _controller.refreshProfile(context, setState);
  }

  // 프로필 편집 페이지로 이동
  void _navigateToProfileEdit() async {
    // SharedPreferences에서 사용자 ID 가져오기
    final prefs = await SharedPreferences.getInstance();
    final String currentUserId = prefs.getString('user_id') ?? "";

    if (currentUserId.isEmpty) {
      // 사용자 ID가 없으면 오류 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '사용자 정보를 찾을 수 없습니다. 다시 로그인해주세요.',
            style: TextStyle(fontFamily: 'Pretendard'),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ProfileEditPage(
              currentUserId: currentUserId, // SharedPreferences에서 가져온 사용자 ID 전달
              currentNickname: _controller.userNickname,
            ),
      ),
    );

    // 프로필 편집에서 돌아온 후 데이터가 업데이트 되었으면 새로고침
    if (result != null && result['updated'] == true) {
      await _refreshData();

      // 성공 메시지 표시 (선택사항)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  '프로필이 업데이트되었습니다.',
                  style: TextStyle(fontFamily: 'Pretendard'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  // 로그아웃 처리
  void _handleLogout() async {
    // 로그아웃 확인 다이얼로그 표시
    final bool confirm =
        await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text(
                  '로그아웃',
                  style: TextStyle(fontFamily: 'Pretendard'),
                ),
                content: const Text(
                  '정말 로그아웃 하시겠습니까?',
                  style: TextStyle(fontFamily: 'Pretendard'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      '취소',
                      style: TextStyle(fontFamily: 'Pretendard'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text(
                      '로그아웃',
                      style: TextStyle(
                        color: Colors.red,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                  ),
                ],
              ),
        ) ??
        false;

    if (confirm && mounted) {
      // 로그아웃 진행
      final success = await _controller.logout(context);

      if (success && mounted) {
        // 로그인 페이지로 이동 (직접 MaterialPageRoute 사용)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // 반응형 크기 계산
    final double cardPadding = 10.0 * (screenWidth / 375);
    final double cardMargin = 15.0 * (screenHeight / 812);
    final double cardBorderRadius = 16.0 * (screenWidth / 375);

    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFD),
      body: SafeArea(
        child:
            _controller.isLoading
                ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFFB233B),
                    ),
                  ),
                )
                : RefreshIndicator(
                  key: _refreshKey,
                  onRefresh: _refreshData,
                  color: const Color(0xFFFB233B),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // 앱바 - 프로필 제목
                        Padding(
                          padding: EdgeInsets.all(cardMargin),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '프로필',
                                style: TextStyle(
                                  fontSize: 20 * (screenWidth / 375),
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF363636),
                                  fontFamily: 'Pretendard',
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.settings,
                                  color: const Color(0xFF363636),
                                  size: 24 * (screenWidth / 375),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => const SettingsScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        // 프로필 정보 카드
                        Container(
                          margin: EdgeInsets.all(cardMargin),
                          padding: EdgeInsets.all(cardPadding),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              cardBorderRadius,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // 프로필 아이콘 - 클릭 가능하도록 GestureDetector로 감싸기 (원형 이미지로 수정)
                              GestureDetector(
                                onTap: _navigateToProfileEdit, // 프로필 편집 페이지로 이동
                                child: Container(
                                  width: 48 * (screenWidth / 375),
                                  height: 48 * (screenWidth / 375),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    // 그림자 효과 추가
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      // 프로필 이미지 컨테이너
                                      Container(
                                        width: 48 * (screenWidth / 375),
                                        height: 48 * (screenWidth / 375),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.grey[100], // 배경색
                                          border: Border.all(
                                            color: Colors.grey[200]!,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: ClipOval(
                                          // 원형으로 클립
                                          child: SvgPicture.asset(
                                            'assets/icons/profile_default.svg',
                                            fit:
                                                BoxFit
                                                    .cover, // cover로 변경하여 원형에 꽉 채우기
                                            width: 48 * (screenWidth / 375),
                                            height: 48 * (screenWidth / 375),
                                          ),
                                        ),
                                      ),
                                      // 편집 버튼 아이콘 (우하단에 작은 아이콘)
                                      Positioned(
                                        bottom: -2,
                                        right: -2,
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            color: Color(0xFFFB233B),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                            // 편집 버튼에도 그림자 효과 추가
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.2,
                                                ),
                                                blurRadius: 3,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.edit,
                                            color: Colors.white,
                                            size: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(width: 16 * (screenWidth / 375)),

                              // 사용자 정보
                              Expanded(
                                child: GestureDetector(
                                  onTap:
                                      _navigateToProfileEdit, // 닉네임 클릭 시 프로필 편집 페이지로 이동
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            _controller.userNickname,
                                            style: TextStyle(
                                              fontSize:
                                                  18 * (screenWidth / 375),
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF363636),
                                              fontFamily: 'Pretendard',
                                            ),
                                          ),
                                          SizedBox(width: 6),
                                          // 편집 가능함을 알려주는 작은 아이콘
                                          Icon(
                                            Icons.edit_outlined,
                                            color: Colors.grey[400],
                                            size: 14,
                                          ),
                                        ],
                                      ),
                                      SizedBox(
                                        height: 4 * (screenHeight / 812),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            'Lv.${_controller.userLevel} 씨앗',
                                            style: TextStyle(
                                              fontSize:
                                                  14 * (screenWidth / 375),
                                              color: Colors.grey[600],
                                              fontFamily: 'Pretendard',
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.info_outline,
                                            color: Colors.grey,
                                            size: 12,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // 경험치 프로그래스 바 (원형)
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  // 배경 원
                                  Container(
                                    width: 40.78,
                                    height: 40.78,
                                    decoration: const ShapeDecoration(
                                      shape: OvalBorder(
                                        side: BorderSide(
                                          width: 6,
                                          strokeAlign:
                                              BorderSide.strokeAlignCenter,
                                          color: Color(0xFFF5F5F5),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // 진행률 원 - 원의 일부만 그리기 위해 CustomPaint를 사용
                                  SizedBox(
                                    width: 40.78,
                                    height: 40.78,
                                    child: CustomPaint(
                                      painter: ArcPainter(
                                        progress: _controller.userExp / 1000,
                                        color: const Color(0xFFFB233B),
                                        strokeWidth: 6,
                                      ),
                                    ),
                                  ),
                                  // 퍼센트 텍스트
                                  Text(
                                    '${(_controller.userExp ~/ 10)}%',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                      fontFamily: 'Pretendard',
                                      color: Color(0xFF363636),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // 네비게이션 카드 - 캘린더
                        _buildCardWithStack(
                          context: context,
                          margin: cardMargin,
                          title: '캘린더 확인하기',
                          label: '계획',
                          imagePath: 'assets/icons/default_profile_card.png',
                          labelColor: const Color(0xFFFB233B),
                          onTap: () => _controller.navigateToCalendar(context),
                        ),

                        // 네비게이션 카드 - 공지사항
                        _buildCardWithStack(
                          context: context,
                          margin: cardMargin,
                          title: '공지사항 확인하기',
                          label: '공지',
                          imagePath: 'assets/icons/default_profile_card.png',
                          labelColor: const Color(0xFFFB233B),
                          onTap: () => _controller.navigateToNotices(context),
                        ),

                        // 네비게이션 카드 - 고객센터
                        // 이미지 변경 - calendar 이미지와 같은 이미지를 사용하고 있으므로 구분을 위해 다른 이미지를 사용하도록 권장
                        _buildCardWithStack(
                          context: context,
                          margin: cardMargin,
                          title: '고객센터 문의하기',
                          label: '문의',
                          imagePath: 'assets/icons/default_profile_card.png',
                          labelColor: const Color(0xFFFB233B),
                          onTap: () => _controller.navigateToSupport(context),
                        ),

                        // 로그아웃 버튼
                        Padding(
                          padding: EdgeInsets.all(cardMargin),
                          child: TextButton(
                            onPressed: _handleLogout,
                            child: Text(
                              '로그아웃',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16 * (screenWidth / 375),
                                fontFamily: 'Pretendard',
                              ),
                            ),
                          ),
                        ),

                        // 오류 메시지 표시
                        if (_controller.errorMessage.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.all(cardMargin),
                            child: Container(
                              padding: EdgeInsets.all(cardPadding),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(
                                  cardBorderRadius,
                                ),
                                border: Border.all(color: Colors.red[200]!),
                              ),
                              child: Text(
                                _controller.errorMessage,
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 14 * (screenWidth / 375),
                                  fontFamily: 'Pretendard',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),

                        // 하단 여백
                        SizedBox(height: 70 * (screenHeight / 812)),
                      ],
                    ),
                  ),
                ),
      ),

      // 하단 네비게이션 바
      bottomNavigationBar: BottomNavBar(
        currentIndex: 3, // 마이페이지
        onTap: (index) {
          // 네비게이션 처리
          // 실제 앱에서는 다른 페이지로 이동하는 코드 필요
        },
      ),
    );
  }

  // 새로운 디자인의 카드 위젯 - Stack을 사용한 레이아웃
  Widget _buildCardWithStack({
    required BuildContext context,
    required double margin,
    required String title,
    required String label,
    required String imagePath,
    required Color labelColor,
    required VoidCallback onTap,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth - (margin * 2); // 양쪽 마진을 고려한 카드 너비
    final cardHeight = 180.0 * (screenWidth / 375); // 카드 높이 조정
    final imageHeight = 120.0 * (screenWidth / 375); // 이미지 높이 조정

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        height: cardHeight,
        margin: EdgeInsets.symmetric(horizontal: margin, vertical: margin / 2),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 이미지 부분 (카드 전체를 덮는 배경)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.grey[200],
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.image_not_supported,
                        size: 50,
                        color: Colors.grey[400],
                      );
                    },
                  ),
                ),
              ),
            ),

            // 하단 텍스트 컨테이너 (이미지 위에 겹치는 형태)
            Positioned(
              bottom: 0,
              child: Container(
                width: cardWidth * 0.92,
                height: (cardHeight - imageHeight) * 0.8, // 약간 작게 설정
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: 16 * (screenWidth / 375),
                  vertical: 8 * (screenWidth / 375),
                ),
                child: Row(
                  children: [
                    // 제목 텍스트
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: const Color(0xFF313131),
                          fontSize: 18 * (screenWidth / 375),
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    // 화살표 아이콘
                    Icon(
                      Icons.arrow_forward,
                      color: const Color(0xFFFB233B),
                      size: 20 * (screenWidth / 375),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
