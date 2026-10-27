import 'package:flutter/material.dart';

import '../../core/app_services.dart';
import '../spike/spike_screen.dart';
import 'fingerspell_panel.dart';
import 'phrase_builder.dart';
import 'signs_panel.dart';
import 'voice_to_sign.dart';

enum TranslateMode { fingerspell, signs, phrases, voiceToSign }

/// Prototype UI: functional, not designed. Real UI/UX comes later.
class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  TranslateMode _mode = TranslateMode.fingerspell;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<TranslateMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: TranslateMode.fingerspell, label: Text('Spell')),
              ButtonSegment(value: TranslateMode.signs, label: Text('Signs')),
              ButtonSegment(value: TranslateMode.phrases, label: Text('Tap')),
              ButtonSegment(value: TranslateMode.voiceToSign, label: Text('Voice→Sign')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: switch (_mode) {
              TranslateMode.fingerspell =>
                FingerspellPanel(services: widget.services),
              TranslateMode.signs => SignsPanel(services: widget.services),
              TranslateMode.phrases =>
                PhraseBuilder(services: widget.services),
              TranslateMode.voiceToSign =>
                VoiceToSign(services: widget.services),
            },
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
