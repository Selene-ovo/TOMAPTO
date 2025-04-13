import 'package:flutter/material.dart';
import 'package:tomapto/widgets/ad_placeholder.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;
import 'package:tomapto/modal/friends_modal_connection.dart';
import 'package:tomapto/modal/friends_show.dart';
import 'package:tomapto/pages/real_time_location_sharing.dart';

class FriendScreen extends StatefulWidget {
  @override
  _FriendScreenState createState() => _FriendScreenState();
}

class _FriendScreenState extends State<FriendScreen> {
  // 친구 데이터 - 새 디자인에 맞춰 업데이트
  List<Map<String, dynamic>> friends = [
    {'id': '1', 'name': '원종호', 'isOnline': true},
    {'id': '2', 'name': '김중호', 'isOnline': true},
    {'id': '3', 'name': '심종완', 'isOnline': true},
    {'id': '4', 'name': '하수용', 'isOnline': false},
    {'id': '5', 'name': '황중혁', 'isOnline': true},
  ];

  // 검색어 컨트롤러
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // 서버에서 친구 목록 가져오기
    _fetchFriendsFromServer().then((_) {
      // 서버 연결 실패 시 로컬 데이터 유지
      if (friends.isEmpty) {
        setState(() {
          friends = [
            {'id': '1', 'name': '원종호', 'isOnline': true},
            {'id': '2', 'name': '김중호', 'isOnline': true},
            {'id': '3', 'name': '심종완', 'isOnline': true},
            {'id': '4', 'name': '하수용', 'isOnline': false},
            {'id': '5', 'name': '황중혁', 'isOnline': true},
          ];
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // API 서버 기본 URL 가져오기
  String _getApiBaseUrl() {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/api';
    // Android 플랫폼이면서 URL이 localhost를 포함하는 경우
    if (Platform.isAndroid && baseUrl.contains('localhost')) {
      // 에뮬레이터에서는 10.0.2.2로 localhost 대체
      return baseUrl.replaceAll('localhost', '10.0.2.2');
    }
    // 다른 플랫폼이거나 이미 localhost가 아닌 경우 원래 URL 반환
    return baseUrl;
  }

  // 서버에서 친구 목록 가져오기
  Future<void> _fetchFriendsFromServer() async {
    try {
      // SharedPreferences에서 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('로그인이 필요합니다');
        return;
      }

      // API 호출
      final apiBaseUrl = _getApiBaseUrl();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/friends/list'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          // 서버에서 받은 친구 목록으로 업데이트
          friends = List<Map<String, dynamic>>.from(data['friends']);
        });
      } else {
        print('친구 목록 불러오기 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('친구 목록 불러오기 오류: $e');
      // 오류 발생 시 로컬 데이터 유지 (변경하지 않음)
    }
  }

  // 친구 검색
  void _searchFriends(String query) {
    if (query.isEmpty) {
      _fetchFriendsFromServer(); // 검색어가 없으면 서버에서 다시 불러오기
      return;
    }

    // 로컬 필터링 (이름에 검색어 포함된 친구만 표시)
    final List<Map<String, dynamic>> filteredFriends =
        friends
            .where(
              (friend) => friend['name'].toString().toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList();

    setState(() {
      friends = filteredFriends;
    });
  }

  // 친구 데이터 유효성 확인 (확장 메서드 대신 일반 함수 사용)
  Map<String, dynamic> _ensureValidFriend(Map<String, dynamic> friend) {
    // ID가 없는 경우 임의 ID 부여
    if (!friend.containsKey('id')) {
      friend['id'] =
          friend['name']?.toString().hashCode.toString() ?? 'unknown';
    }

    // isOnline 필드가 없는 경우 기본값 false 부여
    if (!friend.containsKey('isOnline')) {
      friend['isOnline'] = false;
    }

    return friend;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '친구',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true, // 제목 중앙 정렬
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () {
            // 메뉴 기능
            print('메뉴 버튼 클릭됨');
          },
        ),
        // 오른쪽 돋보기 아이콘 제거
      ),
      body: Column(
        children: [
          // 검색창과 돋보기를 별도의 Row로 배치하여 돋보기를 밖으로 이동
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 56.0,
              vertical: 10.0,
            ),
            child: Row(
              children: [
                // 검색창 (돋보기 없이)
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
                        style: TextStyle(fontSize: 10),
                        decoration: InputDecoration(
                          hintText: '닉네임을 입력해주세요.',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 11),
                        ),
                        onChanged: _searchFriends,
                        onSubmitted: _searchFriends,
                      ),
                    ),
                  ),
                ),

                // 회색 원 밖에 있는 돋보기 아이콘
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Container(
                    width: 15,
                    height: 42,
                    decoration: BoxDecoration(shape: BoxShape.circle),
                    child: InkWell(
                      onTap: () {
                        _searchFriends(_searchController.text);
                      },
                      child: Icon(Icons.search, color: Colors.black, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 광고 플레이스홀더 (기존 스타일 유지)
          AdPlaceholder(),
          SizedBox(height: 5),
          // 빨간색 선 위에 친구 목록 텍스트 위치
          Container(
            width: double.infinity,
            color: Colors.white,
            child: Column(
              children: [
                // 친구 목록 타이틀
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Center(
                    child: Text(
                      '친구 목록',
                      style: TextStyle(
                        fontWeight: FontWeight.w900, // 더 굵게 수정
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                // 빨간색 선 - 더 얇게 수정
                Container(height: 3, color: Colors.red), // 2px → 1px
              ],
            ),
          ),

          // 친구 목록
          Expanded(
            child:
                friends.isEmpty
                    ? Center(child: Text('친구가 없습니다.'))
                    : ListView.builder(
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        // 확장 메서드 대신 일반 함수 사용
                        final validFriend = _ensureValidFriend(
                          Map<String, dynamic>.from(friend),
                        );

                        return Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 25,
                                vertical: 4,
                              ),
                              leading: Stack(
                                children: [
                                  // 흰색 네모 프로필 (회색 원 대신)
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                        width: 0.5, // 더 얇은 테두리
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      color: const Color.fromARGB(255, 0, 0, 0),
                                      size: 30,
                                    ),
                                  ),
                                  // 상태 표시 아이콘을 오른쪽 위로 이동
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color:
                                            validFriend['isOnline']
                                                ? Colors.green
                                                : Colors.red,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1, // 더 얇은 테두리
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              title: Text(
                                validFriend['name'],
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.more_vert,
                                  color: const Color.fromARGB(255, 0, 0, 0),
                                ),
                                onPressed: () {
                                  // 더 보기 메뉴 - 확장 메서드 대신 일반 함수 사용
                                  print(
                                    'More options for ${validFriend['name']}',
                                  );
                                  showFriendProfile(context, validFriend);
                                },
                              ),
                              onTap: () {
                                // 친구 선택 시 - 확장 메서드 대신 일반 함수 사용
                                print('Tapped on ${validFriend['name']}');
                                showFriendProfile(context, validFriend);
                              },
                            ),
                            // 줄바꿈 구분선 (모든 항목 아래 표시) - 더 얇게 수정
                            Divider(
                              height: 1,
                              thickness: 0.5, // 더 얇은 구분선
                              color: Colors.grey[300],
                            ),
                          ],
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
