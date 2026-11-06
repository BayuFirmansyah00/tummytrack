import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:TummyTrack/models/user_model.dart';

class DatabaseService {
  final UserModel userModel;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  
  StreamSubscription? _buttonSubscription;
  // DatabaseReference not required currently; keep subscription only

  DatabaseService(this.userModel);

  /// Stream untuk membaca button pressed dari matras
  Stream<Set<String>> getMatrasDataStream() {
    final deviceId = userModel.linkedDeviceId;
    
    if (deviceId == null || deviceId.isEmpty) {
      print("⚠️ No linked device. Matras stream returning empty set.");
      return Stream.value(<String>{});
    }

    final dbRef = _database.ref('devices/$deviceId/buttonPressed');  // PERUBAHAN: Hapus /sensorData/ agar sesuai dengan ESP32
    
    print("\n🔍 Firebase Matras Stream Setup:");
    print("   Path: devices/$deviceId/buttonPressed");  // PERUBAHAN: Update pesan log
    print("   Database URL: ${_database.app.options.databaseURL}");

    return dbRef.onValue.map((event) {
      print("\n📥 Firebase Event Received:");
      print("   Exists: ${event.snapshot.exists}");
      print("   Path: ${event.snapshot.ref.path}");
      
      if (event.snapshot.exists) {
        final data = event.snapshot.value;
        
        print("   Raw type: ${data.runtimeType}");
        print("   Raw value: $data");
        
        // CRITICAL: Data dari Firebase bisa datang dalam beberapa format
        if (data is String) {
          // Format: "A3,A4,B2,B3,..." (string dengan comma-separated)
          print("   Format: STRING (comma-separated)");
          
          final buttons = data.split(',')
              .map((b) => b.trim())
              .where((b) => b.isNotEmpty)
              .toSet();
          
          print("   ✅ Parsed ${buttons.length} buttons: $buttons");
          return buttons;
          
        } else if (data is List) {
          // Format: ['A3', 'A4', 'B2', ...] (array)
          print("   Format: LIST/ARRAY");
          
          final buttons = data
              .map((b) => b.toString().trim())
              .where((b) => b.isNotEmpty)
              .toSet();
          
          print("   ✅ Parsed ${buttons.length} buttons from list: $buttons");
          return buttons;
          
        } else if (data is Map) {
          // Format: {buttonName: true, ...} (object)
          print("   Format: MAP/OBJECT");
          
      final buttons = data.keys
        .map((k) => k.toString().trim())
              .where((b) => b.isNotEmpty)
              .toSet();
          
          print("   ✅ Parsed ${buttons.length} buttons from map: $buttons");
          return buttons;
          
        } else {
          print("   ❌ Unexpected type: ${data.runtimeType}");
          print("   Value: $data");
        }
      } else {
        print("   ⚠️ Snapshot does not exist");
      }
      
      return <String>{};
    }).handleError((error) {
      print("❌ Error in matras stream: $error");
      print("   Error type: ${error.runtimeType}");
      return <String>{};
    });
  }

  /// Membaca button pressed sekali (one-time read)
  Future<Set<String>> getMatrasButtonsOnce() async {
    final deviceId = userModel.linkedDeviceId;
    
    if (deviceId == null || deviceId.isEmpty) {
      print("⚠️ No linked device. Cannot read matras buttons.");
      return <String>{};
    }

    try {
      print("\n📖 Reading matras buttons (one-time)...");
      print("   Path: devices/$deviceId/buttonPressed");  // PERUBAHAN: Hapus /sensorData/
      
      final snapshot = await _database.ref('devices/$deviceId/buttonPressed').get();  // PERUBAHAN: Hapus /sensorData/
      
      print("   Exists: ${snapshot.exists}");
      
      if (snapshot.exists) {
        final data = snapshot.value;
        
        print("   Type: ${data.runtimeType}");
        print("   Value: $data");
        
        if (data is String) {
          final buttons = data.split(',')
              .map((b) => b.trim())
              .where((b) => b.isNotEmpty)
              .toSet();
          print("   ✅ Read ${buttons.length} buttons (string format)");
          return buttons;
        } else if (data is List) {
          final buttons = data
              .map((b) => b.toString().trim())
              .where((b) => b.isNotEmpty)
              .toSet();
          print("   ✅ Read ${buttons.length} buttons (list format)");
          return buttons;
        } else if (data is Map) {
      final buttons = data.keys
        .map((k) => k.toString().trim())
              .where((b) => b.isNotEmpty)
              .toSet();
          print("   ✅ Read ${buttons.length} buttons (map format)");
          return buttons;
        }
      } else {
        print("   ⚠️ No data found at path");
      }
      
      return <String>{};
    } catch (e) {
      print("❌ Error reading matras buttons: $e");
      print("   Error type: ${e.runtimeType}");
      return <String>{};
    }
  }

  /// TEST: Cek koneksi Firebase dan baca data
  Future<void> testConnection() async {
    final deviceId = userModel.linkedDeviceId;
    
    if (deviceId == null || deviceId.isEmpty) {
      print("⚠️ No device to test");
      return;
    }

    print("\n🧪 Firebase Connection Test");
    print("   Device ID: $deviceId");
    print("   Database URL: ${_database.app.options.databaseURL}");
    print("   =================================");
    
    // Test 1: Status
    try {
      final statusSnap = await _database.ref('devices/$deviceId/status').get();
      print("   ✅ Status path: ${statusSnap.value ?? 'N/A'}");
    } catch (e) {
      print("   ❌ Status error: $e");
    }
    
    // Test 2: ButtonPressed
    try {
      final buttonSnap = await _database.ref('devices/$deviceId/buttonPressed').get();  // PERUBAHAN: Hapus /sensorData/
      print("   ✅ ButtonPressed type: ${buttonSnap.value.runtimeType}");
      print("      Value: ${buttonSnap.value ?? 'empty'}");
    } catch (e) {
      print("   ❌ ButtonPressed error: $e");
    }
    
    // Test 3: Ultrasonic
    try {
      final ultraSnap = await _database.ref('devices/$deviceId/sensorData/ultrasonic').get();  // Tidak diubah, karena ini path lain
      print("   ✅ Ultrasonic: ${ultraSnap.value ?? 'N/A'}");
    } catch (e) {
      print("   ❌ Ultrasonic error: $e");
    }
    
    print("   =================================\n");
  }

  /// Dispose resources
  void dispose() {
  _buttonSubscription?.cancel();
  _buttonSubscription = null;
  }
}