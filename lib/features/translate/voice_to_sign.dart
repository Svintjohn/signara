import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/app_services.dart';
import '../../language/text_to_sign.dart';
import '../../widgets/hand_skeleton.dart';

/// Hearing person -> Deaf person. Speak or type, and the app shows the signs
/// / fingerspelling one at a time.
///
/// Signs you recorded in Collect samples play as a moving hand skeleton (a
/// stand-in for video or an avatar). Anything not recorded shows a
/// placeholder. Output is word-for-word; real ASL grammar differs.
class VoiceToSign extends StatefulWidget {
  const VoiceToSign({super.key, required this.services});

  final AppServices services;

  @override
  State<VoiceToSign> createState() => _VoiceToSignState();
}

class _VoiceToSignState extends State<VoiceToSign> {
  final TextEditingController _text = TextEditingController();
  final stt.SpeechToText _stt = stt.SpeechToText();
  late final TextToSignPlanner _planner;

  List<PlannedItem> _items = const [];
  List<String> _units = const [];
  int _current = -1;
  Timer? _timer;

  bool _listening = false;
  bool _fil = false;

  @override
  void initState() {
    super.initState();
    _planner = TextToSignPlanner(widget.services.vocab);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stt.cancel();
    _text.dispose();
    super.dispose();
  }

  void _plan() {
    _timer?.cancel();
    final items = _planner.plan(_text.text);
    setState(() {
      _items = items;
      _units = TextToSignPlanner.units(items);
      _current = -1;
    });
  }

  void _play() {
    if (_units.isEmpty) return;
    _timer?.cancel();
    setState(() => _current = 0);
    _timer = Timer.periodic(const Duration(milliseconds: 1800), (t) {
      if (!mounted || _current + 1 >= _units.length) {
        t.cancel();
        return;
      }
      setState(() => _current++);
    });
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _stt.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    try {
      final ok = await _stt.initialize(
        onError: (e) {
          if (mounted) setState(() => _listening = false);
        },
        onStatus: (s) {
          if (!mounted) return;
          if (s == 'done' || s == 'notListening') {
            final wasListening = _listening;
            setState(() => _listening = false);
            if (wasListening && _text.text.trim().isNotEmpty) _plan();
          }
        },
      );
      if (!ok) {
        _say('Speech input is not available here. Type instead.');
        return;
      }
      setState(() => _listening = true);
      await _stt.listen(
        onResult: (r) {
          if (!mounted) return;
          setState(() => _text.text = r.recognizedWords);
        },
        localeId: _fil ? 'fil_PH' : 'en_US',
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
      );
    } catch (e) {
      if (mounted) setState(() => _listening = false);
      _say('Could not use the microphone. Type instead.');
    }
  }

  bool get _currentIsSign =>
      _current >= 0 && _current < _units.length && _units[_current].length > 1;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown =
        _current >= 0 && _current < _units.length ? _units[_current] : null;
    final reference =
        shown == null ? null : widget.services.samples.referenceFor(shown);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _text,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: _listening ? 'Listening…' : 'What do you want to say?',
            suffixIcon: IconButton(
              tooltip: _listening ? 'Stop' : 'Speak',
              icon: Icon(_listening ? Icons.stop_circle : Icons.mic),
              onPressed: _toggleMic,
            ),
          ),
          onSubmitted: (_) => _plan(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('EN')),
                ButtonSegment(value: true, label: Text('FIL')),
              ],
              selected: {_fil},
              onSelectionChanged: (s) => setState(() => _fil = s.first),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: _plan,
                icon: const Icon(Icons.sign_language),
                label: const Text('Show signs'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _units.isEmpty ? null : _play,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            child: shown == null
                ? Text(
                    _items.isEmpty
                        ? 'Speak or type, then tap “Show signs”.'
                        : 'Tap Play to step through the signs.',
                    textAlign: TextAlign.center,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        shown,
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 8),
                      if (reference != null)
                        SizedBox(
                          height: 160,
                          width: 160,
                          child: HandSkeletonPlayer(
                            key: ValueKey(shown),
                            frames: reference,
                          ),
                        ),
                      Text(
                        reference != null
                            ? 'Recorded reference'
                            : _currentIsSign
                                ? 'No recording yet · clip / avatar coming'
                                : 'Fingerspell this letter',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final it in _items)
              Chip(
                avatar: Icon(
                  it.isSign ? Icons.sign_language : Icons.abc,
                  size: 18,
                ),
                label: Text(it.isSign ? it.gloss! : it.letters.join('-')),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Word-for-word. Real ASL grammar and word order are different.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
