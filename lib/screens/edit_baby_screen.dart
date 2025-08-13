import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/baby_model.dart';

class EditBabyScreen extends StatefulWidget {
  @override
  _EditBabyScreenState createState() => _EditBabyScreenState();
}

class _EditBabyScreenState extends State<EditBabyScreen> {
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  DateTime? _selectedBirthDate;
  String? _selectedGender;
  final _ageController = TextEditingController();
  String? _selectedRelationship;
  bool _isLoading = false;

  int _selectedIndex = 3;

  @override
  void initState() {
    super.initState();
    final babyModel = Provider.of<BabyModel>(context, listen: false);
    _nameController.text = babyModel.name ?? 'John';
    _selectedBirthDate = babyModel.birthDate ?? DateTime.now();
    _birthDateController.text = _selectedBirthDate != null
        ? "${_selectedBirthDate!.day}/${_selectedBirthDate!.month}/${_selectedBirthDate!.year}"
        : '09/08/2025';
    
    final genderOptions = ['Laki-Laki', 'Perempuan'];
    String? currentGender = babyModel.gender ?? 'Laki-Laki';
    _selectedGender = genderOptions.contains(currentGender) ? currentGender : 'Laki-Laki';
    
    final relationshipOptions = ['Ibu', 'Ayah', 'Wali'];
    String? currentRelationship = babyModel.relationship ?? 'Ibu';
    _selectedRelationship = relationshipOptions.contains(currentRelationship) ? currentRelationship : 'Ibu';
    
    _calculateAge();
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

  void _calculateAge() {
    if (_selectedBirthDate != null) {
      final now = DateTime.now();
      final difference = now.difference(_selectedBirthDate!);
      final totalDays = difference.inDays;
      final months = totalDays ~/ 30;
      final days = totalDays % 30;
      final ageString = '$months bulan $days hari';
      setState(() {
        _ageController.text = ageString;
      });
    }
  }

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
        _birthDateController.text = "${picked.day}/${picked.month}/${picked.year}";
        _calculateAge();
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.isEmpty || 
        _selectedBirthDate == null || 
        _selectedGender == null || 
        _selectedRelationship == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua field harus diisi!')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final babyModel = Provider.of<BabyModel>(context, listen: false);
      babyModel.updateName(_nameController.text);
      babyModel.updateBirthDate(_selectedBirthDate!);
      babyModel.updateGender(_selectedGender!);
      babyModel.updateAgeRange(_ageController.text);
      babyModel.updateRelationship(_selectedRelationship!);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final babySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('babies')
            .limit(1)
            .get();
        if (babySnapshot.docs.isNotEmpty) {
          final babyDoc = babySnapshot.docs.first.reference;
          await babyDoc.update({
            'name': _nameController.text,
            'birth_date': _selectedBirthDate!.toIso8601String(),
            'gender': _selectedGender,
            'age_range': _ageController.text,
            'relationship': _selectedRelationship,
            'updated_at': FieldValue.serverTimestamp(),
          });
        } else {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('babies')
              .add({
            'name': _nameController.text,
            'birth_date': _selectedBirthDate!.toIso8601String(),
            'gender': _selectedGender,
            'age_range': _ageController.text,
            'relationship': _selectedRelationship,
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data bayi berhasil disimpan!')),
      );
      Navigator.pop(context);
    } catch (e) {
      print('Error saving baby data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terjadi kesalahan saat menyimpan data!')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.grey[100],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profil Bayi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: const [Icon(Icons.edit, color: Colors.teal)],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildTextField('Nama', _nameController),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _selectDate,
                child: AbsorbPointer(
                  child: buildTextField('Tanggal Lahir', _birthDateController),
                ),
              ),
              const SizedBox(height: 12),
              buildDropdown(
                'Jenis Kelamin',
                _selectedGender,
                ['Laki-Laki', 'Perempuan'],
                (String? newValue) {
                  setState(() {
                    _selectedGender = newValue;
                  });
                },
              ),
              const SizedBox(height: 12),
              buildTextField('Usia', _ageController, enabled: false),
              const SizedBox(height: 12),
              buildDropdown(
                'Hubungan',
                _selectedRelationship,
                ['Ibu', 'Ayah', 'Wali'],
                (String? newValue) {
                  setState(() {
                    _selectedRelationship = newValue;
                  });
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB0E3E0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          'Simpan',
                          style: TextStyle(color: Colors.black),
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
          selectedItemColor: const Color(0xFF00A3FF),
          unselectedItemColor: Colors.grey[400],
          selectedFontSize: 12,
          unselectedFontSize: 12,
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
              icon: _buildIcon('assets/images/history_active_icon.png', Icons.history),
              label: 'Riwayat',
            ),
            BottomNavigationBarItem(
              icon: _buildIcon('assets/images/1profile_active_icon.png', Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTextField(String label, TextEditingController controller, {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled ? Colors.grey[200] : Colors.grey[300],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: label == 'Tanggal Lahir' 
                ? const Icon(Icons.calendar_today, color: Color(0xFF7DD3FC)) 
                : null,
          ),
        ),
      ],
    );
  }

  Widget buildDropdown(String label, String? value, List<String> items, void Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: items.contains(value) ? value : null,
          hint: Text(label),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[200],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: items.isNotEmpty ? items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList() : [],
          onChanged: items.isNotEmpty ? onChanged : null,
        ),
      ],
    );
  }
}