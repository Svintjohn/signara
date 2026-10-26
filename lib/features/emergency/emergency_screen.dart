import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../data/emergency_phrases.dart';

/// One tap -> loud spoken phrase + big on-screen text the other person can
/// read. Works offline as long as the device has a TTS voice installed.
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final FlutterTts _tts = FlutterTts();
  bool _filipino = false;
  String? _shown;

  @override
  void initState() {
    super.initState();
    _tts.setVolume(1.0);
    _tts.setSpeechRate(0.45);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak(EmergencyPhrase p) async {
    final text = _filipino ? p.fil : p.en;
    setState(() => _shown = text);
    try {
      await _tts.stop();
      await _tts.setLanguage(_filipino ? 'fil-PH' : 'en-US');
      await _tts.speak(text);
    } catch (_) {
      // The on-screen text is still shown if TTS is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('English')),
              ButtonSegment(value: true, label: Text('Filipino')),
            ],
            selected: {_filipino},
            onSelectionChanged: (s) => setState(() => _filipino = s.first),
          ),
          const SizedBox(height: 12),
          if (_shown != null)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _shown!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                for (final p in emergencyPhrases)
                  FilledButton.tonal(
                    onPressed: () => _speak(p),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(p.icon, style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 4),
                        Text(
                          _filipino ? p.fil : p.en,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
