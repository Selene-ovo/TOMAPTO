import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:tomapto/widgets/ad_placeholder.dart';
import 'package:tomapto/services/socket_service.dart';
import 'package:tomapto/services/friends_service.dart';
import 'package:tomapto/controllers/friends/friends_controller.dart';

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

  // 컨트롤러 인스턴스 추가
  final FriendsController _friendsController = FriendsController();

  // 소켓 서비스 인스턴스
  late SocketService _socketService;

  // 탭 컨트롤러
  late TabController _tabController;

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
      final results = await _friendsController.searchUsers(
        searchTerm,
        setState,
      );

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
    await _friendsController.loadFriendRequests(setState);
    setState(() {
      _friendRequests = _friendsController.friendRequests;
    });
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
      final success = await _friendsController.sendFriendRequest(
        userId,
        setState,
      );

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
      final success = await _friendsController.cancelFriendRequest(
        stringRequestId,
        setState,
      );

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
      final success = await _friendsController.acceptFriendRequest(
        stringRequestId,
        setState,
      );

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
      final success = await _friendsController.rejectFriendRequest(
        stringRequestId,
        setState,
      );

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
                        final success = await _friendsController.deleteFriend(
                          user['user_id'],
                          setState,
                        );
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${user['user_nickname'] ?? user['user_id']}님을 친구 목록에서 삭제했습니다',
                              ),
                              backgroundColor: Colors.black,
                              duration: Duration(seconds: 2),
                            ),
                          );
                          await Future.delayed(Duration(milliseconds: 800));
                          _searchUsers();
                        }
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
                    )
                  else if (isRequestSent)
                    // 요청 보낸 경우: "요청 취소하기" 표시
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        if (user['request_id'] != null) {
                          _cancelFriendRequest(user['request_id']);
                          // 요청 취소 SnackBar 표시
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${user['user_nickname'] ?? user['user_id']}님에게 보낸 친구 요청을 취소했습니다',
                              ),
                              backgroundColor: Colors.black,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
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
                            '요청 취소하기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ),
                    )
                  else
                    // 일반 상태(친구 아님): "친구 요청 보내기" 표시
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _sendFriendRequest(user['user_id']);
                        // 요청 보내기 SnackBar 표시
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${user['user_nickname'] ?? user['user_id']}님에게 친구 요청을 보냈습니다',
                            ),
                            backgroundColor: Colors.black,
                            duration: Duration(seconds: 2),
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
                          child: Text(
                            '친구 요청 보내기',
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

                  // 두 번째 버튼: 항상 "친구 차단하기" 표시
                  InkWell(
                    onTap: () async {
                      Navigator.pop(context); // 모달 닫기
                      try {
                        final success = await _friendsController.blockFriend(
                          user['user_id'],
                          setState,
                        );
                        if (success) {
                          // 친구 차단 SnackBar 표시
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${user['user_nickname'] ?? user['user_id']}님을 차단했습니다',
                              ),
                              backgroundColor: Colors.black,
                              duration: Duration(seconds: 2),
                            ),
                          );
                          _searchUsers(); // 검색 결과 새로고침
                        } else {
                          // 실패 시 스낵바 표시
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('차단 처리 중 오류가 발생했습니다. 다시 시도해주세요.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        print('차단 처리 중 오류: $e');
                        // 오류 스낵바 표시
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('차단 처리 중 오류가 발생했습니다. 다시 시도해주세요.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
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
                          '친구 차단하기',
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
                      // 여기에 Center 위젯 추가
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(fontSize: 14),
                        textAlignVertical: TextAlignVertical.center, // 수직 중앙 정렬
                        decoration: InputDecoration(
                          hintText: '닉네임을 입력해주세요.',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                          border: InputBorder.none,
                          isDense: true, // 보다 조밀한 레이아웃
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 0, // 수직 패딩 제거
                          ),
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

          // 광고 플레이스홀더를 이미지로 대체
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

          // 탭바
          Container(
            width: MediaQuery.of(context).size.width, // 전체 화면 너비
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.red,
              indicatorSize: TabBarIndicatorSize.tab, // 탭 너비에 맞춤
              indicatorWeight: 3.0, // 인디케이터 두께
              labelPadding: EdgeInsets.zero, // 패딩 제거
              tabs: [
                Container(
                  width: MediaQuery.of(context).size.width / 2, // 화면 너비의 50%
                  child: const Tab(text: '검색 결과'),
                ),
                Container(
                  width: MediaQuery.of(context).size.width / 2, // 화면 너비의 50%
                  child: const Tab(text: '요청 알림'),
                ),
              ],
            ),
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
              trailing: IconButton(
                icon: Icon(Icons.more_vert),
                onPressed: () => _showUserOptions(user),
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
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_friendRequests.isEmpty) {
      return Center(child: Text('받은 친구 요청이 없습니다'));
    }

    return RefreshIndicator(
      onRefresh: _loadFriendRequests,
      child: ListView.builder(
        itemCount: _friendRequests.length,
        itemBuilder: (context, index) {
          final request = _friendRequests[index];

          return Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 4,
                ),
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
                subtitle: Text(
                  '친구 요청을 보냈습니다',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 거절 버튼 (테두리만 있는 버튼) - 크기 축소
                    Container(
                      width: 36, // 크기 축소
                      height: 36, // 크기 축소
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero, // 패딩 제거로 아이콘 위치 조정
                        icon: Icon(
                          Icons.close,
                          color: Colors.red,
                          size: 20,
                        ), // 아이콘 크기 유지
                        onPressed: () {
                          if (request.containsKey('request_id')) {
                            _rejectFriendRequest(request['request_id']);
                          }
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    // 수락 버튼 - 사람 + 아이콘 이미지로 변경 - 크기 축소
                    Container(
                      width: 36, // 크기 축소
                      height: 36, // 크기 축소
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero, // 패딩 제거
                        icon: Image.asset(
                          'assets/icons/person_add.png',
                          width: 24, // 아이콘 크기 유지
                          height: 24, // 아이콘 크기 유지
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
              ),
            ],
          );
        },
      ),
    );
  }
}
