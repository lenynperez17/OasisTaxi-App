import 'package:flutter/material.dart';

class AppColors {
  // Colores principales de Oasis Taxi - Verde corporativo
  static const Color oasisGreen = Color(0xFF00C800); // Verde Oasis oficial
  static const Color oasisBlack = Color(0xFF000000); // Negro
  static const Color oasisWhite = Color(0xFFFFFFFF); // Blanco
  static const Color primary = oasisGreen; // Color primario
  static const Color white = oasisWhite; // Alias para white

  // Alias para compatibilidad
  static const Color oasisGreenDark = Color(0xFF008F00); // Verde oscuro
  static const Color oasisGreenLight = Color(0xFF4CE54C); // Verde claro

  // Nombres para compatibilidad
  static const Color oasisTurquoise = oasisGreen;
  static const Color oasisTurquoiseDark = oasisGreenDark;
  static const Color oasisTurquoiseLight = oasisGreenLight;
  static const Color rappiOrange = oasisGreen;
  static const Color rappiOrangeDark = oasisGreenDark;
  static const Color rappiOrangeLight = oasisGreenLight;

  // Colores base con mejor contraste
  static const Color black = Color(0xFF1A1A1A); // Negro más suave
  static const Color offWhite = Color(0xFFFAFAFA); // Blanco más suave

  // Colores de estado con mejor contraste
  static const Color success = Color(0xFF00A000); // Verde más oscuro
  static const Color error = Color(0xFFDC2626); // Rojo con mejor contraste
  static const Color warning = Color(0xFFF59E0B); // Naranja con mejor contraste
  static const Color info = Color(0xFF3B82F6); // Azul con mejor contraste

  // Grises con mejor contraste
  static const Color grey = Color(0xFF6B7280);
  static const Color greyLight = Color(0xFFE5E7EB);
  static const Color greyMedium = Color(0xFF9CA3AF);
  static const Color greyDark = Color(0xFF374151);
  static const Color greyExtraDark = Color(0xFF1F2937);

  // Colores de fondo con mejor contraste
  static const Color backgroundLight = Color(0xFFF9FAFB);
  static const Color backgroundMedium = Color(0xFFF3F4F6);
  static const Color backgroundDark = Color(0xFF111827);

  // Colores de texto con mejor contraste
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textOnDark = Colors.white;
  static const Color textOnGreen = Colors.white;
}
