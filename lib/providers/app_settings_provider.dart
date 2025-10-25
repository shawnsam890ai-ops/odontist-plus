import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsProvider extends ChangeNotifier {
  static const _kCountryCodeKey = 'default_country_code';

  String _defaultCountryCode = '91';
  bool _loaded = false;

  String get defaultCountryCode => _defaultCountryCode;
  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _defaultCountryCode = prefs.getString(_kCountryCodeKey) ?? '91';
    } catch (_) {
      _defaultCountryCode = '91';
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setDefaultCountryCode(String code) async {
    // sanitize to digits only, 1-3 digits typical
    final clean = code.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return;
    _defaultCountryCode = clean;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCountryCodeKey, _defaultCountryCode);
    } catch (_) {
      // ignore persistence failure
    }
    notifyListeners();
  }
}
