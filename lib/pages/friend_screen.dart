import 'package:flutter/material.dart';

class FriendScreen extends StatefulWidget {
  @override
  _FriendScreenState createState() => _FriendScreenState();
}

class _FriendScreenState extends State<FriendScreen> {
  // 친구 데이터 - 새 디자인에 맞춰 업데이트
  final List<Map<String, dynamic>> friends = [
    {'name': '원종호', 'isOnline': true},
    {'name': '김종호', 'isOnline': true},
    {'name': '심종완', 'isOnline': true},
    {'name': '하수용', 'isOnline': false},
    {'name': '황중혁', 'isOnline': true},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '친구',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.black),
            onPressed: () {
              // 검색 기능
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 검색창
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: '닉네임을 입력해주세요.',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // 광고 배너 (플레이스홀더)
          Container(
            padding: EdgeInsets.all(8),
            margin: EdgeInsets.symmetric(vertical: 8),
            color: Colors.grey[100],
            height: 50,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/ad_icon.png',
                  width: 24,
                  height: 24,
                  errorBuilder:
                      (context, error, stackTrace) =>
                          Icon(Icons.ad_units, color: Colors.blue),
                ),
                SizedBox(width: 8),
                Text(
                  'Google AdSense',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),

          // 친구 목록 타이틀
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.red, width: 2),
                bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            child: Text('친구 목록', style: TextStyle(fontWeight: FontWeight.bold)),
          ),

          // 친구 목록
          Expanded(
            child: ListView.separated(
              itemCount: friends.length,
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                final friend = friends[index];
                return ListTile(
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.grey[300],
                        child: Icon(Icons.person, color: Colors.grey[700]),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color:
                                friend['isOnline'] ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    friend['name'],
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.more_vert),
                    onPressed: () {
                      // 더 보기 메뉴
                    },
                  ),
                  onTap: () {
                    // 친구 상세 정보 보기
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
