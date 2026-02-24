class IrrigationHistory {
  final String id;
  final String zoneId;
  final DateTime timestamp;
  final int durationSeconds;

  const IrrigationHistory({
    required this.id,
    required this.zoneId,
    required this.timestamp,
    required this.durationSeconds,
  });

  factory IrrigationHistory.fromMap(String id, Map<dynamic, dynamic> map) {
    return IrrigationHistory(
      id: id,
      zoneId: map['zoneId']?.toString() ?? 'unknown',
      timestamp: DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now(),
      durationSeconds: int.tryParse(map['duration'].toString()) ?? 0,
    );
  }

  double get liters => durationSeconds * 0.5; // Example flow rate: 0.5L/sec
}
