import 'package:flutter/material.dart';
import '../../core/theme/modern_theme.dart';
import '../../services/security_integration_service.dart';

/// Componentes reutilizables para pantallas de autenticación
/// Mantiene consistencia visual y funcional en toda la app
class AuthComponents {
  /// Campo de texto seguro para autenticación
  /// Usa SecurityIntegrationService por defecto
  static Widget buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String fieldType,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool obscureText = false,
    Function(String)? onChanged,
    Function(String?)? onSaved,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    Function(String)? onFieldSubmitted,
    bool autofocus = false,
  }) {
    return SecurityIntegrationService.buildSecureTextField(
      context: context,
      controller: controller,
      label: label,
      fieldType: fieldType,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      obscureText: obscureText,
      onChanged: onChanged,
      onSaved: onSaved,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      autofocus: autofocus,
    );
  }

  /// Botón primario para autenticación
  /// Estilo consistente con tema de Oasis Taxi
  static Widget buildPrimaryButton({
    required BuildContext context,
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
    IconData? icon,
    double? width,
    double height = 56.0,
  }) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: ModernTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.buttonShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else ...[
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: ModernTheme.getResponsiveFontSize(context, 16),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Botón secundario (outline) para autenticación
  static Widget buildSecondaryButton({
    required BuildContext context,
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
    IconData? icon,
    double? width,
    double height = 56.0,
  }) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: ModernTheme.oasisGreen, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.oasisGreen),
                ),
              )
            else ...[
              if (icon != null) ...[
                Icon(icon, color: ModernTheme.oasisGreen, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: TextStyle(
                  color: ModernTheme.oasisGreen,
                  fontSize: ModernTheme.getResponsiveFontSize(context, 16),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Contenedor de formulario con estilo consistente
  static Widget buildFormContainer({
    required BuildContext context,
    required Widget child,
    EdgeInsets? padding,
  }) {
    return Container(
      padding: padding ?? EdgeInsets.all(ModernTheme.getResponsivePadding(context)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: ModernTheme.floatingShadow,
      ),
      child: child,
    );
  }

  /// Logo responsivo para pantallas de auth
  static Widget buildLogo({
    required BuildContext context,
    double? size,
  }) {
    final logoSize = size ?? _getResponsiveLogoSize(context);

    return Container(
      width: logoSize,
      height: logoSize,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: ModernTheme.cardShadow,
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo.png',
          width: logoSize * 0.7,
          height: logoSize * 0.7,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.local_taxi,
              size: logoSize * 0.5,
              color: ModernTheme.oasisGreen,
            );
          },
        ),
      ),
    );
  }

  /// Espaciador responsivo
  static Widget buildSpacer({
    required BuildContext context,
    double multiplier = 1.0,
  }) {
    return SizedBox(
      height: ModernTheme.getResponsiveSpacing(context) * multiplier,
    );
  }

  /// Header con título y subtítulo
  static Widget buildAuthHeader({
    required BuildContext context,
    required String title,
    String? subtitle,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: ModernTheme.getResponsiveFontSize(context, 32),
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          buildSpacer(context: context, multiplier: 0.5),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white70,
              fontSize: ModernTheme.getResponsiveFontSize(context, 16),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  /// Divisor con texto "O"
  static Widget buildDivider({
    required BuildContext context,
    String text = 'O',
  }) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Colors.grey[300],
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: ModernTheme.getResponsiveFontSize(context, 14),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: Colors.grey[300],
            thickness: 1,
          ),
        ),
      ],
    );
  }

  /// Link de texto para navegación
  static Widget buildTextLink({
    required BuildContext context,
    required String text,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          color: color ?? ModernTheme.oasisGreen,
          fontSize: ModernTheme.getResponsiveFontSize(context, 14),
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  /// Helper method para calcular tamaño de logo responsivo
  static double _getResponsiveLogoSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 400) {
      return 80.0; // Pantallas muy pequeñas
    } else if (screenWidth < 600) {
      return 100.0; // Pantallas medianas
    } else {
      return 120.0; // Pantallas grandes
    }
  }
}