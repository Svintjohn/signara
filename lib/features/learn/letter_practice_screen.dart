import 'dart:async';

import 'package:flutter/material.dart';
import 'package:signara_landmarks/signara_landmarks.dart';

import '../../core/app_services.dart';
import '../../core/camera_permission.dart';
import '../../recognition/finger_state.dart';
import '../../recognition/landmark_features.dart';

/// "The recognizer is the teacher": the camera watches the learner's hand and
/// tells them what to fix ("Extend your thumb"), like a tutor would.
///
/// PROTOTYPE: feedback comes from finger-state rules for a few letters
/// (see `letterRules`). The thresholds need tuning on a real phone. A trained
/// model + reference landmarks will replace this for the other letters.
class LetterPracticeScreen extends StatefulWidget {
  const LetterPracticeScreen({
    super.key,
    required this.letter,
    required this.services,
  });

  final String letter;
  final AppServices services;

  @override
  State<LetterPracticeScreen> createState() => _LetterPracticeScreenState();
}

class _LetterPracticeScreenState extends State<LetterPracticeScreen> {
  static const int _okNeeded = 8; // frames in a row

  int? _textureId;
  String? _error;
  StreamSubscription<LandmarkFrame>? _sub;
  List<String> _hints = const ['Show your hand to the camera'];
  int _okFrames = 0;
  bool _done = false;

  bool get _hasRule => letterRules.containsKey(widget.letter);

  @override
  void initState() {
    super.initState();
    if (_hasRule) _start();
  }

  Future<void> _start() async {
    if (!await ensureCameraPermission()) {
      setState(() => _error = 'Camera permission is required.');
      return;
    }
    try {
      final id = await SignaraLandmarks.start(front: true);
      _sub = SignaraLandmarks.frames.listen(_onFrame);
      if (!mounted) return;
      setState(() => _textureId = id);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = 'Could not start the camera. Allow camera access and '
            'check your internet on the first load.\n\n$e',
      );
    }
  }

  void _onFrame(LandmarkFrame f) {
    if (_done || !mounted) return;

    if (f.hands.isEmpty) {
      setState(() {
        _hints = const ['Show your hand to the camera'];
        _okFrames = 0;
      });
      return;
    }

    final features = normalizeHand(f.hands.first.xyz, aspect: f.aspect ?? 3 / 4);
    final fb = feedbackFor(widget.letter, FingerStates.fromFeatures(features));
    _okFrames = fb.correct ? _okFrames + 1 : 0;

    if (_okFrames >= _okNeeded) {
      _done = true;
      widget.services.srs.record('letter:${widget.letter}', correct: true);
      widget.services.progress.recordPractice(xp: 10);
    }
    setState(() => _hints = fb.hints);
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (_textureId != null) SignaraLandmarks.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('Practice: ${widget.letter}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: !_hasRule
            ? const Center(
                child: Text(
                  'There is no quick camera check for this letter yet.\n'
                  'It needs the trained model.',
                  textAlign: TextAlign.center,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _error != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : _textureId == null
                              ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                              : Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    SignaraLandmarks.buildPreview(_textureId!),
                                    Positioned(
                                      left: 12,
                                      top: 12,
                                      child: Text(
                                        widget.letter,
                                        style: Theme.of(context)
                                            .textTheme
                                            .displayLarge
                                            ?.copyWith(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_done)
                    Text(
                      '✓ Nice! +10 XP',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    )
                  else
                    for (final h in _hints)
                      Text(
                        h,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                ],
              ),
      ),
    );
  }
}
