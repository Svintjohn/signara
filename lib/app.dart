import 'package:flutter/material.dart';

import 'core/app_services.dart';
import 'core/theme.dart';
import 'features/culture/culture_screen.dart';
import 'features/emergency/emergency_screen.dart';
import 'features/learn/learn_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/translate/translate_screen.dart';

class SignaraApp extends StatelessWidget {
  const SignaraApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Signara',
      debugShowCheckedModeBanner: false,
      theme: SignaraTheme.light(),
      darkTheme: SignaraTheme.dark(),
      themeMode: ThemeMode.system,
      home: HomeShell(services: services),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.services});

  final AppServices services;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      TranslateScreen(services: widget.services),
      LearnScreen(services: widget.services),
      const EmergencyScreen(),
      const CultureScreen(),
      ProfileScreen(services: widget.services),
    ];

    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.translate), label: 'Translate'),
          NavigationDestination(icon: Icon(Icons.school), label: 'Learn'),
          NavigationDestination(icon: Icon(Icons.emergency), label: 'Emergency'),
          NavigationDestination(icon: Icon(Icons.diversity_3), label: 'Culture'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );
  }
}
