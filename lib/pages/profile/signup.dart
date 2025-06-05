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

  // 입력 필드 테두리 스타일은 메서드로 변경 (context가 필요하기 때문)
  static OutlineInputBorder getDefaultBorder() {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: const BorderSide(color: borderColor, width: 1.0),
    );
  }

  static OutlineInputBorder getFocusedBorder(BuildContext context) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.secondary,
        width: 1.0,
      ),
    );
  }

  static OutlineInputBorder getErrorBorder() {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: const BorderSide(color: primaryRed, width: 1.0),
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

  // 포커스 노드 맵 - 포커스 노드를 효율적으로 관리 (이름 포커스 노드 추가)
  late final Map<String, FocusNode> _focusNodes = {
    'name': FocusNode(), // 이름 포커스 노드 추가
    'id': FocusNode(),
    'nickname': FocusNode(),
    'password': FocusNode(),
    'confirmPassword': FocusNode(),
    'email': FocusNode(),
  };

  // 회원가입 컨트롤러
  late SignupController _signupController;

  // 약관 동의 상태 변수 - 기본값을 false로 변경
  bool _allAgreements = false;
  bool _serviceAgreement = false;
  bool _privacyAgreement = false;
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

    // 이름 필드 포커스 이벤트 리스너 추가
    _focusNodes['name']?.addListener(() {
      if (!_focusNodes['name']!.hasFocus &&
          _controllers['name']!.text.isNotEmpty) {
        if (!_signupController.isNameValid) {
          // 필요시 툴팁 표시 (현재는 텍스트로만 표시)
        }
      }
    });

    // 아이디 필드 포커스 이벤트 리스너 수정
    _focusNodes['id']?.addListener(() {
      if (!_focusNodes['id']!.hasFocus && _controllers['id']!.text.isNotEmpty) {
        if (!_signupController.isIdFormatValid ||
            _signupController.isIdDuplicate) {
          _signupController.showTooltip(_focusNodes['id']!, 'id');
        }
      }
    });

    // 닉네임 필드 포커스 이벤트 리스너 수정
    _focusNodes['nickname']?.addListener(() {
      if (!_focusNodes['nickname']!.hasFocus &&
          _controllers['nickname']!.text.isNotEmpty) {
        if (!_signupController.isNicknameFormatValid ||
            _signupController.isNicknameDuplicate) {
          _signupController.showTooltip(_focusNodes['nickname']!, 'nickname');
        }
      }
    });

    // 비밀번호 필드와 비밀번호 확인 필드의 포커스 이벤트 리스너 설정
    _focusNodes['password']?.addListener(() {
      if (!_focusNodes['password']!.hasFocus &&
          _controllers['password']!.text.isNotEmpty) {
        if (_validatePasswordStatus()) {
          _signupController.showTooltip(_focusNodes['password']!, 'password');
        }
      }
    });

    _focusNodes['confirmPassword']?.addListener(() {
      if (!_focusNodes['confirmPassword']!.hasFocus &&
          _controllers['confirmPassword']!.text.isNotEmpty) {
        if (_validateConfirmPasswordStatus()) {
          _signupController.showTooltip(
            _focusNodes['confirmPassword']!,
            'password_confirm',
          );
        }
      }
    });

    _focusNodes['email']?.addListener(() {
      // 포커스 변경 시 UI 강제 업데이트
      setState(() {});
    });
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

  // 서비스 이용약관 모달 표시
  void _showServiceTermsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '서비스 이용약관 동의',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Pretendard',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: const [
                      Text(
                        '서비스 이용약관',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Pretendard',
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '제 1 조 (목적)\n'
                        '이 약관은 서비스 이용에 관한 기본적인 사항을 규정함을 목적으로 합니다.\n\n'
                        '제 2 조 (정의)\n'
                        '1. "서비스"라 함은 회사가 제공하는 위치기반 서비스, 지도 서비스 등을 말합니다.\n'
                        '2. "이용자"라 함은 회사가 제공하는 서비스를 이용하는 자를 말합니다.\n\n'
                        '제 3 조 (약관의 효력 및 변경)\n'
                        '1. 이 약관은 서비스를 이용하고자 하는 모든 이용자에게 적용됩니다.\n'
                        '2. 회사는 필요한 경우 약관을 변경할 수 있으며, 변경된 약관은 적용일 7일 전에 공지합니다.\n\n'
                        '본 약관은 2023년 1월 1일부터 시행됩니다.',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Pretendard',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 개인정보 수집 및 이용 모달 표시
  void _showPrivacyPolicyModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '개인정보 수집 및 이용',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Pretendard',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: const [
                      Text(
                        '개인정보 수집 및 이용 안내',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Pretendard',
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '1. 수집하는 개인정보 항목\n'
                        '- 위치정보: 현재 위치, 검색 위치, 경로 정보\n'
                        '- 기기정보: 기기 식별자, 운영체제 정보\n\n'
                        '2. 수집 및 이용 목적\n'
                        '- 위치기반 서비스 제공\n'
                        '- 서비스 개선 및 불편사항 해결\n\n'
                        '3. 보유 및 이용 기간\n'
                        '- 서비스 이용 종료 시까지 또는 법령에 따른 보관 기간\n\n'
                        '4. 동의 거부권 및 거부 시 불이익\n'
                        '- 개인정보 수집 및 이용에 대한 동의를 거부할 수 있으나, 서비스 이용이 제한될 수 있습니다.',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Pretendard',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
                        color: Color(0xFF363636),
                        fontSize: 13,
                        fontFamily: 'Pretendard',
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
    _allAgreements = _serviceAgreement && _privacyAgreement;
  }

  // 회원가입 가능 여부 확인 함수 추가
  bool get _canSignup {
    // 필수 약관 동의 확인 (마케팅은 선택사항이므로 제외)
    return _serviceAgreement && _privacyAgreement;
  }

  // 수정된 회원가입 처리 함수
  Future<void> _handleSignup() async {
    // 필수 약관 동의 확인
    if (!_serviceAgreement || !_privacyAgreement) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('필수 약관에 동의해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 기존 회원가입 로직 실행
    await _signupController.signup(_formKey);
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
                  // 이름 입력 필드 (검증 기능 추가)
                  _buildNameField(),
                  const SizedBox(height: SignupStyles.fieldSpacing),

                  // 아이디 입력 필드 (검증 기능 강화)
                  _buildIdField(),
                  const SizedBox(height: SignupStyles.fieldSpacing),

                  // 닉네임 입력 필드 (검증 기능 강화)
                  _buildNicknameField(),
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

                  // 가입하기 버튼 (수정됨)
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      scrolledUnderElevation: 0,
      title: Text(
        '회원가입',
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w600,
          fontSize: 22.0,
          color: Color(0xFF363636),
        ),
      ),
      leading: IconButton(
        icon: SvgPicture.asset('assets/icons/back.svg', width: 24, height: 24),
        onPressed: () => Navigator.pop(context),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
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

  // 이름 필드 구성 - 새로 추가된 메서드
  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 이름 라벨
        RichText(
          text: const TextSpan(
            text: '이름',
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

        // 이름 입력 필드
        TextFormField(
          controller: _controllers['name'],
          focusNode: _focusNodes['name'],
          style: const TextStyle(fontFamily: 'Pretendard', fontSize: 16.0),
          decoration: InputDecoration(
            hintText: '이름을 입력해주세요.',
            hintStyle: SignupStyles.hintStyle,
            suffixIcon:
                _controllers['name']!.text.isNotEmpty
                    ? _buildStatusIcon(!_signupController.isNameValid)
                    : null,
            contentPadding: SignupStyles.fieldPadding,
            border: SignupStyles.getDefaultBorder(),
            enabledBorder:
                !_signupController.isNameValid
                    ? SignupStyles.getErrorBorder()
                    : SignupStyles.getDefaultBorder(),
            focusedBorder:
                !_signupController.isNameValid
                    ? SignupStyles.getErrorBorder()
                    : SignupStyles.getFocusedBorder(context),
            errorBorder: SignupStyles.getErrorBorder(),
            focusedErrorBorder: SignupStyles.getErrorBorder(),
            errorStyle: SignupStyles.errorStyle,
          ),
          validator: _validateRequired,
          onChanged: (_) {
            setState(() {});
          },
        ),

        // 이름 에러 메시지 표시
        if (_signupController.nameErrorMessage != null &&
            _signupController.nameErrorMessage!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 5, top: 4),
            child: Text(
              _signupController.nameErrorMessage!,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                color: SignupStyles.primaryRed,
                fontSize: 12.0,
              ),
            ),
          ),
      ],
    );
  }

  // 아이디 필드 구성 - 검증 기능 강화
  Widget _buildIdField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 아이디 라벨
        RichText(
          text: const TextSpan(
            text: '아이디',
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

        // 아이디 입력 필드
        TextFormField(
          controller: _controllers['id'],
          focusNode: _focusNodes['id'],
          style: const TextStyle(fontFamily: 'Pretendard', fontSize: 16.0),
          decoration: InputDecoration(
            hintText: '아이디를 입력해주세요.',
            hintStyle: SignupStyles.hintStyle,
            suffixIcon:
                _controllers['id']!.text.isNotEmpty
                    ? _buildStatusIcon(
                      !_signupController.isIdFormatValid ||
                          _signupController.isIdDuplicate,
                    )
                    : null,
            contentPadding: SignupStyles.fieldPadding,
            border: SignupStyles.getDefaultBorder(),
            enabledBorder:
                (!_signupController.isIdFormatValid ||
                        _signupController.isIdDuplicate)
                    ? SignupStyles.getErrorBorder()
                    : SignupStyles.getDefaultBorder(),
            focusedBorder:
                (!_signupController.isIdFormatValid ||
                        _signupController.isIdDuplicate)
                    ? SignupStyles.getErrorBorder()
                    : SignupStyles.getFocusedBorder(context),
            errorBorder: SignupStyles.getErrorBorder(),
            focusedErrorBorder: SignupStyles.getErrorBorder(),
            errorStyle: SignupStyles.errorStyle,
          ),
          validator: _validateRequired,
          onChanged: (_) {
            setState(() {});
          },
        ),

        // 아이디 에러 메시지 표시
        if (_signupController.idErrorMessage != null &&
            _signupController.idErrorMessage!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 5, top: 4),
            child: Text(
              _signupController.idErrorMessage!,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                color: SignupStyles.primaryRed,
                fontSize: 12.0,
              ),
            ),
          ),

        // 아이디 중복 메시지 표시
        if (_signupController.isIdDuplicate &&
            _signupController.isIdFormatValid)
          Padding(
            padding: const EdgeInsets.only(left: 5, top: 4),
            child: Text(
              '이미 사용 중인 아이디입니다.',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                color: SignupStyles.primaryRed,
                fontSize: 12.0,
              ),
            ),
          ),

        // 도움말 텍스트
        if (_controllers['id']!.text.isEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 5, top: 1),
            child: Text(
              '영어와 숫자만 사용하여 4~16자로 입력해주세요.',
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

  // 닉네임 필드 구성 - 검증 기능 강화
  Widget _buildNicknameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 닉네임 라벨
        RichText(
          text: const TextSpan(
            text: '닉네임',
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

        // 닉네임 입력 필드
        TextFormField(
          controller: _controllers['nickname'],
          focusNode: _focusNodes['nickname'],
          style: const TextStyle(fontFamily: 'Pretendard', fontSize: 16.0),
          decoration: InputDecoration(
            hintText: '닉네임을 입력해주세요.',
            hintStyle: SignupStyles.hintStyle,
            suffixIcon:
                _controllers['nickname']!.text.isNotEmpty
                    ? _buildStatusIcon(
                      !_signupController.isNicknameFormatValid ||
                          _signupController.isNicknameDuplicate,
                    )
                    : null,
            contentPadding: SignupStyles.fieldPadding,
            border: SignupStyles.getDefaultBorder(),
            enabledBorder:
                (!_signupController.isNicknameFormatValid ||
                        _signupController.isNicknameDuplicate)
                    ? SignupStyles.getErrorBorder()
                    : SignupStyles.getDefaultBorder(),
            focusedBorder:
                (!_signupController.isNicknameFormatValid ||
                        _signupController.isNicknameDuplicate)
                    ? SignupStyles.getErrorBorder()
                    : SignupStyles.getFocusedBorder(context),
            errorBorder: SignupStyles.getErrorBorder(),
            focusedErrorBorder: SignupStyles.getErrorBorder(),
            errorStyle: SignupStyles.errorStyle,
          ),
          validator: _validateRequired,
          onChanged: (_) {
            setState(() {});
          },
        ),

        // 닉네임 에러 메시지 표시
        if (_signupController.nicknameErrorMessage != null &&
            _signupController.nicknameErrorMessage!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 5, top: 4),
            child: Text(
              _signupController.nicknameErrorMessage!,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                color: SignupStyles.primaryRed,
                fontSize: 12.0,
              ),
            ),
          ),

        // 닉네임 중복 메시지 표시
        if (_signupController.isNicknameDuplicate &&
            _signupController.isNicknameFormatValid)
          Padding(
            padding: const EdgeInsets.only(left: 5, top: 4),
            child: Text(
              '이미 사용 중인 닉네임입니다.',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                color: SignupStyles.primaryRed,
                fontSize: 12.0,
              ),
            ),
          ),

        // 도움말 텍스트
        if (_controllers['nickname']!.text.isEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 5, top: 1),
            child: Text(
              '한국어, 영어, 숫자만 사용하여 최대 16자까지 입력해주세요.',
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

  // 비밀번호 검증
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }

    // 길이 검사 (8자 이상)
    if (value.length < 8) {
      _signupController.showTooltip(_focusNodes['password']!, 'password');
      return '';
    }

    // 문자 포함 검사 (영문자)
    bool hasLetter = RegExp(r'[a-zA-Z]').hasMatch(value);

    // 숫자 포함 검사
    bool hasDigit = RegExp(r'[0-9]').hasMatch(value);

    // 문자와 숫자 모두 포함되어 있는지 확인
    if (!hasLetter || !hasDigit) {
      _signupController.showTooltip(_focusNodes['password']!, 'password');
      return '';
    }

    return null;
  }

  // 비밀번호 유효성 상태 확인
  bool _validatePasswordStatus() {
    String password = _controllers['password']!.text;
    if (password.isEmpty) return false;

    bool hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
    bool hasDigit = RegExp(r'[0-9]').hasMatch(password);
    return password.length < 8 || !hasLetter || !hasDigit;
  }

  // 비밀번호 확인 유효성 상태 확인
  bool _validateConfirmPasswordStatus() {
    String password = _controllers['password']!.text;
    String confirmPassword = _controllers['confirmPassword']!.text;
    return confirmPassword.isNotEmpty && password != confirmPassword;
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

  // 비밀번호 필드 구성
  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 비밀번호 라벨
        RichText(
          text: const TextSpan(
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
          obscureText: _signupController.obscurePasswordText,
          focusNode: _focusNodes['password'],
          style: const TextStyle(fontFamily: 'Pretendard', fontSize: 16.0),
          decoration: InputDecoration(
            hintText: '비밀번호를 입력해주세요.',
            hintStyle: SignupStyles.hintStyle,
            // 아이콘 버튼 추가
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_controllers['password']!.text.isNotEmpty)
                  _buildStatusIcon(_validatePasswordStatus()),
                IconButton(
                  icon: Icon(
                    _signupController.obscurePasswordText
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: const Color(0xFF363636),
                    size: 20.0 * (MediaQuery.of(context).size.width / 375),
                  ),
                  onPressed: () {
                    _signupController.togglePasswordVisibility(setState);
                  },
                ),
              ],
            ),
            contentPadding: SignupStyles.fieldPadding,
            border: SignupStyles.getDefaultBorder(),
            enabledBorder:
                _validatePasswordStatus()
                    ? SignupStyles.getErrorBorder()
                    : SignupStyles.getDefaultBorder(),
            focusedBorder:
                _validatePasswordStatus()
                    ? SignupStyles.getErrorBorder()
                    : SignupStyles.getFocusedBorder(context),
            errorBorder: SignupStyles.getErrorBorder(),
            focusedErrorBorder: SignupStyles.getErrorBorder(),
            errorStyle: SignupStyles.errorStyle,
          ),
          validator: _validatePassword,
          onChanged: (_) {
            setState(() {});
          },
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
          text: const TextSpan(
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
          obscureText: _signupController.obscureConfirmPasswordText,
          focusNode: _focusNodes['confirmPassword'],
          style: const TextStyle(fontFamily: 'Pretendard', fontSize: 16.0),
          decoration: InputDecoration(
            hintText: '비밀번호를 다시 입력해주세요.',
            hintStyle: SignupStyles.hintStyle,
            // 아이콘 버튼 추가
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_controllers['confirmPassword']!.text.isNotEmpty)
                  _buildStatusIcon(_validateConfirmPasswordStatus()),
                IconButton(
                  icon: Icon(
                    _signupController.obscureConfirmPasswordText
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: const Color(0xFF363636),
                    size: 20.0 * (MediaQuery.of(context).size.width / 375),
                  ),
                  onPressed: () {
                    _signupController.toggleConfirmPasswordVisibility(setState);
                  },
                ),
              ],
            ),
            contentPadding: SignupStyles.fieldPadding,
            border: SignupStyles.getDefaultBorder(),
            enabledBorder:
                _validateConfirmPasswordStatus()
                    ? SignupStyles.getErrorBorder()
                    : SignupStyles.getDefaultBorder(),
            focusedBorder:
                _validateConfirmPasswordStatus()
                    ? SignupStyles.getErrorBorder()
                    : SignupStyles.getFocusedBorder(context),
            errorBorder: SignupStyles.getErrorBorder(),
            focusedErrorBorder: SignupStyles.getErrorBorder(),
            errorStyle: SignupStyles.errorStyle,
          ),
          validator: _validateConfirmPassword,
          onChanged: (_) {
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    // 포커스 상태를 처음에 명시적으로 읽어서 UI에 반영되게 함
    final bool hasEmailFocus = _focusNodes['email']?.hasFocus ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 이메일 라벨
        RichText(
          text: const TextSpan(
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
        Container(
          key: _emailFieldKey,
          height: SignupStyles.inputHeight,
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  (!_signupController.isEmailValid ||
                          _signupController.isEmailDuplicate)
                      ? SignupStyles.primaryRed
                      : hasEmailFocus
                      ? Theme.of(context).colorScheme.secondary
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
                    hintText: '이메일을 입력해주세요.',
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
                  onChanged: (_) {
                    // 입력값 변경 시 상태 업데이트
                    setState(() {});
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

              // 상태 아이콘 (이메일이 비어 있지 않을 때만 표시)
              if (_controllers['email']!.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _buildStatusIcon(_signupController.isEmailDuplicate),
                ),
            ],
          ),
        ),

        // 툴팁 추가 (필요 시 표시됨) - isEmailDuplicate일 때만 표시
        if (_signupController.isEmailDuplicate && !hasEmailFocus)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 14,
                  color: SignupStyles.primaryRed,
                ),
                const SizedBox(width: 4),
                Text(
                  '이미 사용 중인 이메일입니다.',
                  style: TextStyle(
                    color: SignupStyles.primaryRed,
                    fontSize: 12,
                    fontFamily: 'Pretendard',
                  ),
                ),
              ],
            ),
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
                      // 중복 확인 후 인증 절차 진행
                      if (_signupController.isEmailDuplicate) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('이미 사용 중인 이메일입니다.')),
                        );
                        // 툴팁 표시
                        _signupController.showTooltip(
                          _focusNodes['email']!,
                          'email',
                        );
                      } else {
                        _signupController.sendVerificationEmail(email);
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('이메일을 입력해주세요.')),
                      );
                    }
                  },
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(
                      Color(0xFF000000),
                    ),
                    foregroundColor: MaterialStateProperty.all(
                      Color(0xFFFFFFFF),
                    ),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    minimumSize: MaterialStateProperty.all(const Size(100, 36)),
                    splashFactory: NoSplash.splashFactory,
                  ),
                  child: const Text(
                    '인증번호 받기',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(
                      Colors.grey[200],
                    ),
                    foregroundColor: MaterialStateProperty.all(
                      SignupStyles.primaryText,
                    ),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    minimumSize: MaterialStateProperty.all(const Size(100, 36)),
                    splashFactory: NoSplash.splashFactory,
                  ),
                  child: const Text(
                    '인증번호 재발급',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
                          fontFamily: 'Pretendard',
                          color: Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
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
                          text: const TextSpan(
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
                            border: SignupStyles.getDefaultBorder(),
                            enabledBorder: SignupStyles.getDefaultBorder(),
                            focusedBorder: SignupStyles.getFocusedBorder(
                              context,
                            ),
                            errorBorder: SignupStyles.getErrorBorder(),
                            focusedErrorBorder: SignupStyles.getErrorBorder(),
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
                    padding: const EdgeInsets.only(left: 12, top: 28),
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
                      style: ButtonStyle(
                        backgroundColor:
                            MaterialStateProperty.resolveWith<Color>((states) {
                              if (states.contains(MaterialState.disabled)) {
                                return Colors.grey[300]!;
                              }
                              return SignupStyles.primaryRed;
                            }),
                        foregroundColor: MaterialStateProperty.all(
                          Colors.white,
                        ),
                        shape: MaterialStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        minimumSize: MaterialStateProperty.all(
                          const Size(60, 50),
                        ),
                        splashFactory: NoSplash.splashFactory,
                      ),
                      child: const Text(
                        '확인',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                        ),
                      ),
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
                    style: const TextStyle(
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
                    style: const TextStyle(
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

        // 필수 약관 1 - 서비스 이용약관 (화살표 클릭 시 모달 표시)
        _buildAgreementCheckbox(
          text: '[필수] 서비스 이용약관 동의',
          value: _serviceAgreement,
          onChanged: (value) => _handleAgreementChange('service', value),
          isRequired: true,
          hasArrow: true,
          onArrowTap: _showServiceTermsModal, // 화살표 클릭 시 모달 표시
        ),

        // 필수 약관 2 - 개인정보 수집 및 이용 (화살표 클릭 시 모달 표시)
        _buildAgreementCheckbox(
          text: '[필수] 개인정보 수집 및 이용 동의',
          value: _privacyAgreement,
          onChanged: (value) => _handleAgreementChange('privacy', value),
          isRequired: true,
          hasArrow: true,
          onArrowTap: _showPrivacyPolicyModal, // 화살표 클릭 시 모달 표시
        ),
      ],
    );
  }

  // 약관 동의 체크박스 구성 (화살표 클릭 이벤트 추가)
  Widget _buildAgreementCheckbox({
    required String text,
    required bool value,
    required Function(bool?) onChanged,
    bool isRequired = false,
    bool isAll = false,
    bool hasArrow = false,
    VoidCallback? onArrowTap, // 화살표 클릭 이벤트 추가
  }) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          shape: const CircleBorder(),
          // 선택된 상태의 색상
          activeColor:
              isAll ? SignupStyles.primaryRed : SignupStyles.primaryRed,

          // 비선택 상태의 테두리 색상 변경
          side: BorderSide(
            color:
                value
                    ? SignupStyles.primaryRed
                    : Colors.grey.shade400, // 비선택 시 회색
            width: 1.0, // 테두리 두께
          ),

          // 배경색 변경 (선택사항)
          fillColor: MaterialStateProperty.resolveWith<Color?>((
            Set<MaterialState> states,
          ) {
            if (states.contains(MaterialState.selected)) {
              return isAll
                  ? SignupStyles.primaryRed
                  : SignupStyles.primaryRed; // 선택된 상태
            }
            return Colors.transparent; // 비선택 상태는 투명 (또는 원하는 색상으로 변경)
          }),

          // 체크마크 색상 변경 (선택사항)
          checkColor: Colors.white,

          // 포커스/호버 색상 변경 (선택사항)
          overlayColor: MaterialStateProperty.resolveWith<Color?>((
            Set<MaterialState> states,
          ) {
            if (states.contains(MaterialState.pressed)) {
              return SignupStyles.primaryRed.withOpacity(0.1);
            }
            return null;
          }),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: isAll ? FontWeight.w600 : FontWeight.w400,
              fontSize: 16.0,
              color: Color(0xFF363636),
            ),
          ),
        ),
        if (hasArrow)
          GestureDetector(
            onTap: onArrowTap, // 화살표 클릭 시 onArrowTap 실행
            child: const Icon(
              Icons.chevron_right_rounded,
              color: SignupStyles.secondaryText,
            ),
          ),
      ],
    );
  }

  // 가입하기 버튼 구성 (수정됨 - 약관 동의 상태에 따라 버튼 활성화)
  Widget _buildSignupButton() {
    return SizedBox(
      width: double.infinity,
      height: SignupStyles.inputHeight,
      child: ElevatedButton(
        onPressed: _canSignup ? _handleSignup : null, // 수정된 부분
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
            if (states.contains(MaterialState.disabled)) {
              return Colors.grey[400]!; // 비활성화 시 회색
            }
            return SignupStyles.primaryRed; // 활성화 시 빨간색
          }),
          foregroundColor: MaterialStateProperty.all(Colors.white),
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(vertical: 16),
          ),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SignupStyles.borderRadius),
            ),
          ),
          // 스플래시 효과 제거
          splashFactory: NoSplash.splashFactory,
          overlayColor: MaterialStateProperty.resolveWith<Color>((
            Set<MaterialState> states,
          ) {
            if (states.contains(MaterialState.pressed)) {
              return SignupStyles.primaryRed.withOpacity(0.1);
            }
            return Colors.transparent;
          }),
        ),
        child: Text(
          '가입하기',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: SignupStyles.buttonFontSize,
            fontWeight: FontWeight.bold,
            color:
                _canSignup
                    ? Colors.white
                    : Colors.white.withOpacity(0.7), // 텍스트 색상도 조정
          ),
        ),
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
