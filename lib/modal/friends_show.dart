import 'package:flutter/material.dart';
import 'package:tomapto/pages/friends/real_time_location_sharing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;
import 'package:tomapto/services/socket_service.dart';

class FriendsShowModal extends StatefulWidget {
  final Map<String, dynamic> friend;
  final bool hasFollowRequest;
  final Function onShareStatusChanged; // 추가

  const FriendsShowModal({
    Key? key,
    required this.friend,
    this.hasFollowRequest = false,
    required this.onShareStatusChanged, // 추가
  }) : super(key: key);

  @override
  _FriendsShowModalState createState() => _FriendsShowModalState();
}

class _FriendsShowModalState extends State<FriendsShowModal> {
  bool _isLocationSharingActive = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkLocationSharingStatus();
  }

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

  // 위치 공유 상태 확인
  Future<void> _checkLocationSharingStatus() async {
    try {
      // 🔥 수정: 초기 로딩 상태 설정하여 깜빡임 방지
      if (!mounted) return;

      setState(() {
        _isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final myUserId = prefs.getString('user_id'); // 내 사용자 ID 가져오기

      if (token == null || myUserId == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final apiBaseUrl = _getApiBaseUrl();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/location/active-sharings'), // 원래 API 엔드포인트
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // 내가 친구에게 공유하는지만 체크 (원래 로직)
        final iAmSharingToFriend = data.any(
          (sharing) =>
              sharing['sharer_id'] == myUserId && // 내가 공유자이고
              sharing['sharee_id'] == widget.friend['id'], // 친구가 수신자인 경우만
        );

        if (mounted) {
          setState(() {
            _isLocationSharingActive = iAmSharingToFriend; // 내 공유 상태만 표시
            _isLoading = false;
          });
        }

        print('위치 공유 상태 확인: $_isLocationSharingActive');
      } else {
        print('위치 공유 상태 조회 실패: ${response.statusCode} - ${response.body}');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('위치 공유 상태 조회 오류: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 위치 공유 토글
  Future<void> _toggleLocationSharing() async {
    if (_isLoading) return;

    // mounted 체크 추가
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('로그인이 필요합니다')));
          setState(() => _isLoading = false);
        }
        return;
      }

      // 소켓 서비스 초기화
      final socketService = SocketService();
      if (!socketService.isConnected) {
        await socketService.initSocket();
      }

      if (_isLocationSharingActive) {
        // 위치 공유 종료
        // 상태를 먼저 업데이트해서 깜빡임 방지
        if (mounted) {
          setState(() {
            _isLocationSharingActive = false;
            _isLoading = false;
          });
        }

        socketService.stopLocationSharing(widget.friend['id']);
        widget.onShareStatusChanged(false);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('위치 공유가 비활성화되었습니다')));
        }
      } else {
        // 위치 공유 시작
        // 상태를 먼저 업데이트해서 깜빡임 방지
        if (mounted) {
          setState(() {
            _isLocationSharingActive = true;
            _isLoading = false;
          });
        }

        socketService.startLocationSharing(widget.friend['id'], null);
        widget.onShareStatusChanged(true);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('위치 공유가 활성화되었습니다')));
        }
      }

      if (mounted) {
        Navigator.pop(context); // 성공 후 모달 닫기
      }
    } catch (e) {
      print('위치 공유 상태 변경 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('네트워크 오류가 발생했습니다')));
        setState(() => _isLoading = false);
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
          children:
              _isLoading
                  ? [
                    Container(
                      padding: EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFFB233B),
                        ),
                      ),
                    ),
                  ]
                  : [
                    // 친구 위치 보기 버튼
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => RealTimeLocationSharingPage(
                                  selectedFriend: widget.friend,
                                ),
                          ),
                        );
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
                          child: Row(
                            children: [
                              Text(
                                '친구 위치 보기',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (widget.hasFollowRequest)
                                Container(
                                  margin: EdgeInsets.only(left: 8),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 구분선
                    Container(height: 1, color: Colors.grey[300]),

                    // 위치 공유 활성화/비활성화 버튼
                    InkWell(
                      onTap: _toggleLocationSharing,
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
                            _isLocationSharingActive
                                ? '위치 공유 비활성화'
                                : '위치 공유 활성화',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
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
