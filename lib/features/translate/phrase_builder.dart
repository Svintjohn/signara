import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/app_services.dart';
import '../../language/sentence_smoother.dart';

/// Sign phrase -> natural sentence -> voice.
///
/// SIMULATED INPUT: until the isolated-sign model exists (week 3), tapping a
/// sign here stands in for the recognizer. Everything after that (gloss list
/// -> smoothing -> EN/FIL sentence -> TTS) is the real pipeline.
class PhraseBuilder extends StatefulWidget {
  const PhraseBuilder({super.key, required this.services});

  final AppServices services;

  @override
  State<PhraseBuilder> createState() => _PhraseBuilderState();
}

class _PhraseBuilderState extends State<PhraseBuilder> {
  final List<String> _glosses = [];
  final FlutterTts _tts = FlutterTts();
  late final SentenceSmoother _smoother;
  OutputLanguage _lang = OutputLanguage.en;

  @override
  void initState() {
    super.initState();
    _smoother = SentenceSmoother(
      lexicon: {for (final e in widget.services.vocab.signs) e.gloss: e},
    );
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak(String sentence) async {
    if (sentence.isEmpty) return;
    try {
      await _tts.stop();
      await _tts.setLanguage(_lang == OutputLanguage.en ? 'en-US' : 'fil-PH');
      await _tts.speak(sentence);
    } catch (_) {
      // Sentence stays on screen if TTS is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sentence = _smoother.smooth(_glosses, lang: _lang);
    final categories = widget.services.vocab.byCategory;

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
          child: const Text(
            'Simulated: tap signs to stand in for the sign recognizer '
            '(coming in week 3). Smoothing and voice below are real.',
            textAlign: TextAlign.center,
          ),
        ),
        SegmentedButton<OutputLanguage>(
          segments: const [
            ButtonSegment(value: OutputLanguage.en, label: Text('English')),
            ButtonSegment(value: OutputLanguage.fil, label: Text('Filipino')),
          ],
          selected: {_lang},
          onSelectionChanged: (s) => setState(() => _lang = s.first),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _glosses.isEmpty ? 'Tap signs below…' : _glosses.join('  '),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                sentence.isEmpty ? '—' : sentence,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
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
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              for (final entry in categories.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    entry.key.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in entry.value)
                      ActionChip(
                        label: Text(s.gloss),
                        onPressed: () => setState(() => _glosses.add(s.gloss)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
