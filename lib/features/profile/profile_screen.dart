import 'package:flutter/material.dart';

import '../../core/app_services.dart';
import '../collect/collect_screen.dart';
import '../community/community_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: services.progress,
      builder: (context, _) {
        final s = services.progress.state;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Your progress',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            _Stat(label: 'Current streak', value: '${s?.streak ?? 0} days'),
            _Stat(label: 'Best streak', value: '${s?.bestStreak ?? 0} days'),
            _Stat(label: 'Total XP', value: '${s?.xp ?? 0}'),
            _Stat(
              label: 'Practiced today',
              value: (s?.practicedToday ?? false) ? 'Yes' : 'Not yet',
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Collect samples'),
                subtitle: const Text(
                  'Teach the recognizer your letters and signs',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CollectScreen(services: services),
                  ),
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.diversity_3),
                title: const Text('Community contribution'),
                subtitle: const Text('Suggest regional sign variations'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CommunityScreen(services: services),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('About', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Signara is a thesis prototype. It teaches and recognizes a '
              'small set of ASL signs. It is not a replacement for a human '
              'interpreter. It misses facial expressions and grammar.\n\n'
              'Progress and suggestions stay on this device. No camera frames '
              'are stored or uploaded.',
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
