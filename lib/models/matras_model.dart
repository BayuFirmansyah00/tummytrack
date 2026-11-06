// lib/models/matras_model.dart
class MatrasData {
  final List<String> pressedButtons; // e.g., ['A1', 'B3']
  final int count; // Jumlah tombol aktif
  final DateTime timestamp;

  MatrasData({
    required this.pressedButtons,
    required this.count,
    required this.timestamp,
  });

  // Factory untuk parse dari JSON (dari RTDB/Firestore)
  factory MatrasData.fromJson(Map<String, dynamic> json) {
    return MatrasData(
      pressedButtons: List<String>.from(json['pressed_buttons'] ?? []),
      count: json['count'] ?? 0,
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  // Serialize ke JSON untuk simpan ke Firestore/RTDB
  Map<String, dynamic> toJson() {
    return {
      'pressed_buttons': pressedButtons,
      'count': count,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // Method untuk cek apakah data fresh (dalam 10 detik)
  bool isFresh() {
    return DateTime.now().difference(timestamp).inMilliseconds < 10000;
  }

  // Method untuk cek apakah matras aktif (ada tombol ditekan)
  bool isActive() {
    return count > 0;
  }

  // Method untuk convert ke grid 5x11 (untuk UI)
  List<List<bool>> toGrid() {
    // Inisialisasi grid 5 baris x 11 kolom, semua false
    List<List<bool>> grid = List.generate(5, (_) => List.filled(11, false));
    
    // Set true berdasarkan pressedButtons (misal 'A1' -> row 0, col 0)
    for (String button in pressedButtons) {
      if (button.length >= 2) {
        String rowChar = button.substring(0, 1).toUpperCase();
        String colStr = button.substring(1);
        int row = 'ABCDE'.indexOf(rowChar);
        int col = (int.tryParse(colStr) ?? 1) - 1;
        if (row >= 0 && row < 5 && col >= 0 && col < 11) {
          grid[row][col] = true;
        }
      }
    }
    return grid;
  }
}