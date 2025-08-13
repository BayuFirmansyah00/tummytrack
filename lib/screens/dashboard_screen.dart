import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/baby_model.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _babyName;
  int _currentCarouselIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchBabyName();
  }

  void _fetchBabyName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final babySnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('babies')
            .limit(1)
            .get();
        if (babySnapshot.docs.isNotEmpty) {
          final babyDoc = babySnapshot.docs.first.data();
          final babyModel = Provider.of<BabyModel>(context, listen: false);
          setState(() {
            _babyName = babyDoc['name'] ?? 'Baby John';
          });
          babyModel.updateName(babyDoc['name']);
          babyModel.updateGender(babyDoc['gender']);
          babyModel.updateBirthDate((babyDoc['birth_date'] is Timestamp)
              ? (babyDoc['birth_date'] as Timestamp).toDate()
              : DateTime.tryParse(babyDoc['birth_date'] ?? '') ?? DateTime.now());
          babyModel.updateAgeRange(babyDoc['age_range']);
          babyModel.updateRelationship(babyDoc['relationship']);
        }
      } else {
        setState(() {
          _babyName = 'Guest';
        });
      }
    } catch (e) {
      print('Error fetching baby data: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index != 0) {
      _navigateTo(index);
    }
  }

  Widget _buildIcon(String assetPath, IconData fallbackIcon) {
    return Image.asset(
      assetPath,
      width: 24,
      height: 24,
      errorBuilder: (context, error, stackTrace) {
        return Icon(fallbackIcon, size: 24);
      },
    );
  }

  void _navigateTo(int index) {
    String route;
    switch (index) {
      case 1:
        route = '/tummy';
        break;
      case 2:
        route = '/history';
        break;
      case 3:
        route = '/profile';
        break;
      default:
        return;
    }
    Navigator.of(context).pushReplacementNamed(route).then((value) {
      print('Returned from $route');
    }).catchError((error) {
      print('Navigation error to $route: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal navigasi ke $route: $error')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final babyModel = Provider.of<BabyModel>(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.person,
                        size: 40,
                        color: Color(0xFF00A3FF),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/profile').then((value) {
                          print('Returned from /profile');
                        }).catchError((error) {
                          print('Navigation error to /profile: $error');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal navigasi ke profil: $error')),
                          );
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.notifications,
                        size: 24,
                        color: Color(0xFF00A3FF),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/notification').then((value) {
                          print('Returned from /notification');
                        }).catchError((error) {
                          print('Navigation error to /notification: $error');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal navigasi ke notifikasi: $error')),
                          );
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Hai, ${_babyName ?? babyModel.name ?? 'Baby John'}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const Text(
                  'Selamat Datang di aplikasi Tummy Track',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  children: [
                    CarouselSlider(
                      options: CarouselOptions(
                        height: 200,
                        enlargeCenterPage: true,
                        autoPlay: false,
                        enableInfiniteScroll: false,
                        viewportFraction: 0.9,
                        onPageChanged: (index, reason) {
                          setState(() {
                            _currentCarouselIndex = index;
                          });
                        },
                      ),
                      items: [
                        Image.asset('assets/images/card beranda 1.png'),
                        Image.asset('assets/images/card beranda 2.png'),
                        Image.asset('assets/images/card beranda 3.png'),
                        Image.asset('assets/images/card beranda 4.png'),
                        Image.asset('assets/images/card beranda 5.png'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentCarouselIndex == index
                                ? const Color(0xFF00A3FF)
                                : Colors.grey[400],
                          ),
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Tummy Time Track',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<DateTime>(
                        stream: Stream.periodic(const Duration(seconds: 1), (i) => DateTime.now()),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Text('Loading...');
                          final now = snapshot.data!;
                          return Text(
                            '${now.day}-${now.month}-${now.year}, ${now.hour}:${now.minute.toString().padLeft(2, '0')} WIB',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: true,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: Colors.grey[300]!,
                                  strokeWidth: 0.5,
                                );
                              },
                            ),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    switch (value.toInt()) {
                                      case 0: return Text('Mon', style: TextStyle(color: Colors.grey, fontSize: 10));
                                      case 1: return Text('Tue', style: TextStyle(color: Colors.grey, fontSize: 10));
                                      case 2: return Text('Wed', style: TextStyle(color: Colors.grey, fontSize: 10));
                                      case 3: return Text('Thu', style: TextStyle(color: Colors.grey, fontSize: 10));
                                      case 4: return Text('Fri', style: TextStyle(color: Colors.grey, fontSize: 10));
                                      case 5: return Text('Sat', style: TextStyle(color: Colors.grey, fontSize: 10));
                                      case 6: return Text('Sun', style: TextStyle(color: Colors.grey, fontSize: 10));
                                      default: return Text('');
                                    }
                                  },
                                  reservedSize: 22,
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: TextStyle(color: Colors.grey, fontSize: 10),
                                    );
                                  },
                                  reservedSize: 28,
                                ),
                              ),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border.all(color: Colors.grey[300]!, width: 0.5),
                            ),
                            minX: 0,
                            maxX: 6,
                            minY: 0,
                            maxY: 15,
                            lineBarsData: [
                              LineChartBarData(
                                spots: [
                                  FlSpot(0, 5),
                                  FlSpot(1, 7),
                                  FlSpot(2, 10),
                                  FlSpot(3, 8),
                                  FlSpot(4, 12),
                                  FlSpot(5, 9),
                                  FlSpot(6, 6),
                                ],
                                isCurved: true,
                                color: const Color(0xFF00A3FF),
                                barWidth: 2,
                                dotData: FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: const Color(0xFF00A3FF).withOpacity(0.2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF00A3FF),
        unselectedItemColor: Colors.grey[400],
        items: [
          BottomNavigationBarItem(
            icon: _buildIcon('assets/images/1home_active_icon.png', Icons.home),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: _buildIcon('assets/images/tummy_active_icon.png', Icons.child_care),
            label: 'Tummy',
          ),
          BottomNavigationBarItem(
            icon: _buildIcon('assets/images/history_active_icon.png', Icons.history),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: _buildIcon('assets/images/profile_active_icon.png', Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}