import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../models/zone.dart';
import '../models/schedule.dart';
import '../models/history.dart';

class IrrigationProvider extends ChangeNotifier {
  // Supprime la référence statique à _root
  // final DatabaseReference _root = FirebaseDatabase.instance.ref('irrigation');

  // Obtient la référence racine en fonction de l'utilisateur connecté
  DatabaseReference get _root {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // Si aucun utilisateur n'est connecté, on renvoie une référence vide ou temporaire
      // Pour éviter les crashs, mais idéalement on ne devrait pas appeler _root sans user
      return FirebaseDatabase.instance.ref('users/anonymous/irrigation');
    }
    return FirebaseDatabase.instance.ref('users/$uid/irrigation');
  }

  bool get hasUser => FirebaseAuth.instance.currentUser != null;

  bool loading = true;
  String? errorMessage;
  String connectionStatus = 'offline';
  String lastUpdate = '';
  String latestLog = '';
  bool pumpActive = false;
  bool autoRunning = false;
  bool commandPending = false;
  bool basinActive = false;

  final List<Zone> zones = [];
  final List<Schedule> schedules = [];
  final List<IrrigationHistory> history = [];

  StreamSubscription<DatabaseEvent>? _zonesSub;
  StreamSubscription<DatabaseEvent>? _schedulesSub;
  StreamSubscription<DatabaseEvent>? _historySub;
  StreamSubscription<DatabaseEvent>? _pumpSub;
  StreamSubscription<DatabaseEvent>? _autoSub;
  StreamSubscription<DatabaseEvent>? _statusSub;
  StreamSubscription<DatabaseEvent>? _logSub;
  StreamSubscription<DatabaseEvent>? _basinSub;
  Timer? _autoCommandTimer;
  String? _pendingType;
  String? _pendingZoneId;
  bool? _pendingTarget;

  bool get autoCommandPending => commandPending && _pendingType == 'auto';

  void startListening() {
    if (!hasUser) {
      errorMessage = 'Utilisateur non connecte';
      notifyListeners();
      return;
    }
    _listenZones();
    _listenSchedules();
    _listenHistory();
    _listenPump();
    _listenAuto();
    _listenBasin();
    _listenStatus();
    _listenLogs();
  }

  void stopListening() {
    _zonesSub?.cancel();
    _pumpSub?.cancel();
    _autoSub?.cancel();
    _statusSub?.cancel();
    _logSub?.cancel();
    _basinSub?.cancel();
    _autoCommandTimer?.cancel();

    // Reset local state
    zones.clear();
    schedules.clear();
    history.clear();
    pumpActive = false;
    autoRunning = false;
    basinActive = false;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      loading = true;
      errorMessage = null;
      notifyListeners();

      final zonesSnap = await _root.child('zones').get();
      _applyZonesSnapshot(zonesSnap);

      final pumpSnap = await _root.child('pump/active').get();
      pumpActive = pumpSnap.value == true;

      final autoSnap = await _root.child('auto/running').get();
      autoRunning = autoSnap.value == true;

      final basinSnap = await _root.child('basin/active').get();
      basinActive = basinSnap.value == true;

      final statusSnap = await _root.child('status').get();
      _applyStatusSnapshot(statusSnap);

      final logSnap = await _root.child('logs/latest').get();
      latestLog = (logSnap.value ?? '').toString();
    } catch (e) {
      errorMessage = 'Erreur de rafraichissement: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _listenZones() {
    _zonesSub?.cancel();
    _zonesSub = _root.child('zones').onValue.listen((event) {
      _applyZonesSnapshot(event.snapshot);
      _checkPendingCompletion();
      loading = false;
      errorMessage = null;
      notifyListeners();
    }, onError: (error) {
      errorMessage = 'Erreur zones: $error';
      notifyListeners();
    });
  }

  void _listenSchedules() {
    _schedulesSub?.cancel();
    _schedulesSub = _root.child('schedules').onValue.listen((event) {
      _applySchedulesSnapshot(event.snapshot);
      notifyListeners();
    }, onError: (error) {
      errorMessage = 'Erreur plannings: $error';
      notifyListeners();
    });
  }

  void _listenHistory() {
    _historySub?.cancel();
    _historySub =
        _root.child('history').limitToLast(100).onValue.listen((event) {
      _applyHistorySnapshot(event.snapshot);
      notifyListeners();
    }, onError: (error) {
      errorMessage = 'Erreur historique: $error';
      notifyListeners();
    });
  }

  void _applySchedulesSnapshot(DataSnapshot snapshot) {
    schedules
      ..clear()
      ..addAll(_parseSchedules(snapshot.value));
  }

  void _applyHistorySnapshot(DataSnapshot snapshot) {
    history
      ..clear()
      ..addAll(_parseHistory(snapshot.value));
  }

  List<Schedule> _parseSchedules(Object? raw) {
    final data = raw as Map<dynamic, dynamic>?;
    if (data == null) return [];

    final parsed = <Schedule>[];
    data.forEach((key, value) {
      final scheduleData = value as Map<dynamic, dynamic>;
      parsed.add(Schedule.fromMap(key.toString(), scheduleData));
    });

    parsed.sort((a, b) => a.startDate.compareTo(b.startDate));

    return parsed;
  }

  List<IrrigationHistory> _parseHistory(Object? raw) {
    final data = raw as Map<dynamic, dynamic>?;
    if (data == null) return [];

    final parsed = <IrrigationHistory>[];
    data.forEach((key, value) {
      final historyData = value as Map<dynamic, dynamic>;
      parsed.add(IrrigationHistory.fromMap(key.toString(), historyData));
    });

    parsed.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return parsed;
  }

  Future<void> addSchedule(Schedule schedule) async {
    try {
      // Remove ID from map if it's the key, but toMap includes it.
      // Firebase set needs value.
      await _root.child('schedules/${schedule.id}').set(schedule.toMap());
    } catch (e) {
      errorMessage = 'Erreur ajout planning: $e';
      notifyListeners();
    }
  }

  Future<void> deleteSchedule(String id) async {
    try {
      await _root.child('schedules/$id').remove();
    } catch (e) {
      errorMessage = 'Erreur suppression planning: $e';
      notifyListeners();
    }
  }

  Future<void> toggleSchedule(String id, bool enabled) async {
    try {
      await _root.child('schedules/$id').update({'enabled': enabled});
    } catch (e) {
      errorMessage = 'Erreur modification planning: $e';
      notifyListeners();
    }
  }

  void _listenPump() {
    _pumpSub?.cancel();
    _pumpSub = _root.child('pump/active').onValue.listen((event) {
      pumpActive = event.snapshot.value == true;
      notifyListeners();
    }, onError: (error) {
      errorMessage = 'Erreur pompe: $error';
      notifyListeners();
    });
  }

  void _listenAuto() {
    _autoSub?.cancel();
    _autoSub = _root.child('auto/running').onValue.listen((event) {
      autoRunning = event.snapshot.value == true;
      _checkPendingCompletion();
      notifyListeners();
    }, onError: (error) {
      errorMessage = 'Erreur auto: $error';
      notifyListeners();
    });
  }

  void _listenBasin() {
    _basinSub?.cancel();
    _basinSub = _root.child('basin/active').onValue.listen((event) {
      basinActive = event.snapshot.value == true;
      _checkPendingCompletion();
      notifyListeners();
    }, onError: (error) {
      errorMessage = 'Erreur bassin: $error';
      notifyListeners();
    });
  }

  void _listenStatus() {
    _statusSub?.cancel();
    _statusSub = _root.child('status').onValue.listen((event) {
      _applyStatusSnapshot(event.snapshot);
      notifyListeners();
    }, onError: (error) {
      errorMessage = 'Erreur statut: $error';
      notifyListeners();
    });
  }

  void _listenLogs() {
    _logSub?.cancel();
    _logSub = _root.child('logs/latest').onValue.listen((event) {
      latestLog = (event.snapshot.value ?? '').toString();
      notifyListeners();
    }, onError: (error) {
      errorMessage = 'Erreur logs: $error';
      notifyListeners();
    });
  }

  void _applyZonesSnapshot(DataSnapshot snapshot) {
    zones
      ..clear()
      ..addAll(_parseZones(snapshot.value));
  }

  void _applyStatusSnapshot(DataSnapshot snapshot) {
    final data = snapshot.value as Map<dynamic, dynamic>?;
    if (data == null) return;
    connectionStatus = (data['connection'] ?? 'offline').toString();
    lastUpdate = (data['lastUpdate'] ?? '').toString();
  }

  List<Zone> _parseZones(Object? raw) {
    final data = raw as Map<dynamic, dynamic>?;
    if (data == null) return [];

    final parsed = <Zone>[];
    data.forEach((key, value) {
      if (key.toString().startsWith('zone')) {
        final zoneData = value as Map<dynamic, dynamic>;
        parsed.add(Zone.fromMap(key.toString(), zoneData));
      }
    });

    // Sort by zone number (e.g. zone1, zone2, zone10)
    parsed.sort((a, b) {
      final aNum = int.tryParse(a.id.replaceAll('zone', '')) ?? 0;
      final bNum = int.tryParse(b.id.replaceAll('zone', '')) ?? 0;
      return aNum.compareTo(bNum);
    });

    return parsed;
  }

  Future<void> addZone(String name, int duration) async {
    try {
      // Find next available ID
      int maxId = 0;
      for (final zone in zones) {
        final num = int.tryParse(zone.id.replaceAll('zone', '')) ?? 0;
        if (num > maxId) maxId = num;
      }
      final newId = 'zone${maxId + 1}';

      final newZoneData = {
        'name': name,
        'duration': duration,
        'active': false,
        'color': 4283215696, // Default green color
      };

      await _root.child('zones/$newId').set(newZoneData);
    } catch (e) {
      errorMessage = 'Erreur ajout zone: $e';
      notifyListeners();
    }
  }

  Future<void> updateZone(String id, String name, int duration) async {
    try {
      await _root.child('zones/$id').update({
        'name': name,
        'duration': duration,
      });
    } catch (e) {
      errorMessage = 'Erreur modification zone: $e';
      notifyListeners();
    }
  }

  Future<void> deleteZone(String id) async {
    try {
      await _root.child('zones/$id').remove();
    } catch (e) {
      errorMessage = 'Erreur suppression zone: $e';
      notifyListeners();
    }
  }

  int _zoneIndex(String zoneId) {
    return zones.indexWhere((zone) => zone.id == zoneId);
  }

  String _zoneSuffix(String zoneId) {
    final match = RegExp(r'\d+').firstMatch(zoneId);
    return match?.group(0) ?? zoneId;
  }

  Future<void> _recordHistory(String zoneId, int durationSeconds) async {
    if (durationSeconds <= 0) return;
    try {
      await _root.child('history').push().set({
        'zoneId': zoneId,
        'timestamp': DateTime.now().toIso8601String(),
        'duration': durationSeconds,
      });
    } catch (e) {
      print('Erreur enregistrement historique: $e');
    }
  }

  Future<void> setZoneActive(String zoneId, bool active) async {
    errorMessage = null; // Reset error message
    if (active) {
      final anyActive = zones.any((z) => z.id != zoneId && z.active);
      if (anyActive) {
        errorMessage = 'Une seule zone à la fois';
        notifyListeners();
        return;
      }
    }

    if (commandPending) {
      return;
    }
    try {
      _beginPending(type: 'zone', zoneId: zoneId, target: active);
      notifyListeners();
      await _root.child('commands/$zoneId').set(active);
      
      if (active) {
        // Start tracking time
        await _root.child('zones/$zoneId').update({
          'active': true,
          'startTime': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        // Stop tracking and record history
        final zone = zones.firstWhere(
          (z) => z.id == zoneId, 
          orElse: () => Zone(id: '?', name: '?', active: false, durationSeconds: 0, color: Colors.green)
        );
        
        if (zone.startTime != null) {
           final duration = (DateTime.now().millisecondsSinceEpoch - zone.startTime!) ~/ 1000;
           await _recordHistory(zoneId, duration);
        }
        
        await _root.child('zones/$zoneId').update({
          'active': false,
          'startTime': null,
        });
      }
    } catch (e) {
      _clearPending();
      errorMessage = 'Erreur commande zone: $e';
      notifyListeners();
    }
  }

  Future<void> setZoneDuration(String zoneId, int seconds) async {
    if (seconds < 1 || seconds > 86400) {
      errorMessage = 'Duree invalide: $seconds';
      notifyListeners();
      return;
    }
    if (commandPending) {
      return;
    }
    try {
      _beginPending(
        type: 'duration',
        timeout: const Duration(seconds: 4),
        showTimeoutError: false,
      );
      notifyListeners();
      final suffix = _zoneSuffix(zoneId);
      await _root.child('commands/setDuration$suffix').set(seconds);
    } catch (e) {
      _clearPending();
      errorMessage = 'Erreur duree zone: $e';
      notifyListeners();
    }
  }

  Future<void> setAutoRunning(bool enabled) async {
    errorMessage = null;
    if (commandPending || autoRunning == enabled) {
      return;
    }
    try {
      _beginPending(type: 'auto', target: enabled);
      notifyListeners();
      if (enabled) {
        await _root.child('commands/autoStart').set(true);
      } else {
        await _root.child('commands/autoStop').set(true);
      }
      // Mise à jour optimiste
      await _root.child('auto/running').set(enabled);
    } catch (e) {
      _clearPending();
      errorMessage = 'Erreur auto: $e';
      notifyListeners();
    }
  }

  Future<void> setBasinFilling(bool enabled) async {
    errorMessage = null;
    if (commandPending) {
      return;
    }
    try {
      _beginPending(type: 'basin', target: enabled);
      notifyListeners();
      if (enabled) {
        await _root.child('commands/basinStart').set(true);
      } else {
        await _root.child('commands/basinStop').set(true);
      }
      // Mise à jour optimiste
      await _root.child('basin/active').set(enabled);
    } catch (e) {
      _clearPending();
      errorMessage = 'Erreur bassin: $e';
      notifyListeners();
    }
  }

  Future<void> setPreValve(int seconds) async {
    if (seconds < 0 || seconds > 30) {
      errorMessage = 'Pre-valve invalide: $seconds';
      notifyListeners();
      return;
    }
    if (commandPending) {
      return;
    }
    try {
      _beginPending(
        type: 'preValve',
        timeout: const Duration(seconds: 4),
        showTimeoutError: false,
      );
      notifyListeners();
      await _root.child('commands/setPreValve').set(seconds);
    } catch (e) {
      _clearPending();
      errorMessage = 'Erreur pre-valve: $e';
      notifyListeners();
    }
  }

  Future<void> setPostPump(int seconds) async {
    if (seconds < 0 || seconds > 30) {
      errorMessage = 'Post-pompe invalide: $seconds';
      notifyListeners();
      return;
    }
    if (commandPending) {
      return;
    }
    try {
      _beginPending(
        type: 'postPump',
        timeout: const Duration(seconds: 4),
        showTimeoutError: false,
      );
      notifyListeners();
      await _root.child('commands/setPostPump').set(seconds);
    } catch (e) {
      _clearPending();
      errorMessage = 'Erreur post-pompe: $e';
      notifyListeners();
    }
  }

  Future<void> stopAll() async {
    errorMessage = null;
    if (commandPending) {
      return;
    }
    try {
      _beginPending(type: 'stopAll');
      notifyListeners();
      for (final zone in zones) {
        if (zone.active && zone.startTime != null) {
           final duration = (DateTime.now().millisecondsSinceEpoch - zone.startTime!) ~/ 1000;
           await _recordHistory(zone.id, duration);
        }
        await _root.child('commands/${zone.id}').set(false);
        // Mise à jour optimiste
        await _root.child('zones/${zone.id}').update({
          'active': false,
          'startTime': null,
        });
      }
      await _root.child('commands/autoStop').set(true);
      // Mise à jour optimiste
      await _root.child('auto/running').set(false);
    } catch (e) {
      _clearPending();
      errorMessage = 'Erreur stop total: $e';
      notifyListeners();
    }
  }

  void _beginPending({
    required String type,
    String? zoneId,
    bool? target,
    Duration timeout = const Duration(seconds: 12),
    bool showTimeoutError =
        false, // Désactivé par défaut pour éviter le message "Aucune réponse"
  }) {
    commandPending = true;
    _pendingType = type;
    _pendingZoneId = zoneId;
    _pendingTarget = target;
    _autoCommandTimer?.cancel();
    _autoCommandTimer = Timer(timeout, () {
      if (commandPending) {
        commandPending = false;
        _pendingType = null;
        _pendingZoneId = null;
        _pendingTarget = null;
        if (showTimeoutError) {
          // errorMessage = 'Aucune reponse de l\'ESP.'; // Message supprimé à la demande de l'utilisateur
        }
        notifyListeners();
      }
    });
  }

  void _clearPending() {
    commandPending = false;
    _pendingType = null;
    _pendingZoneId = null;
    _pendingTarget = null;
    _autoCommandTimer?.cancel();
    _autoCommandTimer = null;
  }

  void _checkPendingCompletion() {
    if (!commandPending || _pendingType == null) {
      return;
    }

    if (_pendingType == 'auto') {
      if (_pendingTarget == autoRunning) {
        _clearPending();
      }
      return;
    }

    if (_pendingType == 'basin') {
      if (_pendingTarget == basinActive) {
        _clearPending();
      }
      return;
    }

    if (_pendingType == 'zone' && _pendingZoneId != null) {
      final index = _zoneIndex(_pendingZoneId!);
      if (index >= 0 && zones[index].active == _pendingTarget) {
        _clearPending();
      }
      return;
    }

    if (_pendingType == 'stopAll') {
      final allOff = zones.every((zone) => zone.active == false);
      if (allOff && autoRunning == false) {
        _clearPending();
      }
    }
  }

  @override
  void dispose() {
    _zonesSub?.cancel();
    _schedulesSub?.cancel();
    _pumpSub?.cancel();
    _autoSub?.cancel();
    _statusSub?.cancel();
    _logSub?.cancel();
    _basinSub?.cancel();
    _autoCommandTimer?.cancel();
    super.dispose();
  }
}
