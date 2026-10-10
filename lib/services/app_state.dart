import 'package:flutter/foundation.dart';
import '../models/medicine.dart';

class AppState extends ChangeNotifier {
  String _language = 'en'; // 'en' | 'ur'
  Medicine? _currentMedicine;
  bool _isLoading = false;
  String? _errorMessage;

  String get language => _language;
  Medicine? get currentMedicine => _currentMedicine;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setLanguage(String lang) {
    _language = lang;
    notifyListeners();
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setMedicine(Medicine? medicine) {
    _currentMedicine = medicine;
    _errorMessage = null;
    notifyListeners();
  }

  void setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }
}
