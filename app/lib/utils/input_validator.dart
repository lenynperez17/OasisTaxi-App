import 'package:flutter/services.dart';
import 'validation_patterns.dart';

/// Validador universal de inputs para máxima seguridad
/// Previene SQL injection, XSS, buffer overflow y otros ataques
class InputValidator {
  // Patrones maliciosos comunes
  static final RegExp _sqlInjectionPattern = RegExp(
    r"(\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|EXECUTE|UNION|FROM|WHERE|JOIN|TABLE|DATABASE|SCRIPT|JAVASCRIPT|ONCLICK|ONLOAD|ONERROR|ALERT|CONFIRM|PROMPT)\b)|(--)|(;)|(\*)|(\||\/\*|\*\/|xp_|sp_|0x)",
    caseSensitive: false,
  );

  static final RegExp _xssPattern = RegExp(
    r"(<script[^>]*>.*?</script>)|(<iframe[^>]*>.*?</iframe>)|(javascript:)|(on\w+\s*=)|(<[^>]*>)|(&lt;)|(&gt;)|(&quot;)|(&apos;)",
    caseSensitive: false,
  );

  static final RegExp _commandInjectionPattern = RegExp(
    r"([;&|`$])|(\.\.)|(\/etc\/)|(\/bin\/)|(\/usr\/)|(cmd\.exe)|(powershell)|(bash)|(sh\s)",
    caseSensitive: false,
  );

  static final RegExp _pathTraversalPattern = RegExp(
    r"(\.\.[\/\\])|([\/\\]\.\.)|(\.\.%2[fF])|(%2[eE]\.)|(\.\.\/)|(\.\.\x5c)",
  );

  // Límites seguros
  static const int maxStringLength = 500;
  static const int maxNameLength = 100;
  static const int maxEmailLength = 254;
  static const int maxPasswordLength = 128;
  static const int maxPhoneLength = 15;
  static const int maxAddressLength = 200;
  static const int maxDescriptionLength = 1000;
  static const double maxPrice = 9999.99;
  static const double minPrice = 0.01;

  /// Valida y sanitiza entrada de texto genérica
  static String? validateText(
    String? value, {
    required String fieldName,
    int? minLength,
    int? maxLength,
    bool required = true,
    bool allowNumbers = true,
    bool allowSpecialChars = false,
    String? customPattern,
  }) {
    // Verificar requerido
    if (required && (value == null || value.trim().isEmpty)) {
      return '$fieldName es obligatorio';
    }

    if (value == null || value.isEmpty) return null;

    final trimmed = value.trim();

    // Verificar longitud
    if (minLength != null && trimmed.length < minLength) {
      return '$fieldName debe tener al menos $minLength caracteres';
    }

    final max = maxLength ?? maxStringLength;
    if (trimmed.length > max) {
      return '$fieldName no puede exceder $max caracteres';
    }

    // Verificar inyección SQL
    if (_sqlInjectionPattern.hasMatch(trimmed)) {
      return '$fieldName contiene caracteres no permitidos';
    }

    // Verificar XSS
    if (_xssPattern.hasMatch(trimmed)) {
      return '$fieldName contiene código malicioso';
    }

    // Verificar command injection
    if (_commandInjectionPattern.hasMatch(trimmed)) {
      return '$fieldName contiene comandos no permitidos';
    }

    // Verificar path traversal
    if (_pathTraversalPattern.hasMatch(trimmed)) {
      return '$fieldName contiene rutas no permitidas';
    }

    // Validación de caracteres permitidos
    if (!allowNumbers && RegExp(r'\d').hasMatch(trimmed)) {
      return '$fieldName no debe contener números';
    }

    if (!allowSpecialChars &&
        RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(trimmed)) {
      return '$fieldName no debe contener caracteres especiales';
    }

    // Patrón personalizado
    if (customPattern != null && !RegExp(customPattern).hasMatch(trimmed)) {
      return '$fieldName tiene formato inválido';
    }

    return null;
  }

  /// Valida email con máxima seguridad
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email es obligatorio';
    }

    final email = value.trim().toLowerCase();

    // Longitud
    if (email.length > maxEmailLength) {
      return 'Email demasiado largo';
    }

    // Formato básico
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(email)) {
      return 'Formato de email inválido';
    }

    // Verificar dominios temporales/sospechosos
    final blockedDomains = [
      'tempmail.com',
      'guerrillamail.com',
      '10minutemail.com',
      'mailinator.com',
      'throwaway.email',
      'yopmail.com',
      'trashmail.com',
      'fakeinbox.com',
      'maildrop.cc',
    ];

    for (final domain in blockedDomains) {
      if (email.endsWith(domain)) {
        return 'Dominio de email no permitido';
      }
    }

    // Verificar caracteres maliciosos
    if (_sqlInjectionPattern.hasMatch(email) || _xssPattern.hasMatch(email)) {
      return 'Email contiene caracteres no permitidos';
    }

    return null;
  }

  /// Valida teléfono peruano
  static String? validatePeruvianPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Teléfono es obligatorio';
    }

    // Limpiar número
    final phone = value.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');

    // Debe ser 9 dígitos empezando con 9
    if (!RegExp(r'^9[0-9]{8}$').hasMatch(phone)) {
      return 'Debe ser un número móvil peruano (9 dígitos)';
    }

    // Verificar operador válido
    final validPrefixes = [
      '90',
      '91',
      '92',
      '93',
      '94',
      '95',
      '96',
      '97',
      '98',
      '99'
    ];
    final prefix = phone.substring(0, 2);

    if (!validPrefixes.contains(prefix)) {
      return 'Operador móvil no válido';
    }

    return null;
  }

  /// Valida contraseña segura
  static String? validatePassword(String? value, {bool isNewPassword = true}) {
    if (value == null || value.isEmpty) {
      return 'Contraseña es obligatoria';
    }

    if (value.length < 8) {
      return 'Mínimo 8 caracteres';
    }

    if (value.length > maxPasswordLength) {
      return 'Máximo $maxPasswordLength caracteres';
    }

    // Verificar contraseñas comunes - aplicar siempre para seguridad
    final commonPasswords = [
      'password',
      '12345678',
      'qwerty',
      'abc123',
      'password123',
      'admin',
      'letmein',
      'welcome',
      'monkey',
      '1234567890',
    ];

    final lowerValue = value.toLowerCase();
    for (final common in commonPasswords) {
      if (lowerValue.contains(common)) {
        return 'Contraseña demasiado común';
      }
    }

    // Verificar patrón de complejidad (letra + número)
    if (!ValidationPatterns.password.hasMatch(value)) {
      return ValidationPatterns.getPasswordError();
    }

    // Verificar caracteres peligrosos
    if (_sqlInjectionPattern.hasMatch(value)) {
      return 'Contraseña contiene caracteres no permitidos';
    }

    return null;
  }

  /// Valida nombre completo
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nombre completo es obligatorio';
    }

    final name = value.trim();

    if (name.length < 3) {
      return 'Nombre demasiado corto';
    }

    if (name.length > maxNameLength) {
      return 'Nombre demasiado largo';
    }

    // Debe tener al menos nombre y apellido
    if (name.split(' ').length < 2) {
      return 'Ingrese nombre y apellido';
    }

    // Solo letras y espacios
    if (!RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$').hasMatch(name)) {
      return 'Solo se permiten letras';
    }

    // Verificar inyecciones
    if (_sqlInjectionPattern.hasMatch(name) || _xssPattern.hasMatch(name)) {
      return 'Nombre contiene caracteres no permitidos';
    }

    return null;
  }

  /// Valida DNI peruano
  static String? validateDNI(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'DNI es obligatorio';
    }

    final dni = value.trim();

    if (!RegExp(r'^[0-9]{8}$').hasMatch(dni)) {
      return 'DNI debe tener 8 dígitos';
    }

    // Verificar DNIs inválidos conocidos
    if (dni == '00000000' || dni == '11111111' || dni == '12345678') {
      return 'DNI inválido';
    }

    return null;
  }

  /// Valida número de tarjeta (solo formato, no validación real)
  static String? validateCardNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Número de tarjeta es obligatorio';
    }

    final card = value.replaceAll(RegExp(r'[\s\-]'), '');

    if (!RegExp(r'^[0-9]{13,19}$').hasMatch(card)) {
      return 'Número de tarjeta inválido';
    }

    // Algoritmo de Luhn básico
    if (!_isValidLuhn(card)) {
      return 'Número de tarjeta inválido';
    }

    return null;
  }

  /// Valida precio/monto
  static String? validatePrice(
    String? value, {
    double? min,
    double? max,
    bool required = true,
  }) {
    if (required && (value == null || value.trim().isEmpty)) {
      return 'Precio es obligatorio';
    }

    if (value == null || value.isEmpty) return null;

    final price = double.tryParse(value.replaceAll(',', '.'));

    if (price == null) {
      return 'Precio inválido';
    }

    final minPrice = min ?? InputValidator.minPrice;
    final maxPrice = max ?? InputValidator.maxPrice;

    if (price < minPrice) {
      return 'Precio mínimo es S/ ${minPrice.toStringAsFixed(2)}';
    }

    if (price > maxPrice) {
      return 'Precio máximo es S/ ${maxPrice.toStringAsFixed(2)}';
    }

    return null;
  }

  /// Valida dirección
  static String? validateAddress(String? value) {
    return validateText(
      value,
      fieldName: 'Dirección',
      minLength: 10,
      maxLength: maxAddressLength,
      allowNumbers: true,
      allowSpecialChars: true,
    );
  }

  /// Valida placa de vehículo peruana
  static String? validateVehiclePlate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Placa es obligatoria';
    }

    final plate = value.trim().toUpperCase();

    if (!RegExp(r'^[A-Z]{3}-[0-9]{3}$').hasMatch(plate)) {
      return 'Formato de placa inválido (XXX-123)';
    }

    return null;
  }

  /// Valida código OTP
  static String? validateOTP(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Código es obligatorio';
    }

    final otp = value.trim();

    if (!RegExp(r'^[0-9]{6}$').hasMatch(otp)) {
      return 'Código debe ser de 6 dígitos';
    }

    return null;
  }

  /// Algoritmo de Luhn para validar tarjetas
  static bool _isValidLuhn(String number) {
    int sum = 0;
    bool alternate = false;

    for (int i = number.length - 1; i >= 0; i--) {
      int digit = int.parse(number[i]);

      if (alternate) {
        digit *= 2;
        if (digit > 9) {
          digit -= 9;
        }
      }

      sum += digit;
      alternate = !alternate;
    }

    return sum % 10 == 0;
  }

  /// Sanitiza string para output seguro
  static String sanitizeOutput(String input) {
    return input
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;')
        .replaceAll('&', '&amp;')
        .replaceAll(
            RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '');
  }

  /// Limita longitud de string de forma segura
  static String truncate(String input, int maxLength) {
    if (input.length <= maxLength) return input;
    return '${input.substring(0, maxLength - 3)}...';
  }
}

/// TextInputFormatter personalizado para validación en tiempo real
class SecureTextInputFormatter extends TextInputFormatter {
  final int? maxLength;
  final bool allowNumbers;
  final bool allowSpecialChars;
  final String? allowedPattern;

  SecureTextInputFormatter({
    this.maxLength,
    this.allowNumbers = true,
    this.allowSpecialChars = false,
    this.allowedPattern,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Verificar longitud máxima
    if (maxLength != null && newValue.text.length > maxLength!) {
      return oldValue;
    }

    // Filtrar caracteres no permitidos
    String filtered = newValue.text;

    // Remover caracteres peligrosos siempre
    filtered = filtered.replaceAll(RegExp(r'[<>"&]'), '');
    filtered = filtered.replaceAll("'", '');

    if (!allowNumbers) {
      filtered = filtered.replaceAll(RegExp(r'\d'), '');
    }

    if (!allowSpecialChars) {
      filtered = filtered.replaceAll(RegExp(r'[!@#$%^&*(),.?":{}|<>]'), '');
    }

    if (allowedPattern != null) {
      final allowed = RegExp(allowedPattern!);
      filtered =
          filtered.split('').where((char) => allowed.hasMatch(char)).join();
    }

    if (filtered != newValue.text) {
      return TextEditingValue(
        text: filtered,
        selection: TextSelection.collapsed(offset: filtered.length),
      );
    }

    return newValue;
  }
}
