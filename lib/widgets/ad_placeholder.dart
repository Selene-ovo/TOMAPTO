import 'package:flutter/material.dart';

class AdPlaceholder extends StatelessWidget {
  const AdPlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8),
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.grey[100],
      height: 50,
      width: double.infinity,
      child: Stack(
        children: [
          // 중앙 광고 콘텐츠
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.ad_units, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Google AdSense',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),

          // 오른쪽 하단에 "광고" 텍스트
          Positioned(
            bottom: 2,
            right: 4,
            child: Text(
              '광고',
              style: TextStyle(color: Colors.grey[600], fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
