class ScheduleZone {
  final String zoneId;
  final String startTime; // "HH:mm"

  const ScheduleZone({required this.zoneId, required this.startTime});

  Map<String, dynamic> toMap() {
    return {
      'zoneId': zoneId,
      'startTime': startTime,
    };
  }

  factory ScheduleZone.fromMap(Map<dynamic, dynamic> map) {
    return ScheduleZone(
      zoneId: map['zoneId']?.toString() ?? '',
      startTime: map['startTime']?.toString() ?? '00:00',
    );
  }
}

class Schedule {
  final String id;
  final String name;
  final bool enabled;
  final DateTime startDate;
  final DateTime endDate;
  final List<ScheduleZone> zones;

  const Schedule({
    required this.id,
    required this.name,
    required this.enabled,
    required this.startDate,
    required this.endDate,
    required this.zones,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'enabled': enabled,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'zones': zones.map((z) => z.toMap()).toList(),
    };
  }

  factory Schedule.fromMap(String id, Map<dynamic, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      try {
        return DateTime.parse(value.toString());
      } catch (e) {
        return DateTime.now();
      }
    }

    final zonesList = <ScheduleZone>[];
    if (map['zones'] != null) {
      if (map['zones'] is List) {
        for (var item in map['zones']) {
          zonesList.add(ScheduleZone.fromMap(item));
        }
      } else if (map['zones'] is Map) {
        // Handle Firebase array-like map behavior if needed
        (map['zones'] as Map).forEach((k, v) {
          zonesList.add(ScheduleZone.fromMap(v));
        });
      }
    }

    return Schedule(
      id: id,
      name: map['name']?.toString() ?? 'Planning',
      enabled: map['enabled'] == true,
      startDate: parseDate(map['startDate']),
      endDate: parseDate(map['endDate']),
      zones: zonesList,
    );
  }
}
