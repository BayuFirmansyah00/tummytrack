// sensor_service_update.dart - FIXED VERSION WITH CORRECT PATH

import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:TummyTrack/models/user_model.dart';
import 'package:TummyTrack/models/sensor_model.dart';

class SensorDataService {
  final UserModel userModel;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  
  StreamController<Map<String, int>>? _sensorStreamController;
  DatabaseReference? _ultrasonicRef;
  DatabaseReference? _piezoRef;
  StreamSubscription? _ultrasonicSubscription;
  StreamSubscription? _piezoSubscription;
  
  int _lastUltrasonicValue = 0;
  int _lastPiezoValue = 0;
  
  // Tracking untuk debug
  int _ultrasonicUpdateCount = 0;
  int _piezoUpdateCount = 0;
  DateTime? _lastUltrasonicUpdate;
  DateTime? _lastPiezoUpdate;
  String? _activeUltrasonicPath;
  String? _activePiezoPath;

  SensorDataService(this.userModel);

  /// Stream gabungan untuk data sensor - DENGAN PATH YANG BENAR
  Stream<Map<String, int>> getCombinedSensorDataStream() {
    print("\n🚀 === INITIALIZING SENSOR STREAM ===");
    
    // Dispose stream lama jika ada
    _disposeSensorStream();
    
    _sensorStreamController = StreamController<Map<String, int>>.broadcast();
    
    final deviceId = userModel.linkedDeviceId;
    
    if (deviceId == null || deviceId.isEmpty) {
      print("❌ ERROR: No linked device found!");
      print("   UserModel.linkedDeviceId = null");
      _sensorStreamController?.add({'ultrasonic': 0, 'piezo': 0});
      return _sensorStreamController!.stream;
    }

    print("✅ Device ID found: $deviceId");
    print("📏 Device ID length: ${deviceId.length}");
    print("🔍 Device ID format: ${deviceId.contains(':') ? 'with colon' : 'without colon'}");
    
    // PERBAIKAN KRITIS: Coba berbagai format path yang mungkin digunakan ESP32
    final possiblePaths = [
      'devices/$deviceId/sensorData/ultrasonic',  // Format utama
      'devices/$deviceId/ultrasonic',             // Format alternatif 1
      '$deviceId/sensorData/ultrasonic',          // Format alternatif 2
      '$deviceId/ultrasonic',                     // Format alternatif 3
    ];
    
    print("📍 Testing paths:");
    for (int i = 0; i < possiblePaths.length; i++) {
      print("   ${i + 1}. ${possiblePaths[i]}");
    }
    print("🔗 Firebase Database URL: ${_database.app.options.databaseURL}");

    // PERBAIKAN: Coba path utama dulu, jika tidak ada data coba path alternatif
    _subscribeToUltrasonicWithFallback(deviceId, possiblePaths);
    _subscribeToPiezoWithFallback(deviceId, possiblePaths);

    // Emit data awal
    print("📤 Emitting initial data...");
    _emitCombinedData();
    
    print("✅ Sensor stream initialization complete");
    print("🚀 === END INITIALIZATION ===\n");

    return _sensorStreamController!.stream;
  }

  /// Subscribe ke ultrasonic dengan fallback ke path alternatif
  void _subscribeToUltrasonicWithFallback(String deviceId, List<String> paths) {
    int currentPathIndex = 0;
    
    void tryNextPath() {
      if (currentPathIndex >= paths.length) {
        print("❌ All ultrasonic paths failed, using default 0");
        _lastUltrasonicValue = 0;
        _emitCombinedData();
        return;
      }
      
      final currentPath = paths[currentPathIndex];
      print("\n📡 Trying ultrasonic path ${currentPathIndex + 1}: $currentPath");
      
      _ultrasonicRef = _database.ref(currentPath);
      
      // Test path dengan one-time read dulu
      _ultrasonicRef!.get().then((snapshot) {
        if (snapshot.exists) {
          print("✅ Found data at path: $currentPath");
          _startUltrasonicListener(currentPath);
        } else {
          print("⚠️ No data at path: $currentPath");
          currentPathIndex++;
          tryNextPath();
        }
      }).catchError((error) {
        print("❌ Error testing path $currentPath: $error");
        currentPathIndex++;
        tryNextPath();
      });
    }
    
    tryNextPath();
  }

  /// Mulai listener ultrasonic setelah path ditemukan
  void _startUltrasonicListener(String path) {
    _ultrasonicRef = _database.ref(path);
    _activeUltrasonicPath = path;
    print("\n📡 Starting ultrasonic listener on: $path");
    
    _ultrasonicSubscription = _ultrasonicRef!.onValue.listen(
      (event) {
        _ultrasonicUpdateCount++;
        _lastUltrasonicUpdate = DateTime.now();
        
        print("\n🔵 === ULTRASONIC DATA EVENT #$_ultrasonicUpdateCount ===");
        print("⏰ Timestamp: ${_lastUltrasonicUpdate!.toIso8601String()}");
        print("📦 Snapshot exists: ${event.snapshot.exists}");
        print("📍 Path: ${event.snapshot.ref.path}");
        
        if (event.snapshot.exists) {
          final value = event.snapshot.value;
          print("📊 Raw value: $value");
          print("🔍 Value type: ${value.runtimeType}");
          
          // PERBAIKAN ENHANCED: Handle semua kemungkinan format data
          int parsedValue = 0;
          
          if (value is num) {
            parsedValue = value.round();
            print("✅ Parsed as num → int: $parsedValue");
          } else if (value is String) {
            // Coba parse sebagai number
            final numParsed = num.tryParse(value.trim());
            if (numParsed != null) {
              parsedValue = numParsed.round();
              print("✅ Parsed string '$value' → int: $parsedValue");
            } else {
              print("⚠️ Cannot parse string '$value' as number");
            }
          } else if (value is Map) {
            // Jika ESP32 mengirim sebagai object {"value": 123}
            final numValue = value['value'] ?? value['distance'] ?? value['ultrasonic'];
            if (numValue is num) {
              parsedValue = numValue.round();
              print("✅ Parsed from map → int: $parsedValue");
            } else {
              print("⚠️ Map does not contain valid numeric value: $value");
            }
          } else {
            print("⚠️ Unknown data type: ${value.runtimeType}");
          }
          
          // Validasi range yang masuk akal untuk sensor ultrasonic (0-400 cm)
          if (parsedValue >= 0 && parsedValue <= 400) {
            _lastUltrasonicValue = parsedValue;
            print("✅ Valid ultrasonic value: $_lastUltrasonicValue cm");
          } else {
            print("⚠️ Invalid ultrasonic range: $parsedValue cm (expected 0-400)");
            _lastUltrasonicValue = 0;
          }
          
          _emitCombinedData();
        } else {
          print("⚠️ No data at path");
          _lastUltrasonicValue = 0;
          _emitCombinedData();
        }
        print("🔵 === END ULTRASONIC EVENT ===\n");
      },
      onError: (error) {
        print("\n❌ === ULTRASONIC ERROR ===");
        print("Error: $error");
        print("Error type: ${error.runtimeType}");
        print("=========================\n");
        _lastUltrasonicValue = 0;
        _emitCombinedData();
      },
    );

  }

  /// Subscribe ke piezo dengan fallback ke path alternatif
void _subscribeToPiezoWithFallback(String deviceId, List<String> paths) {
  // PERBAIKAN KRITIS: Tambahkan '/current' ke semua path piezo
  final piezoPaths = [
    'devices/$deviceId/sensorData/piezo/current',  // Path utama (nested)
    'devices/$deviceId/sensorData/piezo',          // Path alternatif (flat)
    'devices/$deviceId/piezo/current',             // Alternative 2
    'devices/$deviceId/piezo',                     // Alternative 3
  ];
  
  int currentPathIndex = 0;
    
  void tryNextPiezoPath() {
    if (currentPathIndex >= piezoPaths.length) {
      print("⚠️ All piezo paths failed, using default 0");
      _lastPiezoValue = 0;
      return;
    }
    
    final currentPath = piezoPaths[currentPathIndex];
    print("\n📡 Trying piezo path ${currentPathIndex + 1}: $currentPath");
    
    _piezoRef = _database.ref(currentPath);
    
    _piezoRef!.get().then((snapshot) {
      if (snapshot.exists) {
        print("✅ Found piezo data at path: $currentPath");
        print("   📊 Value: ${snapshot.value} (${snapshot.value.runtimeType})");
        _startPiezoListener(currentPath);
      } else {
        print("⚠️ No piezo data at path: $currentPath");
        currentPathIndex++;
        tryNextPiezoPath();
      }
    }).catchError((error) {
      print("❌ Error testing piezo path $currentPath: $error");
      currentPathIndex++;
      tryNextPiezoPath();
    });
  }
  
  tryNextPiezoPath();
}

  /// Mulai listener piezo setelah path ditemukan
void _startPiezoListener(String path) {
  _piezoRef = _database.ref(path);
  _activePiezoPath = path;
  print("\n📡 Starting piezo listener on: $path");
  
  _piezoSubscription = _piezoRef!.onValue.listen(
    (event) {
      _piezoUpdateCount++;
      _lastPiezoUpdate = DateTime.now();
      
      print("\n🟣 === PIEZO DATA EVENT #$_piezoUpdateCount ===");
      print("⏰ Timestamp: ${_lastPiezoUpdate!.toIso8601String()}");
      print("📦 Snapshot exists: ${event.snapshot.exists}");
      
      if (event.snapshot.exists) {
        final value = event.snapshot.value;
        print("📊 Raw value: $value (${value.runtimeType})");
        
        // PERBAIKAN ENHANCED: Handle semua format data
        int parsedValue = 0;
        
        if (value is num) {
          parsedValue = value.round();
          print("✅ Parsed as num → int: $parsedValue");
        } else if (value is String) {
          final numParsed = num.tryParse(value.trim());
          if (numParsed != null) {
            parsedValue = numParsed.round();
            print("✅ Parsed string '$value' → int: $parsedValue");
          } else {
            print("⚠️ Cannot parse string '$value' as number");
          }
        } else if (value is Map) {
          // Jika ESP32 mengirim nested object
          final numValue = value['current'] ?? value['value'] ?? value['piezo'];
          if (numValue is num) {
            parsedValue = numValue.round();
            print("✅ Parsed from map → int: $parsedValue");
          } else {
            print("⚠️ Map does not contain valid numeric value: $value");
          }
        } else {
          print("⚠️ Unknown data type: ${value.runtimeType}");
        }
        
        // Validasi range yang masuk akal untuk piezo sensor (0-4095 untuk ADC 12-bit)
        if (parsedValue >= 0 && parsedValue <= 4095) {
          _lastPiezoValue = parsedValue;
          print("✅ Valid piezo value: $_lastPiezoValue units");
        } else {
          print("⚠️ Invalid piezo range: $parsedValue units (expected 0-4095)");
          _lastPiezoValue = 0;
        }
        
        _emitCombinedData();
      } else {
        print("⚠️ No data at path");
        _lastPiezoValue = 0;
      }
      print("🟣 === END PIEZO EVENT ===\n");
    },
    onError: (error) {
      print("\n❌ === PIEZO ERROR ===");
      print("Error: $error");
      print("Error type: ${error.runtimeType}");
      print("======================\n");
      _lastPiezoValue = 0;
    },
  );
}


  /// Emit data gabungan ke stream
  void _emitCombinedData() {
    if (_sensorStreamController != null && !_sensorStreamController!.isClosed) {
      final combinedData = {
        'ultrasonic': _lastUltrasonicValue,
        'piezo': _lastPiezoValue,
      };
      
      print("📤 === EMITTING COMBINED DATA ===");
      print("📊 Data: $combinedData");
      print("📏 Ultrasonic: $_lastUltrasonicValue cm");
      print("📊 Piezo: $_lastPiezoValue units");
      print("👂 Stream has listeners: ${_sensorStreamController!.hasListener}");
      
      if (_sensorStreamController!.hasListener) {
        _sensorStreamController!.add(combinedData);
        print("✅ Data emitted successfully to ${_sensorStreamController!.hasListener ? 'active' : 'no'} listeners");
      } else {
        print("⚠️ No listeners, data not emitted");
      }
      
      print("===============================\n");
    } else {
      print("⚠️ Cannot emit: stream closed or null");
    }
  }

  /// Membaca data ultrasonic sekali (one-time read) dengan multiple path fallback
  Future<int> getUltrasonicDistance() async {
    final deviceId = userModel.linkedDeviceId;
    
    if (deviceId == null || deviceId.isEmpty) {
      print("❌ getUltrasonicDistance: No linked device");
      return 0;
    }

    final possiblePaths = [
      'devices/$deviceId/sensorData/ultrasonic',
      'devices/$deviceId/ultrasonic',
      '$deviceId/sensorData/ultrasonic',
      '$deviceId/ultrasonic',
    ];

    print("\n📖 One-time ultrasonic read with fallback...");
    
    for (int i = 0; i < possiblePaths.length; i++) {
      final path = possiblePaths[i];
      print("📍 Trying path ${i + 1}: $path");
      
      try {
        final snapshot = await _database.ref(path).get();
        
        if (snapshot.exists) {
          final value = snapshot.value;
          print("📊 Found value: $value (${value.runtimeType})");
          
          int result = 0;
          if (value is num) {
            result = value.round();
          } else if (value is String) {
            final parsed = num.tryParse(value.trim());
            result = parsed?.round() ?? 0;
          } else if (value is Map) {
            final numValue = value['value'] ?? value['distance'] ?? value['ultrasonic'];
            if (numValue is num) {
              result = numValue.round();
            }
          }
          
          if (result >= 0 && result <= 400) {
            print("✅ Valid result from path $path: $result cm");
            return result;
          } else {
            print("⚠️ Invalid range from path $path: $result cm");
          }
        } else {
          print("⚠️ No data at path: $path");
        }
      } catch (e) {
        print("❌ Error reading path $path: $e");
      }
    }
    
    print("❌ All paths failed, returning 0");
    return 0;
  }

  /// Membaca data piezo sekali
Future<int> getPiezoVibration() async {
  final deviceId = userModel.linkedDeviceId;
  
  if (deviceId == null || deviceId.isEmpty) {
    print("❌ getPiezoVibration: No linked device");
    return 0;
  }

  final possiblePaths = [
    'devices/$deviceId/sensorData/piezo/current',
    'devices/$deviceId/sensorData/piezo',
    'devices/$deviceId/piezo/current',
    'devices/$deviceId/piezo',
  ];

  print("\n📖 One-time piezo read with fallback...");
  
  for (int i = 0; i < possiblePaths.length; i++) {
    final path = possiblePaths[i];
    print("🔍 Trying path ${i + 1}: $path");
    
    try {
      final snapshot = await _database.ref(path).get();
      
      if (snapshot.exists) {
        final value = snapshot.value;
        print("📊 Found value: $value (${value.runtimeType})");
        
        int result = 0;
        if (value is num) {
          result = value.round();
        } else if (value is String) {
          final parsed = num.tryParse(value.trim());
          result = parsed?.round() ?? 0;
        } else if (value is Map) {
          final numValue = value['current'] ?? value['value'] ?? value['piezo'];
          if (numValue is num) {
            result = numValue.round();
          }
        }
        
        if (result >= 0 && result <= 4095) {
          print("✅ Valid result from path $path: $result units");
          return result;
        } else {
          print("⚠️ Invalid range from path $path: $result units");
        }
      } else {
        print("⚠️ No data at path: $path");
      }
    } catch (e) {
      print("❌ Error reading path $path: $e");
    }
  }
  
  print("❌ All paths failed, returning 0");
  return 0;
}


  /// Get service statistics untuk debugging
  Map<String, dynamic> getStatistics() {
    return {
      'deviceId': userModel.linkedDeviceId,
      'ultrasonicUpdateCount': _ultrasonicUpdateCount,
      'piezoUpdateCount': _piezoUpdateCount,
      'lastUltrasonicUpdate': _lastUltrasonicUpdate?.toIso8601String(),
      'lastPiezoUpdate': _lastPiezoUpdate?.toIso8601String(),
      'lastUltrasonicValue': _lastUltrasonicValue,
      'lastPiezoValue': _lastPiezoValue,
      'activeUltrasonicPath': _activeUltrasonicPath,
      'activePiezoPath': _activePiezoPath,
      'streamActive': _sensorStreamController != null && !_sensorStreamController!.isClosed,
      'streamHasListeners': _sensorStreamController?.hasListener ?? false,
      'databaseUrl': _database.app.options.databaseURL,
    };
  }

  /// Print statistics
  void printStatistics() {
    final stats = getStatistics();
    print("\n📊 === SENSOR SERVICE STATISTICS ===");
    stats.forEach((key, value) {
      print("   $key: $value");
    });
    print("=====================================\n");
  }



  /// Simpan snapshot data sensor
  Future<void> saveSensorSnapshot({
    required String babyId,
    required int ultrasonicDistance,
    required int piezoVibration,
    required bool toyInteraction,
  }) async {
    if (userModel.uid == null) {
      print("⚠️ Cannot save sensor snapshot: User not logged in");
      return;
    }

    try {
      final sensorData = SensorData(
        ultrasonicDistance: ultrasonicDistance,
        piezoVibration: piezoVibration,
        timestamp: DateTime.now(),
        toyInteraction: toyInteraction,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userModel.uid)
          .collection('babies')
          .doc(babyId)
          .collection('sensor_snapshots')
          .add(sensorData.toJson());
      
      print("✅ Sensor snapshot saved successfully");
    } catch (e) {
      print("❌ Error saving sensor snapshot: $e");
    }
  }

  /// Membersihkan subscription dan stream
  void _disposeSensorStream() {
    print("🧹 Disposing sensor streams...");
    
    _ultrasonicSubscription?.cancel();
    _piezoSubscription?.cancel();
    
    // Jangan close controller jika masih ada listener
    if (_sensorStreamController != null && !_sensorStreamController!.isClosed) {
      if (!_sensorStreamController!.hasListener) {
        _sensorStreamController?.close();
      }
    }
    
    _ultrasonicSubscription = null;
    _piezoSubscription = null;
    _ultrasonicRef = null;
    _piezoRef = null;
    
    print("✅ Sensor streams disposed");
  }

  /// Force refresh semua subscription
  void forceRefresh() {
    print("\n🔄 === FORCE REFRESH SENSOR STREAMS ===");
    final deviceId = userModel.linkedDeviceId;
    
    if (deviceId == null || deviceId.isEmpty) {
      print("❌ Cannot refresh: No linked device");
      return;
    }
    
    // Dispose dan restart streams
    _disposeSensorStream();
    
    // Tunggu sebentar sebelum restart
    Future.delayed(const Duration(milliseconds: 500), () {
      getCombinedSensorDataStream();
      print("✅ Sensor streams refreshed");
    });
  }

  /// Test Firebase connection dengan multiple paths
Future<Map<String, dynamic>> testFirebaseConnection() async {
  final deviceId = userModel.linkedDeviceId;
  
  if (deviceId == null || deviceId.isEmpty) {
    return {
      'success': false,
      'error': 'No linked device',
      'pathTests': {},
    };
  }

  print("\n🧪 Testing Firebase connection for: $deviceId");
  
  final pathTests = <String, dynamic>{};
  
  // Test Ultrasonic Path
  try {
    final snapshot1 = await _database.ref('devices/$deviceId/sensorData/ultrasonic').get();
    pathTests['ultrasonic'] = {
      'exists': snapshot1.exists,
      'value': snapshot1.value,
      'type': snapshot1.value.runtimeType.toString(),
    };
    print("✓ Ultrasonic test: ${snapshot1.exists}");
  } catch (e) {
    pathTests['ultrasonic'] = {'error': e.toString()};
  }
  
  // Test Piezo Path (NESTED)
  try {
    final snapshot2 = await _database.ref('devices/$deviceId/sensorData/piezo/current').get();
    pathTests['piezo_current'] = {
      'exists': snapshot2.exists,
      'value': snapshot2.value,
      'type': snapshot2.value.runtimeType.toString(),
    };
    print("✓ Piezo current test: ${snapshot2.exists}, value: ${snapshot2.value}");
  } catch (e) {
    pathTests['piezo_current'] = {'error': e.toString()};
  }
  
  // Test Piezo Path (FLAT)
  try {
    final snapshot3 = await _database.ref('devices/$deviceId/sensorData/piezo').get();
    pathTests['piezo_flat'] = {
      'exists': snapshot3.exists,
      'value': snapshot3.value,
      'type': snapshot3.value.runtimeType.toString(),
    };
    print("✓ Piezo flat test: ${snapshot3.exists}");
  } catch (e) {
    pathTests['piezo_flat'] = {'error': e.toString()};
  }
  
  print("🧪 Test complete\n");
  
  return {
    'success': true,
    'deviceId': deviceId,
    'pathTests': pathTests,
    'timestamp': DateTime.now().toIso8601String(),
  };
}


  /// Monitor Firebase real-time (untuk debug panel)
  Stream<Map<String, dynamic>> monitorFirebaseConnection() {
    final deviceId = userModel.linkedDeviceId;
    
    if (deviceId == null || deviceId.isEmpty) {
      return Stream.value({
        'exists': false,
        'timestamp': DateTime.now(),
        'error': 'No device ID',
      });
    }

    // Alternative method tanpa Stream.periodic (lebih stabil)
    return _database.ref('devices/$deviceId/sensorData/ultrasonic').onValue.map((event) {
      return {
        'exists': event.snapshot.exists,
        'value': event.snapshot.value,
        'type': event.snapshot.value?.runtimeType.toString() ?? 'null',
        'timestamp': DateTime.now(),
      };
    }).handleError((error) {
      return {
        'exists': false,
        'error': error.toString(),
        'timestamp': DateTime.now(),
      };
    });
  }

  /// Dispose semua resources
  void dispose() {
    print("🧹 Disposing SensorDataService...");
    printStatistics();
    _disposeSensorStream();
    print("✅ SensorDataService disposed");
  }
  
}