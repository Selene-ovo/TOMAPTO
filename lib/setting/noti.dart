// noti.dart 파일 수정
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

// main 함수와 notiPage 클래스 제거 - 직접 실행할 필요 없음
// NotificationSettingsScreen만 유지

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _calendarNotification = true;
  bool _officialNotification = false;
  bool _promotionNotification = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '알림',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 2),
          _buildNotificationItem(
            title: '캘린더 알림',
            value: _calendarNotification,
            onChanged: (bool value) {
              setState(() {
                _calendarNotification = value;
              });
            },
          ),
          const SizedBox(height: 1),
          _buildNotificationItem(
            title: '공지사항 알림',
            value: _officialNotification,
            onChanged: (bool value) {
              setState(() {
                _officialNotification = value;
              });
            },
          ),
          const SizedBox(height: 1),
          _buildNotificationItem(
            title: '홍보성 정보 수신 동의',
            value: _promotionNotification,
            onChanged: (bool value) {
              setState(() {
                _promotionNotification = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.red,
          ),
        ],
      ),
    );
  }
}