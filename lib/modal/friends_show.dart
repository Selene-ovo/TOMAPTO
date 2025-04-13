import 'package:flutter/material.dart';
import 'package:tomapto/pages/real_time_location_sharing.dart';
import 'package:tomapto/services/location_service.dart';

class FriendsShowModal extends StatelessWidget {
  final Map<String, dynamic> friend;

  const FriendsShowModal({Key? key, required this.friend}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 프로필 사진과 이름
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.grey[200],
          child: Icon(Icons.person, size: 30, color: Colors.black),
        ),
        SizedBox(height: 10),
        Text(
          friend['name'],
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),
        Text(
          friend['isOnline'] ? '온라인' : '오프라인',
          style: TextStyle(
            fontSize: 14,
            color: friend['isOnline'] ? Colors.green : Colors.grey,
          ),
        ),
        SizedBox(height: 16),
        Divider(height: 1, thickness: 0.5, color: Colors.grey[300]),

        // 실시간 위치 공유 기능
        ListTile(
          leading: Icon(Icons.location_on, color: Colors.red),
          title: Text('실시간 위치 공유'),
          onTap: () {
            Navigator.pop(context);
            _startLocationSharing(context, friend);
          },
        ),

        // 친구와 관련된 기본 옵션들
        ListTile(
          leading: Icon(Icons.chat_bubble_outline, color: Colors.blue),
          title: Text('채팅하기'),
          onTap: () {
            Navigator.pop(context);
            // 채팅 기능 구현 (향후 개발)
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('채팅 기능은 준비 중입니다')));
          },
        ),

        ListTile(
          leading: Icon(Icons.block, color: Colors.red),
          title: Text('친구 차단'),
          onTap: () {
            Navigator.pop(context);
            // 차단 확인 대화상자 표시
            _showBlockConfirmation(context, friend);
          },
        ),

        ListTile(
          leading: Icon(Icons.person_remove, color: Colors.grey),
          title: Text('친구 삭제'),
          onTap: () {
            Navigator.pop(context);
            // 삭제 확인 대화상자 표시
            _showDeleteConfirmation(context, friend);
          },
        ),
      ],
    );
  }

  // 위치 공유 시작 함수
  Future<void> _startLocationSharing(
    BuildContext context,
    Map<String, dynamic> friend,
  ) async {
    // 먼저 위치 권한 확인
    bool locationPermissionGranted =
        await LocationService.checkLocationPermission();

    if (!locationPermissionGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('위치 권한이 필요합니다. 설정에서 위치 권한을 활성화해주세요.')),
      );
      return;
    }

    // 위치 공유 시간 선택 대화상자 표시
    _showDurationSelectionDialog(context, friend);
  }

  // 위치 공유 시간 선택 대화상자
  void _showDurationSelectionDialog(
    BuildContext context,
    Map<String, dynamic> friend,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('위치 공유 시간 선택'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${friend['name']}님과 얼마나 오래 위치를 공유하시겠습니까?'),
                SizedBox(height: 16),
                _buildDurationOption(context, friend, 30, '30분'),
                _buildDurationOption(context, friend, 60, '1시간'),
                _buildDurationOption(context, friend, 120, '2시간'),
                _buildDurationOption(context, friend, 0, '계속 공유'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('취소'),
              ),
            ],
          ),
    );
  }

  // 위치 공유 시간 옵션 위젯
  Widget _buildDurationOption(
    BuildContext context,
    Map<String, dynamic> friend,
    int durationMinutes,
    String durationText,
  ) {
    return ListTile(
      title: Text(durationText),
      onTap: () async {
        Navigator.pop(context); // 대화상자 닫기

        // 로딩 표시
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(child: CircularProgressIndicator()),
        );

        try {
          // 무제한 공유인 경우 durationMinutes를 null로 설정
          int? duration = durationMinutes > 0 ? durationMinutes : null;

          print('위치 공유 요청 시작: 친구 ID=${friend['id']}, 기간=$duration');

          // 위치 공유 요청
          bool success = await LocationService.requestLocationSharing(
            friend['id'],
            durationMinutes: duration,
          );

          // 로딩 대화상자 닫기
          Navigator.pop(context);

          print('위치 공유 요청 결과: $success');

          if (success) {
            // 위치 공유 페이지로 이동
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        RealTimeLocationSharingPage(selectedFriend: friend),
              ),
            );
          } else {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('위치 공유를 시작할 수 없습니다.')));
          }
        } catch (e) {
          // 오류 발생 시 로딩 대화상자 닫기
          Navigator.pop(context);
          print('위치 공유 요청 중 오류: $e');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
        }
      },
    );
  }

  // 친구 차단 확인 대화상자
  void _showBlockConfirmation(
    BuildContext context,
    Map<String, dynamic> friend,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('친구 차단'),
            content: Text('${friend['name']}님을 차단하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('취소'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // 실제 차단 로직 구현
                  print('${friend['name']}님이 차단되었습니다.');
                  // 상태 업데이트 등 추가 작업
                },
                child: Text('차단', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  // 친구 삭제 확인 대화상자
  void _showDeleteConfirmation(
    BuildContext context,
    Map<String, dynamic> friend,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('친구 삭제'),
            content: Text('${friend['name']}님을 친구 목록에서 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('취소'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // 실제 삭제 로직 구현
                  print('${friend['name']}님이 삭제되었습니다.');
                },
                child: Text('삭제', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }
}
