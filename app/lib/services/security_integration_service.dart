import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/input_validator.dart';
import '../utils/snackbar_helper.dart';

/// Servicio de integración de seguridad
/// Provee métodos helper para integrar todas las medidas de seguridad
class SecurityIntegrationService {
  /// Crea un TextFormField seguro con validación automática
  static Widget buildSecureTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String fieldType,
    String? hintText,
    bool obscureText = false,
    bool enabled = true,
    int? maxLength,
    TextInputType? keyboardType,
    Widget? prefixIcon,
    Widget? suffixIcon,
    Function(String)? onChanged,
    Function(String?)? onSaved,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    Function(String)? onFieldSubmitted,
    bool autofocus = false,
    bool autocorrect = false,
    bool enableSuggestions = true,
  }) {
    // Determinar validador según tipo de campo
    String? Function(String?) validator;
    List<TextInputFormatter> inputFormatters = [];

    switch (fieldType.toLowerCase()) {
      case 'email':
        validator = InputValidator.validateEmail;
        keyboardType ??= TextInputType.emailAddress;
        inputFormatters.add(SecureTextInputFormatter(
          allowSpecialChars: true,
          maxLength: 254,
        ));
        break;

      case 'password':
        validator = (value) =>
            InputValidator.validatePassword(value, isNewPassword: true);
        obscureText = true;
        enableSuggestions = false;
        autocorrect = false;
        inputFormatters.add(SecureTextInputFormatter(
          maxLength: 128,
          allowSpecialChars: true,
        ));
        break;

      case 'phone':
        validator = InputValidator.validatePeruvianPhone;
        keyboardType ??= TextInputType.phone;
        inputFormatters.add(FilteringTextInputFormatter.digitsOnly);
        inputFormatters.add(LengthLimitingTextInputFormatter(9));
        break;

      case 'dni':
        validator = InputValidator.validateDNI;
        keyboardType ??= TextInputType.number;
        inputFormatters.add(FilteringTextInputFormatter.digitsOnly);
        inputFormatters.add(LengthLimitingTextInputFormatter(8));
        break;

      case 'name':
      case 'fullname':
        validator = InputValidator.validateFullName;
        keyboardType ??= TextInputType.name;
        inputFormatters.add(SecureTextInputFormatter(
          allowNumbers: false,
          allowSpecialChars: false,
          maxLength: 100,
        ));
        break;

      case 'address':
        validator = InputValidator.validateAddress;
        keyboardType ??= TextInputType.streetAddress;
        inputFormatters.add(SecureTextInputFormatter(
          maxLength: 200,
          allowSpecialChars: true,
        ));
        break;

      case 'price':
      case 'amount':
        validator = (value) => InputValidator.validatePrice(value);
        keyboardType ??= TextInputType.numberWithOptions(decimal: true);
        inputFormatters
            .add(FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')));
        break;

      case 'plate':
      case 'vehicleplate':
        validator = InputValidator.validateVehiclePlate;
        keyboardType ??= TextInputType.text;
        inputFormatters.add(UpperCaseTextFormatter());
        inputFormatters.add(LengthLimitingTextInputFormatter(7));
        break;

      case 'otp':
      case 'code':
        validator = InputValidator.validateOTP;
        keyboardType ??= TextInputType.number;
        inputFormatters.add(FilteringTextInputFormatter.digitsOnly);
        inputFormatters.add(LengthLimitingTextInputFormatter(6));
        break;

      case 'card':
      case 'cardnumber':
        validator = InputValidator.validateCardNumber;
        keyboardType ??= TextInputType.number;
        inputFormatters.add(FilteringTextInputFormatter.digitsOnly);
        inputFormatters.add(LengthLimitingTextInputFormatter(19));
        inputFormatters.add(CardNumberFormatter());
        break;

      default:
        // Validación genérica de texto
        validator = (value) => InputValidator.validateText(
              value,
              fieldName: label,
              minLength: 1,
              maxLength: maxLength ?? 500,
            );
        inputFormatters.add(SecureTextInputFormatter(
          maxLength: maxLength ?? 500,
        ));
    }

    return TextFormField(
      controller: controller,
      validator: validator,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      enabled: enabled,
      maxLength: maxLength,
      keyboardType: keyboardType,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      autofocus: autofocus,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      onChanged: onChanged,
      onSaved: onSaved,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red[400]!, width: 2),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100],
        counterText: '',
        errorMaxLines: 2,
      ),
    );
  }

  /// Sanitiza output antes de mostrarlo
  static String sanitizeForDisplay(String input) {
    return InputValidator.sanitizeOutput(input);
  }

  /// Trunca texto de forma segura
  static String truncateText(String input, int maxLength) {
    return InputValidator.truncate(input, maxLength);
  }

  /// Valida un formulario completo con feedback
  static bool validateFormWithFeedback(
    GlobalKey<FormState> formKey,
    BuildContext context,
  ) {
    if (formKey.currentState?.validate() ?? false) {
      return true;
    } else {
      SnackbarHelper.showError(
        context,
        'Por favor corrige los errores en el formulario',
      );
      return false;
    }
  }

  /// Crea un botón seguro con rate limiting
  static Widget buildSecureButton({
    required VoidCallback onPressed,
    required String label,
    required BuildContext context,
    bool isLoading = false,
    IconData? icon,
    Color? backgroundColor,
    Color? textColor,
    double? width,
    double height = 50,
    EdgeInsets? padding,
  }) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      padding: padding,
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : () {
                // Prevenir double-tap
                if (_lastButtonPress != null &&
                    DateTime.now().difference(_lastButtonPress!) <
                        Duration(seconds: 1)) {
                  return;
                }
                _lastButtonPress = DateTime.now();
                onPressed();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? Theme.of(context).primaryColor,
          foregroundColor: textColor ?? Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: isLoading ? 0 : 2,
        ),
        child: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    textColor ?? Colors.white,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  static DateTime? _lastButtonPress;
}

/// Formatter para convertir a mayúsculas
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/// Formatter para números de tarjeta (espacios cada 4 dígitos)
class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();

    for (int i = 0; i < newText.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(newText[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
