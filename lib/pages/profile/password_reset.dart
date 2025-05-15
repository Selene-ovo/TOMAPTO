// password_reset.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';


class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({Key? key}) : super(key: key);

  @override
  _PasswordResetPageState createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  // 컨트롤러 및 포커스 노드
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _verificationCodeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  final FocusNode _idFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _verificationCodeFocusNode = FocusNode();
  final FocusNode _newPasswordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  
  // 상태 변수
  bool _showVerificationField = false;
  bool _showPasswordFields = false;
  bool _isVerificationComplete = false;
  bool _isTimerActive = false;
  int _remainingSeconds = 300; // 5분
  Timer? _timer;
  
  // 비밀번호 유효성 관련 상태
  bool _passwordsMatch = false;
  bool _isConfirmPasswordTouched = false;
  bool _isPasswordValid = false;
  bool _hasMinLength = false;
  bool _hasLetter = false;
  bool _hasNumber = false;
  
  // 이메일 도메인
  final List<String> _emailDomains = [
    '@naver.com',
    '@kakao.com',
    '@daum.net',
    '@hanmail.net',
  ];
  String _selectedDomain = '@naver.com';
  
  @override
  void initState() {
    super.initState();
    _setupListeners();
  }
  
  void _setupListeners() {
    // 포커스 변경 시 setState 호출
    _idFocusNode.addListener(() => setState(() {}));
    _emailFocusNode.addListener(() => setState(() {}));
    _verificationCodeFocusNode.addListener(() => setState(() {}));
    _newPasswordFocusNode.addListener(() => setState(() {}));
    _confirmPasswordFocusNode.addListener(() => setState(() {}));
    
    // 비밀번호 입력 필드 변경 리스너 추가
    _newPasswordController.addListener(_validatePassword);
    _confirmPasswordController.addListener(_validatePassword);
  }
  
  // 비밀번호 유효성 검사
  void _validatePassword() {
    final password = _newPasswordController.text;
    
    setState(() {
      // 개별 조건 검사
      _hasMinLength = password.length >= 8;
      _hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
      _hasNumber = RegExp(r'[0-9]').hasMatch(password);
      
      // 모든 조건이 충족되면 비밀번호 유효
      _isPasswordValid = _hasMinLength && _hasLetter && _hasNumber;
      
      // 비밀번호 일치 여부 확인
      _passwordsMatch = password == _confirmPasswordController.text;
      
      // 확인 필드가 터치되었는지 여부 (입력 시작했으면 true로 설정)
      if (_confirmPasswordController.text.isNotEmpty) {
        _isConfirmPasswordTouched = true;
      }
    });
  }
  
  @override
  void dispose() {
    _idController.dispose();
    _emailController.dispose();
    _verificationCodeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _idFocusNode.dispose();
    _emailFocusNode.dispose();
    _verificationCodeFocusNode.dispose();
    _newPasswordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _timer?.cancel();
    super.dispose();
  }
  
  String _getApiBaseUrl() {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/api';
    if (Platform.isAndroid && baseUrl.contains('localhost')) {
      return baseUrl.replaceAll('localhost', '10.0.2.2');
    }
    return baseUrl;
  }
  
  Future<void> _requestVerificationCode() async {
    if (_idController.text.isEmpty || _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이디와 이메일을 입력해주세요.')),
      );
      return;
    }
    
    // 즉시 UI 업데이트 - 로딩 상태 표시
    setState(() {
      _showVerificationField = true;
      _isTimerActive = true;
      _remainingSeconds = 300;
    });
    
    // 타이머 시작
    _startTimer();
    
    // 로딩 인디케이터 표시
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final loadingSnackBar = SnackBar(
      content: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(width: 16),
          Text('인증번호를 발송 중입니다...'),
        ],
      ),
      duration: Duration(seconds: 60), // 충분히 긴 시간 설정
    );
    
    final snackBarController = scaffoldMessenger.showSnackBar(loadingSnackBar);
    
    try {
      final response = await http.post(
        Uri.parse('${_getApiBaseUrl()}/account/password-reset/send-reset-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _idController.text,
          'email': _emailController.text + _selectedDomain,
        }),
      );
      
      // 로딩 스낵바 닫기
      snackBarController.close();
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? '인증번호가 발송되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // 실패 시 인증 필드 숨김
        setState(() {
          _showVerificationField = false;
          _isTimerActive = false;
          _timer?.cancel();
        });
        
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? '오류가 발생했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // 로딩 스낵바 닫기
      snackBarController.close();
      
      print('인증번호 요청 오류: $e');
      
      // 에러 발생 시 인증 필드 숨김
      setState(() {
        _showVerificationField = false;
        _isTimerActive = false;
        _timer?.cancel();
      });
      
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('서버 연결에 실패했습니다. 네트워크 연결을 확인하세요.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _isTimerActive = false;
          _timer?.cancel();
        }
      });
    });
  }
  
  String _formatTime(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  Widget _buildVerificationSection(double screenHeight) {
    return Column(
      children: [
        _buildSignupStyleVerificationField(),
        SizedBox(height: 8 * (screenHeight / 812)),
        // 타이머 표시
        if (_isTimerActive)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 왼쪽에 상태 표시 메시지 추가
                Text(
                  _verificationCodeController.text.isEmpty ? '인증번호를 입력해주세요' : '인증하기 버튼을 눌러주세요',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontFamily: 'Pretendard',
                  ),
                ),
                // 오른쪽에 타이머 표시
                Text(
                  '남은 시간: ${_formatTime(_remainingSeconds)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _remainingSeconds < 60 ? Colors.red : Colors.grey[600],
                    fontFamily: 'Pretendard',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
  
  Future<void> _verifyCodeAndReset() async {
    if (_verificationCodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인증번호를 입력해주세요.')),
      );
      return;
    }
    
    // 로딩 인디케이터 표시
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final loadingSnackBar = SnackBar(
      content: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(width: 16),
          Text('인증 확인 중...'),
        ],
      ),
      duration: Duration(seconds: 60),
    );
    
    final snackBarController = scaffoldMessenger.showSnackBar(loadingSnackBar);
    
    try {
      // 먼저 인증번호 확인
      final verifyResponse = await http.post(
        Uri.parse('${_getApiBaseUrl()}/account/password-reset/verify-reset-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _idController.text,
          'email': _emailController.text + _selectedDomain,
          'code': _verificationCodeController.text,
        }),
      );
      
      // 로딩 스낵바 닫기
      snackBarController.close();
      
      final verifyData = jsonDecode(verifyResponse.body);
      
      if (verifyResponse.statusCode == 200 && verifyData['verified'] == true) {
        setState(() {
          _isVerificationComplete = true;
          _showPasswordFields = true;
          _timer?.cancel();
        });
        
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(verifyData['message'] ?? '인증이 완료되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(verifyData['message'] ?? '인증번호가 일치하지 않습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // 로딩 스낵바 닫기
      snackBarController.close();
      
      print('인증 확인 오류: $e');
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('서버 연결에 실패했습니다. 네트워크 연결을 확인하세요.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _resetPassword() async {
    if (_newPasswordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('새 비밀번호를 입력해주세요.')),
      );
      return;
    }
    
    if (_newPasswordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호는 8자리 이상이어야 합니다.')),
      );
      return;
    }
    
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')),
      );
      return;
    }
    
    if (!_isVerificationComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 이메일 인증을 완료해주세요.')),
      );
      return;
    }
    
    // 로딩 인디케이터 표시
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final loadingSnackBar = SnackBar(
      content: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(width: 16),
          Text('비밀번호 변경 중...'),
        ],
      ),
      duration: Duration(seconds: 60),
    );
    
    final snackBarController = scaffoldMessenger.showSnackBar(loadingSnackBar);
    
    try {
      final response = await http.post(
        Uri.parse('${_getApiBaseUrl()}/account/password-reset/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _idController.text,
          'email': _emailController.text + _selectedDomain,
          'newPassword': _newPasswordController.text,
        }),
      );
      
      // 로딩 스낵바 닫기
      snackBarController.close();
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? '비밀번호가 성공적으로 변경되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 로그인 페이지로 이동
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? '비밀번호 변경에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // 로딩 스낵바 닫기
      snackBarController.close();
      
      print('비밀번호 재설정 오류: $e');
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('서버 연결에 실패했습니다. 네트워크 연결을 확인하세요.'),
          backgroundColor: Colors.red,
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
          '비밀번호 찾기',
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
              SizedBox(height: 10 * (screenHeight / 812)),
              
              // 이모지
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('🤔', style: TextStyle(fontSize: 35)),
                  SizedBox(width: 8),
                  Text('🤔', style: TextStyle(fontSize: 50)),
                  SizedBox(width: 8),
                  Text('🤔', style: TextStyle(fontSize: 35)),
                ],
              ),
              
              SizedBox(height: 24 * (screenHeight / 812)),
              
              // Main title
              Text(
                _showPasswordFields 
                    ? '새 비밀번호를 설정해주세요' 
                    : '비밀번호를 잊으셨나요?',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: 'Pretendard',
                ),
              ),
              
              SizedBox(height: 12 * (screenHeight / 812)),
              
              // Description text
              Text(
                _showPasswordFields
                    ? '새로운 비밀번호를 입력해주세요.\n안전한 비밀번호로 설정하시기 바랍니다.'
                    : '걱정하지 마세요! 비밀번호를 재설정하는데 도움이 되는\n메시지를 보내드리겠습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.6,
                  fontFamily: 'Pretendard',
                ),
              ),
              
              SizedBox(height: 40 * (screenHeight / 812)),
              
              // 비밀번호 변경 필드가 아닌 경우에만 아이디/이메일 필드 표시
              if (!_showPasswordFields) ...[
                // ID field - signup.dart 스타일 적용
                _buildSignupStyleTextField(
                  controller: _idController,
                  focusNode: _idFocusNode,
                  label: '아이디',
                  hintText: '아이디를 입력해주세요',
                ),
                
                SizedBox(height: 16 * (screenHeight / 812)),
                
                // Email field - signup.dart와 동일한 디자인 적용
                _buildSignupStyleEmailField(),
                
                SizedBox(height: 16 * (screenHeight / 812)),
                
                // Verification code field - 애니메이션 효과 추가
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SizeTransition(
                        sizeFactor: animation,
                        child: child,
                      ),
                    );
                  },
                  child: _showVerificationField
                    ? _buildVerificationSection(screenHeight)
                    : SizedBox.shrink(),
                ),
              ], // 아이디/이메일 필드 끝
              
              // 새 비밀번호 입력 필드들
              if (_showPasswordFields) ...[
                // 새 비밀번호 필드
                _buildSignupStylePasswordField(
                  controller: _newPasswordController,
                  focusNode: _newPasswordFocusNode,
                  label: '새 비밀번호',
                  hintText: '새 비밀번호를 입력해주세요',
                ),
                
                // 비밀번호 규칙 안내
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _hasMinLength ? Icons.check_circle : Icons.warning,
                            color: _hasMinLength ? Colors.green : Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '비밀번호는 8자리 이상이어야 합니다',
                            style: TextStyle(
                              fontSize: 12,
                              color: _hasMinLength ? Colors.green : Colors.orange,
                              fontFamily: 'Pretendard',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            _hasLetter ? Icons.check_circle : Icons.warning,
                            color: _hasLetter ? Colors.green : Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '최소 1개 이상의 문자를 포함해야 합니다',
                            style: TextStyle(
                              fontSize: 12,
                              color: _hasLetter ? Colors.green : Colors.orange,
                              fontFamily: 'Pretendard',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            _hasNumber ? Icons.check_circle : Icons.warning,
                            color: _hasNumber ? Colors.green : Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '최소 1개 이상의 숫자를 포함해야 합니다',
                            style: TextStyle(
                              fontSize: 12,
                              color: _hasNumber ? Colors.green : Colors.orange,
                              fontFamily: 'Pretendard',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 16 * (screenHeight / 812)),
                
                // 비밀번호 확인 필드
                _buildSignupStylePasswordField(
                  controller: _confirmPasswordController,
                  focusNode: _confirmPasswordFocusNode,
                  label: '비밀번호 확인',
                  hintText: '비밀번호를 다시 입력해주세요',
                ),
                
                // 비밀번호 일치 여부 안내
                if (_isConfirmPasswordTouched)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                    child: Row(
                      children: [
                        Icon(
                          _passwordsMatch ? Icons.check_circle : Icons.warning,
                          color: _passwordsMatch ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _passwordsMatch ? '비밀번호가 일치합니다' : '비밀번호가 일치하지 않습니다',
                          style: TextStyle(
                            fontSize: 12,
                            color: _passwordsMatch ? Colors.green : Colors.red,
                            fontFamily: 'Pretendard',
                          ),
                        ),
                      ],
                    ),
                  ),
              ], // 비밀번호 필드 끝
              
              SizedBox(height: 60 * (screenHeight / 812)),
              
              // Action button
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    if (_showPasswordFields) {
                      _resetPassword();
                    } else if (_showVerificationField) {
                      _verifyCodeAndReset();
                    } else {
                      _requestVerificationCode();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showPasswordFields 
                        ? (_isPasswordValid && _passwordsMatch ? Colors.black : Colors.grey)
                        : Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _showPasswordFields 
                        ? '비밀번호 변경' 
                        : _showVerificationField 
                            ? '인증하기' 
                            : '인증번호 받기',
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
      // Bottom navigation bar
      bottomNavigationBar: Container(
        color: Colors.white,
        height: 80,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Icon(Icons.home_outlined, color: Colors.grey, size: 28),
            Icon(Icons.apps, color: Colors.grey, size: 28),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.location_on, color: Colors.white, size: 32),
            ),
            Icon(Icons.star_outline, color: Colors.grey, size: 28),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_outline, color: Colors.black, size: 28),
                Text('마이', style: TextStyle(fontSize: 10, color: Colors.black)),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // X 버튼이 없는 텍스트 필드
  Widget _buildSignupStyleTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hintText,
    bool obscureText = false,
  }) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focusNode.hasFocus ? Colors.red : Colors.grey.shade300,
          width: 1,
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
                obscureText: obscureText,
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
          ],
        ),
      ),
    );
  }
  
  // 비밀번호 필드 (토글 가능한 가시성)
  Widget _buildSignupStylePasswordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hintText,
  }) {
    // 비밀번호 가시성 상태 추적
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
              color: focusNode.hasFocus ? Colors.red : Colors.grey.shade300,
              width: 1,
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
  
  // X 버튼이 없는 이메일 필드
  Widget _buildSignupStyleEmailField() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _emailFocusNode.hasFocus ? Colors.red : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Text(
                '이메일',
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
                controller: _emailController,
                focusNode: _emailFocusNode,
                decoration: InputDecoration(
                  hintText: '이메일을 입력해주세요',
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
            
            // email + domain display with dropdown
            Container(
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: PopupMenuButton<String>(
                initialValue: _selectedDomain,
                padding: EdgeInsets.zero,
                offset: const Offset(0, 40),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedDomain,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          fontFamily: 'Pretendard',
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.grey,
                        size: 16,
                      ),
                    ],
                  ),
                ),
                onSelected: (String value) {
                  setState(() {
                    _selectedDomain = value;
                  });
                },
                itemBuilder: (BuildContext context) {
                  return _emailDomains.map((String domain) {
                    return PopupMenuItem<String>(
                      value: domain,
                      height: 40,
                      child: Container(
                        width: double.infinity,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          domain,
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Pretendard',
                          ),
                        ),
                      ),
                    );
                  }).toList();
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // X 버튼이 없는 인증번호 필드
  Widget _buildSignupStyleVerificationField() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _verificationCodeFocusNode.hasFocus ? Colors.red : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Text(
                '인증번호',
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
                controller: _verificationCodeController,
                focusNode: _verificationCodeFocusNode,
                decoration: InputDecoration(
                  hintText: '인증번호를 입력해주세요',
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
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            // Send/Resend button
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(16),
              ),
              child: GestureDetector(
                onTap: _requestVerificationCode,
                child: const Center(
                  child: Text(
                    '재전송',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}