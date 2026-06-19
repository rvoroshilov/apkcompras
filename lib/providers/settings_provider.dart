import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  int _seedColor = 0xFF2E7D32;
  int _backgroundStyle = 1;
  String _avatarEmoji = '🏠';

  ThemeMode get themeMode => _themeMode;
  int get seedColor => _seedColor;
  int get backgroundStyle => _backgroundStyle;
  String get avatarEmoji => _avatarEmoji;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = switch (prefs.getString('theme_mode')) {
      'light' => ThemeMode.light,
      'dark'  => ThemeMode.dark,
      _       => ThemeMode.system,
    };
    _seedColor = prefs.getInt('seed_color') ?? 0xFF2E7D32;
    _backgroundStyle = prefs.getInt('bg_style') ?? 1;
    _avatarEmoji = prefs.getString('avatar_emoji') ?? '🏠';
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark  => 'dark',
      _               => 'system',
    });
    notifyListeners();
  }

  Future<void> setSeedColor(int color) async {
    _seedColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('seed_color', color);
    notifyListeners();
  }

  Future<void> setBackgroundStyle(int style) async {
    _backgroundStyle = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bg_style', style);
    notifyListeners();
  }

  Future<void> setAvatarEmoji(String emoji) async {
    _avatarEmoji = emoji;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('avatar_emoji', emoji);
    notifyListeners();
  }
}
