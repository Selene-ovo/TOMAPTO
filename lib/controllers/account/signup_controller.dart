import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;

// 상수 정의
class SignupConstants {
  // 툴팁 이미지 경로
  static const Map<String, String> tooltipImages = {
    'id': 'assets/icons/id_tooltip.svg',
    'nickname': 'assets/icons/nickname_tooltip.svg',
    'password': 'assets/icons/password_tooltip.svg',
    'password_confirm': 'assets/icons/password_confirm_tooltip.svg',
    'email': 'assets/icons/email_tooltip.svg',
  };

  // 이메일 도메인 리스트
  static const List<String> domains = [
    '@naver.com',
    '@kakao.com',
    '@daum.net',
    '@hanmail.net',
  ];

  // API 응답 메시지
  static const String signupSuccess = '회원가입이 완료되었습니다.';
  static const String signupError = '회원가입 중 오류가 발생했습니다.';
  static const String serverError = '서버 오류가 발생했습니다.';
  static const String verificationSent = '인증번호가 이메일로 발송되었습니다.';
  static const String verificationSuccess = '이메일 인증이 완료되었습니다.';
  static const String verificationFailed = '인증번호가 일치하지 않습니다.';
  static const String verificationExpired = '인증번호가 만료되었습니다. 다시 요청해주세요.';
}

// API 서비스 클래스 - API 통신 로직 분리
class SignupApiService {
  // API 기본 URL 가져오기
  static String getApiBaseUrl() {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/api';
    // Android 플랫폼이면서 URL이 localhost를 포함하는 경우
    if (Platform.isAndroid && baseUrl.contains('localhost')) {
      // 에뮬레이터에서는 10.0.2.2로 localhost 대체
      return baseUrl.replaceAll('localhost', '10.0.2.2');
    }
    // 다른 플랫폼이거나 이미 localhost가 아닌 경우 원래 URL 반환
    return baseUrl;
  }

  // 중복 확인 API 호출
  static Future<bool> checkDuplicate(String field, String value) async {
    try {
      final apiBaseUrl = getApiBaseUrl();
      final encodedValue = Uri.encodeComponent(value);
      final response = await http.get(
        Uri.parse(
          '$apiBaseUrl/account/check-duplicate?field=$field&value=$encodedValue',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['isDuplicate'] ?? false;
      }
      return false;
    } catch (e) {
      print('중복 확인 오류: $e');
      return false;
    }
  }

  // 회원가입 API 호출
  static Future<Map<String, dynamic>> signup(
    Map<String, String> userData,
  ) async {
    try {
      final apiBaseUrl = getApiBaseUrl();
      final response = await http.post(
        Uri.parse('$apiBaseUrl/account/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      );

      if (response.statusCode == 201) {
        return {'success': true, 'message': SignupConstants.signupSuccess};
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? SignupConstants.signupError,
        };
      }
    } catch (e) {
      print('회원가입 오류: $e');
      return {'success': false, 'message': SignupConstants.signupError};
    }
  }

  // 이메일 인증번호 발송 API 호출
  static Future<Map<String, dynamic>> sendVerificationEmail(
    String email,
  ) async {
    try {
      final apiBaseUrl = getApiBaseUrl();
      final response = await http.post(
        Uri.parse('$apiBaseUrl/account/verification/send-verification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': SignupConstants.verificationSent};
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? '인증번호 발송에 실패했습니다.',
        };
      }
    } catch (e) {
      print('이메일 인증 발송 오류: $e');
      return {'success': false, 'message': '서버 연결에 실패했습니다.'};
    }
  }

  // 이메일 인증번호 확인 API 호출
  static Future<Map<String, dynamic>> verifyCode(
    String email,
    String code,
  ) async {
    try {
      final apiBaseUrl = getApiBaseUrl();
      final response = await http.post(
        Uri.parse('$apiBaseUrl/account/verification/verify-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': code}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': data['verified'] ?? false,
          'message':
              data['verified'] == true
                  ? SignupConstants.verificationSuccess
                  : SignupConstants.verificationFailed,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? SignupConstants.verificationFailed,
        };
      }
    } catch (e) {
      print('이메일 인증 확인 오류: $e');
      return {'success': false, 'message': '서버 연결에 실패했습니다.'};
    }
  }

  // 이메일 인증 상태 확인 API 호출
  static Future<Map<String, dynamic>> checkEmailVerification(
    String email,
  ) async {
    try {
      final apiBaseUrl = getApiBaseUrl();
      final encodedEmail = Uri.encodeComponent(email);
      final response = await http.get(
        Uri.parse(
          '$apiBaseUrl/account/verification/check-verification?email=$encodedEmail',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'verified': data['verified'] ?? false};
      } else {
        return {'success': false, 'verified': false};
      }
    } catch (e) {
      print('이메일 인증 상태 확인 오류: $e');
      return {'success': false, 'verified': false};
    }
  }
}

// 툴팁 관리 클래스 - 툴팁 관련 로직 분리
class TooltipManager {
  OverlayEntry? _currentTooltip;
  String? _currentTooltipType;

  // 툴팁 표시
  void showTooltip(BuildContext context, FocusNode node, String tooltipType) {
    removeTooltip();

    final overlay = Overlay.of(context);
    final RenderBox fieldBox = node.context!.findRenderObject() as RenderBox;
    final fieldPosition = fieldBox.localToGlobal(Offset.zero);
    final fieldSize = fieldBox.size;

    final String imagePath =
        SignupConstants.tooltipImages[tooltipType] ??
        'assets/icons/error_circle.svg';

    // 위치 계산
    double left = fieldPosition.dx + fieldSize.width - 135;
    double top = fieldPosition.dy + fieldSize.height + 3;

    // 이메일 필드에 대한 특별 처리
    if (tooltipType == 'email') {
      left = fieldPosition.dx + fieldSize.width + 18;
    }

    _currentTooltipType = tooltipType;

    _currentTooltip = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: removeTooltip,
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: Material(
                color: Colors.transparent,
                elevation: 0,
                child: SvgPicture.asset(
                  imagePath,
                  width: 186,
                  height: 64,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_currentTooltip!);
  }

  // 툴팁 제거
  void removeTooltip() {
    if (_currentTooltip != null) {
      _currentTooltip!.remove();
      _currentTooltip = null;
      _currentTooltipType = null;
    }
  }

  // 정리
  void dispose() {
    removeTooltip();
  }
}

// 회원가입 컨트롤러 - 핵심 로직만 포함
class SignupController {
  // Context
  final BuildContext context;

  // Controller & Focus Nodes
  final Map<String, TextEditingController> controllers;
  final Map<String, FocusNode> focusNodes;

  // Scroll controller
  final ScrollController scrollController;

  // Function to update the UI
  final Function(VoidCallback) updateUI;

  // State variables
  String _selectedDomain = SignupConstants.domains[0];
  bool _isIdDuplicate = false;
  bool _isNicknameDuplicate = false;
  bool _isEmailDuplicate = false;
  bool _isEmailValid = true;

  // 이메일 인증 관련 상태 변수
  bool _isVerificationSent = false;
  bool _isEmailVerified = false;
  String _verificationError = '';
  int _verificationTimeLeft = 0; // 초 단위 남은 시간
  Timer? _verificationTimer;

  // Debounce timers
  Timer? _idDebounceTimer;
  Timer? _nicknameDebounceTimer;
  Timer? _emailDebounceTimer;

  // Tooltip manager
  final TooltipManager _tooltipManager = TooltipManager();

  // Getters
  bool get isIdDuplicate => _isIdDuplicate;
  bool get isNicknameDuplicate => _isNicknameDuplicate;
  bool get isEmailDuplicate => _isEmailDuplicate;
  bool get isEmailValid => _isEmailValid;
  String get selectedDomain => _selectedDomain;
  List<String> get domains => SignupConstants.domains;

  // 이메일 인증 관련 getter
  bool get isVerificationSent => _isVerificationSent;
  bool get isEmailVerified => _isEmailVerified;
  String get verificationError => _verificationError;
  int get verificationTimeLeft => _verificationTimeLeft;

  // Constructor
  SignupController({
    required this.context,
    required this.controllers,
    required this.focusNodes,
    required this.scrollController,
    required this.updateUI,
  }) {
    // 이벤트 리스너 설정
    _setupEventListeners();

    // 인증번호 컨트롤러 초기화
    if (!controllers.containsKey('verificationCode')) {
      controllers['verificationCode'] = TextEditingController();
    }
  }

  // 이벤트 리스너 설정
  void _setupEventListeners() {
    focusNodes['id']?.addListener(() => onFocusChange('id'));
    focusNodes['nickname']?.addListener(() => onFocusChange('nickname'));
    focusNodes['email']?.addListener(() => onFocusChange('email'));

    controllers['id']?.addListener(() => onTextChange('id'));
    controllers['nickname']?.addListener(() => onTextChange('nickname'));
    controllers['email']?.addListener(() => onTextChange('email'));

    scrollController.addListener(onScroll);
  }

  // 포커스 변경 이벤트 통합 처리
  void onFocusChange(String field) {
    final focusNode = focusNodes[field];
    final controller = controllers[field];

    if (focusNode != null &&
        !focusNode.hasFocus &&
        controller != null &&
        controller.text.isNotEmpty) {
      switch (field) {
        case 'id':
          _checkDuplicate('user_id', controller.text);
          break;
        case 'nickname':
          _checkDuplicate('user_nickname', controller.text);
          break;
        case 'email':
          _checkDuplicate('user_email', controller.text + _selectedDomain);
          if (_isEmailDuplicate && focusNodes['email'] != null) {
            showTooltip(focusNodes['email']!, 'email');
          }
          break;
      }
    } else if (focusNode != null && !focusNode.hasFocus) {
      _tooltipManager.removeTooltip();
    }
  }

  // 텍스트 변경 이벤트 통합 처리
  void onTextChange(String field) {
    switch (field) {
      case 'id':
        _idDebounceTimer?.cancel();
        if (controllers['id']?.text.isNotEmpty ?? false) {
          _idDebounceTimer = Timer(const Duration(milliseconds: 100), () {
            _checkDuplicate('user_id', controllers['id']!.text);
          });
        } else {
          updateUI(() {
            _isIdDuplicate = false;
          });
          _tooltipManager.removeTooltip();
        }
        break;
      case 'nickname':
        _nicknameDebounceTimer?.cancel();
        if (controllers['nickname']?.text.isNotEmpty ?? false) {
          _nicknameDebounceTimer = Timer(const Duration(milliseconds: 100), () {
            _checkDuplicate('user_nickname', controllers['nickname']!.text);
          });
        } else {
          updateUI(() {
            _isNicknameDuplicate = false;
          });
          _tooltipManager.removeTooltip();
        }
        break;
      case 'email':
        _emailDebounceTimer?.cancel();
        if (controllers['email']?.text.isNotEmpty ?? false) {
          _emailDebounceTimer = Timer(const Duration(milliseconds: 100), () {
            _checkDuplicate(
              'user_email',
              controllers['email']!.text + _selectedDomain,
            );
          });

          // 이메일이 변경되면 인증 상태 초기화
          if (_isVerificationSent || _isEmailVerified) {
            updateUI(() {
              _isVerificationSent = false;
              _isEmailVerified = false;
              _verificationError = '';
              _verificationTimeLeft = 0;
              _verificationTimer?.cancel();
            });
          }
        } else {
          updateUI(() {
            _isEmailDuplicate = false;
          });
          _tooltipManager.removeTooltip();
        }
        break;
    }
  }

  // 스크롤 이벤트 처리
  void onScroll() {
    _tooltipManager.removeTooltip();
  }

  // 중복 확인 통합 처리
  Future<void> _checkDuplicate(String field, String value) async {
    bool isDuplicate = await SignupApiService.checkDuplicate(field, value);

    updateUI(() {
      switch (field) {
        case 'user_id':
          _isIdDuplicate = isDuplicate;
          if (_isIdDuplicate && focusNodes['id'] != null) {
            showTooltip(focusNodes['id']!, 'id');
          }
          break;
        case 'user_nickname':
          _isNicknameDuplicate = isDuplicate;
          if (_isNicknameDuplicate && focusNodes['nickname'] != null) {
            showTooltip(focusNodes['nickname']!, 'nickname');
          }
          break;
        case 'user_email':
          _isEmailDuplicate = isDuplicate;
          if (_isEmailDuplicate && focusNodes['email'] != null) {
            showTooltip(focusNodes['email']!, 'email');
          }

          // 이메일이 중복되면 인증 상태 초기화
          if (isDuplicate && (_isVerificationSent || _isEmailVerified)) {
            _isVerificationSent = false;
            _isEmailVerified = false;
            _verificationError = '';
            _verificationTimeLeft = 0;
            _verificationTimer?.cancel();
          }
          break;
      }
    });
  }

  // 이메일 인증번호 발송
  Future<void> sendVerificationEmail(String email) async {
    // 인증 상태 초기화
    _verificationTimer?.cancel();
    controllers['verificationCode']?.clear();

    updateUI(() {
      _isVerificationSent = true;
      _isEmailVerified = false;
      _verificationError = '';
      _verificationTimeLeft = 300; // 5분 = 300초
    });

    // 타이머 시작 - 1초마다 갱신
    _verificationTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      updateUI(() {
        if (_verificationTimeLeft > 0) {
          _verificationTimeLeft--;
        } else {
          timer.cancel();
        }
      });
    });

    // API 호출
    final response = await SignupApiService.sendVerificationEmail(email);

    if (!response['success']) {
      updateUI(() {
        _verificationError = response['message'];
      });

      // 오류 메시지 표시
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(response['message'])));
    } else {
      // 성공 메시지 표시
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('인증번호가 이메일로 발송되었습니다.')));
    }
  }

  // 인증번호 확인
  Future<void> verifyCode(String code) async {
    final email = controllers['email']!.text + _selectedDomain;

    // 인증 시간이 만료된 경우
    if (_verificationTimeLeft <= 0) {
      updateUI(() {
        _verificationError = SignupConstants.verificationExpired;
      });
      return;
    }

    final response = await SignupApiService.verifyCode(email, code);

    updateUI(() {
      if (response['success']) {
        _isEmailVerified = true;
        _verificationError = '';
        _verificationTimer?.cancel();

        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(SignupConstants.verificationSuccess),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _verificationError = response['message'];

        // 오류 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  // 이메일 유효성 설정
  void setEmailValid(bool isValid) {
    updateUI(() {
      _isEmailValid = isValid;
    });
  }

  // 도메인 업데이트
  void updateDomain(String newDomain) {
    updateUI(() {
      _selectedDomain = newDomain;
    });

    // 이메일이 변경되면 인증 상태 초기화
    if (_isVerificationSent || _isEmailVerified) {
      updateUI(() {
        _isVerificationSent = false;
        _isEmailVerified = false;
        _verificationError = '';
        _verificationTimeLeft = 0;
        _verificationTimer?.cancel();
      });
    }

    if (controllers['email']?.text.isNotEmpty ?? false) {
      _checkDuplicate(
        'user_email',
        controllers['email']!.text + _selectedDomain,
      );
    }
  }

  // 툴팁 표시
  void showTooltip(FocusNode node, String tooltipType) {
    _tooltipManager.showTooltip(context, node, tooltipType);
  }

  // 회원가입 처리
  Future<void> signup(GlobalKey<FormState> formKey) async {
    try {
      // 기본 폼 유효성 검증
      if (formKey.currentState?.validate() != true) {
        return;
      }

      // 중복 확인
      if (_isIdDuplicate) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('이미 사용 중인 아이디입니다.')));
        return;
      }

      if (_isNicknameDuplicate) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('이미 사용 중인 닉네임입니다.')));
        return;
      }

      if (_isEmailDuplicate) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('이미 사용 중인 이메일입니다.')));
        return;
      }

      // 이메일 유효성 확인
      bool isEmailValid = controllers['email']?.text.isNotEmpty ?? false;
      setEmailValid(isEmailValid);

      if (!_isEmailValid) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('올바른 이메일을 입력해주세요.')));
        return;
      }

      // 이메일 인증 확인
      if (!_isEmailVerified) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('이메일 인증이 필요합니다.')));
        return;
      }

      // 회원가입 데이터 준비
      final userData = {
        'user_name': controllers['name']?.text ?? '',
        'user_id': controllers['id']?.text ?? '',
        'user_nickname': controllers['nickname']?.text ?? '',
        'user_password': controllers['password']?.text ?? '',
        'user_email': (controllers['email']?.text ?? '') + _selectedDomain,
      };

      // API 호출
      final result = await SignupApiService.signup(userData);

      // 결과 처리
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'],
            style: const TextStyle(fontFamily: 'Pretendard'),
          ),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );

      // 성공 시 로그인 페이지로 이동
      if (result['success'] == true) {
        Navigator.of(context).pop(); // 로그인 페이지로 돌아가기
      }
    } catch (e) {
      print('회원가입 처리 중 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('회원가입 처리 중 오류가 발생했습니다: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 이메일 인증 상태 확인 (선택 사항)
  Future<void> checkEmailVerificationStatus() async {
    final email = controllers['email']!.text + _selectedDomain;
    try {
      final response = await SignupApiService.checkEmailVerification(email);

      updateUI(() {
        _isEmailVerified = response['verified'] ?? false;
      });

      if (_isEmailVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이메일 인증이 확인되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('이메일 인증 상태 확인 오류: $e');
    }
  }

  // 리소스 정리
  void dispose() {
    _idDebounceTimer?.cancel();
    _nicknameDebounceTimer?.cancel();
    _emailDebounceTimer?.cancel();
    _verificationTimer?.cancel();
    _tooltipManager.dispose();
  }

  bool obscurePasswordText = true; // 비밀번호 가리기 (기본값 true)
  bool obscureConfirmPasswordText = true; // 비밀번호 확인 가리기 (기본값 true)

  // 비밀번호 표시/숨김 토글 메서드
  void togglePasswordVisibility(Function setState) {
    setState(() {
      obscurePasswordText = !obscurePasswordText;
    });
  }

  // 비밀번호 확인 표시/숨김 토글 메서드
  void toggleConfirmPasswordVisibility(Function setState) {
    setState(() {
      obscureConfirmPasswordText = !obscureConfirmPasswordText;
    });
  }
}
