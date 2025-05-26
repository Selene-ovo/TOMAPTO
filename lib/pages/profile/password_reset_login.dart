// password_reset_login.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PasswordResetPage extends StatefulWidget {
  final String? prefilledUserId;
  
  const PasswordResetPage({
    Key? key,
    this.prefilledUserId,
  }) : super(key: key);

  @override
  _PasswordResetPageState createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  // 컨트롤러
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  // 포커스 노드
  final FocusNode _currentPasswordFocusNode = FocusNode();
  final FocusNode _newPasswordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  
  // 상태 변수
  bool _isLoading = false;
  
  // 비밀번호 유효성 관련 상태
  bool _passwordsMatch = false;
  bool _isConfirmPasswordTouched = false;
  bool _isPasswordValid = false;
  bool _hasMinLength = false;
  bool _hasLetter = false;
  bool _hasNumber = false;
  bool _isDifferentFromCurrent = true; // 기존 비밀번호와 다른지 확인
  bool _isCurrentPasswordTouched = false; // 현재 비밀번호 입력 여부

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }
  
  void _setupListeners() {
    // 포커스 변경 시 setState 호출
    _currentPasswordFocusNode.addListener(() => setState(() {}));
    _newPasswordFocusNode.addListener(() => setState(() {}));
    _confirmPasswordFocusNode.addListener(() => setState(() {}));
    
    // 비밀번호 입력 필드 변경 리스너 추가
    _currentPasswordController.addListener(_validatePassword);
    _newPasswordController.addListener(_validatePassword);
    _confirmPasswordController.addListener(_validatePassword);
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
      // 가능한 토큰 키들 확인
      List<String> possibleKeys = [
        'auth_token',
        'token',
        'user_token',
        'access_token',
        'jwt_token',
        'authentication_token'
      ];
      
      for (String key in possibleKeys) {
        String? token = prefs.getString(key);
        if (token != null && token.isNotEmpty) {
          print('토큰 발견: 키=$key, 길이=${token.length}');
          return token;
        }
      }
      
      print('토큰을 찾을 수 없습니다.');
      return null;
    } catch (e) {
      print('토큰 조회 오류: $e');
      return null;
    }
  }
  
  // 비밀번호 유효성 검사
  void _validatePassword() {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;
    
    setState(() {
      // 현재 비밀번호 입력 여부 확인
      _isCurrentPasswordTouched = currentPassword.isNotEmpty;
      
      // 개별 조건 검사
      _hasMinLength = newPassword.length >= 8;
      _hasLetter = RegExp(r'[a-zA-Z]').hasMatch(newPassword);
      _hasNumber = RegExp(r'[0-9]').hasMatch(newPassword);
      
      // 기존 비밀번호와 다른지 확인 (현재 비밀번호가 입력되었을 때만)
      if (_isCurrentPasswordTouched && newPassword.isNotEmpty) {
        _isDifferentFromCurrent = currentPassword != newPassword;
      } else {
        _isDifferentFromCurrent = true; // 아직 확인할 수 없으면 일단 true
      }
      
      // 모든 조건이 충족되면 비밀번호 유효
      _isPasswordValid = _hasMinLength && _hasLetter && _hasNumber;
      
      // 비밀번호 일치 여부 확인
      _passwordsMatch = newPassword == confirmPassword && newPassword.isNotEmpty;
      
      // 확인 필드가 터치되었는지 여부 (입력 시작했으면 true로 설정)
      if (confirmPassword.isNotEmpty) {
        _isConfirmPasswordTouched = true;
      }
    });
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _currentPasswordFocusNode.dispose();
    _newPasswordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }
  
  // 비밀번호 변경 처리
  Future<void> _changePassword() async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('모든 필드를 입력해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (!_isPasswordValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('새 비밀번호가 요구사항을 충족하지 않습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (!_passwordsMatch) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('새 비밀번호가 일치하지 않습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인 세션이 만료되었습니다. 다시 로그인해주세요.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }
      
      final response = await http.post(
        Uri.parse('${_getApiBaseUrl()}/account/profile-edit/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'current_password': _currentPasswordController.text,
          'new_password': _newPasswordController.text,
        }),
      );
      
      print('비밀번호 변경 응답: ${response.statusCode}');
      print('비밀번호 변경 내용: ${response.body}');
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        // 성공 시 이전 페이지로 돌아가기
        Navigator.of(context).pop({
          'passwordChanged': true,
          'message': data['message'] ?? '비밀번호가 성공적으로 변경되었습니다.',
        });
      } else if (response.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? '현재 비밀번호가 올바르지 않거나 인증이 만료되었습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      } else if (response.statusCode == 400) {
        // 400 에러 시 (동일한 비밀번호 등) - 스낵바로 표시
        final message = data['message'] ?? '비밀번호 변경에 실패했습니다.';
        
        // 동일한 비밀번호 에러인지 확인하고 적절한 색상으로 표시
        Color backgroundColor = Colors.orange;
        if (message.contains('현재 비밀번호와 다른') || message.contains('동일한')) {
          backgroundColor = Colors.red;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor,
            duration: Duration(seconds: 3), // 3초간 표시
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? '비밀번호 변경에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('비밀번호 변경 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 변경 가능 여부 확인
  bool get _canChangePassword {
    return _currentPasswordController.text.isNotEmpty &&
           _isPasswordValid &&
           _passwordsMatch &&
           !_isLoading;
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
          '비밀번호 변경',
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
                    
                    // 이모지 - 👍👍👍 (크기는 중간 크게 중간)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text('👍', style: TextStyle(fontSize: 35)),
                        SizedBox(width: 8),
                        Text('👍', style: TextStyle(fontSize: 50)),
                        SizedBox(width: 8),
                        Text('👍', style: TextStyle(fontSize: 35)),
                      ],
                    ),
                    
                    SizedBox(height: 24 * (screenHeight / 812)),
                    
                    // Main title - 비밀번호 변경 칭찬합니다!
                    Text(
                      '비밀번호 변경 칭찬합니다!',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                    
                    SizedBox(height: 12 * (screenHeight / 812)),
                    
                    // Description text - 주기적으로 비밀번호를 변경하는 것은 좋은 습관입니다.
                    Text(
                      '주기적으로 비밀번호를 변경하는 것은\n좋은 습관입니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[600],
                        height: 1.6,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                    
                    SizedBox(height: 40 * (screenHeight / 812)),
                    
                    // 현재 비밀번호 필드
                    _buildPasswordField(
                      controller: _currentPasswordController,
                      focusNode: _currentPasswordFocusNode,
                      label: '현재 비밀번호',
                      hintText: '현재 비밀번호를 입력해주세요',
                    ),
                    
                    SizedBox(height: 20 * (screenHeight / 812)),
                    
                    // 새 비밀번호 필드
                    _buildPasswordField(
                      controller: _newPasswordController,
                      focusNode: _newPasswordFocusNode,
                      label: '새 비밀번호',
                      hintText: '새 비밀번호를 입력해주세요',
                    ),
                    
                    // 비밀번호 규칙 안내
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildValidationRow(
                            _hasMinLength,
                            '비밀번호는 8자리 이상이어야 합니다',
                          ),
                          SizedBox(height: 4),
                          _buildValidationRow(
                            _hasLetter,
                            '최소 1개 이상의 문자를 포함해야 합니다',
                          ),
                          SizedBox(height: 4),
                          _buildValidationRow(
                            _hasNumber,
                            '최소 1개 이상의 숫자를 포함해야 합니다',
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 16 * (screenHeight / 812)),
                    
                    // 비밀번호 확인 필드
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      focusNode: _confirmPasswordFocusNode,
                      label: '비밀번호 확인',
                      hintText: '새 비밀번호를 다시 입력해주세요',
                    ),
                    
                    // 비밀번호 일치 여부 안내
                    if (_isConfirmPasswordTouched)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        child: _buildValidationRow(
                          _passwordsMatch,
                          _passwordsMatch ? '비밀번호가 일치합니다' : '비밀번호가 일치하지 않습니다',
                        ),
                      ),
                    
                    SizedBox(height: 60 * (screenHeight / 812)),
                    
                    // 비밀번호 변경 버튼
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: ElevatedButton(
                        onPressed: _canChangePassword ? _changePassword : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _canChangePassword
                              ? Color(0xFFFB233B)
                              : Colors.grey,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          elevation: 0,
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
                                '비밀번호 변경',
                                style: const TextStyle(
                                  color: Colors.white,
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
  
  // 비밀번호 필드 위젯 (토글 가능한 가시성)
  Widget _buildPasswordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hintText,
  }) {
    final ValueNotifier<bool> _obscurePassword = ValueNotifier<bool>(true);
    
    return ValueListenableBuilder<bool>(
      valueListenable: _obscurePassword,
      builder: (context, isObscured, _) {
        return Container(
          height: 54,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: focusNode.hasFocus ? Color(0xFFFB233B) : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    label,
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
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    obscureText: isObscured,
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ),
                // 비밀번호 표시 토글 버튼
                GestureDetector(
                  onTap: () {
                    _obscurePassword.value = !isObscured;
                  },
                  child: Icon(
                    isObscured ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // 유효성 검사 행 위젯
  Widget _buildValidationRow(bool isValid, String text) {
    return Row(
      children: [
        Icon(
          isValid ? Icons.check_circle : Icons.warning,
          color: isValid ? Colors.green : Colors.orange,
          size: 16,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isValid ? Colors.green : Colors.orange,
              fontFamily: 'Pretendard',
            ),
          ),
        ),
      ],
    );
  }
}