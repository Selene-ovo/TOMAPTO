import 'package:flutter/material.dart';
import 'package:tomapto/modal/friends_show.dart';

// 친구 목록에서 친구를 선택했을 때 호출되는 함수
void showFriendOptions(BuildContext context, Map<String, dynamic> friend) {
  // 친구 모달 표시
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(child: FriendsShowModal(friend: friend)),
      );
    },
  );
}

// friends_list_screen.dart에서 사용할 확장 기능
extension FriendListExtension on Map<String, dynamic> {
  // 친구 객체에 대한 필수 필드 확인 및 기본값 제공
  Map<String, dynamic> ensureValidFriend() {
    // ID가 없는 경우 임의 ID 부여
    if (!this.containsKey('id')) {
      this['id'] = this['name']?.toString().hashCode.toString() ?? 'unknown';
    }

    // isOnline 필드가 없는 경우 기본값 false 부여
    if (!this.containsKey('isOnline')) {
      this['isOnline'] = false;
    }

    return this;
  }
}
