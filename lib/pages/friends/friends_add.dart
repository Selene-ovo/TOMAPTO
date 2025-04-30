import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:tomapto/widgets/ad_placeholder.dart';
import 'package:tomapto/services/socket_service.dart';

class FriendsAddPage extends StatefulWidget {
  final String initialSearchTerm;

  const FriendsAddPage({Key? key, this.initialSearchTerm = ''})
    : super(key: key);

  @override
  _FriendsAddPageState createState() => _FriendsAddPageState();
}

class _FriendsAddPageState extends State<FriendsAddPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _friendRequests = [];

  // 탭 컨트롤러
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialSearchTerm;
    _tabController = TabController(length: 2, vsync: this);

    // 초기 검색어가 있으면 자동 검색
    if (widget.initialSearchTerm.isNotEmpty) {
      _searchUsers();
    }

    // 친구 요청 목록 로드
    _loadFriendRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // API 서버 기본 URL 가져오기
  String _getApiBaseUrl() {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/api';
    String? localIp = dotenv.env['LOCAL_IP'];

    // 안드로이드 플랫폼인 경우
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

    // 다른 플랫폼이거나 이미 localhost가 아닌 경우 원래 URL 반환
    return baseUrl;
  }

  // 사용자 검색
  Future<void> _searchUsers() async {
    final searchTerm = _searchController.text.trim();
    if (searchTerm.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // SharedPreferences에서 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        setState(() {
          _errorMessage = '로그인이 필요합니다';
          _isLoading = false;
        });
        return;
      }

      // API 호출
      final apiBaseUrl = _getApiBaseUrl();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/account/search?term=$searchTerm'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(data['users'] ?? []);
          _isLoading = false;
        });
      } else {
        print('사용자 검색 실패: ${response.statusCode} - ${response.body}');
        setState(() {
          _errorMessage = '사용자 검색 중 오류가 발생했습니다';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('사용자 검색 오류: $e');
      setState(() {
        _errorMessage = '네트워크 오류가 발생했습니다';
        _isLoading = false;
      });
    }
  }

  // 친구 요청 목록 로드
  Future<void> _loadFriendRequests() async {
    try {
      // SharedPreferences에서 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        setState(() {
          _errorMessage = '로그인이 필요합니다';
        });
        return;
      }

      // API 호출
      final apiBaseUrl = _getApiBaseUrl();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/friends/requests'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          _friendRequests = List<Map<String, dynamic>>.from(
            data['requests'] ?? [],
          );
        });
      } else {
        print('친구 요청 목록 불러오기 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('친구 요청 목록 로드 오류: $e');
    }
  }

  // 친구 요청 보내기
  Future<void> _sendFriendRequest(String userId) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // SharedPreferences에서 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        setState(() {
          _errorMessage = '로그인이 필요합니다';
          _isLoading = false;
        });
        return;
      }

      // 소켓 서비스를 사용하여 친구 요청 전송
      final socketService = SocketService();
      if (!socketService.isConnected) {
        await socketService.initSocket();
      }

      // 소켓으로 친구 요청 전송
      socketService.sendFriendRequest(userId);

      // API 호출도 병행 (소켓 연결 실패 시 대비)
      final apiBaseUrl = _getApiBaseUrl();
      final response = await http.post(
        Uri.parse('$apiBaseUrl/friends/request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'recipient_id': userId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // 요청 성공 처리
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('친구 요청을 보냈습니다')));

        // 검색 결과에서 해당 사용자 상태 업데이트
        setState(() {
          for (var user in _searchResults) {
            if (user['user_id'] == userId) {
              user['request_sent'] = true;
            }
          }
        });
      } else {
        final errorData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorData['message'] ?? '친구 요청 실패')),
        );
      }
    } catch (e) {
      print('친구 요청 보내기 오류: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('네트워크 오류가 발생했습니다')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 친구 요청 수락
  Future<void> _acceptFriendRequest(String requestId) async {
    try {
      // API 호출 구현
      // ...

      // 요청 목록 새로고침
      _loadFriendRequests();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('친구 요청을 수락했습니다')));
    } catch (e) {
      print('친구 요청 수락 오류: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('네트워크 오류가 발생했습니다')));
    }
  }

  // 친구 요청 거절
  Future<void> _rejectFriendRequest(String requestId) async {
    try {
      // API 호출 구현
      // ...

      // 요청 목록 새로고침
      _loadFriendRequests();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('친구 요청을 거절했습니다')));
    } catch (e) {
      print('친구 요청 거절 오류: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('네트워크 오류가 발생했습니다')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '친구 추가',
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
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20.0),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: '닉네임을 입력해주세요.',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 11),
                        ),
                        onSubmitted: (_) => _searchUsers(),
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
                    child: InkWell(
                      onTap: _searchUsers,
                      child: Icon(Icons.search, color: Colors.black, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 광고 플레이스홀더
          AdPlaceholder(),
          SizedBox(height: 5),

          // 탭바
          TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.red,
            tabs: const [Tab(text: '검색 결과'), Tab(text: '요청 알림')],
          ),

          // 구분선
          Container(height: 1, color: Colors.grey[300]),

          // 탭 컨텐츠
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 검색 결과 탭
                _buildSearchResultsTab(),

                // 요청 알림 탭
                _buildRequestsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 검색 결과 탭 위젯
  Widget _buildSearchResultsTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage));
    }

    if (_searchResults.isEmpty) {
      return Center(child: Text('검색 결과가 없습니다'));
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final bool isRequestSent = user['request_sent'] == true;

        return Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 25, vertical: 4),
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!, width: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.person, color: Colors.black, size: 30),
              ),
              title: Text(
                user['user_nickname'] ?? user['user_id'],
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
              ),
              trailing: ElevatedButton(
                onPressed:
                    isRequestSent
                        ? null
                        : () => _sendFriendRequest(user['user_id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRequestSent ? Colors.grey : Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  isRequestSent ? '요청됨' : '친구 추가',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            Divider(height: 1, thickness: 0.5, color: Colors.grey[300]),
          ],
        );
      },
    );
  }

  // 요청 알림 탭 위젯
  Widget _buildRequestsTab() {
    if (_friendRequests.isEmpty) {
      return Center(child: Text('받은 친구 요청이 없습니다'));
    }

    return ListView.builder(
      itemCount: _friendRequests.length,
      itemBuilder: (context, index) {
        final request = _friendRequests[index];

        return Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 25, vertical: 4),
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!, width: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.person, color: Colors.black, size: 30),
              ),
              title: Text(
                request['sender_nickname'] ?? request['sender_id'],
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
              ),
              subtitle: Text('친구 요청을 보냈습니다'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 수락 버튼
                  ElevatedButton(
                    onPressed:
                        () => _acceptFriendRequest(request['request_id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text('수락', style: TextStyle(color: Colors.white)),
                  ),
                  SizedBox(width: 8),
                  // 거절 버튼
                  OutlinedButton(
                    onPressed:
                        () => _rejectFriendRequest(request['request_id']),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text('거절'),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 0.5, color: Colors.grey[300]),
          ],
        );
      },
    );
  }
}
