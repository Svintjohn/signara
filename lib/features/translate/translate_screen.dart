import 'package:flutter/material.dart';

import '../spike/spike_screen.dart';

enum TranslateMode { signToVoice, voiceToSign }

/// Two-way conversation screen. Right now this is only the UI shell:
/// recognition (sign -> voice) and playback (voice -> sign) come in weeks 3-6.
class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  TranslateMode _mode = TranslateMode.signToVoice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _mode == TranslateMode.signToVoice
                        ? Icons.videocam_outlined
                        : Icons.record_voice_over_outlined,
                    size: 56,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _mode == TranslateMode.signToVoice
                        ? 'Camera recognition is not built yet.\n'
                            'Use the spike below to test the camera pipeline.'
                        : 'Speech → sign playback is not built yet.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SpikeScreen()),
            ),
            icon: const Icon(Icons.speed),
            label: const Text('Week-1 spike: camera → landmarks'),
          ),
          const SizedBox(height: 8),
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
