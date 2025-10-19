import 'package:flutter/foundation.dart';

class HolidaysProvider with ChangeNotifier {
  // store holidays as yyyy-mm-dd strings for simplicity
  final Set<String> _holidays = {};

  bool isHoliday(DateTime d) {
    final key = _key(d);
    return _holidays.contains(key);
  }

  void toggleHoliday(DateTime d) {
    final key = _key(d);
    if (_holidays.contains(key)) {
      _holidays.remove(key);
    } else {
      _holidays.add(key);
    }
    notifyListeners();
  }

  List<DateTime> holidaysForMonth(int year, int month) {
    return _holidays
        .where((k) => k.startsWith('$year-${month.toString().padLeft(2, '0')}'))
        .map((k) {
      final parts = k.split('-');
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    }).toList()
      ..sort();
  }

  void setHolidays(List<DateTime> dates) {
    _holidays.clear();
    for (final d in dates) {
      _holidays.add(_key(d));
    }
    notifyListeners();
  }

  String _key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
