// profile_edit.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
// 새로운 비밀번호 변경 페이지 import (프로필 편집 전용)
import 'package:tomapto/pages/profile/password_reset_login.dart';
// 로그인 페이지 import (로그아웃 시 필요)
import 'package:tomapto/pages/profile/login.dart';

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
  bool _isLoading = false;
  
  // 유효성 검사 상태
  bool _isUserIdValid = true;
  bool _isNicknameValid = true;
  String? _userIdValidationMessage;
  String? _nicknameValidationMessage;
  
  // 중복 확인 상태
  bool _isUserIdAvailable = true;
  bool _isNicknameAvailable = true;
  String? _userIdAvailabilityMessage;
  String? _nicknameAvailabilityMessage;
  
  // 중복 확인 타이머
  Timer? _userIdTimer;
  Timer? _nicknameTimer;
  
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
    
    // 현재 프로필 정보 로드
    _loadCurrentProfile();
  }
  
  void _setupListeners() {
    // 포커스 변경 시 setState 호출
    _userIdFocusNode.addListener(() => setState(() {}));
    _nicknameFocusNode.addListener(() => setState(() {}));
    
    // 텍스트 변경 리스너
    _userIdController.addListener(_onUserIdChanged);
    _nicknameController.addListener(_onNicknameChanged);
  }
  
  // API 기본 URL 가져오기
  String _getApiBaseUrl() {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/api';
    if (Platform.isAndroid && baseUrl.contains('localhost')) {
      return baseUrl.replaceAll('localhost', '10.0.2.2');
    }
    return baseUrl;
  }
  
  // 토큰 가져오기
  Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (e) {
      print('토큰 조회 오류: $e');
      return null;
    }
  }
  
  // 현재 프로필 정보 로드
  Future<void> _loadCurrentProfile() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final token = await _getToken();
      if (token == null) {
        throw Exception('인증 토큰이 없습니다.');
      }
      
      final response = await http.get(
        Uri.parse('${_getApiBaseUrl()}/account/profile-edit/current'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      print('프로필 조회 응답: ${response.statusCode}');
      print('프로필 조회 내용: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _originalUserId = data['data']['user_id'] ?? widget.currentUserId;
            _originalNickname = data['data']['user_nickname'] ?? widget.currentNickname;
            
            _userIdController.text = _originalUserId;
            _nicknameController.text = _originalNickname;
          });
        }
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? '프로필 조회에 실패했습니다.');
      }
    } catch (e) {
      print('프로필 로드 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('프로필 정보를 불러오는데 실패했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _onUserIdChanged() {
    final userId = _userIdController.text;
    
    // 유효성 검사
    setState(() {
      _isUserIdChanged = userId != _originalUserId;
      _userIdValidationMessage = _getUserIdValidationMessage(userId);
      _isUserIdValid = _userIdValidationMessage == null;
      _checkForChanges();
    });
    
    // 중복 확인 타이머 설정
    _userIdTimer?.cancel();
    if (userId.isNotEmpty && _isUserIdValid && _isUserIdChanged) {
      _userIdTimer = Timer(const Duration(milliseconds: 500), () {
        _checkUserIdAvailability(userId);
      });
    } else if (!_isUserIdChanged) {
      setState(() {
        _isUserIdAvailable = true;
        _userIdAvailabilityMessage = null;
      });
    }
  }
  
  void _onNicknameChanged() {
    final nickname = _nicknameController.text;
    
    // 유효성 검사
    setState(() {
      _isNicknameChanged = nickname != _originalNickname;
      _nicknameValidationMessage = _getNicknameValidationMessage(nickname);
      _isNicknameValid = _nicknameValidationMessage == null;
      _checkForChanges();
    });
    
    // 중복 확인 타이머 설정
    _nicknameTimer?.cancel();
    if (nickname.isNotEmpty && _isNicknameValid && _isNicknameChanged) {
      _nicknameTimer = Timer(const Duration(milliseconds: 500), () {
        _checkNicknameAvailability(nickname);
      });
    } else if (!_isNicknameChanged) {
      setState(() {
        _isNicknameAvailable = true;
        _nicknameAvailabilityMessage = null;
      });
    }
  }
  
  void _checkForChanges() {
    setState(() {
      _hasChanges = _isUserIdChanged || _isNicknameChanged;
    });
  }
  
  // 아이디 유효성 검사 메시지
  String? _getUserIdValidationMessage(String userId) {
    if (userId.isEmpty) {
      return null; // 빈 값일 때는 메시지 없음
    }
    
    if (userId.length < 4) {
      return '아이디는 4자 이상이어야 합니다.';
    }
    
    if (userId.length > 20) {
      return '아이디는 20자 이하여야 합니다.';
    }
    
    final RegExp userIdRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!userIdRegex.hasMatch(userId)) {
      return '영문, 숫자, 언더스코어(_)만 사용 가능합니다.';
    }
    
    return null; // 유효함
  }
  
  // 닉네임 유효성 검사 메시지
  String? _getNicknameValidationMessage(String nickname) {
    if (nickname.isEmpty) {
      return null; // 빈 값일 때는 메시지 없음
    }
    
    if (nickname.length < 2) {
      return '닉네임은 2자 이상이어야 합니다.';
    }
    
    if (nickname.length > 20) {
      return '닉네임은 20자 이하여야 합니다.';
    }
    
    return null; // 유효함
  }
  
  // 아이디 중복 확인
  Future<void> _checkUserIdAvailability(String userId) async {
    try {
      final token = await _getToken();
      if (token == null) return;
      
      final response = await http.post(
        Uri.parse('${_getApiBaseUrl()}/account/profile-edit/check-userid'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'new_user_id': userId,
        }),
      );
      
      final data = jsonDecode(response.body);
      
      if (mounted) {
        setState(() {
          _isUserIdAvailable = data['available'] ?? false;
          _userIdAvailabilityMessage = data['message'];
        });
      }
    } catch (e) {
      print('아이디 중복 확인 오류: $e');
      if (mounted) {
        setState(() {
          _isUserIdAvailable = false;
          _userIdAvailabilityMessage = '중복 확인에 실패했습니다.';
        });
      }
    }
  }
  
  // 닉네임 중복 확인
  Future<void> _checkNicknameAvailability(String nickname) async {
    try {
      final token = await _getToken();
      if (token == null) return;
      
      final response = await http.post(
        Uri.parse('${_getApiBaseUrl()}/account/profile-edit/check-nickname'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'new_nickname': nickname,
        }),
      );
      
      final data = jsonDecode(response.body);
      
      if (mounted) {
        setState(() {
          _isNicknameAvailable = data['available'] ?? false;
          _nicknameAvailabilityMessage = data['message'];
        });
      }
    } catch (e) {
      print('닉네임 중복 확인 오류: $e');
      if (mounted) {
        setState(() {
          _isNicknameAvailable = false;
          _nicknameAvailabilityMessage = '중복 확인에 실패했습니다.';
        });
      }
    }
  }
  
  @override
  void dispose() {
    _userIdController.dispose();
    _nicknameController.dispose();
    _userIdFocusNode.dispose();
    _nicknameFocusNode.dispose();
    _userIdTimer?.cancel();
    _nicknameTimer?.cancel();
    super.dispose();
  }
  
  // 저장 가능 여부 확인
  bool get _canSave {
    return _hasChanges && 
           _isUserIdValid && 
           _isNicknameValid && 
           _isUserIdAvailable && 
           _isNicknameAvailable &&
           !_isLoading;
  }
  
  // 저장하기 처리
  Future<void> _saveProfile() async {
    if (!_canSave) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('인증 토큰이 없습니다.');
      }
      
      // 요청 바디 구성
      Map<String, dynamic> requestBody = {};
      if (_isUserIdChanged) {
        requestBody['new_user_id'] = _userIdController.text;
      }
      if (_isNicknameChanged) {
        requestBody['new_nickname'] = _nicknameController.text;
      }
      
      if (requestBody.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('변경할 정보가 없습니다.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      print('프로필 업데이트 요청: $requestBody');
      
      final response = await http.put(
        Uri.parse('${_getApiBaseUrl()}/account/profile-edit/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );
      
      print('프로필 업데이트 응답: ${response.statusCode}');
      print('프로필 업데이트 내용: ${response.body}');
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data['message'] ?? '프로필이 성공적으로 업데이트되었습니다.',
                    style: TextStyle(fontFamily: 'Pretendard'),
                  ),
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
        
        // 아이디가 변경된 경우 로그아웃 처리
        if (data['data']?['updated_fields']?['user_id_changed'] == true) {
          _showLogoutDialog();
        } else {
          // 이전 페이지로 돌아가기 (업데이트된 데이터 전달)
          Navigator.of(context).pop({
            'userId': data['data']['user_id'],
            'nickname': data['data']['user_nickname'],
            'updated': true,
          });
        }
      } else if (response.statusCode == 401) {
        // 인증 만료
        _showLogoutDialog();
      } else {
        // 오류 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message'] ?? '프로필 업데이트에 실패했습니다.',
              style: TextStyle(fontFamily: 'Pretendard'),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      print('프로필 저장 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '네트워크 오류가 발생했습니다.',
            style: TextStyle(fontFamily: 'Pretendard'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 로그아웃 처리
  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_id');
      await prefs.remove('user_nickname');
      print('로그아웃 완료 - 토큰 및 사용자 정보 삭제');
    } catch (e) {
      print('로그아웃 처리 오류: $e');
    }
  }
  
  // 로그아웃 다이얼로그 표시
  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          '아이디 변경 완료',
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
              '아이디가 성공적으로 변경되었습니다.',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange[600]),
                      SizedBox(width: 6),
                      Text(
                        '중요 안내',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.orange[600],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '보안을 위해 다시 로그인해주세요.\n변경된 아이디로 로그인하시기 바랍니다.',
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
          ElevatedButton(
            onPressed: () async {
              // 로그아웃 처리
              await _logout();
              
              // 로그인 페이지로 이동
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFB233B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              '확인',
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
  
  // 비밀번호 변경 페이지로 직접 이동 (모달 제거)
  void _navigateToPasswordReset() async {
    print('프로필 편집에서 비밀번호 변경 페이지로 직접 이동');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PasswordResetPage(
          prefilledUserId: widget.currentUserId, // 현재 사용자 ID 미리 채우기
        ),
      ),
    );
    
    // 비밀번호 변경 완료 시 처리
    if (result != null && result['passwordChanged'] == true) {
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
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFB233B)),
              ),
            )
          : SingleChildScrollView(
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
                      isValid: _isUserIdValid && _isUserIdAvailable,
                      validationMessage: _userIdValidationMessage ?? _userIdAvailabilityMessage,
                      isError: !_isUserIdValid || (!_isUserIdAvailable && _isUserIdChanged),
                    ),
                    
                    SizedBox(height: 20 * (screenHeight / 812)),
                    
                    // 닉네임 변경 필드
                    _buildEditField(
                      controller: _nicknameController,
                      focusNode: _nicknameFocusNode,
                      label: '닉네임',
                      hintText: '닉네임을 입력해주세요',
                      isChanged: _isNicknameChanged,
                      isValid: _isNicknameValid && _isNicknameAvailable,
                      validationMessage: _nicknameValidationMessage ?? _nicknameAvailabilityMessage,
                      isError: !_isNicknameValid || (!_isNicknameAvailable && _isNicknameChanged),
                    ),
                    
                    SizedBox(height: 20 * (screenHeight / 812)),
                    
                    // 비밀번호 변경 버튼 (모달 제거, 직접 이동)
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
                          onTap: _navigateToPasswordReset, // 직접 페이지 이동
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
                        onPressed: _canSave ? _saveProfile : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _canSave 
                              ? Color(0xFFFB233B) 
                              : Color(0xFFFB233B).withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          elevation: 0,
                          disabledBackgroundColor: Color(0xFFFB233B).withOpacity(0.5),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                '저장하기',
                                style: TextStyle(
                                  color: _canSave ? Colors.white : Colors.white.withOpacity(0.7),
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
    required bool isValid,
    String? validationMessage,
    bool isError = false,
  }) {
    Color borderColor;
    Color labelColor;
    
    if (isError) {
      borderColor = Colors.red;
      labelColor = Colors.red;
    } else if (focusNode.hasFocus) {
      borderColor = Color(0xFFFB233B);
      labelColor = isChanged ? Color(0xFFFB233B) : Colors.grey[700]!;
    } else if (isChanged && isValid) {
      borderColor = Color(0xFFFB233B).withOpacity(0.3);
      labelColor = Color(0xFFFB233B);
    } else {
      borderColor = Colors.grey.shade300;
      labelColor = Colors.grey[700]!;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: isChanged ? Colors.white : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: isChanged ? 1.5 : 1,
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
                      color: labelColor,
                      fontSize: 15,
                      fontWeight: isChanged ? FontWeight.w500 : FontWeight.w400,
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
                      color: isChanged ? Colors.black : Colors.grey[700],
                      fontWeight: isChanged ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
                
                // 상태 표시 아이콘
                if (isChanged)
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isError 
                          ? Colors.red 
                          : isValid 
                              ? Color(0xFFFB233B) 
                              : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isError 
                          ? Icons.close 
                          : isValid 
                              ? Icons.check 
                              : Icons.warning,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        // 유효성 검사 메시지
        if (validationMessage != null && validationMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Text(
              validationMessage,
              style: TextStyle(
                color: isError ? Colors.red : Colors.green,
                fontSize: 12,
                fontFamily: 'Pretendard',
              ),
            ),
          ),
      ],
    );
  }
}