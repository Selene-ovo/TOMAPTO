// widgets/drawer_widget.dart
import 'package:flutter/material.dart';
import 'package:tomapto/pages/friends/friends_add.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;

class DrawerWidget extends StatefulWidget {
  final int newRequestsCount;
  final Function onRequestsUpdated;

  const DrawerWidget({
    Key? key,
    required this.newRequestsCount,
    required this.onRequestsUpdated,
  }) : super(key: key);

  @override
  State<DrawerWidget> createState() => _DrawerWidgetState();
}

class _DrawerWidgetState extends State<DrawerWidget> {
  // 사용자 정보를 저장할 변수
  String _userName = '사용자'; // 기본값 설정
  String _userNickname = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 위젯이 화면에 마운트된 후에 데이터를 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserProfile();
    });
  }

  // API 서버 기본 URL 가져오기
  String _getApiBaseUrl() {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/api';
    String? localIp = dotenv.env['LOCAL_IP'];

    // 안드로이드 플랫폼인 경우
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

  // 로그인한 사용자 프로필 정보 로드
  Future<void> _loadUserProfile() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // API 호출하여 프로필 정보 가져오기
      final apiBaseUrl = _getApiBaseUrl();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/account/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final userData = data['data'];

          setState(() {
            _userName = userData['user_name'] ?? '사용자';
            _userNickname = userData['user_nickname'] ?? '';
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('사용자 프로필 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 화면 너비 계산으로 드로어와 회색선의 너비 설정
    final screenWidth = MediaQuery.of(context).size.width;
    final double drawerWidth = screenWidth * 0.65; // 화면 너비의 65%
    final double lineWidth = drawerWidth * 0.8; // 드로어 너비의 80%

    return ClipRect(
      child: Container(
        width: drawerWidth,
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // 상단 패딩 추가
            SizedBox(height: MediaQuery.of(context).padding.top),

            // 햄버거 메뉴 영역 (수정됨: 타이틀 제거)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // 햄버거 메뉴 버튼 (가로선 3개) - 클릭 시 드로어 닫기
                  InkWell(
                    onTap: () {
                      // 드로어 닫기
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(height: 2, width: 18, color: Colors.black),
                          const SizedBox(height: 4),
                          Container(height: 2, width: 18, color: Colors.black),
                          const SizedBox(height: 4),
                          Container(height: 2, width: 18, color: Colors.black),
                        ],
                      ),
                    ),
                  ),
                  // "친구" 텍스트 제거됨
                ],
              ),
            ),

            // 사용자 프로필 영역 - 간격 조정됨
            Padding(
              padding: const EdgeInsets.only(
                top: 10, // 줄어든 상단 여백
                left: 16,
                right: 16,
                bottom: 10, // 줄어든 하단 여백
              ),
              child: Row(
                children: [
                  // 사각형 프로필 이미지
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[300]!, width: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.black,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 사용자 닉네임 또는 이름 표시
                  Expanded(
                    child: Text(
                      _isLoading
                          ? '로드 중...'
                          : (_userNickname.isNotEmpty
                              ? _userNickname
                              : _userName),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.black),
                ],
              ),
            ),

            // 중앙 정렬된 80% 너비의 회색선
            Center(
              child: Container(
                width: lineWidth,
                height: 1,
                color: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 12), // 여백 추가
            // 메뉴 항목 리스트
            ListTile(
              leading: const Icon(Icons.person_add, color: Colors.black87),
              title: Row(
                children: [
                  const Text(
                    '친구 추가',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  if (widget.newRequestsCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.newRequestsCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              onTap: () {
                Navigator.pop(context); // 드로어 닫기

                // 새 요청이 있으면 요청 알림 탭으로, 없으면 검색 결과 탭으로 이동
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => FriendsAddPage(
                          initialSearchTerm: '',
                          initialTabIndex:
                              widget.newRequestsCount > 0
                                  ? 1
                                  : 0, // 새 요청이 있으면 요청 알림 탭(1), 없으면 검색 결과 탭(0)
                        ),
                  ),
                ).then((_) {
                  // 친구 추가 페이지에서 돌아왔을 때 갱신 콜백 호출
                  widget.onRequestsUpdated();
                });
              },
            ),

            ListTile(
              leading: const Icon(Icons.block, color: Colors.black87),
              title: const Text(
                '차단 목록',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                // 차단 목록 페이지로 이동
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('차단 목록 기능은 준비 중입니다')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
