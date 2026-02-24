import 'package:flutter/material.dart';

class Zone {
  final String id;
  final String name;
  final bool active;
  final int durationSeconds;
  final Color color;
  final int? startTime;

  const Zone({
    required this.id,
    required this.name,
    required this.active,
    required this.durationSeconds,
    required this.color,
    this.startTime,
  });

  Zone copyWith({
    String? id,
    String? name,
    bool? active,
    int? durationSeconds,
    Color? color,
    int? startTime,
  }) {
    return Zone(
      id: id ?? this.id,
      name: name ?? this.name,
      active: active ?? this.active,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      color: color ?? this.color,
      startTime: startTime ?? this.startTime,
    );
  }

  factory Zone.fromMap(String id, Map<dynamic, dynamic> data) {
    return Zone(
      id: id,
      name: (data['name'] ?? 'Zone').toString(),
      active: data['active'] == true,
      durationSeconds: (data['duration'] ?? 0) is int
          ? data['duration'] as int
          : int.tryParse(data['duration'].toString()) ?? 0,
      color: Colors.green,
      startTime: data['startTime'] != null
          ? int.tryParse(data['startTime'].toString())
          : null,
    );
  }
}
