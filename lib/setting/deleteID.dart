import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomapto/pages/profile/login.dart';
import 'package:tomapto/services/api_service.dart';

class DeleteIDScreen extends StatefulWidget {
  const DeleteIDScreen({Key? key}) : super(key: key);

  @override
  State<DeleteIDScreen> createState() => _DeleteIDScreenState();
}

class _DeleteIDScreenState extends State<DeleteIDScreen> {
  bool _agreeToDelete = false;
  bool _isLoading = false;
  String? _password;
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  // 회원탈퇴 처리 함수
  Future<void> _processAccountDeletion() async {
    if (!_agreeToDelete) {
      _showErrorSnackBar('회원탈퇴에 동의해주세요.');
      return;
    }

    if (_password == null || _password!.trim().isEmpty) {
      _showErrorSnackBar('비밀번호를 입력해주세요.');
      return;
    }

    // 최종 확인 다이얼로그
    bool confirmed = await _showFinalConfirmationDialog();
    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 토큰 확인
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        throw Exception('로그인 정보가 없습니다. 다시 로그인해주세요.');
      }

      // API 서비스를 통한 URL 가져오기
      final apiBaseUrl = ApiService.getApiBaseUrl();
      final url = Uri.parse('$apiBaseUrl/account/delete');
      
      print('=== 회원탈퇴 요청 시작 ===');
      print('요청 URL: $url');
      print('토큰 존재: ${token.isNotEmpty}');
      
      // 여러 단계의 타임아웃과 재시도 로직
      http.Response? response;
      int maxRetries = 3;
      int currentRetry = 0;
      
      while (currentRetry < maxRetries) {
        try {
          print('시도 ${currentRetry + 1}/$maxRetries');
          
          response = await http.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'User-Agent': 'ToMapTo-Mobile-App',
            },
            body: jsonEncode({
              'password': _password!.trim(),
            }),
          ).timeout(
            Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('요청 시간이 초과되었습니다.', Duration(seconds: 30));
            },
          );
          
          // 성공적으로 응답을 받았으면 루프 종료
          break;
          
        } on SocketException catch (e) {
          print('소켓 연결 오류 (시도 ${currentRetry + 1}): $e');
          currentRetry++;
          
          if (currentRetry >= maxRetries) {
            throw Exception('서버에 연결할 수 없습니다.\n네트워크 연결을 확인해주세요.');
          }
          
          await Future.delayed(Duration(seconds: 2));
          
        } on TimeoutException catch (e) {
          print('타임아웃 오류 (시도 ${currentRetry + 1}): $e');
          currentRetry++;
          
          if (currentRetry >= maxRetries) {
            throw Exception('서버 응답 시간이 초과되었습니다.\n잠시 후 다시 시도해주세요.');
          }
          
          await Future.delayed(Duration(seconds: 2));
          
        } on HttpException catch (e) {
          print('HTTP 오류 (시도 ${currentRetry + 1}): $e');
          currentRetry++;
          
          if (currentRetry >= maxRetries) {
            throw Exception('서버와 통신 중 오류가 발생했습니다.');
          }
          
          await Future.delayed(Duration(seconds: 2));
        }
      }
      
      if (response == null) {
        throw Exception('서버 응답을 받을 수 없습니다.');
      }
      
      print('서버 응답 코드: ${response.statusCode}');
      print('서버 응답 내용: ${response.body}');
      
      // 응답 처리
      if (response.statusCode == 200) {
        try {
          final responseData = json.decode(response.body);
          if (responseData['success'] == true) {
            // 로컬 데이터 삭제
            await _clearAllUserData();
            
            // 성공 다이얼로그 표시
            if (mounted) {
              _showSuccessDialog();
            }
          } else {
            final message = responseData['message'] ?? '회원탈퇴 처리 중 오류가 발생했습니다.';
            _showErrorSnackBar(message);
          }
        } catch (jsonError) {
          print('JSON 파싱 오류: $jsonError');
          // JSON 파싱 실패해도 200 응답이면 성공으로 간주
          await _clearAllUserData();
          if (mounted) {
            _showSuccessDialog();
          }
        }
        
      } else if (response.statusCode == 401) {
        _showErrorSnackBar('비밀번호가 일치하지 않습니다.');
        
      } else if (response.statusCode == 404) {
        _showErrorSnackBar('사용자 정보를 찾을 수 없습니다.');
        
      } else if (response.statusCode == 403) {
        _showErrorSnackBar('회원탈퇴 권한이 없습니다.');
        
      } else if (response.statusCode >= 500) {
        _showErrorSnackBar('서버 내부 오류가 발생했습니다.\n잠시 후 다시 시도해주세요.');
        
      } else {
        // 기타 오류
        try {
          final errorData = json.decode(response.body);
          final message = errorData['message'] ?? '회원탈퇴 처리 중 오류가 발생했습니다.';
          _showErrorSnackBar(message);
        } catch (e) {
          _showErrorSnackBar('서버 오류가 발생했습니다. (코드: ${response.statusCode})');
        }
      }
      
    } on SocketException catch (e) {
      print('최종 소켓 연결 오류: $e');
      _showErrorSnackBar('네트워크 연결을 확인해주세요.\n• Wi-Fi 또는 모바일 데이터 연결 상태 확인\n• 서버 상태 확인 필요');
      
    } on TimeoutException catch (e) {
      print('최종 타임아웃 오류: $e');
      _showErrorSnackBar('서버 응답 시간이 초과되었습니다.\n잠시 후 다시 시도해주세요.');
      
    } on FormatException catch (e) {
      print('데이터 형식 오류: $e');
      _showErrorSnackBar('서버 응답 형식에 오류가 있습니다.');
      
    } catch (e) {
      print('예상치 못한 오류: $e');
      String errorMessage = '회원탈퇴 처리 중 오류가 발생했습니다.';
      
      if (e.toString().contains('연결')) {
        errorMessage = '서버 연결에 실패했습니다.\n네트워크 설정을 확인해주세요.';
      } else if (e.toString().contains('로그인')) {
        errorMessage = '로그인 정보가 만료되었습니다.\n다시 로그인해주세요.';
      }
      
      _showErrorSnackBar(errorMessage);
      
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 최종 확인 다이얼로그
  Future<bool> _showFinalConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('회원탈퇴 최종 확인', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '정말로 회원탈퇴를 진행하시겠습니까?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 12),
            Text(
              '• 모든 개인정보가 영구적으로 삭제됩니다\n'
              '• 친구 관계 및 위치 공유 정보가 삭제됩니다\n'
              '• 삭제된 정보는 복구할 수 없습니다',
              style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('탈퇴하기', style: TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    ) ?? false;
  }

  // 사용자 데이터 삭제 함수
  Future<void> _clearAllUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 모든 사용자 관련 데이터 삭제
      final keysToRemove = [
        'token',
        'refresh_token',
        'user_id',
        'username',
        'email',
        'profile_data',
        'remember_me',
        'is_logged_in',
        'notification_settings',
        'map_settings',
        'navigation_settings',
        'recent_searches',
        'favorite_locations',
        'user_profile_picture_url',
        'last_location',
        'friend_list',
        'location_sharing_settings',
      ];
      
      for (String key in keysToRemove) {
        await prefs.remove(key);
      }
      
      print('모든 사용자 데이터가 삭제되었습니다.');
    } catch (e) {
      print('사용자 데이터 삭제 중 오류: $e');
      // 데이터 삭제 실패해도 회원탈퇴는 성공으로 간주
    }
  }

  // 에러 메시지 스낵바
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 5),
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: SnackBarAction(
          label: '닫기',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text(
              '회원탈퇴 완료',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Text(
          '회원탈퇴가 정상적으로 처리되었습니다.\n그동안 서비스를 이용해 주셔서 감사합니다.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
            style: TextButton.styleFrom(
              backgroundColor: Color(0xFFFF3B30),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('확인', style: TextStyle(fontWeight: FontWeight.w500)),
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
          onPressed: _isLoading ? null : () => Navigator.pop(context),
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
                        '• 탈퇴 시 모든 개인정보와 이용 기록이 완전히 삭제됩니다.\n'
                        '• 친구 관계, 위치 공유 등 모든 데이터가 삭제됩니다.\n'
                        '• 삭제된 정보는 복구가 불가능합니다.\n'
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
                        '안전한 회원탈퇴를 위해 현재 비밀번호를 입력해주세요.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          hintText: '현재 비밀번호를 입력하세요',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Color(0xFFFF3B30), width: 2),
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
                          onChanged: _isLoading ? null : (value) {
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
                    onPressed: (_isLoading || !_agreeToDelete || (_password?.trim().isEmpty ?? true)) 
                        ? null 
                        : _processAccountDeletion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      disabledBackgroundColor: Colors.grey[300],
                      elevation: _isLoading ? 0 : 2,
                    ),
                    child: _isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                '처리 중...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ],
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
              child: Center(
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF3B30)),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '회원탈퇴 처리 중...',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '모든 데이터를 안전하게 삭제하고 있습니다.\n잠시만 기다려주세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}