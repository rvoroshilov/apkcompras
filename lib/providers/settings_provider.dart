import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  int _seedColor = 0xFF2E7D32;
  int _backgroundStyle = 1;
  String _avatarEmoji = '🏠';
  String _backgroundImage = '';

  ThemeMode get themeMode => _themeMode;
  int get seedColor => _seedColor;
  int get backgroundStyle => _backgroundStyle;
  String get avatarEmoji => _avatarEmoji;
  String get backgroundImage => _backgroundImage;
  bool get hasBackgroundImage => _backgroundImage.isNotEmpty;

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
    _backgroundImage = prefs.getString('bg_image') ?? '';
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

  /// [filename] es el nombre devuelto por BackupHelper.saveImage, o ''
  /// para quitar el fondo personalizado.
  Future<void> setBackgroundImage(String filename) async {
    _backgroundImage = filename;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bg_image', filename);
    notifyListeners();
  }
}
