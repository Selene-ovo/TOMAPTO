// profile_edit.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
// 비밀번호 재설정 페이지 import - 경로를 정확히 확인해주세요
import 'package:tomapto/pages/profile/password_reset.dart';

class ProfileEditPage extends StatefulWidget {
  final String currentUserId;
  final String currentNickname;

  const ProfileEditPage({
    Key? key,
    required this.currentUserId,
    required this.currentNickname,
  }) : super(key: key);

  @override
  _ProfileEditPageState createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  // 컨트롤러
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  
  // 포커스 노드
  final FocusNode _userIdFocusNode = FocusNode();
  final FocusNode _nicknameFocusNode = FocusNode();
  
  // 상태 변수
  bool _hasChanges = false;
  bool _isUserIdChanged = false;
  bool _isNicknameChanged = false;
  
  // 원본 값들
  late String _originalUserId;
  late String _originalNickname;

  @override
  void initState() {
    super.initState();
    
    // 초기값 설정
    _originalUserId = widget.currentUserId;
    _originalNickname = widget.currentNickname;
    
    _userIdController.text = _originalUserId;
    _nicknameController.text = _originalNickname;
    
    // 리스너 설정
    _setupListeners();
  }
  
  void _setupListeners() {
    // 포커스 변경 시 setState 호출
    _userIdFocusNode.addListener(() => setState(() {}));
    _nicknameFocusNode.addListener(() => setState(() {}));
    
    // 텍스트 변경 리스너
    _userIdController.addListener(_checkForChanges);
    _nicknameController.addListener(_checkForChanges);
  }
  
  void _checkForChanges() {
    setState(() {
      _isUserIdChanged = _userIdController.text != _originalUserId;
      _isNicknameChanged = _nicknameController.text != _originalNickname;
      _hasChanges = _isUserIdChanged || _isNicknameChanged;
    });
  }
  
  @override
  void dispose() {
    _userIdController.dispose();
    _nicknameController.dispose();
    _userIdFocusNode.dispose();
    _nicknameFocusNode.dispose();
    super.dispose();
  }
  
  // 저장하기 처리
  Future<void> _saveProfile() async {
    if (!_hasChanges) return;
    
    // 로딩 인디케이터 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFB233B)),
              ),
              SizedBox(height: 16),
              Text(
                '프로필을 업데이트 중입니다...',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    // 실제 저장 로직은 여기에 구현 (API 호출 등)
    await Future.delayed(Duration(seconds: 2)); // 임시 딜레이
    
    // 로딩 다이얼로그 닫기
    Navigator.of(context).pop();
    
    // 성공 메시지 표시
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              '프로필이 성공적으로 업데이트되었습니다.',
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
    
    // 이전 페이지로 돌아가기 (업데이트된 데이터 전달)
    Navigator.of(context).pop({
      'userId': _userIdController.text,
      'nickname': _nicknameController.text,
      'updated': true,
    });
  }
  
  // 비밀번호 변경 페이지로 이동
  void _navigateToPasswordReset() async {
    print('프로필 편집에서 비밀번호 변경 페이지로 이동 - isFromProfileEdit: true'); // 디버그 로그
    
    // 비밀번호 재설정 페이지로 이동 (프로필 편집에서 왔다는 정보 전달)
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PasswordResetPage(
          isFromProfileEdit: true, // 프로필 편집에서 왔다는 플래그 전달
        ),
      ),
    );
    
    // 비밀번호 변경이 완료되었다면 결과에 따라 처리
    if (result != null && result['passwordChanged'] == true) {
      // 비밀번호가 변경되었다면 로그아웃 처리 또는 다른 액션 수행
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                '비밀번호가 성공적으로 변경되었습니다.',
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
  
  // 비밀번호 변경 확인 다이얼로그
  void _showPasswordChangeConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          '비밀번호 변경',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '비밀번호 재설정 페이지로 이동하시겠습니까?',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue[600]),
                      SizedBox(width: 6),
                      Text(
                        '안내사항',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue[600],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• 아이디와 이메일 인증을 통한 비밀번호 재설정\n• 인증 완료 후 새로운 비밀번호 설정 가능\n• 보안을 위해 이메일 인증이 필요합니다',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '취소',
              style: TextStyle(
                fontFamily: 'Pretendard',
                color: Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToPasswordReset(); // 비밀번호 재설정 페이지로 이동
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFB233B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              '이동하기',
              style: TextStyle(
                fontFamily: 'Pretendard',
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '프로필 수정',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: 'Pretendard',
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 24 * (screenWidth / 375),
            vertical: 20 * (screenHeight / 812),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 20 * (screenHeight / 812)),
              
              // 프로필 아이콘
              Stack(
                children: [
                  Container(
                    width: 80 * (screenWidth / 375),
                    height: 80 * (screenWidth / 375),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[100],
                      border: Border.all(color: Colors.grey[300]!, width: 2),
                    ),
                    child: ClipOval(
                      child: SvgPicture.asset(
                        'assets/icons/profile_default.svg',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Color(0xFFFB233B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 40 * (screenHeight / 812)),
              
              // 아이디 변경 필드
              _buildEditField(
                controller: _userIdController,
                focusNode: _userIdFocusNode,
                label: '아이디',
                hintText: '아이디를 입력해주세요',
                isChanged: _isUserIdChanged,
              ),
              
              SizedBox(height: 20 * (screenHeight / 812)),
              
              // 닉네임 변경 필드
              _buildEditField(
                controller: _nicknameController,
                focusNode: _nicknameFocusNode,
                label: '닉네임',
                hintText: '닉네임을 입력해주세요',
                isChanged: _isNicknameChanged,
              ),
              
              SizedBox(height: 20 * (screenHeight / 812)),
              
              // 비밀번호 변경 버튼 - 클릭 시 비밀번호 재설정 페이지로 이동
              Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _showPasswordChangeConfirmDialog, // 확인 다이얼로그 표시
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 56,
                            child: Text(
                              '비밀번호',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                fontFamily: 'Pretendard',
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              '비밀번호 변경',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 15,
                                fontFamily: 'Pretendard',
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.grey[600],
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: 60 * (screenHeight / 812)),
              
              // 저장하기 버튼
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                ),
                child: ElevatedButton(
                  onPressed: _hasChanges ? _saveProfile : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasChanges 
                        ? Color(0xFFFB233B) 
                        : Color(0xFFFB233B).withOpacity(0.5), // 밝은 색상으로 차이
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: Color(0xFFFB233B).withOpacity(0.5),
                  ),
                  child: Text(
                    '저장하기',
                    style: TextStyle(
                      color: _hasChanges ? Colors.white : Colors.white.withOpacity(0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: 20 * (screenHeight / 812)),
            ],
          ),
        ),
      ),
    );
  }
  
  // 수정 가능한 텍스트 필드 위젯
  Widget _buildEditField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hintText,
    required bool isChanged,
  }) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: isChanged ? Colors.white : Colors.grey[100], // 변경 시 배경색 다르게
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focusNode.hasFocus 
              ? Color(0xFFFB233B) 
              : isChanged 
                  ? Color(0xFFFB233B).withOpacity(0.3) 
                  : Colors.grey.shade300,
          width: isChanged ? 1.5 : 1, // 변경 시 테두리 두껍게
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Text(
                label,
                style: TextStyle(
                  color: isChanged ? Color(0xFFFB233B) : Colors.grey[700], // 변경 시 레이블 색상 다르게
                  fontSize: 15,
                  fontWeight: isChanged ? FontWeight.w500 : FontWeight.w400, // 변경 시 굵게
                  fontFamily: 'Pretendard',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: hintText,
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 15,
                    fontFamily: 'Pretendard',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                style: TextStyle(
                  fontSize: 15,
                  fontFamily: 'Pretendard',
                  color: isChanged ? Colors.black : Colors.grey[700], // 변경 시 텍스트 색상
                  fontWeight: isChanged ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            
            // 변경 표시 아이콘
            if (isChanged)
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Color(0xFFFB233B),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}