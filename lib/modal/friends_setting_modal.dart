// lib/modal/friends_setting_modal.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;
import 'package:tomapto/services/socket_service.dart';
import 'package:tomapto/pages/friends/real_time_location_sharing.dart';

class FriendsSettingModal extends StatefulWidget {
  final Map<String, dynamic> friend;
  final Function onShareStatusChanged; // 공유 상태 변경 시 호출할 콜백

  const FriendsSettingModal({
    Key? key,
    required this.friend,
    required this.onShareStatusChanged,
  }) : super(key: key);

  @override
  _FriendsSettingModalState createState() => _FriendsSettingModalState();
}

class _FriendsSettingModalState extends State<FriendsSettingModal> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  // API 서버 기본 URL 가져오기
  String _getApiBaseUrl() {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/api';
    String? localIp = dotenv.env['LOCAL_IP'];

    // 안드로이드 에뮬레이터에서 실행 중인 경우
    if (Platform.isAndroid) {
      // localhost를 사용 중이고 LOCAL_IP가 설정되어 있다면
      if (baseUrl.contains('localhost') &&
          localIp != null &&
          localIp.isNotEmpty) {
        // localhost를 LOCAL_IP로 대체
        return baseUrl.replaceAll('localhost', localIp);
      }

      // 에뮬레이터 특정 주소 처리
      if (baseUrl.contains('localhost')) {
        return baseUrl.replaceAll('localhost', '10.0.2.2');
      }
    }

    // 그 외의 경우 원래 URL 반환
    return baseUrl;
  }

  // 친구 차단하기
  Future<void> _blockFriend() async {
    try {
      // mounted 체크 추가
      if (!mounted) return;

      // 차단 확인 다이얼로그 표시
      final confirm =
          await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text('친구 차단'),
                  content: Text(
                    '${widget.friend['name']}님을 차단하시겠습니까?\n차단 시 서로 친구 목록에서 제거되며, 위치 공유도 종료됩니다.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: Text('차단'),
                    ),
                  ],
                ),
          ) ??
          false;

      if (!confirm) return;

      //  mounted 체크 추가
      if (!mounted) return;

      setState(() {
        _isLoading = true;
      });

      // SharedPreferences에서 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('로그인이 필요합니다')));
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // API 호출
      final apiBaseUrl = _getApiBaseUrl();
      final response = await http.post(
        Uri.parse('$apiBaseUrl/friends/block'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'friend_id': widget.friend['id']}),
      );

      if (response.statusCode == 200) {
        // 차단 성공
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.friend['name']}님을 차단했습니다')),
          );
        }

        // 콜백 호출을 통해 친구 목록 갱신
        widget.onShareStatusChanged(false);

        // 모달 닫기
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorData['message'] ?? '친구 차단 실패')),
          );
        }
      }
    } catch (e) {
      print('친구 차단 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('네트워크 오류가 발생했습니다')));
      }
    } finally {
      //  mounted 체크 추가
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 친구 삭제하기
  Future<void> _deleteFriend() async {
    try {
      //  mounted 체크 추가
      if (!mounted) return;

      // 삭제 확인 다이얼로그 표시
      final confirm =
          await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text('친구 삭제'),
                  content: Text('${widget.friend['name']}님을 친구 목록에서 삭제하시겠습니까?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: Text('삭제'),
                    ),
                  ],
                ),
          ) ??
          false;

      if (!confirm) return;

      //  mounted 체크 추가
      if (!mounted) return;

      setState(() {
        _isLoading = true;
      });

      // SharedPreferences에서 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('로그인이 필요합니다')));
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // API 호출
      final apiBaseUrl = _getApiBaseUrl();
      final response = await http.post(
        Uri.parse('$apiBaseUrl/friends/delete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'friend_id': widget.friend['id']}),
      );

      if (response.statusCode == 200) {
        // 친구 삭제 성공
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.friend['name']}님을 친구 목록에서 삭제했습니다'),
            ),
          );
        }

        // 콜백 호출을 통해 친구 목록 갱신
        widget.onShareStatusChanged(false);

        // 모달 닫기
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorData['message'] ?? '친구 삭제 실패')),
          );
        }
      }
    } catch (e) {
      print('친구 삭제 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('네트워크 오류가 발생했습니다')));
      }
    } finally {
      //  mounted 체크 추가
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
            // 차단하기 버튼
            InkWell(
              onTap: () async {
                // 모달을 먼저 닫지 않고 함수에서 처리하도록 변경
                await _blockFriend();
              },
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
                  child: Text(
                    '차단하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.red, // 빨간색
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
            ),

            // 구분선
            Container(height: 1, color: Colors.grey[300]),

            // 삭제하기 버튼
            InkWell(
              onTap: () async {
                // 수정: 모달을 먼저 닫지 않고 함수에서 처리하도록 변경
                await _deleteFriend();
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
                    '친구 삭제하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black, // 검정색
                    ),
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

  // 친구 설정 모달을 표시하는 함수
  void showFriendSettings(
    BuildContext context,
    Map<String, dynamic> friend,
    Function onShareStatusChanged,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => FriendsSettingModal(
            friend: friend,
            onShareStatusChanged: onShareStatusChanged,
          ),
    );
  }
}
