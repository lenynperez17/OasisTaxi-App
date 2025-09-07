import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Helper centralizado para mostrar SnackBars consistentes
class SnackBarHelper {
  
  /// Mostrar SnackBar de éxito
  static void showSuccess(BuildContext context, String message, {int duration = 3}) {
    _showSnackBar(
      context, 
      message, 
      AppColors.oasisGreen, 
      Icons.check_circle_outline,
      duration
    );
  }

  /// Mostrar SnackBar de error
  static void showError(BuildContext context, String message, {int duration = 4}) {
    _showSnackBar(
      context, 
      message, 
      Colors.red, 
      Icons.error_outline,
      duration
    );
  }

  /// Mostrar SnackBar de advertencia
  static void showWarning(BuildContext context, String message, {int duration = 3}) {
    _showSnackBar(
      context, 
      message, 
      Colors.orange, 
      Icons.warning_outlined,
      duration
    );
  }

  /// Mostrar SnackBar informativo
  static void showInfo(BuildContext context, String message, {int duration = 3}) {
    _showSnackBar(
      context, 
      message, 
      Colors.blue, 
      Icons.info_outline,
      duration
    );
  }

  /// Mostrar SnackBar personalizado
  static void showCustom(
    BuildContext context, 
    String message, {
    Color? backgroundColor,
    Color? textColor,
    IconData? icon,
    int duration = 3,
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: textColor ?? Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor ?? Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor ?? AppColors.oasisBlack,
        duration: Duration(seconds: duration),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: action,
      ),
    );
  }

  /// Helper privado para mostrar SnackBar base
  static void _showSnackBar(
    BuildContext context, 
    String message, 
    Color backgroundColor, 
    IconData icon,
    int duration,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: Duration(seconds: duration),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Limpiar SnackBars existentes
  static void clear(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  /// Mostrar SnackBar con acción
  static void showWithAction(
    BuildContext context,
    String message,
    String actionLabel,
    VoidCallback onActionPressed, {
    Color? backgroundColor,
    int duration = 5,
  }) {
    showCustom(
      context,
      message,
      backgroundColor: backgroundColor,
      duration: duration,
      action: SnackBarAction(
        label: actionLabel,
        textColor: Colors.white,
        onPressed: onActionPressed,
      ),
    );
  }
}