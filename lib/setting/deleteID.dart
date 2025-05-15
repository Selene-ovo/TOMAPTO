import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // 타임아웃 처리를 위한 import 추가
import 'dart:io'; // SocketException을 위한 import 추가
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomapto/pages/profile/login.dart';


class DeleteIDScreen extends StatefulWidget {
  const DeleteIDScreen({Key? key}) : super(key: key);

  @override
  State<DeleteIDScreen> createState() => _DeleteIDScreenState();
}

class _DeleteIDScreenState extends State<DeleteIDScreen> {
  bool _agreeToDelete = false;
  bool _isLoading = false;
  String? _password;
  String? _reason; // 탈퇴 사유를 저장할 변수 추가

  // 개발 환경에 따라 적절한 API URL 설정
  String apiUrl = '';

  @override
  void initState() {
    super.initState();
    _configureApiUrl();
  }

  // 디바이스에 따라 API URL 설정
  void _configureApiUrl() {
    if (Platform.isAndroid) {
      // 안드로이드 에뮬레이터용
      apiUrl = 'http://10.0.2.2:8080';
    } else if (Platform.isIOS) {
      // iOS 시뮬레이터용
      apiUrl = 'http://localhost:8080';
    } else {
      // 웹 또는 기타 플랫폼
      apiUrl = 'http://localhost:8080';
    }
    
    // 실제 기기에서 테스트할 때는 여기에 실제 서버 IP 주소를 하드코딩하거나
    // 환경 설정에서 로드할 수 있습니다.
    // 예: apiUrl = 'http://192.168.0.xxx:8080';
    
    print('설정된 API URL: $apiUrl');
  }

  // 회원탈퇴 처리 함수
  Future<void> _processAccountDeletion() async {
    if (!_agreeToDelete) {
      _showErrorSnackBar('회원탈퇴에 동의해주세요.');
      return;
    }

    if (_password == null || _password!.isEmpty) {
      _showErrorSnackBar('비밀번호를 입력해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 서버에 회원탈퇴 요청
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        throw Exception('로그인 정보가 없습니다.');
      }
      
      final url = Uri.parse('$apiUrl/api/account/delete');
      
      print('회원탈퇴 요청 URL: $url');
      print('요청 데이터: {"password": "****", "reason": "${_reason ?? ''}"}');
      
      // 타임아웃 시간 늘리기 (120초로 설정)
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'password': _password,
          'reason': _reason ?? '',
        }),
      ).timeout(const Duration(seconds: 120)); // 타임아웃 시간 120초로 설정
      
      print('서버 응답 상태 코드: ${response.statusCode}');
      print('서버 응답 내용: ${response.body}');
      
      if (response.statusCode == 200) {
        // 로컬 데이터 삭제
        await _clearAllUserData();
        
        // 성공 다이얼로그 표시
        if (mounted) {
          _showSuccessDialog();
        }
      } else {
        // 서버에서 오류 응답이 온 경우
        Map<String, dynamic> errorData;
        try {
          errorData = jsonDecode(response.body);
          print('오류 응답 데이터: $errorData');
        } catch (e) {
          print('응답 본문 파싱 오류: $e');
          errorData = {'message': '서버에서 알 수 없는 오류가 발생했습니다.'};
        }
        
        // 비밀번호 관련 오류 메시지를 명확하게 표시
        if (errorData.containsKey('message') && 
            errorData['message'].toString().contains('비밀번호')) {
          throw Exception('비밀번호가 일치하지 않습니다.');
        } else {
          throw Exception(errorData['message'] ?? '회원탈퇴 처리 중 오류가 발생했습니다.');
        }
      }
    } on TimeoutException catch (_) {
      // 타임아웃 오류 처리
      if (mounted) {
        _showErrorSnackBar('서버 요청 시간이 초과되었습니다. 네트워크 연결을 확인해주세요.');
      }
      print('회원탈퇴 요청 타임아웃');
    } on SocketException catch (e) {
      // 소켓 연결 오류 처리
      if (mounted) {
        _showErrorSnackBar('서버에 연결할 수 없습니다. 네트워크 연결을 확인해주세요.');
      }
      print('소켓 연결 오류: $e');
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('회원탈퇴 처리 중 오류가 발생했습니다: ${e.toString()}');
      }
      print('회원탈퇴 오류: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 사용자 데이터 삭제 함수
  Future<void> _clearAllUserData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 모든 사용자 관련 데이터 삭제
    await prefs.remove('token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_id');
    await prefs.remove('username');
    await prefs.remove('email');
    await prefs.remove('profile_data');
    await prefs.remove('remember_me');
    
    // 사용자 설정 삭제
    await prefs.remove('notification_settings');
    await prefs.remove('map_settings');
    await prefs.remove('navigation_settings');
    
    // 앱 내 캐시 데이터 삭제
    await prefs.remove('recent_searches');
    await prefs.remove('favorite_locations');
    
    print('모든 사용자 데이터가 삭제되었습니다.');
  }

  // 에러 메시지 스낵바
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 성공 다이얼로그
  void _showSuccessDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('회원탈퇴 완료'),
        content: const Text('회원탈퇴가 정상적으로 처리되었습니다.\n그동안 서비스를 이용해 주셔서 감사합니다.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '회원탈퇴',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // 주의사항
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        '회원탈퇴 전 꼭 확인해주세요!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '• 탈퇴 시 모든 개인정보와 이용 기록이 삭제됩니다.\n'
                        '• 삭제된 정보는 복구가 불가능합니다.\n'
                        '• 등록된 게시물은 자동으로 삭제되지 않습니다.\n'
                        '• 탈퇴 후 재가입해도 이전 정보는 복구되지 않습니다.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 비밀번호 확인
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '비밀번호 확인',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '안전한 회원탈퇴를 위해 비밀번호를 입력해주세요.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: '비밀번호를 입력하세요',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _password = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 1),
                
                // 탈퇴 사유 (선택)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '탈퇴 사유 (선택)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '더 나은 서비스를 위해 탈퇴 사유를 알려주세요.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: '탈퇴 사유를 입력하세요 (선택사항)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _reason = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 동의 체크박스
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _agreeToDelete,
                          onChanged: (value) {
                            setState(() {
                              _agreeToDelete = value ?? false;
                            });
                          },
                          activeColor: const Color(0xFFFF3B30),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '위 내용을 모두 확인하였으며, 회원탈퇴에 동의합니다.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // 탈퇴하기 버튼
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _processAccountDeletion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B30),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            '탈퇴하기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
          
          // 로딩 오버레이
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF3B30)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}