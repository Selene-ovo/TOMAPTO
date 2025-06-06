import 'package:flutter/material.dart';
import 'package:tomapto/controllers/map/transit_map_controller.dart';

class RouteHeaderWidget extends StatelessWidget {
  final String originName;
  final String destinationName;

  const RouteHeaderWidget({
    Key? key,
    required this.originName,
    required this.destinationName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$originName → $destinationName',
                  style: TextStyle(
                    fontFamily: "Pretendard",
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF363636),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TurnByTurnWidget extends StatelessWidget {
  final Map<String, dynamic> currentInstruction;
  final String currentRoadName;
  final Color mainColor;

  const TurnByTurnWidget({
    Key? key,
    required this.currentInstruction,
    required this.currentRoadName,
    required this.mainColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 턴바이턴 instruction의 도로명을 우선으로 사용
    String displayRoadName = '';

    final instructionRoadName = currentInstruction['roadName']?.toString();
    if (instructionRoadName != null &&
        instructionRoadName.isNotEmpty &&
        instructionRoadName != '도로 안내' &&
        instructionRoadName != '도로' &&
        !instructionRoadName.endsWith('구간')) {
      displayRoadName = instructionRoadName;
    } else if (currentRoadName.isNotEmpty &&
        currentRoadName != '도로 확인 중...' &&
        currentRoadName != '현재 도로' &&
        currentRoadName != '도로') {
      displayRoadName = currentRoadName;
    } else {
      displayRoadName = '도로 안내';
    }

    return Positioned(
      top: 140,
      left: 20,
      child: Container(
        decoration: BoxDecoration(
          color: mainColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(
              currentInstruction['icon'] as IconData? ??
                  currentInstruction['directionIcon'] as IconData? ??
                  Icons.arrow_upward_rounded,
              color: Colors.white,
              size: 40,
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${currentInstruction['distanceToPoint'] ?? currentInstruction['distance'] ?? 0}m',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  constraints: BoxConstraints(maxWidth: 200),
                  child: Text(
                    displayRoadName,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class NextTurnWidget extends StatelessWidget {
  final Map<String, dynamic> nextInstruction;

  const NextTurnWidget({Key? key, required this.nextInstruction})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 245,
      left: 20,
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFF2F80ED),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(
              nextInstruction['directionIcon'] as IconData? ??
                  Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 24,
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${nextInstruction['distanceToPoint'] ?? nextInstruction['distance'] ?? 0}m',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Container(
                  constraints: BoxConstraints(maxWidth: 150),
                  child: Text(
                    nextInstruction['roadName']?.toString() ?? '도로',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SpeedLimitWidget extends StatelessWidget {
  final double currentSpeed;
  final int speedLimit;
  final Map<String, dynamic>? currentInstruction;
  final bool isInSpeedLimitZone;

  const SpeedLimitWidget({
    Key? key,
    required this.currentSpeed,
    required this.speedLimit,
    this.currentInstruction,
    this.isInSpeedLimitZone = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 220,
      left: 20,
      child: Column(
        children: [
          Container(
            width: 100,
            height: 60,
            alignment: Alignment.center,
            child: Stack(
              children: [
                if (currentSpeed > speedLimit)
                  Text(
                    '${currentSpeed.toInt()}',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      foreground:
                          Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 8
                            ..color = Colors.red,
                    ),
                  ),
                if (currentSpeed <= speedLimit)
                  Text(
                    '${currentSpeed.toInt()}',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      foreground:
                          Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 8
                            ..color = Colors.black,
                    ),
                  ),
                Text(
                  '${currentSpeed.toInt()}',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 15),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    currentSpeed > speedLimit ? Colors.red : Colors.grey[600]!,
                width: 5,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 5),
              ],
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 8,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 1),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: speedLimit > 30 ? Colors.orange : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 1),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: speedLimit > 60 ? Colors.red : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '$speedLimit',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color:
                        currentSpeed > speedLimit ? Colors.red : Colors.black,
                  ),
                ),
              ],
            ),
          ),
          if (isInSpeedLimitZone) ...[
            SizedBox(height: 10),
            Container(
              width: 80,
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: currentInstruction != null ? Colors.red : Colors.grey,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                currentInstruction != null
                    ? '${currentInstruction!['distanceToPoint'] ?? currentInstruction!['distance'] ?? 0}m'
                    : '0m',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class NavigationInfoWidget extends StatelessWidget {
  final bool isPathDisplayed;
  final String remainingDistance;
  final String remainingTime;
  final Color mainColor;

  const NavigationInfoWidget({
    Key? key,
    required this.isPathDisplayed,
    required this.remainingDistance,
    required this.remainingTime,
    required this.mainColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPathDisplayed) ...[
                Text(
                  remainingDistance,
                  style: TextStyle(
                    fontFamily: "Pretendard",
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: mainColor,
                  ),
                ),
                Text(
                  ' • ',
                  style: TextStyle(
                    fontFamily: "Pretendard",
                    fontSize: 14,
                    color: Color(0xFF000000),
                  ),
                ),
                Text(
                  remainingTime,
                  style: TextStyle(
                    fontFamily: "Pretendard",
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF000000),
                  ),
                ),
              ],
              if (!isPathDisplayed)
                Text(
                  '경로 로딩 중...',
                  style: TextStyle(
                    fontFamily: "Pretendard",
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF000000),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AutoRecalculateDisabledWidget extends StatelessWidget {
  final VoidCallback onRenable;

  const AutoRecalculateDisabledWidget({Key? key, required this.onRenable})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 80,
      left: 20,
      right: 20,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '경로 자동 재갱신이 비활성화되었습니다',
                style: TextStyle(
                  fontFamily: "Pretendard",
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            TextButton(
              onPressed: onRenable,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size(0, 0),
              ),
              child: Text(
                '활성화',
                style: TextStyle(
                  fontFamily: "Pretendard",
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NavigationControlButtons extends StatelessWidget {
  final Color mainColor;
  final VoidCallback onMenuPressed;
  final VoidCallback onLocationPressed;

  const NavigationControlButtons({
    Key? key,
    required this.mainColor,
    required this.onMenuPressed,
    required this.onLocationPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          bottom: 110,
          right: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onMenuPressed,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle),
                  child: Icon(Icons.menu_rounded, color: mainColor, size: 24),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 60,
          right: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onLocationPressed,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle),
                  child: Icon(
                    Icons.my_location_rounded,
                    color: mainColor,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
