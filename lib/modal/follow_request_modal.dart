// lib/modal/follow_request_modal.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FollowRequestModal extends StatefulWidget {
  final int requestId;
  final String requesterName;
  final VoidCallback? onResponseSent; // 응답 후 콜백

  const FollowRequestModal({
    Key? key,
    required this.requestId,
    required this.requesterName,
    this.onResponseSent,
  }) : super(key: key);

  @override
  _FollowRequestModalState createState() => _FollowRequestModalState();
}

class _FollowRequestModalState extends State<FollowRequestModal> {
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

  // 따라가기 요청 응답
  Future<void> _respondToRequest(String response) async {
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
      final httpResponse = await http.post(
        Uri.parse('$apiBaseUrl/follow/respond'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'request_id': widget.requestId,
          'response': response, // 'accept' or 'reject'
        }),
      );

      final data = json.decode(httpResponse.body);

      if (httpResponse.statusCode == 200) {
        final message =
            response == 'accept' ? '따라가기 요청을 수락했습니다' : '따라가기 요청을 거절했습니다';
        _showSnackBar(message);

        if (widget.onResponseSent != null) {
          widget.onResponseSent!();
        }
        Navigator.pop(context);
      } else {
        _showSnackBar(data['error'] ?? '응답 실패');
      }
    } catch (e) {
      print('따라가기 응답 오류: $e');
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('따라가기 요청'),
      content: Text('${widget.requesterName}님이 따라가기를 요청했습니다.\n수락하시겠습니까?'),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => _respondToRequest('reject'),
          child: Text('거절하기', style: TextStyle(color: Colors.grey[600])),
        ),
        TextButton(
          onPressed: _isLoading ? null : () => _respondToRequest('accept'),
          child:
              _isLoading
                  ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Text('수락하기', style: TextStyle(color: Colors.blue)),
        ),
      ],
    );
  }
}
