import 'package:flutter/material.dart';

import 'core/progress_controller.dart';
import 'core/theme.dart';
import 'features/emergency/emergency_screen.dart';
import 'features/learn/learn_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/translate/translate_screen.dart';

class SignaraApp extends StatelessWidget {
  const SignaraApp({super.key, required this.progress});

  final ProgressController progress;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Signara',
      debugShowCheckedModeBanner: false,
      theme: SignaraTheme.light(),
      darkTheme: SignaraTheme.dark(),
      themeMode: ThemeMode.system,
      home: HomeShell(progress: progress),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.progress});

  final ProgressController progress;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const TranslateScreen(),
      LearnScreen(progress: widget.progress),
      const EmergencyScreen(),
      ProfileScreen(progress: widget.progress),
    ];

    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.translate),
            label: 'Translate',
          ),
          NavigationDestination(icon: Icon(Icons.school), label: 'Learn'),
          NavigationDestination(
            icon: Icon(Icons.emergency),
            label: 'Emergency',
          ),
          NavigationDestination(icon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );
  }
}
