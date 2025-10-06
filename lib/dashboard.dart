import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class Dashboard extends StatelessWidget {
  final List<Map<String, dynamic>> appliances;

  const Dashboard({super.key, required this.appliances});

  @override
  Widget build(BuildContext context) {
    // Prepare data for bar chart
    final barGroups = appliances.asMap().entries.map((entry) {
      final i = entry.key;
      final appliance = entry.value;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: (appliance['monthlyKWh'] ?? 0).toDouble(),
            color: Colors.tealAccent,
            width: 16,
          )
        ],
      );
    }).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Text(
            'Monthly Energy Usage (kWh)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: appliances.isEmpty
                    ? 10
                    : appliances
                        .map((e) => e['monthlyKWh'] ?? 0)
                        .reduce((a, b) => a > b ? a : b)
                        .toDouble() *
                        1.2,
                barGroups: barGroups,
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= appliances.length) return const Text('');
                          return Text(appliances[idx]['name'] ?? '');
                        }),
                  ),
                ),
              ),
            ),
          ),
          const Divider(),
          ...appliances.map((a) => Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  leading: Image.file(File(a['imagePath'])),
                  title: Text('${a['name']} (${a['efficiencyStars']}★)'),
                  subtitle: Text(
                      'Power: ${a['powerDraw']}W\nMonthly: ${a['monthlyKWh'].toStringAsFixed(1)} kWh\nYearly: ${a['yearlyKWh'].toStringAsFixed(1)} kWh'),
                ),
              )),
        ],
      ),
    );
  }
}
