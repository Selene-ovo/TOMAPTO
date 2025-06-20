// lib/modal/follow_modal.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FollowModal extends StatefulWidget {
  final Map<String, dynamic> friend;
  final String currentStatus; // 'none', 'pending', 'accepted'
  final bool isRequester; // 내가 요청한 상태인지
  final VoidCallback onStatusChanged; // 상태 변경 콜백

  const FollowModal({
    Key? key,
    required this.friend,
    required this.currentStatus,
    required this.isRequester,
    required this.onStatusChanged,
  }) : super(key: key);

  @override
  _FollowModalState createState() => _FollowModalState();
}

class _FollowModalState extends State<FollowModal> {
  bool _isLoading = false;

  // API 서버 기본 URL 가져오기
  String _getApiBaseUrl() {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/api';
    String? localIp = dotenv.env['LOCAL_IP'];

    if (Platform.isAndroid) {
      if (baseUrl.contains('localhost') &&
          localIp != null &&
          localIp.isNotEmpty) {
        return baseUrl.replaceAll('localhost', localIp);
      }
      if (baseUrl.contains('localhost')) {
        return baseUrl.replaceAll('localhost', '10.0.2.2');
      }
    }
    return baseUrl;
  }

  // 따라가기 요청 보내기
  Future<void> _sendFollowRequest() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        _showSnackBar('로그인이 필요합니다');
        return;
      }

      final apiBaseUrl = _getApiBaseUrl();
      final response = await http.post(
        Uri.parse('$apiBaseUrl/follow/request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'friend_id': widget.friend['id']}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        _showSnackBar('따라가기 요청을 보냈습니다');
        widget.onStatusChanged(); // 상태 갱신
        Navigator.pop(context);
      } else if (response.statusCode == 409) {
        // 중복 요청 처리
        _showSnackBar(data['error']);
        Navigator.pop(context);
      } else {
        _showSnackBar(data['error'] ?? '요청 실패');
      }
    } catch (e) {
      print('따라가기 요청 오류: $e');
      _showSnackBar('네트워크 오류가 발생했습니다');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 따라가기 요청 취소
  Future<void> _cancelFollowRequest() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        _showSnackBar('로그인이 필요합니다');
        return;
      }

      final apiBaseUrl = _getApiBaseUrl();
      final response = await http.post(
        Uri.parse('$apiBaseUrl/follow/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'friend_id': widget.friend['id']}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        _showSnackBar('따라가기 요청을 취소했습니다');
        widget.onStatusChanged(); // 상태 갱신
        Navigator.pop(context);
      } else {
        _showSnackBar(data['error'] ?? '취소 실패');
      }
    } catch (e) {
      print('따라가기 취소 오류: $e');
      _showSnackBar('네트워크 오류가 발생했습니다');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 따라가기 중단
  Future<void> _stopFollowing() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        _showSnackBar('로그인이 필요합니다');
        return;
      }

      final apiBaseUrl = _getApiBaseUrl();
      final response = await http.post(
        Uri.parse('$apiBaseUrl/follow/stop'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'friend_id': widget.friend['id']}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        _showSnackBar('따라가기를 중단했습니다');
        widget.onStatusChanged(); // 상태 갱신
        Navigator.pop(context);
      } else {
        _showSnackBar(data['error'] ?? '중단 실패');
      }
    } catch (e) {
      print('따라가기 중단 오류: $e');
      _showSnackBar('네트워크 오류가 발생했습니다');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // 상태에 따른 버튼 텍스트 및 액션 결정
  Widget _buildFollowButton() {
    String buttonText;
    VoidCallback? onPressed;

    switch (widget.currentStatus) {
      case 'pending':
        if (widget.isRequester) {
          buttonText = '찾아가기 취소하기';
          onPressed = _cancelFollowRequest;
        } else {
          // 상대방이 요청한 경우 - 이 모달에서는 처리하지 않음
          return SizedBox.shrink();
        }
        break;
      case 'accepted':
        buttonText = '찾아가기';
        onPressed = () {
          // 이미 따라가기 중이면 스낵바 표시
          _showSnackBar('이미 따라가기중입니다');
        };
        break;
      default: // 'none'
        buttonText = '찾아가기';
        onPressed = _sendFollowRequest;
        break;
    }

    return InkWell(
      onTap: _isLoading ? null : onPressed,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(left: 16.0),
          child:
              _isLoading
                  ? Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text(
                        '처리중...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ],
                  )
                  : Text(
                    buttonText,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.left,
                  ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 따라가기 버튼
            _buildFollowButton(),

            // 구분선
            Container(height: 1, color: Colors.grey[300]),

            // 그만하기 버튼
            InkWell(
              onTap:
                  _isLoading
                      ? null
                      : () {
                        Navigator.pop(context);
                      },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.only(left: 16.0),
                  child: Text(
                    '그만하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.left,
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
