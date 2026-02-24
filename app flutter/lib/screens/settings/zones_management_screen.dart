import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/zone.dart';
import '../../providers/irrigation_provider.dart';

class ZonesManagementScreen extends StatelessWidget {
  const ZonesManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IrrigationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des zones'),
      ),
      body: ListView.builder(
        itemCount: provider.zones.length,
        itemBuilder: (context, index) {
          final zone = provider.zones[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: zone.color,
                child: Text('${index + 1}'),
              ),
              title: Text(zone.name),
              subtitle: Text('${zone.durationSeconds} secondes'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showZoneDialog(context, zone),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(context, zone),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showZoneDialog(context, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showZoneDialog(BuildContext context, Zone? zone) {
    final nameController = TextEditingController(text: zone?.name ?? '');
    final durationController =
        TextEditingController(text: zone?.durationSeconds.toString() ?? '60');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(zone == null ? 'Ajouter une zone' : 'Modifier la zone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nom de la zone'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: durationController,
              decoration: const InputDecoration(labelText: 'Duree (secondes)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final duration = int.tryParse(durationController.text) ?? 0;

              if (name.isNotEmpty && duration > 0) {
                final provider =
                    Provider.of<IrrigationProvider>(context, listen: false);
                if (zone == null) {
                  provider.addZone(name, duration);
                } else {
                  provider.updateZone(zone.id, name, duration);
                }
                Navigator.pop(context);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Zone zone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la zone ?'),
        content: Text('Voulez-vous vraiment supprimer "${zone.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<IrrigationProvider>(context, listen: false)
                  .deleteZone(zone.id);
              Navigator.pop(context);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
