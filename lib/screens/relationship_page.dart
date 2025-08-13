import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/baby_model.dart';

class RelationshipPage extends StatefulWidget {
  @override
  _RelationshipPageState createState() => _RelationshipPageState();
}

class _RelationshipPageState extends State<RelationshipPage> {
  String? _selectedRelationship;
  bool _isLoading = false;

  Future<void> _nextScreen() async {
    if (_selectedRelationship == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih hubungan terlebih dahulu')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final babyModel = Provider.of<BabyModel>(context, listen: false);
      babyModel.updateRelationship(_selectedRelationship!);

      // Logging semua data BabyModel
      print('Baby relationship updated: ${babyModel.relationship}');
      print('Complete BabyModel data:');
      print('  Name: ${babyModel.name}');
      print('  Gender: ${babyModel.gender}');
      print('  Birth Date: ${babyModel.birthDate}');
      print('  Age Range: ${babyModel.ageRange}');
      print('  Relationship: ${babyModel.relationship}');

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final babySnapshot = await userDoc.collection('babies').limit(1).get();

        if (babySnapshot.docs.isNotEmpty) {
          // Update existing baby data
          final babyDoc = babySnapshot.docs.first.reference;
          await babyDoc.update({
            'name': babyModel.name,
            'gender': babyModel.gender,
            'birth_date': babyModel.birthDate?.toIso8601String(),
            'age_range': babyModel.ageRange,
            'relationship': babyModel.relationship,
            'updated_at': FieldValue.serverTimestamp(),
          });
          print('Updated existing baby data for ${user.uid}');
        } else {
          // Create new baby data
          await userDoc.collection('babies').add({
            'name': babyModel.name,
            'gender': babyModel.gender,
            'birth_date': babyModel.birthDate?.toIso8601String(),
            'age_range': babyModel.ageRange,
            'relationship': babyModel.relationship,
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });
          print('Created new baby data for ${user.uid}');
        }

        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada pengguna yang login')),
        );
      }
    } catch (e) {
      print('Error saving baby data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terjadi kesalahan saat menyimpan data')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                height: 4,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Apa hubungan Anda dengan bayi?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              DropdownButtonFormField<String>(
                value: _selectedRelationship,
                hint: Text('Pilih Hubungan', style: TextStyle(color: Colors.grey[500])),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF7DD3FC)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                ),
                items: <String>['Ibu', 'Ayah', 'Wali'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: const TextStyle(fontSize: 16)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedRelationship = newValue;
                  });
                },
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _nextScreen,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7DD3FC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Lanjut',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}