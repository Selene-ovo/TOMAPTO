import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';

// 폰트 사이즈 상수 정의
class AppFontSize {
  static const double small = 12.0;
  static const double medium = 14.0;
  static const double regular = 16.0;
  static const double large = 18.0;
  static const double extraLarge = 20.0;
  static const double headline = 24.0;
}

// 폰트 웨이트 상수 정의
class AppFontWeight {
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
}

// 텍스트 스타일 상수 정의
class AppTextStyle {
  static TextStyle get smallRegular => TextStyle(
    fontFamily: 'Pretendard',
    fontSize: AppFontSize.small,
    fontWeight: AppFontWeight.regular,
  );

  static TextStyle get mediumRegular => TextStyle(
    fontFamily: 'Pretendard',
    fontSize: AppFontSize.medium,
    fontWeight: AppFontWeight.regular,
  );

  static TextStyle get regularRegular => TextStyle(
    fontFamily: 'Pretendard',
    fontSize: AppFontSize.regular,
    fontWeight: AppFontWeight.regular,
  );

  static TextStyle get regularSemiBold => TextStyle(
    fontFamily: 'Pretendard',
    fontSize: AppFontSize.regular,
    fontWeight: AppFontWeight.semiBold,
  );

  static TextStyle get regularBold => TextStyle(
    fontFamily: 'Pretendard',
    fontSize: AppFontSize.regular,
    fontWeight: AppFontWeight.bold,
  );

  static TextStyle get largeBold => TextStyle(
    fontFamily: 'Pretendard',
    fontSize: AppFontSize.large,
    fontWeight: AppFontWeight.bold,
  );
}

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '회원가입',
      theme: ThemeData(
        fontFamily: 'Pretendard',
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        textTheme: TextTheme(
          bodyLarge: TextStyle(fontFamily: 'Pretendard'),
          bodyMedium: TextStyle(fontFamily: 'Pretendard'),
          bodySmall: TextStyle(fontFamily: 'Pretendard'),
          titleLarge: TextStyle(fontFamily: 'Pretendard'),
          titleMedium: TextStyle(fontFamily: 'Pretendard'),
          titleSmall: TextStyle(fontFamily: 'Pretendard'),
          labelLarge: TextStyle(fontFamily: 'Pretendard'),
          labelMedium: TextStyle(fontFamily: 'Pretendard'),
          labelSmall: TextStyle(fontFamily: 'Pretendard'),
        ),
      ),
      home: const SignUpPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController(); // 스크롤 컨트롤러 추가

  // 텍스트 컨트롤러들
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // 이메일 도메인 관련 변수
  String _selectedDomain = '@naver.com';
  final List<String> _domains = [
    '@naver.com',
    '@kakao.com',
    '@daum.net',
    '@hanmail.net',
  ];

  // 중복 검사 상태 변수
  bool _isIdDuplicate = false;
  bool _isNicknameDuplicate = false;
  bool _isEmailDuplicate = false;
  bool _isEmailValid = true;

  // 포커스 노드들
  final FocusNode _idFocusNode = FocusNode();
  final FocusNode _nicknameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  // 디바운스 타이머들
  Timer? _idDebounceTimer;
  Timer? _nicknameDebounceTimer;
  Timer? _emailDebounceTimer;

  // 현재 툴팁 정보 변수들
  OverlayEntry? _currentTooltip;
  String? _currentTooltipType; // 현재 표시 중인 툴팁 타입
  GlobalKey _fixedTooltipKey = GlobalKey(); // 툴팁의 고정 위치를 위한 키

  // 각 필드별 툴팁 이미지 경로
  final Map<String, String> _tooltipImages = {
    'id': 'assets/icons/id_tooltip.svg',
    'nickname': 'assets/icons/nickname_tooltip.svg',
    'password': 'assets/icons/password_tooltip.svg',
    'password_confirm': 'assets/icons/password_confirm_tooltip.svg',
    'email': 'assets/icons/email_tooltip.svg',
  };

  @override
  void initState() {
    super.initState();

    // 포커스 리스너 추가
    _idFocusNode.addListener(_onIdFocusChange);
    _nicknameFocusNode.addListener(_onNicknameFocusChange);
    _emailFocusNode.addListener(_onEmailFocusChange);

    // 텍스트 컨트롤러 리스너 추가
    _idController.addListener(_onIdChanged);
    _nicknameController.addListener(_onNicknameChanged);
    _emailController.addListener(_onEmailChanged);

    // 스크롤 리스너 추가 - 고정 툴팁 위치를 위해
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    // 컨트롤러 해제
    _nameController.dispose();
    _idController.dispose();
    _nicknameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();

    // 포커스 노드 해제
    _idFocusNode.dispose();
    _nicknameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();

    // 타이머 해제
    _idDebounceTimer?.cancel();
    _nicknameDebounceTimer?.cancel();
    _emailDebounceTimer?.cancel();

    // 스크롤 컨트롤러 해제
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();

    // 툴팁 제거
    _removeTooltip();

    super.dispose();
  }

  // 스크롤 이벤트 핸들러 - 툴팁이 표시되어 있다면 제거
  void _onScroll() {
    // 스크롤 시 툴팁 제거
    if (_currentTooltip != null) {
      _removeTooltip();
    }
  }

  // 포커스 변경 핸들러들
  void _onIdFocusChange() {
    if (!_idFocusNode.hasFocus && _idController.text.isNotEmpty) {
      _checkIdDuplicate(_idController.text);
    } else if (!_idFocusNode.hasFocus) {
      _removeTooltip();
    }
  }

  void _onNicknameFocusChange() {
    if (!_nicknameFocusNode.hasFocus && _nicknameController.text.isNotEmpty) {
      _checkNicknameDuplicate(_nicknameController.text);
    } else if (!_nicknameFocusNode.hasFocus) {
      _removeTooltip();
    }
  }

  void _onEmailFocusChange() {
    if (!_emailFocusNode.hasFocus && _emailController.text.isNotEmpty) {
      _checkEmailDuplicate(_emailController.text + _selectedDomain);
    } else if (!_emailFocusNode.hasFocus) {
      _removeTooltip();
    }
  }

  // 텍스트 변경 핸들러들
  void _onIdChanged() {
    _idDebounceTimer?.cancel();
    if (_idController.text.isNotEmpty) {
      _idDebounceTimer = Timer(const Duration(milliseconds: 100), () {
        _checkIdDuplicate(_idController.text);
      });
    } else {
      setState(() {
        _isIdDuplicate = false;
      });
      _removeTooltip();
    }
  }

  void _onNicknameChanged() {
    _nicknameDebounceTimer?.cancel();
    if (_nicknameController.text.isNotEmpty) {
      _nicknameDebounceTimer = Timer(const Duration(milliseconds: 100), () {
        _checkNicknameDuplicate(_nicknameController.text);
      });
    } else {
      setState(() {
        _isNicknameDuplicate = false;
      });
      _removeTooltip();
    }
  }

  void _onEmailChanged() {
    _emailDebounceTimer?.cancel();
    if (_emailController.text.isNotEmpty) {
      _emailDebounceTimer = Timer(const Duration(milliseconds: 100), () {
        _checkEmailDuplicate(_emailController.text + _selectedDomain);
      });
    } else {
      setState(() {
        _isEmailDuplicate = false;
      });
      _removeTooltip();
    }
  }

  // API 기본 URL 획득
  String get _apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000/api';

  // 중복 검사 API 호출 함수들
  Future<void> _checkIdDuplicate(String id) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_apiBaseUrl/account/check-duplicate?field=user_id&value=$id',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isIdDuplicate = data['isDuplicate'] ?? false;
        });

        if (_isIdDuplicate) {
          _showTooltip(_idFocusNode, 'id');
        } else {
          _removeTooltip();
        }
      } else {
        print('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('ID 중복 확인 중 오류 발생: $e');
    }
  }

  Future<void> _checkNicknameDuplicate(String nickname) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_apiBaseUrl/account/check-duplicate?field=user_nickname&value=$nickname',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isNicknameDuplicate = data['isDuplicate'] ?? false;
        });

        if (_isNicknameDuplicate) {
          _showTooltip(_nicknameFocusNode, 'nickname');
        } else {
          _removeTooltip();
        }
      } else {
        print('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('닉네임 중복 확인 중 오류 발생: $e');
    }
  }

  Future<void> _checkEmailDuplicate(String email) async {
    try {
      final encodedEmail = Uri.encodeComponent(email);

      final response = await http.get(
        Uri.parse(
          '$_apiBaseUrl/account/check-duplicate?field=user_email&value=$encodedEmail',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isEmailDuplicate = data['isDuplicate'] ?? false;
        });

        if (_isEmailDuplicate) {
          _showTooltip(_emailFocusNode, 'email');
        } else {
          _removeTooltip();
        }
      } else {
        print('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('이메일 중복 확인 중 오류 발생: $e');
    }
  }

  // 툴팁 표시 함수 - 앱 전체에 고정된 오버레이 사용
  void _showTooltip(FocusNode node, String tooltipType) {
    // 이전 툴팁 제거
    _removeTooltip();

    // 현재 화면 상태 가져오기 - MaterialApp의 최상위 네비게이터 키를 사용하는 것이 가장 좋습니다
    final overlay = Overlay.of(context);

    // 필드의 실제 화면 위치 구하기
    final RenderBox fieldBox = node.context!.findRenderObject() as RenderBox;
    final fieldPosition = fieldBox.localToGlobal(Offset.zero);
    final fieldSize = fieldBox.size;

    // 툴팁 이미지 경로 가져오기
    final String imagePath =
        _tooltipImages[tooltipType] ?? 'assets/icons/error_circle.svg';

    // 툴팁 위치 계산 - 필드 타입에 따라 다르게 처리
    double left = fieldPosition.dx + fieldSize.width - 135;
    double top = fieldPosition.dy + fieldSize.height + 3;

    // 이메일 필드는 특별 처리
    if (tooltipType == 'email') {
      left = fieldPosition.dx + fieldSize.width + 18;
    }

    // 현재 타입 저장
    _currentTooltipType = tooltipType;

    // OverlayEntry 생성 - 화면에 고정된 위치로 표시
    _currentTooltip = OverlayEntry(
      // 중요: 여기서 OverlayEntry는 화면 전체에 걸쳐 있으며 스크롤과 무관함
      builder: (context) {
        return Stack(
          children: [
            // 투명 전체 화면 - 툴팁 외부 터치 처리용
            Positioned.fill(
              child: GestureDetector(
                onTap: _removeTooltip,
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
              ),
            ),
            // 고정된 위치에 툴팁 표시
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

    // 오버레이에 툴팁 추가
    overlay.insert(_currentTooltip!);
  }

  // 툴팁 제거 함수
  void _removeTooltip() {
    if (_currentTooltip != null) {
      _currentTooltip!.remove();
      _currentTooltip = null;
      _currentTooltipType = null;
    }
  }

  // 회원가입 실행 함수
  Future<void> _signUp() async {
    bool isEmailValid = _emailController.text.isNotEmpty;
    setState(() {
      _isEmailValid = isEmailValid;
    });

    // 유효성 검사 통과 시에만 회원가입 진행
    if (_formKey.currentState!.validate() &&
        !_isIdDuplicate &&
        !_isNicknameDuplicate &&
        !_isEmailDuplicate &&
        _isEmailValid) {
      try {
        // 회원가입 데이터 준비
        final userData = {
          'user_name': _nameController.text,
          'user_id': _idController.text,
          'user_nickname': _nicknameController.text,
          'user_password': _passwordController.text,
          'user_email': _emailController.text + _selectedDomain,
        };

        // API 호출
        final response = await http.post(
          Uri.parse('$_apiBaseUrl/account/signup'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(userData),
        );

        // 응답 처리
        if (response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '회원가입이 완료되었습니다.',
                style: TextStyle(fontFamily: 'Pretendard'),
              ),
            ),
          );

          // 로그인 페이지로 이동 (주석 처리됨)
          // Navigator.of(context).pushReplacementNamed('/login');
        } else {
          // 오류 처리
          final errorData = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorData['message'] ?? '회원가입 중 오류가 발생했습니다.',
                style: TextStyle(fontFamily: 'Pretendard'),
              ),
            ),
          );
        }
      } catch (e) {
        print('회원가입 중 오류 발생: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '회원가입 중 오류가 발생했습니다.',
              style: TextStyle(fontFamily: 'Pretendard'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '회원가입',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: AppFontWeight.bold,
            fontSize: AppFontSize.large,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController, // 스크롤 컨트롤러 연결
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 이름 필드
                buildInputField(
                  controller: _nameController,
                  labelText: '이름',
                  hintText: '이름을 적어주세요.',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '';
                    }
                    return null;
                  },
                  isRequired: true,
                ),
                const SizedBox(height: 16),

                // 아이디 필드
                buildInputField(
                  controller: _idController,
                  labelText: '아이디',
                  hintText: '아이디를 적어주세요.',
                  focusNode: _idFocusNode,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '';
                    }
                    return null;
                  },
                  isRequired: true,
                  hasError: _isIdDuplicate,
                  suffixIcon:
                      _idController.text.isNotEmpty
                          ? _buildStatusIcon(_isIdDuplicate)
                          : null,
                ),
                const SizedBox(height: 16),

                // 닉네임 필드
                buildInputField(
                  controller: _nicknameController,
                  labelText: '닉네임',
                  hintText: '닉네임을 적어주세요.',
                  focusNode: _nicknameFocusNode,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '';
                    }
                    return null;
                  },
                  isRequired: true,
                  hasError: _isNicknameDuplicate,
                  suffixIcon:
                      _nicknameController.text.isNotEmpty
                          ? _buildStatusIcon(_isNicknameDuplicate)
                          : null,
                ),
                const SizedBox(height: 16),

                // 비밀번호 필드
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 비밀번호 라벨
                    RichText(
                      text: TextSpan(
                        text: '비밀번호',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          color: Colors.black,
                          fontWeight: AppFontWeight.semiBold,
                          fontSize: AppFontSize.regular,
                        ),
                        children: const [
                          TextSpan(
                            text: '*',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              color: Colors.red,
                              fontWeight: AppFontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 비밀번호 입력 필드
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      focusNode: _passwordFocusNode,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: AppFontSize.regular,
                      ),
                      decoration: InputDecoration(
                        hintText: '비밀번호를 적어주세요.',
                        hintStyle: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: AppFontSize.regular,
                          color: Colors.grey,
                        ),
                        suffixIcon: const Icon(
                          Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        // 테두리 스타일 통합
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1.0,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1.0,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.blue,
                            width: 1.0,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.red, width: 1.0),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.red, width: 1.0),
                        ),
                        errorStyle: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: AppFontSize.small,
                          color: Colors.red,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '';
                        }
                        if (value.length < 8) {
                          _showTooltip(_passwordFocusNode, 'password');
                          return '';
                        }
                        return null;
                      },
                    ),
                    Padding(
                      padding: EdgeInsets.only(left: 5, top: 1),
                      child: Text(
                        '문자와 숫자가 포함된 8자리 이상의 조합으로 설정해주세요.',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          color: Colors.grey,
                          fontSize: AppFontSize.small,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 비밀번호 확인 필드
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 비밀번호 확인 라벨
                    RichText(
                      text: TextSpan(
                        text: '비밀번호 확인',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          color: Colors.black,
                          fontWeight: AppFontWeight.semiBold,
                          fontSize: AppFontSize.regular,
                        ),
                        children: const [
                          TextSpan(
                            text: '*',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              color: Colors.red,
                              fontWeight: AppFontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 비밀번호 확인 입력 필드
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      focusNode: _confirmPasswordFocusNode,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: AppFontSize.regular,
                      ),
                      decoration: InputDecoration(
                        hintText: '비밀번호를 적어주세요.',
                        hintStyle: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: AppFontSize.regular,
                          color: Colors.grey,
                        ),
                        suffixIcon: const Icon(
                          Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        // 테두리 스타일 통합
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1.0,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1.0,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.blue,
                            width: 1.0,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.red, width: 1.0),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.red, width: 1.0),
                        ),
                        errorStyle: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: AppFontSize.small,
                          color: Colors.red,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '';
                        }
                        if (value != _passwordController.text) {
                          _showTooltip(
                            _confirmPasswordFocusNode,
                            'password_confirm',
                          );
                          return null;
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 이메일 입력 필드와 드롭다운
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이메일 라벨
                    RichText(
                      text: TextSpan(
                        text: '이메일',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          color: Colors.black,
                          fontWeight: AppFontWeight.semiBold,
                          fontSize: AppFontSize.regular,
                        ),
                        children: const [
                          TextSpan(
                            text: '*',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 통합된 입력 필드와 드롭다운
                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        Container(
                          height: 56,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color:
                                  (!_isEmailValid || _isEmailDuplicate)
                                      ? Colors.red
                                      : Colors.grey.shade300,
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              // 이메일 입력 부분
                              Expanded(
                                child: TextFormField(
                                  controller: _emailController,
                                  focusNode: _emailFocusNode,
                                  style: TextStyle(fontFamily: 'Pretendard'),
                                  decoration: InputDecoration(
                                    hintText: '이메일을 적어주세요.',
                                    hintStyle: TextStyle(
                                      fontFamily: 'Pretendard',
                                      color: Colors.grey,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    border: InputBorder.none, // 경계선 제거
                                    errorStyle: const TextStyle(
                                      height: -5,
                                    ), // 에러 텍스트 숨김
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      setState(() {
                                        _isEmailValid = false;
                                      });
                                      return '';
                                    }
                                    setState(() {
                                      _isEmailValid = true;
                                    });
                                    return null;
                                  },
                                ),
                              ),
                              // 구분선
                              Container(
                                width: 0.4,
                                height: 30,
                                color: Colors.grey.shade300,
                              ),
                              // 도메인 드롭다운
                              Container(
                                width: 140,
                                child: DropdownButtonHideUnderline(
                                  child: ButtonTheme(
                                    alignedDropdown: true,
                                    child: DropdownButton<String>(
                                      value: _selectedDomain,
                                      icon: const Icon(Icons.arrow_drop_down),
                                      iconSize: 24,
                                      isExpanded: true,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 0,
                                      ),
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          _selectedDomain = newValue!;
                                        });
                                        if (_emailController.text.isNotEmpty) {
                                          _checkEmailDuplicate(
                                            _emailController.text +
                                                _selectedDomain,
                                          );
                                        }
                                      },
                                      items:
                                          _domains.map<
                                            DropdownMenuItem<String>
                                          >((String value) {
                                            return DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(
                                                value,
                                                style: TextStyle(
                                                  fontFamily: 'Pretendard',
                                                  fontSize: AppFontSize.medium,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                              // 상태 아이콘을 위한 여백 추가
                              SizedBox(width: 40),
                            ],
                          ),
                        ),
                        // 상태 아이콘 (이메일이 비어있지 않을 때만 표시)
                        if (_emailController.text.isNotEmpty)
                          Positioned(
                            right: 16,
                            child: Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              child: SvgPicture.asset(
                                _isEmailDuplicate
                                    ? 'assets/icons/error_circle.svg'
                                    : 'assets/icons/check_circle.svg',
                                width: 36,
                                height: 24,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 약관 동의 섹션
                    buildAgreementCheckbox(
                      text: '약관에 모두 동의합니다',
                      value: true,
                      onChanged: (value) {},
                      isAll: true,
                    ),
                    const Divider(),
                    buildAgreementCheckbox(
                      text: '[필수] 서비스 이용약관 동의',
                      value: true,
                      onChanged: (value) {},
                      isRequired: true,
                      hasArrow: true,
                    ),
                    buildAgreementCheckbox(
                      text: '[필수] 개인정보 수집 및 이용 동의',
                      value: true,
                      onChanged: (value) {},
                      isRequired: true,
                      hasArrow: true,
                    ),
                    buildAgreementCheckbox(
                      text: '[선택] 홍보성 정보 수신 동의',
                      value: false,
                      onChanged: (value) {},
                      hasArrow: false,
                    ),
                    const SizedBox(height: 24),

                    // 가입하기 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _signUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          '가입하기',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: AppFontSize.large,
                            fontWeight: AppFontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 입력 필드 생성 헬퍼 메서드
  Widget buildInputField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    bool obscureText = false,
    FocusNode? focusNode,
    String? Function(String?)? validator,
    bool isRequired = false,
    bool hasError = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: labelText,
            style: TextStyle(
              fontFamily: 'Pretendard',
              color: Color(0xFF363636),
              fontWeight: AppFontWeight.semiBold,
              fontSize: AppFontSize.regular,
            ),
            children:
                isRequired
                    ? [
                      TextSpan(
                        text: '*',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          color: Color(0xFFFB233B),
                          fontWeight: AppFontWeight.bold,
                        ),
                      ),
                    ]
                    : null,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: AppFontSize.regular,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: AppFontSize.regular,
              color: Colors.grey,
            ),
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            // 테두리 스타일 통합
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError ? Colors.red : Colors.grey.shade300,
                width: 1.0,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError ? Colors.red : Colors.grey.shade300,
                width: 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError ? Colors.red : Colors.blue,
                width: 1.0,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 1.0),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 1.0),
            ),
            errorStyle: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: AppFontSize.small,
              color: Colors.red,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  // 상태 아이콘 생성 헬퍼 메서드
  Widget _buildStatusIcon(bool isError) {
    return Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.only(right: 20),
      child:
          isError
              ? SvgPicture.asset('assets/icons/error_circle.svg')
              : SvgPicture.asset('assets/icons/check_circle.svg'),
    );
  }

  // 약관 동의 체크박스 생성 헬퍼 메서드
  Widget buildAgreementCheckbox({
    required String text,
    required bool value,
    required Function(bool?) onChanged,
    bool isRequired = false,
    bool isAll = false,
    bool hasArrow = false,
  }) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          shape: const CircleBorder(),
          activeColor: isAll ? Colors.grey : Colors.red,
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: isAll ? AppFontWeight.bold : AppFontWeight.regular,
              fontSize: AppFontSize.regular,
            ),
          ),
        ),
        if (hasArrow) const Icon(Icons.chevron_right, color: Colors.grey),
      ],
    );
  }
}
