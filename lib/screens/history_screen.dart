import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _selectedIndex = 2;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
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
        return FirebaseFirestore.instance.collection('empty').limit(0).get();
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
        final session = TummyTimeSession.fromJson(sessionData);
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
                Text('Tanggal: ${DateFormat('dd/MM/yyyy HH:mm').format(session.date)}'),
                Text('Durasi: ${session.duration}'),
                Text('Mood: ${session.mood}'),
                const SizedBox(height: 16),
                const Text('Pencapaian:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...session.achievements.asMap().entries.map((entry) {
                  final index = entry.key;
                  final achieved = entry.value;
                  return Row(
                    children: [
                      Icon(achieved ? Icons.check_circle : Icons.circle_outlined),
                      const SizedBox(width: 8),
                      Text(index < TummyTimeSession.achievementTexts.length 
                          ? TummyTimeSession.achievementTexts[index] 
                          : 'Achievement ${index + 1}'),
                    ],
                  );
                }),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Tutup'),
                ),
              ],
            ),
          ),
        );
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
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Riwayat Tummy Time',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.calendar_today, color: Color(0xFF7DD3D8)),
                        onPressed: _selectDate,
                      ),
                      if (_selectedDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.red),
                          onPressed: _clearDateFilter,
                        ),
                    ],
                  ),
                ],
              ),
              if (_selectedDate != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7DD3D8).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, color: Color(0xFF7DD3D8)),
                      const SizedBox(width: 8),
                      Text(
                        'Filter: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}',
                        style: const TextStyle(
                          color: Color(0xFF7DD3D8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _getBabySessionsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('Tidak ada riwayat sesi'));
                    }
                    
                    final sessions = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
                    final filteredSessions = _selectedDate != null
                        ? sessions.where((session) {
                            final sessionDate = DateTime.parse(session['date']);
                            return sessionDate.year == _selectedDate!.year &&
                                   sessionDate.month == _selectedDate!.month &&
                                   sessionDate.day == _selectedDate!.day;
                          }).toList()
                        : sessions;

                    if (filteredSessions.isEmpty) {
                      return const Center(child: Text('Tidak ada riwayat untuk tanggal ini'));
                    }

                    return ListView.builder(
                      itemCount: filteredSessions.length,
                      itemBuilder: (context, index) {
                        final session = filteredSessions[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: const Icon(Icons.timer, color: Color(0xFF7DD3D8)),
                            title: Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(session['date'])),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Durasi: ${session['duration']}'),
                                Text('Mood: ${session['mood']}'),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                            onTap: () => _showSessionDetails(session),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Theme.of(context).colorScheme.secondary,
        unselectedItemColor: Colors.grey[400],
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.baby_changing_station_outlined),
            activeIcon: Icon(Icons.baby_changing_station),
            label: 'Tummy',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
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
  
  static const List<String> achievementTexts = [
    'Mengangkat kepala',
    'Mendorong dengan lengan',
    'Berbalik ke samping',
    'Mencapai mainan',
    'Menendang kaki',
    'Tertawa',
    'Bergerak maju',
  ];
  
  TummyTimeSession.fromJson(Map<String, dynamic> json) {
    date = DateTime.parse(json['date']);
    duration = json['duration'];
    mood = json['mood'];
    achievements = List<bool>.from(json['achievements']);
  }
}