import 'package:flutter/material.dart';

import '../models/zone.dart';

class ZoneCard extends StatelessWidget {
  final Zone zone;
  final Future<void> Function(String, bool) onToggle;
  final Future<void> Function(String, int) onDurationChanged;
  final bool busy;

  const ZoneCard({
    super.key,
    required this.zone,
    required this.onToggle,
    required this.onDurationChanged,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = zone.active ? Colors.green : Colors.grey;
    final durationLabel = _formatDuration(zone.durationSeconds);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.grass, color: activeColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    zone.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                Switch(
                  value: zone.active,
                  onChanged: busy ? null : (value) => onToggle(zone.id, value),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text('Duree: $durationLabel')),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => _showDurationDialog(context, zone.durationSeconds),
                  child: const Text('Modifier'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final safeSeconds = totalSeconds < 0 ? 0 : totalSeconds;
    final hours = safeSeconds ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;
    final seconds = safeSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _showDurationDialog(BuildContext context, int currentSeconds) async {
    final hoursController = TextEditingController(
      text: (currentSeconds ~/ 3600).toString(),
    );
    final minutesController = TextEditingController(
      text: ((currentSeconds % 3600) ~/ 60).toString(),
    );
    final secondsController = TextEditingController(
      text: (currentSeconds % 60).toString(),
    );

    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Definir la duree'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hoursController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Heures'),
              ),
              TextField(
                controller: minutesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Minutes'),
              ),
              TextField(
                controller: secondsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Secondes'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final hours = int.tryParse(hoursController.text) ?? 0;
                final minutes = int.tryParse(minutesController.text) ?? 0;
                final seconds = int.tryParse(secondsController.text) ?? 0;
                final total = (hours * 3600) + (minutes * 60) + seconds;
                Navigator.of(context).pop(total);
              },
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );

    if (result == null) return;
    await onDurationChanged(zone.id, result);
  }
}
