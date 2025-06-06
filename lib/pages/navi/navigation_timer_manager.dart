import 'dart:async';
import 'package:flutter/material.dart';

class NavigationTimerManager {
  final Set<Timer> _activeTimers = {};

  Timer? _temporaryRouteTimer;
  Timer? _routeWaitTimer;
  Timer? _turnByTurnTimer;
  Timer? _recalculateTimer;

  void addTimer(Timer timer) {
    _activeTimers.add(timer);
  }

  Timer createTemporaryRouteTimer(Duration duration, VoidCallback callback) {
    _temporaryRouteTimer?.cancel();
    _temporaryRouteTimer = Timer(duration, callback);
    addTimer(_temporaryRouteTimer!);
    return _temporaryRouteTimer!;
  }

  Timer createRouteWaitTimer(Duration duration, VoidCallback callback) {
    _routeWaitTimer?.cancel();
    _routeWaitTimer = Timer.periodic(duration, (timer) {
      callback();
    });
    addTimer(_routeWaitTimer!);
    return _routeWaitTimer!;
  }

  Timer createTurnByTurnTimer(Duration duration, VoidCallback callback) {
    _turnByTurnTimer?.cancel();
    _turnByTurnTimer = Timer.periodic(duration, (timer) {
      callback();
    });
    addTimer(_turnByTurnTimer!);
    return _turnByTurnTimer!;
  }

  Timer createRecalculateTimer(Duration duration, VoidCallback callback) {
    _recalculateTimer?.cancel();
    _recalculateTimer = Timer(duration, callback);
    addTimer(_recalculateTimer!);
    return _recalculateTimer!;
  }

  Timer createDelayTimer(Duration duration, VoidCallback callback) {
    final timer = Timer(duration, callback);
    addTimer(timer);
    return timer;
  }

  Timer createPeriodicTimer(Duration duration, VoidCallback callback) {
    final timer = Timer.periodic(duration, (timer) {
      callback();
    });
    addTimer(timer);
    return timer;
  }

  void cancelTemporaryRouteTimer() {
    _temporaryRouteTimer?.cancel();
    if (_temporaryRouteTimer != null) {
      _activeTimers.remove(_temporaryRouteTimer);
      _temporaryRouteTimer = null;
    }
  }

  void cancelRouteWaitTimer() {
    _routeWaitTimer?.cancel();
    if (_routeWaitTimer != null) {
      _activeTimers.remove(_routeWaitTimer);
      _routeWaitTimer = null;
    }
  }

  void cancelTurnByTurnTimer() {
    _turnByTurnTimer?.cancel();
    if (_turnByTurnTimer != null) {
      _activeTimers.remove(_turnByTurnTimer);
      _turnByTurnTimer = null;
    }
  }

  void cancelRecalculateTimer() {
    _recalculateTimer?.cancel();
    if (_recalculateTimer != null) {
      _activeTimers.remove(_recalculateTimer);
      _recalculateTimer = null;
    }
  }

  void cancelAllTimers() {
    for (Timer timer in _activeTimers) {
      timer.cancel();
    }
    _activeTimers.clear();

    _temporaryRouteTimer = null;
    _routeWaitTimer = null;
    _turnByTurnTimer = null;
    _recalculateTimer = null;
  }

  void dispose() {
    cancelAllTimers();
  }
}
