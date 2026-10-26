import 'package:flutter/material.dart';

import '../../core/progress_controller.dart';
import '../../data/vocab.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key, required this.progress});

  final ProgressController progress;

  static String _title(String category) =>
      category[0].toUpperCase() + category.substring(1);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Vocab>(
      future: Vocab.load(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Could not load vocab: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final vocab = snap.data!;
        final categories = vocab.byCategory;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AnimatedBuilder(
              animation: progress,
              builder: (context, _) {
                final s = progress.state;
                return Text(
                  '🔥 ${s?.streak ?? 0}-day streak   ·   ⭐ ${s?.xp ?? 0} XP',
                  style: Theme.of(context).textTheme.titleMedium,
                );
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.abc),
                title: const Text('Fingerspelling'),
                subtitle: Text(
                  '${vocab.alphabet.length} letters · '
                  '${vocab.numbers.length} numbers',
                ),
                onTap: () => _openPractice(
                  context,
                  title: 'Fingerspelling',
                  items: [...vocab.alphabet, ...vocab.numbers],
                ),
              ),
            ),
            for (final entry in categories.entries)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.sign_language),
                  title: Text(_title(entry.key)),
                  subtitle: Text('${entry.value.length} signs'),
                  onTap: () => _openPractice(
                    context,
                    title: _title(entry.key),
                    items: entry.value.map((e) => e.gloss).toList(),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _openPractice(
    BuildContext context, {
    required String title,
    required List<String> items,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PracticeStub(
          title: title,
          items: items,
          progress: progress,
        ),
      ),
    );
  }
}

/// Placeholder for the real lesson: later this shows a reference clip, opens
/// the camera, and compares the learner's landmarks to the target sign.
class _PracticeStub extends StatefulWidget {
  const _PracticeStub({
    required this.title,
    required this.items,
    required this.progress,
  });

  final String title;
  final List<String> items;
  final ProgressController progress;

  @override
  State<_PracticeStub> createState() => _PracticeStubState();
}

class _PracticeStubState extends State<_PracticeStub> {
  int _i = 0;

  Future<void> _done() async {
    await widget.progress.recordPractice(xp: 10);
    if (!mounted) return;
    setState(() => _i = (_i + 1) % widget.items.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.items[_i],
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Reference clip + camera feedback coming in weeks 5-6.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _done,
              child: const Text('Mark as practiced  (+10 XP)'),
            ),
          ],
        ),
      ),
    );
  }
}
