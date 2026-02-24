import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../providers/irrigation_provider.dart';
import '../login/login_screen.dart';
import 'zones_management_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IrrigationProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Systeme', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.settings_input_component),
          title: const Text('Gestion des zones'),
          subtitle: const Text('Ajouter, modifier ou supprimer des zones'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ZonesManagementScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.router),
          title: const Text('Etat connexion'),
          subtitle: Text(provider.connectionStatus),
        ),
        ListTile(
          leading: const Icon(Icons.schedule),
          title: const Text('Derniere mise a jour'),
          subtitle:
              Text(provider.lastUpdate.isEmpty ? '-' : provider.lastUpdate),
        ),
        const Divider(),
        Text('Temps d\'attente',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        _DelayTile(
          title: 'Delai vanne -> pompe',
          onSave: provider.setPreValve,
          busy: provider.commandPending,
        ),
        _DelayTile(
          title: 'Delai pompe -> vanne',
          onSave: provider.setPostPump,
          busy: provider.commandPending,
        ),
        const Divider(),
        Text('Notifications',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        SwitchListTile(
          value: true,
          onChanged: (_) {},
          title: const Text('Activer notifications'),
        ),
        const Divider(),
        Text('Donnees', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.download),
          title: const Text('Exporter CSV'),
          onTap: () {},
        ),
        const Divider(),
        Text('A propos', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Version 1.0.0'),
          subtitle: Text('Mikafa'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text(
            'Se deconnecter',
            style: TextStyle(color: Colors.red),
          ),
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Deconnexion'),
                content: const Text('Voulez-vous vraiment vous deconnecter ?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Se deconnecter'),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              // Stop listening before signing out to clear data
              context.read<IrrigationProvider>().stopListening();

              await FirebaseAuth.instance.signOut();
              await GoogleSignIn().signOut();

              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            }
          },
        ),
      ],
    );
  }
}

class _DelayTile extends StatefulWidget {
  final String title;
  final ValueChanged<int> onSave;
  final bool busy;

  const _DelayTile({
    required this.title,
    required this.onSave,
    required this.busy,
  });

  @override
  State<_DelayTile> createState() => _DelayTileState();
}

class _DelayTileState extends State<_DelayTile> {
  final _controller = TextEditingController(text: '2');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.title),
      subtitle: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        enabled: !widget.busy,
        decoration: const InputDecoration(suffixText: 's'),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.save),
        onPressed: widget.busy
            ? null
            : () {
                final value = int.tryParse(_controller.text.trim()) ?? 0;
                widget.onSave(value);
              },
      ),
    );
  }
}
