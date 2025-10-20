import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_theme.dart';
import 'dart:typed_data';
import 'dart:io' show File;
import 'package:image/image.dart' as img;

enum ThemePreset { green, purple, red, custom }

class ThemeProvider extends ChangeNotifier {
  // Default and allowed background assets (renamed to BG1..BG4)
  static const String defaultBackgroundAsset = 'assets/images/BG1.jpg';
  static const List<String> allowedBackgroundAssets = <String>[
    'assets/images/BG1.jpg',
    'assets/images/BG2.jpg',
    'assets/images/BG3.jpg',
    'assets/images/BG4.jpg',
  ];
  // Map legacy asset names to new BG names to migrate persisted values seamlessly
  static const Map<String, String> _legacyToNew = <String, String>{
    'assets/images/abstract-textured.jpg': 'assets/images/BG1.jpg',
    'assets/images/solid-gypsum.jpg': 'assets/images/BG2.jpg',
    'assets/images/smooth-blue.jpg': 'assets/images/BG3.jpg',
    'assets/images/soft-vintage.jpg': 'assets/images/BG4.jpg',
  };
  static const _kPresetKey = 'theme.preset';
  static const _kCustomPrimaryKey = 'theme.custom.primary';
  static const _kCustomContainerKey = 'theme.custom.primaryContainer';
  static const _kBackgroundImagePathKey = 'theme.background.imagePath';
  static const _kForceWhiteTextKey = 'theme.forceWhiteText';
  static const _kBackgroundDimKey = 'theme.background.dim';
  static const _kAutoContrastKey = 'theme.background.autoContrast';
  static const _kRxHeaderPathKey = 'print.rx.header.path';
  static const _kRxFooterPathKey = 'print.rx.footer.path';

  ThemePreset _preset = ThemePreset.purple; // default to purple as requested
  Color _customPrimary = const Color(0xFF28A745);
  Color _customPrimaryContainer = const Color(0xFF28A745);
  bool _loaded = false;
  String? _backgroundImagePath; // null => use default gradient
  bool _forceWhiteText = false;
  double _backgroundDim = 0.22; // 0.0 - 0.6 recommended
  bool _autoContrast = false;
  String? _rxHeaderPath; // 'asset:...' or absolute file path
  String? _rxFooterPath; // 'asset:...' or absolute file path

  bool get isLoaded => _loaded;
  ThemePreset get preset => _preset;
  Color get customPrimary => _customPrimary;
  Color get customPrimaryContainer => _customPrimaryContainer;
  String? get backgroundImagePath => _backgroundImagePath;
  bool get hasBackgroundImage => _backgroundImagePath != null && _backgroundImagePath!.isNotEmpty;
  bool get isDefaultBackground => _backgroundImagePath == 'asset:$defaultBackgroundAsset';
  bool get forceWhiteText => _forceWhiteText;
  double get backgroundDim => _backgroundDim;
  bool get autoContrast => _autoContrast;
  String? get rxHeaderPath => _rxHeaderPath;
  String? get rxFooterPath => _rxFooterPath;
  bool get hasRxHeader => _rxHeaderPath != null && _rxHeaderPath!.isNotEmpty;
  bool get hasRxFooter => _rxFooterPath != null && _rxFooterPath!.isNotEmpty;

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
  _backgroundImagePath = prefs.getString(_kBackgroundImagePathKey);
    // Enforce default and allowed asset list; migrate old values if needed
    String? newPath;
    if (_backgroundImagePath == null || _backgroundImagePath!.isEmpty) {
      newPath = 'asset:$defaultBackgroundAsset';
    } else if (!_backgroundImagePath!.startsWith('asset:')) {
      // Any file path is disallowed now
      newPath = 'asset:$defaultBackgroundAsset';
    } else {
      final currentAsset = _backgroundImagePath!.substring('asset:'.length);
      // Migrate legacy to new
      final migrated = _legacyToNew[currentAsset];
      final effective = migrated ?? currentAsset;
      if (!allowedBackgroundAssets.contains(effective)) {
        newPath = 'asset:$defaultBackgroundAsset';
      } else {
        newPath = 'asset:$effective';
      }
    }
    if (newPath != _backgroundImagePath) {
      _backgroundImagePath = newPath;
      await prefs.setString(_kBackgroundImagePathKey, _backgroundImagePath!);
    }
  _forceWhiteText = prefs.getBool(_kForceWhiteTextKey) ?? false;
  _backgroundDim = prefs.getDouble(_kBackgroundDimKey) ?? _backgroundDim;
  _autoContrast = prefs.getBool(_kAutoContrastKey) ?? false;
    _rxHeaderPath = prefs.getString(_kRxHeaderPathKey);
    _rxFooterPath = prefs.getString(_kRxFooterPathKey);
    _loaded = true;
    notifyListeners();
    // Optionally analyze on startup if enabled
    if (_autoContrast && _backgroundImagePath != null && _backgroundImagePath!.isNotEmpty) {
      // Fire and forget
      // ignore: unawaited_futures
      analyzeBackgroundAndAdjust();
    }
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
    final base = AppTheme.lightFrom(primary: colors.$1, primaryContainer: colors.$2);
    return _forceWhiteText ? _applyForceWhiteText(base) : base;
  }

  ThemeData get darkTheme {
    final colors = _currentColors();
    final base = AppTheme.darkFrom(primary: colors.$1);
    return _forceWhiteText ? _applyForceWhiteText(base) : base;
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

  Future<void> setBackgroundImagePath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    // Null resets to default
    final candidate = (path == null || path.isEmpty) ? 'asset:$defaultBackgroundAsset' : path;
    // Only allow assets from the whitelist (also migrate legacy names)
    String effective;
    if (!candidate.startsWith('asset:')) {
      effective = 'asset:$defaultBackgroundAsset';
    } else {
      final asset = candidate.substring('asset:'.length);
      final migrated = _legacyToNew[asset];
      final effAsset = migrated ?? asset;
      effective = allowedBackgroundAssets.contains(effAsset)
          ? 'asset:$effAsset'
          : 'asset:$defaultBackgroundAsset';
    }
    _backgroundImagePath = effective;
    await prefs.setString(_kBackgroundImagePathKey, _backgroundImagePath!);
    notifyListeners();
    if (_autoContrast) {
      // ignore: unawaited_futures
      analyzeBackgroundAndAdjust();
    }
  }

  Future<void> setBackgroundImageAsset(String assetPath) async {
    // Store with asset: prefix to distinguish from file paths
    if (!allowedBackgroundAssets.contains(assetPath)) {
      await setBackgroundImagePath(null); // fallback to default
    } else {
      await setBackgroundImagePath(assetPath.isEmpty ? null : 'asset:$assetPath');
    }
  }

  // Rx header/footer image settings
  Future<void> setRxHeaderImagePath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    _rxHeaderPath = (path == null || path.isEmpty) ? null : path;
    if (_rxHeaderPath == null) {
      await prefs.remove(_kRxHeaderPathKey);
    } else {
      await prefs.setString(_kRxHeaderPathKey, _rxHeaderPath!);
    }
    notifyListeners();
  }

  Future<void> setRxFooterImagePath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    _rxFooterPath = (path == null || path.isEmpty) ? null : path;
    if (_rxFooterPath == null) {
      await prefs.remove(_kRxFooterPathKey);
    } else {
      await prefs.setString(_kRxFooterPathKey, _rxFooterPath!);
    }
    notifyListeners();
  }

  Future<void> setRxHeaderImageAsset(String assetPath) async =>
      setRxHeaderImagePath(assetPath.isEmpty ? null : 'asset:$assetPath');
  Future<void> setRxFooterImageAsset(String assetPath) async =>
      setRxFooterImagePath(assetPath.isEmpty ? null : 'asset:$assetPath');

  Future<void> setForceWhiteText(bool value) async {
    _forceWhiteText = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kForceWhiteTextKey, _forceWhiteText);
    notifyListeners();
  }

  ThemeData _applyForceWhiteText(ThemeData theme) {
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        foregroundColor: Colors.white,
        titleTextStyle: (theme.appBarTheme.titleTextStyle ?? const TextStyle()).copyWith(color: Colors.white),
      ),
    );
  }

  Future<void> setBackgroundDim(double value) async {
    // Clamp to a safe range
    final v = value.clamp(0.0, 0.8);
    _backgroundDim = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kBackgroundDimKey, _backgroundDim);
    notifyListeners();
  }

  Future<void> setAutoContrast(bool value) async {
    _autoContrast = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoContrastKey, _autoContrast);
    notifyListeners();
    if (_autoContrast) {
      await analyzeBackgroundAndAdjust();
    }
  }

  Future<void> analyzeBackgroundAndAdjust() async {
    final path = _backgroundImagePath;
    if (path == null || path.isEmpty) return;
    try {
      Uint8List bytes;
      if (path.startsWith('asset:')) {
        final asset = path.substring('asset:'.length);
        final bd = await rootBundle.load(asset);
        bytes = bd.buffer.asUint8List();
      } else {
        bytes = await File(path).readAsBytes();
      }
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return;
      // Downscale for speed
      final resized = img.copyResize(decoded, width: 64);
      final pixels = resized.getBytes();
      // image package returns bytes as RGBA
      int count = 0;
      double sum = 0;
      for (int i = 0; i < pixels.length; i += 4) {
        final r = pixels[i];
        final g = pixels[i + 1];
        final b = pixels[i + 2];
        // Rec. 709 luma
        final lum = 0.2126 * r + 0.7152 * g + 0.0722 * b; // 0..255
        sum += lum;
        count++;
      }
      if (count == 0) return;
      final avg = sum / count; // 0..255

      // Heuristics: darker background -> white appbar text, lower dim; bright background -> darker appbar text, higher dim
      bool whiteAppBar;
      double dim;
      if (avg <= 90) {
        whiteAppBar = true;
        dim = 0.12;
      } else if (avg <= 150) {
        whiteAppBar = true;
        dim = 0.20;
      } else {
        whiteAppBar = false;
        dim = 0.30;
      }

      // Update settings in a single notify cycle
      final prefs = await SharedPreferences.getInstance();
      _forceWhiteText = whiteAppBar;
      _backgroundDim = dim;
      await prefs.setBool(_kForceWhiteTextKey, _forceWhiteText);
      await prefs.setDouble(_kBackgroundDimKey, _backgroundDim);
      notifyListeners();
    } catch (_) {
      // Ignore failures; keep current settings
    }
  }
}
