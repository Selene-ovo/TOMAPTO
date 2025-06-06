import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'route_instruction_controller.dart';
import 'route_data_controller.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class RouteParserController {
  List<NLatLng> extractPathCoordinates(Map<String, dynamic> route) {
    final List<NLatLng> pathCoordinates = [];

    if (route['path'] != null) {
      final path = route['path'] as List;

      if (path.isNotEmpty && path[0] is! List) {
        // 평면 배열: [lng1, lat1, lng2, lat2, ...]
        for (int i = 0; i < path.length; i += 2) {
          if (i + 1 < path.length) {
            double longitude = (path[i] as num).toDouble();
            double latitude = (path[i + 1] as num).toDouble();
            pathCoordinates.add(NLatLng(latitude, longitude));
          }
        }
      } else {
        // 중첩 배열: [[lng1, lat1], [lng2, lat2], ...]
        for (var point in path) {
          if (point is List && point.length >= 2) {
            double longitude = (point[0] as num).toDouble();
            double latitude = (point[1] as num).toDouble();
            pathCoordinates.add(NLatLng(latitude, longitude));
          }
        }
      }
    }

    return pathCoordinates;
  }

  List<TurnByTurnInstruction> extractTurnInstructions(
    Map<String, dynamic> route,
    List<NLatLng> pathCoordinates,
  ) {
    List<TurnByTurnInstruction> instructions = [];

    try {
      if (route['guide'] != null) {
        final guides = route['guide'] as List;

        for (int i = 0; i < guides.length; i++) {
          final guide = guides[i];

          final instruction = TurnByTurnInstruction.fromNaverGuide(
            guide,
            pathCoordinates,
          );
          if (instruction != null) {
            instructions.add(instruction);
          }
        }
      }

      if (instructions.isEmpty && route['section'] != null) {
        instructions = _createInstructionsFromSections(route, pathCoordinates);
      }

      if (route['section'] != null) {
        instructions = _enhanceRoadNamesFromSections(instructions, route);
      }
    } catch (e) {
      // Empty instructions on error
    }

    return instructions;
  }

  List<Map<String, dynamic>> extractSectionInfo(Map<String, dynamic> route) {
    List<Map<String, dynamic>> sections = [];

    try {
      if (route['section'] != null) {
        final sectionList = route['section'] as List;

        for (int i = 0; i < sectionList.length; i++) {
          final section = sectionList[i];

          final sectionInfo = {
            'pointIndex': (section['pointIndex'] as num?)?.toInt() ?? 0,
            'pointCount': (section['pointCount'] as num?)?.toInt() ?? 0,
            'distance': (section['distance'] as num?)?.toInt() ?? 0,
            'name': section['name']?.toString() ?? '도로',
            'congestion': (section['congestion'] as num?)?.toInt() ?? 0,
            'speed': (section['speed'] as num?)?.toInt() ?? 50,
            'duration': _calculateSectionDuration(
              (section['distance'] as num?)?.toInt() ?? 0,
              (section['speed'] as num?)?.toInt() ?? 50,
            ),
          };

          sections.add(sectionInfo);
        }
      }
    } catch (e) {
      // Empty sections on error
    }

    return sections;
  }

  List<RoadSegment> parseRoadSegments(Map<String, dynamic> routeData) {
    List<RoadSegment> segments = [];

    try {
      if (routeData['route'] != null && routeData['route']['trafast'] != null) {
        final route = routeData['route']['trafast'][0];

        if (route['guide'] != null) {
          final guides = route['guide'] as List;

          for (var guide in guides) {
            if (guide['name'] != null && guide['distance'] != null) {
              String roadName = guide['name'].toString();
              int distance = (guide['distance'] as num).toInt();
              int duration = (guide['duration'] as num?)?.toInt() ?? 0;

              if (roadName.isNotEmpty && roadName != '0' && distance > 0) {
                segments.add(
                  RoadSegment(
                    roadName: roadName,
                    distance: distance,
                    duration: duration,
                    coordinates: [],
                  ),
                );
              }
            }
          }
        }

        if (segments.isEmpty && route['section'] != null) {
          final sections = route['section'] as List;

          for (var section in sections) {
            if (section['name'] != null) {
              String roadName = section['name'].toString();
              int distance = (section['distance'] as num?)?.toInt() ?? 0;
              int duration = (section['duration'] as num?)?.toInt() ?? 0;

              if (roadName.isNotEmpty && distance > 0) {
                segments.add(
                  RoadSegment(
                    roadName: roadName,
                    distance: distance,
                    duration: duration,
                    coordinates: [],
                  ),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      // Empty segments on error
    }

    return segments;
  }

  Map<String, dynamic> parseTmapWalkResponse(
    dynamic data,
    NLatLng start,
    NLatLng end,
  ) {
    final List<NLatLng> pathCoordinates = [];
    int totalTime = 0;
    int totalDistance = 0;

    try {
      if (data['features'] != null) {
        final features = data['features'] as List;

        for (var feature in features) {
          final properties = feature['properties'];
          if (properties != null) {
            if (properties['totalTime'] != null) {
              totalTime = (properties['totalTime'] as num).round();
            }
            if (properties['totalDistance'] != null) {
              totalDistance = (properties['totalDistance'] as num).round();
            }
            if (totalTime > 0 && totalDistance > 0) break;
          }
        }

        for (var feature in features) {
          final geometry = feature['geometry'];
          if (geometry == null) continue;

          if (geometry['type'] == 'LineString') {
            final coordinates = geometry['coordinates'] as List;
            for (var coord in coordinates) {
              if (coord is List && coord.length >= 2) {
                double longitude = (coord[0] as num).toDouble();
                double latitude = (coord[1] as num).toDouble();
                pathCoordinates.add(NLatLng(latitude, longitude));
              }
            }
          } else if (geometry['type'] == 'Point') {
            final coordinates = geometry['coordinates'] as List;
            if (coordinates.length >= 2) {
              double longitude = (coordinates[0] as num).toDouble();
              double latitude = (coordinates[1] as num).toDouble();
              pathCoordinates.add(NLatLng(latitude, longitude));
            }
          }
        }
      }

      if (pathCoordinates.length < 2) {
        pathCoordinates.clear();
        pathCoordinates.addAll(_generateSimpleWalkPath(start, end));

        if (totalDistance == 0) {
          totalDistance = _calculateDistance(start, end).round();
        }
        if (totalTime == 0) {
          totalTime = (totalDistance / 1.4).round();
        }
      }

      return {
        'routes': [
          {'path': pathCoordinates},
        ],
        'distance': totalDistance,
        'duration': totalTime,
      };
    } catch (e) {
      return _getMockWalkRouteData(start, end);
    }
  }

  List<TurnByTurnInstruction> _createInstructionsFromSections(
    Map<String, dynamic> route,
    List<NLatLng> pathCoordinates,
  ) {
    List<TurnByTurnInstruction> instructions = [];
    final sections = route['section'] as List;

    double accumulatedDistance = 0;
    for (int i = 0; i < sections.length; i++) {
      final section = sections[i];
      String roadName = _extractCleanRoadName(
        section['name']?.toString() ?? '',
      );

      // 도로명이 비어있으면 기본값 사용
      if (roadName.isEmpty) {
        roadName = '${i + 1}구간';
      }

      final distance = (section['distance'] as num?)?.toInt() ?? 0;
      final duration = (section['duration'] as num?)?.toInt() ?? 0;

      if (distance > 50) {
        final pointIndex =
            (section['pointIndex'] as num?)?.toInt() ??
            (i * (pathCoordinates.length ~/ sections.length));
        final position =
            pointIndex < pathCoordinates.length
                ? pathCoordinates[pointIndex]
                : pathCoordinates.isNotEmpty
                ? pathCoordinates.last
                : NLatLng(0, 0);

        instructions.add(
          TurnByTurnInstruction(
            type: 0,
            instruction: '${roadName}으로 계속 이동',
            position: position,
            distance: accumulatedDistance.round(),
            duration: duration,
            iconData: Icons.arrow_upward_rounded,
            directionText: '직진',
            roadName: roadName,
            pointIndex: pointIndex,
          ),
        );
      }
      accumulatedDistance += distance;
    }

    return instructions;
  }
}

List<TurnByTurnInstruction> _enhanceRoadNamesFromSections(
  List<TurnByTurnInstruction> instructions,
  Map<String, dynamic> route,
) {
  if (route['section'] == null) return instructions;

  final sections = route['section'] as List;
  List<TurnByTurnInstruction> enhancedInstructions = [];

  for (int i = 0; i < instructions.length; i++) {
    final instruction = instructions[i];
    String enhancedRoadName = instruction.roadName;

    double minDistance = double.infinity;
    String closestSectionRoadName = '';

    for (var section in sections) {
      final sectionName = _extractCleanRoadName(
        section['name']?.toString() ?? '',
      );
      if (sectionName.isNotEmpty) {
        final pointIndex = (section['pointIndex'] as num?)?.toInt() ?? 0;
        final distance = (instruction.pointIndex - pointIndex).abs().toDouble();

        if (distance < minDistance) {
          minDistance = distance;
          closestSectionRoadName = sectionName;
        }
      }
    }

    if (closestSectionRoadName.isNotEmpty &&
        (instruction.roadName.isEmpty ||
            instruction.roadName == '도로' ||
            instruction.roadName.startsWith('도로 '))) {
      enhancedRoadName = closestSectionRoadName;
    }

    enhancedInstructions.add(
      TurnByTurnInstruction(
        type: instruction.type,
        instruction: instruction.instruction,
        position: instruction.position,
        distance: instruction.distance,
        duration: instruction.duration,
        iconData: instruction.iconData,
        directionText: instruction.directionText,
        roadName: enhancedRoadName,
        pointIndex: instruction.pointIndex,
      ),
    );
  }

  return enhancedInstructions;
}

int _calculateSectionDuration(int distance, int speed) {
  if (speed <= 0) return 0;
  double timeInHours = distance / 1000.0 / speed;
  return (timeInHours * 3600).round();
}

String _extractCleanRoadName(String rawName) {
  if (rawName.isEmpty || rawName == '0') return '';

  String cleanName = rawName.replaceAll(RegExp(r'\([^)]*\)'), '').trim();

  // 숫자만 있는 경우 도로번호로 처리
  if (RegExp(r'^\d+$').hasMatch(cleanName)) {
    return '${cleanName}번 도로';
  }

  cleanName =
      cleanName
          .replaceAll('고속도로', '')
          .replaceAll('국도', '')
          .replaceAll('지방도', '')
          .trim();

  if (cleanName.length < 2) return '';

  return cleanName;
}

List<NLatLng> _generateSimpleWalkPath(NLatLng start, NLatLng end) {
  final distance = _calculateDistance(start, end);

  if (distance < 100) {
    return [start, end];
  }

  final points = <NLatLng>[start];
  final steps = (distance / 200).clamp(1, 4).round();

  for (int i = 1; i < steps; i++) {
    final ratio = i / steps;
    final lat = start.latitude + (end.latitude - start.latitude) * ratio;
    final lng = start.longitude + (end.longitude - start.longitude) * ratio;
    points.add(NLatLng(lat, lng));
  }

  points.add(end);
  return points;
}

double _calculateDistance(NLatLng point1, NLatLng point2) {
  const double earthRadius = 6371000;
  final double lat1 = point1.latitude * (3.141592653589793 / 180);
  final double lat2 = point2.latitude * (3.141592653589793 / 180);
  final double dLat =
      (point2.latitude - point1.latitude) * (3.141592653589793 / 180);
  final double dLon =
      (point2.longitude - point1.longitude) * (3.141592653589793 / 180);

  final double a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadius * c;
}

Map<String, dynamic> _getMockWalkRouteData(NLatLng start, NLatLng end) {
  final distance = _calculateDistance(start, end).round();
  final duration = (distance / 1.4).round();

  return {
    'distance': distance,
    'duration': duration,
    'routes': [
      {'path': _generateSimpleWalkPath(start, end)},
    ],
  };
}
