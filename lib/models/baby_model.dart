import 'package:flutter/material.dart';

class BabyModel with ChangeNotifier {
  String? name;
  DateTime? birthDate;
  String? ageRange;
  String? relationship;
  String? gender; // Tambahkan properti gender

  void updateName(String value) {
    name = value;
    notifyListeners();
  }

  void updateBirthDate(DateTime value) {
    birthDate = value;
    notifyListeners();
  }

  void updateAgeRange(String value) {
    ageRange = value;
    notifyListeners();
  }

  void updateRelationship(String value) {
    relationship = value;
    notifyListeners();
  }

  void updateGender(String value) { // Tambahkan metode updateGender
    gender = value;
    notifyListeners();
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'birth_date': birthDate?.toIso8601String(),
      'age_range': ageRange,
      'relationship': relationship,
      'gender': gender, // Tambahkan gender ke JSON
    };
  }
}