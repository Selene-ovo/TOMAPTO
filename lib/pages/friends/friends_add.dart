import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:tomapto/services/socket_service.dart';
import 'package:tomapto/services/friends_service.dart';

class FriendsAddPage extends StatefulWidget {
  final String initialSearchTerm;
  final int initialTabIndex; // 새로 추가된 파라미터

  const FriendsAddPage({
    Key? key,
    this.initialSearchTerm = '',
    this.initialTabIndex = 0, // 기본값은 '검색 결과' 탭 (0)
  }) : super(key: key);

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

  // 소켓 서비스 인스턴스
  late SocketService _socketService;

  // 탭 컨트롤러
  late TabController _tabController;

  // 아이디 마스킹 함수 (5자 이상 전제)
  String _maskUserId(String userId) {
    if (userId.length < 5) {
      return userId; // 기존 사용자 대응
    }

    String visiblePart = userId.substring(0, userId.length - 4);
    String maskedPart = '****';

    return '$visiblePart$maskedPart';
  }

  // API 토큰 가져오기
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialSearchTerm;

    // 탭 컨트롤러에 초기 탭 인덱스 설정
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex, // 위젯에서 전달된 초기 탭 인덱스 사용
    );

    // 소켓 서비스 초기화
    _socketService = SocketService();
    _initSocketListeners();

    // 초기 검색어가 있으면 자동 검색
    if (widget.initialSearchTerm.isNotEmpty) {
      _searchUsers();
    }

    // 친구 요청 목록 로드
    _loadFriendRequests();
  }

  // ID를 문자열로 변환하는 헬퍼 메서드
  String _ensureStringId(dynamic id) {
    if (id == null) return '';
    return id.toString();
  }

  // 소켓 이벤트 리스너 초기화
  void _initSocketListeners() async {
    if (!_socketService.isConnected) {
      await _socketService.initSocket();
    }

    // 친구 요청 이벤트 리스너
    _socketService.onFriendRequest.listen((data) {
      // 요청 목록 새로고침
      _loadFriendRequests();
    });

    // 친구 수락 이벤트 리스너
    _socketService.onFriendAccept.listen((data) {
      // 친구 목록/검색 결과 갱신을 위해 검색어가 있으면 재검색
      if (_searchController.text.isNotEmpty) {
        _searchUsers();
      }
    });
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
      final results = await FriendsService.searchUsers(searchTerm);

      // 검색 결과 보정 - 요청 받음 상태가 잘못 설정된 경우 수정
      for (var user in results) {
        // request_id가 없거나 비어있는데 request_received가 true인 경우 수정
        if ((_getBoolValue(user['request_received']) == true) &&
            (!user.containsKey('request_id') || user['request_id'] == null)) {
          user['request_received'] = false;
          print('사용자 ${user['user_id']}의 request_received 상태 수정됨: false');
        }
      }

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '사용자 검색 중 오류가 발생했습니다';
        _isLoading = false;
      });
    }
  }

  // 친구 요청 목록 로드
  Future<void> _loadFriendRequests() async {
    try {
      final requests = await FriendsService.getFriendRequests();
      setState(() {
        _friendRequests = requests;
      });
    } catch (e) {
      print('친구 요청 목록 로드 오류: $e');
    }
  }

  // 친구 요청 보내기
  Future<void> _sendFriendRequest(String userId) async {
    try {
      // 소켓이 연결되어 있는지 확인
      if (!_socketService.isConnected) {
        await _socketService.initSocket();
      }

      // 소켓을 통한 실시간 알림 전송
      _socketService.sendFriendRequest(userId);

      // API를 통한 데이터베이스 업데이트
      final success = await FriendsService.sendFriendRequest(userId);

      if (success) {
        await Future.delayed(Duration(milliseconds: 500)); // 서버 처리 시간 고려
        _searchUsers();
      }
    } catch (e) {
      print('친구 요청 보내기 오류: $e');
    }
  }

  // 친구 요청 취소
  Future<void> _cancelFriendRequest(dynamic requestId) async {
    try {
      // request_id를 문자열로 변환
      final stringRequestId = _ensureStringId(requestId);
      print('요청 취소 시도: $stringRequestId (원본 타입: ${requestId.runtimeType})');

      if (stringRequestId.isEmpty) {
        print('유효하지 않은 요청 ID입니다');
        return;
      }

      // API를 통한 요청 취소
      final success = await FriendsService.cancelFriendRequest(stringRequestId);

      if (success) {
        await Future.delayed(Duration(milliseconds: 500)); // 서버 처리 시간 고려
        _searchUsers();
      }
    } catch (e) {
      print('친구 요청 취소 오류: $e');
    }
  }

  // 친구 요청 수락
  Future<void> _acceptFriendRequest(dynamic requestId) async {
    try {
      // request_id를 문자열로 변환
      final stringRequestId = _ensureStringId(requestId);
      print('요청 수락 원본 ID: $requestId');
      print('요청 수락 ID 타입: ${requestId.runtimeType}');
      print('요청 수락 변환 후 ID: $stringRequestId');

      if (stringRequestId.isEmpty) {
        print('유효하지 않은 요청 ID입니다');
        return;
      }

      // 사용자 ID 가져오기
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';

      print('수락할 요청 ID: $stringRequestId, 사용자 ID: $userId');

      // 요청 확인 API 호출 (서버에서 해당 API가 구현되어 있다면)
      final apiBaseUrl = _getApiBaseUrl();
      final checkUrl = '$apiBaseUrl/friends/request/$stringRequestId/check';
      try {
        final checkResponse = await http.get(
          Uri.parse(checkUrl),
          headers: {'Authorization': 'Bearer ${await getToken()}'},
        );
        print('요청 확인 응답: ${checkResponse.statusCode} - ${checkResponse.body}');
      } catch (e) {
        print('요청 확인 API 호출 오류 (무시): $e');
      }

      // 소켓이 연결되어 있는지 확인
      if (!_socketService.isConnected) {
        await _socketService.initSocket();
      }

      // 소켓을 통한 수락 이벤트 전송
      _socketService.acceptFriendRequest(stringRequestId);

      // API를 통한 요청 수락
      final success = await FriendsService.acceptFriendRequest(stringRequestId);

      if (success) {
        await Future.delayed(Duration(milliseconds: 500)); // 서버 처리 시간 고려
        _loadFriendRequests();

        // 검색 결과에도 영향을 미칠 수 있으므로 검색어가 있으면 재검색
        if (_searchController.text.isNotEmpty) {
          _searchUsers();
        }
      }
    } catch (e) {
      print('친구 요청 수락 오류: $e');
    }
  }

  // 친구 요청 거절
  Future<void> _rejectFriendRequest(dynamic requestId) async {
    try {
      // request_id를 문자열로 변환
      final stringRequestId = _ensureStringId(requestId);
      print('요청 거절 시도: $stringRequestId (원본 타입: ${requestId.runtimeType})');

      if (stringRequestId.isEmpty) {
        print('유효하지 않은 요청 ID입니다');
        return;
      }

      // API를 통한 요청 거절
      final success = await FriendsService.rejectFriendRequest(stringRequestId);

      if (success) {
        await Future.delayed(Duration(milliseconds: 500)); // 서버 처리 시간 고려
        _loadFriendRequests();
      }
    } catch (e) {
      print('친구 요청 거절 오류: $e');
    }
  }

  // 다양한 타입의 불리언 값 처리를 위한 헬퍼 메서드
  bool _getBoolValue(dynamic value) {
    if (value == null) return false;

    if (value is bool) {
      return value;
    } else if (value is int) {
      return value == 1;
    } else if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    return false;
  }

  // 사용자 옵션 모달 표시
  void _showUserOptions(Map<String, dynamic> user) {
    // 서버에서 올바른 상태를 확인하기 전에 추가 검증
    bool isFriend =
        _getBoolValue(user['is_friend']) &&
        (user['friendship_status'] == 'active' ||
            user['friendship_status'] == null);

    bool isRequestSent =
        _getBoolValue(user['request_sent']) &&
        (user['request_status'] == 'pending' || user['request_status'] == null);

    // 중요: request_id가 유효하지 않은 경우 요청 받음 상태를 무시하고 일반 상태로 처리
    bool isRequestReceived = false;

    // 디버깅
    print(
      '사용자 ${user['user_id']} 상태: ' +
          'is_friend=${user['is_friend']}, ' +
          'request_sent=${user['request_sent']}, ' +
          'request_received=${user['request_received']}, ' +
          'request_id=${user['request_id']}',
    );

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
                  // 첫 번째 버튼: 상태에 따라 다른 옵션 표시
                  if (isFriend)
                    // 친구인 경우: "친구 삭제하기" 표시
                    InkWell(
                      onTap: () async {
                        Navigator.pop(context);
                        final success = await FriendsService.deleteFriend(
                          user['user_id'],
                        );
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${user['user_nickname'] ?? user['user_id']}님을 친구 목록에서 삭제했습니다.',
                              ),
                              backgroundColor: Color(0xFFFB233B),
                            ),
                          );
                          _searchUsers(); // 검색 결과 새로고침
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        margin: EdgeInsets.symmetric(horizontal: 24.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '친구 삭제하기',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFFB233B),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    )
                  else if (isRequestSent)
                    // 요청 보낸 경우: "친구 요청 취소하기" 표시
                    InkWell(
                      onTap: () async {
                        Navigator.pop(context);
                        await _cancelFriendRequest(user['request_id']);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${user['user_nickname'] ?? user['user_id']}님에게 보낸 친구 요청을 취소했습니다.',
                            ),
                            backgroundColor: Colors.grey[600],
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        margin: EdgeInsets.symmetric(horizontal: 24.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '친구 요청 취소하기',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    )
                  else
                    // 일반 사용자인 경우: "친구 요청 보내기" 표시
                    InkWell(
                      onTap: () async {
                        Navigator.pop(context);
                        await _sendFriendRequest(user['user_id']);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${user['user_nickname'] ?? user['user_id']}님에게 친구 요청을 보냈습니다.',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        margin: EdgeInsets.symmetric(horizontal: 24.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '친구 요청 보내기',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),

                  SizedBox(height: 8),

                  // 두 번째 버튼: "차단하기" (모든 경우에 표시)
                  InkWell(
                    onTap: () async {
                      Navigator.pop(context);
                      final success = await FriendsService.blockFriend(
                        user['user_id'],
                      );
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${user['user_nickname'] ?? user['user_id']}님을 차단했습니다.',
                            ),
                            backgroundColor: Color(0xFFFB233B),
                          ),
                        );
                        _searchUsers(); // 검색 결과 새로고침
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      margin: EdgeInsets.symmetric(horizontal: 24.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '차단하기',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFFB233B),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 8),

                  // 세 번째 버튼: "취소" (닫기)
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      margin: EdgeInsets.symmetric(horizontal: 24.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '취소',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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

  // 친구 요청 카드 위젯
  Widget _buildFriendRequestCard(Map<String, dynamic> request) {
    final senderNickname = request['sender_nickname']?.toString() ?? '';
    final senderId = request['sender_id']?.toString() ?? '';
    final maskedId = _maskUserId(senderId);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 프로필 이미지
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[300],
            child: Icon(Icons.person, color: Colors.grey[600]),
          ),
          SizedBox(width: 12),
          // 사용자 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  senderNickname.isNotEmpty ? senderNickname : maskedId,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (senderNickname.isNotEmpty)
                  Text(
                    maskedId,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
              ],
            ),
          ),
          // 수락/거절 버튼
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Color(0xFFFB233B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Image.asset(
                    'assets/icons/person_remove.png',
                    width: 24,
                    height: 24,
                  ),
                  onPressed: () {
                    if (request.containsKey('request_id')) {
                      _rejectFriendRequest(request['request_id']);
                    }
                  },
                ),
              ),
              SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Image.asset(
                    'assets/icons/person_add.png',
                    width: 24,
                    height: 24,
                  ),
                  onPressed: () {
                    if (request.containsKey('request_id')) {
                      _acceptFriendRequest(request['request_id']);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
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
                    child: Center(
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(fontSize: 14),
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          hintText: '닉네임을 입력해주세요.',
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 0,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey[500],
                            size: 20,
                          ),
                        ),
                        onSubmitted: (value) => _searchUsers(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 검색 버튼
                GestureDetector(
                  onTap: _searchUsers,
                  child: Container(
                    height: 35,
                    width: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFB233B),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Center(
                      child: Text(
                        '검색',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 탭바
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.0),
            child: TabBar(
              controller: _tabController,
              labelColor: Color(0xFFFB233B),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFFFB233B),
              tabs: [Tab(text: '검색 결과'), Tab(text: '친구 요청')],
            ),
          ),

          // 탭뷰
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 검색 결과 탭
                _buildSearchResultsTab(),
                // 친구 요청 탭
                _buildFriendRequestsTab(),
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
      return Center(
        child: Text(_errorMessage, style: TextStyle(color: Colors.red)),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty ? '닉네임을 검색해보세요' : '검색 결과가 없습니다',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _buildUserCard(user);
      },
    );
  }

  // 친구 요청 탭 위젯
  Widget _buildFriendRequestsTab() {
    if (_friendRequests.isEmpty) {
      return Center(
        child: Text(
          '받은 친구 요청이 없습니다',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      itemCount: _friendRequests.length,
      itemBuilder: (context, index) {
        final request = _friendRequests[index];
        return _buildFriendRequestCard(request);
      },
    );
  }

  // 사용자 카드 위젯
  Widget _buildUserCard(Map<String, dynamic> user) {
    final nickname = user['user_nickname']?.toString() ?? '';
    final userId = user['user_id']?.toString() ?? '';
    final maskedId = _maskUserId(userId);

    // 상태 확인
    bool isFriend = _getBoolValue(user['is_friend']);
    bool isRequestSent = _getBoolValue(user['request_sent']);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 프로필 이미지
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[300],
            child: Icon(Icons.person, color: Colors.grey[600]),
          ),
          SizedBox(width: 12),
          // 사용자 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname.isNotEmpty ? nickname : maskedId,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (nickname.isNotEmpty)
                  Text(
                    maskedId,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
              ],
            ),
          ),
          // 상태에 따른 버튼
          GestureDetector(
            onTap: () => _showUserOptions(user),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color:
                    isFriend
                        ? Colors.green
                        : isRequestSent
                        ? Colors.grey[400]
                        : Color(0xFFFB233B),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isFriend
                    ? '친구'
                    : isRequestSent
                    ? '요청됨'
                    : '요청',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
