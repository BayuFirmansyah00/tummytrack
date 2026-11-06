import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class TummyTimeSession {
  final DateTime date;
  final String duration;
  final String mood;
  final List<bool>? achievements;
  final List<String>? achievementTexts; // Tambahkan ini
  final List<String> matrasButtons; // Tambahkan ini
  final String babyActivity; // Tambahkan ini
  final bool toyInteraction; // Tambahkan ini
  // Anda bisa membuat sub-model untuk data sensor jika mau
  final int avgUltrasonic;
  final int avgPiezo;


  TummyTimeSession({
    required this.date,
    required this.duration,
    required this.mood,
    this.achievements,
    this.achievementTexts,
    required this.matrasButtons,
    required this.babyActivity,
    required this.toyInteraction,
    required this.avgUltrasonic,
    required this.avgPiezo,
  });

factory TummyTimeSession.fromJson(Map<String, dynamic> json) {
  print("\n📖 === PARSING SESSION DATA ===");
  
  // Parse date
  DateTime sessionDate;
  if (json['date'] is Timestamp) {
    sessionDate = (json['date'] as Timestamp).toDate();
  } else if (json['date'] is String) {
    sessionDate = DateTime.parse(json['date']);
  } else {
    sessionDate = DateTime.now();
  }
  
  print("📅 Date: $sessionDate");

  // =====================================================================
  // PERBAIKAN: Parse sensor data dengan fallback yang aman
  // =====================================================================
  final sensorData = json['sensor_data'] as Map<String, dynamic>?;
  
  int avgUltrasonic = 0;
  int avgPiezo = 0;
  String babyActivity = 'tidak aktif';
  bool toyInteraction = false;
  int activePercentage = 0;
  int toyInteractionPercentage = 0;
  
  if (sensorData != null) {
    print("📊 Sensor data found:");
    print("  Raw data: $sensorData");
    
    // Parse dengan safe casting
    avgUltrasonic = _parseIntSafe(sensorData['avg_ultrasonic_distance']);
    avgPiezo = _parseIntSafe(sensorData['avg_piezo_vibration']);
    babyActivity = sensorData['baby_activity']?.toString() ?? 'tidak aktif';
    toyInteraction = sensorData['toy_interaction'] == true;
    activePercentage = _parseIntSafe(sensorData['active_percentage']);
    toyInteractionPercentage = _parseIntSafe(sensorData['toy_interaction_percentage']);
    
    print("  ✅ Parsed ultrasonic: $avgUltrasonic cm");
    print("  ✅ Parsed piezo: $avgPiezo units");
    print("  ✅ Parsed activity: $babyActivity");
    print("  ✅ Parsed toy interaction: $toyInteraction");
    print("  Parsed active percentage: $activePercentage");
    print("  Parsed toy interaction percentage: $toyInteractionPercentage");
  } else {
    print("⚠️ No sensor data in session");
  }
  
  // Parse matras buttons
  final matrasButtons = json['matras_buttons'] as List<dynamic>?;
  final buttonList = matrasButtons?.map((e) => e.toString()).toList() ?? [];
  
  print("🔘 Matras buttons: ${buttonList.length} buttons");

  print("=== END PARSING ===\n");

  return TummyTimeSession(
    date: sessionDate,
    duration: json['duration']?.toString() ?? '0 menit',
    mood: json['mood']?.toString() ?? 'Normal',
    achievements: json['achievements'] != null 
        ? List<bool>.from(json['achievements']) 
        : null,
    achievementTexts: json['achievement_texts'] != null 
        ? List<String>.from(json['achievement_texts']) 
        : null,
    matrasButtons: buttonList,
    babyActivity: babyActivity,
    toyInteraction: toyInteraction,
    avgUltrasonic: avgUltrasonic,
    avgPiezo: avgPiezo,
  );
}

// =====================================================================
// HELPER: Safe integer parsing
// =====================================================================
static int _parseIntSafe(dynamic value) {
  if (value == null) return 0;
  
  if (value is int) return value;
  
  if (value is double) return value.toInt();
  
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  
  return 0;
}

  static List<String> getAchievementTexts(DateTime? birthDate, DateTime sessionDate) {
    if (birthDate == null) return [];
    
    final ageInDays = sessionDate.difference(birthDate).inDays;
    
    if (ageInDays <= 30) {
      return [
        'Mengangkat kepala sebentar',
        'Menoleh ke kiri dan kanan',
        'Bertahan dalam posisi tummy time 1-2 menit',
      ];
    } else if (ageInDays <= 90) {
      return [
        'Mengangkat kepala dengan stabil',
        'Menopang dengan lengan',
        'Bertahan 3-5 menit',
        'Mulai berguling',
      ];
    } else if (ageInDays <= 180) {
      return [
        'Push-up mini dengan lengan',
        'Meraih mainan di depan',
        'Bertahan 10-15 menit',
        'Berguling bolak-balik',
      ];
    } else {
      return [
        'Duduk dengan bantuan',
        'Merangkak atau bersiap merangkak',
        'Bermain dengan mainan',
        'Transisi posisi mandiri',
      ];
    }
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 2;
  DateTime? _selectedDate;
  DateTime? _babyBirthDate;
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fetchBabyData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchBabyData() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final babySnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('babies')
                .limit(1)
                .get();
        if (babySnapshot.docs.isNotEmpty) {
          final babyDoc = babySnapshot.docs.first.data();
          setState(() {
            _babyBirthDate = DateTime.parse(babyDoc['birth_date']);
          });
        } else {
          _showSnackBar('Data bayi tidak ditemukan', isError: true);
        }
      } catch (e) {
        _showSnackBar('Gagal mengambil data bayi: $e', isError: true);
      }
    } else {
      _showSnackBar('Pengguna tidak terautentikasi', isError: true);
    }
    setState(() => _isLoading = false);
    _animationController.forward();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

// PERBAIKAN: _getBabySessionsStream() di history_screen.dart
// Ganti fungsi ini untuk menghindari duplikasi

Stream<QuerySnapshot<Map<String, dynamic>>> _getBabySessionsStream() {
  final user = FirebaseAuth.instance.currentUser;
  
  if (user == null) {
    print("❌ No authenticated user");
    return const Stream.empty();
  }

  print("\n📡 Setting up sessions stream for user: ${user.uid}");

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('babies')
      .limit(1)
      .snapshots()
      .asyncExpand((babySnapshot) {
        if (babySnapshot.docs.isEmpty) {
          print("⚠️ No baby document found");
          return const Stream.empty();
        }

        final babyDoc = babySnapshot.docs.first;
        print("✅ Baby found: ${babyDoc.id}");

        // Query dengan filter tanggal yang benar
        var query = babyDoc.reference
            .collection('tummy_time_sessions')
            .orderBy('date', descending: true);
        
        // Filter berdasarkan tanggal jika dipilih
        if (_selectedDate != null) {
          final startOfDay = DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            0, 0, 0,
          );
          final endOfDay = DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            23, 59, 59,
          );
          
          print("📅 Filtering sessions for: $startOfDay to $endOfDay");
          
          query = query
              .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
              .where('date', isLessThan: Timestamp.fromDate(endOfDay));
        }

        return query.snapshots();
      });
}

// =====================================================================
// PERBAIKAN: Build ListView dengan validasi data
// =====================================================================
// Ganti bagian ListView.builder di build() dengan ini:

Widget _buildSessionsList(List<Map<String, dynamic>> sessions) {
  // Filter duplikasi berdasarkan timestamp unik
  final validSessions = <Map<String, dynamic>>[];
  final seenTimestamps = <int>{};
  
  for (final session in sessions) {
    try {
      // Validasi field yang diperlukan
      if (session['date'] == null) {
        print("⚠️ Skipping session: missing date");
        continue;
      }
      
      // Parse tanggal
      DateTime sessionDate;
      if (session['date'] is Timestamp) {
        sessionDate = (session['date'] as Timestamp).toDate();
      } else if (session['date'] is String) {
        sessionDate = DateTime.parse(session['date']);
      } else {
        continue;
      }
      
      // Buat key unik berdasarkan timestamp dalam milidetik
      final timestamp = sessionDate.millisecondsSinceEpoch;
      
      // Skip jika sudah ada
      if (seenTimestamps.contains(timestamp)) {
        print("⚠️ Skipping duplicate at $sessionDate");
        continue;
      }
      
      seenTimestamps.add(timestamp);
      validSessions.add(session);
      
    } catch (e) {
      print("❌ Error validating session: $e");
    }
  }
  
  print("✅ Valid unique sessions: ${validSessions.length} / ${sessions.length}");
  
  if (validSessions.isEmpty) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Riwayat',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedDate != null
                  ? 'Tidak ada sesi pada tanggal ini'
                  : 'Mulai sesi tummy time pertama Anda',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  return ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    itemCount: validSessions.length,
    itemBuilder: (context, index) {
      final sessionData = validSessions[index];
      
      try {
        // Parse tanggal
        DateTime sessionDateTime;
        if (sessionData['date'] is Timestamp) {
          sessionDateTime = (sessionData['date'] as Timestamp).toDate();
        } else if (sessionData['date'] is String) {
          sessionDateTime = DateTime.parse(sessionData['date']);
        } else {
          sessionDateTime = DateTime.now();
        }
        
        // Ambil data dasar
        final duration = sessionData['duration']?.toString() ?? '0 menit';
        final mood = sessionData['mood']?.toString() ?? 'Normal';
        
        // Parse data matras buttons
        final matrasButtons = sessionData['matras_buttons'] as List<dynamic>?;
        final buttonCount = matrasButtons?.length ?? 0;
        final isActive = buttonCount >= 15;
        
        // Parse sensor data
        final sensorData = sessionData['sensor_data'] as Map<String, dynamic>?;
        final hasValidSensorData = sensorData != null && (
          (sensorData['avg_ultrasonic_distance'] ?? 0) > 0 ||
          (sensorData['avg_piezo_vibration'] ?? 0) > 0
        );
        
        // Parse baby activity
        final babyActivity = sensorData?['baby_activity']?.toString() ?? 'tidak aktif';
        final toyInteraction = sensorData?['toy_interaction'] == true;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () => _showSessionDetails(sessionData),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header dengan tanggal dan badge sensor
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          DateFormat('EEEE, dd MMMM yyyy • HH:mm', 'id_ID')
                              .format(sessionDateTime),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ),
                      if (hasValidSensorData)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.sensors,
                                size: 12,
                                color: Colors.blue[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Data',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Info chips: Duration, Mood, Activity, Toy
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(
                        Icons.timer_outlined,
                        duration,
                        color: const Color(0xFF2C3E50),
                      ),
                      _buildInfoChip(
                        Icons.mood_rounded,
                        mood,
                        color: _getMoodColor(mood),
                      ),
                      _buildInfoChip(
                        isActive ? Icons.check_circle : Icons.remove_circle_outline,
                        isActive ? 'Aktif ($buttonCount)' : 'Tidak Aktif ($buttonCount)',
                        color: isActive ? Colors.green.shade600 : Colors.orange.shade700,
                      ),
                      if (hasValidSensorData)
                        _buildInfoChip(
                          Icons.baby_changing_station,
                          babyActivity == 'aktif' ? 'Aktif' : 
                          babyActivity == 'kurang berinteraksi' ? 'Kurang Aktif' : 'Pasif',
                          color: babyActivity == 'aktif' ? Colors.green : 
                                 babyActivity == 'kurang berinteraksi' ? Colors.orange : Colors.red,
                        ),
                      if (toyInteraction)
                        _buildInfoChip(
                          Icons.toys,
                          'Mainan Aktif',
                          color: const Color(0xFFFFD700),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      } catch (e) {
        print("❌ Error building session card: $e");
        return const SizedBox.shrink();
      }
    },
  );
}

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: const Color(0xFF7DD3D8),
              secondary: const Color(0xFF4A90A4),
            ), dialogTheme: DialogThemeData(backgroundColor: Colors.white),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDate = null;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _navigateTo(index);
  }

  void _navigateTo(int index) {
    String route;
    switch (index) {
      case 0:
        route = '/dashboard';
        break;
      case 1:
        route = '/tummy';
        break;
      case 2:
        return;
      case 3:
        route = '/profile';
        break;
      default:
        return;
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

void _showSessionDetails(Map<String, dynamic> sessionData) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      try {
        final session = TummyTimeSession.fromJson(sessionData);
        
        // Ambil achievement texts
        final achievementTexts = sessionData.containsKey('achievement_texts')
            ? List<String>.from(sessionData['achievement_texts'])
            : TummyTimeSession.getAchievementTexts(_babyBirthDate, session.date);

        // Ambil data sensor
        final sensorData = sessionData['sensor_data'] as Map<String, dynamic>?;
        final avgUltrasonic = sensorData?['avg_ultrasonic_distance'] ?? 0;
        final avgPiezo = sensorData?['avg_piezo_vibration'] ?? 0;
        final babyActivity = sensorData?['baby_activity']?.toString() ?? 'tidak aktif';
        final toyInteraction = sensorData?['toy_interaction'] == true;
        final activePercentage = sensorData?['active_percentage'] ?? 0;
        final toyInteractionPercentage = sensorData?['toy_interaction_percentage'] ?? 0;
        
        // Ambil data matras
        final matrasButtons = sessionData['matras_buttons'] as List<dynamic>? ?? [];
        final buttonPressed = matrasButtons.length;
        final isActive = buttonPressed >= 15;
        
        // Ambil metadata
        final babyAgeDays = sessionData['baby_age_days'] ?? 0;
        final sensorTypeUsed = sessionData['sensor_type_used'] ?? 'unknown';

        // VALIDASI: Cek apakah ada data sensor yang valid
        final hasSensorData = avgUltrasonic > 0 || avgPiezo > 0;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
              maxWidth: MediaQuery.of(context).size.width * 0.95,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7DD3D8).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.analytics_outlined,
                            color: Color(0xFF7DD3D8),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Detail Sesi Tummy Track',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Informasi lengkap aktivitas bayi',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF7F8C8D),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey[100],
                            foregroundColor: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Session Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FFFE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF7DD3D8).withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            Icons.calendar_today_rounded,
                            'Tanggal & Waktu',
                            DateFormat('EEEE, dd MMMM yyyy • HH:mm', 'id').format(session.date),
                          ),
                          const Divider(height: 24),
                          _buildInfoRow(
                            Icons.timer_outlined,
                            'Durasi Sesi',
                            session.duration,
                          ),
                          const Divider(height: 24),
                          _buildInfoRow(
                            Icons.mood_rounded,
                            'Mood Bayi',
                            session.mood,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // STATUS AKTIVITAS MATRAS
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            isActive
                                ? const Color(0xFF4CAF50).withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            isActive
                                ? const Color(0xFF4CAF50).withOpacity(0.05)
                                : Colors.orange.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive ? const Color(0xFF4CAF50) : Colors.orange,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isActive ? const Color(0xFF4CAF50) : Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isActive ? Icons.check_circle : Icons.remove_circle,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Status Aktivitas Matras',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF7F8C8D),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isActive ? 'Bayi Aktif' : 'Bayi Tidak Aktif',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: isActive ? const Color(0xFF4CAF50) : Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Tombol Tertekan',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF7F8C8D),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$buttonPressed / 55',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: isActive ? const Color(0xFF4CAF50) : Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive ? const Color(0xFF4CAF50) : Colors.orange,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    isActive ? 'AKTIF' : 'TIDAK AKTIF',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (buttonPressed > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Posisi Matras yang Tertekan:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7F8C8D),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: matrasButtons.take(20).map((button) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF7DD3D8).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          button.toString(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF2C3E50),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  if (buttonPressed > 20)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        '... dan ${buttonPressed - 20} tombol lainnya',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // DATA SENSOR SECTION
                         if (hasSensorData) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Data Sensor',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1E1E1E),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Usia: $babyAgeDays hari • $sensorTypeUsed',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.sensors,
                                    color: Color(0xFF4CAF50),
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            // Sensor Cards
                            if (avgUltrasonic > 0)
                              _buildSensorCard(
                                icon: Icons.straighten,
                                title: 'Jarak Ultrasonic',
                                value: '$avgUltrasonic cm',
                                subtitle: avgUltrasonic < 30
                                    ? 'Bayi dekat dengan mainan'
                                    : 'Dalam jarak aman',
                                color: const Color(0xFF4CAF50),
                                isActive: avgUltrasonic < 30,
                              ),
                            if (avgUltrasonic > 0 && avgPiezo > 0)
                              const SizedBox(height: 16),
                            if (avgPiezo > 0)
                              _buildSensorCard(
                                icon: Icons.vibration,
                                title: 'Getaran Piezo',
                                value: '$avgPiezo unit',
                                subtitle: avgPiezo > 5
                                    ? 'Getaran terdeteksi'
                                    : 'Tidak ada getaran',
                                color: const Color(0xFFFFA726),
                                isActive: avgPiezo > 5,
                              ),
                            
                            const SizedBox(height: 16),
                            
                            // Baby Activity Status
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: babyActivity == 'aktif'
                                    ? const Color(0xFF4CAF50).withOpacity(0.1)
                                    : babyActivity == 'kurang berinteraksi'
                                        ? Colors.orange.withOpacity(0.1)
                                        : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: babyActivity == 'aktif'
                                          ? const Color(0xFF4CAF50)
                                          : babyActivity == 'kurang berinteraksi'
                                              ? Colors.orange
                                              : Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.baby_changing_station,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Aktivitas Bayi',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF7F8C8D),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          babyActivity.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: babyActivity == 'aktif'
                                                ? const Color(0xFF4CAF50)
                                                : babyActivity == 'kurang berinteraksi'
                                                    ? Colors.orange
                                                    : Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (activePercentage > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '$activePercentage%',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            
                            // Toy Interaction
                            if (toyInteraction) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD700).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFFD700),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.toys,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Interaksi Mainan',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF7F8C8D),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Bayi berinteraksi dengan mainan',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFFFFD700),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (toyInteractionPercentage > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '$toyInteractionPercentage%',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      // Tampilkan pesan jika tidak ada data sensor
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Tidak ada data sensor untuk sesi ini',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ACHIEVEMENTS SECTION
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.emoji_events_outlined,
                                color: Colors.orange[600],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Pencapaian Perkembangan',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          if (session.achievements != null && session.achievements!.isNotEmpty)
                            ...List.generate(session.achievements!.length, (index) {
                              final achieved = session.achievements![index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: achieved ? Colors.green[50] : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: achieved ? Colors.green[200]! : Colors.grey[200]!,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: achieved ? Colors.green[600] : Colors.grey[400],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        achieved ? Icons.check : Icons.circle_outlined,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        index < achievementTexts.length
                                            ? achievementTexts[index]
                                            : 'Achievement ${index + 1}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: achieved ? Colors.green[800] : Colors.grey[700],
                                          fontWeight: achieved ? FontWeight.w500 : FontWeight.normal,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            })
                          else
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.orange[600],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Tidak ada data pencapaian untuk sesi ini',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF7F8C8D),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // SUMMARY STATISTICS (NEW SECTION)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF7DD3D8).withOpacity(0.1),
                            const Color(0xFF7DD3D8).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF7DD3D8).withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ringkasan Sesi',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSummaryItem(
                                Icons.grid_on,
                                'Tombol',
                                '$buttonPressed',
                                isActive ? Colors.green : Colors.orange,
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.grey[300],
                              ),
                              _buildSummaryItem(
                                Icons.baby_changing_station,
                                'Aktivitas',
                                babyActivity == 'aktif' ? 'Aktif' :
                                babyActivity == 'kurang berinteraksi' ? 'Sedang' : 'Rendah',
                                babyActivity == 'aktif' ? Colors.green :
                                babyActivity == 'kurang berinteraksi' ? Colors.orange : Colors.red,
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.grey[300],
                              ),
                              _buildSummaryItem(
                                Icons.toys,
                                'Mainan',
                                toyInteraction ? 'Ya' : 'Tidak',
                                toyInteraction ? const Color(0xFFFFD700) : Colors.grey,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Close Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7DD3D8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Tutup',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      } catch (e) {
        // Error Dialog
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.red[600],
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Oops! Terjadi Kesalahan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Data sesi tidak lengkap atau rusak.\nError: ${e.toString()}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF7F8C8D),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Tutup'),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    },
  );
}

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF7DD3D8), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF7F8C8D),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2C3E50),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSensorCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.all(12), // Kurangi padding
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Penting untuk mencegah overflow
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 18,
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isActive)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'AKTIF',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            softWrap: true,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Color _getMoodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'senang':
        return Colors.green;
      case 'rewel':
        return Colors.red;
      case 'mengantuk':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  Widget _buildInfoChip(IconData icon, String text, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(String assetPath, IconData fallbackIcon) {
    return Image.asset(
      assetPath,
      width: 24,
      height: 24,
      errorBuilder: (context, error, stackTrace) => Icon(
        fallbackIcon,
        size: 24,
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFF8FFFE),
    appBar: AppBar(
      centerTitle: true,
      title: const Text(
        'Riwayat',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color.fromARGB(255, 255, 255, 255),
        ),
      ),
      backgroundColor: const Color(0xFF7DD3D8),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => _navigateTo(0),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _fetchBabyData,
          tooltip: 'Refresh data',
        ),
      ],
    ),
    body: SafeArea(
      child: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF7DD3D8),
                    ),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Memuat riwayat sesi...',
                    style: TextStyle(
                      color: Color(0xFF7F8C8D),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF8FFFE), Color(0xFFF0FDFF)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section (unchanged)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF7DD3D8).withOpacity(0.8),
                                        const Color(0xFF7DD3D8).withOpacity(0.6),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.history_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Riwayat Aktivitas',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2C3E50),
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Pantau perkembangan tummy time bayi',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF7F8C8D),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (_babyBirthDate == null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.orange[50]!,
                                      Colors.orange[25]!,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.orange[200]!,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[100],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.orange[600],
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Perhatian',
                                            style: TextStyle(
                                              color: Color(0xFFE65100),
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Tanggal lahir bayi belum diatur. Beberapa fitur mungkin terbatas.',
                                            style: TextStyle(
                                              color: Color(0xFFE65100),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            const Text(
                              'Filter berdasarkan tanggal',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _selectDate,
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        gradient: _selectedDate != null
                                            ? LinearGradient(
                                                colors: [
                                                  const Color(0xFF7DD3D8)
                                                      .withOpacity(0.1),
                                                  const Color(0xFF7DD3D8)
                                                      .withOpacity(0.05),
                                                ],
                                              )
                                            : null,
                                        color: _selectedDate == null
                                            ? const Color(0xFFF8FFFE)
                                            : null,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _selectedDate != null
                                              ? const Color(0xFF7DD3D8)
                                              : Colors.grey[300]!,
                                          width: _selectedDate != null ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: _selectedDate != null
                                                  ? const Color(0xFF7DD3D8)
                                                      .withOpacity(0.2)
                                                  : Colors.grey[100],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.calendar_today_rounded,
                                              color: _selectedDate != null
                                                  ? const Color(0xFF7DD3D8)
                                                  : Colors.grey[500],
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _selectedDate == null
                                                      ? 'Pilih Tanggal'
                                                      : 'Tanggal Dipilih',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _selectedDate == null
                                                      ? 'Tampilkan semua tanggal'
                                                      : DateFormat(
                                                          'dd MMMM yyyy',
                                                          'id_ID',
                                                        ).format(_selectedDate!),
                                                  style: TextStyle(
                                                    color: _selectedDate != null
                                                        ? const Color(0xFF2C3E50)
                                                        : Colors.grey[600],
                                                    fontSize: 14,
                                                    fontWeight:
                                                        _selectedDate != null
                                                            ? FontWeight.w600
                                                            : FontWeight.normal,
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
                                if (_selectedDate != null) ...[
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: _clearDateFilter,
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red[50],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.red[200]!,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: Colors.red[600],
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _getBabySessionsStream(),
                            builder: (context, snapshot) {
                              // Handle loading state
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7DD3D8)),
                                        strokeWidth: 3,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'Memuat data sesi...',
                                        style: TextStyle(
                                          color: Color(0xFF7F8C8D),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              // Handle error state
                              if (snapshot.hasError) {
                                return Center(
                                  child: Text(
                                    'Error: ${snapshot.error}',
                                    style: const TextStyle(color: Colors.red, fontSize: 16),
                                  ),
                                );
                              }
                              // Handle no data or empty data
                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'Belum ada riwayat sesi.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF7F8C8D),
                                    ),
                                  ),
                                );
                              }
                              // Convert documents to list
                              final sessions = snapshot.data!.docs.map((doc) => doc.data()).toList();
                              // Build ListView
      return _buildSessionsList(sessions);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
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
            icon: _buildIcon('assets/images/tummy_active_icon.png', Icons.child_care),
            label: 'Tummy',
          ),
          BottomNavigationBarItem(
            icon: _buildIcon('assets/images/1history_active_icon.png', Icons.history),
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