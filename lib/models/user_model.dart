import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserModel with ChangeNotifier {
  String? uid;
  String? name;
  String? phone;
  String? email;
  String? linkedDeviceId;

  // Ubah Map<String, dynamic> menjadi Map<String, dynamic>? agar bisa null
  void setUser(User firebaseUser, Map<String, dynamic>? firestoreData) {
    uid = firebaseUser.uid;
    email = firebaseUser.email;

    if (firestoreData != null) {
      name = firestoreData['name'] as String?;
      phone = firestoreData['phone'] as String?;
      // Ambil linked device dari data firestore jika ada
      linkedDeviceId =
          firestoreData['linkedDeviceId'] as String?; // <-- TAMBAHKAN INI
    }
    notifyListeners();
  }

  // <-- TAMBAHKAN FUNGSI BARU DI BAWAH INI -->
  void setLinkedDevice(String? deviceId) {
    linkedDeviceId = deviceId;
    notifyListeners();
    print("UserModel updated with deviceId: $deviceId");
  }

  void clearUser() {
    uid = null;
    email = null;
    name = null;
    phone = null;
    linkedDeviceId = null; // <-- TAMBAHKAN INI
    notifyListeners();
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'phone': phone,
      'email': email,
      'linkedDeviceId': linkedDeviceId, // <-- TAMBAHKAN INI
    };
  }

  void updateName(String value) {
    name = value;
    notifyListeners();
  }

  void updatePhone(String value) {
    phone = value;
    notifyListeners();
  }

  void updateEmail(String value) {
    email = value;
    notifyListeners();
  }

  /// Print device info untuk debugging
  void printDeviceInfo() {
    print("\n📱 === USER MODEL DEVICE INFO ===");
    print("UID: $uid");
    print("Email: $email");
    print("Name: $name");
    print("Phone: $phone");
    print("Linked Device ID: $linkedDeviceId");
    print("Device ID Length: ${linkedDeviceId?.length ?? 0}");
    print("Device ID Format: ${linkedDeviceId != null && linkedDeviceId!.contains(':') ? 'with colon' : 'without colon'}");
    print("================================\n");
  }
}