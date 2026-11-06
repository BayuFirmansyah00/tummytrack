// ignore_for_file: duplicate_import, unused_import, unused_field, unused_element

import 'package:TummyTrack/models/user_model.dart';
import 'package:TummyTrack/services/bluetoothservices.dart'; // Untuk BluetoothController & SensorDataService
import 'package:TummyTrack/services/matrasdataservices.dart'; // Untuk DatabaseService
import 'package:TummyTrack/models/baby_model.dart';
import 'package:TummyTrack/models/sensor_model.dart';
import 'package:TummyTrack/services/sensor_service_update.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:TummyTrack/models/tummy_time_state.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'achievement_screen.dart';
// note: removed unused imports (rive, matras_model, duplicate services)

// Asumsi MatrasData model sederhana (jika belum ada di matras_model.dart)
class MatrasData {
  final List<String> pressedButtons;
  final int count;
  final DateTime timestamp;

  MatrasData({
    required this.pressedButtons,
    required this.count,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'pressed_buttons': pressedButtons,
    'count': count,
    'timestamp': timestamp.toIso8601String(),
  };

  bool isActive() => count >= 15;
}

enum TimerState { initial, running, paused }

class TummyTimeScreen extends StatefulWidget {
  const TummyTimeScreen({super.key});

  @override
  _TummyTimeScreenState createState() => _TummyTimeScreenState();
}

class _TummyTimeScreenState extends State<TummyTimeScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 1;
  Timer? _timer;
  int _seconds = 0;
  int _minutes = 0;
  TimerState _currentState = TimerState.initial;
  late AnimationController _rotationController;
  late AnimationController _progressController;
  String _selectedMood = 'Normal';
  late int _maxDurationSeconds;
  int _remainingSeconds = 0;
  StreamSubscription? _matrasSubscription;
  StreamSubscription? _sensorSubscription;
  List<bool> _achievements = [false, false, false, false, false, false, false];
  final List<String> _achievementTexts = [];
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  List<List<bool>> _matrasGrid = List.generate(
    5,
    (_) => List.filled(11, false),
  );
  List<List<String>> pressbutton = []; // Inisialisasi di initState
  String? _lastButtonPressed;
  bool _isLoading = true;
  final bool _bluetoothConnected = false;
  String? _currentLinkedDeviceId;

  // Variabel sensor
  SensorData? _currentSensorData;
  MatrasData? _currentMatrasData;
  final List<SensorData> _sensorHistory = [];
  Timer? _averageTimer;
  String _babyActivity = 'tidak aktif';
  bool _toyInteraction = false;
  int _ultrasonicDistance = 0;
  int _piezoVibration = 0;
  int _avgUltrasonicDistance = 0;
  int _avgPiezoVibration = 0;
  int _pressedButtonCount = 0;
  Timer? _debugTimer;
  Timer? _connectionTestTimer;

  @override
  void initState() {
    super.initState();
    pressbutton = List.generate(1, (_) => <String>[]); // Inisialisasi kosong
    _initializeScreen();
    _currentLinkedDeviceId =
        Provider.of<UserModel>(context, listen: false).linkedDeviceId;
    _progressController = AnimationController(
      duration: const Duration(seconds: 120),
      vsync: this,
    );
    final babyModel = Provider.of<BabyModel>(context, listen: false);
    _fetchBabyData(babyModel);
    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    _initializeNotifications();
    _startAverageTimer();
    
    // TAMBAHAN: Auto refresh debug setiap 2 detik
    _debugTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _debugSensorValues();
      }
    });
    
    // TAMBAHAN: Test koneksi Firebase setiap 10 detik      if (_currentLinkedDeviceId != null && _currentLinkedDeviceId!.isNotEmpty) {
  if (_currentLinkedDeviceId != null && _currentLinkedDeviceId!.isNotEmpty) {
  _connectionTestTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
    if (mounted) {
      _testFirebaseConnection();
    }
  });
  }
  
    // TAMBAHAN: Setup listener untuk TummyTimeState (opsional, untuk debugging)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tummyState = Provider.of<TummyTimeState>(context, listen: false);
      print("[TummyTimeScreen] connected to TummyTimeState");
      tummyState.printDebugInfo();
    });
  }
  

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userModel = Provider.of<UserModel>(context);

    if (userModel.linkedDeviceId != _currentLinkedDeviceId) {
      _currentLinkedDeviceId = userModel.linkedDeviceId;
      _matrasSubscription?.cancel();
      _sensorSubscription?.cancel();
      if (_currentLinkedDeviceId != null && _currentLinkedDeviceId!.isNotEmpty) {
        print("Linked device changed. Subscribing to matras & sensor...");
        _subscribeToMatrasData();
        _subscribeToSensorData();
      } else {
        print("No linked device. Stopping subscriptions.");
        _resetSensorData();
      }
    }
  }

void _subscribeToSensorData() {
  _sensorSubscription?.cancel();

  final userModel = Provider.of<UserModel>(context, listen: false);
  final tummyState = Provider.of<TummyTimeState>(context, listen: false);
  if (userModel.linkedDeviceId == null || userModel.linkedDeviceId!.isEmpty) {
    print("❌ Sensor subscription failed: No linked device.");
    return;
  }

  print("[TummyTimeScreen] Starting sensor subscription for device: ${userModel.linkedDeviceId}");

  final sensorService = SensorDataService(userModel);

  // Optionally test connection
  sensorService.testFirebaseConnection().then((r) => print("[SensorService] test: $r")).catchError((e) => print("[SensorService] test failed: $e"));

  _sensorSubscription = sensorService.getCombinedSensorDataStream().listen(
    (data) {
      print("\n[Sensor] Data received: $data");
      if (!mounted) return;

      final babyModel = Provider.of<BabyModel>(context, listen: false);
      final ageDays = babyModel.birthDate != null
          ? DateTime.now().difference(babyModel.birthDate!).inDays
          : 0;

      // Update centralized state
      tummyState.updateSensorData(
        ultrasonic: data['ultrasonic'] ?? 0,
        piezo: data['piezo'] ?? 0,
        babyAgeDays: ageDays,
      );

      // Sync into local UI variables
      setState(() {
        _ultrasonicDistance = tummyState.ultrasonicDistance;
        _piezoVibration = tummyState.piezoVibration;
        _babyActivity = tummyState.babyActivity;
        _toyInteraction = tummyState.toyInteraction;
        // keep small history for UI charts if desired
        _sensorHistory.add(SensorData(
          ultrasonicDistance: _ultrasonicDistance,
          piezoVibration: _piezoVibration,
          toyInteraction: _toyInteraction,
          timestamp: DateTime.now(),
        ));
        if (_sensorHistory.length > 10) _sensorHistory.removeAt(0);
      });

      print("[Sensor] State updated via TummyTimeState (session readings: ${tummyState.sessionSensorReadingsCount})");
    },
    onError: (error) {
      print("❌ Error listening to sensor stream: $error");
    },
    onDone: () => print("[Sensor] Stream closed"),
  );

  print("[TummyTimeScreen] Sensor subscription is now active.");
}

void _calculateBabyActivity(String sensorActivity, bool hasToyInteraction) {
  print("\n=== CALCULATING BABY ACTIVITY ===");
  print("📊 Sensor Activity: $sensorActivity");
  print("🎮 Has Toy Interaction: $hasToyInteraction");
  print("🔢 Pressed Button Count: $_pressedButtonCount");
  print("📏 Ultrasonic Distance: $_ultrasonicDistance cm");
  print("🔊 Piezo Vibration: $_piezoVibration units");
  
  bool matrasActive = _pressedButtonCount >= 15;
  bool sensorActive = sensorActivity == 'aktif';
  
  // Perbaikan: Logika ultrasonic spesifik
  bool ultrasonicActive = (_ultrasonicDistance > 0 && _ultrasonicDistance < 60);
  print("📏 Ultrasonic Active (<60cm): $ultrasonicActive");
  
  print("✅ Matras Active (>=15 buttons): $matrasActive");
  print("✅ Sensor Active: $sensorActive");

  // Logika prioritas:
  // 1. Jika matras aktif (>=15 button) → AKTIF
  // 2. Jika sensor aktif atau toy interaction atau ultrasonic active → AKTIF
  // 3. Jika ada button tapi < 15 → KURANG BERINTERAKSI
  // 4. Sisanya → TIDAK AKTIF
  
  if (matrasActive) {
    _babyActivity = 'aktif';
    print("✅ Result: AKTIF (matras >= 15 buttons)");
  } else if (sensorActive || hasToyInteraction || ultrasonicActive) {
    _babyActivity = 'aktif';
    print("✅ Result: AKTIF (sensor active or toy interaction or ultrasonic <60cm)");
  } else if (_pressedButtonCount > 0 && _pressedButtonCount < 15) {
    _babyActivity = 'kurang berinteraksi';
    print("⚠️ Result: KURANG BERINTERAKSI (0 < buttons < 15)");
  } else {
    _babyActivity = 'tidak aktif';
    print("❌ Result: TIDAK AKTIF");
  }
  
  _toyInteraction = hasToyInteraction || _pressedButtonCount > 0;
  
  print("🎮 Final Toy Interaction: $_toyInteraction");
  print("👶 Final Baby Activity: $_babyActivity");
  print("=================================\n");
  
  if (mounted) setState(() {});
}

  void _startAverageTimer() {
    _averageTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_sensorHistory.isNotEmpty) {
        final avgDistance = _sensorHistory
            .map((s) => s.ultrasonicDistance)
            .reduce((a, b) => a + b) ~/
            _sensorHistory.length;
        final avgVibration = _sensorHistory
            .map((s) => s.piezoVibration)
            .reduce((a, b) => a + b) ~/
            _sensorHistory.length;
        _avgUltrasonicDistance = avgDistance;
        _avgPiezoVibration = avgVibration;
        _sensorHistory.clear();
        if (mounted) setState(() {});
      }
    });
  }

  void _debugSensorValues() {
    final userModel = Provider.of<UserModel>(context, listen: false);
    print("\n🔍 === DEBUG SENSOR VALUES ===");
    print("Device ID: ${userModel.linkedDeviceId}");
    print("Device ID Length: ${userModel.linkedDeviceId?.length}");
    print("Device ID Format: ${userModel.linkedDeviceId != null && userModel.linkedDeviceId!.contains(':') ? 'with colon' : 'without colon'}");
    print("Ultrasonic Distance: $_ultrasonicDistance cm");
    print("Piezo Vibration: $_piezoVibration units");
    print("Toy Interaction: $_toyInteraction");
    print("Baby Activity: $_babyActivity");
    print("Pressed Button Count: $_pressedButtonCount");
    print("Current Sensor Data: ${_currentSensorData?.toJson()}");
    print("Sensor History Length: ${_sensorHistory.length}");
    print("Subscription Active: ${_sensorSubscription != null}");
    print("Matras Subscription Active: ${_matrasSubscription != null}");
    print("Firebase Database URL: ${FirebaseDatabase.instance.app.options.databaseURL}");
    
    // Test possible paths
    final possiblePaths = [
      'devices/${userModel.linkedDeviceId}/sensorData/ultrasonic',
      'devices/${userModel.linkedDeviceId}/ultrasonic',
      '${userModel.linkedDeviceId}/sensorData/ultrasonic',
      '${userModel.linkedDeviceId}/ultrasonic',
    ];
    
    print("Possible Firebase paths:");
    for (int i = 0; i < possiblePaths.length; i++) {
      print("  ${i + 1}. ${possiblePaths[i]}");
    }
    
    print("=== END DEBUG ===\n");
  }

  void _resetSensorData() {
    setState(() {
      _currentSensorData = null;
      _currentMatrasData = null;
      _babyActivity = 'tidak aktif';
      _toyInteraction = false;
      _sensorHistory.clear();
      _ultrasonicDistance = 0;
      _piezoVibration = 0;
      _avgUltrasonicDistance = 0;
      _avgPiezoVibration = 0;
      _pressedButtonCount = 0;
      pressbutton = List.generate(1, (_) => <String>[]);
    });
  }

  void _subscribeToMatrasData() {
    _matrasSubscription?.cancel();
    final userModel = Provider.of<UserModel>(context, listen: false);
    final tummyState = Provider.of<TummyTimeState>(context, listen: false);
    if (userModel.linkedDeviceId == null || userModel.linkedDeviceId!.isEmpty) {
      print("❌ Matras subscription failed: No linked device.");
      return;
    }

    print("[TummyTimeScreen] Starting matras subscription for device: ${userModel.linkedDeviceId}");
    final dbService = DatabaseService(userModel);
    _matrasSubscription = dbService.getMatrasDataStream().listen(
      (pressedButtons) {
        if (mounted) {
          print("\n[Matras] Data received: ${pressedButtons.length} buttons");

          // Update centralized state
          tummyState.updateMatrasData(pressedButtons);

          // Sync local UI state from tummyState
          setState(() {
            _matrasGrid = tummyState.matrasGrid;
            _pressedButtonCount = tummyState.pressedButtonCount;
            _babyActivity = tummyState.babyActivity;
            _toyInteraction = tummyState.toyInteraction;
            _currentMatrasData = MatrasData(
              pressedButtons: tummyState.accumulatedButtons,
              count: tummyState.accumulatedButtonCount,
              timestamp: DateTime.now(),
            );
          });

          print("[Matras] State updated via TummyTimeState (accumulated: ${tummyState.accumulatedButtonCount})");
        }
      },
      onError: (error) {
        print("❌ Error in matras stream: $error");
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _averageTimer?.cancel();
    _debugTimer?.cancel();
    _connectionTestTimer?.cancel(); // TAMBAHAN
    _rotationController.dispose();
    _progressController.dispose();
    _matrasSubscription?.cancel();
    _sensorSubscription?.cancel();
    super.dispose();
  }

  void _resetTimer() {
    HapticFeedback.lightImpact();
    _timer?.cancel();
    _progressController.reset();

    final babyModel = Provider.of<BabyModel>(context, listen: false);
    final tummyState = Provider.of<TummyTimeState>(context, listen: false);
    _setDurationAndAchievements(babyModel);

    setState(() {
      _currentState = TimerState.initial;
      _seconds = _remainingSeconds % 60;
      _minutes = _remainingSeconds ~/ 60;
      _matrasGrid = List.generate(5, (_) => List.filled(11, false));
      _lastButtonPressed = null;
    });

    // Reset via TummyTimeState so accumulated session data cleared
    tummyState.resetState();
    print("[TummyTimeScreen] Session reset via TummyTimeState");
  }

  Future<void> _scheduleNextNotification() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final now = DateTime.now();
        final nextTime = now.add(const Duration(minutes: 1));
        final matrasTime = now.add(const Duration(minutes: 2));
        print("Scheduling notification at: $nextTime");
        await flutterLocalNotificationsPlugin.zonedSchedule(
          0,
          'Tummy Time Reminder',
          'Waktunya bayi Anda melaksanakan Tummy Time',
          tz.TZDateTime.from(nextTime, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'tummy_time_channel',
              'Tummy Time Notifications',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        print("Notification scheduled");
        await FirebaseFirestore.instance.collection('notifications').add({
          'user_id': user.uid,
          'type': 'tummy_time_reminder',
          'message': 'Waktunya bayi Anda melaksanakan Tummy Time',
          'timestamp': Timestamp.fromDate(nextTime),
          'is_read': false,
        });
        await FirebaseFirestore.instance.collection('notifications').add({
          'user_id': user.uid,
          'type': 'mat_connection_status',
          'message': 'Saatnya untuk Tummy Time di matras',
          'timestamp': Timestamp.fromDate(matrasTime),
          'is_read': false,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notifikasi dijadwalkan')),
          );
        }
      }
    } catch (e) {
      print("Notification error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menjadwalkan notifikasi: $e')),
        );
      }
    }
  }

List<String> _getPressedButtons() {
  List<String> pressed = [];
  
  // Jika ada data matras dari stream, gunakan itu
    if (_currentMatrasData != null && _currentMatrasData!.pressedButtons.isNotEmpty) {
    pressed = _currentMatrasData!.pressedButtons;
    print("\n=== GET PRESSED BUTTONS (from stream) ===");
    print("Pressed count: ${pressed.length}");
    print("Pressed list: $pressed");
  } 
  // Fallback: scan dari grid jika stream tidak ada data
  else {
    for (int row = 0; row < 5; row++) {
      for (int col = 0; col < 11; col++) {
        if (_matrasGrid[row][col]) {
          pressed.add(buttonLabels[row][col]);
        }
      }
    }
    print("\n=== GET PRESSED BUTTONS (from grid) ===");
    print("Grid state scan - Pressed count: ${pressed.length}");
    print("Pressed list: $pressed");
  }
  
  print("=== END GET PRESSED ===\n");
  return pressed;
}

// =====================================================================
// PERBAIKAN 2: Update fungsi _saveTummyTimeSession() 
// Pastikan menggunakan data yang benar
// =====================================================================
    
Future<void> _saveTummyTimeSession() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    final babyModel = Provider.of<BabyModel>(context, listen: false);
    final tummyState = Provider.of<TummyTimeState>(context, listen: false);
    
    if (user == null || babyModel.babyId == null) {
      print("âŒ Cannot save: user or babyId is null");
      return;
    }

    final now = DateTime.now();
    final duration = _maxDurationSeconds - _remainingSeconds;
    
    // Hitung usia bayi dalam hari
    final babyAgeDays = babyModel.birthDate != null
        ? now.difference(babyModel.birthDate!).inDays
        : 0;
    
    // Tentukan sensor type yang digunakan berdasarkan usia
    String sensorTypeUsed = 'unknown';
    if (babyAgeDays <= 90) {
      sensorTypeUsed = 'piezo_sensor_0_3_months';
    } else if (babyAgeDays <= 180) {
      sensorTypeUsed = 'ultrasonic_sensor_4_6_months';
    } else {
      sensorTypeUsed = 'combined_sensors_6plus_months';
    }

    print("\n[INFO] === SAVING SESSION FROM TUMMYTIMESTATE ===");

    // Get session summary from state
    final sessionSummary = tummyState.getSessionSummary(babyAgeDays: babyAgeDays);

    var pressedButtons = List<String>.from(sessionSummary['buttons'] ?? []);

    // If there are no accumulated buttons (subscription timing issue), try a one-time read
    if (pressedButtons.isEmpty) {
      try {
        final userModelForDb = Provider.of<UserModel>(context, listen: false);
        final dbService = DatabaseService(userModelForDb);
        final fetched = await dbService.getMatrasButtonsOnce();
        if (fetched.isNotEmpty) {
          pressedButtons = fetched.toList();
          print('[INFO] Fallback: fetched ${pressedButtons.length} matras buttons via one-time DB read');
        } else {
          print('[INFO] Fallback read returned no buttons');
        }
      } catch (e) {
        print('[WARN] Fallback matras read failed: $e');
      }
    }
    final avgUltrasonic = sessionSummary['avg_ultrasonic'] ?? 0;
    final avgPiezo = sessionSummary['avg_piezo'] ?? 0;
    final finalActivity = sessionSummary['baby_activity'] ?? 'tidak aktif';
    final toyInteraction = sessionSummary['toy_interaction'] ?? false;

    // Build sensor data structure
    final sensorData = {
      'avg_ultrasonic_distance': avgUltrasonic,
      'avg_piezo_vibration': avgPiezo,
      'baby_activity': finalActivity,
      'toy_interaction': toyInteraction,
      'active_percentage': finalActivity == 'aktif' ? 100 : (finalActivity == 'kurang berinteraksi' ? 50 : 0),
      'toy_interaction_percentage': toyInteraction ? 75 : 0,
      'sensor_data_available': (avgUltrasonic > 0 || avgPiezo > 0),
      'ultrasonic_active': (avgUltrasonic > 0 && avgUltrasonic < 60),
      'piezo_active': (avgPiezo > 5),
      'matras_active': (pressedButtons.length >= 15),
      'sensor_read_timestamp': FieldValue.serverTimestamp(),
    };

    final sessionData = {
      'date': Timestamp.fromDate(now),
      'duration': '${(sessionSummary['session_duration'] ?? duration) ~/ 60} menit ${(sessionSummary['session_duration'] ?? duration) % 60} detik',
      'duration_seconds': sessionSummary['session_duration'] ?? duration,
      'mood': _selectedMood,
      'achievements': _achievements,
      'achievement_texts': _achievementTexts,
      'matras_buttons': pressedButtons,
      'matras_button_count': pressedButtons.length,
      'sensor_data': sensorData,
      'baby_age_days': babyAgeDays,
      'sensor_type_used': sensorTypeUsed,
      'session_timestamp': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
      'data_version': '2.0',
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('babies')
        .doc(babyModel.babyId)
        .collection('tummy_time_sessions')
        .add(sessionData);

    print("[INFO] Session saved successfully with ${pressedButtons.length} buttons");

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sesi tersimpan: ${pressedButtons.length} button, Sensor: ${sensorTypeUsed.replaceAll('_', ' ')}'),
          backgroundColor: Colors.green,
        ),
      );
    }
    
  } catch (e, stackTrace) {
    print('[ERROR] Save session error: $e');
    print('Stack trace: $stackTrace');
  }
}

void _resetAfterSave() {
  setState(() {
    // Reset sensor history
    _sensorHistory.clear();
    
    // Reset nilai sensor (PENTING: jangan reset ke 0 jika stream masih aktif)
    // Biarkan nilai terakhir tetap ada untuk referensi
    // _ultrasonicDistance akan diupdate oleh stream berikutnya
    // _piezoVibration akan diupdate oleh stream berikutnya
    
    // Reset status
    _babyActivity = 'tidak aktif';
    _toyInteraction = false;
    _pressedButtonCount = 0;
    
    // Reset grid
    _matrasGrid = List.generate(5, (_) => List.filled(11, false));
    
    // Reset current sensor data
    _currentSensorData = null;
    _currentMatrasData = null;
    
    print("🔄 State reset after save (sensor values preserved for stream)");
  });
}

void _debugSensorBeforeSave() {
  print("\n🔍 === DEBUG SENSOR BEFORE SAVE ===");
  print("State values:");
  print("  _ultrasonicDistance: $_ultrasonicDistance cm");
  print("  _piezoVibration: $_piezoVibration units");
  print("  _pressedButtonCount: $_pressedButtonCount");
  print("  _babyActivity: $_babyActivity");
  print("  _toyInteraction: $_toyInteraction");
  
  print("\nHistory:");
  print("  _sensorHistory.length: ${_sensorHistory.length}");
  if (_sensorHistory.isNotEmpty) {
    print("  Last reading: ${_sensorHistory.last.toJson()}");
  }
  
  print("\nCurrent data:");
  print("  _currentSensorData: ${_currentSensorData?.toJson()}");
  print("  _currentMatrasData: ${_currentMatrasData?.toJson()}");
  
  print("\nStream status:");
  print("  _sensorSubscription active: ${_sensorSubscription != null}");
  print("  _matrasSubscription active: ${_matrasSubscription != null}");
  
  print("=== END DEBUG ===\n");
}

// =====================================================================
// UPDATE: Panggil reset setelah dialog ditutup
// =====================================================================
Future<void> _showAchievementDialog() async {
  final result = await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AchievementScreen(
        duration:
            '${(_maxDurationSeconds - _remainingSeconds) ~/ 60} menit ${(_maxDurationSeconds - _remainingSeconds) % 60} detik',
        mood: _selectedMood,
        achievements: List<bool>.from(_achievements),
        onClose: () {
          // kept for compatibility - dialog will return result via Navigator.pop
          Navigator.of(context).pop();
        },
      );
    },
  );

  // If AchievementScreen returned selected achievements, apply them
  if (result != null && result is Map<String, dynamic>) {
    setState(() {
      try {
        final ach = result['achievements'];
        if (ach is List) {
          _achievements = List<bool>.from(ach.map((e) => e == true));
        }
        final texts = result['achievement_texts'];
        if (texts is List) {
          _achievementTexts.clear();
          _achievementTexts.addAll(texts.map((e) => e.toString()));
        }
      } catch (e) {
        print('[WARN] Failed to apply achievements from dialog: $e');
      }
    });
  }

  // Save consolidated session once
  await _saveTummyTimeSession();

  // Now reset timers & central session state
  _resetTimer();

  // Reset screen-local state after save
  _resetAfterSave();

  // Schedule notification
  _scheduleNextNotification();
}

  String get _formattedTime {
    return '${_minutes.toString().padLeft(2, '0')}:${_seconds.toString().padLeft(2, '0')}';
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _navigateTo(index);
  }

  // Inisialisasi controller menggunakan Get.put()
  final BluetoothController controller = Get.put(BluetoothController());

  final TextEditingController _searchController = TextEditingController();
  final RxString searchQuery = ''.obs;

  void showBluetoothDialog(
    BluetoothController controller,
    TextEditingController searchController,
    RxString searchQuery,
  ) {
    controller.scanDevices();
    searchController.clear();
    searchQuery.value = '';

    Get.dialog(
      Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Cari Perangkat Bluetooth',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF7DD3D8),
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              controller.stopScan();
              Get.back();
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: () {
                controller.scanDevices();
              },
              tooltip: 'Pindai Ulang',
            ),
          ],
        ),
        body: Column(
          children: [
            // Header with Search and Status (sama seperti kode asli Anda)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF7DD3D8),
                    const Color(0xFF7DD3D8).withOpacity(0.1),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
              child: Column(
                children: [
                  // Search Bar (sama seperti asli)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: searchController,
                      onChanged: (value) {
                        searchQuery.value = value;
                      },
                      decoration: InputDecoration(
                        hintText: 'Cari berdasarkan nama atau alamat...',
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF7DD3D8),
                          size: 24,
                        ),
                        suffixIcon: Obx(
                          () => searchQuery.value.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    searchController.clear();
                                    searchQuery.value = '';
                                  },
                                )
                              : const SizedBox(),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Status Info (sama seperti asli)
                  Obx(
                    () => Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: controller.isScanning.value
                            ? const Color(0xFF7DD3D8).withOpacity(0.1)
                            : Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: controller.isScanning.value
                              ? const Color(0xFF7DD3D8).withOpacity(0.3)
                              : Colors.grey.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (controller.isScanning.value) ...[
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF7DD3D8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Sedang memindai perangkat...',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                            ),
                          ] else ...[
                            Icon(
                              controller.discoveredDevices.isNotEmpty
                                  ? Icons.bluetooth_rounded
                                  : Icons.bluetooth_disabled_rounded,
                              color: controller.discoveredDevices.isNotEmpty
                                  ? const Color(0xFF7DD3D8)
                                  : Colors.grey[600],
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                controller.discoveredDevices.isNotEmpty
                                    ? '${controller.discoveredDevices.length} perangkat ditemukan'
                                    : 'Tidak ada perangkat ditemukan',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: controller.discoveredDevices.isNotEmpty
                                      ? const Color(0xFF2C3E50)
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Obx(() {
                final filteredDevices = controller.discoveredDevices.where((result) {
                  if (searchQuery.value.isEmpty) return true;
                  final device = result.device;
                  final deviceName = (device.name ?? "perangkat tidak dikenal").toLowerCase();
                  final deviceAddress = device.address.toLowerCase();
                  final query = searchQuery.value.toLowerCase();
                  return deviceName.contains(query) || deviceAddress.contains(query);
                }).toList();

                if (!controller.isScanning.value && controller.discoveredDevices.isEmpty) {
                  return _buildEmptyState();
                }

                if (searchQuery.value.isNotEmpty && filteredDevices.isEmpty) {
                  return _buildNoSearchResults();
                }

                return Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (searchQuery.value.isNotEmpty && filteredDevices.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7DD3D8).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Menampilkan ${filteredDevices.length} dari ${controller.discoveredDevices.length} perangkat',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7DD3D8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: ListView.separated(
                          itemCount: filteredDevices.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final result = filteredDevices[index];
                            return _buildDeviceCard(controller, result);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
      barrierDismissible: false,
      useSafeArea: false,
    );
  }

  // Helper functions untuk Bluetooth Dialog (sama seperti kode asli Anda)
  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bluetooth_disabled_rounded,
                size: 64,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tidak Ada Perangkat Ditemukan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Pastikan perangkat Bluetooth dalam mode pairing dan berada dalam jangkauan.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
                            textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                controller.scanDevices();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Pindai Sekarang'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7DD3D8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 64,
                color: Colors.orange[600],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tidak Ada Hasil Pencarian',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Obx(
              () => Text(
                'Tidak ditemukan perangkat dengan kata kunci "${searchQuery.value}"',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    searchQuery.value = '';
                  },
                  icon: const Icon(Icons.clear_all_rounded),
                  label: const Text('Hapus Filter'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange[600],
                    side: BorderSide(color: Colors.orange[300]!),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    controller.scanDevices();
                    _searchController.clear();
                    searchQuery.value = '';
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Pindai Ulang'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7DD3D8),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(
    BluetoothController controller,
    BluetoothDiscoveryResult result,
  ) {
    final device = result.device;
    final deviceName = device.name ?? "Perangkat Tidak Dikenal";

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF7DD3D8).withOpacity(0.2),
          child: Icon(Icons.bluetooth_rounded, color: const Color(0xFF7DD3D8)),
        ),
        title: Text(
          deviceName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(device.address),
        trailing: ElevatedButton(
          onPressed: () async {
            Get.snackbar(
              "Menyambungkan...",
              "Mencoba terhubung ke ${device.name ?? device.address}",
              showProgressIndicator: true,
              isDismissible: false,
            );

await controller.connectToDevice(device);

if (controller.connectionStatus.value == 'connected') {
  final userModel = Provider.of<UserModel>(context, listen: false);
  
  // Gunakan Bluetooth address langsung, buang colon
  String macAddress = device.address.replaceAll(":", "").toUpperCase();
  print("[MAC] Using Bluetooth address: $macAddress");
  
  userModel.setLinkedDevice(macAddress);
  print("Device linked: $macAddress");

  showWifiConfigDialog(controller);
}
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7DD3D8),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Sambung'),
        ),
      ),
    );
  }

  // Helper functions untuk device
  IconData _getDeviceIcon(String deviceName) {
    final name = deviceName.toLowerCase();
    if (name.contains('headphone') || name.contains('earphone')) {
      return Icons.headphones_rounded;
    } else if (name.contains('speaker')) {
      return Icons.speaker_rounded;
    } else if (name.contains('mouse')) {
      return Icons.mouse_rounded;
    } else if (name.contains('keyboard')) {
      return Icons.keyboard_rounded;
    } else if (name.contains('phone')) {
      return Icons.smartphone_rounded;
    } else if (name.contains('watch')) {
      return Icons.watch_rounded;
    } else if (name.contains('sensor') || name.contains('matras')) {
      return Icons.sensors_rounded;
    }
    return Icons.bluetooth_rounded;
  }

  Color _getDeviceColor(String deviceName) {
    final name = deviceName.toLowerCase();
    if (name.contains('sensor') || name.contains('matras')) {
      return const Color(0xFF4CAF50);
    } else if (name.contains('audio') ||
        name.contains('speaker') ||
        name.contains('headphone')) {
      return const Color(0xFF9C27B0);
    } else if (name.contains('phone') || name.contains('watch')) {
      return const Color(0xFF2196F3);
    }
    return const Color(0xFF7DD3D8);
  }

  String _getDeviceCategory(String deviceName) {
    final name = deviceName.toLowerCase();
    if (name.contains('sensor') || name.contains('matras')) {
      return 'Sensor';
    } else if (name.contains('headphone') || name.contains('earphone')) {
      return 'Audio';
    } else if (name.contains('speaker')) {
      return 'Audio';
    } else if (name.contains('mouse') || name.contains('keyboard')) {
      return 'Input';
    } else if (name.contains('phone')) {
      return 'Mobile';
    } else if (name.contains('watch')) {
      return 'Wearable';
    }
    return 'Perangkat';
  }

  IconData _getSignalIcon(int rssi) {
    if (rssi >= -50) {
      return Icons.signal_cellular_4_bar_rounded;
    } else if (rssi >= -70) {
      return Icons.signal_cellular_alt_2_bar_rounded;
    } else {
      return Icons.signal_cellular_alt_1_bar_rounded;
    }
  }

  String _getSignalText(int rssi) {
    if (rssi >= -50) {
      return 'Kuat';
    } else if (rssi >= -70) {
      return 'Sedang';
    } else {
      return 'Lemah';
    }
  }

  Color _getSignalColor(int rssi) {
    if (rssi >= -50) {
      return Colors.green;
    } else if (rssi >= -70) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required bool isActive,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  // Helper method untuk statistics item
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF9CA3AF),
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildIcon(String assetPath, IconData fallbackIcon) {
    return Image.asset(
      assetPath,
      width: 24,
      height: 24,
      errorBuilder: (context, error, stackTrace) {
        return Icon(fallbackIcon, size: 24);
      },
    );
  }

  void _navigateTo(int index) {
    String route;
    switch (index) {
      case 0:
        route = '/dashboard';
        break;
      case 1:
        return;
      case 2:
        route = '/history';
        break;
      case 3:
        route = '/profile';
        break;
      default:
        return;
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  Widget _buildBluetoothSection(BluetoothController controller) {
    return Obx(() {
      final bool isConnected = controller.connectionStatus.value == 'connected';
      final deviceName =
          controller.connectedDevice?.name ??
          controller.connectedDevice?.address ??
          'perangkat';

      return Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A3FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bluetooth,
                  color: Color(0xFF00A3FF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bluetooth Connection',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Hubungkan ke sensor matras',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isConnected
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isConnected
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: isConnected
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF6B7280),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isConnected
                        ? 'Terhubung ke $deviceName'
                        : 'Belum terhubung ke perangkat',
                    style: TextStyle(
                      fontSize: 12,
                      color: isConnected
                          ? const Color(0xFF166534)
                          : const Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                if (isConnected) {
                  controller.disconnectFromDevice();
                  final userModel = Provider.of<UserModel>(context, listen: false);
                  userModel.setLinkedDevice(null);
                } else {
                  showBluetoothDialog(
                    controller,
                    _searchController,
                    searchQuery,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnected
                    ? Colors.redAccent.withOpacity(0.9)
                    : const Color(0xFF00A3FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isConnected ? Icons.link_off : Icons.bluetooth_searching,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isConnected ? 'Putuskan Sambungan' : 'Cari & Hubungkan',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildTimerSection() {
    String statusText;
    Color statusColor;
    String sessionText;
    String buttonText;
    IconData buttonIcon;
    Color buttonColor;
    Color shadowColor;

    switch (_currentState) {
      case TimerState.running:
        statusText = 'Berjalan';
        statusColor = const Color(0xFF4CAF50);
        sessionText = 'Sesi Aktif';
        buttonText = 'Jeda';
        buttonIcon = Icons.pause;
        buttonColor = const Color(0xFFEF4444);
        shadowColor = Colors.red;
        break;
      case TimerState.paused:
        statusText = 'Dijeda';
        statusColor = const Color(0xFFFFA726);
        sessionText = 'Sesi Dijeda';
        buttonText = 'Lanjut';
        buttonIcon = Icons.play_arrow;
        buttonColor = Colors.blue;
        shadowColor = Colors.blue;
        break;
  case TimerState.initial:
        statusText = 'Siap';
        statusColor = const Color(0xFF6B7280);
        sessionText = 'Siap Mulai';
        buttonText = 'Mulai';
        buttonIcon = Icons.play_arrow;
        buttonColor = const Color(0xFF4CAF50);
        shadowColor = const Color(0xFF4CAF50);
        break;
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tummy Time Timer',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E1E1E),
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Lacak durasi tummy time',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: 280,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
                            Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF8F9FA),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                ),
              ),

              // Progress Ring
              CustomPaint(
                size: const Size(280, 280),
                painter: EnhancedProgressPainter(
                  1.0 - (_remainingSeconds / _maxDurationSeconds),
                  _currentState == TimerState.running,
                ),
              ),

              // Center Content
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Timer Display
                  Text(
                    _formattedTime,
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E1E1E),
                      letterSpacing: -1,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Session Info
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A3FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      sessionText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00A3FF),
                      ),
                    ),
                  ),
                ],
              ),

              // Control Button
              Positioned(
                bottom: 20,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _handleStateChange,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(buttonIcon, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          buttonText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: _buildQuickAction(
                icon: Icons.refresh,
                label: 'Reset',
                onTap: _resetTimer,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

void showWifiConfigDialog(BluetoothController controller) {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController ssidController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    var isLoading = false.obs;
    var isPasswordVisible = false.obs;

    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: Get.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Section (Tidak berubah)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF79BCC1), Color(0xFF9FD3D7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.wifi_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Konfigurasi WiFi',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Hubungkan matras ke jaringan',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // --- PERBAIKAN DI SINI ---
              // Agar konten tidak overflow saat keyboard muncul, kita buat agar bisa di-scroll
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Description (Tidak berubah)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF79BCC1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF79BCC1).withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: const Color(0xFF79BCC1),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Masukkan kredensial WiFi yang akan digunakan oleh matras sensor untuk terhubung ke internet.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF374151),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // SSID Field (Tidak berubah)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Nama WiFi (SSID)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF374151),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: ssidController,
                                decoration: InputDecoration(
                                  hintText: 'Masukkan nama WiFi',
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(12),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF79BCC1,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.wifi,
                                      color: Color(0xFF79BCC1),
                                      size: 20,
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF79BCC1),
                                      width: 2,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Colors.red,
                                      width: 1,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'SSID tidak boleh kosong';
                                  }
                                  if (value.length < 1 || value.length > 32) {
                                    return 'SSID harus antara 1-32 karakter';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Password Field (Tidak berubah)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Password WiFi',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF374151),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Obx(
                                () => TextFormField(
                                  controller: passwordController,
                                  obscureText: !isPasswordVisible.value,
                                  decoration: InputDecoration(
                                    hintText: 'Masukkan password WiFi',
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    prefixIcon: Container(
                                      margin: const EdgeInsets.all(12),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF79BCC1,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.lock_outline_rounded,
                                        color: Color(0xFF79BCC1),
                                        size: 20,
                                      ),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        isPasswordVisible.value
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: Colors.grey[600],
                                      ),
                                      onPressed:
                                          () =>
                                              isPasswordVisible.value =
                                                  !isPasswordVisible.value,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF79BCC1),
                                        width: 2,
                                      ),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: Colors.red,
                                        width: 1,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Password tidak boleh kosong';
                                    }
                                    if (value.length < 8) {
                                      return 'Password minimal 8 karakter';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Security Note (Tidak berubah)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.yellow[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.yellow[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.security_outlined,
                                  color: Colors.orange[700],
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Data akan dikirim dengan aman ke matras sensor',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF92400E),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Action Buttons (Tidak berubah)
              Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: () {
                          controller.disconnectFromDevice();
                          Get.back();
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Batal',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Obx(
                        () => Container(
                          decoration: BoxDecoration(
                            gradient:
                                isLoading.value
                                    ? null
                                    : const LinearGradient(
                                      colors: [
                                        Color(0xFF79BCC1),
                                        Color(0xFF9FD3D7),
                                      ],
                                    ),
                            color: isLoading.value ? Colors.grey[300] : null,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow:
                                isLoading.value
                                    ? null
                                    : [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF79BCC1,
                                        ).withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                          ),
                          child: ElevatedButton.icon(
                            icon:
                                isLoading.value
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const Icon(
                                      Icons.send_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                            label: Text(
                              isLoading.value
                                  ? 'Mengirim...'
                                  : 'Kirim & Konfigurasi',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed:
                                isLoading.value
                                    ? null
                                    : () async {
                                      if (formKey.currentState!.validate()) {
                                        isLoading.value = true;
                                        String ssid =
                                            ssidController.text.trim();
                                        String password =
                                            passwordController.text;
                                        String dataToSend =
                                            "SSID:$ssid|PASS:$password\n";

                                        try {
                                          await controller.sendData(dataToSend);

                                          // Enhanced timeout handling
                                          Future.delayed(
                                            const Duration(seconds: 15),
                                            () {
                                              if (Get.isDialogOpen ?? false) {
                                                isLoading.value = false;
                                                Get.snackbar(
                                                  "Timeout",
                                                  "Tidak ada respon dari perangkat. Pastikan kredensial WiFi benar dan coba lagi.",
                                                  backgroundColor:
                                                      Colors.orange[400],
                                                  colorText: Colors.white,
                                                  snackPosition:
                                                      SnackPosition.TOP,
                                                  borderRadius: 12,
                                                  margin: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                  icon: const Icon(
                                                    Icons.warning_amber_rounded,
                                                    color: Colors.white,
                                                  ),
                                                );
                                              }
                                            },
                                          );
                                        } catch (e) {
                                          isLoading.value = false;
                                          Get.snackbar(
                                            "Error",
                                            "Gagal mengirim konfigurasi: ${e.toString()}",
                                            backgroundColor: Colors.red[400],
                                            colorText: Colors.white,
                                            snackPosition: SnackPosition.TOP,
                                            borderRadius: 12,
                                            margin: const EdgeInsets.all(16),
                                            icon: const Icon(
                                              Icons.error_outline,
                                              color: Colors.white,
                                            ),
                                          );
                                        }
                                      }
                                    },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }
// PERBAIKAN: _buildSensorSection() dengan layout yang fleksibel
Widget _buildSensorSection() {
  final babyModel = Provider.of<BabyModel>(context, listen: false);
  final ageDays = babyModel.birthDate != null
      ? DateTime.now().difference(babyModel.birthDate!).inDays
      : 0;
  final isSensorActive = _currentSensorData?.isFresh() ?? false;
  
  // ======================================================================
  // PERBAIKAN: Pastikan nilai diambil langsung dari variabel state
  // Variabel ini di-update oleh _subscribeToSensorData
  // ======================================================================
  final distance = _ultrasonicDistance;
  final vibration = _piezoVibration;
  
  print("\n🎨 Building sensor section UI:");
  print("   Distance to display: $distance cm");
  print("   Vibration to display: $vibration units");
  
  String activityStatus;
  Color activityColor;
  IconData activityIcon;

  switch (_babyActivity) {
    case 'aktif':
      activityStatus = 'Aktif';
      activityColor = const Color(0xFF22C55E);
      activityIcon = Icons.check_circle;
      break;
    case 'kurang berinteraksi':
      activityStatus = 'Kurang Berinteraksi';
      activityColor = Colors.orange;
      activityIcon = Icons.schedule;
      break;
    default:
      activityStatus = 'Tidak Aktif';
      activityColor = Colors.red;
      activityIcon = Icons.block;
  }

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 15,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ... (Bagian header tidak berubah)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sensor Aktivitas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E1E1E),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Deteksi gerakan bayi ($ageDays hari)',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSensorActive
                        ? const Color(0xFF4CAF50).withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isSensorActive ? const Color(0xFF4CAF50) : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isSensorActive ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSensorActive ? const Color(0xFF4CAF50) : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: _debugSensorValues,
                  icon: const Icon(Icons.bug_report, size: 14),
                  label: const Text('Debug', style: TextStyle(fontSize: 10)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Tampilkan sensor cards dengan nilai real-time
        Row(
          children: [
            if (ageDays >= 120 && ageDays <= 180) ...[
              Expanded(
                child: _buildSensorCard(
                  icon: Icons.straighten,
                  label: 'Jarak Ultrasonic',
                  // ==========================================================
                  // Tampilkan nilai `distance` yang sudah diupdate
                  // ==========================================================
                  value: '${distance.toString()} cm', 
                  color: const Color(0xFF00A3FF),
                  isActive: distance > 0 && distance < 30,
                  subtitle: 'Sensor untuk 4-6 bulan',
                ),
              ),
            ] else if (ageDays > 180) ...[
                // Placeholder jika umur lebih dari 6 bulan
            ],
            if (ageDays >= 0 && ageDays <= 90) ...[
              Expanded(
                child: _buildSensorCard(
                  icon: Icons.vibration,
                  label: 'Getaran Piezo',
                  value: '$vibration unit',
                  color: const Color(0xFFFFA726),
                  isActive: vibration > 5,
                  subtitle: 'Sensor untuk 0-3 bulan',
                ),
              ),
            ] else if (ageDays > 90 && ageDays < 120) ...[
              // Placeholder jika umur 3-4 bulan
            ],
          ],
        ),
        const SizedBox(height: 16),
        // ... (Sisa kode tidak berubah)
        if (distance > 0 || vibration > 0 || _pressedButtonCount > 0) ...[
          //... (Debug info panel)
        ],
        // ... (Status Activity Card)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: activityColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: activityColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(
                activityIcon,
                color: activityColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status Aktivitas Bayi',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    Text(
                      activityStatus,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: activityColor,
                      ),
                    ),
                    if (_toyInteraction)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.toys, size: 16, color: Color(0xFFFFD700)),
                            SizedBox(width: 4),
                            Text(
                              'Mainan Aktif',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFFFD700),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}



// Helper untuk sensor card (tidak berubah)
Widget _buildSensorCard({
  required IconData icon,
  required String label,
  required String value, // PERBAIKAN: terima String langsung
  required Color color,
  required bool isActive,
  String? subtitle,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isActive ? color.withOpacity(0.3) : Colors.grey[200]!,
      ),
    ),
    child: Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 8),
        Text(
          value, // Tampilkan value langsung
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isActive ? color : Colors.grey[600],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    ),
  );
}


  // Test Firebase connection dengan fungsi yang diperbaiki
  Future<void> _testFirebaseConnection() async {
    print("\n🧪 === FIREBASE CONNECTION TEST START ===");
    
    final userModel = Provider.of<UserModel>(context, listen: false);
    final deviceId = userModel.linkedDeviceId;
    
    print("🔍 Device ID: $deviceId");
    
    if (deviceId == null || deviceId.isEmpty) {
      print("❌ ERROR: No linked device!");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No linked device found')),
      );
      return;
    }
    
    try {
      // Gunakan fungsi test yang baru dari SensorDataService
      final sensorService = SensorDataService(userModel);
      
      print("\n🔌 Testing with enhanced SensorDataService...");
      final testResults = await sensorService.testFirebaseConnection();
      
      print("📊 Test Results: $testResults");
      
      // Cari path yang berhasil
      String? workingPath;
      int? workingValue;
      
      final pathTests = testResults['pathTests'] as Map<String, dynamic>? ?? {};
      for (final entry in pathTests.entries) {
        final pathResult = entry.value as Map<String, dynamic>;
        if (pathResult['exists'] == true && pathResult['parsedValue'] != null) {
          workingPath = entry.key;
          workingValue = pathResult['parsedValue'] as int?;
          break;
        }
      }
      
      // Test one-time read dengan fallback
      final distance = await sensorService.getUltrasonicDistance();
      print("📏 One-time read result: $distance cm");
      
      // Print statistics
      sensorService.printStatistics();
      
      print("🧪 === TEST COMPLETE ===\n");
      
      // Show result to user
      String message;
      Color backgroundColor;
      
      if (workingPath != null && workingValue != null && workingValue > 0) {
        message = 'Connection OK! Path: $workingPath, Value: $workingValue cm';
        backgroundColor = Colors.green;
      } else if (distance > 0) {
        message = 'Fallback read successful: $distance cm';
        backgroundColor = Colors.orange;
      } else {
        message = 'No sensor data found. Check ESP32 connection.';
        backgroundColor = Colors.red;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 5),
        ),
      );
      
    } catch (e) {
      print("❌ Firebase test error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Firebase test failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper untuk debug row
  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _initializeScreen() {
    final babyModel = Provider.of<BabyModel>(context, listen: false);
    _fetchBabyData(babyModel);
    if (_currentLinkedDeviceId != null && _currentLinkedDeviceId!.isNotEmpty) {
      _subscribeToMatrasData();
      _subscribeToSensorData();
    }
  }

  Future<void> _fetchBabyData(BabyModel babyModel) async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && babyModel.babyId == null) {
      try {
        final babySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('babies')
            .limit(1)
            .get();

        if (babySnapshot.docs.isNotEmpty) {
          final babyDoc = babySnapshot.docs.first.data();
          babyModel.updateBabyId(babySnapshot.docs.first.id);
          final birthDateStr = babyDoc['birth_date'] as String?;
          if (birthDateStr != null) {
            babyModel.updateBirthDate(DateTime.parse(birthDateStr));
          }
        }
      } catch (e) {
        print("Fetch baby data error: $e");
      }
    }

    _setDurationAndAchievements(babyModel);
    setState(() => _isLoading = false);
  }

  Future<void> _initializeNotifications() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    if (await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.areNotificationsEnabled() ==
        false) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  void _setDurationAndAchievements(BabyModel babyModel) {
    final birthDate = babyModel.birthDate;
    print("Birth date from BabyModel: $birthDate");
    if (birthDate == null) {
      _maxDurationSeconds = 120;
      _remainingSeconds = 120;
      _minutes = 2;
      _achievementTexts.clear();
      _achievementTexts.addAll([
        'Bayi bisa mengangkat kepala mandiri hingga setinggi 45 derajat?',
        'Bayi bisa menggerakkan kepala dari kiri/kanan ke tengah?',
        'Bayi bisa melihat dan menatap wajah Anda?',
        'Bayi bisa mengoceh spontan atau bereaksi dengan mengoceh?',
        'Bayi membalas tersenyum ketika diajak bicara/ tersenyum?',
        'Bayi bereaksi terkejut terhadap suara keras?',
        'Bayi mengenal ibu dengan pengelihatan, penciuman, pendengaran, kontak?',
      ]);
      _achievements = List.filled(7, false);
    } else {
      final currentDate = DateTime.now();
      final ageDays = currentDate.difference(birthDate).inDays;

      if (ageDays <= 90) {
        _maxDurationSeconds = 120;
        _remainingSeconds = 120;
        _minutes = 2;
        _achievementTexts.clear();
        _achievementTexts.addAll([
          'Bayi bisa mengangkat kepala mandiri hingga setinggi 45 derajat?',
          'Bayi bisa menggerakkan kepala dari kiri/kanan ke tengah?',
          'Bayi bisa melihat dan menatap wajah Anda?',
          'Bayi bisa mengoceh spontan atau bereaksi dengan mengoceh?',
          'Bayi membalas tersenyum ketika diajak bicara/ tersenyum?',
          'Bayi bereaksi terkejut terhadap suara keras?',
          'Bayi mengenal ibu dengan pengelihatan, penciuman, pendengaran, kontak?',
        ]);
        _achievements = List.filled(7, false);
      } else if (ageDays <= 180) {
        _maxDurationSeconds = 180;
        _remainingSeconds = 180;
        _minutes = 3;
        _achievementTexts.clear();
        _achievementTexts.addAll([
          'Bayi bisa berbalik dari telungkup ke telentang?',
          'Bayi bisa mengangkat kepala secara mandiri hingga tegak 90 derajat?',
          'Bayi bisa mempertahankan posisi kepala tetap tegak dan stabil?',
          'Bayi bisa menggenggam atau meraih mainan?',
          'Bayi bisa mengamati tangannya sendiri?',
          'Bayi mengeluarkan suara gembira bernada tinggi atau memekik?',
          'Bayi tersenyum ketika melihat mainan saat bermain sendiri?',
        ]);
        _achievements = List.filled(7, false);
      } else {
        _maxDurationSeconds = 240;
        _remainingSeconds = 240;
        _minutes = 4;
        _achievementTexts.clear();
        _achievementTexts.addAll([
          'Bayi bisa mengangkat kepala mandiri hingga setinggi 45 derajat?',
          'Bayi bisa menggerakkan kepala dari kiri/kanan ke tengah?',
          'Bayi bisa melihat dan menatap wajah Anda?',
        ]);
        _achievements = List.filled(3, false);
      }
    }
    _progressController.duration = Duration(seconds: _maxDurationSeconds);
    print("Max duration set to: $_maxDurationSeconds seconds");
  }

  void _handleStateChange() {
    HapticFeedback.mediumImpact();
    final tummyState = Provider.of<TummyTimeState>(context, listen: false);

    setState(() {
      switch (_currentState) {
        case TimerState.initial:
        case TimerState.paused:
          _currentState = TimerState.running;

          // Start session in state manager
          if (!tummyState.isSessionActive) {
            tummyState.startSession();
            print("[TummyTimeScreen] Session started via TummyTimeState");
          }

          double startProgress = 1.0 - (_remainingSeconds / _maxDurationSeconds);
          _progressController.forward(from: startProgress);

          _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (!mounted) {
              timer.cancel();
              return;
            }

            final elapsed = _maxDurationSeconds - _remainingSeconds;
            tummyState.updateSessionDuration(elapsed);

            setState(() {
              if (_remainingSeconds > 0) {
                _remainingSeconds--;
                _seconds = _remainingSeconds % 60;
                _minutes = _remainingSeconds ~/ 60;
              } else {
                timer.cancel();
                _currentState = TimerState.initial;
                // Stop session in state manager
                tummyState.stopSession();
                print("[TummyTimeScreen] Timer completed, showing achievement dialog...");
                _showAchievementDialog();
              }
            });
          });
          break;
        case TimerState.running:
          _currentState = TimerState.paused;
          _timer?.cancel();
          _progressController.stop();
          // Note: session remains active in TummyTimeState
          print("[TummyTimeScreen] Timer paused (session still active)");
          break;
      }
    });
  }

  Future<void> _disconnectDevice() async {
    try {
      final userModel = Provider.of<UserModel>(context, listen: false);
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && userModel.linkedDeviceId != null) {
        final rtdbRef = FirebaseDatabase.instance.ref(
          'users/${user.uid}/linkedDevices',
        );
        await rtdbRef.remove();

        userModel.setLinkedDevice(null);
        _resetSensorData();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Koneksi perangkat berhasil diputuskan'),
          ),
        );
      }
    } catch (e) {
      print('Error disconnecting device: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memutuskan koneksi: $e')),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    final userModel = Provider.of<UserModel>(context);
    final hasLinkedDevice = userModel.linkedDeviceId != null && userModel.linkedDeviceId!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => _navigateTo(0),
                        ),
                        const Text(
                          'Tummy Time',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                        if (hasLinkedDevice)
                          TextButton.icon(
                            onPressed: _disconnectDevice,
                            icon: const Icon(
                              Icons.link_off,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            label: const Text(
                              'Putuskan',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: Colors.red.shade100),
                              ),
                              backgroundColor: Colors.red.withOpacity(0.05),
                            ),
                          )
                        else
                          const SizedBox(width: 48.0),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Main Content: Conditional berdasarkan linked device
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: hasLinkedDevice
                          ? _buildTimerSection()  // Timer jika connected
                          : _buildBluetoothSection(controller),  // Bluetooth dialog jika tidak
                    ),

                    if (hasLinkedDevice) ...[
                      const SizedBox(height: 20),

                      // Matras Grid Section
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Matras Posisi',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E1E1E),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Peta aktivitas tummy time',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF4CAF50),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _pressedButtonCount >= 15 ? 'Aktif ($_pressedButtonCount tombol)' : 'Tidak Aktif',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _pressedButtonCount >= 15 ? const Color(0xFF4CAF50) : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            Row(
                              children: [
                                _buildLegendItem(
                                  color: const Color(0xFF4CAF50),
                                  label: 'Area Aktif',
                                  isActive: true,
                                ),
                                const SizedBox(width: 16),
                                _buildLegendItem(
                                  color: const Color(0xFFE0E0E0),
                                  label: 'Area Tidak Aktif',
                                  isActive: false,
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                  width: 1,
                                ),
                              ),
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 11,
                                  mainAxisSpacing: 3,
                                  crossAxisSpacing: 3,
                                  childAspectRatio: 1,
                                ),
                                itemCount: 55,
                                itemBuilder: (context, index) {
                                  final row = index ~/ 11;
                                  final col = index % 11;
                                  final isActive = _matrasGrid[row][col];

                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeInOutCubic,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? const Color(0xFF4CAF50)
                                          : const Color(0xFFE0E0E0),
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: isActive
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF4CAF50).withOpacity(0.3),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ]
                                          : null,
                                      border: Border.all(
                                        color: isActive
                                            ? const Color(0xFF45A049)
                                            : const Color(0xFFD1D5DB),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(4),
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          child: Center(
                                            child: Text(
                                              buttonLabels[row][col],
                                              style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: isActive
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                                color: isActive
                                                    ? Colors.white
                                                    : const Color(0xFF6B7280),
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatItem(
                                    icon: Icons.grid_on,
                                    label: 'Total Area',
                                    value: '55',
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: const Color(0xFFE5E7EB),
                                ),
                                Expanded(
                                  child: _buildStatItem(
                                    icon: Icons.check_circle_outline,
                                    label: 'Area Aktif',
                                    value: '${_matrasGrid.expand((row) => row).where((cell) => cell).length}',
                                    color: const Color(0xFF4CAF50),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: const Color(0xFFE5E7EB),
                                ),
                                Expanded(
                                  child: _buildStatItem(
                                    icon: Icons.analytics_outlined,
                                    label: 'Coverage',
                                    value: '${((_matrasGrid.expand((row) => row).where((cell) => cell).length / 55) * 100).toStringAsFixed(0)}%',
                                    color: const Color(0xFF00A3FF),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Mood Selector
                      const Text(
                        'Mood baby',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: ['Normal', 'Menangis', 'Senang'].map((mood) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedMood = mood;
                              });
                            },
                            child: Column(
                              children: [
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF79BCC1),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _selectedMood == mood
                                          ? const Color(0xFF7DD3D8)
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                  child: Center(
                                    child: Image.asset(
                                      'assets/images/${mood.toLowerCase()}.png',
                                      width: 55,
                                      height: 55,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Icon(
                                          Icons.face,
                                          size: 55,
                                          color: Colors.white,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  mood,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _selectedMood == mood
                                        ? const Color(0xFF7DD3D8)
                                        : Colors.grey[600],
                                    fontWeight: _selectedMood == mood
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),

                      // Sensor Section: Hanya jika ada linked device dan data sensor
                        _buildSensorSection(),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF7DD3D8),
          unselectedItemColor: Colors.grey[400],
          items: [
            BottomNavigationBarItem(
              icon: _buildIcon('assets/images/home_active_icon.png', Icons.home),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: _buildIcon('assets/images/1tummy_active_icon.png', Icons.child_care),
              label: 'Tummy',
            ),
            BottomNavigationBarItem(
              icon: _buildIcon('assets/images/history_active_icon.png', Icons.history),
              label: 'Riwayat',
            ),
            BottomNavigationBarItem(
              icon: _buildIcon('assets/images/profile_active_icon.png', Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }


}

// Konstanta untuk button labels di matras grid
const List<List<String>> buttonLabels = [
  ["A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8", "A9", "A10", "A11"],
  ["B1", "B2", "B3", "B4", "B5", "B6", "B7", "B8", "B9", "B10", "B11"],
  ["C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8", "C9", "C10", "C11"],
  ["D1", "D2", "D3", "D4", "D5", "D6", "D7", "D8", "D9", "D10", "D11"],
  ["E1", "E2", "E3", "E4", "E5", "E6", "E7", "E8", "E9", "E10", "E11"],
];

// Move EnhancedProgressPainter to top-level
class EnhancedProgressPainter extends CustomPainter {
  final double progress;
  final bool isRunning;

  EnhancedProgressPainter(this.progress, this.isRunning);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    final backgroundPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    if (progress > 0) {
      final progressPaint = Paint()
        ..shader = LinearGradient(
          colors: [const Color(0xFF00A3FF), const Color(0xFF0056b3)],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }

    // Animated pulse effect when running
    if (isRunning) {
      final pulsePaint = Paint()
        ..color = const Color(0xFF00A3FF).withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(center, radius + 10, pulsePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}