import '../data/sample_store.dart';
import '../data/vocab.dart';
import '../learning/spaced_repetition.dart';
import 'progress_controller.dart';
import 'streak_service.dart';

/// Everything the screens share. Built once in main().
class AppServices {
  const AppServices({
    required this.progress,
    required this.srs,
    required this.vocab,
    required this.store,
    required this.samples,
  });

  final ProgressController progress;
  final SpacedRepetitionService srs;
  final Vocab vocab;
  final KeyValueStore store;

  /// Hand samples recorded on this device (what the recognizers learn from).
  final SampleStore samples;
}
