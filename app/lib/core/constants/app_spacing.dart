import 'package:flutter/material.dart';

/// Sistema de espaciado unificado basado en grid de 8 puntos
/// Proporciona constantes consistentes para espaciado, padding y dimensiones
class AppSpacing {
  AppSpacing._();

  // === ESPACIADO BASE (8-point grid) ===
  static const double _baseUnit = 8.0;

  // Espaciado micro (1-2 unidades)
  static const double xs = _baseUnit * 0.5; // 4px
  static const double sm = _baseUnit; // 8px

  // Espaciado estándar (2-4 unidades)
  static const double md = _baseUnit * 2; // 16px
  static const double lg = _baseUnit * 3; // 24px
  static const double xl = _baseUnit * 4; // 32px

  // Espaciado grande (5-8 unidades)
  static const double xxl = _baseUnit * 6; // 48px
  static const double xxxl = _baseUnit * 8; // 64px
  static const double mega = _baseUnit * 10; // 80px

  // === PADDING ESPECÍFICO ===

  // Padding de contenedores
  static const double containerPadding = md; // 16px
  static const double containerPaddingLarge = lg; // 24px
  static const double sectionPadding = xl; // 32px
  static const double screenPadding = lg; // 24px

  // Padding de formularios
  static const double formPadding = md; // 16px
  static const double fieldSpacing = md; // 16px
  static const double buttonSpacing = lg; // 24px
  static const double buttonPadding = md; // 16px

  // Padding de cards
  static const double cardPadding = md; // 16px
  static const double cardPaddingLarge = lg; // 24px
  static const double cardMargin = sm; // 8px
  static const double cardSpacing = md; // 16px

  // Espaciado entre elementos
  static const double elementSpacing = sm; // 8px
  static const double sectionSpacing = lg; // 24px
  static const double sectionMargin = xl; // 32px - Comment 3: Added missing constant
  static const double groupSpacing = md; // 16px

  // === DIMENSIONES DE COMPONENTES ===

  // AppBar y NavigationBar
  static const double appBarHeight = 56.0;
  static const double appBarHeightLarge = 64.0;
  static const double navigationBarHeight = 60.0;

  // Botones
  static const double buttonHeight = 48.0;
  static const double buttonHeightSmall = 36.0;
  static const double buttonHeightLarge = 56.0;
  static const double buttonMinWidth = 120.0;
  static const double minButtonWidth = 120.0;

  // Campos de texto
  static const double textFieldHeight = 48.0;
  static const double textFieldHeightLarge = 56.0;
  static const double textFieldBorderRadius = 12.0;
  static const double inputHeight = 56.0;

  // Lista y elementos
  static const double listItemHeight = 72.0;
  static const double maxContentWidth = 600.0;

  // Iconos
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
  static const double iconSizeXLarge = 48.0;
  static const double iconSizeSm = 16.0;
  static const double iconSizeMd = 24.0;
  static const double iconSizeLg = 32.0;
  static const double iconSizeXl = 48.0;

  // Touch targets (mínimo recomendado por Material Design)
  static const double minTouchTarget = 48.0;

  // === ELEVACIONES ===
  static const double elevationNone = 0.0;
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;
  static const double elevationMax = 16.0;

  // === BORDER RADIUS ===
  static const double radiusXS = 4.0;
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusXXL = 32.0;
  static const double radiusCircle = 100.0;

  // Aliases para compatibilidad
  static const double radiusXs = radiusXS;
  static const double radiusSm = radiusSM;
  static const double radiusMd = radiusMD;
  static const double radiusLg = radiusLG;
  static const double radiusXl = radiusXL;
  static const double radiusRound = radiusCircle;

  // === ELEVACIONES ===
  static const double elevationNone = 0.0;
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;
  static const double elevationVeryHigh = 16.0;

  // === MÉTODOS HELPER ===

  /// Convierte unidades base a píxeles
  static double units(double multiplier) => _baseUnit * multiplier;

  /// EdgeInsets uniformes
  static EdgeInsets all(double value) => EdgeInsets.all(value);

  /// EdgeInsets simétricos
  static EdgeInsets symmetric({
    double horizontal = 0.0,
    double vertical = 0.0,
  }) =>
      EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);

  /// EdgeInsets solo horizontal
  static EdgeInsets horizontal(double value) =>
      EdgeInsets.symmetric(horizontal: value);

  /// EdgeInsets solo vertical
  static EdgeInsets vertical(double value) =>
      EdgeInsets.symmetric(vertical: value);

  /// EdgeInsets personalizados usando el sistema de unidades
  static EdgeInsets only({
    double left = 0.0,
    double top = 0.0,
    double right = 0.0,
    double bottom = 0.0,
  }) =>
      EdgeInsets.only(
        left: left,
        top: top,
        right: right,
        bottom: bottom,
      );

  /// SizedBox con altura específica
  static Widget verticalSpace(double height) => SizedBox(height: height);

  /// SizedBox con ancho específico
  static Widget horizontalSpace(double width) => SizedBox(width: width);

  /// SizedBox con espaciado vertical usando unidades base
  static Widget verticalSpaceUnits(double units) =>
      SizedBox(height: _baseUnit * units);

  /// SizedBox con espaciado horizontal usando unidades base
  static Widget horizontalSpaceUnits(double units) =>
      SizedBox(width: _baseUnit * units);

  // === ESPACIADORES PREDEFINIDOS ===

  /// Espaciadores verticales comunes
  static Widget get verticalSpaceXS => verticalSpace(xs);
  static Widget get verticalSpaceSM => verticalSpace(sm);
  static Widget get verticalSpaceMD => verticalSpace(md);
  static Widget get verticalSpaceLG => verticalSpace(lg);
  static Widget get verticalSpaceXL => verticalSpace(xl);
  static Widget get verticalSpaceXXL => verticalSpace(xxl);

  /// Espaciadores horizontales comunes
  static Widget get horizontalSpaceXS => horizontalSpace(xs);
  static Widget get horizontalSpaceSM => horizontalSpace(sm);
  static Widget get horizontalSpaceMD => horizontalSpace(md);
  static Widget get horizontalSpaceLG => horizontalSpace(lg);
  static Widget get horizontalSpaceXL => horizontalSpace(xl);
  static Widget get horizontalSpaceXXL => horizontalSpace(xxl);

  // === PADDING PREDEFINIDOS ===

  /// Padding de contenedores comunes
  static EdgeInsets get containerPaddingAll => all(containerPadding);
  static EdgeInsets get containerPaddingHorizontal =>
      horizontal(containerPadding);
  static EdgeInsets get containerPaddingVertical => vertical(containerPadding);

  /// Padding de formularios
  static EdgeInsets get formPaddingAll => all(formPadding);
  static EdgeInsets get formPaddingHorizontal => horizontal(formPadding);

  /// Padding de cards
  static EdgeInsets get cardPaddingAll => all(cardPadding);
  static EdgeInsets get cardPaddingLargeAll => all(cardPaddingLarge);
  static EdgeInsets get cardMarginAll => all(cardMargin);

  // === BORDER RADIUS PREDEFINIDOS ===

  /// BorderRadius comunes
  static BorderRadius get borderRadiusXS => BorderRadius.circular(radiusXS);
  static BorderRadius get borderRadiusSM => BorderRadius.circular(radiusSM);
  static BorderRadius get borderRadiusMD => BorderRadius.circular(radiusMD);
  static BorderRadius get borderRadiusLG => BorderRadius.circular(radiusLG);
  static BorderRadius get borderRadiusXL => BorderRadius.circular(radiusXL);
  static BorderRadius get borderRadiusXXL => BorderRadius.circular(radiusXXL);
  static BorderRadius get borderRadiusCircle =>
      BorderRadius.circular(radiusCircle);

  // === DURATIONS PARA ANIMACIONES ===
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
}