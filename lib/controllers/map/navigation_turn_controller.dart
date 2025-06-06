import 'dart:async';
import 'dart:math';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:tomapto/controllers/map/transit_map_controller.dart';
import 'package:tomapto/controllers/route/route_instruction_controller.dart';

class NavigationTurnController {
  final TransitMode mode;

  List<TurnByTurnInstruction> _turnInstructions = [];
  List<NLatLng> _pathCoordinates = [];
  int _currentInstructionIndex = 0;
  Map<String, dynamic>? _currentInstruction;
  Map<String, dynamic>? _nextInstruction;

  final StreamController<Map<String, dynamic>> _turnByTurnController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get turnByTurnStream =>
      _turnByTurnController.stream;

  Map<String, dynamic>? get currentInstruction => _currentInstruction;
  Map<String, dynamic>? get nextInstruction => _nextInstruction;

  NavigationTurnController(this.mode);

  void setApiTurnInstructions(
    List<TurnByTurnInstruction> instructions,
    List<NLatLng> pathCoordinates,
  ) {
    _turnInstructions = instructions;
    _pathCoordinates = pathCoordinates;
    _currentInstructionIndex = 0;

    if (_turnInstructions.isNotEmpty) {
      _updateCurrentInstruction();
    }
  }

  void updateTurnByTurnInstruction(NLatLng currentPosition) {
    if (_turnInstructions.isEmpty || mode != TransitMode.car) return;

    if (_currentInstructionIndex < _turnInstructions.length) {
      final currentTurn = _turnInstructions[_currentInstructionIndex];
      final distanceToTurn = _calculateDistance(
        currentPosition,
        currentTurn.position,
      );

      if (distanceToTurn < 50) {
        _currentInstructionIndex++;
        _updateCurrentInstruction();
      }
    }
  }

  void _updateCurrentInstruction() {
    if (_currentInstructionIndex < _turnInstructions.length) {
      final instruction = _turnInstructions[_currentInstructionIndex];

      _currentInstruction = {
        'direction': instruction.directionText,
        'distance': instruction.distance,
        'roadName': instruction.roadName,
        'instruction': instruction.instruction,
        'point': instruction.position,
        'icon': instruction.iconData,
        'directionIcon': instruction.iconData,
        'distanceToPoint': instruction.distance,
      };

      // 다음 분기점 정보
      if (_currentInstructionIndex + 1 < _turnInstructions.length) {
        final nextInstruction = _turnInstructions[_currentInstructionIndex + 1];
        _nextInstruction = {
          'direction': nextInstruction.directionText,
          'distance': nextInstruction.distance,
          'roadName': nextInstruction.roadName,
          'instruction': nextInstruction.instruction,
          'point': nextInstruction.position,
          'icon': nextInstruction.iconData,
          'directionIcon': nextInstruction.iconData,
          'distanceToPoint': nextInstruction.distance,
        };
      } else {
        _nextInstruction = null;
      }

      _turnByTurnController.add(_currentInstruction!);
    } else {
      _currentInstruction = null;
      _nextInstruction = null;
    }
  }

  double _calculateDistance(NLatLng point1, NLatLng point2) {
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

  void dispose() {
    _turnByTurnController.close();
  }
}
