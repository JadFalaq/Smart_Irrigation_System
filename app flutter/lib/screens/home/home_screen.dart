import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../providers/irrigation_provider.dart';
import '../../widgets/zone_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pumpController;

  @override
  void initState() {
    super.initState();
    _pumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _pumpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IrrigationProvider>();

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 30),
            _StatusBanner(
              status: provider.connectionStatus,
              lastUpdate: provider.lastUpdate,
            ),
            const SizedBox(height: 24),
            _AutoToggle(
              enabled: provider.autoRunning,
              busy: provider.commandPending,
              showLoader: provider.autoCommandPending,
              onChanged: provider.setAutoRunning,
            ),
            const SizedBox(height: 16),
            _PumpCard(
              active: provider.pumpActive,
              controller: _pumpController,
            ),
            const SizedBox(height: 16),
            if (provider.loading)
              Shimmer.fromColors(
                baseColor: Colors.grey.shade800,
                highlightColor: Colors.grey.shade700,
                child: Column(
                  children: List.generate(
                    3,
                    (index) => Container(
                      height: 120,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              )
            else
              Column(
                children: provider.zones
                    .asMap()
                    .entries
                    .map((entry) => ZoneCard(
                          zone: entry.value,
                          onToggle: provider.setZoneActive,
                          onDurationChanged: provider.setZoneDuration,
                          busy: provider.commandPending,
                        ))
                    .toList(),
              ),
            const SizedBox(height: 16),
            _LogCard(message: provider.latestLog),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: provider.commandPending ? null : provider.stopAll,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('STOP TOUT'),
            ),
            if (provider.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                provider.errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  final String lastUpdate;

  const _StatusBanner({required this.status, required this.lastUpdate});

  @override
  Widget build(BuildContext context) {
    final online = status.toLowerCase().contains('on');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: online ? Colors.green.shade700 : Colors.red.shade700,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (online ? Colors.green : Colors.red).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              online ? Icons.wifi : Icons.wifi_off,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  online ? 'ESP EN LIGNE' : 'ESP HORS LIGNE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  lastUpdate.isEmpty
                      ? 'En attente de données...'
                      : 'Dernière MAJ: $lastUpdate',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoToggle extends StatelessWidget {
  final bool enabled;
  final bool busy;
  final bool showLoader;
  final ValueChanged<bool> onChanged;

  const _AutoToggle({
    required this.enabled,
    required this.busy,
    required this.showLoader,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Mode auto',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            if (showLoader)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            Switch(value: enabled, onChanged: busy ? null : onChanged),
          ],
        ),
      ),
    );
  }
}

class _PumpCard extends StatelessWidget {
  final bool active;
  final AnimationController controller;

  const _PumpCard({required this.active, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            RotationTransition(
              turns: controller,
              child: Icon(
                Icons.water,
                size: 40,
                color: active ? Colors.blue : Colors.grey,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                active ? 'Pompe active' : 'Pompe arretee',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            Icon(
              active ? Icons.check_circle : Icons.pause_circle,
              color: active ? Colors.green : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final String message;

  const _LogCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.receipt_long),
        title: const Text('Dernier log'),
        subtitle: Text(message.isEmpty ? 'Aucun log' : message),
      ),
    );
  }
}
