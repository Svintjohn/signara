import 'package:flutter/material.dart';

import '../../core/app_services.dart';
import '../../learning/lesson_items.dart';
import 'lesson_screen.dart';

/// Situational lessons + today's spaced-repetition practice.
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  int _due = 0;

  static const Map<String, String> _titles = {
    'basics': 'Basics · Pangunahin',
    'emergency': 'Emergency · Sa emergency',
    'hospital': 'At the hospital · Sa ospital',
    'school': 'At school · Sa eskwela',
    'questions': 'Question words · Mga tanong',
  };

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final n = await widget.services.srs.dueCount();
    if (!mounted) return;
    setState(() => _due = n);
  }

  Future<void> _open(String title, List<String> ids) async {
    if (ids.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LessonScreen(
          title: title,
          ids: ids,
          services: widget.services,
        ),
      ),
    );
    await _refresh();
  }

  Future<void> _today() async {
    final ids = await widget.services.srs.todaysSession(
      LessonItem.allIds(widget.services.vocab),
    );
    if (!mounted) return;
    await _open("Today's practice", ids);
  }

  @override
  Widget build(BuildContext context) {
    final vocab = widget.services.vocab;
    final categories = vocab.byCategory;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AnimatedBuilder(
          animation: widget.services.progress,
          builder: (context, _) {
            final s = widget.services.progress.state;
            return Text(
              '🔥 ${s?.streak ?? 0}-day streak   ·   ⭐ ${s?.xp ?? 0} XP',
              style: Theme.of(context).textTheme.titleMedium,
            );
          },
        ),
        const SizedBox(height: 12),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: ListTile(
            leading: const Icon(Icons.local_fire_department),
            title: const Text("Today's practice"),
            subtitle: Text(
              _due == 0
                  ? 'Nothing due. New cards are waiting.'
                  : '$_due card${_due == 1 ? '' : 's'} due for review',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _today,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.abc),
            title: const Text('Fingerspelling · Alpabeto'),
            subtitle: Text(
              '${vocab.alphabet.length} letters · ${vocab.numbers.length} numbers',
            ),
            onTap: () => _open(
              'Fingerspelling',
              LessonItem.fingerspellingIds(vocab),
            ),
          ),
        ),
        for (final entry in categories.entries)
          Card(
            child: ListTile(
              leading: const Icon(Icons.sign_language),
              title: Text(_titles[entry.key] ?? entry.key),
              subtitle: Text('${entry.value.length} signs'),
              onTap: () => _open(
                _titles[entry.key] ?? entry.key,
                LessonItem.idsForCategory(vocab, entry.key),
              ),
            ),
          ),
      ],
    );
  }
}
