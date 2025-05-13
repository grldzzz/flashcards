import 'package:flutter/material.dart';

class AppTheme {
  // Colores principales
  static const Color primaryColor = Color(0xFF2C3E50);      // Azul oscuro
  static const Color secondaryColor = Color(0xFF3498DB);    // Azul claro
  static const Color accentColor = Color(0xFF1ABC9C);       // Verde azulado
  
  // Colores de fondo - Tema claro
  static const Color backgroundColorLight = Color(0xFFF5F7FA);   // Gris muy claro
  static const Color cardColorLight = Colors.white;
  
  // Colores de fondo - Tema oscuro
  static const Color backgroundColorDark = Color(0xFF121212);    // Casi negro
  static const Color cardColorDark = Color(0xFF1E1E1E);          // Gris muy oscuro
  
  // Colores de texto - Tema claro
  static const Color textPrimaryLight = Color(0xFF2C3E50);       // Azul oscuro
  static const Color textSecondaryLight = Color(0xFF7F8C8D);     // Gris
  
  // Colores de texto - Tema oscuro
  static const Color textPrimaryDark = Color(0xFFECF0F1);        // Blanco grisáceo
  static const Color textSecondaryDark = Color(0xFFBDC3C7);      // Gris claro
  static const Color textLight = Colors.white;
  
  // Colores de estado
  static const Color errorColor = Color(0xFFE74C3C);        // Rojo
  static const Color successColor = Color(0xFF27AE60);      // Verde
  static const Color warningColor = Color(0xFFF39C12);      // Naranja
  
  // Elevaciones
  static const double cardElevation = 2.0;
  static const double buttonElevation = 1.0;
  
  // Bordes redondeados
  static const double borderRadius = 12.0;
  static const double buttonRadius = 8.0;
  
  // Espaciado
  static const double spacing = 16.0;
  static const double spacingSmall = 8.0;
  
  // Colores para usar directamente (son constantes)
  static const Color backgroundColor = backgroundColorLight;
  static const Color cardColor = cardColorLight;
  static const Color textPrimary = textPrimaryLight;
  static const Color textSecondary = textSecondaryLight;
  
  // Métodos para obtener colores según el tema actual
  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? backgroundColorDark : backgroundColorLight;
  }
  static Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? cardColorDark : cardColorLight;
  }
  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? textPrimaryDark : textPrimaryLight;
  }
  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? textSecondaryDark : textSecondaryLight;
  }
  
  // Control del modo oscuro (se establece desde ThemeProvider)
  static bool isDarkMode = false;
  
  // Tema claro
  static ThemeData lightTheme() {
    isDarkMode = false;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        error: errorColor,
        background: backgroundColorLight,
        surface: cardColorLight,
        onPrimary: textLight,
        onSecondary: textLight,
        onBackground: textPrimaryLight,
        onSurface: textPrimaryLight,
      ),
      
      // Configuración general
      scaffoldBackgroundColor: backgroundColorLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: textLight,
        centerTitle: true,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(borderRadius)),
        ),
      ),
      
      // Tarjetas
      cardTheme: CardTheme(
        color: cardColorLight,
        elevation: cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        margin: const EdgeInsets.symmetric(
          vertical: spacingSmall,
          horizontal: spacing,
        ),
      ),
      
      // Botones
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: textLight,
          elevation: buttonElevation,
          padding: const EdgeInsets.symmetric(
            horizontal: spacing,
            vertical: spacingSmall + 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor),
          padding: const EdgeInsets.symmetric(
            horizontal: spacing,
            vertical: spacingSmall + 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(
            horizontal: spacing,
            vertical: spacingSmall,
          ),
        ),
      ),
      
      // Campos de texto
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: textSecondaryLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide(color: textSecondaryLight.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: secondaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacing,
          vertical: spacingSmall + 4,
        ),
      ),
      
      // Sliders
      sliderTheme: SliderThemeData(
        activeTrackColor: secondaryColor,
        inactiveTrackColor: secondaryColor.withOpacity(0.3),
        thumbColor: accentColor,
        overlayColor: accentColor.withOpacity(0.2),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
      ),
      
      // Diálogos
      dialogTheme: DialogTheme(
        backgroundColor: cardColorLight,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      
      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: textLight,
        elevation: 4,
        shape: CircleBorder(),
      ),
      
      // Iconos
      iconTheme: const IconThemeData(
        color: primaryColor,
        size: 24,
      ),
      
      // Textos
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textPrimaryLight, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: textPrimaryLight, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: textPrimaryLight, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: textPrimaryLight, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: textPrimaryLight, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(color: textPrimaryLight, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: textPrimaryLight, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textPrimaryLight, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: textPrimaryLight, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: textPrimaryLight),
        bodyMedium: TextStyle(color: textPrimaryLight),
        bodySmall: TextStyle(color: textSecondaryLight),
        labelLarge: TextStyle(color: textPrimaryLight, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: textPrimaryLight),
        labelSmall: TextStyle(color: textSecondaryLight),
      ),
    );
  }
  
  // Tema oscuro
  static ThemeData darkTheme() {
    isDarkMode = true;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: secondaryColor,         // Usamos el azul claro como primario en modo oscuro
        secondary: accentColor,
        tertiary: primaryColor,
        error: errorColor,
        background: backgroundColorDark,
        surface: cardColorDark,
        onPrimary: textLight,
        onSecondary: textLight,
        onBackground: textPrimaryDark,
        onSurface: textPrimaryDark,
      ),
      
      // Configuración general
      scaffoldBackgroundColor: backgroundColorDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1A2E),  // Azul muy oscuro
        foregroundColor: textLight,
        centerTitle: true,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(borderRadius)),
        ),
      ),
      
      // Tarjetas
      cardTheme: CardTheme(
        color: cardColorDark,
        elevation: cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        margin: const EdgeInsets.symmetric(
          vertical: spacingSmall,
          horizontal: spacing,
        ),
      ),
      
      // Botones
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: secondaryColor,
          foregroundColor: textLight,
          elevation: buttonElevation,
          padding: const EdgeInsets.symmetric(
            horizontal: spacing,
            vertical: spacingSmall + 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: secondaryColor,
          side: const BorderSide(color: secondaryColor),
          padding: const EdgeInsets.symmetric(
            horizontal: spacing,
            vertical: spacingSmall + 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: secondaryColor,
          padding: const EdgeInsets.symmetric(
            horizontal: spacing,
            vertical: spacingSmall,
          ),
        ),
      ),
      
      // Campos de texto
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2A2A),  // Un poco más claro que el fondo
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: secondaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacing,
          vertical: spacingSmall + 4,
        ),
        labelStyle: const TextStyle(color: textSecondaryDark),
        hintStyle: TextStyle(color: textSecondaryDark.withOpacity(0.7)),
      ),
      
      // Sliders
      sliderTheme: SliderThemeData(
        activeTrackColor: accentColor,
        inactiveTrackColor: accentColor.withOpacity(0.3),
        thumbColor: secondaryColor,
        overlayColor: secondaryColor.withOpacity(0.2),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
      ),
      
      // Diálogos
      dialogTheme: DialogTheme(
        backgroundColor: cardColorDark,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      
      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: textLight,
        elevation: 4,
        shape: CircleBorder(),
      ),
      
      // Iconos
      iconTheme: const IconThemeData(
        color: secondaryColor,
        size: 24,
      ),
      
      // Textos
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textPrimaryDark, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: textPrimaryDark, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: textPrimaryDark, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: textPrimaryDark, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: textPrimaryDark, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(color: textPrimaryDark, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: textPrimaryDark, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textPrimaryDark, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: textPrimaryDark, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: textPrimaryDark),
        bodyMedium: TextStyle(color: textPrimaryDark),
        bodySmall: TextStyle(color: textSecondaryDark),
        labelLarge: TextStyle(color: textPrimaryDark, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: textPrimaryDark),
        labelSmall: TextStyle(color: textSecondaryDark),
      ),
    );
  }
  
  // Retorna el tema adecuado según el modo actual
  static ThemeData getTheme(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return lightTheme();
      case ThemeMode.dark:
        return darkTheme();
      case ThemeMode.system:
      default:
        // En este caso, la plataforma decidirá qué tema usar
        // Pero necesitamos actualizar nuestra variable isDarkMode
        final window = WidgetsBinding.instance.window;
        isDarkMode = window.platformBrightness == Brightness.dark;
        return isDarkMode ? darkTheme() : lightTheme();
    }
  }
}
