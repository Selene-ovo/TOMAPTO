import 'package:flutter/material.dart';

class TransitOptionWidget extends StatelessWidget {
  final int index;
  final int selectedIndex;
  final IconData icon;
  final String label;
  final Function(int) onTap;
  final double iconSize;

  const TransitOptionWidget({
    super.key,
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconSize = 28.0,
  });

  @override
  Widget build(BuildContext context) {
    // 텍스트 크기는 아이콘 크기에 비례하게 조정
    final double textSize = iconSize * 0.42;

    // 선택된 탭에 따라 색상 설정
    Color iconColor;
    if (selectedIndex == index) {
      iconColor = Color(0xFFFB233B);
    } else {
      iconColor = Colors.grey;
    }

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: iconSize * 0.42),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: iconSize),
              SizedBox(height: iconSize * 0.14),
              Text(
                label,
                style: TextStyle(color: iconColor, fontSize: textSize),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
