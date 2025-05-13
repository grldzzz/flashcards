import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Proveedor para manejar el tema de la aplicación (oscuro/claro)
class ThemeProvider extends ChangeNotifier {
  static const _boxName = 'app_settings';
  static const _themeKey = 'theme_mode';
  
  Box get _box => Hive.box(_boxName);
  
  ThemeProvider() {
    // Inicializamos con el tema del sistema por defecto
    if (!_box.containsKey(_themeKey)) {
      _box.put(_themeKey, ThemeMode.system.index);
    }
  }
  
  /// Inicializa la box de configuración si es necesario
  static Future<void> initialize() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }
  
  /// Obtiene el modo de tema actual
  ThemeMode get themeMode {
    final value = _box.get(_themeKey, defaultValue: ThemeMode.system.index);
    return ThemeMode.values[value];
  }
  
  /// Cambia el modo de tema
  Future<void> setThemeMode(ThemeMode mode) async {
    await _box.put(_themeKey, mode.index);
    notifyListeners();
  }
  
  /// Alterna entre los modos claro y oscuro
  Future<void> toggleTheme() async {
    final currentMode = themeMode;
    if (currentMode == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }
}
