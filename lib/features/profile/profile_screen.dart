import 'package:flutter/material.dart';

import '../../core/progress_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.progress});

  final ProgressController progress;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final s = progress.state;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Your progress', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            _Stat(label: 'Current streak', value: '${s?.streak ?? 0} days'),
            _Stat(label: 'Best streak', value: '${s?.bestStreak ?? 0} days'),
            _Stat(label: 'Total XP', value: '${s?.xp ?? 0}'),
            _Stat(
              label: 'Practiced today',
              value: (s?.practicedToday ?? false) ? 'Yes' : 'Not yet',
            ),
            const SizedBox(height: 24),
            const Text(
              'Everything stays on this device. No camera frames or '
              'progress data are uploaded.',
            ),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(title: Text(label), trailing: Text(value)),
    );
  }
}
