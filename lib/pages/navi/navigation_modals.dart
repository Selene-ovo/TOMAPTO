import 'package:flutter/material.dart';
import 'dart:async';
import 'package:tomapto/controllers/map/transit_map_controller.dart';

class NavigationModals {
  static void showRecalculateModal({
    required BuildContext context,
    required VoidCallback onAccept,
    required VoidCallback onDecline,
    required TransitMode mode,
  }) {
    bool isModalShown = true;
    final Color mainColor = Color(0xFFFB233B);

    Timer? recalculateTimer = Timer(Duration(seconds: 5), () {
      if (isModalShown && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        onAccept();
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Timer.periodic(Duration(seconds: 1), (timer) {
              if (!isModalShown) {
                timer.cancel();
                return;
              }
              if (context.mounted) {
                setModalState(() {});
              }
            });

            return WillPopScope(
              onWillPop: () async => false,
              child: AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: mainColor),
                    SizedBox(width: 8),
                    Text(
                      '경로 이탈 감지',
                      style: TextStyle(
                        fontFamily: "Pretendard",
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF363636),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '현재 경로에서 벗어났습니다.\n새로운 경로로 재갱신하시겠습니까?',
                      style: TextStyle(
                        fontFamily: "Pretendard",
                        fontSize: 14,
                        color: Color(0xFF363636),
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            color: mainColor,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '5초 후 자동 재갱신',
                            style: TextStyle(
                              fontFamily: "Pretendard",
                              fontSize: 12,
                              color: mainColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            recalculateTimer?.cancel();
                            Navigator.of(context, rootNavigator: true).pop();
                            onDecline();
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey[400]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            '아니요',
                            style: TextStyle(
                              fontFamily: "Pretendard",
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            recalculateTimer?.cancel();
                            Navigator.of(context, rootNavigator: true).pop();
                            onAccept();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mainColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            '재갱신',
                            style: TextStyle(
                              fontFamily: "Pretendard",
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      isModalShown = false;
      recalculateTimer?.cancel();
    });
  }

  static void showMenuModal({
    required BuildContext context,
    required TransitMode mode,
    required String originName,
    required String destinationName,
    required String remainingDistance,
    required String remainingTime,
    required bool autoRecalculateEnabled,
    required Function(bool) onAutoRecalculateChanged,
    required VoidCallback onExitPressed,
  }) {
    final Color mainColor =
        mode == TransitMode.car ? Color(0xFFFB233B) : Color(0xFF0771EB);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '네비게이션 메뉴',
                            style: TextStyle(
                              fontFamily: "Pretendard",
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF363636),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: Colors.grey[200]),
                    Container(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          if (mode == TransitMode.car) ...[
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.auto_fix_high,
                                    color: mainColor,
                                    size: 20,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '경로 자동 재갱신',
                                          style: TextStyle(
                                            fontFamily: "Pretendard",
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF363636),
                                          ),
                                        ),
                                        Text(
                                          '경로 이탈 시 자동으로 새 경로를 찾습니다',
                                          style: TextStyle(
                                            fontFamily: "Pretendard",
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: autoRecalculateEnabled,
                                    onChanged: (value) {
                                      setModalState(() {});
                                      onAutoRecalculateChanged(value);
                                    },
                                    activeColor: mainColor,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16),
                          ],
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '현재 경로',
                                  style: TextStyle(
                                    fontFamily: "Pretendard",
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '$originName → $destinationName',
                                  style: TextStyle(
                                    fontFamily: "Pretendard",
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF363636),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      '남은 거리: $remainingDistance',
                                      style: TextStyle(
                                        fontFamily: "Pretendard",
                                        fontSize: 14,
                                        color: mainColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      ' • ',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    Text(
                                      '예상 시간: $remainingTime',
                                      style: TextStyle(
                                        fontFamily: "Pretendard",
                                        fontSize: 14,
                                        color: Color(0xFF363636),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                onExitPressed();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: mainColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.stop_circle_outlined, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    '안내 종료',
                                    style: TextStyle(
                                      fontFamily: "Pretendard",
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey[300]!),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                '취소',
                                style: TextStyle(
                                  fontFamily: "Pretendard",
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Color(0xFF363636),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static void showExitConfirmationDialog({
    required BuildContext context,
    required TransitMode mode,
    required VoidCallback onConfirm,
  }) {
    final Color mainColor =
        mode == TransitMode.car ? Color(0xFFFB233B) : Color(0xFF0771EB);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '안내 종료',
            style: TextStyle(
              fontFamily: "Pretendard",
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '네비게이션 안내를 종료하시겠습니까?',
            style: TextStyle(fontFamily: "Pretendard"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '취소',
                style: TextStyle(
                  fontFamily: "Pretendard",
                  color: Colors.grey[700],
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onConfirm();
              },
              child: Text(
                '종료',
                style: TextStyle(
                  fontFamily: "Pretendard",
                  color: mainColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static void showArrivalDialog({
    required BuildContext context,
    required TransitMode mode,
    required String destinationName,
  }) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              '목적지 도착',
              style: TextStyle(
                fontFamily: "Pretendard",
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              '목적지에 도착했습니다!',
              style: TextStyle(fontFamily: "Pretendard"),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  '확인',
                  style: TextStyle(
                    fontFamily: "Pretendard",
                    color:
                        mode == TransitMode.car
                            ? Color(0xFFFB233B)
                            : Color(0xFF0771EB),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  static void showLocationServiceDialog({
    required BuildContext context,
    required VoidCallback onCancel,
    required VoidCallback onOpenSettings,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '위치 서비스 비활성화',
            style: TextStyle(
              fontFamily: "Pretendard",
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '네비게이션을 사용하려면 위치 서비스를 활성화해야 합니다.',
            style: TextStyle(fontFamily: "Pretendard"),
          ),
          actions: [
            TextButton(
              onPressed: onCancel,
              child: Text(
                '취소',
                style: TextStyle(
                  fontFamily: "Pretendard",
                  color: Colors.grey[700],
                ),
              ),
            ),
            TextButton(
              onPressed: onOpenSettings,
              child: Text(
                '설정으로 이동',
                style: TextStyle(
                  fontFamily: "Pretendard",
                  color: Color(0xFFFB233B),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static void showPermissionDeniedDialog({
    required BuildContext context,
    required TransitMode mode,
    required VoidCallback onCancel,
    required VoidCallback onOpenSettings,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '위치 권한 필요',
            style: TextStyle(
              fontFamily: "Pretendard",
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '네비게이션을 사용하려면 위치 권한이 필요합니다.',
            style: TextStyle(fontFamily: "Pretendard"),
          ),
          actions: [
            TextButton(
              onPressed: onCancel,
              child: Text(
                '취소',
                style: TextStyle(
                  fontFamily: "Pretendard",
                  color: Colors.grey[700],
                ),
              ),
            ),
            TextButton(
              onPressed: onOpenSettings,
              child: Text(
                '설정으로 이동',
                style: TextStyle(
                  fontFamily: "Pretendard",
                  color:
                      mode == TransitMode.car
                          ? Color(0xFFFB233B)
                          : Color(0xFF0771EB),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
