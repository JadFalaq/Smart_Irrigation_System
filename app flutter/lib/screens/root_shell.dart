import 'package:flutter/material.dart';

import '../widgets/bottom_nav.dart';
import 'basin/basin_screen.dart';
import 'home/home_screen.dart';
import 'schedule/schedule_screen.dart';
import 'settings/settings_screen.dart';
import 'statistics/stats_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    BasinScreen(),
    StatsScreen(),
    ScheduleScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: BottomNav(
        currentIndex: _index,
        onChanged: (index) => setState(() => _index = index),
      ),
    );
  }
}
