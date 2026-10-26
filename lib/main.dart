import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/progress_controller.dart';
import 'core/streak_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final progress = ProgressController(StreakService(PrefsStore(prefs)));
  await progress.load();
  runApp(SignaraApp(progress: progress));
}
