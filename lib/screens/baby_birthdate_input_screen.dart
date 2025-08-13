import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/baby_model.dart';

class BirthDatePage extends StatefulWidget {
  const BirthDatePage({Key? key}) : super(key: key);

  @override
  _BirthDatePageState createState() => _BirthDatePageState();
}

class _BirthDatePageState extends State<BirthDatePage> {
  DateTime? selectedDate;

  void _calculateAge() {
    if (selectedDate != null) {
      final now = DateTime.now(); // Menggunakan waktu nyata
      final difference = now.difference(selectedDate!);
      final totalDays = difference.inDays;
      final months = totalDays ~/ 30;
      final days = totalDays % 30;
      final ageString = '$months bulan $days hari';
      final babyModel = Provider.of<BabyModel>(context, listen: false);
      babyModel.updateAgeRange(ageString);
      print('Calculated age: $ageString');
    }
  }

  void _nextScreen() {
    if (selectedDate != null) {
      final babyModel = Provider.of<BabyModel>(context, listen: false);
      babyModel.updateBirthDate(selectedDate!);
      _calculateAge();
      print('Baby birthdate updated: ${babyModel.birthDate}');
      print('Baby age range updated: ${babyModel.ageRange}');
      print('Saving to Firestore: ${babyModel.toJson()}');
      Navigator.pushReplacementNamed(context, '/relationship');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masukkan tanggal lahir')));
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
                  'Tanggal lahir bayi Anda?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null && picked != selectedDate) {
                    setState(() {
                      selectedDate = picked;
                    });
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[50],
                  ),
                  child: Row(
                    children: [
                      Text(
                        selectedDate != null 
                            ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"
                            : 'Masukkan Tanggal Lahir',
                        style: TextStyle(
                          fontSize: 16,
                          color: selectedDate != null ? Colors.black87 : Colors.grey[500],
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.calendar_today,
                        color: Color(0xFF7DD3FC),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _nextScreen,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7DD3FC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
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