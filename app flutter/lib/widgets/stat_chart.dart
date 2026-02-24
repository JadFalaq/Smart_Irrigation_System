import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class StatBarChart extends StatelessWidget {
  final List<double> values;

  const StatBarChart({super.key, required this.values});

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: values
            .asMap()
            .entries
            .map(
              (entry) => BarChartGroupData(
                x: entry.key,
                barRods: [BarChartRodData(toY: entry.value, width: 14)],
              ),
            )
            .toList(),
      ),
    );
  }
}

class StatPieChart extends StatelessWidget {
  final List<double> values;

  const StatPieChart({super.key, required this.values});

  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        sections: values
            .asMap()
            .entries
            .map(
              (entry) => PieChartSectionData(
                value: entry.value,
                title: 'Z${entry.key + 1}',
                radius: 60,
              ),
            )
            .toList(),
      ),
    );
  }
}
