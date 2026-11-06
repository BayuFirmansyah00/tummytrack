import 'package:TummyTrack/models/user_model.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';

class FirebaseService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  Future<void> linkDeviceToUser({
    required String uid,
    required String deviceId,
  }) async {
    try {
      final DatabaseReference userLinkedDevicesRef = _dbRef
          .child('users')
          .child(uid)
          .child('linkedDevices')
          .child(deviceId);

      await userLinkedDevicesRef.set(true);
      if (Get.isRegistered<UserModel>()) {
        final userModel = Get.find<UserModel>();
        userModel.setLinkedDevice(deviceId);
      }

      print('Sukses: Perangkat $deviceId berhasil ditautkan ke user $uid');
    } catch (e) {
      
      print('Error saat menautkan perangkat: $e');
      
      throw Exception('Gagal menautkan perangkat.');
    }
  }
}
