import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;
import 'package:tomapto/widgets/ad_placeholder.dart';
import 'package:tomapto/widgets/navbar.dart';

class BlacklistFriends extends StatefulWidget {
  @override
  _BlacklistFriendsState createState() => _BlacklistFriendsState();
}

class _BlacklistFriendsState extends State<BlacklistFriends> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _blockedUsers = [];
  List<Map<String, dynamic>> _filteredBlockedUsers = [];
  String _errorMessage = '';

  // 아이디 마스킹 함수 추가
  String _maskUserId(String userId) {
    if (userId.length < 5) {
      return userId;
    }

    String visiblePart = userId.substring(0, userId.length - 4);
    String maskedPart = '****';

    return '$visiblePart$maskedPart';
  }

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  // 차단 목록 불러오기
  Future<void> _loadBlockedUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = '로그인이 필요합니다';
        });
        return;
      }

      final apiBaseUrl = _getApiBaseUrl();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/friends/blocked'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _blockedUsers = List<Map<String, dynamic>>.from(
            data['blockedUsers'] ?? [],
          );
          _filteredBlockedUsers = List<Map<String, dynamic>>.from(
            _blockedUsers,
          );
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = '차단 목록을 불러오는데 실패했습니다';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '오류가 발생했습니다: $e';
      });
    }
  }

  // 차단 해제
  Future<void> _unblockUser(String userId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = '로그인이 필요합니다';
        });
        return;
      }

      final apiBaseUrl = _getApiBaseUrl();
      final response = await http.post(
        Uri.parse('$apiBaseUrl/friends/unblock'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'blocked_id': userId}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('차단이 해제되었습니다')));

        // 목록 새로고침
        _loadBlockedUsers();
      } else {
        setState(() {
          _isLoading = false;
          final data = json.decode(response.body);
          _errorMessage = data['error'] ?? '차단 해제에 실패했습니다';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '오류가 발생했습니다: $e';
      });
    }
  }

  // 검색어로 차단 목록 필터링
  void _filterBlockedUsers(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredBlockedUsers = List<Map<String, dynamic>>.from(_blockedUsers);
      });
    } else {
      setState(() {
        _filteredBlockedUsers =
            _blockedUsers
                .where(
                  (user) =>
                      (user['name']?.toString().toLowerCase() ?? '').contains(
                        query.toLowerCase(),
                      ) ||
                      (user['nickname']?.toString().toLowerCase() ?? '')
                          .contains(query.toLowerCase()) ||
                      (user['id']?.toString().toLowerCase() ?? '').contains(
                        query.toLowerCase(),
                      ),
                )
                .toList();
      });
    }
  }

  // 차단 사용자 옵션 모달 표시
  void _showBlockedUserOptions(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
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
                  // 차단 해제하기 버튼
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _unblockUser(user['id']);
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
                          '차단 해제하기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ),
                  ),

                  // 구분선
                  Container(height: 1, color: Colors.grey[300]),

                  // 친구 삭제하기 버튼
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      // 차단된 사용자는 이미 친구 관계가 아닐 수 있으므로 스낵바만 표시
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('이미 차단된 사용자이므로 친구 관계가 아닙니다')),
                      );
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
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '친구 차단',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 검색창
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 56.0,
              vertical: 10.0,
            ),
            child: Row(
              children: [
                // 검색창
                Expanded(
                  child: Container(
                    height: 35,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(fontSize: 14),
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          hintText: '닉네임을 입력해주세요.',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 0,
                          ),
                        ),
                        onChanged: (text) => _filterBlockedUsers(text),
                      ),
                    ),
                  ),
                ),

                // 돋보기 아이콘
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Container(
                    width: 15,
                    height: 42,
                    decoration: BoxDecoration(shape: BoxShape.circle),
                    child: Icon(Icons.search, color: Colors.black, size: 22),
                  ),
                ),
              ],
            ),
          ),

          // Google AdSense 배너
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 16.0,
            ),
            child: Image.asset(
              'assets/icons/adsense_banner.png',
              width: double.infinity,
              height: 50,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(height: 5),

          // 차단 목록 타이틀
          Container(
            width: double.infinity,
            color: Colors.white,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Center(
                    child: Text(
                      '차단 목록',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                Container(height: 3, color: Colors.red),
              ],
            ),
          ),

          // 차단 목록
          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFFB233B),
                        ),
                      ),
                    )
                    : _errorMessage.isNotEmpty
                    ? Center(child: Text(_errorMessage))
                    : _filteredBlockedUsers.isEmpty
                    ? Center(child: Text('차단한 사용자가 없습니다'))
                    : RefreshIndicator(
                      onRefresh: _loadBlockedUsers,
                      child: ListView.builder(
                        itemCount: _filteredBlockedUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredBlockedUsers[index];
                          return Column(
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 0,
                                ),
                                leading: Container(
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
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.black,
                                    size: 30,
                                  ),
                                ),
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 닉네임 (메인 표시)
                                    Text(
                                      user['nickname'] ??
                                          user['name'] ??
                                          '닉네임 없음',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 15,
                                      ),
                                    ),
                                    // 마스킹된 아이디 (항상 표시)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        '@${_maskUserId(user['id'] ?? 'unknown')}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.more_vert,
                                    color: Colors.black,
                                  ),
                                  onPressed:
                                      () => _showBlockedUserOptions(user),
                                ),
                              ),
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                color: Colors.grey[300],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
