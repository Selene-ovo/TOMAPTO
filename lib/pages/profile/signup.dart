import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tomapto/controllers/account/signup_controller.dart';
import 'package:tomapto/pages/profile/login.dart';

// 스타일 상수 정의 - 일관된 스타일 적용을 위한 중앙 관리
class SignupStyles {
  // 색상
  static const Color primaryRed = Color(0xFFFB233B);
  static const Color primaryText = Color(0xFF363636);
  static const Color secondaryText = Color(0xFFB6B6B6);
  static const Color borderColor = Color(0xFFE0E0E0);

  // 크기
  static const double inputHeight = 56.0;
  static const double borderRadius = 16.0;
  static const double labelFontSize = 16.0;
  static const double hintFontSize = 16.0;
  static const double buttonFontSize = 18.0;

  // 패딩 및 마진
  static const EdgeInsets fieldPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 16,
  );
  static const double fieldSpacing = 16.0;
  static const double smallSpacing = 8.0;

  // 텍스트 스타일
  static const TextStyle labelStyle = TextStyle(
    fontFamily: 'Pretendard',
    color: primaryText,
    fontWeight: FontWeight.w500,
    fontSize: labelFontSize,
  );

  static const TextStyle hintStyle = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: hintFontSize,
    color: Colors.grey,
  );

  static const TextStyle errorStyle = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 12.0,
    color: primaryRed,
  );

  static const TextStyle buttonStyle = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: buttonFontSize,
    fontWeight: FontWeight.bold,
  );

  // 입력 필드 테두리 스타일
  static OutlineInputBorder defaultBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(borderRadius),
    borderSide: const BorderSide(color: borderColor, width: 1.0),
  );

  static OutlineInputBorder focusedBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(borderRadius),
    borderSide: const BorderSide(color: Colors.blue, width: 1.0),
  );

  static OutlineInputBorder errorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(borderRadius),
    borderSide: const BorderSide(color: primaryRed, width: 1.0),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const SignUpPage(),
    );
  }
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final GlobalKey _emailFieldKey = GlobalKey();

  // 커스텀 드롭다운을 위한 변수
  bool _isDropdownOpen = false;
  OverlayEntry? _dropdownOverlay;

  // 컨트롤러 맵 - 컨트롤러를 효율적으로 관리
  late final Map<String, TextEditingController> _controllers = {
    'name': TextEditingController(),
    'id': TextEditingController(),
    'nickname': TextEditingController(),
    'password': TextEditingController(),
    'confirmPassword': TextEditingController(),
    'email': TextEditingController(),
  };

  // 포커스 노드 맵 - 포커스 노드를 효율적으로 관리
  late final Map<String, FocusNode> _focusNodes = {
    'id': FocusNode(),
    'nickname': FocusNode(),
    'password': FocusNode(),
    'confirmPassword': FocusNode(),
    'email': FocusNode(),
  };

  // 회원가입 컨트롤러
  late SignupController _signupController;

  // 약관 동의 상태 변수
  bool _allAgreements = true;
  bool _serviceAgreement = true;
  bool _privacyAgreement = true;
  bool _marketingAgreement = false;

  @override
  void initState() {
    super.initState();

    // 컨트롤러 초기화
    _signupController = SignupController(
      context: context,
      controllers: _controllers,
      focusNodes: _focusNodes,
      scrollController: _scrollController,
      updateUI: setState,
    );
  }

  @override
  void dispose() {
    // 드롭다운 오버레이 제거
    _removeDropdownOverlay();

    // 컨트롤러와 포커스 노드 해제
    _controllers.forEach((_, controller) => controller.dispose());
    _focusNodes.forEach((_, node) => node.dispose());

    // 스크롤 컨트롤러 해제
    _scrollController.dispose();

    // 회원가입 컨트롤러 정리
    _signupController.dispose();

    super.dispose();
  }

  // 드롭다운 오버레이 표시 메서드
  void _showDropdownOverlay(BuildContext context, GlobalKey emailFieldKey) {
    // 기존 오버레이 제거
    _removeDropdownOverlay();

    // 현재 위젯의 위치 구하기
    final RenderBox renderBox =
        emailFieldKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);

    _dropdownOverlay = OverlayEntry(
      builder: (context) => _buildDropdownOverlay(offset, renderBox.size),
    );

    Overlay.of(context).insert(_dropdownOverlay!);
    setState(() {
      _isDropdownOpen = true;
    });
  }

  // 드롭다운 오버레이 UI 구성 - 위젯 분리
  Widget _buildDropdownOverlay(Offset offset, Size renderBoxSize) {
    return Positioned(
      left: offset.dx + renderBoxSize.width - 150,
      top: offset.dy + renderBoxSize.height + 5,
      child: Material(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 120,
          height: 110,
          child: Stack(
            children: [
              // 드롭다운 배경
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  width: 120,
                  height: 110,
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    shadows: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                        offset: const Offset(0, 1),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),

              // 드롭다운 아이템
              ..._signupController.domains.asMap().entries.map((entry) {
                int index = entry.key;
                String domain = entry.value;
                return Positioned(
                  left: 12,
                  top: index * 28 + 2,
                  child: GestureDetector(
                    onTap: () {
                      _signupController.updateDomain(domain);
                      _removeDropdownOverlay();
                    },
                    child: Text(
                      domain,
                      style: const TextStyle(
                        color: SignupStyles.primaryText,
                        fontSize: 13,
                        fontFamily: 'Pretendard Variable',
                        fontWeight: FontWeight.w400,
                        height: 1.83,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // 드롭다운 오버레이 제거 메서드
  void _removeDropdownOverlay() {
    if (_dropdownOverlay != null) {
      _dropdownOverlay!.remove();
      _dropdownOverlay = null;
      setState(() {
        _isDropdownOpen = false;
      });
    }
  }

  // 약관 동의 상태 변경 처리
  void _handleAgreementChange(String type, bool? value) {
    if (value == null) return;

    setState(() {
      switch (type) {
        case 'all':
          _allAgreements = value;
          _serviceAgreement = value;
          _privacyAgreement = value;
          _marketingAgreement = value;
          break;
        case 'service':
          _serviceAgreement = value;
          _updateAllAgreementsState();
          break;
        case 'privacy':
          _privacyAgreement = value;
          _updateAllAgreementsState();
          break;
        case 'marketing':
          _marketingAgreement = value;
          _updateAllAgreementsState();
          break;
      }
    });
  }

  // 전체 동의 상태 업데이트
  void _updateAllAgreementsState() {
    _allAgreements =
        _serviceAgreement && _privacyAgreement && _marketingAgreement;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 배경 터치 시 드롭다운 닫기 및 포커스 해제
        _removeDropdownOverlay();
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: SingleChildScrollView(
          controller: _scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 이름 입력 필드
                  _buildInputField(
                    controller: _controllers['name']!,
                    labelText: '이름',
                    hintText: '이름을 적어주세요.',
                    validator: _validateRequired,
                    isRequired: true,
                  ),
                  const SizedBox(height: SignupStyles.fieldSpacing),

                  // 아이디 입력 필드
                  _buildInputField(
                    controller: _controllers['id']!,
                    labelText: '아이디',
                    hintText: '아이디를 적어주세요.',
                    focusNode: _focusNodes['id'],
                    validator: _validateRequired,
                    isRequired: true,
                    hasError: _signupController.isIdDuplicate,
                    suffixIcon:
                        _controllers['id']!.text.isNotEmpty
                            ? _buildStatusIcon(_signupController.isIdDuplicate)
                            : null,
                  ),
                  const SizedBox(height: SignupStyles.fieldSpacing),

                  // 닉네임 입력 필드
                  _buildInputField(
                    controller: _controllers['nickname']!,
                    labelText: '닉네임',
                    hintText: '닉네임을 적어주세요.',
                    focusNode: _focusNodes['nickname'],
                    validator: _validateRequired,
                    isRequired: true,
                    hasError: _signupController.isNicknameDuplicate,
                    suffixIcon:
                        _controllers['nickname']!.text.isNotEmpty
                            ? _buildStatusIcon(
                              _signupController.isNicknameDuplicate,
                            )
                            : null,
                  ),
                  const SizedBox(height: SignupStyles.fieldSpacing),

                  // 비밀번호 필드
                  _buildPasswordField(),
                  const SizedBox(height: SignupStyles.fieldSpacing),

                  // 비밀번호 확인 필드
                  _buildConfirmPasswordField(),
                  const SizedBox(height: SignupStyles.fieldSpacing),

                  // 이메일 입력 필드와 드롭다운
                  _buildEmailField(),
                  const SizedBox(height: 24),

                  // 약관 동의 섹션
                  _buildAgreementsSection(),
                  const SizedBox(height: 24),

                  // 가입하기 버튼
                  _buildSignupButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 앱바 구성
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      scrolledUnderElevation: 0,
      title: const Text(
        '회원가입',
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w600,
          fontSize: 22.0,
          color: SignupStyles.primaryText,
        ),
      ),
      leading: IconButton(
        icon: SvgPicture.asset('assets/icons/back.svg', width: 24, height: 24),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  // 필수 입력 검증
  String? _validateRequired(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }
    return null;
  }

  // 비밀번호 검증
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }
    if (value.length < 8) {
      _signupController.showTooltip(_focusNodes['password']!, 'password');
      return '';
    }
    return null;
  }

  // 비밀번호 확인 검증
  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }
    if (value != _controllers['password']!.text) {
      _signupController.showTooltip(
        _focusNodes['confirmPassword']!,
        'password_confirm',
      );
      return '';
    }
    return null;
  }

  // 입력 필드 구성
  Widget _buildInputField({
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
        // 라벨
        RichText(
          text: TextSpan(
            text: labelText,
            style: SignupStyles.labelStyle,
            children:
                isRequired
                    ? [
                      const TextSpan(
                        text: '*',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          color: SignupStyles.primaryRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ]
                    : null,
          ),
        ),
        const SizedBox(height: SignupStyles.smallSpacing),

        // 입력 필드
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          style: const TextStyle(fontFamily: 'Pretendard', fontSize: 16.0),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: SignupStyles.hintStyle,
            suffixIcon: suffixIcon,
            contentPadding: SignupStyles.fieldPadding,
            border: SignupStyles.defaultBorder,
            enabledBorder:
                hasError
                    ? SignupStyles.errorBorder
                    : SignupStyles.defaultBorder,
            focusedBorder:
                hasError
                    ? SignupStyles.errorBorder
                    : SignupStyles.focusedBorder,
            errorBorder: SignupStyles.errorBorder,
            focusedErrorBorder: SignupStyles.errorBorder,
            errorStyle: SignupStyles.errorStyle,
          ),
          validator: validator,
        ),
      ],
    );
  }

  // 비밀번호 필드 구성
  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 비밀번호 라벨
        RichText(
          text: TextSpan(
            text: '비밀번호',
            style: SignupStyles.labelStyle,
            children: [
              TextSpan(
                text: '*',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  color: SignupStyles.primaryRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SignupStyles.smallSpacing),

        // 비밀번호 입력 필드
        TextFormField(
          controller: _controllers['password'],
          obscureText: true,
          focusNode: _focusNodes['password'],
          style: const TextStyle(fontFamily: 'Pretendard', fontSize: 16.0),
          decoration: InputDecoration(
            hintText: '비밀번호를 적어주세요.',
            hintStyle: SignupStyles.hintStyle,
            suffixIcon: const Icon(Icons.visibility_off, color: Colors.grey),
            contentPadding: SignupStyles.fieldPadding,
            border: SignupStyles.defaultBorder,
            enabledBorder: SignupStyles.defaultBorder,
            focusedBorder: SignupStyles.focusedBorder,
            errorBorder: SignupStyles.errorBorder,
            focusedErrorBorder: SignupStyles.errorBorder,
            errorStyle: SignupStyles.errorStyle,
          ),
          validator: _validatePassword,
        ),

        // 도움말 텍스트
        const Padding(
          padding: EdgeInsets.only(left: 5, top: 1),
          child: Text(
            '문자와 숫자가 포함된 8자리 이상의 조합으로 설정해주세요.',
            style: TextStyle(
              fontFamily: 'Pretendard',
              color: Colors.grey,
              fontSize: 12.0,
            ),
          ),
        ),
      ],
    );
  }

  // 비밀번호 확인 필드 구성
  Widget _buildConfirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 비밀번호 확인 라벨
        RichText(
          text: TextSpan(
            text: '비밀번호 확인',
            style: SignupStyles.labelStyle,
            children: [
              TextSpan(
                text: '*',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  color: SignupStyles.primaryRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SignupStyles.smallSpacing),

        // 비밀번호 확인 입력 필드
        TextFormField(
          controller: _controllers['confirmPassword'],
          obscureText: true,
          focusNode: _focusNodes['confirmPassword'],
          style: const TextStyle(fontFamily: 'Pretendard', fontSize: 16.0),
          decoration: InputDecoration(
            hintText: '비밀번호를 적어주세요.',
            hintStyle: SignupStyles.hintStyle,
            suffixIcon: const Icon(Icons.visibility_off, color: Colors.grey),
            contentPadding: SignupStyles.fieldPadding,
            border: SignupStyles.defaultBorder,
            enabledBorder: SignupStyles.defaultBorder,
            focusedBorder: SignupStyles.focusedBorder,
            errorBorder: SignupStyles.errorBorder,
            focusedErrorBorder: SignupStyles.errorBorder,
            errorStyle: SignupStyles.errorStyle,
          ),
          validator: _validateConfirmPassword,
        ),
      ],
    );
  }

  // 이메일 필드와 인증 필드 부분만 변경
  // signup.dart 파일 내 _buildEmailField() 메서드를 대체합니다.

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 이메일 라벨
        RichText(
          text: TextSpan(
            text: '이메일',
            style: SignupStyles.labelStyle,
            children: [
              TextSpan(
                text: '*',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  color: SignupStyles.primaryRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SignupStyles.smallSpacing),

        // 통합된 입력 필드와 드롭다운
        Stack(
          key: _emailFieldKey,
          alignment: Alignment.centerRight,
          children: [
            Container(
              height: SignupStyles.inputHeight,
              decoration: BoxDecoration(
                border: Border.all(
                  color:
                      (!_signupController.isEmailValid ||
                              _signupController.isEmailDuplicate)
                          ? SignupStyles.primaryRed
                          : SignupStyles.borderColor,
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(SignupStyles.borderRadius),
              ),
              child: Row(
                children: [
                  // 이메일 입력 부분
                  Expanded(
                    child: TextFormField(
                      controller: _controllers['email'],
                      focusNode: _focusNodes['email'],
                      style: const TextStyle(fontFamily: 'Pretendard'),
                      decoration: const InputDecoration(
                        hintText: '이메일을 적어주세요.',
                        hintStyle: SignupStyles.hintStyle,
                        contentPadding: SignupStyles.fieldPadding,
                        border: InputBorder.none,
                        errorStyle: TextStyle(height: -5),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          _signupController.setEmailValid(false);
                          return '';
                        }
                        _signupController.setEmailValid(true);
                        return null;
                      },
                    ),
                  ),

                  // 구분선
                  Container(
                    width: 0.4,
                    height: 30,
                    color: SignupStyles.borderColor,
                  ),

                  // 커스텀 도메인 드롭다운
                  InkWell(
                    onTap: () {
                      if (_isDropdownOpen) {
                        _removeDropdownOverlay();
                      } else {
                        _showDropdownOverlay(context, _emailFieldKey);
                      }
                    },
                    child: Container(
                      width: 140,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _signupController.selectedDomain,
                            style: const TextStyle(
                              color: SignupStyles.primaryText,
                              fontSize: 13,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Icon(
                            _isDropdownOpen
                                ? Icons.arrow_drop_up
                                : Icons.arrow_drop_down,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 상태 아이콘을 위한 공간
                  const SizedBox(width: 20),
                ],
              ),
            ),

            // 상태 아이콘 (이메일이 비어 있지 않을 때만 표시)
            if (_controllers['email']!.text.isNotEmpty)
              Positioned(
                right: 16,
                child: _buildStatusIcon(_signupController.isEmailDuplicate),
              ),
          ],
        ),

        // 이메일 인증번호 요청 버튼
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!_signupController.isEmailVerified &&
                  !_signupController.isVerificationSent)
                ElevatedButton(
                  onPressed: () {
                    // 이메일이 유효한지 확인
                    final email =
                        _controllers['email']!.text +
                        _signupController.selectedDomain;
                    if (email.isNotEmpty) {
                      _signupController.sendVerificationEmail(email);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('이메일을 입력해주세요.')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: SignupStyles.primaryText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(100, 36),
                  ),
                  child: const Text('인증번호 받기', style: TextStyle(fontSize: 12)),
                ),

              if (!_signupController.isEmailVerified &&
                  _signupController.isVerificationSent)
                ElevatedButton(
                  onPressed: () {
                    final email =
                        _controllers['email']!.text +
                        _signupController.selectedDomain;
                    _signupController.sendVerificationEmail(email);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: SignupStyles.primaryText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(100, 36),
                  ),
                  child: const Text('인증번호 재발급', style: TextStyle(fontSize: 12)),
                ),

              if (_signupController.isEmailVerified)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 14),
                      SizedBox(width: 4),
                      Text(
                        '인증 완료',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // 인증번호 입력 필드
        if (_signupController.isVerificationSent &&
            !_signupController.isEmailVerified)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 인증번호 입력 필드
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            text: '인증번호',
                            style: SignupStyles.labelStyle,
                            children: [
                              TextSpan(
                                text: '*',
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  color: SignupStyles.primaryRed,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _controllers['verificationCode'],
                          style: const TextStyle(fontFamily: 'Pretendard'),
                          decoration: InputDecoration(
                            hintText: '인증번호를 입력하세요',
                            hintStyle: SignupStyles.hintStyle,
                            contentPadding: SignupStyles.fieldPadding,
                            border: SignupStyles.defaultBorder,
                            enabledBorder: SignupStyles.defaultBorder,
                            focusedBorder: SignupStyles.focusedBorder,
                            errorBorder: SignupStyles.errorBorder,
                            focusedErrorBorder: SignupStyles.errorBorder,
                            errorStyle: SignupStyles.errorStyle,
                            // 남은 시간 표시 (선택 사항)
                            suffixIcon:
                                _signupController.verificationTimeLeft > 0
                                    ? Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: Center(
                                        widthFactor: 1,
                                        child: Text(
                                          '${_signupController.verificationTimeLeft ~/ 60}:${(_signupController.verificationTimeLeft % 60).toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    )
                                    : null,
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          buildCounter:
                              (
                                context, {
                                required currentLength,
                                required isFocused,
                                maxLength,
                              }) => null,
                        ),
                      ],
                    ),
                  ),

                  // 인증번호 확인 버튼
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 32),
                    child: ElevatedButton(
                      onPressed:
                          _signupController.verificationTimeLeft > 0
                              ? () {
                                final code =
                                    _controllers['verificationCode']!.text;
                                if (code.length == 6) {
                                  _signupController.verifyCode(code);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('6자리 인증번호를 입력해주세요.'),
                                    ),
                                  );
                                }
                              }
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SignupStyles.primaryRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: const Size(80, 56),
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                      child: const Text('확인', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
              ),

              // 인증 관련 안내 메시지
              if (_signupController.verificationError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _signupController.verificationError,
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ),

              if (_signupController.verificationTimeLeft <= 0 &&
                  _signupController.isVerificationSent)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '인증번호가 만료되었습니다. 재발급 받으세요.',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ),

              if (_signupController.isVerificationSent)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '인증번호가 이메일로 발송되었습니다.',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  // 약관 동의 섹션 구성
  Widget _buildAgreementsSection() {
    return Column(
      children: [
        // 전체 동의
        _buildAgreementCheckbox(
          text: '약관에 모두 동의합니다',
          value: _allAgreements,
          onChanged: (value) => _handleAgreementChange('all', value),
          isAll: true,
        ),
        const Divider(),

        // 필수 약관 1
        _buildAgreementCheckbox(
          text: '[필수] 서비스 이용약관 동의',
          value: _serviceAgreement,
          onChanged: (value) => _handleAgreementChange('service', value),
          isRequired: true,
          hasArrow: true,
        ),

        // 필수 약관 2
        _buildAgreementCheckbox(
          text: '[필수] 개인정보 수집 및 이용 동의',
          value: _privacyAgreement,
          onChanged: (value) => _handleAgreementChange('privacy', value),
          isRequired: true,
          hasArrow: true,
        ),

        // 선택 약관
        _buildAgreementCheckbox(
          text: '[선택] 홍보성 정보 수신 동의',
          value: _marketingAgreement,
          onChanged: (value) => _handleAgreementChange('marketing', value),
          hasArrow: false,
        ),
      ],
    );
  }

  // 약관 동의 체크박스 구성
  Widget _buildAgreementCheckbox({
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
          activeColor:
              isAll ? SignupStyles.secondaryText : SignupStyles.primaryRed,
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: isAll ? FontWeight.w600 : FontWeight.w500,
              fontSize: 15.0,
              color: SignupStyles.primaryText,
            ),
          ),
        ),
        if (hasArrow)
          const Icon(Icons.chevron_right, color: SignupStyles.secondaryText),
      ],
    );
  }

  // 가입하기 버튼 구성
  Widget _buildSignupButton() {
    return SizedBox(
      width: double.infinity,
      height: SignupStyles.inputHeight,
      child: ElevatedButton(
        onPressed: () => _signupController.signup(_formKey),
        style: ElevatedButton.styleFrom(
          backgroundColor: SignupStyles.primaryRed,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SignupStyles.borderRadius),
          ),
        ),
        child: const Text('가입하기', style: SignupStyles.buttonStyle),
      ),
    );
  }

  // 상태 아이콘 생성
  Widget _buildStatusIcon(bool isError) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      child: SvgPicture.asset(
        isError
            ? 'assets/icons/error_circle.svg'
            : 'assets/icons/check_circle.svg',
        width: 20,
        height: 20,
        fit: BoxFit.contain,
      ),
    );
  }
}
