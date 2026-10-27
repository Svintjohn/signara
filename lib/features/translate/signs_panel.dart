import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:signara_landmarks/signara_landmarks.dart';

import '../../core/app_services.dart';
import '../../core/camera_permission.dart';
import '../../language/sentence_smoother.dart';
import '../../recognition/sequence_features.dart';
import '../../recognition/sign_segmenter.dart';
import '../../recognition/sign_template_classifier.dart';

/// Sign -> sentence -> voice, using the signs recorded in Collect samples.
///
/// Recognition is by example (dynamic time warping), so it only knows the
/// signs and signers that were recorded. Lower your hand between signs.
class SignsPanel extends StatefulWidget {
  const SignsPanel({super.key, required this.services});

  final AppServices services;

  @override
  State<SignsPanel> createState() => _SignsPanelState();
}

class _SignsPanelState extends State<SignsPanel> {
  final SignSegmenter _segmenter = SignSegmenter();
  final FlutterTts _tts = FlutterTts();
  late final SentenceSmoother _smoother;
  final List<String> _glosses = [];

  SignTemplateClassifier? _clf;
  int _clfRevision = -1;

  int? _textureId;
  String? _error;
  bool _running = false;
  StreamSubscription<LandmarkFrame>? _sub;
  OutputLanguage _lang = OutputLanguage.en;
  String _status = 'Start the camera, then sign. Lower your hand between signs.';

  @override
  void initState() {
    super.initState();
    _smoother = SentenceSmoother(
      lexicon: {for (final e in widget.services.vocab.signs) e.gloss: e},
    );
  }

  SignTemplateClassifier get _classifier {
    final store = widget.services.samples;
    if (_clf == null || _clfRevision != store.revision) {
      _clf = SignTemplateClassifier(store.seqs);
      _clfRevision = store.revision;
    }
    return _clf!;
  }

  Future<void> _start() async {
    if (!await ensureCameraPermission()) {
      setState(() => _error = 'Camera permission is required.');
      return;
    }
    try {
      final id = await SignaraLandmarks.start();
      _sub = SignaraLandmarks.frames.listen(_onFrame);
      if (!mounted) return;
      setState(() {
        _textureId = id;
        _running = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not start the camera.\n\n$e');
    }
  }

  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    await SignaraLandmarks.stop();
    _segmenter.reset();
    if (!mounted) return;
    setState(() {
      _running = false;
      _textureId = null;
    });
  }

  void _onFrame(LandmarkFrame f) {
    if (!mounted) return;
    final hand = f.hands.isEmpty
        ? null
        : RawHand(f.hands.first.xyz, f.aspect ?? 3 / 4);

    final done = _segmenter.update(hand);
    if (done == null) {
      if (_segmenter.isRecording) {
        setState(() => _status = 'Seeing a sign… ${_segmenter.length}');
      }
      return;
    }

    final clf = _classifier;
    final match = clf.classify(buildSequence(done));
    setState(() {
      if (match == null) {
        _status = 'Not sure what that was. Try again or record more samples.';
      } else {
        _glosses.add(match.gloss);
        _status = '${match.gloss}  (${(match.confidence * 100).round()}%)';
      }
    });
  }

  Future<void> _speak(String sentence) async {
    if (sentence.isEmpty) return;
    try {
      await _tts.stop();
      await _tts.setLanguage(_lang == OutputLanguage.en ? 'en-US' : 'fil-PH');
      await _tts.speak(sentence);
    } catch (_) {
      // The sentence stays on screen if TTS is unavailable.
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (_running) SignaraLandmarks.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final known = widget.services.samples.seqCounts.length;
    final sentence = _smoother.smooth(_glosses, lang: _lang);

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
            known == 0
                ? 'No signs recorded yet. Go to Me → Collect samples first.'
                : 'Knows $known recorded sign${known == 1 ? '' : 's'}. '
                    'Personalized: it only knows the signs and signers recorded.',
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
                    : SignaraLandmarks.buildPreview(_textureId!),
          ),
        ),
        const SizedBox(height: 4),
        Text(_status, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          _glosses.isEmpty ? '—' : _glosses.join('  '),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        Text(
          sentence.isEmpty ? ' ' : sentence,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            SegmentedButton<OutputLanguage>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: OutputLanguage.en, label: Text('EN')),
                ButtonSegment(value: OutputLanguage.fil, label: Text('FIL')),
              ],
              selected: {_lang},
              onSelectionChanged: (s) => setState(() => _lang = s.first),
            ),
            OutlinedButton(
              onPressed: _glosses.isEmpty
                  ? null
                  : () => setState(_glosses.removeLast),
              child: const Text('Undo'),
            ),
            OutlinedButton(
              onPressed:
                  _glosses.isEmpty ? null : () => setState(_glosses.clear),
              child: const Text('Clear'),
            ),
            FilledButton.icon(
              onPressed: sentence.isEmpty ? null : () => _speak(sentence),
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
