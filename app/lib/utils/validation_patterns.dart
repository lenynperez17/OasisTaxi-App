class ValidationPatterns {
  // Email validation
  static final RegExp email = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  // Phone validation (formato peruano)
  static final RegExp phone = RegExp(
    r'^(\+51)?[9][0-9]{8}$',
  );

  // Password validation (mínimo 8 caracteres, al menos 1 letra y 1 número)
  static final RegExp password = RegExp(
    r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@$!%*#?&]{8,}$',
  );

  // Name validation (solo letras y espacios)
  static final RegExp name = RegExp(
    r'^[a-zA-ZÀ-ÿ\s]{2,50}$',
  );

  // License plate validation (formato peruano)
  static final RegExp licensePlate = RegExp(
    r'^[A-Z]{3}-[0-9]{3}$|^[A-Z]{2}-[0-9]{4}$',
  );

  // DNI validation (8 dígitos)
  static final RegExp dni = RegExp(
    r'^[0-9]{8}$',
  );

  // License number validation
  static final RegExp licenseNumber = RegExp(
    r'^[A-Z]{1}[0-9]{8}$',
  );

  // Métodos de validación
  static bool isValidEmail(String email) {
    return ValidationPatterns.email.hasMatch(email);
  }

  static bool isValidPhone(String phone) {
    return ValidationPatterns.phone.hasMatch(phone);
  }

  static bool isValidPassword(String password) {
    return ValidationPatterns.password.hasMatch(password);
  }

  static bool isValidName(String name) {
    return ValidationPatterns.name.hasMatch(name);
  }

  static bool isValidLicensePlate(String plate) {
    return ValidationPatterns.licensePlate.hasMatch(plate.toUpperCase());
  }

  static bool isValidDNI(String dni) {
    return ValidationPatterns.dni.hasMatch(dni);
  }

  static bool isValidLicenseNumber(String license) {
    return ValidationPatterns.licenseNumber.hasMatch(license.toUpperCase());
  }

  /// Validación específica para móviles peruanos (CRÍTICO ANTI-BYPASS)
  static bool isValidPeruMobile(String phoneNumber) {
    // Validación estricta: solo números de móvil peruanos válidos
    // Formato: 9XXXXXXXX (9 dígitos empezando con 9)
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[\s\-\+]'), '');

    // Triple verificación obligatoria
    if (!RegExp(r'^9[0-9]{8}$').hasMatch(cleanPhone)) return false;

    // Verificar operador válido
    final operatorCode = cleanPhone.substring(0, 2);
    final validOperators = {
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
    };

    return validOperators.contains(operatorCode);
  }

  /// Formatear número para Firebase Auth (+51 prefix)
  static String formatForFirebaseAuth(String phoneNumber) {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[\s\-\+]'), '');
    return '+51$cleanPhone';
  }

  // Mensajes de error
  static String getEmailError() {
    return 'Ingrese un email válido';
  }

  static String getPhoneError() {
    return 'Ingrese un número de teléfono peruano válido (+51 9XXXXXXXX)';
  }

  static String getPasswordError() {
    return 'La contraseña debe tener mínimo 8 caracteres, al menos 1 letra y 1 número';
  }

  static String getNameError() {
    return 'El nombre debe contener solo letras y tener entre 2 y 50 caracteres';
  }

  static String getLicensePlateError() {
    return 'Ingrese una placa válida (AAA-123 o AA-1234)';
  }

  static String getDNIError() {
    return 'El DNI debe tener 8 dígitos';
  }

  static String getLicenseNumberError() {
    return 'Ingrese un número de licencia válido (A12345678)';
  }
}
