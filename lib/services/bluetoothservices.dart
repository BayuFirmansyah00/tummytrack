// bluetoothservices.dart - PERBAIKAN SEDERHANA

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import '../services/connectdevservices.dart'; 

class BluetoothController extends GetxController {
  final FlutterBluetoothSerial bluetooth = FlutterBluetoothSerial.instance;

  var discoveredDevices = <BluetoothDiscoveryResult>[].obs;
  var isScanning = false.obs;
  var connectionStatus = ''.obs;

  StreamSubscription<BluetoothDiscoveryResult>? _discoveryStreamSub;
  BluetoothConnection? connection;
  BluetoothDevice? connectedDevice;

  @override
  void onInit() {
    super.onInit();
    bluetooth.requestEnable();
  }

  void scanDevices() {
    discoveredDevices.clear();
    isScanning.value = true;
    _discoveryStreamSub = bluetooth.startDiscovery().listen(
      (result) {
        final exists = discoveredDevices.any(
          (d) => d.device.address == result.device.address,
        );
        if (!exists) {
          discoveredDevices.add(result);
        }
      },
      onError: (e) {
        Get.snackbar("Error", "Gagal memindai: $e");
        isScanning.value = false;
      },
      onDone: () {
        isScanning.value = false;
      },
    );
    Future.delayed(const Duration(seconds: 8), () {
      if (isScanning.value) {
        stopScan();
      }
    });
  }

  void stopScan() {
    _discoveryStreamSub?.cancel();
    isScanning.value = false;
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      stopScan();
      connection = await BluetoothConnection.toAddress(device.address);
      connectedDevice = device;

      Get.snackbar(
        "Tersambung",
        "Berhasil terhubung ke ${device.name ?? device.address}",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // ===================================================================
      // PERBAIKAN: Gunakan Bluetooth address langsung (tidak perlu menunggu)
      // ===================================================================
      
      // Ekstrak MAC dari Bluetooth address
      String bluetoothMAC = device.address.replaceAll(":", "").toUpperCase();
      
      print("\n[Bluetooth Connect]");
      print("  Bluetooth Address: ${device.address}");
      print("  Extracted MAC: $bluetoothMAC");
      print("  Length: ${bluetoothMAC.length}");

      connectionStatus.value = "connected";
      if (Get.isDialogOpen ?? false) Get.back();

      // Link ke Firebase
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final firebaseService = FirebaseService();
        
        print("\n[Firebase Linking]");
        print("  UID: ${user.uid}");
        print("  Device ID: $bluetoothMAC");
        
        await firebaseService.linkDeviceToUser(
          uid: user.uid,
          deviceId: bluetoothMAC,
        );
        
        Get.snackbar(
          "Sinkronisasi Akun",
          "Perangkat berhasil ditautkan ke akun Anda.",
          backgroundColor: Colors.blue,
          colorText: Colors.white,
        );
      }

      // Dengarkan responses dari ESP32 untuk WiFi config
      connection?.input?.listen(
        (data) {
          String response = String.fromCharCodes(data).trim();
          print("Data diterima dari ESP32: $response");

          if (response.toLowerCase().contains("ok")) {
            if (Get.isDialogOpen ?? false) {
              Get.back();
            }
            Get.snackbar(
              "Konfigurasi Berhasil",
              "Perangkat matras berhasil terhubung ke WiFi.",
              backgroundColor: Colors.green,
              colorText: Colors.white,
              duration: const Duration(seconds: 4),
            );
          } else if (response.toLowerCase().contains("error")) {
            Get.snackbar(
              "Konfigurasi Gagal",
              response,
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
          }
        },
        onDone: () {
          print("Bluetooth stream closed");
          disconnectFromDevice();
        },
        onError: (error) {
          print("Bluetooth stream error: $error");
        },
      );
      
    } catch (e) {
      print("Connection error: $e");
      Get.snackbar("Error", "Gagal terhubung: $e");
      connectionStatus.value = "disconnected";
    }
  }

  Future<void> sendData(String data) async {
    if (connection?.isConnected ?? false) {
      connection?.output.add(Uint8List.fromList(data.codeUnits));
      await connection?.output.allSent;
      print("Data terkirim: $data");
    } else {
      Get.snackbar("Error", "Tidak ada perangkat terhubung.");
    }
  }

  Future<void> disconnectFromDevice() async {
    await connection?.close();
    if (connectionStatus.value != "disconnected") {
      Get.snackbar("Terputus", "Koneksi dengan perangkat telah diputus.");
    }
    connectionStatus.value = "disconnected";
    connectedDevice = null;
    connection = null;
  }

  @override
  void onClose() {
    _discoveryStreamSub?.cancel();
    connection?.dispose();
    super.onClose();
  }
}