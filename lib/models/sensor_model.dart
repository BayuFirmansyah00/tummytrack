// lib/models/sensor_model.dart
class SensorData {
  final int ultrasonicDistance; // cm (jarak bayi ke sensor)
  final int piezoVibration; // unit getaran
  final bool toyInteraction; // true jika mainan disentuh
  final DateTime timestamp;

  SensorData({
    required this.ultrasonicDistance,
    required this.piezoVibration,
    required this.toyInteraction,
    required this.timestamp,
  });

  // Factory untuk parse dari JSON (dari RTDB/Firestore)
  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      ultrasonicDistance: json['ultrasonicDistance'] ?? json['ultrasonic'] ?? 0, // Handle kedua format
      piezoVibration: json['piezoVibration'] ?? json['piezo'] ?? 0,
      toyInteraction: json['toyInteraction'] ?? false,
      timestamp: DateTime.tryParse(json['timestamp'] ?? DateTime.now().toIso8601String()) ?? DateTime.now(),
    );
  }

  // Serialize ke JSON untuk simpan ke Firestore/RTDB
  Map<String, dynamic> toJson() {
    return {
      'ultrasonicDistance': ultrasonicDistance,
      'piezoVibration': piezoVibration,
      'toyInteraction': toyInteraction,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // Method untuk cek apakah data fresh (dalam 10 detik)
  bool isFresh() {
    return DateTime.now().difference(timestamp).inMilliseconds < 10000;
  }

  // Method untuk hitung aktivitas bayi berdasarkan umur (hybrid dengan matras)
  // PERBAIKAN: Sesuai requirement - Ultrasonic hanya 4-6 bulan, Piezo hanya 0-3 bulan
  String calculateActivity(int ageDays) {
    final isUltrasonicActive = ultrasonicDistance > 0 && ultrasonicDistance < 30; // Bayi dekat/menjangkau
    final isPiezoActive = piezoVibration > 5; // Getaran minimal
    final isToyActive = toyInteraction;

    if (ageDays >= 0 && ageDays <= 90) {
      // 0-3 bulan: Hanya Piezo
      return isPiezoActive ? 'aktif' : 'tidak aktif';
    } else if (ageDays >= 120 && ageDays <= 180) {
      // 4-6 bulan: Hanya Ultrasonic
      return isUltrasonicActive ? 'aktif' : 'tidak aktif';
    } else {
      // Lainnya: Gunakan toy interaction atau fallback
      return isToyActive ? 'aktif' : 'tidak aktif';
    }
  }

  // Method untuk copy dengan perubahan nilai tertentu
  SensorData copyWith({
    int? ultrasonicDistance,
    int? piezoVibration,
    bool? toyInteraction,
    DateTime? timestamp,
  }) {
    return SensorData(
      ultrasonicDistance: ultrasonicDistance ?? this.ultrasonicDistance,
      piezoVibration: piezoVibration ?? this.piezoVibration,
      toyInteraction: toyInteraction ?? this.toyInteraction,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}