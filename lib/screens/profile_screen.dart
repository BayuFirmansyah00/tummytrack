import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/baby_model.dart';
import '../models/user_model.dart';
import 'edit_parent_screen.dart';
import 'edit_baby_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final int _selectedIndex = 3;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _fetchParentData();
    _fetchBabyData();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _fetchParentData() async {
    final userModel = Provider.of<UserModel>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          userModel.updateName(data['name'] ?? 'Nama Tidak Diketahui');
          userModel.updateEmail(
            data['email'] ?? user.email ?? 'Email Tidak Diketahui',
          );
        } else {
          userModel.updateEmail(user.email ?? 'Email Tidak Diketahui');
          userModel.updateName('Nama Tidak Diketahui');
        }
      } catch (e) {
        print('Error fetching parent data: $e');
        userModel.updateEmail(user.email ?? 'Email Tidak Diketahui');
        userModel.updateName('Nama Tidak Diketahui');
      }
    }
  }

  void _fetchBabyData() async {
    final babyModel = Provider.of<BabyModel>(context, listen: false);
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
          babyModel.updateName(babyDoc['name']);
          babyModel.updateGender(babyDoc['gender']);
          babyModel.updateBirthDate(DateTime.parse(babyDoc['birth_date']));
          babyModel.updateAgeRange(babyDoc['age_range']);
          babyModel.updateRelationship(babyDoc['relationship']);
        }
      } catch (e) {
        print('Error fetching baby data: $e');
      }
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

  void _onItemTapped(int index) {
    if (index != _selectedIndex) {
      String route;
      switch (index) {
        case 0:
          route = '/dashboard';
          break;
        case 1:
          route = '/tummy';
          break;
        case 2:
          route = '/history';
          break;
        default:
          return;
      }
      Navigator.of(context).pushReplacementNamed(route);
    }
  }

  Widget _buildHeader(UserModel userModel) {
    return Container(
      // Dekorasi background tetap sama
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF79BCC1), Color(0xFF9FD3D7)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        child: Padding(
          // Beri sedikit padding agar konten tidak menempel langsung di tepi layar
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            // Column utama untuk mengatur judul di atas dan konten profil di bawahnya
            crossAxisAlignment:
                CrossAxisAlignment.start, // Ratakan semua ke kiri
            children: [
              // 1. Judul "Profil" kita letakkan di tengah sendiri
              const Center(
                child: Text(
                  'Profil',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Center(
                child: Column(
                  // 2. CrossAxisAlignment diatur ke center agar semua item rata tengah
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Bagian Atas: Foto Profil
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const CircleAvatar(
                            radius: 45, // Ukuran avatar bisa disesuaikan
                            backgroundColor: Colors.white,
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: Color(0xFFE0F7FA),
                              child: Icon(
                                Icons.person,
                                size: 40,
                                color: Color(0xFF79BCC1),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // 3. SizedBox diubah dari width menjadi height untuk memberi jarak vertikal
                    const SizedBox(height: 20),

                    // 4. Widget Text langsung diletakkan di Column utama
                    //    (tanpa perlu Expanded dan Column tambahan)
                    Text(
                      userModel.name ?? 'Nama Pengguna',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      overflow:
                          TextOverflow.ellipsis, // Jika nama terlalu panjang
                    ),
                    const SizedBox(height: 5),
                    Text(
                      userModel.email ?? 'example@gmail.com',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                      overflow:
                          TextOverflow.ellipsis, // Jika email terlalu panjang
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required List<Widget> children,
    required VoidCallback onEdit,
    required IconData headerIcon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF79BCC1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    headerIcon,
                    color: const Color(0xFF79BCC1),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF79BCC1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFF79BCC1),
                    ),
                    onPressed: onEdit,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.grey[600], size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF333333),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text(
                  'Konfirmasi Keluar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                content: const Text(
                  'Apakah Anda yakin ingin keluar dari aplikasi?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Batal',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      FirebaseAuth.instance.signOut().then((_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Berhasil keluar!'),
                            backgroundColor: Colors.green[400],
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                        Navigator.pushReplacementNamed(context, '/login');
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Keluar',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        icon: const Icon(Icons.logout, color: Colors.white),
        label: const Text(
          'Keluar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final babyModel = Provider.of<BabyModel>(context);
    final userModel = Provider.of<UserModel>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              _buildHeader(userModel),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildInfoCard(
                        title: 'Informasi Orang Tua',
                        headerIcon: Icons.person_outline,
                        onEdit: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditParentScreen(),
                            ),
                          );
                        },
                        children: [
                          _buildInfoRow(
                            Icons.person_outline,
                            'Nama',
                            userModel.name ?? 'User',
                          ),
                          _buildInfoRow(
                            Icons.phone_outlined,
                            'Telepon',
                            userModel.phone ?? '081234567890',
                          ),
                          _buildInfoRow(
                            Icons.email_outlined,
                            'Email',
                            userModel.email ?? 'example@gmail.com',
                          ),
                        ],
                      ),
                      _buildInfoCard(
                        title: 'Informasi Bayi',
                        headerIcon: Icons.child_care_outlined,
                        onEdit: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => EditBabyScreen()),
                          );
                        },
                        children: [
                          _buildInfoRow(
                            Icons.child_care_outlined,
                            'Nama Bayi',
                            babyModel.name ?? 'John',
                          ),
                          _buildInfoRow(
                            Icons.calendar_today_outlined,
                            'Tanggal Lahir',
                            babyModel.birthDate?.toString().split(' ')[0] ??
                                '22 Juli 2025',
                          ),
                          _buildInfoRow(
                            Icons.transgender_outlined,
                            'Jenis Kelamin',
                            babyModel.gender ?? 'Laki-Laki',
                          ),
                          _buildInfoRow(
                            Icons.timeline_outlined,
                            'Usia',
                            babyModel.ageRange ?? '2 Minggu',
                          ),
                          _buildInfoRow(
                            Icons.family_restroom_outlined,
                            'Hubungan',
                            babyModel.relationship ?? 'Ibu',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildLogoutButton(),
                      const SizedBox(height: 30),
                    ],
                  ),
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
          selectedItemColor: const Color(0xFF79BCC1),
          unselectedItemColor: Colors.grey[400],
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: _buildIcon(
                'assets/images/home_active_icon.png',
                Icons.home,
              ),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: _buildIcon(
                'assets/images/tummy_active_icon.png',
                Icons.child_care,
              ),
              label: 'Tummy',
            ),
            BottomNavigationBarItem(
              icon: _buildIcon(
                'assets/images/history_active_icon.png',
                Icons.history,
              ),
              label: 'Riwayat',
            ),
            BottomNavigationBarItem(
              icon: _buildIcon(
                'assets/images/1profile_active_icon.png',
                Icons.person,
              ),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
