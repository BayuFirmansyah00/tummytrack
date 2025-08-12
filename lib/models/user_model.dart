import 'package:flutter/material.dart';

class UserModel with ChangeNotifier {
  String? name;
  String? phone;
  String? email;

  void updateName(String value) {
    name = value;
    notifyListeners();
  }

  void updatePhone(String value) {
    phone = value;
    notifyListeners();
  }

  void updateEmail(String value) {
    email = value;
    notifyListeners();
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
    };
  }
}