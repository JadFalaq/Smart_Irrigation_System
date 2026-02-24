import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/irrigation_provider.dart';

class BasinScreen extends StatelessWidget {
  const BasinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IrrigationProvider>();
    final isActive = provider.basinActive;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Remplir le bassin'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.water_drop,
                  color: isActive ? Colors.blue : Colors.grey,
                ),
                title: Text(isActive ? 'Remplissage en cours' : 'Bassin a l\'arret'),
                subtitle: Text(
                  isActive ? 'Le moteur 2 est actif' : 'Le moteur 2 est inactive',
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? Colors.red : Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: provider.commandPending
                  ? null
                  : () => provider.setBasinFilling(!isActive),
              icon: Icon(isActive ? Icons.stop_circle : Icons.play_circle),
              label: Text(isActive ? 'ARRETER' : 'DEMARRER'),
            ),
          ],
        ),
      ),
    );
  }
}
