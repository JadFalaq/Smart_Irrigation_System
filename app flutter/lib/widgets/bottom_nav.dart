import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const BottomNav({super.key, required this.currentIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onChanged,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.water_drop), label: 'Bassin'),
        NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Stats'),
        NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Planning'),
        NavigationDestination(icon: Icon(Icons.settings), label: 'Parametres'),
      ],
    );
  }
}
