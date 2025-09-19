import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ModernTheme {
  // Colores corporativos de Oasis Taxi
  static const Color oasisGreen = Color(0xFF00C800);
  static const Color oasisBlack =
      Color(0xFF2C2C2C); // Cambiado de negro puro a gris oscuro
  static const Color oasisWhite = Color(0xFFFFFFFF);
  static const Color accentGray =
      Color(0xFF6B6B6B); // Gris más claro para mejor contraste
  static const Color lightGray = Color(0xFFF8F8F8);

  // Aliases para compatibilidad con el código existing
  static const Color primaryColor =
      oasisGreen; // Color principal para compatibilidad
  static const Color primaryOrange = oasisGreen;
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color darkBlue = Color(0xFF1976D2);
  static const Color accent = accentGray; // Alias para compatibilidad
  static const Color accentYellow = Color(0xFFFFC107);
  static const Color cardDark = Color(0xFF1A1D35);

  // Colores de fondo
  static const Color background = Color(0xFFF8F9FD);
  static const Color backgroundLight = Color(0xFFF8F9FD);
  static const Color backgroundDark = Color(0xFF1E2937);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color cardBackgroundDark = Color(0xFF2D3748);

  // Colores de texto
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textLight = Color(0xFFFFFFFF);

  // Colores de estado
  static const Color success = Color(0xFF00C896);
  static const Color warning = Color(0xFFFFB547);
  static const Color error = Color(0xFFFF4757);
  static const Color info = Color(0xFF00B8D4);

  // Getter para borderColor
  static Color get borderColor => Color(0xFFE0E0E0);

  // Gradientes modernos con colores corporativos
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [oasisGreen, Color(0xFF00A000)],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF4A5568), Color(0xFF2D3748)],
  );

  static const LinearGradient lightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [oasisWhite, lightGray],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [oasisGreen, Color(0xFF00E000)],
  );

  // Sombras modernas
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: Offset(0, 10),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: oasisGreen.withValues(alpha: 0.3),
      blurRadius: 15,
      offset: Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> floatingShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 30,
      offset: Offset(0, 15),
      spreadRadius: 0,
    ),
  ];

  // Temas
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: oasisGreen,
    scaffoldBackgroundColor: backgroundLight,
    colorScheme: ColorScheme.light(
      primary: oasisGreen,
      secondary: oasisBlack,
      surface: cardBackground,
      error: error,
    ),
    fontFamily: 'SF Pro Display',
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: textPrimary),
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: oasisGreen,
        foregroundColor: oasisWhite,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: cardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: oasisGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: error, width: 1),
      ),
      hintStyle: TextStyle(
        color: textSecondary,
        fontSize: 14,
      ),
      labelStyle: TextStyle(
        color: textSecondary,
        fontSize: 14,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: cardBackground,
      selectedItemColor: oasisGreen,
      unselectedItemColor: textSecondary,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    dividerTheme: DividerThemeData(
      color: Colors.grey.shade200,
      thickness: 1,
      space: 1,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: oasisGreen,
    scaffoldBackgroundColor: backgroundDark,
    colorScheme: ColorScheme.dark(
      primary: oasisGreen,
      secondary: oasisBlack,
      surface: cardBackgroundDark,
      error: error,
    ),
    fontFamily: 'SF Pro Display',
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: textLight),
      titleTextStyle: TextStyle(
        color: textLight,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: oasisGreen,
        foregroundColor: oasisWhite,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: cardBackgroundDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: cardBackgroundDark,
      selectedItemColor: oasisGreen,
      unselectedItemColor: textSecondary,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );

  // === CONSTANTES RESPONSIVE ===

  // Breakpoints para diseño responsivo
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;
  static const double desktopBreakpoint = 1440;

  // Constantes de padding responsivo
  static const double paddingSmall = 16.0;
  static const double paddingLarge = 24.0;

  // Constantes de spacing responsivo
  static const double spacingSmall = 16.0;
  static const double spacingLarge = 24.0;

  // Factores de escala de fuente
  static const double fontScaleMobile = 0.9;
  static const double fontScaleTablet = 1.0;
  static const double fontScaleDesktop = 1.1;

  // Métodos helper para diseño responsivo
  static double getResponsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth < mobileBreakpoint ? paddingSmall : paddingLarge;
  }

  static double getResponsiveSpacing(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth < mobileBreakpoint ? spacingSmall : spacingLarge;
  }

  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < mobileBreakpoint) {
      return baseSize * fontScaleMobile;
    } else if (screenWidth < tabletBreakpoint) {
      return baseSize * fontScaleTablet;
    } else {
      return baseSize * fontScaleDesktop;
    }
  }

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  static bool isCompactScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// Obtiene tamaño de icono responsivo
  static double getResponsiveIconSize(BuildContext context, {
    double smallSize = 20.0,
    double mediumSize = 24.0,
    double largeSize = 28.0,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < mobileBreakpoint) {
      return smallSize;
    } else if (screenWidth < tabletBreakpoint) {
      return mediumSize;
    } else {
      return largeSize;
    }
  }

  /// Obtiene elevación adaptativa basada en el tamaño de pantalla
  static double getAdaptiveElevation(BuildContext context, {
    double mobileElevation = 2.0,
    double tabletElevation = 4.0,
    double desktopElevation = 8.0,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < mobileBreakpoint) {
      return mobileElevation;
    } else if (screenWidth < tabletBreakpoint) {
      return tabletElevation;
    } else {
      return desktopElevation;
    }
  }

  /// Sombras responsivas para cards
  static List<BoxShadow> getCardShadows(BuildContext context) {
    final elevation = getAdaptiveElevation(context);
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: elevation * 2.5,
        offset: Offset(0, elevation),
        spreadRadius: 0,
      ),
    ];
  }

  /// Retorna SystemUiOverlayStyle apropiado basado en brightness del fondo
  static SystemUiOverlayStyle getSystemOverlayStyle({
    required bool isLightBackground,
  }) {
    return isLightBackground
        ? SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            statusBarBrightness: Brightness.light,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.dark,
          )
        : SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            statusBarBrightness: Brightness.dark,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
          );
  }
}
