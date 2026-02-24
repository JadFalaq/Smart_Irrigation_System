import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/schedule.dart';
import '../../models/zone.dart';
import '../../providers/irrigation_provider.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  List<Schedule> _getSchedulesForDay(
      DateTime day, List<Schedule> allSchedules) {
    return allSchedules.where((schedule) {
      if (!schedule.enabled) return false;
      // Check if day is within range
      // Normalize dates to ignore time
      final start = DateTime(schedule.startDate.year, schedule.startDate.month,
          schedule.startDate.day);
      final end = DateTime(
          schedule.endDate.year, schedule.endDate.month, schedule.endDate.day);
      final check = DateTime(day.year, day.month, day.day);
      return check.compareTo(start) >= 0 && check.compareTo(end) <= 0;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IrrigationProvider>();
    final schedules = provider.schedules;
    final selectedSchedules = _selectedDay == null
        ? <Schedule>[]
        : _getSchedulesForDay(_selectedDay!, schedules);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: TableCalendar(
              focusedDay: _focusedDay,
              firstDay: DateTime.utc(2024, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
              },
              eventLoader: (day) => _getSchedulesForDay(day, schedules),
              calendarStyle: const CalendarStyle(
                markerDecoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Plannings du jour',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              ElevatedButton.icon(
                onPressed: () => _openCreateSchedule(context),
                icon: const Icon(Icons.add),
                label: const Text('Nouveau'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (selectedSchedules.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('Aucun arrosage prévu ce jour-là.')),
            )
          else
            ...selectedSchedules.map((schedule) => _ScheduleCard(
                  schedule: schedule,
                  zones: provider.zones,
                )),
          const SizedBox(height: 24),
          Text(
            'Tous les plannings',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          if (schedules.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('Aucun planning configuré.')),
            )
          else
            ...schedules.map((schedule) => _ScheduleCard(
                  schedule: schedule,
                  showDates: true,
                  onDelete: () => provider.deleteSchedule(schedule.id),
                  onToggle: (val) => provider.toggleSchedule(schedule.id, val),
                  zones: provider.zones,
                )),
        ],
      ),
    );
  }

  Future<void> _openCreateSchedule(BuildContext context) async {
    final provider = context.read<IrrigationProvider>();
    final zones = provider.zones;

    final nameController = TextEditingController();
    DateTimeRange? dateRange;
    final Map<String, TimeOfDay> zoneTimes = {}; // ZoneID -> Time
    final Set<String> selectedZones = {};

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Créer un planning',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du planning',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(dateRange == null
                          ? 'Sélectionner une période'
                          : '${DateFormat('dd/MM/yyyy').format(dateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(dateRange!.end)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setModalState(() => dateRange = picked);
                        }
                      },
                    ),
                    const Divider(),
                    Text('Configuration des zones',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (zones.isEmpty)
                      const Text(
                          'Aucune zone disponible. Ajoutez des zones dans les paramètres.',
                          style: TextStyle(color: Colors.orange)),
                    ...zones.map((zone) {
                      final isSelected = selectedZones.contains(zone.id);
                      final time = zoneTimes[zone.id] ??
                          const TimeOfDay(hour: 6, minute: 0);

                      return Card(
                        elevation: isSelected ? 2 : 0,
                        color: isSelected
                            ? Theme.of(context).primaryColor.withOpacity(0.05)
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isSelected
                              ? BorderSide(
                                  color: Theme.of(context).primaryColor,
                                  width: 1.5)
                              : BorderSide.none,
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            CheckboxListTile(
                              value: isSelected,
                              title: Text(
                                zone.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              activeColor: Theme.of(context).primaryColor,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              onChanged: (val) {
                                setModalState(() {
                                  if (val == true) {
                                    selectedZones.add(zone.id);
                                    if (!zoneTimes.containsKey(zone.id)) {
                                      zoneTimes[zone.id] =
                                          const TimeOfDay(hour: 6, minute: 0);
                                    }
                                  } else {
                                    selectedZones.remove(zone.id);
                                  }
                                });
                              },
                            ),
                            if (isSelected)
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 16, right: 16, bottom: 12),
                                child: Row(
                                  children: [
                                    Icon(Icons.access_time,
                                        size: 20, color: Colors.grey[700]),
                                    const SizedBox(width: 8),
                                    const Text("Heure de démarrage :",
                                        style: TextStyle(fontSize: 14)),
                                    const Spacer(),
                                    OutlinedButton(
                                      onPressed: () async {
                                        final picked = await showTimePicker(
                                          context: context,
                                          initialTime: time,
                                          builder: (context, child) {
                                            return MediaQuery(
                                              data: MediaQuery.of(context)
                                                  .copyWith(
                                                      alwaysUse24HourFormat:
                                                          true),
                                              child: child!,
                                            );
                                          },
                                        );
                                        if (picked != null) {
                                          setModalState(() =>
                                              zoneTimes[zone.id] = picked);
                                        }
                                      },
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        side: BorderSide(
                                            color: Theme.of(context)
                                                .primaryColor
                                                .withOpacity(0.5)),
                                      ),
                                      child: Text(
                                        time.format(context),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        if (nameController.text.isEmpty ||
                            dateRange == null ||
                            selectedZones.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Veuillez remplir tous les champs (nom, dates, zones)')),
                          );
                          return;
                        }

                        final newSchedule = Schedule(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: nameController.text.trim(),
                          enabled: true,
                          startDate: dateRange!.start,
                          endDate: dateRange!.end,
                          zones: selectedZones
                              .map((zid) => ScheduleZone(
                                    zoneId: zid,
                                    startTime:
                                        '${zoneTimes[zid]!.hour.toString().padLeft(2, '0')}:${zoneTimes[zid]!.minute.toString().padLeft(2, '0')}',
                                  ))
                              .toList(),
                        );

                        provider.addSchedule(newSchedule);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('ENREGISTRER LE PLANNING'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final Schedule schedule;
  final bool showDates;
  final VoidCallback? onDelete;
  final ValueChanged<bool>? onToggle;
  final List<Zone> zones;

  const _ScheduleCard({
    required this.schedule,
    this.showDates = false,
    this.onDelete,
    this.onToggle,
    this.zones = const <Zone>[],
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schedule.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (showDates) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              '${dateFormat.format(schedule.startDate)} - ${dateFormat.format(schedule.endDate)}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (onToggle != null)
                  Switch(
                    value: schedule.enabled,
                    onChanged: onToggle,
                    activeColor: Theme.of(context).primaryColor,
                  ),
              ],
            ),
            const Divider(height: 24),
            const Text(
              'Zones & Horaires :',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: schedule.zones.map((sz) {
                final zoneName = zones
                        .cast<Zone?>()
                        .firstWhere((z) => z?.id == sz.zoneId,
                            orElse: () => null)
                        ?.name ??
                    'Zone ${sz.zoneId}';

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.water_drop,
                          size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        '$zoneName : ',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        sz.startTime,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            if (onDelete != null) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: Colors.red),
                  label: const Text('Supprimer',
                      style: TextStyle(color: Colors.red)),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
