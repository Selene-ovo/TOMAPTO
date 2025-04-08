import 'package:flutter/material.dart';

class FriendScreen extends StatefulWidget {
  @override
  _FriendScreenState createState() => _FriendScreenState();
}

class _FriendScreenState extends State<FriendScreen> {
  // 임시 친구 데이터 (실제로는 API나 DB에서 가져옴)
  final List<Map<String, dynamic>> friends = [
    {
      'name': '하수용용',
      'avatar': 'assets/images/profile1.png',
      'distance': '0.5km',
      'lastUpdated': '1분 전',
      'isSharing': true,
    },
    {
      'name': '심종완완',
      'avatar': 'assets/images/profile2.png',
      'distance': '1.2km',
      'lastUpdated': '5분 전',
      'isSharing': true,
    },
    {
      'name': '황중혁혁',
      'avatar': 'assets/images/profile3.png',
      'distance': '3.7km',
      'lastUpdated': '30분 전',
      'isSharing': true,
    },
    {
      'name': '원종호',
      'avatar': 'assets/images/profile4.png',
      'distance': '오프라인',
      'lastUpdated': '1시간 전',
      'isSharing': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('친구 위치'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              // 위치 새로고침 로직
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('위치 정보를 새로고침했습니다')));
            },
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              // 설정 화면 이동 로직
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 내 위치 공유 상태 카드
          _buildMyLocationCard(),

          // 구분선
          Divider(thickness: 1),

          // 친구 위치 목록 헤더
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '내 근처 친구',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text('${friends.where((f) => f['isSharing']).length}명 온라인'),
              ],
            ),
          ),

          // 친구 목록
          Expanded(
            child: ListView.builder(
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friend = friends[index];
                return _buildFriendItem(friend);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 지도 전체 화면으로 보기
          _showMapFullScreen(context);
        },
        child: Icon(Icons.map),
        tooltip: '지도로 보기',
      ),
    );
  }

  Widget _buildMyLocationCard() {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.person, color: Colors.white, size: 30),
                ),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '나의 위치',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '서울시 강남구 테헤란로',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
                Spacer(),
                Switch(
                  value: true,
                  onChanged: (value) {
                    // 위치 공유 토글 로직
                    setState(() {
                      // 위치 공유 상태 변경
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(Icons.map, size: 50, color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendItem(Map<String, dynamic> friend) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: friend['isSharing'] ? Colors.green : Colors.grey,
        child: Text(friend['name'].substring(0, 1)),
      ),
      title: Text(friend['name']),
      subtitle: Text('${friend['distance']} • ${friend['lastUpdated']}'),
      trailing: IconButton(
        icon: Icon(Icons.navigation),
        onPressed:
            friend['isSharing']
                ? () {
                  // 길찾기 로직
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${friend['name']}님에게 가는 길을 안내합니다')),
                  );
                }
                : null,
        color: friend['isSharing'] ? Colors.blue : Colors.grey,
      ),
      onTap: () {
        // 친구 상세 정보 화면으로 이동
        if (friend['isSharing']) {
          _showFriendDetail(context, friend);
        }
      },
    );
  }

  void _showFriendDetail(BuildContext context, Map<String, dynamic> friend) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    child: Text(friend['name'].substring(0, 1)),
                  ),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend['name'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${friend['distance']} 떨어져 있음',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(Icons.map, size: 50, color: Colors.grey[700]),
                ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.message),
                    label: Text('메시지 보내기'),
                    onPressed: () {
                      Navigator.pop(context);
                      // 메시지 보내기 로직
                    },
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.navigation),
                    label: Text('길찾기'),
                    onPressed: () {
                      Navigator.pop(context);
                      // 길찾기 로직
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMapFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              appBar: AppBar(title: Text('친구 위치 지도')),
              body: Stack(
                children: [
                  // 지도가 들어갈 자리 (실제로는 Google Maps 또는 다른 지도 API 사용)
                  Container(
                    color: Colors.grey[300],
                    child: Center(
                      child: Icon(
                        Icons.map,
                        size: 100,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),

                  // 친구 목록 패널
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 120,
                      padding: EdgeInsets.symmetric(vertical: 8),
                      color: Colors.white,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: friends.where((f) => f['isSharing']).length,
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final onlineFriends =
                              friends.where((f) => f['isSharing']).toList();
                          return Container(
                            width: 100,
                            margin: EdgeInsets.only(right: 12),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  child: Text(
                                    onlineFriends[index]['name'].substring(
                                      0,
                                      1,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  onlineFriends[index]['name'],
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  onlineFriends[index]['distance'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
