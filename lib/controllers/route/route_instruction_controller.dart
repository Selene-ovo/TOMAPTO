import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'dart:math';

class TurnByTurnInstruction {
  final int type;
  final String instruction;
  final NLatLng position;
  final int distance;
  final int duration;
  final IconData iconData;
  final String directionText;
  final String roadName;
  final int pointIndex;

  TurnByTurnInstruction({
    required this.type,
    required this.instruction,
    required this.position,
    required this.distance,
    required this.duration,
    required this.iconData,
    required this.directionText,
    required this.roadName,
    this.pointIndex = 0,
  });

  static TurnByTurnInstruction? fromNaverGuide(
    Map<String, dynamic> guide,
    List<NLatLng> pathCoordinates,
  ) {
    try {
      final int guideType = (guide['type'] as num?)?.toInt() ?? 0;
      final String instructions =
          guide['instructions']?.toString() ??
          guide['guidance']?.toString() ??
          guide['description']?.toString() ??
          '직진';

      final int distance = (guide['distance'] as num?)?.toInt() ?? 0;
      final int duration =
          (guide['duration'] as num?)?.toInt() ??
          (guide['time'] as num?)?.toInt() ??
          0;

      // 도로명 추출 우선순위: instruction 텍스트 > API 필드
      final String roadName =
          _extractRoadNameFromInstruction(instructions) ??
          _extractBestRoadName(guide);

      NLatLng position;
      if (guide['x'] != null && guide['y'] != null) {
        final double x = (guide['x'] as num).toDouble();
        final double y = (guide['y'] as num).toDouble();
        position = NLatLng(y, x);
      } else if (guide['lng'] != null && guide['lat'] != null) {
        final double lng = (guide['lng'] as num).toDouble();
        final double lat = (guide['lat'] as num).toDouble();
        position = NLatLng(lat, lng);
      } else if (guide['longitude'] != null && guide['latitude'] != null) {
        final double longitude = (guide['longitude'] as num).toDouble();
        final double latitude = (guide['latitude'] as num).toDouble();
        position = NLatLng(latitude, longitude);
      } else {
        final int pointIndex = (guide['pointIndex'] as num?)?.toInt() ?? 0;
        if (pointIndex < pathCoordinates.length) {
          position = pathCoordinates[pointIndex];
        } else if (pathCoordinates.isNotEmpty) {
          position = pathCoordinates.first;
        } else {
          return null;
        }
      }

      int pointIndex = 0;
      if (pathCoordinates.isNotEmpty) {
        double minDistance = double.infinity;
        for (int i = 0; i < pathCoordinates.length; i++) {
          final double dist = _calculateDistance(position, pathCoordinates[i]);
          if (dist < minDistance) {
            minDistance = dist;
            pointIndex = i;
          }
        }
      }

      final iconAndText = analyzeInstructionText(instructions);

      return TurnByTurnInstruction(
        type: guideType,
        instruction: instructions,
        position: position,
        distance: distance,
        duration: duration,
        iconData: iconAndText['icon'],
        directionText: iconAndText['text'],
        roadName: roadName,
        pointIndex: pointIndex,
      );
    } catch (e) {
      return null;
    }
  }

  // instruction 텍스트에서 도로명 추출
  static String? _extractRoadNameFromInstruction(String instruction) {
    // '경강로' 방면으로 좌회전 패턴
    final directionPattern = RegExp(r"'([^']+)'\s*방면");
    final directionMatch = directionPattern.firstMatch(instruction);
    if (directionMatch != null) {
      final roadName = directionMatch.group(1)!;
      if (_isValidRoadName(roadName)) {
        return roadName;
      }
    }

    // "경강로로" 또는 "경강로에서" 패턴
    final roadPattern = RegExp(r'([가-힣\w]+(?:로|길|대로|가|동|리))[로에서으로를]+');
    final roadMatch = roadPattern.firstMatch(instruction);
    if (roadMatch != null) {
      final roadName = roadMatch.group(1)!;
      if (_isValidRoadName(roadName)) {
        return roadName;
      }
    }

    // 기본 한글 도로명 패턴 (2글자 이상)
    final basicPattern = RegExp(r'([가-힣]{2,}(?:로|길|대로|도로|가|동|리))');
    final basicMatch = basicPattern.firstMatch(instruction);
    if (basicMatch != null) {
      final roadName = basicMatch.group(1)!;
      if (_isValidRoadName(roadName)) {
        return roadName;
      }
    }

    return null;
  }

  // 유효한 도로명인지 확인
  static bool _isValidRoadName(String roadName) {
    if (roadName.length < 2) return false;

    // 제외할 단어들
    const excludeWords = [
      '방면',
      '방향',
      '사거리',
      '교차로',
      '고가교',
      '지하차도',
      '터널',
      '다리',
      '교량',
      '출구',
      '진입',
      '나가기',
      '합류',
    ];

    for (String word in excludeWords) {
      if (roadName.contains(word)) return false;
    }

    return true;
  }

  static double _calculateDistance(NLatLng point1, NLatLng point2) {
    const double earthRadius = 6371000;
    final double lat1 = point1.latitude * (pi / 180);
    final double lat2 = point2.latitude * (pi / 180);
    final double dLat = (point2.latitude - point1.latitude) * (pi / 180);
    final double dLon = (point2.longitude - point1.longitude) * (pi / 180);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  static Map<String, dynamic> getIconAndTextFromNaverGuideType(
    int type,
    String instruction,
  ) {
    final instructionAnalysis = analyzeInstructionText(instruction);

    switch (type) {
      case 6:
        return {'icon': Icons.merge_rounded, 'text': '고속도로 진입'};
      case 7:
        return {'icon': Icons.exit_to_app_rounded, 'text': '고속도로 나가기'};
      case 8:
        return {'icon': Icons.merge_rounded, 'text': '왼쪽 고속도로 진입'};
      case 9:
        return {'icon': Icons.merge_rounded, 'text': '오른쪽 고속도로 진입'};
      case 10:
        return {'icon': Icons.exit_to_app_rounded, 'text': '왼쪽 고속도로 나가기'};
      case 11:
        return {'icon': Icons.exit_to_app_rounded, 'text': '오른쪽 고속도로 나가기'};
      case 12:
        return {'icon': Icons.arrow_upward_rounded, 'text': '고속도로 계속'};
      case 14:
        return {'icon': Icons.traffic_rounded, 'text': '터널 진입'};
      case 15:
        return {'icon': Icons.location_city_rounded, 'text': '다리'};
      case 16:
        return {'icon': Icons.keyboard_arrow_down_rounded, 'text': '지하차도'};
      case 29:
        return {'icon': Icons.location_on_rounded, 'text': '목적지 도착'};
      default:
        if (type >= 17 && type <= 28) {
          final clockPosition = type - 16;
          return {
            'icon': Icons.roundabout_right_rounded,
            'text': '로터리 ${clockPosition}시 방향',
          };
        }
        return instructionAnalysis;
    }
  }

  static Map<String, dynamic> analyzeInstructionText(String instruction) {
    final lowerInstruction = instruction.toLowerCase();

    if (lowerInstruction.contains('좌회전') ||
        lowerInstruction.contains('왼쪽으로 회전') ||
        lowerInstruction.contains('left turn') ||
        (lowerInstruction.contains('왼쪽') && lowerInstruction.contains('회전'))) {
      return {'icon': Icons.turn_left_rounded, 'text': '좌회전'};
    }

    if (lowerInstruction.contains('우회전') ||
        lowerInstruction.contains('오른쪽으로 회전') ||
        lowerInstruction.contains('right turn') ||
        (lowerInstruction.contains('오른쪽') && lowerInstruction.contains('회전'))) {
      return {'icon': Icons.turn_right_rounded, 'text': '우회전'};
    }

    if (lowerInstruction.contains('유턴') ||
        lowerInstruction.contains('u턴') ||
        lowerInstruction.contains('u-turn')) {
      return {'icon': Icons.u_turn_left_rounded, 'text': 'U턴'};
    }

    if (lowerInstruction.contains('왼쪽') ||
        lowerInstruction.contains('좌측') ||
        lowerInstruction.contains('left')) {
      return {'icon': Icons.turn_slight_left_rounded, 'text': '왼쪽 방향'};
    }

    if (lowerInstruction.contains('오른쪽') ||
        lowerInstruction.contains('우측') ||
        lowerInstruction.contains('right')) {
      return {'icon': Icons.turn_slight_right_rounded, 'text': '오른쪽 방향'};
    }

    if (lowerInstruction.contains('직진') ||
        lowerInstruction.contains('계속') ||
        lowerInstruction.contains('straight')) {
      return {'icon': Icons.arrow_upward_rounded, 'text': '직진'};
    }

    if (lowerInstruction.contains('진입') ||
        lowerInstruction.contains('합류') ||
        lowerInstruction.contains('고가차도')) {
      return {'icon': Icons.merge_rounded, 'text': '진입'};
    }

    if (lowerInstruction.contains('나가기') || lowerInstruction.contains('출구')) {
      return {'icon': Icons.exit_to_app_rounded, 'text': '나가기'};
    }

    if (lowerInstruction.contains('목적지') || lowerInstruction.contains('도착')) {
      return {'icon': Icons.location_on_rounded, 'text': '목적지 도착'};
    }

    if (lowerInstruction.contains('회전교차로') ||
        lowerInstruction.contains('로터리')) {
      return {'icon': Icons.roundabout_right_rounded, 'text': '회전교차로'};
    }

    final timePattern = RegExp(r'(\d+)시\s*방향');
    final timeMatch = timePattern.firstMatch(lowerInstruction);
    if (timeMatch != null) {
      final hour = timeMatch.group(1)!;
      return {'icon': Icons.roundabout_right_rounded, 'text': '${hour}시 방향'};
    }

    return {'icon': Icons.arrow_upward_rounded, 'text': '직진'};
  }

  static String _extractBestRoadName(Map<String, dynamic> guide) {
    List<String> roadNameCandidates = [
      guide['name']?.toString() ?? '',
      guide['roadName']?.toString() ?? '',
      guide['streetName']?.toString() ?? '',
      guide['road']?.toString() ?? '',
      guide['street']?.toString() ?? '',
    ];

    for (String candidate in roadNameCandidates) {
      String cleanName = _cleanRoadName(candidate);
      if (cleanName.isNotEmpty) {
        return cleanName;
      }
    }

    return '도로 안내';
  }

  static String _cleanRoadName(String rawName) {
    if (rawName.isEmpty) return '';

    if (RegExp(r'^\d+$').hasMatch(rawName)) {
      return '${rawName}번 도로';
    }

    if (rawName == '0' || rawName == '-' || rawName == 'null') return '';

    String cleanName = rawName.replaceAll(RegExp(r'\([^)]*\)'), '').trim();

    cleanName =
        cleanName
            .replaceAll(RegExp(r'^(국도|지방도|고속도로|시도|군도|구도)\s*'), '')
            .replaceAll(RegExp(r'\s*(국도|지방도|고속도로|시도|군도|구도)$'), '')
            .replaceAll('번길', '길')
            .trim();

    if (cleanName.length < 2) return '';

    if (!RegExp(r'^[가-힣a-zA-Z0-9\s\-\.]+$').hasMatch(cleanName)) return '';

    return cleanName;
  }
}
