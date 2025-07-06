// widgets/drawer_widget.dart
import 'package:flutter/material.dart';
import 'package:tomapto/pages/friends/friends_add.dart';
import 'package:tomapto/pages/friends/blacklist_friends.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomapto/pages/profile/profile_edit.dart';
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
  String _userId = ''; // 사용자 ID 추가
  String? _profileImageUrl; // 프로필 이미지 URL 추가
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 위젯이 화면에 마운트된 후에 데이터를 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserProfile();
      _loadProfileImage();
    });
  }

  // 아이디 마스킹 함수 추가
  String _maskUserId(String userId) {
    if (userId.length < 5) {
      return userId; // 기존 사용자 대응
    }

    String visiblePart = userId.substring(0, userId.length - 4);
    String maskedPart = '****';

    return '$visiblePart$maskedPart';
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
            _userId = userData['user_id'] ?? ''; // 사용자 ID 저장
            _profileImageUrl =
                userData['user_profile_picture_url']; // 프로필 이미지 URL 저장
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

  // 프로필 이미지 URL 로드 (추가로 호출하는 메서드)
  Future<void> _loadProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) return;

      final apiBaseUrl = _getApiBaseUrl();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/account/profile-edit/current'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _profileImageUrl = data['data']['user_profile_picture_url'];
          });
        }
      }
    } catch (e) {
      print('프로필 이미지 로드 오류: $e');
    }
  }

  // 프로필 이미지 위젯 빌드
  Widget _buildProfileImage() {
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          _profileImageUrl!,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.person, color: Colors.black, size: 30);
          },
        ),
      );
    } else {
      return const Icon(Icons.person, color: Colors.black, size: 30);
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
                ],
              ),
            ),

            // 사용자 프로필 영역 - 간격 조정됨
            InkWell(
              onTap: () async {
                // 프로필 편집 페이지로 이동
                final prefs = await SharedPreferences.getInstance();
                final String currentUserId =
                    prefs.getString('user_id') ?? _userId;

                if (currentUserId.isEmpty) {
                  // 사용자 ID가 없으면 오류 메시지 표시
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('사용자 정보를 찾을 수 없습니다.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // DrawerWidget 닫기
                Navigator.pop(context);

                // 프로필 편집 페이지로 이동
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileEditPage(
                      currentUserId: currentUserId,
                      currentNickname: _userNickname.isNotEmpty
                          ? _userNickname
                          : _userName,
                    ),
                  ),
                ).then((_) {
                  // 프로필 편집 페이지에서 돌아왔을 때 프로필 정보 다시 로드
                  _loadUserProfile();
                  _loadProfileImage();
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 10,
                  left: 16,
                  right: 16,
                  bottom: 10,
                ),
                child: Row(
                  children: [
                    // 사각형 프로필 이미지
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _buildProfileImage(),
                    ),
                    const SizedBox(width: 12),
                    // 사용자 정보 표시 - 닉네임과 마스킹된 아이디로 변경
                    Expanded(
                      child: _isLoading
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '로드 중...',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 닉네임 (메인 표시)
                                Text(
                                  _userNickname.isNotEmpty
                                      ? _userNickname
                                      : _userName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                // 마스킹된 아이디 (아래에 작게 표시)
                                if (_userId.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      '@${_maskUserId(_userId)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.black),
                  ],
                ),
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
                    builder: (context) => FriendsAddPage(
                      initialSearchTerm: '',
                      initialTabIndex: widget.newRequestsCount > 0 ? 1 : 0,
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
                Navigator.pop(context); // 드로어 닫기
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BlacklistFriends()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
