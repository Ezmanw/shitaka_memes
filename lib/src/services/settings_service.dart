import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService instance = SettingsService._();
  SettingsService._();

  static const String _keySeedColor = 'seed_color';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyOutputDir = 'output_dir';

  Color _seedColor = const Color(0xFF8BC34A); // Cyber Lime default
  ThemeMode _themeMode = ThemeMode.dark;
  String? _customOutputDir;

  Color get seedColor => _seedColor;
  ThemeMode get themeMode => _themeMode;
  String? get customOutputDir => _customOutputDir;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final colorVal = prefs.getInt(_keySeedColor);
      if (colorVal != null) {
        _seedColor = Color(colorVal);
      }
      final modeIndex = prefs.getInt(_keyThemeMode);
      if (modeIndex != null && modeIndex < ThemeMode.values.length) {
        _themeMode = ThemeMode.values[modeIndex];
      }
      _customOutputDir = prefs.getString(_keyOutputDir);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keySeedColor, color.toARGB32());
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyThemeMode, mode.index);
    } catch (_) {}
  }

  Future<void> setCustomOutputDir(String? path) async {
    _customOutputDir = (path != null && path.trim().isNotEmpty) ? path.trim() : null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_customOutputDir == null) {
        await prefs.remove(_keyOutputDir);
      } else {
        await prefs.setString(_keyOutputDir, _customOutputDir!);
      }
    } catch (_) {}
  }
}
