import 'package:flutter/foundation.dart';

import 'streak_service.dart';

/// Holds streak/XP state for the UI.
class ProgressController extends ChangeNotifier {
  ProgressController(this._service);

  final StreakService _service;

  StreakState? state;

  Future<void> load() async {
    state = await _service.load();
    notifyListeners();
  }

  Future<void> recordPractice({int xp = 10}) async {
    state = await _service.recordActivity(xp: xp);
    notifyListeners();
  }
}
