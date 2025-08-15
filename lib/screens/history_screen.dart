import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Add this for Indonesian locale

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _selectedIndex = 2;
  DateTime? _selectedDate;
  DateTime? _babyBirthDate;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null); // Initialize Indonesian locale
    _fetchBabyData();
  }

  Future<void> _fetchBabyData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final babySnapshot = await FirebaseFirestore.instance
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
        }
      } catch (e) {
        print('Error fetching baby data: $e');
      }
    }
  }

  Stream<QuerySnapshot> _getBabySessionsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('babies')
          .limit(1)
          .snapshots()
          .asyncMap((babySnapshot) async {
        if (babySnapshot.docs.isNotEmpty) {
          final babyDoc = babySnapshot.docs.first;
          print('Fetching sessions for baby: ${babyDoc.id}');
          return await babyDoc.reference.collection('tummy_time_sessions')
              .orderBy('createdAt', descending: true)
              .get();
        }
        return await FirebaseFirestore.instance.collection('empty').limit(0).get();
      });
    }
    return Stream.value(FirebaseFirestore.instance.collection('empty').limit(0).get() as QuerySnapshot);
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
            ),
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
      builder: (BuildContext context) {
        TummyTimeSession? session;
        try {
          session = TummyTimeSession.fromJson(sessionData);
          final achievementTexts = sessionData.containsKey('achievement_texts')
              ? List<String>.from(sessionData['achievement_texts'])
              : TummyTimeSession.getAchievementTexts(_babyBirthDate, session!.date);

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detail Sesi',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Tanggal: ${DateFormat('dd/MM/yyyy HH:mm').format(session!.date)}'),
                  Text('Durasi: ${session.duration}'), // Display duration
                  Text('Mood: ${session.mood}'),
                  const SizedBox(height: 16),
                  const Text('Pencapaian:', style: TextStyle(fontWeight: FontWeight.bold)),
                  if (session!.achievements.isNotEmpty)
                    ...List.generate(
                      session!.achievements.length,
                      (index) {
                        final achieved = session!.achievements[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Icon(
                              achieved ? Icons.check_circle : Icons.circle_outlined,
                              color: achieved ? Colors.green : Colors.grey,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                index < achievementTexts.length
                                    ? achievementTexts[index]
                                    : 'Achievement ${index + 1}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                  else
                    const Text('Tidak ada data pencapaian'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Tutup'),
                  ),
                ],
              ),
            ),
          );
        } catch (e) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Error: Data sesi tidak lengkap atau rusak.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Tutup'),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => _navigateTo(0),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Riwayat',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedDate == null
                            ? 'Pilih Tanggal'
                            : DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate!),
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const Icon(Icons.calendar_today, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              if (_selectedDate != null) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _clearDateFilter,
                  child: const Text(
                    'Hapus Filter Tanggal',
                    style: TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _getBabySessionsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('Tidak ada riwayat sesi.'));
                    }
                    final sessions = snapshot.data!.docs
                        .map((doc) => doc.data() as Map<String, dynamic>)
                        .where((session) {
                      if (_selectedDate == null) return true;
                      DateTime sessionDate;
                      if (session['date'] is Timestamp) {
                        sessionDate = (session['date'] as Timestamp).toDate().toLocal();
                      } else {
                        sessionDate = DateTime.parse(session['date']).toLocal();
                      }
                      return sessionDate.year == _selectedDate!.year &&
                          sessionDate.month == _selectedDate!.month &&
                          sessionDate.day == _selectedDate!.day;
                    }).toList();
                    if (sessions.isEmpty) {
                      return const Center(child: Text('Tidak ada sesi pada tanggal ini.'));
                    }
                    return ListView.builder(
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        DateTime sessionDateTime;
                        if (session['date'] is Timestamp) {
                          sessionDateTime = (session['date'] as Timestamp).toDate();
                        } else {
                          sessionDateTime = DateTime.parse(session['date']);
                        }
                        final formattedDate = DateFormat('EEEE, dd MMMM yyyy, h.mm a', 'id').format(sessionDateTime);
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Image.asset(
                              'assets/images/1tummy_active_icon.png', // Assume this asset
                              width: 40,
                              height: 40,
                            ),
                            title: const Text(
                              'Tummy Track',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                              ),
                            ),
                            subtitle: Text(formattedDate),
                            trailing: ElevatedButton(
                              onPressed: () => _showSessionDetails(session),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE0F7FA),
                                foregroundColor: const Color(0xFF7DD3D8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Detail'),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
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
              icon: Image.asset('assets/images/home_active_icon.png'),
              activeIcon: Image.asset('assets/images/home_active_icon.png'),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Image.asset('assets/images/tummy_active_icon.png'),
              activeIcon: Image.asset('assets/images/tummy_active_icon.png'),
              label: 'Tummy',
            ),
            BottomNavigationBarItem(
              icon: Image.asset('assets/images/1history_active_icon.png'),
              activeIcon: Image.asset('assets/images/1history_active_icon.png'),
              label: 'Riwayat',
            ),
            BottomNavigationBarItem(
              icon: Image.asset('assets/images/profile_active_icon.png'),
              activeIcon: Image.asset('assets/images/profile_active_icon.png'),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

class TummyTimeSession {
  String? id;
  late DateTime date;
  late String duration;
  late String mood;
  late List<bool> achievements;
  
  static List<String> getAchievementTexts(DateTime? birthDate, DateTime sessionDate) {
    if (birthDate == null) {
      // Default untuk bayi tanpa tanggal lahir (anggap 0-3 bulan)
      return [
        'Bayi bisa mengangkat kepala mandiri hingga setinggi 45 derajat?',
        'Bayi bisa menggerakkan kepala dari kiri/kanan ke tengah?',
        'Bayi bisa melihat dan menatap wajah Anda?',
        'Bayi bisa mengoceh spontan atau bereaksi dengan mengoceh?',
        'Bayi membalas tersenyum ketika diajak bicara/ tersenyum?',
        'Bayi bereaksi terkejut terhadap suara keras?',
        'Bayi mengenal ibu dengan pengelihatan, penciuman, pendengaran, kontak?',
      ];
    }

    final ageDays = sessionDate.difference(birthDate).inDays;

    if (ageDays <= 90) {
      // Usia 0-3 bulan
      return [
        'Bayi bisa mengangkat kepala mandiri hingga setinggi 45 derajat?',
        'Bayi bisa menggerakkan kepala dari kiri/kanan ke tengah?',
        'Bayi bisa melihat dan menatap wajah Anda?',
        'Bayi bisa mengoceh spontan atau bereaksi dengan mengoceh?',
        'Bayi membalas tersenyum ketika diajak bicara/ tersenyum?',
        'Bayi bereaksi terkejut terhadap suara keras?',
        'Bayi mengenal ibu dengan pengelihatan, penciuman, pendengaran, kontak?',
      ];
    } else if (ageDays <= 180) {
      // Usia 4-6 bulan
      return [
        'Bayi bisa berbalik dari telungkup ke telentang?',
        'Bayi bisa mengangkat kepala secara mandiri hingga tegak 90 derajat?',
        'Bayi bisa mempertahankan posisi kepala tetap tegak dan stabil?',
        'Bayi bisa menggenggam atau meraih mainan?',
        'Bayi bisa mengamati tangannya sendiri?',
        'Bayi mengeluarkan suara gembira bernada tinggi atau memekik?',
        'Bayi tersenyum ketika melihat mainan saat bermain sendiri?',
      ];
    } else {
      // Default untuk usia lainnya
      return [
        'Bayi bisa mengangkat kepala mandiri hingga setinggi 45 derajat?',
        'Bayi bisa menggerakkan kepala dari kiri/kanan ke tengah?',
        'Bayi bisa melihat dan menatap wajah Anda?',
      ];
    }
  }
  
  TummyTimeSession.fromJson(Map<String, dynamic> json) {
    if (json['date'] is Timestamp) {
      date = (json['date'] as Timestamp).toDate();
    } else {
      date = DateTime.parse(json['date']);
    }
    duration = json['duration'];
    mood = json['mood'];
    achievements = List<bool>.from(json['achievements']);
  }
}