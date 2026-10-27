import 'package:flutter/material.dart';

import '../../core/app_services.dart';
import '../../learning/lesson_items.dart';
import '../../widgets/hand_skeleton.dart';
import 'letter_practice_screen.dart';

/// Flashcards with self-rating. "Got it" moves a card to a longer review
/// interval, "Again" brings it back today (spaced repetition).
///
/// No sign clips yet: the card shows the word and its meaning. The reference
/// video / animation slot is a placeholder.
class LessonScreen extends StatefulWidget {
  const LessonScreen({
    super.key,
    required this.title,
    required this.ids,
    required this.services,
  });

  final String title;
  final List<String> ids;
  final AppServices services;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  late final List<LessonItem> _items;
  int _i = 0;
  bool _revealed = false;
  int _gotIt = 0;

  @override
  void initState() {
    super.initState();
    _items = [
      for (final id in widget.ids)
        if (LessonItem.fromId(widget.services.vocab, id) != null)
          LessonItem.fromId(widget.services.vocab, id)!,
    ];
  }

  Future<void> _answer(bool correct) async {
    final item = _items[_i];
    await widget.services.srs.record(item.id, correct: correct);
    await widget.services.progress.recordPractice(xp: correct ? 10 : 2);
    if (!mounted) return;
    setState(() {
      if (correct) _gotIt++;
      _i++;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final done = _i >= _items.length;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _items.isEmpty
            ? const Center(child: Text('No cards in this lesson.'))
            : done
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🎉', style: TextStyle(fontSize: 56)),
                        const SizedBox(height: 8),
                        Text(
                          'Done: $_gotIt of ${_items.length} remembered',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Back'),
                        ),
                      ],
                    ),
                  )
                : _card(context, _items[_i]),
      ),
    );
  }

  Widget _card(BuildContext context, LessonItem item) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(value: _i / _items.length),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final ref = widget.services.samples.referenceFor(item.title);
                    if (ref == null) {
                      return Text(
                        'No recording yet · clip / animation coming',
                        style: Theme.of(context).textTheme.bodySmall,
                      );
                    }
                    return Column(
                      children: [
                        SizedBox(
                          height: 160,
                          width: 160,
                          child: HandSkeletonPlayer(
                            key: ValueKey(item.id),
                            frames: ref,
                          ),
                        ),
                        Text(
                          'Recorded reference',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    );
                  },
                ),
                if (_revealed) ...[
                  const SizedBox(height: 24),
                  Text(item.en, style: Theme.of(context).textTheme.titleLarge),
                  Text(item.fil, style: Theme.of(context).textTheme.titleMedium),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (item.letter != null && item.id.startsWith('letter:'))
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LetterPracticeScreen(
                  letter: item.letter!,
                  services: widget.services,
                ),
              ),
            ),
            icon: const Icon(Icons.videocam),
            label: const Text('Practice with camera'),
          ),
        const SizedBox(height: 8),
        if (!_revealed)
          FilledButton(
            onPressed: () => setState(() => _revealed = true),
            child: const Text('Show meaning'),
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _answer(false),
                  child: const Text('Again'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => _answer(true),
                  child: const Text('Got it  (+10 XP)'),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
