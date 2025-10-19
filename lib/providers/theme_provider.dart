import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_theme.dart';

enum ThemePreset { green, purple, red, custom }

class ThemeProvider extends ChangeNotifier {
  static const _kPresetKey = 'theme.preset';
  static const _kCustomPrimaryKey = 'theme.custom.primary';
  static const _kCustomContainerKey = 'theme.custom.primaryContainer';

  ThemePreset _preset = ThemePreset.purple; // default to purple as requested
  Color _customPrimary = const Color(0xFF28A745);
  Color _customPrimaryContainer = const Color(0xFF28A745);
  bool _loaded = false;

  bool get isLoaded => _loaded;
  ThemePreset get preset => _preset;
  Color get customPrimary => _customPrimary;
  Color get customPrimaryContainer => _customPrimaryContainer;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final presetStr = prefs.getString(_kPresetKey);
    if (presetStr != null) {
      _preset = ThemePreset.values.firstWhere(
        (e) => e.name == presetStr,
        orElse: () => ThemePreset.green,
      );
    }
    final p = prefs.getInt(_kCustomPrimaryKey);
    final pc = prefs.getInt(_kCustomContainerKey);
    if (p != null) _customPrimary = Color(p);
    if (pc != null) _customPrimaryContainer = Color(pc);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setPreset(ThemePreset preset) async {
    _preset = preset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPresetKey, preset.name);
    notifyListeners();
  }

  Future<void> setCustomColors(Color primary, {Color? primaryContainer}) async {
    _customPrimary = primary;
    _customPrimaryContainer = primaryContainer ?? primary.withOpacity(0.85);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCustomPrimaryKey, _customPrimary.value);
    await prefs.setInt(_kCustomContainerKey, _customPrimaryContainer.value);
    if (_preset != ThemePreset.custom) {
      await setPreset(ThemePreset.custom);
    } else {
      notifyListeners();
    }
  }

  ThemeData get lightTheme {
    final colors = _currentColors();
    return AppTheme.lightFrom(primary: colors.$1, primaryContainer: colors.$2);
  }

  ThemeData get darkTheme {
    final colors = _currentColors();
    return AppTheme.darkFrom(primary: colors.$1);
  }

  (Color, Color) _currentColors() {
    switch (_preset) {
      case ThemePreset.green:
        return (const Color(0xFF28A745), const Color(0xFF28A745));
      case ThemePreset.purple:
        // Requested combo: primary icopurple (#8B27E2), light purple container (#D9B6FF)
        return (const Color(0xFF8B27E2), const Color(0xFFD9B6FF));
      case ThemePreset.red:
        return (const Color(0xFFE53935), const Color(0xFFE57373));
      case ThemePreset.custom:
        return (_customPrimary, _customPrimaryContainer);
    }
  }
}
