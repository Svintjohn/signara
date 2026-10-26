import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:signara_landmarks/signara_landmarks.dart';

import '../../recognition/fingerspelling_controller.dart';
import '../../recognition/letter_classifier.dart';
import '../spike/spike_screen.dart';

enum TranslateMode { signToVoice, voiceToSign }

/// Prototype UI: functional, not designed. Real UI/UX comes later.
class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  TranslateMode _mode = TranslateMode.signToVoice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<TranslateMode>(
            segments: const [
              ButtonSegment(
                value: TranslateMode.signToVoice,
                icon: Icon(Icons.sign_language),
                label: Text('Sign → Voice'),
              ),
              ButtonSegment(
                value: TranslateMode.voiceToSign,
                icon: Icon(Icons.mic),
                label: Text('Voice → Sign'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _mode == TranslateMode.signToVoice
                ? const _SignToVoice()
                : const Center(
                    child: Text('Speech → sign playback is not built yet.'),
                  ),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SpikeScreen()),
            ),
            icon: const Icon(Icons.speed),
            label: const Text('Week-1 spike: fps test'),
          ),
          Text(
            'Prototype. Not a replacement for a human interpreter.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SignToVoice extends StatefulWidget {
  const _SignToVoice();

  @override
  State<_SignToVoice> createState() => _SignToVoiceState();
}

class _SignToVoiceState extends State<_SignToVoice> {
  // Swap for the TFLite classifier once the model exists.
  final FingerspellingController _controller = FingerspellingController(
    classifier: const NoModelClassifier(),
  );
  final FlutterTts _tts = FlutterTts();

  int? _textureId;
  String? _error;
  bool _running = false;
  StreamSubscription<LandmarkFrame>? _sub;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _start() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
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
      setState(() => _error = 'Could not start camera: $e');
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
      // Text stays on screen if TTS is unavailable.
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
    final stab = _controller.stabilizer;
    final text = _controller.buffer.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_controller.classifier.isReady)
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'No trained model loaded yet, so letters will not be '
              'recognized. Camera and landmarks work.',
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
                ? Center(child: Text(_error!))
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
                          Texture(textureId: _textureId!),
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
                            child: LinearProgressIndicator(value: stab.progress),
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
