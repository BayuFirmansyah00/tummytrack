import 'package:flutter/material.dart';

class BabyModel with ChangeNotifier {
  String? babyId; // Tambah babyId
  String? name;
  DateTime? birthDate;
  String? ageRange;
  String? relationship;
  String? gender;

  void updateBabyId(String value) {
    babyId = value;
    notifyListeners();
  }

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

  void updateGender(String value) {
    gender = value;
    notifyListeners();
  }

  Map<String, dynamic> toJson() {
    return {
      'baby_id': babyId, // Tambah babyId ke JSON
      'name': name,
      'birth_date': birthDate?.toIso8601String(),
      'age_range': ageRange,
      'relationship': relationship,
      'gender': gender,
    };
  }
}