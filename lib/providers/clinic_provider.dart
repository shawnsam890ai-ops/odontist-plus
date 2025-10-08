import 'package:flutter/foundation.dart';
import '../models/clinic.dart';

class ClinicProvider with ChangeNotifier {
  final List<Clinic> _clinics = [];

  List<Clinic> get clinics => List.unmodifiable(_clinics);

  void addClinic(Clinic c) {
    _clinics.add(c);
    notifyListeners();
  }
}
