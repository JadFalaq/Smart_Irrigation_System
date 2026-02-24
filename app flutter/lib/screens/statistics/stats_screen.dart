import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../providers/irrigation_provider.dart';
import '../../models/history.dart';
import '../../models/zone.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    // Ensure locale data is initialized even if main() didn't run (e.g. hot reload)
    _initialization = initializeDateFormatting('fr_FR', null);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final provider = context.watch<IrrigationProvider>();
        final history = provider.history;

        // Calculate daily consumption (last 7 days)
        final dailyValues = _calculateDailyValues(history);

        // Calculate zone distribution
        final zoneUsage = _calculateZoneUsage(history, provider.zones.length);

        // Calculate total liters
        final totalLiters =
            history.fold<double>(0, (sum, item) => sum + item.liters).round();

        // Find top zone
        String topZone = '-';
        if (zoneUsage.isNotEmpty) {
          final sortedZones = zoneUsage.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          if (sortedZones.isNotEmpty) {
            final topZoneId = sortedZones.first.key;
            // Try to find zone name
            final zone = provider.zones.cast<Zone?>().firstWhere(
                  (z) => z?.id == topZoneId,
                  orElse: () => null,
                );
            topZone = zone?.name ?? 'Zone $topZoneId';
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (history.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Aucune donnée historique disponible pour le moment.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            Text('Consommation 7 jours (L)',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final date = DateTime.now()
                              .subtract(Duration(days: 6 - value.toInt()));
                          return Text(DateFormat('E', 'fr_FR')
                              .format(date)
                              .substring(0, 1)); // Mon -> L
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: dailyValues
                      .asMap()
                      .entries
                      .map(
                        (entry) => BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value,
                              width: 14,
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(4),
                            )
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Répartition par zone',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: zoneUsage.isEmpty
                  ? const Center(child: Text('Pas de données'))
                  : PieChart(
                      PieChartData(
                        sections: zoneUsage.entries.map((entry) {
                          final index = int.tryParse(entry.key
                                  .replaceAll(RegExp(r'[^0-9]'), '')) ??
                              0;
                          final color =
                              Colors.primaries[index % Colors.primaries.length];

                          return PieChartSectionData(
                            value: entry.value,
                            title: 'Z${index}',
                            radius: 60,
                            color: color,
                            titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          );
                        }).toList(),
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            _InfoCards(totalLitres: totalLiters, topZone: topZone),
          ],
        );
      },
    );
  }

  List<double> _calculateDailyValues(List<IrrigationHistory> history) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final values = List<double>.filled(7, 0);

    for (var item in history) {
      final itemDate = DateTime(
          item.timestamp.year, item.timestamp.month, item.timestamp.day);
      final diff = today.difference(itemDate).inDays;
      if (diff >= 0 && diff < 7) {
        values[6 - diff] += item.liters;
      }
    }
    return values;
  }

  Map<String, double> _calculateZoneUsage(
      List<IrrigationHistory> history, int zoneCount) {
    final usage = <String, double>{};
    for (var item in history) {
      usage[item.zoneId] = (usage[item.zoneId] ?? 0) + item.liters;
    }
    return usage;
  }
}

// Helper class for type checking workaround removed

class _InfoCards extends StatelessWidget {
  final int totalLitres;
  final String topZone;

  const _InfoCards({required this.totalLitres, required this.topZone});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Total litres',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text('$totalLitres L',
                      style: Theme.of(context).textTheme.headlineMedium),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Zone principale',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text(topZone,
                      style: Theme.of(context).textTheme.headlineMedium),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
