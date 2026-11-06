// tummy_time_state.dart - UPGRADED VERSION WITH SESSION TRACKING

import 'package:flutter/material.dart';
import 'package:TummyTrack/models/sensor_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// State manager terpusat untuk Tummy Time dengan session tracking
/// 
/// UPGRADE:
/// - Tracking semua data selama session berlangsung
/// - Menyimpan history untuk averaging
/// - Tidak kehilangan data saat UI rebuild
/// - Ready untuk save ke Firestore
class TummyTimeState with ChangeNotifier {
  // ===================================================================
  // DATA REAL-TIME (Current State)
  // ===================================================================
  
  // Data Sensor Real-time
  int _ultrasonicDistance = 0;
  int _piezoVibration = 0;
  String _babyActivity = 'tidak aktif';
  bool _toyInteraction = false;
  DateTime? _lastSensorUpdate;

  // Data Matras Real-time
  List<List<bool>> _matrasGrid = List.generate(5, (_) => List.filled(11, false));
  int _pressedButtonCount = 0;
  
  // ===================================================================
  // SESSION DATA (Accumulated during session)
  // ===================================================================
  
  // Session Status
  bool _isSessionActive = false;
  DateTime? _sessionStartTime;
  int _sessionDuration = 0; // in seconds
  
  // Accumulated Button Data
  final Set<String> _accumulatedButtons = {}; // Unique buttons pressed
  final Map<String, int> _buttonPressCount = {}; // Count per button
  final Map<String, DateTime> _buttonFirstPress = {}; // First press time
  final Map<String, DateTime> _buttonLastPress = {}; // Last press time
  
  // Sensor History
  final List<SensorData> _sessionSensorHistory = [];
  final List<SensorData> _recentSensorHistory = []; // Last 10 for real-time
  
  // Statistics
  int _totalSensorReadings = 0;
  int _validUltrasonicReadings = 0;
  int _validPiezoReadings = 0;
  
  // ===================================================================
  // GETTERS - Real-time Data
  // ===================================================================
  
  int get ultrasonicDistance => _ultrasonicDistance;
  int get piezoVibration => _piezoVibration;
  String get babyActivity => _babyActivity;
  bool get toyInteraction => _toyInteraction;
  DateTime? get lastSensorUpdate => _lastSensorUpdate;
  List<List<bool>> get matrasGrid => _matrasGrid;
  int get pressedButtonCount => _pressedButtonCount;
  
  bool get isSensorActive => 
      _lastSensorUpdate != null && 
      DateTime.now().difference(_lastSensorUpdate!).inSeconds < 10;
  
  // ===================================================================
  // GETTERS - Session Data
  // ===================================================================
  
  bool get isSessionActive => _isSessionActive;
  DateTime? get sessionStartTime => _sessionStartTime;
  int get sessionDuration => _sessionDuration;
  
  // Button Session Data
  int get accumulatedButtonCount => _accumulatedButtons.length;
  List<String> get accumulatedButtons => _accumulatedButtons.toList()..sort();
  Map<String, int> get buttonPressCount => Map.from(_buttonPressCount);
  
  // Sensor Session Data
  int get sessionSensorReadingsCount => _sessionSensorHistory.length;
  List<SensorData> get sessionSensorHistory => List.from(_sessionSensorHistory);
  
  // Statistics
  int get totalSensorReadings => _totalSensorReadings;
  int get validUltrasonicReadings => _validUltrasonicReadings;
  int get validPiezoReadings => _validPiezoReadings;
  
  // ===================================================================
  // SESSION CONTROL METHODS
  // ===================================================================
  
  /// Mulai session baru
  void startSession() {
    if (_isSessionActive) {
      print("[TummyTimeState] Session already active, ignoring startSession()");
      return;
    }
    
    _isSessionActive = true;
    _sessionStartTime = DateTime.now();
    _sessionDuration = 0;
    
    // Clear accumulated data
    _accumulatedButtons.clear();
    _buttonPressCount.clear();
    _buttonFirstPress.clear();
    _buttonLastPress.clear();
    _sessionSensorHistory.clear();
    
    // Reset statistics
    _totalSensorReadings = 0;
    _validUltrasonicReadings = 0;
    _validPiezoReadings = 0;
    
  print("\n=== SESSION STARTED ===");
  print("   Start time: $_sessionStartTime");
    
    notifyListeners();
  }
  
  /// Update durasi session (dipanggil setiap detik dari timer)
  void updateSessionDuration(int seconds) {
    _sessionDuration = seconds;
    // Tidak perlu notifyListeners() di sini karena akan terlalu sering
  }
  
  /// Stop session (tapi jangan clear data, untuk save nanti)
  void stopSession() {
    if (!_isSessionActive) {
      print("âš ï¸ No active session to stop");
      return;
    }
    
    _isSessionActive = false;
    
    print("\nâ¸ï¸ === SESSION STOPPED ===");
    print("   Duration: $_sessionDuration seconds");
    print("   Buttons collected: ${_accumulatedButtons.length}");
    print("   Sensor readings: ${_sessionSensorHistory.length}");
    
    notifyListeners();
  }
  
  /// Clear semua session data (setelah save berhasil)
  void clearSessionData() {
    _accumulatedButtons.clear();
    _buttonPressCount.clear();
    _buttonFirstPress.clear();
    _buttonLastPress.clear();
    _sessionSensorHistory.clear();
    
    _sessionStartTime = null;
    _sessionDuration = 0;
    _totalSensorReadings = 0;
    _validUltrasonicReadings = 0;
    _validPiezoReadings = 0;
    
    print("[TummyTimeState] Session data cleared");
    notifyListeners();
  }
  
  // ===================================================================
  // DATA UPDATE METHODS
  // ===================================================================
  
  /// Update data sensor dari stream
  void updateSensorData({
    required int ultrasonic, 
    required int piezo,
    int? babyAgeDays,
  }) {
    _ultrasonicDistance = ultrasonic;
    _piezoVibration = piezo;
    _lastSensorUpdate = DateTime.now();
    _totalSensorReadings++;
    
    // Track valid readings
    if (ultrasonic > 0) _validUltrasonicReadings++;
    if (piezo > 0) _validPiezoReadings++;

    // Deteksi interaksi mainan
    _toyInteraction = (ultrasonic > 0 && ultrasonic < 30) || piezo > 5;
    
    // Hitung aktivitas bayi
    _calculateBabyActivity();
    
    // Buat sensor data object
    final sensorData = SensorData(
      ultrasonicDistance: ultrasonic,
      piezoVibration: piezo,
      timestamp: DateTime.now(),
      toyInteraction: _toyInteraction,
    );
    
    // Tambahkan ke recent history (untuk UI real-time)
    _recentSensorHistory.add(sensorData);
    if (_recentSensorHistory.length > 10) {
      _recentSensorHistory.removeAt(0);
    }
    
    // PENTING: Simpan ke session history jika session aktif
    if (_isSessionActive) {
      _sessionSensorHistory.add(sensorData);
      
      if (_sessionSensorHistory.length % 10 == 0) {
        print("[TummyTimeState] Session sensor history: ${_sessionSensorHistory.length} readings");
      }
    }
    
    notifyListeners();
  }

  /// Update data matras dari stream
  void updateMatrasData(Set<String> pressedButtons) {
    final now = DateTime.now();
    
    // Update grid untuk display
    _matrasGrid = List.generate(5, (_) => List.filled(11, false));
    _pressedButtonCount = pressedButtons.length;
    
    for (var button in pressedButtons) {
      try {
        final row = 'ABCDE'.indexOf(button[0].toUpperCase());
        final col = int.parse(button.substring(1)) - 1;
        
        if (row != -1 && col >= 0 && col < 11) {
          _matrasGrid[row][col] = true;
          
          // PENTING: Track button untuk session
          if (_isSessionActive) {
            // Tambahkan ke accumulated set (unique)
            final wasNew = _accumulatedButtons.add(button);
            
            // Update press count
            _buttonPressCount[button] = (_buttonPressCount[button] ?? 0) + 1;
            
            // Track timing
            _buttonLastPress[button] = now;
            if (wasNew) {
              _buttonFirstPress[button] = now;
            }
            
            // Log setiap 5 button baru
            if (_accumulatedButtons.length % 5 == 0) {
              print("[TummyTimeState] Accumulated buttons: ${_accumulatedButtons.length}");
            }
          }
        }
      } catch (e) {
        print("âš ï¸ Error parsing button $button: $e");
      }
    }
    
    _calculateBabyActivity();
    notifyListeners();
  }

  /// Logika terpusat untuk menentukan status aktivitas bayi
  void _calculateBabyActivity() {
    bool matrasActive = _pressedButtonCount >= 15;
    bool ultrasonicActive = (_ultrasonicDistance > 0 && _ultrasonicDistance < 60);
    bool piezoActive = (_piezoVibration > 5);
    
    if (matrasActive) {
      _babyActivity = 'aktif';
    } else if (ultrasonicActive || piezoActive || _toyInteraction) {
      _babyActivity = 'aktif';
    } else if (_pressedButtonCount > 0 && _pressedButtonCount < 15) {
      _babyActivity = 'kurang berinteraksi';
    } else {
      _babyActivity = 'tidak aktif';
    }
  }

  // ===================================================================
  // DATA EXTRACTION METHODS (untuk save ke Firestore)
  // ===================================================================
  
  /// Get sensor averages berdasarkan usia bayi
  Map<String, dynamic> getSensorAverages({required int babyAgeDays}) {
    if (_sessionSensorHistory.isEmpty) {
      return {
        'avg_ultrasonic': _ultrasonicDistance,
        'avg_piezo': _piezoVibration,
        'readings_count': 0,
        'source': 'current_value',
      };
    }
    
    int avgUltrasonic = 0;
    int avgPiezo = 0;
    
    if (babyAgeDays <= 90) {
      // 0-3 bulan: Hanya piezo
      final validPiezo = _sessionSensorHistory
          .map((s) => s.piezoVibration)
          .where((v) => v > 0)
          .toList();
      
      if (validPiezo.isNotEmpty) {
        avgPiezo = validPiezo.reduce((a, b) => a + b) ~/ validPiezo.length;
      } else {
        avgPiezo = _piezoVibration;
      }
      avgUltrasonic = 0;
      
    } else if (babyAgeDays <= 180) {
      // 4-6 bulan: Hanya ultrasonic
      final validUltrasonic = _sessionSensorHistory
          .map((s) => s.ultrasonicDistance)
          .where((v) => v > 0)
          .toList();
      
      if (validUltrasonic.isNotEmpty) {
        avgUltrasonic = validUltrasonic.reduce((a, b) => a + b) ~/ validUltrasonic.length;
      } else {
        avgUltrasonic = _ultrasonicDistance;
      }
      avgPiezo = 0;
      
    } else {
      // 6+ bulan: Keduanya
      final validUltrasonic = _sessionSensorHistory
          .map((s) => s.ultrasonicDistance)
          .where((v) => v > 0)
          .toList();
      final validPiezo = _sessionSensorHistory
          .map((s) => s.piezoVibration)
          .where((v) => v > 0)
          .toList();
      
      avgUltrasonic = validUltrasonic.isNotEmpty
          ? validUltrasonic.reduce((a, b) => a + b) ~/ validUltrasonic.length
          : _ultrasonicDistance;
      
      avgPiezo = validPiezo.isNotEmpty
          ? validPiezo.reduce((a, b) => a + b) ~/ validPiezo.length
          : _piezoVibration;
    }
    
    return {
      'avg_ultrasonic': avgUltrasonic,
      'avg_piezo': avgPiezo,
      'current_ultrasonic': _ultrasonicDistance,
      'current_piezo': _piezoVibration,
      'readings_count': _sessionSensorHistory.length,
      'valid_ultrasonic_readings': _validUltrasonicReadings,
      'valid_piezo_readings': _validPiezoReadings,
      'source': 'session_average',
    };
  }
  
  /// Get final baby activity dengan validasi
  String getFinalBabyActivity() {
    bool matrasActive = _accumulatedButtons.length >= 15;
    bool hasSensorActivity = _sessionSensorHistory.any(
      (s) => s.ultrasonicDistance < 60 || s.piezoVibration > 5
    );
    
    if (matrasActive) {
      return 'aktif';
    } else if (hasSensorActivity) {
      return 'aktif';
    } else if (_accumulatedButtons.isNotEmpty && _accumulatedButtons.length < 15) {
      return 'kurang berinteraksi';
    } else {
      return 'tidak aktif';
    }
  }
  
  /// Get toy interaction status
  bool getFinalToyInteraction() {
    return _accumulatedButtons.isNotEmpty || 
           _sessionSensorHistory.any((s) => 
             s.ultrasonicDistance < 60 || s.piezoVibration > 5
           );
  }
  
  /// Get session summary untuk save
  Map<String, dynamic> getSessionSummary({required int babyAgeDays}) {
    final sensorAverages = getSensorAverages(babyAgeDays: babyAgeDays);
    final finalActivity = getFinalBabyActivity();
    final toyInteraction = getFinalToyInteraction();
    
    return {
      // Button data
      'buttons': accumulatedButtons,
      'button_count': _accumulatedButtons.length,
      'button_press_counts': buttonPressCount,
      
      // Sensor data
      'avg_ultrasonic': sensorAverages['avg_ultrasonic'],
      'avg_piezo': sensorAverages['avg_piezo'],
      'current_ultrasonic': sensorAverages['current_ultrasonic'],
      'current_piezo': sensorAverages['current_piezo'],
      
      // Activity
      'baby_activity': finalActivity,
      'toy_interaction': toyInteraction,
      
      // Stats
      'readings_count': _sessionSensorHistory.length,
      'valid_ultrasonic_readings': _validUltrasonicReadings,
      'valid_piezo_readings': _validPiezoReadings,
      'total_readings': _totalSensorReadings,
      
      // Timing
      'session_start': _sessionStartTime?.toIso8601String(),
      'session_duration': _sessionDuration,
    };
  }
  
  // ===================================================================
  // RESET & DEBUG METHODS
  // ===================================================================
  
  /// Reset semua state (untuk tombol reset timer)
  void resetState() {
    // Reset real-time data
    _ultrasonicDistance = 0;
    _piezoVibration = 0;
    _babyActivity = 'tidak aktif';
    _toyInteraction = false;
    _matrasGrid = List.generate(5, (_) => List.filled(11, false));
    _pressedButtonCount = 0;
    _lastSensorUpdate = null;
    _recentSensorHistory.clear();
    
    // Reset session data
    _isSessionActive = false;
    clearSessionData();
    
    print("[TummyTimeState] State reset complete");
    notifyListeners();
  }
  
  /// Print debug info
  void printDebugInfo() {
  print("\n=== TUMMY TIME STATE DEBUG ===");
  print("SESSION:");
    print("  Active: $_isSessionActive");
    print("  Start: $_sessionStartTime");
    print("  Duration: $_sessionDuration seconds");
    print("\nBUTTONS:");
    print("  Current pressed: $_pressedButtonCount");
    print("  Accumulated: ${_accumulatedButtons.length}");
    print("  Top 5 pressed: ${_getTopPressedButtons(5)}");
    print("\nSENSOR:");
    print("  Current - U: $_ultrasonicDistance cm, P: $_piezoVibration units");
    print("  History: ${_sessionSensorHistory.length} readings");
    print("  Valid - U: $_validUltrasonicReadings, P: $_validPiezoReadings");
    print("  Last update: $_lastSensorUpdate");
    print("\nACTIVITY:");
    print("  Status: $_babyActivity");
    print("  Toy interaction: $_toyInteraction");
    print("===================================\n");
  }

  // ===================================================================
  // PERSISTENCE (local save using SharedPreferences)
  // ===================================================================

  /// Save current session summary to local storage (SharedPreferences)
  /// Returns true when saved successfully.
  Future<bool> saveSessionLocally({required int babyAgeDays}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final session = getSessionSummary(babyAgeDays: babyAgeDays);
      // Add created_at for local record
      session['created_at'] = DateTime.now().toIso8601String();

      final List<String> saved = prefs.getStringList('tummy_time_sessions') ?? [];
      saved.insert(0, jsonEncode(session));
      await prefs.setStringList('tummy_time_sessions', saved);

      print('[TummyTimeState] Session saved locally (${saved.length} total)');
      return true;
    } catch (e) {
      print('[TummyTimeState] Failed to save session locally: $e');
      return false;
    }
  }

  /// Load saved sessions from local storage, returns list of decoded maps
  Future<List<Map<String, dynamic>>> loadSavedSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> saved = prefs.getStringList('tummy_time_sessions') ?? [];
      return saved.map((s) {
        try {
          final decoded = jsonDecode(s) as Map<String, dynamic>;
          return decoded;
        } catch (_) {
          return <String, dynamic>{};
        }
      }).where((m) => m.isNotEmpty).toList();
    } catch (e) {
      print('[TummyTimeState] Failed to load sessions: $e');
      return [];
    }
  }

  /// Save current session locally and clear in-memory session data when saved
  Future<bool> persistSessionAndClear({required int babyAgeDays}) async {
    final success = await saveSessionLocally(babyAgeDays: babyAgeDays);
    if (success) {
      clearSessionData();
    }
    return success;
  }
  
  List<MapEntry<String, int>> _getTopPressedButtons(int count) {
    final sorted = _buttonPressCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(count).toList();
  }
}