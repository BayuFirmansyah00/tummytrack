import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/baby_model.dart';

class EditBabyScreen extends StatefulWidget {
  const EditBabyScreen({super.key});

  @override
  _EditBabyScreenState createState() => _EditBabyScreenState();
}

class _EditBabyScreenState extends State<EditBabyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  DateTime? _selectedBirthDate;
  String? _selectedGender;
  final _ageController = TextEditingController();
  String? _selectedRelationship;
  bool _isLoading = false;
  bool _isLoadingData = true;

  final int _selectedIndex = 3;

  @override
  void initState() {
    super.initState();
    _loadBabyData();
  }

  Future<void> _loadBabyData() async {
    setState(() {
      _isLoadingData = true;
    });

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
          final babyData = babySnapshot.docs.first.data();
          setState(() {
            _nameController.text = babyData['name'] ?? '';
            _selectedGender = babyData['gender'] ?? 'Laki-Laki';
            _selectedRelationship = babyData['relationship'] ?? 'Ibu';
            
            if (babyData['birth_date'] != null) {
              _selectedBirthDate = DateTime.parse(babyData['birth_date']);
              _birthDateController.text = 
                  "${_selectedBirthDate!.day}/${_selectedBirthDate!.month}/${_selectedBirthDate!.year}";
            }
            
            _calculateAge();
          });
        } else {
          // Set default values
          setState(() {
            _selectedGender = 'Laki-Laki';
            _selectedRelationship = 'Ibu';
          });
        }
      } catch (e) {
        print('Error loading baby data: $e');
        setState(() {
          _selectedGender = 'Laki-Laki';
          _selectedRelationship = 'Ibu';
        });
      }
    }

    setState(() {
      _isLoadingData = false;
    });
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF79BCC1),
              onPrimary: Colors.white,
              onSurface: Color(0xFF333333),
            ),
          ),
          child: child!,
        );
      },
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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanggal lahir harus diisi!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        throw Exception('User tidak ditemukan. Silakan login kembali.');
      }

      print('Saving baby data for user: ${user.uid}');

      // Prepare data
      Map<String, dynamic> babyData = {
        'name': _nameController.text.trim(),
        'birth_date': _selectedBirthDate!.toIso8601String(),
        'gender': _selectedGender!,
        'age_range': _ageController.text,
        'relationship': _selectedRelationship!,
        'updated_at': FieldValue.serverTimestamp(),
      };

      // Check if baby document exists
      final babySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('babies')
          .limit(1)
          .get();

      if (babySnapshot.docs.isNotEmpty) {
        // Update existing baby
        final babyDoc = babySnapshot.docs.first.reference;
        await babyDoc.update(babyData);
        print('Baby data updated');
      } else {
        // Create new baby document
        babyData['created_at'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('babies')
            .add(babyData);
        print('New baby data created');
      }

      // Update local model
      final babyModel = Provider.of<BabyModel>(context, listen: false);
      babyModel.updateName(_nameController.text.trim());
      babyModel.updateBirthDate(_selectedBirthDate!);
      babyModel.updateGender(_selectedGender!);
      babyModel.updateAgeRange(_ageController.text);
      babyModel.updateRelationship(_selectedRelationship!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data bayi berhasil disimpan!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error saving baby data: $e');
      
      if (mounted) {
        String errorMessage = 'Terjadi kesalahan saat menyimpan data';
        
        if (e.toString().contains('permission')) {
          errorMessage = 'Tidak memiliki izin untuk menyimpan data';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Tidak ada koneksi internet';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profil Bayi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              Icons.child_care_outlined,
              color: const Color(0xFF79BCC1),
            ),
          )
        ],
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // Baby Avatar
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF79BCC1),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: const Color(0xFFE0F7FA),
                          child: Icon(
                            Icons.child_care,
                            size: 60,
                            color: const Color(0xFF79BCC1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Form Fields
                      _buildTextField(
                        label: 'Nama Bayi',
                        controller: _nameController,
                        icon: Icons.child_care_outlined,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama bayi harus diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      
                      _buildDateField(),
                      const SizedBox(height: 20),
                      
                      _buildDropdownField(
                        label: 'Jenis Kelamin',
                        value: _selectedGender,
                        items: ['Laki-Laki', 'Perempuan'],
                        icon: Icons.transgender_outlined,
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      
                      _buildTextField(
                        label: 'Usia',
                        controller: _ageController,
                        icon: Icons.timeline_outlined,
                        enabled: false,
                      ),
                      const SizedBox(height: 20),
                      
                      _buildDropdownField(
                        label: 'Hubungan',
                        value: _selectedRelationship,
                        items: ['Ibu', 'Ayah', 'Wali'],
                        icon: Icons.family_restroom_outlined,
                        onChanged: (value) {
                          setState(() {
                            _selectedRelationship = value;
                          });
                        },
                      ),
                      const SizedBox(height: 40),
                      
                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveChanges,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF79BCC1),
                            disabledBackgroundColor: Colors.grey[400],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 3,
                            shadowColor: const Color(0xFF79BCC1).withOpacity(0.4),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Simpan Perubahan',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                    ],
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
          selectedItemColor: const Color(0xFF79BCC1),
          unselectedItemColor: Colors.grey[400],
          elevation: 0,
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

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          validator: validator,
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey[100],
            prefixIcon: Icon(icon, color: const Color(0xFF79BCC1)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF79BCC1), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tanggal Lahir',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectDate,
          child: AbsorbPointer(
            child: TextFormField(
              controller: _birthDateController,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(
                  Icons.calendar_today_outlined,
                  color: Color(0xFF79BCC1),
                ),
                suffixIcon: const Icon(
                  Icons.arrow_drop_down,
                  color: Color(0xFF79BCC1),
                ),
                hintText: 'Pilih tanggal lahir',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF79BCC1), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: items.contains(value) ? value : null,
          hint: Text(
            'Pilih $label',
            style: TextStyle(color: Colors.grey[600]),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            prefixIcon: Icon(icon, color: const Color(0xFF79BCC1)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF79BCC1), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}