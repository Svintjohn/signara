import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/app_services.dart';
import 'core/progress_controller.dart';
import 'core/streak_service.dart';
import 'data/sample_store.dart';
import 'data/vocab.dart';
import 'learning/spaced_repetition.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final store = PrefsStore(prefs);

  final progress = ProgressController(StreakService(store));
  await progress.load();
  final vocab = await Vocab.load();
  final samples = SampleStore(store);
  await samples.load();

  runApp(
    SignaraApp(
      services: AppServices(
        progress: progress,
        srs: SpacedRepetitionService(store),
        vocab: vocab,
        store: store,
        samples: samples,
      ),
    ),
  );
}
