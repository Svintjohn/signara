import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:signara_landmarks/signara_landmarks.dart';

import '../../core/app_services.dart';
import '../../core/camera_permission.dart';
import '../../recognition/finger_state.dart';
import '../../recognition/fingerspelling_controller.dart';
import '../../recognition/sample_letter_classifier.dart';

/// Sign -> voice by fingerspelling. Camera + hand landmarks -> letters ->
/// word -> spoken. Letters you recorded in Collect samples are matched by
/// nearest example; for everything else it falls back to the finger rules.
class FingerspellPanel extends StatefulWidget {
  const FingerspellPanel({super.key, required this.services});

  final AppServices services;

  @override
  State<FingerspellPanel> createState() => _FingerspellPanelState();
}

class _FingerspellPanelState extends State<FingerspellPanel> {
  late final FingerspellingController _controller;
  final FlutterTts _tts = FlutterTts();

  int? _textureId;
  String? _error;
  bool _running = false;
  StreamSubscription<LandmarkFrame>? _sub;

  @override
  void initState() {
    super.initState();
    _controller = FingerspellingController(
      classifier: SampleLetterClassifier(() => widget.services.samples.statics),
    );
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _start() async {
    if (!await ensureCameraPermission()) {
      setState(() => _error = 'Camera permission is required.');
      return;
    }
    try {
      final id = await SignaraLandmarks.start();
      _sub = SignaraLandmarks.frames.listen(_controller.onFrame);
      if (!mounted) return;
      setState(() {
        _textureId = id;
        _running = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = 'Could not start the camera. Allow camera access and '
            'check your internet on the first load.\n\n$e',
      );
    }
  }

  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    await SignaraLandmarks.stop();
    if (!mounted) return;
    setState(() {
      _running = false;
      _textureId = null;
    });
  }

  Future<void> _speak() async {
    final text = _controller.buffer.text;
    if (text.isEmpty) return;
    try {
      await _tts.stop();
      await _tts.setLanguage('en-US');
      await _tts.speak(text);
    } catch (_) {
      // The text stays on screen if TTS is unavailable.
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (_running) SignaraLandmarks.stop();
    _tts.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final live = _controller.live;
    final text = _controller.buffer.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.services.samples.statics.isEmpty
                ? 'Demo recognizer: finger rules only. It knows '
                    '${letterRules.keys.join(' ')}. Record more letters in '
                    'Me → Collect samples. Hold a letter steady to add it.'
                : 'Using ${widget.services.samples.staticCounts.length} '
                    'recorded letters + finger rules. Hold a letter steady to '
                    'add it.',
            textAlign: TextAlign.center,
          ),
        ),
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
                      child: Text(_error!, textAlign: TextAlign.center),
                    ),
                  )
                : _textureId == null
                    ? Center(
                        child: FilledButton.icon(
                          onPressed: _start,
                          icon: const Icon(Icons.videocam),
                          label: const Text('Start camera'),
                        ),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          SignaraLandmarks.buildPreview(_textureId!),
                          Positioned(
                            left: 12,
                            top: 12,
                            child: Text(
                              live?.letter ?? '–',
                              style: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.copyWith(color: Colors.white),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: LinearProgressIndicator(
                              value: _controller.stabilizer.progress,
                            ),
                          ),
                        ],
                      ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text.isEmpty ? 'Spell a word with your hand…' : text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: _controller.backspace,
              child: const Text('Undo'),
            ),
            OutlinedButton(
              onPressed: _controller.endWord,
              child: const Text('Space'),
            ),
            OutlinedButton(
              onPressed: _controller.clear,
              child: const Text('Clear'),
            ),
            FilledButton.icon(
              onPressed: _speak,
              icon: const Icon(Icons.volume_up),
              label: const Text('Speak'),
            ),
            if (_running)
              TextButton(onPressed: _stop, child: const Text('Stop camera')),
          ],
        ),
      ],
    );
  }
}
